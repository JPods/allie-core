---
name: MeshMobility UI cleanup + path security
description: Left panel simplified; right panel reorg; server-only save; path whitelist (RED flag); Compete button; Report+Isochrone disabled until Run; mobile hamburger/collapse; 10 training features with scripts+quizzes
type: project
---

2026-07-21: Major MeshMobility UI cleanup session.

**Left panel:** Removed Refresh, Reload, Clipboard, CityTool. Added Compete (save+submit to Alice). Report+Isochrone under Simulate, grayed until Run completes.

**Right panel:** Row 1 (Find City, Tools, Overlays, Settings) + Row 2 (CityTool 💰, Regulations, Root Cause). All _blank.

**RED FLAG fixed:** Path validation on all file ops. `_validate_path()` rejects paths outside whitelist. Server-only save — no file picker, no navigation. Filename auto-generated (ST_City_YYYY-MM-DD.jpd), saved to blessed `mesh_mobility_maps/` folder. `os.path.basename()` strips any path components.

**Mobile:** Left palette = hamburger. Right sidebar = slides off-screen, map fills space.

**Training:** 10 features × 3 files (README + script + qa.json) = 30 files, 50 quiz questions. At `route_time/training/`.

**Why:** Clean UI for training videos. Security before deployment. One save path = no confusion.

**How to apply:** On Andi, set ALLOWED_PATHS to user-specific folders. Same validation code, different paths.
