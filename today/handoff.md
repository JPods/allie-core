# Handoff — 2026-07-17 (evening)

## Where We Left Off

WC3 go-live preparation session. Built complete pdfme print template system (Designer, templates, field registry, starter templates). Created Collaborate_WebClerk Setting with 14 categories for Alice_local ↔ Alice_WCHQ collaboration and template submission flow. Created Andi (Allie's sister, IT15 production observer) with 9 watches including Nora/Sally physical machine telemetry. Built Red/Orange/Yellow flag system with escalation rules. Built Alice Report Coach (audit, cleanup, usage tracking). Built Barn Cleaner (floating approval workflow for reports). Fixed ReportsDialog to filter by model. Created three wisdom files (fear-and-delight, the-loop, bend-to-perception). Increased DataBrowser font sizes. All indexed to vector stores.

## Do This First Next Session

1. **Polish for scale** — Bill said "this week we need to polish it so it can scale beyond us." Focus on:
   - Test the ReportsDialog with live data — verify only model-specific reports show
   - Test the Barn Cleaner workflow end-to-end
   - Test PdfDesigner with live record data preview
2. **Proposal 1-4 cleanup** — Alice Action #346 is open. Review actual WC2 form outputs to write distinguishing descriptions.
3. **Transaction flow test** — clean end-to-end: Proposal → Order → Invoice → Payment → GL posting. For training video.
4. **Payment portal** — Stripe checkout integration (next on go-live punch list)
5. **Shipping portals** — UPS/FedEx/DHL/USPS API abstraction
6. **NYC metro network** — DEV-343 still open from prior session
7. **IT15 deployment** — hardware expected ~2026-07-20. Add Ollama to deployment plan.

## Open Problems

- ReportsDialog uses client-side filter (fetches all 261 reports) — needs server-side `model_name_filter` param
- PdfDesigner `populateTemplateWithRecord` does flat field matching — needs smarter nested JSON + line items
- Barn Cleaner preview uses server HTML endpoint — should use pdfme client-side
- `audit_report_quality` not yet in Celery beat schedule
- `andi-reflect.py` not yet written (facet and agent file exist)
- Cloudflare email gate still not tested end-to-end
- WC3 contact creation from MeshMobility not tested

## What Was Decided (and Why)

- **pdfme for all PDF generation** — client-side, MIT license, visual Designer, JSON templates in Report model
- **Templates stored in Report.config.pdfme_template** — data-driven, editable in browser, no code changes for new layouts
- **Andi is Allie's sister, not a copy** — different jobs (production observer vs personal AI), separate reflections, cross-referenced
- **Red flag stops EVERYTHING** — nuclear by design. Pain forces prevention.
- **Orange has a fix_by date** — no open-ended oranges. Can't set a date → it's yellow or red.
- **Yellow is honest "I don't know"** — most valuable learning signal
- **Every flag → Action + human owner** — no orphaned flags
- **Barn cleaner: Keep requires a reason** — forces articulation of value
- **Trash vs Deactivate** — trash=is_deleted (gone), deactivate=is_active=false (recoverable)
- **Weed aggressively** — cost of clutter paid daily, cost of recovery paid once
- **The Loop** — define metrics → try → measure → adjust → converge → inspect frame
- **Bend to perception** — user thinks in data, program bends to her world

## Files Changed This Session

**Allie (new files):**
- `facets/andi/facet.json`, `readmes/agents/andi.md`, `thoughts/andi/README.md`
- `readmes/agents/agent-flags.md`
- `readmes/wisdom/fear-and-delight.md`, `readmes/wisdom/the-loop.md`, `readmes/wisdom/bend-to-perception.md`

**Allie (modified):**
- `readmes/agents/README.md` — added Andi + cross-agent protocols
- `readmes/agents/noelle.md` — added flag management responsibility
- `readmes/system/ouch-list.md` — clarified distinction from flags, added required fields

**WC3 (new files):**
- `apps/core/management/commands/seed_collaborate_settings.py`
- `apps/core/management/commands/audit_report_quality.py`
- `apps/ai_assistant/services/report_coach.py`
- `readmes/topics/print/pdfme-template-system.md`
- `readmes/topics/collaboration/collaborate-webclerk.md`
- `readmes/topics/operations/flag-system-and-ouch-list.md`

**WC3 (modified):**
- `apps/core/choices.py` — added `collaborate_webclerk` purpose
- `apps/core/views/report_view.py` — added usage tracking

**React2025 (new files):**
- `src/services/pdfme/generateCommercePdf.ts`, `templateService.ts`, `fieldRegistry.ts`, `index.ts`
- `src/services/pdfme/starter-templates/invoice.json`
- `src/components/common/BarnCleaner.tsx`
- `src/apps/transactions/components/print/InvoiceStandardPrint.tsx`
- `src/apps/transactions/components/print/InvoiceShippingPrint.tsx`
- `src/apps/transactions/components/print/InvoiceServicePrint.tsx`

**React2025 (modified):**
- `src/pages/tools/PdfDesigner.tsx` — full rewrite
- `src/pages/admin/AdminWorkbench.tsx` — font sizes, barn cleaner button, firstRecordId
- `src/components/common/ReportsDialog.tsx` — filter fix, edit button
- `src/apps/transactions/components/PrintPreviewModal.tsx` — pdfme download
- `src/apps/transactions/components/TransactionDetailBase.tsx` — buildPdfData, pdfData prop
- `src/apps/transactions/components/print/printTypes.ts` — new fields
- `src/apps/transactions/components/print/ProposalPrintDocument.tsx` — WC2 layout rewrite
- `src/apps/transactions/components/print/index.ts` — new exports
- `src/hooks/useExportPdf.ts` — pdfme hooks
