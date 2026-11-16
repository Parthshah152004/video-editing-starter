# Setting up the Video Editing Starter

## First time (30-90 minutes, mostly downloads)

1. Install **Adobe Premiere Pro, After Effects, Media Encoder** and the **Claude desktop app**.
   Sign in to both yourself.
2. Download the starter. In PowerShell:
   ```
   winget install --id Git.Git -e
   git clone https://github.com/Parthshah152004/video-editing-starter.git "$HOME\Desktop\Video Editing Starter"
   ```
   (Use `git clone`, not "Download ZIP": the clone is what lets updates arrive by themselves.)
3. Run the setup:
   ```
   cd "$HOME\Desktop\Video Editing Starter"
   powershell -ExecutionPolicy Bypass -File .\kit\setup.ps1
   ```
   It installs the free tools, the Premiere/AE connectors and panels, writes `.mcp.json`, installs
   the local AI tools if the PC has an NVIDIA GPU (about 25 GB; `-SkipBig` leaves out the 9 GB
   upscaler model, `-SkipAI` skips them all) and turns on auto-update at every login.
4. Do the steps it prints at the end (two Adobe settings, open the two panels).
5. Open the folder in Claude Code and start with your first video. Tell it your style as you go;
   it writes it into `STYLE.md`.

## Updates
Updates to the starter download by themselves at every login (or run `kit\update.ps1`). Your own
changes (your `STYLE.md`, your jobs) stay on your PC and are kept when updates arrive. To keep your
own online backup, fork the repo on GitHub and point your copy at your fork.

## Auto-update
A "Video Kit Auto-Update" shortcut in the Windows Startup folder. It only fast-forwards, never
overwrites your work. Log: `%LOCALAPPDATA%\VideoKit\autoupdate.log`. Turn off with
`kit\install-autoupdate.ps1 -Remove`.

## Licences
See `THIRD_PARTY_NOTICES.md`.
