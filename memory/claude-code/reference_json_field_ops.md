---
name: json_field_ops — surgical JSON updates
description: apps/core/services/json_field_ops.py — apply_json_op() for recursive upsert/merge/append/remove on any JSON field; proven in shell, not yet wired through save_view API path
type: reference
---

`apply_json_op(obj, path, mode, value, key)` — one function for all JSON operations.

Modes: update, merge, upsert, append, remove, delete.
Path syntax: `"config.views"`, `"config.views[name=Bill]"`, `"metadata.flags.reviewed"`.
Handles arrays inside arrays, dicts inside arrays, any depth.

Works perfectly in Django shell (proven with Setting.config.views upsert). NOT yet working through the save_view API — the field loop skips dot-path keys before they reach `apply_json_op`. Debug needed at save_view.py line 570-653.

**How to apply:** File is at `apps/core/services/json_field_ops.py`. Import: `from apps.core.services.json_field_ops import apply_json_op`.
