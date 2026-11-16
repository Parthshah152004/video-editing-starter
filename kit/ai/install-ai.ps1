# Installs the local AI tools exactly as they are on the home PC. Safe to re-run: anything that
# already works is skipped. Called by kit\setup.ps1; can also be run on its own:
#   powershell -ExecutionPolicy Bypass -File .\kit\ai\install-ai.ps1
# Options:
#   -Only whisperx,demucs,...   install just these (names below)
#   -SkipBig                    skip the 9 GB SeedVR2 model download
#   -Root <folder>              where to install (default %USERPROFILE%\.cache\video-editor)
#
# Names: whisperx demucs matting gaze gradio kokoro matanyone rife blender facemodel seedvr2
#   -IgnoreComfy                install SeedVR2 standalone even if ComfyUI Desktop has it (for testing)
param([string[]]$Only = @(), [switch]$SkipBig, [switch]$IgnoreComfy, [string]$Root = (Join-Path $env:USERPROFILE ".cache\video-editor"))

$ErrorActionPreference = "Continue"
$Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$env:PYTHONUTF8 = "1"
$env:HF_HUB_DISABLE_SYMLINKS = "1"
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$Req = Join-Path $PSScriptRoot "requirements"
New-Item -ItemType Directory -Force $Root | Out-Null
$results = [ordered]@{}
function Want($n) { ($Only.Count -eq 0) -or ($Only -contains $n) }
function Say($t) { Write-Host "`n--- $t" -ForegroundColor Cyan }

# ---- GPU check ---------------------------------------------------------------
$gpus = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object Name) -join ", "
$hasNvidia = $gpus -match "NVIDIA"
Write-Host "GPU(s): $gpus"
if (-not $hasNvidia) { Write-Host "No NVIDIA GPU: skipping the CUDA tools (WhisperX, Demucs, cut-out, SeedVR2). The rest still installs." -ForegroundColor Yellow }

# ---- Python 3.11 via uv ------------------------------------------------------
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
  winget install --id astral-sh.uv -e --source winget --accept-package-agreements --accept-source-agreements --silent | Out-Host
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
}
$py311 = (uv python find 3.11 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $py311) { uv python install 3.11 | Out-Host; $py311 = (uv python find 3.11) }
Write-Host "Python 3.11: $py311"

function Get-File($url, $dst) {
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  if (Test-Path $dst) { return $true }
  Write-Host "  downloading $url"
  curl.exe -L --fail --retry 3 -o "$dst.part" $url
  if ($LASTEXITCODE -ne 0) { Remove-Item "$dst.part" -ErrorAction SilentlyContinue; return $false }
  Move-Item "$dst.part" $dst -Force; return $true
}

# Venv from a frozen package list. CUDA builds come from the PyTorch index for the given CUDA tag.
function New-Venv($name, $cuda, $check) {
  $venv = Join-Path $Root "$name-venv"; $vpy = Join-Path $venv "Scripts\python.exe"
  if (Test-Path $vpy) {
    $null = & $vpy -c $check 2>$null
    if ($LASTEXITCODE -eq 0) { $results[$name] = "already installed"; return }
  }
  Say "$name venv"
  if (-not (Test-Path $vpy)) { uv venv $venv --python $py311 | Out-Host }
  $uvArgs = @("pip", "install", "--python", $vpy, "-r", (Join-Path $Req "$name.txt"), "--index-strategy", "unsafe-best-match")
  if ($cuda) { $uvArgs += @("--extra-index-url", "https://download.pytorch.org/whl/$cuda") }
  & uv @uvArgs | Out-Host
  $out = & $vpy -c $check 2>&1
  $results[$name] = if ($LASTEXITCODE -eq 0) { "OK  $out" } else { "FAILED  $out" }
}

$torchCheck = "import torch;print(torch.__version__, 'cuda' if torch.cuda.is_available() else 'NO-CUDA')"

if ($hasNvidia) {
  if (Want "whisperx") { New-Venv "whisperx" "cu128" "import whisperx, torch;print('whisperx', torch.__version__, 'cuda' if torch.cuda.is_available() else 'NO-CUDA')" }
  if (Want "demucs")   { New-Venv "demucs"   "cu128" "import demucs, beat_this, torch;print('demucs+beat_this', torch.__version__, 'cuda' if torch.cuda.is_available() else 'NO-CUDA')" }
  if (Want "matting")  { New-Venv "matting"  "cu128" $torchCheck }
}
if (Want "gaze")   { New-Venv "gaze"   $null "import mediapipe, cv2;print('mediapipe', mediapipe.__version__)" }
if (Want "gradio") { New-Venv "gradio" $null "import gradio_client;print('gradio_client ok')" }
if (Want "kokoro") { New-Venv "kokoro" $null "import kokoro;print('kokoro', kokoro.__version__)" }

# ---- MatAnyone 2 (cut-out), pinned to the home PC's commit -----------------
if ($hasNvidia -and (Want "matanyone")) {
  $d = Join-Path $Root "MatAnyone2"
  if (-not (Test-Path (Join-Path $d ".git"))) {
    Say "MatAnyone2"
    git clone -q https://github.com/pq-yang/MatAnyone2 $d
    git -C $d checkout -q 0079197acd6d16a741f71558809c06c586c579e0
  }
  $results["matanyone"] = if (Test-Path (Join-Path $d ".git")) { "OK" } else { "FAILED" }
}

# ---- RIFE (slow-mo frame interpolation, Vulkan: any GPU) --------------------
if (Want "rife") {
  $exe = Join-Path $Root "rife\bin\rife-ncnn-vulkan-20221029-windows\rife-ncnn-vulkan.exe"
  if (-not (Test-Path $exe)) {
    Say "RIFE"
    $zip = Join-Path $Root "rife\dl\rife.zip"
    if (Get-File "https://github.com/nihui/rife-ncnn-vulkan/releases/download/20221029/rife-ncnn-vulkan-20221029-windows.zip" $zip) {
      Expand-Archive $zip (Join-Path $Root "rife\bin") -Force
    }
  }
  $results["rife"] = if (Test-Path $exe) { "OK  $exe" } else { "FAILED" }
}

# ---- Blender 4.5.12 portable -------------------------------------------------
if (Want "blender") {
  $exe = Join-Path $Root "blender\blender-4.5.12-windows-x64\blender.exe"
  if (-not (Test-Path $exe)) {
    Say "Blender 4.5.12 portable"
    $zip = Join-Path $Root "blender_dl\blender.zip"
    if (Get-File "https://download.blender.org/release/Blender4.5/blender-4.5.12-windows-x64.zip" $zip) {
      Expand-Archive $zip (Join-Path $Root "blender") -Force
    }
  }
  $results["blender"] = if (Test-Path $exe) { "OK  $exe" } else { "FAILED" }
}

# ---- MediaPipe face model (gaze / face-safe zones) --------------------------
if (Want "facemodel") {
  $f = Join-Path $Root "gaze-models\face_landmarker.task"
  $ok = Get-File "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task" $f
  $results["facemodel"] = if ($ok) { "OK  $f" } else { "FAILED" }
}

# ---- SeedVR2 7B upscaler (standing upscale rule) ------------------------------
# Home PC runs it inside ComfyUI Desktop. Elsewhere it is installed standalone (same node, same
# model, same CLI) at <Root>\SeedVR2 with its own venv.
if ($hasNvidia -and (Want "seedvr2")) {
  $comfyNode = Join-Path $env:LOCALAPPDATA "Comfy-Desktop\ComfyUI-Installs\Comfy UI\ComfyUI\custom_nodes\ComfyUI-SeedVR2_VideoUpscaler"
  if ((Test-Path $comfyNode) -and -not $IgnoreComfy) {
    $results["seedvr2"] = "already installed in ComfyUI Desktop"
  } else {
    Say "SeedVR2 (standalone)"
    $node = Join-Path $Root "SeedVR2"
    if (-not (Test-Path (Join-Path $node ".git"))) {
      git clone -q https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git $node
      git -C $node checkout -q 4490bd1f482e026674543386bb2a4d176da245b9
    }
    New-Venv "seedvr2" "cu130" "import torch, diffusers, peft;print('seedvr2 deps', torch.__version__, 'cuda' if torch.cuda.is_available() else 'NO-CUDA')"
    $models = Join-Path $node "models\SEEDVR2"
    if (-not $SkipBig) {
      $a = Get-File "https://huggingface.co/AInVFX/SeedVR2_comfyUI/resolve/main/seedvr2_ema_7b_sharp_fp8_e4m3fn_mixed_block35_fp16.safetensors" (Join-Path $models "seedvr2_ema_7b_sharp_fp8_e4m3fn_mixed_block35_fp16.safetensors")
      $b = Get-File "https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/ema_vae_fp16.safetensors" (Join-Path $models "ema_vae_fp16.safetensors")
      $results["seedvr2"] = "$($results['seedvr2']) | models: " + $(if ($a -and $b) { "OK  $models" } else { "FAILED" })
    } else { $results["seedvr2"] = "$($results['seedvr2']) | models skipped (-SkipBig)" }
  }
}

# ---- Summary -------------------------------------------------------------------
Write-Host "`n=== AI tools ===" -ForegroundColor Green
$results.GetEnumerator() | ForEach-Object { "{0,-10} {1}" -f $_.Key, $_.Value } | Out-Host
$summary = "AI tools installed $(Get-Date -Format 'yyyy-MM-dd HH:mm') on $env:COMPUTERNAME (GPU: $gpus)`n" + (($results.GetEnumerator() | ForEach-Object { "- $($_.Key): $($_.Value)" }) -join "`n")
[IO.File]::WriteAllText((Join-Path $Root "INSTALLED.txt"), $summary)
