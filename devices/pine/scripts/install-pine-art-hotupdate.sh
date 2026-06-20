#!/bin/bash
# Pine ART Hot Update Installation Script (Linux/macOS)
# Pushes patched ART APEX to Redmi 7A and stages for next boot

set -e

ARTIFACT_DIR="${1:-pine-art-hotupdate}"
DEVICE_SERIAL="${2:-192.168.2.103:5555}"
ROOT_SU="/debug_ramdisk/su"

echo "========================================"
echo "Pine ART Hot Update Installer"
echo "========================================"
echo

# Check artifact directory
if [ ! -d "$ARTIFACT_DIR" ]; then
    echo "ERROR: Artifact directory not found: $ARTIFACT_DIR"
    echo "Please download and extract the artifact from GitHub Actions first."
    exit 1
fi

# Check ADB
if ! command -v adb &> /dev/null; then
    echo "ERROR: adb not found. Please install Android SDK Platform Tools."
    exit 1
fi

# Connect to device
echo "Connecting to device $DEVICE_SERIAL..."
adb connect "$DEVICE_SERIAL"
sleep 2

# Verify device
echo "Verifying device..."
device=$(adb -s "$DEVICE_SERIAL" shell getprop ro.product.device 2>&1 | tr -d '\r')
if [[ ! "$device" =~ pine ]]; then
    echo "WARNING: Device codename is '$device', expected 'pine'"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check root
echo "Checking root access..."
root_check=$(adb -s "$DEVICE_SERIAL" shell "$ROOT_SU -c 'id'" 2>&1)
if [[ ! "$root_check" =~ uid=0 ]]; then
    echo "ERROR: Root access not available via $ROOT_SU"
    echo "Output: $root_check"
    exit 1
fi
echo "Root access confirmed."

# Find APEX files
mapfile -t apex_files < <(find "$ARTIFACT_DIR/files" -name "*.apex" -type f)
if [ ${#apex_files[@]} -eq 0 ]; then
    echo "ERROR: No APEX files found in $ARTIFACT_DIR/files/"
    exit 1
fi

echo
echo "Found ${#apex_files[@]} APEX file(s):"
for apex in "${apex_files[@]}"; do
    size_mb=$(du -h "$apex" | cut -f1)
    echo "  - $(basename "$apex") ($size_mb)"
done

# Create /data/temp directories first
echo
echo "Creating /data/temp dump directories..."
adb -s "$DEVICE_SERIAL" shell "$ROOT_SU -c 'mkdir -p /data/temp/pine-art-dumps /data/temp/pine-crypto-dumps'"
adb -s "$DEVICE_SERIAL" shell "$ROOT_SU -c 'chmod 0777 /data/temp'"
adb -s "$DEVICE_SERIAL" shell "$ROOT_SU -c 'chmod 0777 /data/temp/pine-art-dumps'"
adb -s "$DEVICE_SERIAL" shell "$ROOT_SU -c 'chmod 0777 /data/temp/pine-crypto-dumps'"

adb -s "$DEVICE_SERIAL" shell "$ROOT_SU -c 'ls -ld /data/temp /data/temp/pine-art-dumps /data/temp/pine-crypto-dumps'"

# Confirm installation
echo
echo "Ready to install ART hot update."
echo "This will:"
echo "  1. Push APEX files to /data/local/tmp/"
echo "  2. Stage them for activation on next boot"
echo "  3. Require a reboot to take effect"
echo
read -p "Proceed with installation? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Push APEX files
echo
echo "Pushing APEX files to device..."
for apex in "${apex_files[@]}"; do
    apex_name=$(basename "$apex")
    echo "  Pushing $apex_name..."
    adb -s "$DEVICE_SERIAL" push "$apex" "/data/local/tmp/$apex_name"
done

# Stage APEX via adb install
echo
echo "Staging APEX modules..."
for apex in "${apex_files[@]}"; do
    apex_name=$(basename "$apex")
    echo "  Staging $apex_name..."
    stage_path="/data/local/tmp/$apex_name"

    # Try adb install --staged for APEX
    if adb -s "$DEVICE_SERIAL" install --staged "$stage_path" 2>&1; then
        echo "    Staged successfully."
    else
        echo "    WARNING: Staging may have failed."
        echo "    You may need to manually activate via 'adb shell pm install-staged' or reboot."
    fi
done

# Enable DEX dump
echo
echo "Enabling DEX dump for testing..."
adb -s "$DEVICE_SERIAL" shell setprop persist.sys.pine_art_dexdump true
echo "  persist.sys.pine_art_dexdump = true"
adb -s "$DEVICE_SERIAL" shell "$ROOT_SU -c 'touch /data/temp/pine-crypto-dump.enable'"
echo "  /data/temp/pine-crypto-dump.enable created"

# Installation summary
echo
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo
echo "Next steps:"
echo "  1. Reboot device: adb reboot"
echo "  2. Reconnect: adb connect $DEVICE_SERIAL"
echo "  3. Test dump:"
echo "       adb shell monkey -p com.android.settings 1"
echo "       adb shell su -c 'ls -lR /data/temp/pine-art-dumps/'"
echo "       adb shell su -c 'find /data/temp/pine-crypto-dumps -type f -maxdepth 3 -print'"
echo "  4. Check logs:"
echo "       adb logcat -d | grep 'pine ART dexdump'"
echo

# Cleanup temp files
echo "Cleaning up..."
for apex in "${apex_files[@]}"; do
    apex_name=$(basename "$apex")
    adb -s "$DEVICE_SERIAL" shell rm -f "/data/local/tmp/$apex_name" 2>&1 || true
done

echo "Done! Ready to reboot."
