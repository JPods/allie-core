# Compute Pipeline v2

One button. Three phases. Math only.

## Files

| File | Phase | Responsibility |
|------|-------|---------------|
| `compute.rb` | — | Orchestrator — calls phases in sequence |
| `compute_validator.rb` | 1 | Validate designer section of lines.json |
| `compute_chain_builder.rb` | 2 | Build Natalie/Noelle chains from successor graph |
| `compute_geometry.rb` | 3 | Extract geometry from CP markers + chain-walk |
| `compute_writer.rb` | — | Write lines.computed.json |

## Design Documents

- `phase1_validation.md` — what is checked, what causes rejection
- `phase2_chain_building.md` — how chains are derived from topology
- `phase3_geometry.md` — how geometry is computed from math

## Principles

1. The designer owns the topology (tracks, successors, CPs)
2. The agents derive the behavior (chains, routing, slots)
3. Compute connects them through math
4. If it can't be computed, reject — don't degrade
5. No edge walking. No hand-authored chains. No entity attributes as geometry source.
