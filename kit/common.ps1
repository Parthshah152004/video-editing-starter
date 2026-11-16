# Shared helpers for save.ps1 / update.ps1 / setup.ps1 (dot-source this file).
$KitRepo = Split-Path -Parent $PSScriptRoot
$Gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $Gh -and (Test-Path "C:\Program Files\GitHub CLI\gh.exe")) { $Gh = "C:\Program Files\GitHub CLI\gh.exe" }

function Get-KitConfig { Get-Content (Join-Path $PSScriptRoot "repos.json") -Raw | ConvertFrom-Json }
function Get-KitOwner { (Get-KitConfig).owner }
# share_memory=false (the lite starter) means Claude's memory is never uploaded from this copy
function Test-ShareMemory { $c = Get-KitConfig; return -not ($c.PSObject.Properties.Name -contains 'share_memory' -and $c.share_memory -eq $false) }
function Get-GhLogin { if ($Gh) { (& $Gh api user --jq .login 2>$null) } }
# Can this GitHub account see the repo? (people you share one repo with can't see the others)
function Test-RepoAccess($full) { if (-not $Gh) { return $false }; & $Gh repo view $full --json name 2>$null | Out-Null; return ($LASTEXITCODE -eq 0) }

function Get-KitRepos {
  $cfg = Get-Content (Join-Path $PSScriptRoot "repos.json") -Raw | ConvertFrom-Json
  foreach ($r in $cfg.repos) {
    [pscustomobject]@{ Name = $r.name; Owner = $cfg.owner; Path = (Join-Path $env:USERPROFILE $r.path) }
  }
}

# Claude keeps memory per folder in ~/.claude/projects/<folder path with non-letters as '-'>/memory.
# In the repo it is stored without the "C--Users-<name>-" prefix so it works on a PC with another user name.
function Get-HomeSlug { ($env:USERPROFILE -replace '[^A-Za-z0-9]', '-') + '-' }
$MemStore = Join-Path $KitRepo "kit\claude-memory"
$ClaudeProjects = Join-Path $env:USERPROFILE ".claude\projects"

function Backup-AllMemory {
  $homeSlug = Get-HomeSlug
  if (-not (Test-Path $ClaudeProjects)) { return }
  Get-ChildItem $ClaudeProjects -Directory | ForEach-Object {
    $mem = Join-Path $_.FullName "memory"
    if ((Test-Path $mem) -and (Get-ChildItem $mem -File -ErrorAction SilentlyContinue) -and $_.Name.StartsWith($homeSlug)) {
      $key = $_.Name.Substring($homeSlug.Length)
      robocopy $mem (Join-Path $MemStore $key) /E /XO /NFL /NDL /NJH /NJS /NP | Out-Null
    }
  }
}

function Restore-AllMemory {
  $homeSlug = Get-HomeSlug
  if (-not (Test-Path $MemStore)) { return }
  Get-ChildItem $MemStore -Directory | ForEach-Object {
    $dst = Join-Path $ClaudeProjects ($homeSlug + $_.Name + "\memory")
    New-Item -ItemType Directory -Force $dst | Out-Null
    robocopy $_.FullName $dst /E /XO /NFL /NDL /NJH /NJS /NP | Out-Null
  }
}
