---
name: MeshMobility keyboard shortcuts
description: Keys 1-6 for placement; collapsible palette; closest-CP connect; save handle; dead end/orphan highlighting
type: reference
---

Placement shortcuts (disabled in input fields):
1=Station N-S, 2=E-W, 3=NW-SE, 4=NE-SW, 5=Circle, 6=Circle 45°
Press key, click map to place. Esc to cancel.

UI features built 2026-07-05:
- Closest-open-CP connect: click any CP on struct A, any on struct B → system finds nearest pair
- Save remembers file handle (App._saveHandle), cleared on New, set on Open
- Unsaved changes warning on New/Open (App._dirty flag)
- Flash messages: flashWarning() yellow, flashSuccess() green — replace blocking alerts
- Alt+drag suppression: 300ms window after drag-end prevents accidental CP selection
- Collapsible palette sections: click label to toggle
- Dead ends (yellow dashed) + orphans (green dashed) shown on Run
- Full docs: mesh_mobility/readmes/keyboard-shortcuts.md
