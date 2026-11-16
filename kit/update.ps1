# Get the latest of ALL backed-up folders from GitHub (what you saved on the other PC).
# Folders missing on this PC are downloaded. Run at the START of a work session:
#   powershell -ExecutionPolicy Bypass -File .\kit\update.ps1
# -Auto: quiet mode used by the login shortcut (kit\install-autoupdate.ps1). Waits for the internet,
#        only fast-forwards (never merges or rewrites anything), logs to
#        %LOCALAPPDATA%\VideoKit\autoupdate.log and shows one message only if something needs you.
param([switch]$Auto)
. (Join-Path $PSScriptRoot "common.ps1")
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

$LogDir = Join-Path $env:LOCALAPPDATA "VideoKit"; New-Item -ItemType Directory -Force $LogDir | Out-Null
$Log = Join-Path $LogDir "autoupdate.log"
$problems = @()
function Out-Line($t, $color = "Gray") {
  if ($Auto) { Add-Content -Path $Log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $t" -Encoding UTF8 } else { Write-Host $t -ForegroundColor $color }
}

if ($Auto) {
  # wait up to 3 minutes for the network after login
  $deadline = (Get-Date).AddMinutes(3)
  while ((Get-Date) -lt $deadline) {
    git ls-remote -q https://github.com/git/git.git HEAD 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 10
  }
  Out-Line "---- auto-update start ($env:COMPUTERNAME)"
}

foreach ($r in Get-KitRepos) {
  if (Test-Path (Join-Path $r.Path ".git")) {
    Push-Location $r.Path
    try {
      if ($Auto) { $out = git pull --ff-only --autostash -q 2>&1 } else { $out = git pull --rebase --autostash -q 2>&1 }
      if ($LASTEXITCODE -eq 0) { Out-Line "  updated    $($r.Name)" Green }
      else { Out-Line "  PROBLEM    $($r.Name): $out" Yellow; $problems += $r.Name }
    } finally { Pop-Location }
  } elseif (Test-Path $r.Path) {
    Out-Line "  CHECK      $($r.Name): '$($r.Path)' exists but is not a git folder; left alone" Yellow
    $problems += $r.Name
  } elseif (-not (Test-RepoAccess "$($r.Owner)/$($r.Name)")) {
    Out-Line "  skip       $($r.Name) (not shared with this GitHub account)"
  } else {
    & $Gh repo clone "$($r.Owner)/$($r.Name)" "$($r.Path)" -- -q 2>&1 | Out-Null
    if (Test-Path (Join-Path $r.Path ".git")) { Out-Line "  downloaded $($r.Name) -> $($r.Path)" Green }
    else { Out-Line "  PROBLEM    could not download $($r.Name)" Yellow; $problems += $r.Name }
  }
}

# Put the updated memory into Claude's memory folders on this PC (newer files win)
Restore-AllMemory
Out-Line "Memory restored. Done." Green

if ($Auto -and $problems.Count -gt 0) {
  Add-Type -AssemblyName System.Windows.Forms
  [System.Windows.Forms.MessageBox]::Show(
    "Auto-update could not update: $($problems -join ', ').`n`nBoth PCs probably changed the same folder. Open Claude in the Video Editing Starter Kit folder and say 'update the kit' to sort it out.`n`nLog: $Log",
    "Video kit auto-update") | Out-Null
}
