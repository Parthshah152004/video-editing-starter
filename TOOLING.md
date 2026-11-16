# Tooling

Technical setup only. Installed by `kit\setup.ps1` (see `kit/SETUP.md`).

## The PC
- Windows 10/11, PowerShell 5.1 and Git Bash. PowerShell 5.1 has no `&&` / `||`; avoid `2>&1` on
  native programs. Refresh PATH after installs:
  `$env:Path=[Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')`
- Installed by setup: Git, GitHub CLI, Node LTS, ffmpeg/ffprobe, uv (Python 3.11), yt-dlp, Deno.
- Adobe Premiere Pro, After Effects and Media Encoder are installed by the editor.

## Local AI tools (`kit\ai\install-ai.ps1`, NVIDIA GPU only for the CUDA ones)
All in `%USERPROFILE%\.cache\video-editor\`; `INSTALLED.txt` there says what this PC has.

| Tool | Folder | Use |
|---|---|---|
| WhisperX | `whisperx-venv` | transcripts with word timings |
| Demucs + Beat This | `demucs-venv` | split voice from music, detect beats |
| BiRefNet / MatAnyone 2 | `matting-venv`, `MatAnyone2` | subject cut-outs |
| MediaPipe | `gaze-venv`, `gaze-models` | face and gaze detection |
| Kokoro | `kokoro-venv` | scratch text-to-speech |
| RIFE ncnn-vulkan | `rife\bin\...` | frame interpolation |
| Blender 4.5 portable | `blender\...` | 3D |
| SeedVR2 7B | `SeedVR2`, `seedvr2-venv` | generative upscaling (`inference_cli.py`) |

Run Python tools with the venv's own `Scripts\python.exe`, with `PYTHONUTF8=1`.
`scripts\transcribe.py` is a basic WhisperX wrapper.

## Premiere Pro connector (`premiere-pro`)
- Server in `kit\vendor\premiere-mcp-lean`, registered in `.mcp.json` (written by setup).
- Works through a panel inside Premiere: open a NEW empty project, then Window > Extensions >
  MCP Bridge (CEP). Needs `PlayerDebugMode` (setup prints the command; the editor runs it).
- Tools load on demand: search them with ToolSearch, start with `get_capabilities`, check the
  connection with `ping` / `verify_premiere_connection`.
- Re-read clip and sequence IDs after every change; make cuts as real trimmable clips.

## After Effects connectors (`after-effects`, `aftereffects-kumo`)
- Panel: Window > `mcp-bridge-auto.jsx`, tick "Auto-run commands". Needs the AE preference
  "Allow Scripts to Write Files and Access Network" (the editor ticks it).
- Always a new, empty AE project.

## HyperFrames (HTML to MP4 graphics)
- Skills in `.claude\skills\` (`/hyperframes` first). Renders with Chrome; good for titles,
  captions and motion graphics without Adobe.

## Helpers
- `scripts\page_shot.mjs <url> <out.png>`: screenshot of a web page (headless Chrome).
- `scripts\ui.ps1`, `scripts\ui_drive.ps1`: screenshot / click / type on the desktop.
- `.claude\skills\watch`: watch a video file or link and answer questions about it.

## Folder map
`jobs/<job>/` = `raw transcript plan build out` | `assets/fonts` | `presets/` | `scripts/` |
`kit/` (setup, connectors, AI installer, sync scripts).
