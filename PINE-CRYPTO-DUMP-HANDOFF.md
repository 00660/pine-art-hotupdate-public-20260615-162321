# Pine ART Crypto Dump Build Handoff

## Scope

This repository is the pine ART, Conscrypt, and BoringSSL APEX builder that already produced successful ART artifacts. The work keeps Java crypto dump instrumentation in `com.android.art`, adds second-layer Conscrypt instrumentation in `com.android.conscrypt`, and adds third-layer BoringSSL native instrumentation through the Conscrypt native dependency path, not a target APK injection path.

## Changed files

- `.github/workflows/build-pine-art-rom.yml`: applies the existing ART DEX dump patch plus libcore, Conscrypt, and BoringSSL crypto dump patches, then uploads the applied diffs.
- `devices/pine/patches/art/android-12.0.0_r32/pine-libcore-crypto-dump.patch`: patches Android 12 `libcore` Java crypto classes.
- `devices/pine/patches/art/android-12.0.0_r32/pine-conscrypt-crypto-dump.patch`: patches Android 12 Conscrypt repackaged provider/TLS classes.
- `devices/pine/patches/art/android-12.0.0_r32/pine-boringssl-crypto-dump.patch`: patches Android 12 BoringSSL native crypto entry points.
- `README.md`: documents runtime switches and output path.

## Runtime behavior

The generated ART APEX logs Java crypto material to:

```text
/data/temp/pine-crypto-dumps/<package>/java-crypto.log
/data/temp/pine-crypto-dumps/<package>/conscrypt-crypto.log
/data/temp/pine-crypto-dumps/<package>/boringssl-crypto.log
```

Enable globally:

```bash
adb shell su -c "mkdir -p /data/temp/pine-crypto-dumps && chmod 0777 /data/temp /data/temp/pine-crypto-dumps"
adb shell su -c "touch /data/temp/pine-crypto-dump.enable"
```

Limit to one package:

```bash
adb shell su -c "echo com.target.app > /data/temp/pine-crypto-dump.pkg"
```

Disable:

```bash
adb shell su -c "rm -f /data/temp/pine-crypto-dump.enable /data/temp/pine-crypto-dump.pkg"
```

## Instrumented APIs

- `Cipher.init`, `Cipher.update`, `Cipher.doFinal`
- `Mac.init`, `Mac.update`, `Mac.doFinal`
- `MessageDigest.update`, `MessageDigest.digest`
- `SecretKeySpec` constructors and `getEncoded`
- `IvParameterSpec` constructors and `getIV`
- Conscrypt `OpenSSLEvpCipher` EVP cipher init/update/final
- Conscrypt `OpenSSLAeadCipher` AEAD init/update/AAD/final
- Conscrypt `OpenSSLMac` HMAC init/update/final
- Conscrypt `OpenSSLMessageDigestJDK` digest update/final
- Conscrypt socket plaintext read/write paths
- BoringSSL `EVP_CipherInit_ex`, `EVP_EncryptUpdate`, `EVP_DecryptUpdate`
- BoringSSL `EVP_EncryptFinal_ex`, `EVP_DecryptFinal_ex`
- BoringSSL `HMAC_Init_ex`, `HMAC_Update`, `HMAC_Final`
- BoringSSL `MD5_Update`, `SHA1_Update`, `SHA256_Update`, `SHA512_Update`

## Backup

Pre-edit backup:

```text
.backups\pine-crypto-output-20260620-132538
```

The backup contains the pre-edit workflow, README, guide, patch directory, and `pre-edit.diff`.

## Validation

Local validation completed before pushing:

```text
git apply --check pine-libcore-crypto-dump.patch: OK
git apply pine-libcore-crypto-dump.patch: OK
git diff --check after apply: OK
```

GitHub Actions remains the authoritative build path. Do not run a full Android build locally for this repo unless explicitly needed.
