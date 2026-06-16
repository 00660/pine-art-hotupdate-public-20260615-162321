#!/bin/bash
# Package Pine ART DEX Dump Magisk Module

set -e

MODULE_DIR="$(dirname "$0")/magisk-module"
OUTPUT_DIR="$(dirname "$0")/output"
MODULE_NAME="pine-art-dexdump-setup-magisk-v1.0.zip"

echo "Packaging Pine ART DEX Dump Magisk module..."

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Create temporary build directory
BUILD_DIR=$(mktemp -d)
trap "rm -rf $BUILD_DIR" EXIT

# Copy module files
cp "$MODULE_DIR/module.prop" "$BUILD_DIR/"
cp "$MODULE_DIR/post-fs-data.sh" "$BUILD_DIR/"
chmod 755 "$BUILD_DIR/post-fs-data.sh"

# Create update-binary (standard Magisk installer)
mkdir -p "$BUILD_DIR/META-INF/com/google/android"
cat > "$BUILD_DIR/META-INF/com/google/android/update-binary" << 'EOF'
#!/sbin/sh
OUTFD=$2
ZIPFILE=$3

ui_print() {
  echo "ui_print $1" > /proc/self/fd/$OUTFD
  echo "ui_print" > /proc/self/fd/$OUTFD
}

ui_print "=========================================="
ui_print "Pine ART DEX Dump Setup"
ui_print "=========================================="

MODPATH=/data/adb/modules/pine_art_dexdump_setup
rm -rf $MODPATH
mkdir -p $MODPATH

unzip -o "$ZIPFILE" -d $MODPATH >&2
chmod 755 $MODPATH/post-fs-data.sh

ui_print "Module installed successfully!"
ui_print "Reboot to activate."
ui_print ""
ui_print "After reboot, /data/temp/pine-art-dumps"
ui_print "will be created automatically."
ui_print ""
ui_print "=========================================="

exit 0
EOF
chmod 755 "$BUILD_DIR/META-INF/com/google/android/update-binary"

# Create updater-script (required but unused by Magisk)
cat > "$BUILD_DIR/META-INF/com/google/android/updater-script" << 'EOF'
#MAGISK
EOF

# Create zip
cd "$BUILD_DIR"
zip -r "$OUTPUT_DIR/$MODULE_NAME" . > /dev/null

echo "✓ Module packaged: $OUTPUT_DIR/$MODULE_NAME"
echo ""
echo "Install via:"
echo "  adb push $OUTPUT_DIR/$MODULE_NAME /sdcard/"
echo "  # Then flash in Magisk Manager"
