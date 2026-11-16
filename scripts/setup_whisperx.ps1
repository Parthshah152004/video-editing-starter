# One-time WhisperX environment (shared, reused for every job). Safe to re-run: never recreates an existing venv.
$ErrorActionPreference = 'Continue'
$env:PYTHONUTF8 = '1'
$env:HF_HUB_DISABLE_SYMLINKS = '1'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

$venv = Join-Path $HOME '.cache\video-editor\whisperx-venv'
$vpy  = Join-Path $venv 'Scripts\python.exe'
$py   = (uv python find 3.11)

if (-not (Test-Path $vpy)) {
    "== creating venv at $venv"
    uv venv $venv --python $py
}

"== installing whisperx"
uv pip install --python $vpy whisperx
if ($LASTEXITCODE -ne 0) { "FAILED: whisperx install"; exit 1 }

# PyPI torch on Windows is CPU-only: swap in the CUDA 12.8 build, pinned to the same version whisperx resolved.
$tv = & $vpy -c "import torch;print(torch.__version__.split('+')[0])"
$ta = & $vpy -c "import torchaudio;print(torchaudio.__version__.split('+')[0])"
"== torch $tv / torchaudio $ta -> cu128"
# uv ranks --index above PyPI (and --extra-index-url above --index-url), so the cu128 index must be passed as --index.
uv pip install --python $vpy --force-reinstall "torch==$tv" "torchaudio==$ta" --index https://download.pytorch.org/whl/cu128
if ($LASTEXITCODE -ne 0) { "FAILED: cu128 torch install"; exit 1 }

"== verify"
& $vpy -c "import torch;print('torch', torch.__version__, 'cuda available:', torch.cuda.is_available()); print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU only')"
