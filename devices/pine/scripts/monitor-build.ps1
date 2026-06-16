# Monitor GitHub Actions workflow run status

param(
    [string]$RunId = "",
    [string]$Repo = "00660/pine-art-hotupdate-public-20260615-162321"
)

$ErrorActionPreference = 'Stop'

# Get GitHub token
$cred = "protocol=https`nhost=github.com`n`n" | git credential fill 2>&1
$lines = $cred -split "`r?`n"
$token = (($lines | Where-Object { $_ -like 'password=*' } | Select-Object -First 1) -replace '^password=', '')

if (-not $token) {
    Write-Host "ERROR: Unable to get GitHub token" -ForegroundColor Red
    exit 1
}

$headers = @{
    Authorization = "Bearer $token"
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'pine-build-monitor'
}

# If no run ID provided, get the latest
if (-not $RunId) {
    Write-Host "Fetching latest workflow run..." -ForegroundColor Yellow
    $runs = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Repo/actions/runs?per_page=1"
    if ($runs.workflow_runs.Count -eq 0) {
        Write-Host "ERROR: Could not find any workflow runs" -ForegroundColor Red
        exit 1
    }
    $RunId = $runs.workflow_runs[0].id
    Write-Host "Monitoring run ID: $RunId" -ForegroundColor Green
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Pine ART Hot Update Build Monitor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Repository: $Repo" -ForegroundColor White
Write-Host "Run ID: $RunId" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Monitor loop
$lastStatus = ""
while ($true) {
    try {
        # Fetch run status
        $run = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Repo/actions/runs/$RunId"

        $status = $run.status
        $conclusion = $run.conclusion
        $createdAt = $run.created_at
        $updatedAt = $run.updated_at
        $htmlUrl = $run.html_url

        # Only print if status changed
        if ($status -ne $lastStatus) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Host "[$timestamp] Status: $status" -ForegroundColor Yellow

            if ($conclusion) {
                if ($conclusion -eq "success") {
                    Write-Host "✅ Build completed successfully!" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "Download artifact:" -ForegroundColor White
                    Write-Host "  gh run download $RunId --repo $Repo --name pine-art-hotupdate" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "Or visit:" -ForegroundColor White
                    Write-Host "  $htmlUrl" -ForegroundColor Gray
                    exit 0
                } else {
                    Write-Host "❌ Build failed with conclusion: $conclusion" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "Check logs:" -ForegroundColor White
                    Write-Host "  $htmlUrl" -ForegroundColor Gray
                    exit 1
                }
            } elseif ($status -eq "queued") {
                Write-Host "⏳ Waiting for GitHub runner..." -ForegroundColor Cyan
            } elseif ($status -eq "in_progress") {
                Write-Host "🔵 Build in progress..." -ForegroundColor Blue
                Write-Host "   Watch live: $htmlUrl" -ForegroundColor Gray
            }

            $lastStatus = $status
        }

        # Wait before next check
        Start-Sleep -Seconds 30
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Start-Sleep -Seconds 60
    }
}
