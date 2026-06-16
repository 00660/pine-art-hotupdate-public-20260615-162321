#!/system/bin/sh
# Pine ART DEX dump OTA setup script
# Creates /data/temp directory structure for DEX dumping

set -e

TEMP_BASE="/data/temp"
DUMP_BASE="${TEMP_BASE}/pine-art-dumps"

echo "Pine ART DEX dump setup"

# Create base directories
if [ ! -d "${TEMP_BASE}" ]; then
    mkdir -p "${TEMP_BASE}"
    chmod 0777 "${TEMP_BASE}"
    echo "Created ${TEMP_BASE}"
else
    echo "${TEMP_BASE} already exists"
fi

if [ ! -d "${DUMP_BASE}" ]; then
    mkdir -p "${DUMP_BASE}"
    chmod 0777 "${DUMP_BASE}"
    echo "Created ${DUMP_BASE}"
else
    echo "${DUMP_BASE} already exists"
    chmod 0777 "${DUMP_BASE}"
fi

# Set SELinux context if supported
if command -v chcon >/dev/null 2>&1; then
    chcon -R u:object_r:system_data_file:s0 "${TEMP_BASE}" 2>/dev/null || true
fi

echo "Setup complete. DEX dumps will be written to: ${DUMP_BASE}/<package>/"
echo ""
echo "To enable dumping for a specific package:"
echo "  setprop persist.sys.pine_art_dexdump true"
echo "  setprop persist.sys.pine_art_dexdump_pkg <package_name>"
echo ""
echo "To enable dumping for all packages:"
echo "  setprop persist.sys.pine_art_dexdump true"
echo ""
echo "To disable:"
echo "  setprop persist.sys.pine_art_dexdump false"
