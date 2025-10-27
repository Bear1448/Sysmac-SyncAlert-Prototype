# tools/lock-end.ps1 — minimal version (PowerShell 5 safe, auto-upstream push)
param(
  [string]$Project = "SyncAlert",
  [string]$LocksPath = "locks",
  [string]$Summary = ""
)

# Paths
$LockFile = Join-Path $LocksPath "$Project.lock"

# Guard: require an existing lock
if (-not (Test-Path $LockFile)) {
  Write-Error "No lock file found for '$Project' at $LockFile."
  exit 1
}

# Remove the lock file
Remove-Item $LockFile -Force

# --- Commit and smart push ---
git add $LockFile
git commit -m "chore(lock): $Project released ($Summary)"

# Auto-detect upstream like in lock-start.ps1
$curr = (git branch --show-current).Trim()
$hasUpstream = $false
try {
    & git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null
    $hasUpstream = $true
} catch {}

if ($hasUpstream) { git push } else { git push -u origin $curr }

# --- Teams notify (simple text payload) ---
$Webhook = $env:SYNCALERT_WEBHOOK
if ([string]::IsNullOrWhiteSpace($Webhook)) {
  Write-Warning "SYNCALERT_WEBHOOK not set; skipping Teams post."
  exit 0
}

$now = (Get-Date).ToString("o")
$payload = @{ 
  text = "[UNLOCK] $Project lock released | Summary: $Summary | Time: $now" 
} | ConvertTo-Json

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-RestMethod -Uri $Webhook -Method Post -Body $payload -ContentType 'application/json'
  Write-Host "✅ Lock released and Teams notified."
} catch {
  Write-Warning ("Teams post failed: " + $_.Exception.Message)
}
