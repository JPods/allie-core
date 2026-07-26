# Handoff — 2026-07-26

## Where We Left Off
Bill is drafting capital raising documents for JPods Mall of America deployment. Sent email to Adrian Perica (Apple VP Corporate Development) about collaboration. ROI calculator live at meshmobility.com/pbc. Bill going offline.

## Do This First Next Session
1. **Gantt parent toggle** — clicking MOA parent should activate all child sprints (Action #31056). Bill needs this for MOA management presentation next week.
2. **Gantt task names** — showing "Untitled Action" because `task` field is JSONField. Extract string value for display.
3. **Fix DataBrowser sign-in redirect** — login succeeds but doesn't navigate to dashboard automatically.
4. **Capital draft review** — Bill is drafting 2-page executive summary + 1-page offer sheet. Review and tighten when ready.
5. **ROI calculator refinements** — Bill may have feedback on meshmobility.com/pbc after using it in conversations.

## Open Problems
- Gmail MCP insufficient scopes — can't search threads (needs re-auth with broader OAuth)
- AuditLog `user_agent` NOT NULL — noisy on shell operations, non-fatal
- `dt_kanban` on Project model is DateTimeField, should be BigIntegerField (Action #31055)
- Image on /pbc may not load through Cloudflare (works on direct access)
- DB sync between Mac and Andi is manual (pg_dump/restore) — needs Connection/Bundle long-term

## What Was Decided (and Why)
- **One Document per contact for ALL communications** — email, voice, typed, system. Not per transaction or per thread. One pile, filtered views. Too many piles = can't find anything.
- **Pending records → library after 12 months** — closed pendings are lightweight but millions slow active queries. Alice manages the sweep. Per-business rules (fireplace=50yr, coffee=2yr).
- **Operational DB + library architecture** — same schema, separate DB. Active stays fast, library is complete. Alice manages aging. Disk is cheap, query speed is not.
- **JPods ROI Engine structure** — JPods (invention, never raises capital), NCC (builds $13M/mile, 52 weekly closes), LMC (operates $20M/mile, farebox). Isolated risks. Same as housing.
- **MOA deal** — $3M per NCC/LMC license, 50% of ALL license revenue to MOA lenders until matched.
- **10,000 car threshold** — don't build where you can't remove 10K cars/day. 30K+ AADT = target corridor.
- **Distillation** — Tier 3 teaches Tier 2 teaches Tier 1. Knowledge flows down, cost goes to zero. Agents coach Claude at leftshoe.
- **Hive computing** — JPods stations are edge nodes. Thousands of Pis. The network that moves people also moves intelligence. hivetechnologies.com.

## Files Changed This Session (Day 3)
- `sites/jpods-roi-calculator/index.html` — Payback calculator with BOM, miles/km toggle, AADT threshold
- `readmes/65-distillation.md` — Three-tier learning + hive architecture
- `readmes/56-moa-project-specs.md` — MOA specs summary
- `readmes/capital-pages/jpods-executive-summary-draft.md` — 2-page capital draft
- `readmes/topics/architecture/email-document-architecture.md` — Email thread Documents
- `readmes/topics/architecture/campaign-reseller-collaboration.md` — Manufacturer ROI at last mile
- `readmes/topics/architecture/pending-flow-picture.md` — Pending records as business narrative
- `readmes/topics/reports-and-dashboards.md` — 35 reports, 7 dashboards
- `readmes/topics/ai/alice-data-quality.md` — Three-tier data quality
- `readmes/topics/architecture/ui-preferences.md` — metadata.wcui on Contact
- `apps/core/services/dedup.py` — Server-side dedup with journal
- `apps/core/services/phone_normalizer.py` — Normalize + format phones
- `apps/core/services/wcui_prefs.py` — UI preferences on Contact
- `components/common/DedupPanel.tsx` — Full dedup UI with merge/delete/edit/note/research
- `components/fields/PhoneField.tsx` — Normalize on blur, format on display
- `components/fields/ZipField.tsx` — New zip code field widget
- `pages/admin/AdminWorkbench.tsx` — App mode, A+/A- font, dedup via reports, server-side filters
- `pages/admin/AliceDashboard.tsx` — Data Quality tab
- WC3 DB: 5,322 clean contacts, 462 actions, 299 reports, 55 projects (including MOA hierarchy)
