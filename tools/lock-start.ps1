# tools/lock-start.ps1 — minimal version (PowerShell 5 safe, auto-upstream push)
param(
  [Parameter(Mandatory = $true)][string]$Note,
  [string]$Project = "SyncAlert",
  [string]$LocksPath = "locks",
  [string]$User = $env:USERNAME,
  [string]$Branch
)

# Resolve branch name if not provided
if (-not $Branch) { $Branch = (git branch --show-current) }

# Basic identifiers
$HostName = $env:COMPUTERNAME
$LockFile = Join-Path $LocksPath "$Project.lock"

# Prevent multiple editors at once
if (Test-Path $LockFile) {
  Write-Error "Lock already exists (see $LockFile)."
  exit 1
}

# Create lock metadata
$now = (Get-Date).ToString("o")
$lock = [pscustomobject]@{
  project = $Project
  user    = $User
  host    = $HostName
  branch  = $Branch
  start   = $now
  note    = $Note
}

# Save JSON file
$lock | ConvertTo-Json -Depth 3 | Out-File -Encoding UTF8 $LockFile

# --- Commit and smart push ---
git add $LockFile
git commit -m "chore(lock): $Project held by $User ($Note)"

# Auto-detect if branch already has an upstream
$curr = (git branch --show-current).Trim()
$hasUpstream = $false
try {
    # the "@{u}" must be quoted so PS doesn't think it's a hashtable
    & git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null
    $hasUpstream = $true
} catch {}

if ($hasUpstream) {
    git push
} else {
    git push -u origin $curr
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
  Invoke-RestMethod -Uri $Webhook -Method Post -Body $payload -ContentType 'application/json'
  Write-Host "✅ Lock file committed and Teams notified."
} catch {
  Write-Warning ("Teams post failed: " + $_.Exception.Message)
}
