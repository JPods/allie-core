# Consolidation Plan — Allie Readmes 30–33
**Date:** 2026-04-27
**Scope:** 10 files reviewed; this plan drives the merge to one polished set.
**Input brief:** `Physical_RouteTime_SketchUp_WebClerk.txt`

---

## What exists now

| Doc | Original | Parallel (with WebClerk) | SU draft | CC draft |
|-----|----------|--------------------------|----------|----------|
| Universal (30) | 30-allie-universal.md | 30-allie-universal-parallel.md | — | — |
| MeshMobility (31) | 31-allie-route-time.md | 31-allie-route-time-parallel.md | — | — |
| SketchUp (32) | 32-allie-sketchup.md | 32-allie-sketchup-parallel.md | 32-allie-sketchup-su-parallel.md | 32-allie-sketchup-CC.md |
| Physical (33) | 33-allie-physical.md | 33-allie-physical-parallel.md | — | — |

---

## Merge verdict for each document pair

### 30 — Universal

**Winner to carry forward:** `30-allie-universal-parallel.md`

What it adds over the original that must be kept:
- Allie is always present across all environments (not episodic)
- Allie is the AI substrate for Noelle, Natalie, and Nora until standalone processors exist
- WebClerk is the structured operating database (not runtime authority)
- Three kinds of truth stated explicitly: runtime truth / long-form knowledge / structured operating records
- Promotion rule tightened: two-environment independent appearance plus survives third environment

What the original has that the parallel lacks:
- The Knowledge Matrix taxonomy table is cleaner in the original
- Cross-domain mapping obligation example (CP concept) — should be carried forward verbatim

**Action:** Use parallel as the base. Transplant the Knowledge Matrix table and CP mapping example from the original. Produce `30-allie-universal-FINAL.md`.

---

### 31 — MeshMobility

**Winner to carry forward:** `31-allie-route-time-parallel.md`

What it adds over the original that must be kept:
- Allie always present framing
- WebClerk project 25 / project 24 usage spelled out concretely
- Stop and Review rule for MeshMobility (not present in original)
- Authority boundary stated for three layers: Python runtime / Allie / WebClerk
- Minimum required state before results are worth believing — 4 conditions

What the original has that the parallel lacks:
- Walk-Ride-Walk coverage color table (5/10/20/30 min → green/blue/yellow/red)
- Congestion vs. Topology Bug distinction table with four observable signals
- `diag_grid.py` verified-correct note with exact route ratios

**Action:** Use parallel as base. Transplant WRW color table, congestion/topology-bug table, and diag_grid verification note from original. Produce `31-allie-route-time-FINAL.md`.

---

### 32 — SketchUp

**Three-way merge: CC + parallel + su-parallel**

Best-of by section:

| Section | Best source |
|---------|------------|
| Plugin path + git workflow | CC (`32-allie-sketchup-CC.md`) |
| Full critical files table | CC (has jpod_constants, jpod_network, jpod_path_builder, jpod_guideway, templates — absent everywhere else) |
| Seven critical rules | CC (empirical findings — must survive session turnover) |
| Gap log P1–P5 quick reference | CC |
| Export artifact workflow | CC (most explicit: artifact → downstream flow) |
| `network.json` format | CC |
| WebClerk project 25/24 usage | Parallel (`32-allie-sketchup-parallel.md`) |
| WebClerk boundary rule (model vs readmes vs WebClerk) | Parallel |
| Authority boundary with cleaner wording | Parallel |
| Definition gate — what the code actually enforces | CC and Parallel agree; CC has cleaner format |
| Station contract as 4 conditions | CC |
| Cross-domain mappings with Invariant column | CC |
| Session workflow as numbered sequence | CC |
| Allie always present + AI substrate framing | Both parallel and CC |
| For the User section (Bill) | Original + parallel blend |
| SU readiness gate checklist | su-parallel (`32-allie-sketchup-su-parallel.md`) |
| Session evidence packet format | su-parallel |
| Comparison protocol (for cross-version review) | su-parallel — useful during this polish sprint; drop or archive after merge is complete |

**Action:** Create `32-allie-sketchup-FINAL.md`:
- Take CC as the structural base (most complete)
- Add WebClerk sections from parallel
- Add SU readiness gate checklist from su-parallel
- Add session evidence packet from su-parallel
- Drop su-parallel comparison protocol section (it is sprint-specific scaffolding)

---

### 33 — Physical

**Winner to carry forward:** `33-allie-physical-parallel.md`

What it adds over the original that must be kept:
- Allie always present framing
- WebClerk project 25 / project 24 usage spelled out concretely
- Three-layer truth separation: runtime / Allie / WebClerk
- Stop and Review equivalent for hardware (not just software)
- Physical contradiction record must name the upstream artifact that changes
- "Physical is the final arbiter" restated as a formal design decision

What the original has that the parallel lacks:
- Full MQTT TELEMETRY field map (0–22, field by field) — critical and absent from parallel
- START ping field map (0–6)
- Natalie's response format
- Fleet state check bash commands (mosquitto_sub, i2cdetect, etc.)
- Known hardware behaviors table (I2C lockup, TOF LED MAGENTA, endless RESEND loop, virtual=true)
- Allie's startup sequence (7 steps)
- Nora JSONL event type table

**Action:** Use parallel as base. Transplant full TELEMETRY/START/Natalie-response field maps, fleet check bash commands, hardware behaviors table, startup sequence, and JSONL event type table from original verbatim. Produce `33-allie-physical-FINAL.md`.

---

## Remaining gaps (not yet addressed in any version)

1. **`network.jpd` open question** — CC flags it as unknown: what is the `.jpd` in the JPodsSM workspace? Is it a SketchUp export or something else? This needs an answer before the SU doc is marked stable.

2. **Evidence packet format** — su-parallel proposes markdown; no version specifies JSON schema. Should be one format across all environments for machine-readable comparison.

3. **FollowMe deploy path** — CC asks: how does `followme.json` get from the SketchUp machine to physical pods and podPresenter? Deploy script or manual? Not documented anywhere in the 10 files.

4. **MeshMobility routing sanity endpoint** — all versions flag `GET /api/network/routing_check` as a proposed-but-not-built endpoint. If built it belongs in the FINAL doc as current, not speculative.

5. **Allie WebSocket / Mosquitto port 9001** — physical draft notes this as a gap for live Allie↔Nora channel. Should be an explicit open task in WebClerk project 25.

6. **Multi-venue broker address** — physical notes broker is hardcoded to 192.168.1.189. No solution exists yet. Needs a WebClerk action with sunset.

---

## JPods framework context (from brief)

The brief states the mission context that must be embedded in the universal doc and respected in each environment doc:

**Why:** Change economic lifeblood from oil to ingenuity.

**What:** JPods solar-powered, grade-separated, self-driving networks for Middle-mile (.5–50 miles) + walking/biking for Last-mile. Replace 60% of car-miles in cities.

**How:** Start small. Iterate relentlessly. Give away WebClerk, JPodsSM, MeshMobility, SketchUp applications so a mass of people (Wisdom of the Many) can design their city's network. Viable networks → JPods forms company, funds construction, shares equity, builds and operates. (Model: AOL mass-distribution creating email tipping point.)

**Regulatory frame:** 5x5 FreeMarket — private networks 5× more efficient than roads, pay 5% of gross transport revenues for airspace over approved public Rights of Way, regulated by the 3,000× better safety record of theme park rides.

This belongs explicitly in the Universal doc. It is not currently in any version.

---

## Allie always-on (from brief)

The brief states: "I want Allie to be omnipresent on my computer. I want her knowing everything I do, unless I specifically turn her off. I want her to turn on, when the machine turns on."

This is an infrastructure requirement, not a doc requirement. Implementation steps:
1. Add a LaunchAgent plist for Allie startup on login.
2. Add an opt-out toggle Allie checks before each session.
3. This is independent of the doc consolidation — recommend creating a WebClerk action for it.

---

## WebClerk local database (from brief)

"Allie needs to be able to turn on [the WebClerk local version] when she needs to record something into a database... mark them to be posted to a database when action is required by others... post action model records to assign me, her, and others tasks."

Current state of the parallel docs: WebClerk is named as the structured operating database. The project 25 / project 24 / action / setting / note patterns are documented. What is not yet documented is:

- How Allie starts the local WebClerk instance autonomously
- How she writes action records with owner assignments programmatically
- The offline queue: notes stored locally → posted when action is required

Recommend: This belongs in `05-webclerk-integration.md` and needs a new section. This is a separate track from the doc consolidation.

---

## Recommended merge sequence

1. Produce `32-allie-sketchup-FINAL.md` — highest cross-version complexity; do this first as the template.
2. Produce `30-allie-universal-FINAL.md` — add JPods mission context; this sets the frame for 31 and 33.
3. Produce `31-allie-route-time-FINAL.md` — straightforward parallel + transplant.
4. Produce `33-allie-physical-FINAL.md` — straightforward parallel + transplant of field maps.
5. Update `05-webclerk-integration.md` — add Allie autonomous DB startup section.
6. Create WebClerk actions for: Allie always-on LaunchAgent, FollowMe deploy path, routing_check endpoint, Mosquitto port 9001, multi-venue broker.

---

## Status: what is already polished vs what needs Bill's review

| Item | Status |
|------|--------|
| All 4 parallel drafts | Written — ready for transplant |
| CC draft (32) | Written — ready as SU base |
| JPods mission context in universal | Not yet written — needs drafting |
| Session evidence packet schema | Proposed — needs format decision |
| `network.jpd` identity | Unknown — needs Bill's answer |
| FollowMe deploy path | Unknown — needs Bill's answer |
| Allie always-on LaunchAgent | Not started — needs infrastructure track |
| WebClerk autonomous DB startup | Not started — needs `05-webclerk-integration.md` section |
