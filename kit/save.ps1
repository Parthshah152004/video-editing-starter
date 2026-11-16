# Save everything new in ALL backed-up folders (and Claude's memory for every project) to GitHub.
# Run at the END of a work session on any PC:
#   powershell -ExecutionPolicy Bypass -File .\kit\save.ps1
param([string]$Message = "")
. (Join-Path $PSScriptRoot "common.ps1")

# 1. Copy Claude's memory (all projects) into the kit repo (newer files win).
#    Only the owner's memory is uploaded; anyone else the kit is shared with keeps theirs on their PC
#    (they still RECEIVE the owner's memory through update.ps1).
$owner = Get-KitOwner; $login = Get-GhLogin
if (-not (Test-ShareMemory)) { Write-Host "  memory is never uploaded from this copy" }
elseif ($login -and $owner -and $login -eq $owner) { Backup-AllMemory }
else { Write-Host "  memory not uploaded (signed in to GitHub as '$login', kit owner is '$owner')" }

if (-not $Message) { $Message = "Update from $env:COMPUTERNAME on $(Get-Date -Format 'yyyy-MM-dd HH:mm')" }

# 2. Commit and push every repo
foreach ($r in Get-KitRepos) {
  if (-not (Test-Path (Join-Path $r.Path ".git"))) { Write-Host "  skip  $($r.Name) (not on this PC)"; continue }
  Push-Location $r.Path
  try {
    git add -A
    if (git status --porcelain) {
      git commit -q -m $Message
      git pull --rebase --autostash -q
      git push -q
      Write-Host "  saved $($r.Name)" -ForegroundColor Green
    } else {
      git pull --rebase --autostash -q
      git push -q 2>$null
      Write-Host "  ok    $($r.Name) (nothing new)"
    }
  } finally { Pop-Location }
}
