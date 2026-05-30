# LineageOS recipes

Recipes in this directory are generated from official LineageOS sources only:

- `https://wiki.lineageos.org/devices/`
- `https://github.com/LineageOS`
- `https://download.lineageos.org/api/v2/devices/<codename>/builds`

`build_ready` means the LineageOS wiki entry provides a Xiaomi device tree and kernel repo, both repos have a shared LineageOS branch, the kernel repo validates as a full source tree, BoardConfig exposes `TARGET_KERNEL_CONFIG`, and the official LineageOS download API has a current OTA zip to provide the matching `boot.img` baseline.
