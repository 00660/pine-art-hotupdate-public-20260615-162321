# LineageOS Xiaomi catalog

This directory is populated by `.github/workflows/discover-lineage-xiaomi.yml`.

The workflow uses official LineageOS sources only:

- `https://wiki.lineageos.org/devices/`
- `https://github.com/LineageOS`
- `https://download.lineageos.org/api/v2/devices/<codename>/builds`

Generated files:

- `lineage-xiaomi-devices.json`
- `lineage-xiaomi-recipes.json`
- `lineage-xiaomi-blocked.json`

Build automation only treats a recipe as `build_ready` when the wiki metadata, LineageOS GitHub repos, BoardConfig files, and official LineageOS download API provide enough facts to build without guessing.
