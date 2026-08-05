# metadata vs prefs — The Boundary Rule

**Established:** 2026-08-04 by Bill James

## The Rule

Every model with JSON envelope fields (metadata, prefs, config, refs) must respect this boundary:

| Field | What goes in it | Who writes it | Example keys |
|-------|----------------|---------------|--------------|
| **metadata** | Data *about* the record — machine-managed, untyped, variable per record | System, Alice, imports | history, health, flags, source, images, versioning, access, search_log, navigation_log, erosions, zb (validation) |
| **prefs** | How the record's *owner/user* wants things to behave — typed, user-controlled | User, UI, wcuiPrefs.ts | nav, wcui, databrowser, color_mode, gantt, layout, training, userdefined |
| **config** | Structural data the system needs — schema definitions, original import data | System, imports, admin | original_mac, phone_original, schema definitions |
| **refs** | Denormalized relationship caches — links, tags, import tracking | System, sync, Alice | links, tags, import, contact (score-matched) |

## Why This Matters

If preferences mix into metadata, every algorithm that reads metadata for health scoring, search indexing, or pattern detection has to skip user preference keys. If metadata leaks into prefs, the prefs UI shows machine data the user can't understand.

The cost of mixing: silent bugs where a health check flags a user preference as anomalous data, or where a preference reset wipes machine-written history.

## Enforcement

1. **Pydantic schemas** in the `field_access` Setting for each model define which keys are valid in each envelope
2. **Alice** checks on every write: is this key going into the right envelope?
3. **Allie** checks at nightly synthesis: scan for keys in the wrong envelope, flag as FAULT
4. **wcapi save** validates against the schema before writing

## Migration (2026-08-04)

- `metadata.wcui` → `prefs.wcui` (done — wcui_prefs.py updated)
- `metadata.databrowser` → `prefs.databrowser` (done — values copied to prefs)
- Old metadata keys left in place (read migration: check prefs first, fall back to metadata)

## Applies To

All models with JSON envelope fields. Not just Contact — Order, Item, Setting, Project, Action, etc.
