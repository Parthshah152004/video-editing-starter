# Makes "update the kit" run by itself, hidden, every time you log in to Windows.
# Adds a shortcut to your Startup folder (no admin needed). Remove it with -Remove.
#   powershell -ExecutionPolicy Bypass -File .\kit\install-autoupdate.ps1
#   powershell -ExecutionPolicy Bypass -File .\kit\install-autoupdate.ps1 -Remove
param([switch]$Remove)
$startup = [Environment]::GetFolderPath("Startup")
$lnk = Join-Path $startup "Video Kit Auto-Update.lnk"

if ($Remove) {
  Remove-Item $lnk -ErrorAction SilentlyContinue
  Write-Host "Auto-update at login turned OFF."
  return
}

$update = Join-Path $PSScriptRoot "update.ps1"
$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut($lnk)
$s.TargetPath = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
$s.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$update`" -Auto"
$s.WorkingDirectory = Split-Path -Parent $PSScriptRoot
$s.WindowStyle = 7
$s.Description = "Gets the latest video kit folders and memory from GitHub at login"
$s.Save()
Write-Host "Auto-update at login turned ON: $lnk" -ForegroundColor Green
Write-Host "Log: $env:LOCALAPPDATA\VideoKit\autoupdate.log"
