# tools/lock-start.ps1 - claim the edit lock for a Sysmac project (PowerShell 5 safe)
#
# Usage:  .\tools\lock-start.ps1 -Note "adding conveyor stop rung"
#
# Pulls first so the lock check sees what teammates already pushed, writes
# locks/<Project>.lock, commits and pushes it, then posts [LOCK] to Teams.
param(
  [Parameter(Mandatory = $true)][string]$Note,
  [string]$Project = "SyncAlert",
  [string]$LocksPath = "locks",
  [string]$User = $env:USERNAME,
  [string]$Branch
)

# Resolve branch name if not provided
if (-not $Branch) { $Branch = (git branch --show-current).Trim() }

# Get the latest locks before checking. Without this, two people can both
# see "no lock" locally and claim the project at the same time.
git pull --ff-only 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Warning "Could not pull latest changes (no upstream yet, or offline). Lock check uses local state only."
}

# Basic identifiers
$HostName = $env:COMPUTERNAME
$LockFile = Join-Path $LocksPath "$Project.lock"

# Prevent multiple editors at once
if (Test-Path $LockFile) {
  $existing = Get-Content $LockFile -Raw | ConvertFrom-Json
  Write-Error "Lock already held by $($existing.user) on $($existing.host) since $($existing.start) ($($existing.note))."
  exit 1
}

# Create lock metadata
New-Item -ItemType Directory -Force -Path $LocksPath | Out-Null
$now = (Get-Date).ToString("o")
$lock = [pscustomobject]@{
  project = $Project
  user    = $User
  host    = $HostName
  branch  = $Branch
  start   = $now
  note    = $Note
}
$lock | ConvertTo-Json -Depth 3 | Out-File -Encoding UTF8 $LockFile

# --- Commit and push ---
git add $LockFile
git commit -m "chore(lock): $Project held by $User ($Note)"
if ($LASTEXITCODE -ne 0) { Write-Error "git commit failed; lock not taken."; exit 1 }

# Does this branch track a remote yet? Native commands don't throw in
# PowerShell, so check the exit code instead of using try/catch.
git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null | Out-Null
$hasUpstream = ($LASTEXITCODE -eq 0)

if ($hasUpstream) { git push } else { git push -u origin $Branch }

if ($LASTEXITCODE -ne 0) {
  # Most likely someone else pushed a lock first. Undo ours so we don't
  # announce a lock the team never saw.
  git reset --hard HEAD~1 | Out-Null
  Write-Error "Push failed (someone may have taken the lock first). Run again after 'git pull'."
  exit 1
}

# --- Teams notify (simple text payload) ---
$Webhook = $env:SYNCALERT_WEBHOOK
if ([string]::IsNullOrWhiteSpace($Webhook)) {
  Write-Warning "SYNCALERT_WEBHOOK not set; skipping Teams post."
  exit 0
}

$payload = @{
  text = "[LOCK] $Project locked by $User on $HostName | Branch: $Branch | Note: $Note | Time: $now"
} | ConvertTo-Json

try {
  # Force TLS 1.2 for older PowerShell
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-RestMethod -Uri $Webhook -Method Post -Body $payload -ContentType 'application/json' | Out-Null
  Write-Host "Lock file committed and Teams notified."
} catch {
  Write-Warning ("Teams post failed: " + $_.Exception.Message)
}
