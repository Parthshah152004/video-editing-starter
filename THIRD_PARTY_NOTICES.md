# Third-party software

This starter bundles the following open-source software, unchanged unless noted. Each keeps its own
licence; the full licence texts are in the folders listed (or in `LICENSES/`).

| Component | Folder | Licence | Source |
|---|---|---|---|
| Premiere Pro MCP (lean) + its CEP panel | `kit/vendor/premiere-mcp-lean`, `kit/adobe/MCPBridgeCEP` | MIT (`kit/vendor/premiere-mcp-lean/LICENSE`) | npm `premiere-pro-mcp` |
| After Effects MCP + `mcp-bridge-auto.jsx` panel | `kit/vendor/after-effects-mcp`, `kit/adobe/mcp-bridge-auto.jsx` | MIT (`kit/vendor/after-effects-mcp/LICENSE`) | github.com/Dakkshin/after-effects-mcp |
| @kumoproductions/mcp-aftereffects (installed by npm) | `kit/vendor/mcp-aftereffects-kumo` | MIT | npm `@kumoproductions/mcp-aftereffects` |
| HyperFrames skills, media-use skill | `.claude/skills/hyperframes*`, `.claude/skills/media-use` | Apache-2.0 (`LICENSES/Apache-2.0.txt`) | github.com/heygen-com/hyperframes |
| Watch skill | `.claude/skills/watch` | MIT (`.claude/skills/watch/LICENSE`) | github.com/bradautomates/claude-video |
| Fonts | `assets/fonts` | SIL Open Font License (Google Fonts) | fonts.google.com |

The local AI tools (WhisperX, Demucs, Beat This, BiRefNet, MatAnyone 2, MediaPipe, Kokoro, RIFE,
Blender, SeedVR2) are not included; `kit/ai/install-ai.ps1` downloads them from their official
sources, each under its own licence. MatAnyone 2 is for non-commercial use only.
