# pine ART hot update public builder

Temporary public GitHub Actions builder for Redmi 7A pine ART hot update.

- Source ROM baseline: PixelExtended snow
- Patch: devices/pine/patches/art/android-12.0.0_r32/pine-art-registerdexfile-dump.patch
- Workflow: .github/workflows/build-pine-art-rom.yml
- Current hosted-runner strategy: build `com.android.art` with `aosp_arm64-user`, aggressively free disk, keep 8G extra swap, and use diagnostics to track resource pressure. True resume-from-failure requires a self-hosted runner with persistent `android/out`.
