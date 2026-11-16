# Video editing project

FIRST read `TOOLING.md`. It covers the tools, the Premiere / After Effects connectors and how this
folder is laid out (technical only).

THEN read `STYLE.md`. It is the editor's own style and order of work. It starts empty: where it is
silent, ask the editor; never invent a style. When the editor gives style instructions, references or
feedback, write them into `STYLE.md` so they apply to every later video.

Working rules:
- Never touch original footage. Copy it into `jobs/<job>/raw/` and work there.
- Work only in a NEW, empty Premiere / After Effects project, never one holding other work.
- One approval gate: show the plan (shot or cut list) and wait for a yes, then run through to export.
- Captions and on-screen text come only from the transcript or the editor's own words. Proof-read them.
- Never change security settings. Give the editor the exact click path and let them do it.
- Ask before spending money, creating accounts or anything outward-facing.
- Review the whole export yourself (frames, text crops, transitions) before handing it over, and give
  the full file path of every deliverable.

`kit/SETUP.md` explains setup on a new PC. "save the kit" runs `kit\save.ps1`, "update the kit" runs
`kit\update.ps1`.
