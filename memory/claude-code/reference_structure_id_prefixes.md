---
name: Structure ID prefixes — s/tc/b
description: Stations=s001, traffic circles=tc001, barriers=b001. All lowercase 3-digit. Barriers serialized for safety inspection. Pre-placed, removed by users, IDs at Build.
type: reference
---

Structure IDs use type-based prefixes, all lowercase:
- **s001, s002...** — stations (parking, line_end, thru_dip)
- **tc001, tc002...** — traffic circles
- **b001, b002...** — barriers (cpb)

Barriers are serialized because they are subject to barrier inspection to assure guideway safety. Every barrier must be individually identifiable for inspection records.

Barriers are pre-placed on all station models — users remove them to open CPs, not add them. Barrier IDs are assigned at Build time, not at placement.

Code: `jpod_structure_tool.rb` `next_structure_id(model, model_id:)`
