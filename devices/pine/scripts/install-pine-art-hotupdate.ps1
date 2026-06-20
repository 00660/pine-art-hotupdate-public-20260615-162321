# Pine ART Hot Update Installation Script
# Pushes patched ART APEX to Redmi 7A and stages for next boot

param(
    [string]$ArtifactDir = "pine-art-hotupdate",
    [string]$DeviceSerial = "192.168.2.103:5555",
    [string]$RootSu = "/debug_ramdisk/su"
)

$ErrorActionPreference = 'Stop'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Pine ART Hot Update Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check artifact directory
if (-not (Test-Path $ArtifactDir)) {
    Write-Host "ERROR: Artifact directory not found: $ArtifactDir" -ForegroundColor Red
    Write-Host "Please download and extract the artifact from GitHub Actions first." -ForegroundColor Yellow
    exit 1
}

# Check ADB
try {
    $null = adb version
} catch {
    Write-Host "ERROR: adb not found. Please install Android SDK Platform Tools." -ForegroundColor Red
    exit 1
}

# Connect to device
Write-Host "Connecting to device $DeviceSerial..." -ForegroundColor Yellow
adb connect $DeviceSerial
Start-Sleep -Seconds 2

# Verify device
Write-Host "Verifying device..." -ForegroundColor Yellow
$device = adb -s $DeviceSerial shell getprop ro.product.device 2>&1
if ($device -notmatch "pine") {
    Write-Host "WARNING: Device codename is '$device', expected 'pine'" -ForegroundColor Yellow
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne "y") {
        exit 1
    }
}

# Check root
Write-Host "Checking root access..." -ForegroundColor Yellow
$rootCheck = adb -s $DeviceSerial shell "$RootSu -c 'id'" 2>&1
if ($rootCheck -notmatch "uid=0") {
    Write-Host "ERROR: Root access not available via $RootSu" -ForegroundColor Red
    Write-Host "Output: $rootCheck" -ForegroundColor Gray
    exit 1
}
Write-Host "Root access confirmed." -ForegroundColor Green

# Find APEX files
$apexFiles = Get-ChildItem "$ArtifactDir/files" -Filter "*.apex" -File
if ($apexFiles.Count -eq 0) {
    Write-Host "ERROR: No APEX files found in $ArtifactDir/files/" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Found $($apexFiles.Count) APEX file(s):" -ForegroundColor Green
foreach ($apex in $apexFiles) {
    $sizeMB = [math]::Round($apex.Length / 1MB, 2)
    Write-Host "  - $($apex.Name) ($sizeMB MB)" -ForegroundColor White
}

# Create /data/temp directories first
Write-Host ""
Write-Host "Creating /data/temp dump directories..." -ForegroundColor Yellow
adb -s $DeviceSerial shell "$RootSu -c 'mkdir -p /data/temp/pine-art-dumps /data/temp/pine-crypto-dumps'"
adb -s $DeviceSerial shell "$RootSu -c 'chmod 0777 /data/temp'"
adb -s $DeviceSerial shell "$RootSu -c 'chmod 0777 /data/temp/pine-art-dumps'"
adb -s $DeviceSerial shell "$RootSu -c 'chmod 0777 /data/temp/pine-crypto-dumps'"

$tempCheck = adb -s $DeviceSerial shell "$RootSu -c 'ls -ld /data/temp /data/temp/pine-art-dumps /data/temp/pine-crypto-dumps'" 2>&1
Write-Host $tempCheck -ForegroundColor Gray

# Confirm installation
Write-Host ""
Write-Host "Ready to install ART hot update." -ForegroundColor Yellow
Write-Host "This will:" -ForegroundColor Yellow
Write-Host "  1. Push APEX files to /data/local/tmp/" -ForegroundColor White
Write-Host "  2. Stage them for activation on next boot" -ForegroundColor White
Write-Host "  3. Require a reboot to take effect" -ForegroundColor White
Write-Host ""
$response = Read-Host "Proceed with installation? (y/N)"
if ($response -ne "y") {
    Write-Host "Installation cancelled." -ForegroundColor Yellow
    exit 0
}

# Push APEX files
Write-Host ""
Write-Host "Pushing APEX files to device..." -ForegroundColor Yellow
foreach ($apex in $apexFiles) {
    Write-Host "  Pushing $($apex.Name)..." -ForegroundColor White
    adb -s $DeviceSerial push "$($apex.FullName)" "/data/local/tmp/$($apex.Name)"
}

# Stage APEX via adb install
Write-Host ""
Write-Host "Staging APEX modules..." -ForegroundColor Yellow
foreach ($apex in $apexFiles) {
    Write-Host "  Staging $($apex.Name)..." -ForegroundColor White
    $stagePath = "/data/local/tmp/$($apex.Name)"

    # Try adb install --staged for APEX
    $installOutput = adb -s $DeviceSerial install --staged $stagePath 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    Staged successfully." -ForegroundColor Green
    } else {
        Write-Host "    WARNING: Staging may have failed." -ForegroundColor Yellow
        Write-Host "    Output: $installOutput" -ForegroundColor Gray
        Write-Host "    You may need to manually activate via 'adb shell pm install-staged' or reboot." -ForegroundColor Yellow
    }
}

# Enable DEX dump
Write-Host ""
Write-Host "Enabling DEX dump for testing..." -ForegroundColor Yellow
adb -s $DeviceSerial shell setprop persist.sys.pine_art_dexdump true
Write-Host "  persist.sys.pine_art_dexdump = true" -ForegroundColor Green
adb -s $DeviceSerial shell "$RootSu -c 'touch /data/temp/pine-crypto-dump.enable'"
Write-Host "  /data/temp/pine-crypto-dump.enable created" -ForegroundColor Green

# Installation summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Reboot device: adb reboot" -ForegroundColor White
Write-Host "  2. Reconnect: adb connect $DeviceSerial" -ForegroundColor White
Write-Host "  3. Test dump:" -ForegroundColor White
Write-Host "       adb shell monkey -p com.android.settings 1" -ForegroundColor Gray
Write-Host "       adb shell su -c 'ls -lR /data/temp/pine-art-dumps/'" -ForegroundColor Gray
Write-Host "       adb shell su -c 'find /data/temp/pine-crypto-dumps -maxdepth 3 -type f -print'" -ForegroundColor Gray
Write-Host "  4. Check logs:" -ForegroundColor White
Write-Host "       adb logcat -d | grep 'pine ART dexdump'" -ForegroundColor Gray
Write-Host ""

# Cleanup temp files
Write-Host "Cleaning up..." -ForegroundColor Yellow
foreach ($apex in $apexFiles) {
    adb -s $DeviceSerial shell rm -f "/data/local/tmp/$($apex.Name)" 2>&1 | Out-Null
}

Write-Host "Done! Ready to reboot." -ForegroundColor Green
