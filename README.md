# pine ART hot update public builder

Temporary public GitHub Actions builder for Redmi 7A pine ART hot update.

- Source ROM baseline: PixelExtended snow
- ART patch: devices/pine/patches/art/android-12.0.0_r32/pine-art-registerdexfile-dump.patch
- Java crypto patch: devices/pine/patches/art/android-12.0.0_r32/pine-libcore-crypto-dump.patch
- Conscrypt crypto patch: devices/pine/patches/art/android-12.0.0_r32/pine-conscrypt-crypto-dump.patch
- BoringSSL native crypto patch: devices/pine/patches/art/android-12.0.0_r32/pine-boringssl-crypto-dump.patch
- Bionic/linker anti-detect patch: devices/pine/patches/bionic/android-12.0.0_r32/pine-bionic-linker-antidetect.patch
- Framework/property/package anti-detect patch: devices/pine/patches/frameworks-base/android-12.0.0_r32/pine-framework-antidetect.patch
- Native SO analysis tool: devices/pine/tools/pine-so-analysis.py
- Workflow: .github/workflows/build-pine-art-rom.yml
- Current hosted-runner strategy: build `com.android.art com.android.conscrypt com.android.runtime framework-minus-apex services` with `aosp_arm64-user`, aggressively free disk, keep 8G extra swap, drop `android/.repo` before build, and use diagnostics to track resource pressure. True resume-from-failure requires a self-hosted runner with persistent `android/out`.

## Java crypto dump switch

The ART APEX build now also patches libcore Java crypto call sites:

- `javax.crypto.Cipher`: `init`, `update`, `doFinal`
- `javax.crypto.Mac`: `init`, `update`, `doFinal`
- `java.security.MessageDigest`: `update`, `digest`
- `javax.crypto.spec.SecretKeySpec`: constructor and `getEncoded`
- `javax.crypto.spec.IvParameterSpec`: constructor and `getIV`

Runtime output is appended to `/data/temp/pine-crypto-dumps/<package>/java-crypto.log`.

The Conscrypt APEX patch adds second-layer instrumentation for:

- `OpenSSLEvpCipher`: EVP cipher init/update/final
- `OpenSSLAeadCipher`: AEAD init/update/AAD/final
- `OpenSSLMac`: HMAC init/update/final
- `OpenSSLMessageDigestJDK`: digest update/final
- `ConscryptFileDescriptorSocket` and `ConscryptEngineSocket`: TLS plaintext read/write paths

Conscrypt output is appended to `/data/temp/pine-crypto-dumps/<package>/conscrypt-crypto.log`.

The BoringSSL native patch adds third-layer instrumentation for:

- `EVP_CipherInit_ex`, `EVP_EncryptUpdate`, `EVP_DecryptUpdate`
- `EVP_EncryptFinal_ex`, `EVP_DecryptFinal_ex`
- `HMAC_Init_ex`, `HMAC_Update`, `HMAC_Final`
- `MD5_Update`, `SHA1_Update`, `SHA256_Update`, `SHA512_Update`

BoringSSL output is appended to `/data/temp/pine-crypto-dumps/<package>/boringssl-crypto.log`.

## System anti-detect switch

The system component patches add target-scoped hiding on top of the boot-layer syscall filter:

- bionic/libc wrappers: `access`, `faccessat`, `open`, `openat`, `readlink`
- linker: `dlopen` / `android_dlopen_ext` library-name blocking for common instrumentation names
- framework: package list/package lookup filtering and selected property spoofing

Enable only for one package:

```bash
adb shell su -c "setprop debug.pine.hide_pkg com.target.app"
adb shell su -c "setprop debug.pine.native_hide 1"
adb shell su -c "setprop debug.pine.framework_hide 1"
```

Disable:

```bash
adb shell su -c "setprop debug.pine.native_hide 0"
adb shell su -c "setprop debug.pine.framework_hide 0"
adb shell su -c "setprop debug.pine.hide_pkg ''"
```

## Native SO analysis

The artifact contains `tools/pine-so-analysis.py` for offline SO/OLLVM triage:

```bash
python3 tools/pine-so-analysis.py --out report-dir target.apk
python3 tools/pine-so-analysis.py --out report-dir native-libs/
```

It emits hashes, ELF/readelf output when available, strings, and heuristic hits for anti-debug/root detection, crypto, and OLLVM-like markers.

Enable it on device:

```bash
adb shell su -c "mkdir -p /data/temp/pine-crypto-dumps && chmod 0777 /data/temp /data/temp/pine-crypto-dumps"
adb shell su -c "touch /data/temp/pine-crypto-dump.enable"
adb shell su -c "echo com.target.app > /data/temp/pine-crypto-dump.pkg"
```

Disable it:

```bash
adb shell su -c "rm -f /data/temp/pine-crypto-dump.enable /data/temp/pine-crypto-dump.pkg"
```
