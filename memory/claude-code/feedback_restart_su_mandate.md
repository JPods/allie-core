---
name: Mandate SketchUp restart when needed
description: Don't hesitate to tell Bill to restart SketchUp — the JS/HTML console dialog doesn't always adapt to reloads. Say "restart SU" directly, don't suggest "reload plugin."
type: feedback
---

Don't hesitate to mandate restarting SketchUp. The HTML dialog (jpod_console) doesn't always pick up changes on plugin reload — especially JS/CSS changes, dialog state, and sometimes Ruby module redefinitions.

**Why:** Bill said "Do not hesitate to mandate restarting su. The js html sometimes is not very adaptive." Reload works for pure Ruby changes. Restart is needed when: HTML dialog content changed, new .rb files added to boot.rb, module structure changed (new modules replacing old ones), or console behavior seems stale.

**How to apply:** When making changes that touch HTML dialogs, add new files, or restructure modules, say "Restart SU" not "reload su_jpods." Be direct — don't hedge with "you might need to restart."
