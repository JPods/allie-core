---
name: .config vs sync app tokens
description: Individual tokens (.config in contact record = CarryOn seed) vs machine-to-machine tokens (sync app); sovereignty applied to auth
type: feedback
---

Sync app tokens go between databases (machine-to-machine). .config tokens go to individuals (person-to-machine).

**Why:** Bill distinguishes individual identity from system integration. The user's .config lives inside their WC3 contact metadata — it IS the CarryOn seed. The individual owns their identity, not the platform. This is Desktop Hosting applied to authentication.

**How to apply:** MeshMobility .config stores last_city, last_save_file, overlay prefs in contact metadata. Auth.getConfig(key) / Auth.setConfig(key, value) in auth.js. Server endpoint /api/auth/config. Never put individual tokens in sync app infrastructure.
