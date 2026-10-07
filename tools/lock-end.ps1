# tools/lock-end.ps1 - release the edit lock for a Sysmac project (PowerShell 5 safe)
#
# Usage:  .\tools\lock-end.ps1 -Summary "added conveyor stop rung, tested in sim"
#
# Removes locks/<Project>.lock, commits and pushes, then posts [UNLOCK] to Teams.
param(
  [string]$Summary = "",           # first, so  lock-end.ps1 "summary"  works
  [string]$Project = "SyncAlert",
  [string]$LocksPath = "locks",
  [string]$User = $env:USERNAME,
  [switch]$Force   # release a lock held by someone else (e.g. they went home)
)

$LockFile = Join-Path $LocksPath "$Project.lock"

# Guard: require an existing lock
if (-not (Test-Path $LockFile)) {
  Write-Error "No lock file found for '$Project' at $LockFile."
  exit 1
}

# Guard: only the holder releases, unless -Force
$existing = Get-Content $LockFile -Raw | ConvertFrom-Json
if ($existing.user -ne $User -and -not $Force) {
  Write-Error "Lock is held by $($existing.user), not $User. Use -Force to release it anyway."
  exit 1
}

# Remove the lock file
Remove-Item $LockFile -Force

# --- Commit and push ---
git add $LockFile
git commit -m "chore(lock): $Project released ($Summary)"
if ($LASTEXITCODE -ne 0) { Write-Error "git commit failed; lock not released."; exit 1 }

# Native commands don't throw in PowerShell, so check the exit code
git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null | Out-Null
$hasUpstream = ($LASTEXITCODE -eq 0)

$curr = (git branch --show-current).Trim()
if ($hasUpstream) { git push } else { git push -u origin $curr }

if ($LASTEXITCODE -ne 0) {
  Write-Error "Push failed. The lock is released locally but not on GitHub yet. Pull, then push."
  exit 1
}

# --- Teams notify (simple text payload) ---
$Webhook = $env:SYNCALERT_WEBHOOK
if ([string]::IsNullOrWhiteSpace($Webhook)) {
  Write-Warning "SYNCALERT_WEBHOOK not set; skipping Teams post."
  exit 0
}

$now = (Get-Date).ToString("o")
$payload = @{
  text = "[UNLOCK] $Project lock released by $User | Summary: $Summary | Time: $now"
} | ConvertTo-Json

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-RestMethod -Uri $Webhook -Method Post -Body $payload -ContentType 'application/json' | Out-Null
  Write-Host "Lock released and Teams notified."
} catch {
  Write-Warning ("Teams post failed: " + $_.Exception.Message)
}
