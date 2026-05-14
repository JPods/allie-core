# JPods SketchUp Plugin — Feature List
**Last Updated:** 2026-05-13
**Purpose:** Planned features and enhancements, not yet implemented. Separate from the
ouch-list (safety/risk) and the gap-log (known defects). These are deliberate additions
to the student workflow tool.

---

## Format

| # | Feature | Why | Domain | Priority | Status |
|---|---------|-----|--------|----------|--------|
| F-nn | what | why it matters | file/tool | High / Med / Low | Idea / Specced / In Progress / Done |

---

## Guideway Geometry

| # | Feature | Why | Domain | Priority | Status |
|---|---------|-----|--------|----------|--------|
| F-01 | User-configurable minimum XY turn radius per model | `MIN_TURN_RADIUS` is currently a global constant (30 m). Campus and urban deployments need tighter turns; rural or high-speed corridors need looser ones. Exposed sharp horizontal bends where the constant was the wrong value for the site. | `jpod_constants.rb`, `jpod_path_builder.rb`, Network Editor Constraints panel | High | Idea |
| F-02 | User-configurable minimum Z (vertical) curve radius per model | `MIN_Z_CHANGE_DIAMETER` is currently a global constant. Fixing legacy 7.6 m waypoint Z values exposed that the vertical profile produces grade transitions that are too sharp when a significant vertical drop occurs over a short horizontal distance. Students need to be able to smooth this out without touching code. | `jpod_constants.rb`, `jpod_path_builder.rb`, Network Editor Constraints panel | High | Idea |
| F-03 | Per-connection XY and Z radius override | Beyond the model-wide default, individual connections (especially tight urban segments) may need their own radius settings. Would appear as fields in the Network Editor connection card. | `jpod_network_editor.rb`, `jpod_network.rb`, followme JSON schema | Medium | Idea |

**Root cause note for F-01 / F-02 (2026-05-13):**
Both constants are already in `PRIMARY_CONSTRAINT_DEFAULTS` and exposed in the Network
Editor Constraints panel — but they are model-wide only and require a Build to take
effect. The user experience needed is: adjust the radius slider, see the green Bezier
preview update in real time in the Connect Guideways tool, then Build.

The sharp Z radius defect was revealed when the build pipeline was fixed to use
`terrain + CLEARANCE_HEIGHT` instead of the legacy marker Z (7.5 m stored in old
waypoint groups). Once the vertical drop was computed correctly, the grade transitions
at waypoints became visible as tight kinks.

---

## Connect Guideways Tool

| # | Feature | Why | Domain | Priority | Status |
|---|---------|-----|--------|----------|--------|
| F-04 | Live Bezier preview updates when Constraints panel sliders change | Currently the green preview only updates when the tool is re-activated or a waypoint is moved. If a student adjusts MIN_Z_CHANGE_DIAMETER in the Constraints panel, they should see the Bezier reshape immediately. | `jpod_connect_tool.rb`, `jpod_network_editor.rb` | Medium | Idea |
| F-05 | Waypoint elevation readout in status bar | When placing or dragging a waypoint, show the current terrain Z and the resulting guideway Z (terrain + CLEARANCE_HEIGHT) in the status bar so students understand what height the beam will be at that point. | `jpod_connect_tool.rb` | Low | Idea |

---

## Network Editor

| # | Feature | Why | Domain | Priority | Status |
|---|---------|-----|--------|----------|--------|
| F-06 | Per-connection grade profile graph | Show a small elevation cross-section in the connection card: terrain line, grade-limit envelope, and beam Z line. Helps students identify where columns will be tall or where the grade is at its limit. | `jpod_network_editor.rb` | Medium | Idea |

