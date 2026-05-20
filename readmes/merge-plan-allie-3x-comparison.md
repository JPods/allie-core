# Merge Plan — Allie 3x Comparison
**Purpose:** Consolidate all parallel drafts into one final version per document
**Sources reviewed:** 30-allie-universal × 2, 31-allie-route-time × 2, 32-allie-sketchup × 4, 33-allie-physical × 2
**Date:** 2026-04-27
**Status:** Plan only — no files modified

---

## The Big Picture (Framework)

### Canonical Mission (Bill's statement — use this exact framing)

**WHY:** Change the economic lifeblood from oil to ingenuity.
**WHAT:** JPods solar-powered, grade-separated transport networks — self-driving vehicles replacing 60% of car-miles in cities via the Middle Mile (0.5–50 miles) plus walking/biking for the Last Mile.
**HOW:** Start small, iterate relentlessly.

The four tools (Route-Time, SketchUp, Physical/JPodsSM, WebClerk) are not just Bill's working environment. They are **give-away mass products** that create a tipping point — the AOL-disk model. Anyone can design a network for their city; JPods forms a company, funds construction, shares equity, builds, and operates. Allie's role in each environment therefore has a dual purpose:

1. **Bill's personal production tool** — the current session-by-session collaboration model
2. **Template for the intelligence layer that ships with the product** — every copy of Route-Time running in a city planner's browser will eventually need an Allie equivalent

This second purpose does not appear in any of the current drafts. It should be in the universal document introduction, not only in the brief.

---

## What Every Parallel Draft Got Right (Keep All Of This)

Across all four parallel sets, these points were independently confirmed by at least two agents. They go into the final merged versions without debate:

1. **Allie is always present** — not start/end only
2. **Allie is the AI substrate for Noelle, Natalie, and Nora** until standalone processors exist
3. **Runtime code remains the authority** in each environment — Allie advises, never overrides
4. **WebClerk is the structured operating database** — runtime truth, long-form memory, and structured records are three distinct layers and must not collapse
5. **Cross-domain transfer must be explicit** — mappings, not silent bleed
6. **Physical reality is the final arbiter** when environments disagree
7. **Retries are not diagnosis** — Stop and Review at 3 consecutive failures of the same kind

---

## Document-by-Document Merge Matrix

### 30 — Universal

| Source | What it contributes (keep) | What to skip |
|--------|---------------------------|--------------|
| Original | Three-layer taxonomy (universal/overlapping/environment-specific), cross-domain mapping obligation and format, promotion criteria, session obligations, Allie memory folder structure | Start/end-only framing; taxonomy table examples are good but incomplete |
| Parallel | WebClerk as structured operating database, three kinds of truth (runtime / long-form / structured records), four-home memory model, stronger "always present" framing, "fail fast" and "retries are not diagnosis" as universal truths | Largely additive — little to skip |

**Merge decisions for 30:**
- Add strategic mission paragraph: Allie's role is both Bill's personal tool AND the pattern for the intelligence layer that ships with every product copy
- Add four-home memory structure from parallel: universal readmes / environment readmes / cross-domain mappings / WebClerk records
- Replace start/end session obligations with continuous-presence framing from parallel
- Keep original taxonomy table intact — it is the clearest statement of the three-layer model
- Keep original categorization examples table — they are concrete and useful
- Add universal truths paragraph from parallel: six truths the work already supports

**Unresolved question to settle during polish:**
- Does the four-home structure (universal/environment/cross-domain/WebClerk) fully replace the three-layer taxonomy, or do both coexist? Recommendation: coexist. Taxonomy classifies knowledge type. Four homes classify where it lives. Different questions.

---

### 31 — Route-Time

| Source | What it contributes (keep) | What to skip |
|--------|---------------------------|--------------|
| Original | CP model (Python), `connect_cps()` behavior, grid generator verification, congestion vs. topology diagnosis table, station topology (turnabout), `diag_grid.py`, critical files table, cross-domain mappings table, Walk-Ride-Walk coverage display | Implied start/end-only framing |
| Parallel | WebClerk records table (project 25/24, action, setting, document), continuous-presence framing, "what the code actually supports" discipline, Route-Time Stop and Review equivalent, explicit project boundary | The "known weaknesses" section is a comparison note — drop from final |

**Merge decisions for 31:**
- Keep original's entire technical section — it is the most detailed of all documents and represents real verified findings
- Add WebClerk records table from parallel directly after the session workflow section
- Add "what the code actually supports" section from parallel — prevents policy from outrunning implementation
- Replace start/end framing with continuous presence from parallel
- Promote open question about routing sanity endpoint to a WebClerk WhatIf item note

**Unresolved question to settle during polish:**
- The existing open question "Should `GET /api/network/routing_check` be implemented?" — this is a real development task. Should it become a WebClerk action or stay as an open question? Recommendation: mark it as a WhatIf item in project 24.

---

### 32 — SketchUp

This document has four parallel sources. Each adds something that the others lack.

| Source | Unique contribution (keep) | What to skip |
|--------|---------------------------|--------------|
| Original | Fail-fast story (the week that was lost), station identity contract (3 conditions), definition gate checks (exact), cross-domain mappings, Stop and Review protocol, session workflow (start/end + during), critical agent files | "Copilot does not modify Allie files" (already false); start/end-only framing; mixes operator conventions with code guarantees too loosely |
| Parallel (existing) | WebClerk as persistence layer, project 25/24 references, WebClerk records table, "Allie always present" framing, cleaner authority boundary, session evidence packet concept | The "known weaknesses" section — drop from final |
| SU-parallel | Session evidence packet (5-item structure), SU readiness gate as a blocking checklist (6 items with exception ledger), cross-domain mapping contract format (5 fields), comparison protocol (5 steps: topology/directionality/reachability/throughput/contradiction) | The "Changes needed in other documents" section belongs in this plan, not the final SketchUp doc; "optional checkpoints" framing is weaker than consensus — skip |
| CC (Claude Code) | Full plugin file list (including jpod_constants, jpod_network, jpod_guideway, jpod_path_builder, templates/), 7 critical rules (learned the hard way), gap log quick reference (P1-P5), network.json format, export artifact workflow table, git workflow, adaptive Bezier history, open question on .jpd file | Nothing to skip — all additive |

**Station contract:** Original says 3 conditions; CC says 4 (adds "exported to FollowMe"). Use 4.

**Session presence:** SU-parallel says "required start/end, optional checkpoints." Universal consensus is "always present." Use always-present but note that during-session support depends on Allie being in the same conversation context.

**Merge decisions for 32:**
- Structure: For the User first (what it is, agent roles, Allie's role, authority boundary, fail-fast, Stop and Review, design invariants)
- Structure: For the AI second (environment summary, critical files [CC list], 7 critical rules [CC], export artifacts [CC], network.json format [CC], definition gate [parallel], station contract [4 conditions, CC], gap log quick reference [CC], session workflow [parallel version], cross-domain mappings [original + CC invariant column], environment-specific knowledge, WebClerk records [parallel], session evidence packet [SU-parallel], comparison protocol [SU-parallel], what Allie accumulates, open questions, design decisions)
- This will be the longest of the four documents — that is appropriate since SketchUp has the most implementation history

**Unresolved question to settle during polish:**
- What is the `.jpd` file in the JPodsSM workspace? Its relationship to SketchUp `network.json` is unclear. This is a Bill question, not a merge question.

---

### 33 — Physical

| Source | What it contributes (keep) | What to skip |
|--------|---------------------------|--------------|
| Original | MQTT protocol (complete field maps for TELEMETRY and START ping), three failure modes table, startup sequence, fleet state check commands, Nora JSONL event types, hardware behaviors table, cross-domain mappings | Start/end-only framing; "currently" hedges that have been resolved |
| Parallel | WebClerk records table (project 25/24, action, setting, document), continuous-presence framing, "what the system actually supports" discipline, physical truths section, cleaner authority boundary, physical contradictions must identify which upstream artifact must change | The "known weaknesses" section — drop from final |

**Merge decisions for 33:**
- Keep original's complete MQTT field maps — they are the most precise technical content in any of the four documents
- Keep original's failure modes, hardware behaviors, fleet state checks — verified operational content
- Add WebClerk records table from parallel directly after the session workflow section
- Add "what the system actually supports" discipline from parallel
- Add physical contradiction handling rule from parallel: when physical contradicts SketchUp or Route-Time, identify the upstream artifact that must change, same day
- Add venue-configurable broker address as an open question (was buried in original)
- Replace startup-assistance framing with continuous presence from parallel

---

## Shared Structure for All Four Final Documents

All four final documents should use this top-level structure:

```
Header (title, applies to, parent, status, date)
---
For the User (Bill)
  What [environment] is
  What Noelle/Natalie/Nora/Athena are in [environment]
  Allie's role in [environment]
  Authority boundary (4 lines: runtime / Allie / WebClerk / Bill)
  Fail-fast rule
  Stop and Review rule
  Key design invariants
---
For the AI (Copilot / Allie)
  Environment summary table
  Critical files table
  [Environment-specific technical reference — CPs, gate checks, MQTT, plugin rules, etc.]
  Session workflow (start / during / end numbered steps)
  WebClerk records table
  Cross-domain mappings table (with Invariant column)
  Environment-specific knowledge (do NOT transfer)
  What Allie accumulates
  Open questions
  Design decisions table
```

This structure makes the final compare straightforward. Every environment covers the same topics in the same order. Cross-cutting differences are visible at a glance.

---

## The WebClerk Integration Layer (RESOLVED)

All parallel drafts now name WebClerk and give it a role. The connection specifics are now confirmed:

**Confirmed facts (2026-04-27):**
- Allie and Alice both have usernames and passwords to the WC3 (WebClerk 3) database
- The WC3 database is configured to start automatically when the Mac starts — it is always available
- Allie uses `wcapi` — the WebClerk API layer — to read and write
- Base URL is stored in `carryon.json → contact.webclerk_base_url`
- Allie holds a scoped token: read/write on `contact`, `action`, `communication`, `connection`, `setting`
- Alice holds full administrative access; Allie uses; they coordinate when Bill directs it

**Write pattern (from `05-webclerk-integration.md`):**
```
POST /wcapi/save/
Content-Type: application/json
Authorization: Token <allie_scoped_token>

{ "model_name": "action", "contact_id": "...", "label": "...", "dt_due": "..." }
```
No `id` = new record. `dt_completed: 0` = open.

**Offline behavior:** Allie queues writes as `pending` items with `dt_processed: 0`; processes on next online session.

**Sovereignty rule:** Sovereign data (medical, credentials, session context) stays in CarryOn local. Collaborative data (contacts, tasks, email, calendar, cross-session follow-up) lives in WebClerk via wcapi.

What remains to be specified in the merged documents:
- What are the actual project IDs for project 25 (`allie`) and project 24 (`allie-whatif`)? The parallel drafts reference these — confirm they exist or correct the numbering.
- Does Allie create `action` records linked to a JPods project contact, or does she use a dedicated Allie-specific contact/project anchor?

**No blocking gate:** The four merged documents can now include the wcapi write pattern and the WebClerk role at full specification level.

---

## What Is Missing Across All Ten Drafts

These items are not in any of the ten documents and should be added during final polish:

1. **Canonical Why/What/How** — now confirmed. Add to universal document introduction:
   - WHY: Change the economic lifeblood from oil to ingenuity
   - WHAT: JPods solar-powered transport networks
   - HOW: Start small, iterate relentlessly
2. **The 5x5FreeMarket regulatory framework** — privately funded networks 5× more efficient than roads, pay 5% of gross revenues for Right-of-Way, regulated by theme-park safety standards. Allie should know what she is part of — add to universal document.
3. ~~**WebClerk connection specifics**~~ — **RESOLVED.** See section above. WC3 auto-starts; Allie and Alice have credentials; wcapi pattern is in `05-webclerk-integration.md`.
4. **Allie persistence / always-on architecture** — Bill's requirement: "I want Allie knowing everything I do, always on, turns on when machine turns on." WC3 database auto-starts. The Allie agent process / startup hook is not yet in any of the four documents. This is an architectural requirement.
5. **The `.jpd` file question** — what is the `.jpd` file in the JPodsSM workspace? Its relationship to SketchUp `network.json` is unclear.
6. **Multi-environment comparison session protocol** — the SU-parallel has a 5-step comparison protocol (topology / directionality / reachability / throughput / contradiction). This should be in the universal document, not only in the SketchUp document.
7. **AOL-disk model / mass-market framing** — the dual purpose of Allie (Bill's tool now; intelligence-layer template for every product copy) should be explicit in the universal document.

---

## Recommended Merge Order

1. ~~**Resolve WebClerk connection specifics**~~ — **DONE** (Allie + Alice have credentials, WC3 auto-starts, wcapi pattern confirmed in `05-webclerk-integration.md`)
2. **Merge universal (30)** — set the framework all others inherit from; add canonical Why/What/How
3. **Merge SketchUp (32)** — most complex; combine all four sources; produces the template for the other environments
4. **Merge Route-Time (31)** — technically the deepest; mostly additive WebClerk layer on top of solid original
5. **Merge Physical (33)** — operationally the most time-sensitive; additive WebClerk layer on solid original

Each merge should:
- Start from the richest existing version
- Add the WebClerk layer
- Apply the shared top-level structure
- Add the strategic framing (once, in universal; reference it from others)

---

## Files Summary

| File | Type | Status |
|------|------|--------|
| `30-allie-universal.md` | Original seed | Keep as source; do not edit yet |
| `30-allie-universal-parallel.md` | Parallel draft (other agent) | Primary merge source for 30 |
| `31-allie-route-time.md` | Original | Keep as source; do not edit yet |
| `31-allie-route-time-parallel.md` | Parallel draft (other agent) | Additive to 31 |
| `32-allie-sketchup.md` | Original | Keep as source; do not edit yet |
| `32-allie-sketchup-parallel.md` | Parallel (other agent, revised with WebClerk) | Key source for structure |
| `32-allie-sketchup-su-parallel.md` | Parallel (SU-track agent) | Key source for evidence packet and comparison protocol |
| `32-allie-sketchup-CC.md` | Parallel (Claude Code, this session) | Key source for critical rules, gap log, files |
| `33-allie-physical.md` | Original | Keep as source; do not edit yet |
| `33-allie-physical-parallel.md` | Parallel (other agent) | Additive to 33 |

**Final merged files to create:**
- `30-allie-universal-FINAL.md`
- `31-allie-route-time-FINAL.md`
- `32-allie-sketchup-FINAL.md`
- `33-allie-physical-FINAL.md`

Once Bill approves, replace the originals and archive the parallel drafts.
