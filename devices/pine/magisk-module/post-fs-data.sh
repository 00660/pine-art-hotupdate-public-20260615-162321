#!/system/bin/sh
# Pine ART DEX dump post-fs-data initialization
# Creates /data/temp directory structure before system boots

MODDIR=${0%/*}

mkdir -p /data/temp/pine-art-dumps
chmod 0777 /data/temp
chmod 0777 /data/temp/pine-art-dumps

# Optional: Set SELinux context
if [ -e /system/bin/chcon ]; then
    chcon -R u:object_r:system_data_file:s0 /data/temp 2>/dev/null || true
fi

# Log success
echo "$(date): Pine ART DEX dump directories initialized" >> /data/temp/pine-art-init.log
