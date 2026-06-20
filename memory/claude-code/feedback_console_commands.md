---
name: Console commands must be letter-perfect
description: Never post literal paths with spaces in console commands. Use Sketchup.find_support_file for SketchUp reloads. Markdown wraps at spaces invisibly.
type: feedback
---

Never post a SketchUp reload command as a literal path. The path `Application Support/SketchUp 2026` contains spaces. Markdown code blocks and backtick formatting introduce extra whitespace at those spaces when rendering long lines. The command looks correct on screen; the terminal receives a broken one. Most users cannot diagnose this.

**Always use:**
```
load Sketchup.find_support_file('jpod_network.rb', 'Plugins/su_jpods')
```

**Why:** No spaces in the argument. No wrapping risk. Works on any machine regardless of SketchUp version or user home directory path.

**How to apply:** Before posting any console command, check whether the command contains spaces that could cause line wrapping. If yes, find an alternative form with no spaces, or use a variable assignment to break it up safely.

**The broader principle:** A command that works on screen but fails in the terminal is worse than no command — it consumes the user's time diagnosing a problem that was never theirs.

**Scar:** `readmes/wisdom/scars.md` — "Console Commands Must Be Letter-Perfect — 2026-05-18"
