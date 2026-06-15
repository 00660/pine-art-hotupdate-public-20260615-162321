param(
  [string]$Serial = "192.168.2.103:5555",
  [Parameter(Mandatory = $true)]
  [string]$ApexPath,
  [string]$RemoteDir = "/sdcard/pine-art-hotupdate",
  [string]$RootShell = "/debug_ramdisk/su"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ApexPath)) {
  throw "missing APEX: $ApexPath"
}

$fileName = Split-Path -Leaf $ApexPath
$remoteApex = "$RemoteDir/$fileName"

adb connect $Serial | Out-Host
adb -s $Serial wait-for-device
adb -s $Serial shell "mkdir -p '$RemoteDir'"
adb -s $Serial push "$ApexPath" "$remoteApex"

$sha = (Get-FileHash -LiteralPath $ApexPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "LOCAL_SHA256=$sha"
adb -s $Serial shell "ls -l '$remoteApex'; sha256sum '$remoteApex' 2>/dev/null || true"

$install = & adb -s $Serial install --staged --apex "$ApexPath" 2>&1
$installText = $install -join "`n"
Write-Host $installText
if ($LASTEXITCODE -eq 0) {
  Write-Host "STAGED_APEX_OK reboot_required=1"
  exit 0
}

Write-Host "STAGED_APEX_FAILED; trying root remount fallback"
$rootCheck = & adb -s $Serial shell "$RootShell -c id" 2>&1
if ($LASTEXITCODE -ne 0 -or (($rootCheck -join "`n") -notmatch "uid=0")) {
  Write-Host "NO_ROOT_FALLBACK remote_apex=$remoteApex"
  exit 2
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$cmd = @"
set -eu
REMOTE_APEX='$remoteApex'
BACKUP_DIR='/data/local/tmp/pine-art-hotupdate-backup-$stamp'
mkdir -p "`$BACKUP_DIR"
for path in /system/apex/com.android.art.apex /system/apex/com.android.runtime.apex; do
  [ -e "`$path" ] && cp -a "`$path" "`$BACKUP_DIR"/ || true
done
mount -o rw,remount /system || mount -o rw,remount /
cp -f "`$REMOTE_APEX" /system/apex/com.android.art.apex
chmod 0644 /system/apex/com.android.art.apex
chown root:root /system/apex/com.android.art.apex
restorecon /system/apex/com.android.art.apex 2>/dev/null || true
sync
echo "ROOT_REPLACE_OK backup=`$BACKUP_DIR reboot_required=1"
"@

$cmd = $cmd -replace "`r`n", "`n"
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($cmd))
adb -s $Serial shell "echo '$encoded' | base64 -d > /data/local/tmp/pine-art-hotupdate-root.sh"
adb -s $Serial shell "$RootShell -c 'sh /data/local/tmp/pine-art-hotupdate-root.sh'"
