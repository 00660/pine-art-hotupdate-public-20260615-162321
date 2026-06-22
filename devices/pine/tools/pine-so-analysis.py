#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import shutil
import string
import subprocess
import sys
import zipfile
from pathlib import Path


DETECTION_NEEDLES = [
    "frida", "xposed", "lsposed", "zygisk", "riru", "magisk", "kernelsu",
    "apatch", "ptrace", "tracerpid", "/proc/self/maps", "/proc/self/status",
    "getprop", "ro.debuggable", "ro.secure", "process_vm_readv",
    "perf_event_open", "dlopen", "dlsym", "android_dlopen_ext", "syscall",
]

CRYPTO_NEEDLES = [
    "aes", "rsa", "ecb", "cbc", "gcm", "hmac", "sha1", "sha256", "sha512",
    "evp_", "ssl_", "tls", "boringssl", "openssl",
]

OLLVM_NEEDLES = [
    "ollvm", "obfuscator", "bcf", "fla", "substitution", "__llvm", "llvm",
]


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def is_elf(path):
    try:
        with open(path, "rb") as f:
            return f.read(4) == b"\x7fELF"
    except OSError:
        return False


def extract_printable_strings(data, min_len=6):
    allowed = set(bytes(string.printable, "ascii"))
    current = bytearray()
    out = []
    for b in data:
        if b in allowed and b not in (0x0b, 0x0c):
            current.append(b)
        else:
            if len(current) >= min_len:
                out.append(current.decode("ascii", "ignore"))
            current.clear()
    if len(current) >= min_len:
        out.append(current.decode("ascii", "ignore"))
    return out


def count_needles(text, needles):
    lower = text.lower()
    hits = {}
    for needle in needles:
        count = lower.count(needle.lower())
        if count:
            hits[needle] = count
    return hits


def run_readelf(path):
    if shutil.which("readelf") is None:
        return ""
    proc = subprocess.run(
        ["readelf", "-h", "-l", "-d", str(path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=30,
        check=False,
    )
    return proc.stdout


def collect_inputs(inputs, work_dir):
    out = []
    extracted = work_dir / "extracted"
    extracted.mkdir(parents=True, exist_ok=True)
    for item in inputs:
        path = Path(item)
        if path.is_dir():
            out.extend(p for p in path.rglob("*") if p.is_file() and (p.suffix == ".so" or is_elf(p)))
            continue
        if path.is_file() and zipfile.is_zipfile(path):
            target = extracted / path.stem
            target.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(path) as zf:
                for name in zf.namelist():
                    if name.endswith(".so") and (name.startswith("lib/") or "/lib/" in name):
                        zf.extract(name, target)
            out.extend(p for p in target.rglob("*.so") if p.is_file())
            continue
        if path.is_file() and (path.suffix == ".so" or is_elf(path)):
            out.append(path)
    return sorted(set(out), key=lambda p: str(p))


def analyze_file(path, root, out_dir):
    data = path.read_bytes()
    strings_list = extract_printable_strings(data)
    strings_text = "\n".join(strings_list)
    rel = os.path.relpath(path, root) if str(path).startswith(str(root)) else path.name
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", rel)[:180]

    (out_dir / f"{safe}.strings.txt").write_text(strings_text[:512 * 1024], encoding="utf-8")
    readelf_text = run_readelf(path)
    if readelf_text:
        (out_dir / f"{safe}.readelf.txt").write_text(readelf_text, encoding="utf-8")

    return {
        "path": rel,
        "size": len(data),
        "sha256": sha256_file(path),
        "detection_hits": count_needles(strings_text, DETECTION_NEEDLES),
        "crypto_hits": count_needles(strings_text, CRYPTO_NEEDLES),
        "ollvm_hints": count_needles(strings_text, OLLVM_NEEDLES),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="+", help="APK, zip, SO, or directory")
    parser.add_argument("--out", required=True, help="output report directory")
    args = parser.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    work_dir = out_dir / "_work"
    work_dir.mkdir(parents=True, exist_ok=True)

    files = collect_inputs(args.inputs, work_dir)
    summaries = [analyze_file(path, work_dir, out_dir) for path in files]
    summary = {
        "elf_count": len(summaries),
        "files": summaries,
    }
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (out_dir / "README.md").write_text(
        "# Pine SO Analysis\n\n"
        "This report lists ELF files, hashes, selected strings, and heuristic hits for "
        "anti-debug/root detection, crypto, and OLLVM-like markers.\n",
        encoding="utf-8",
    )
    shutil.rmtree(work_dir, ignore_errors=True)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
