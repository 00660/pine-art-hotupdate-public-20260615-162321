# pine ART hot update public builder

Temporary public GitHub Actions builder for Redmi 7A pine ART hot update.

- Source ROM baseline: PixelExtended snow
- ART patch: devices/pine/patches/art/android-12.0.0_r32/pine-art-registerdexfile-dump.patch
- Java crypto patch: devices/pine/patches/art/android-12.0.0_r32/pine-libcore-crypto-dump.patch
- Workflow: .github/workflows/build-pine-art-rom.yml
- Current hosted-runner strategy: build `com.android.art` with `aosp_arm64-user`, aggressively free disk, keep 8G extra swap, drop `android/.repo` before build, and use diagnostics to track resource pressure. True resume-from-failure requires a self-hosted runner with persistent `android/out`.

## Java crypto dump switch

The ART APEX build now also patches libcore Java crypto call sites:

- `javax.crypto.Cipher`: `init`, `update`, `doFinal`
- `javax.crypto.Mac`: `init`, `update`, `doFinal`
- `java.security.MessageDigest`: `update`, `digest`
- `javax.crypto.spec.SecretKeySpec`: constructor and `getEncoded`
- `javax.crypto.spec.IvParameterSpec`: constructor and `getIV`

Runtime output is appended to `/data/temp/pine-crypto-dumps/<package>/java-crypto.log`.

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
