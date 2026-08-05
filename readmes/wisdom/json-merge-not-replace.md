# JSON Merge, Not Replace — Scar

## The Scar

Saving a record with a partial `.prefs` object wiped all other prefs keys.
User edits `prefs.budget = 50000`, save sends `prefs: {budget: 50000}`,
backend does `obj.prefs = payload['prefs']`, and `prefs.terms`, `prefs.ship_via`,
everything else — gone.

## The Rule

Any save that touches `.prefs`, `.config`, `.metadata`, or `.refs` must **merge**,
not **replace**. Use `apply_json_op` for surgical updates.

```python
# WRONG — replaces entire prefs
obj.prefs = payload['prefs']

# RIGHT — merges into existing prefs
from apps.core.services.json_field_ops import apply_json_op
apply_json_op(obj, 'prefs', 'merge', payload['prefs'])
```

## Where This Applies

- `save_view.py` — the main wcapi save endpoint
- `transaction_save.py` — transaction-specific save
- Any management command that updates JSON fields
- Any signal handler that modifies refs/metadata

## The React Side

React sends the full nested object after editing. It doesn't know what changed —
it sends the whole `config` or `prefs`. The backend must diff and merge, or use
`apply_json_op` to upsert the changed keys without touching the rest.

## Cost of This Scar

Lost customer preferences, lost shipping defaults, lost qualification data.
Silent — no error, no warning. The data just disappeared on the next save.
