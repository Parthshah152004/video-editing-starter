# One-time setup of the Video Editing Starter Kit on a new PC (office, laptop, rebuild).
# Run from the repo folder in PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\kit\setup.ps1
# It installs EVERYTHING by default: tools, MCP servers, Adobe panels, all your folders, Claude's
# memory, the local AI tools (if the PC has an NVIDIA GPU) and auto-update at every login.
# Optional switches:
#   -SkipInstalls    do not install Git/Node/ffmpeg/uv/yt-dlp/GitHub CLI with winget
#   -SkipAI          do not install the local AI tools (kit\ai\install-ai.ps1)
#   -SkipBig         install the AI tools but not the 9 GB SeedVR2 model
#   -NoAutoUpdate    do not add the auto-update-at-login shortcut
param([switch]$SkipInstalls, [switch]$SkipAI, [switch]$SkipBig, [switch]$NoAutoUpdate)

$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
function Step($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Note($t) { Write-Host "  $t" -ForegroundColor Yellow }
function RefreshPath { $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') }

Write-Host "Repo: $Repo"

# 1. Tools ---------------------------------------------------------------------
if (-not $SkipInstalls) {
  Step "1/6 Installing free tools with winget (skips ones already installed)"
  $pkgs = @(
    @{id="Git.Git"; cmd="git"},
    @{id="GitHub.cli"; cmd="gh"},
    @{id="OpenJS.NodeJS.LTS"; cmd="node"},
    @{id="Gyan.FFmpeg"; cmd="ffmpeg"},
    @{id="astral-sh.uv"; cmd="uv"},
    @{id="yt-dlp.yt-dlp"; cmd="yt-dlp"},
    @{id="DenoLand.Deno"; cmd="deno"}
  )
  foreach ($p in $pkgs) {
    RefreshPath
    if (Get-Command $p.cmd -ErrorAction SilentlyContinue) { Write-Host "  ok  $($p.cmd)"; continue }
    Write-Host "  installing $($p.id) ..."
    winget install --id $p.id -e --source winget --accept-package-agreements --accept-source-agreements --silent | Out-Host
  }
  RefreshPath
} else { Step "1/6 Skipping tool installs" ; RefreshPath }

# 2. MCP servers (Premiere / After Effects) -----------------------------------
Step "2/6 Installing MCP server packages (npm ci)"
foreach ($d in "premiere-mcp-lean","after-effects-mcp","mcp-aftereffects-kumo") {
  $dir = Join-Path $Repo "kit\vendor\$d"
  Push-Location $dir
  try {
    Write-Host "  $d"
    # --ignore-scripts: the built JS (dist/, build/) is already in the repo, no rebuild needed
    if (Test-Path package-lock.json) { npm.cmd ci --omit=dev --ignore-scripts --no-audit --no-fund | Out-Host } else { npm.cmd install --omit=dev --ignore-scripts --no-audit --no-fund | Out-Host }
  } finally { Pop-Location }
}

# 3. .mcp.json for THIS pc -----------------------------------------------------
Step "3/6 Writing .mcp.json with this PC's paths"
$v = Join-Path $Repo "kit\vendor"
$mcp = [ordered]@{ mcpServers = [ordered]@{
  "premiere-pro" = [ordered]@{
    command = "node"
    args = @("$v\premiere-mcp-lean\dist\index.js")
    env = [ordered]@{ PREMIERE_TEMP_DIR = (Join-Path $env:TEMP "premiere-mcp-bridge"); PREMIERE_MCP_TELEMETRY = "0" }
    timeout = 600000
  }
  "after-effects" = [ordered]@{ command = "node"; args = @("$v\after-effects-mcp\build\index.js") }
  "aftereffects-kumo" = [ordered]@{
    command = "node"
    args = @("$v\mcp-aftereffects-kumo\node_modules\@kumoproductions\mcp-aftereffects\dist\index.js")
    timeout = 600000
  }
}}
$json = $mcp | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText((Join-Path $Repo ".mcp.json"), $json, (New-Object Text.UTF8Encoding $false))
Write-Host "  wrote $Repo\.mcp.json"

# 4. Adobe bridge panels -------------------------------------------------------
Step "4/6 Installing the Adobe bridge panels"
$cepDst = Join-Path $env:APPDATA "Adobe\CEP\extensions\MCPBridgeCEP"
New-Item -ItemType Directory -Force $cepDst | Out-Null
Copy-Item (Join-Path $Repo "kit\adobe\MCPBridgeCEP\*") $cepDst -Recurse -Force
Write-Host "  Premiere CEP panel -> $cepDst"

$aeDirs = Get-ChildItem "C:\Program Files\Adobe" -Directory -Filter "Adobe After Effects*" -ErrorAction SilentlyContinue
foreach ($ae in $aeDirs) {
  $dst = Join-Path $ae.FullName "Support Files\Scripts\ScriptUI Panels"
  try {
    Copy-Item (Join-Path $Repo "kit\adobe\mcp-bridge-auto.jsx") $dst -Force -ErrorAction Stop
    Write-Host "  AE panel -> $dst"
  } catch {
    Note "Could not write to $dst (needs admin). Copy it yourself from an ADMIN PowerShell:"
    Note "  Copy-Item `"$Repo\kit\adobe\mcp-bridge-auto.jsx`" `"$dst`""
  }
}
if (-not $aeDirs) { Note "After Effects not found in C:\Program Files\Adobe - install it, then re-run this script." }

# 5. Other folders + Claude memory --------------------------------------------
Step "5/6 Downloading your other folders and restoring Claude's memory for every project"
# update.ps1 clones any repo in kit\repos.json that is missing here, then restores all memory
& (Join-Path $PSScriptRoot "update.ps1")

# 6. Local AI tools + auto-update ---------------------------------------------
Step "6/6 Local AI tools (WhisperX, Demucs, cut-out, Kokoro, gaze, RIFE, Blender, SeedVR2) and auto-update"
if (-not $SkipAI) {
  $aiArgs = @{}; if ($SkipBig) { $aiArgs.SkipBig = $true }
  & (Join-Path $PSScriptRoot "ai\install-ai.ps1") @aiArgs
} else { Note "Skipped AI tools (-SkipAI). Run kit\ai\install-ai.ps1 later." }
if (-not $NoAutoUpdate) { & (Join-Path $PSScriptRoot "install-autoupdate.ps1") }

Write-Host "`nDONE. Things only YOU can do (security settings):" -ForegroundColor Green
Write-Host "  a) Let Premiere load unsigned panels (run once in PowerShell):"
Write-Host "       reg add HKCU\Software\Adobe\CSXS.12 /v PlayerDebugMode /t REG_SZ /d 1 /f"
Write-Host "  b) After Effects > Edit > Preferences > Scripting & Expressions > tick 'Allow Scripts to Write Files and Access Network'"
Write-Host "  c) Open Premiere (new empty project) > Window > Extensions > MCP Bridge (CEP)"
Write-Host "     Open After Effects > Window > mcp-bridge-auto.jsx > tick 'Auto-run commands'"
Write-Host "  d) Start Claude Code in: $Repo"
