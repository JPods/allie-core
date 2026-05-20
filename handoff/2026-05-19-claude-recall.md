# Claude Recall — 2026-05-19
*Read this before handoff.md. It is your cross-session working memory.*

## Open Arcs (predictions and failures without TFTS closure)

### DNW: 20260518T210721-dnw.md
# DNW — 2026-05-18T21:07:21

test entry — verifying dnw writes to inbox and events.jsonl

### DNW: 20260518T211126-dnw.md
# DNW — 2026-05-18T21:11:26

intent: intent: test dnw with code ref
code:   allie-dnw.sh:1

### DNW: 20260518T211141-dnw.md
# DNW — 2026-05-18T21:11:41

intent: intent: fix tty detection in capture
code:   allie-capture.py:main

### DNW: 20260518T213411-dnw.md
# DNW — 2026-05-18T21:34:11

intent: intent: post SketchUp reload path — line wrapped at space in 'SketchUp 2026', broke the path
code:   display/markdown code block wrapping

### DNW: 20260518T213625-dnw.md
# DNW — 2026-05-18T21:36:25

intent: intent: display SketchUp reload path without extra spaces — both code block and backtick inline added spaces around 'SketchUp 2026'; correct form is to quote the u

### DNW: 20260518T214239-dnw.md
# DNW — 2026-05-18T21:42:39

intent: intent: fix S050.CP0 inverted tangent via avg_outward_tangent guard — guard fires only when inward_ref is also correct; for S050 both avg and inward_ref were inwar

### DNW: 20260518T214659-dnw.md
# DNW — 2026-05-18T21:46:59

intent: intent: post SketchUp load command letter-perfect — code blocks and backticks both introduce extra spaces at 'SketchUp 2026'; most users cannot diagnose this
code:

### DNW: 20260518T234431-dnw.md
# DNW — boot.rb load list vs main.rb load list divergence (recurring)

tried:    assume boot.rb and main.rb stay in sync
result:   third file found missing from boot.rb (jpod_vehicle_anim, jpod_layer_

## From sum-claude-recall (confirmed patterns)
## Confirmed Patterns

*(none yet — first WI cycles needed before confirmation is possible)*

---


## Recent TFTS Principles (pre-loaded for next tx)
- [20260518T230734-tfts.md] Two categories of fix are required when a tag assignment is added to a build pipeline:

## Code Snippet Index (process/snippets/)
*When Bill types tx:, check this index for relevant patterns.*

### PYTHON
- `python-inspect-su-json.md`: # SNIPPET: python-inspect-su-json  # When:    before writing Ruby that consumes SketchUp-generated JSON (map.json, feature.json,  # Why:     The JSON schemas evolved over many sessions. Key naming, ne
### SU
- `su-bezier-arriving-tangent.rb`: # SNIPPET: su-bezier-arriving-tangent  # When:    computing Hermite-to-Bezier control points at the TO (destination) endpoint  # Why:     Hermite terminal tangent = curve velocity at that point.
- `su-cap-pt-tangent-validation.rb`: # SNIPPET: su-cap-pt-tangent-validation  # When:    computing CP tangent direction in scan_stub_pair_tips (jpod_structure_tool.rb)  # Why:     Cluster centroids and bounding-box radial distance both f
- `su-pair-stubs-empty-guard.rb`: # SNIPPET: su-pair-stubs-empty-guard  # When:    any function that aggregates points from a component scan and divides by count  # Why:     Non-station components (terrain tile, Geolocation Content, d
- `su-retag-existing-geometry.rb`: # SNIPPET: su-retag-existing-geometry  # When:    after adding tag assignment to a build pipeline — existing built geometry  # Why:     Without (2), the tag fix is correct but invisible until a full r
- `su-vector3d-multiply.rb`: # SNIPPET: su-vector3d-multiply  # When:    any SketchUp Ruby code that needs to scale a vector  # Why:     Geom::Vector3d has no coerce method — vec * scalar raises ArgumentError at runtime
