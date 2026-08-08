# Handoff — 2026-08-07 (MVP Sprint)

## Where We Left Off
MVP sprint — action card UI, column widths, label-as-select, assigned_to widget. Bill needs sleep. Git commit pending for both WC3 and React2025.

## Do This First Next Session
1. **Git commit** — WC3 (action.py __str__ fix, init_handlers) + React2025 (DynamicDetail, ContactSelectWidget, DataGrid, useDataBrowser, KanbanBoardPage, KanbanTaskModal, UnifiedGantt, GanttTaskTemplate, FieldRow, Router, widget registry)
2. **Verify contact click** — `/contact/21` should open Antor's record. Was getting 429 rate limiting from too many tabs. Close extra tabs first.
3. **Claude is_staff** — id=10627 needs `is_staff=true` to appear in assignee select

## Key Decisions Made
- **Label-as-select** — WC3 norm: colored label above, select control below. Schema names as labels.
- **Six rendering contexts** — db.list, db.detail, db.page, db.card, db.panel, ui.tsx
- **Column widths** — user-sovereign, 3px minimum, no auto-sizing, do not overhelp
- **Onboarding always priority 1** — trail-breaking doctrine (readmes/wisdom/trail-breaking.md)
- **Thread you can pull** — consult Allie/Alice DURING work, not after (readmes/wisdom/thread-you-can-pull.md)
- **assigned_to sources** — is_staff, project.prefs.assigned_to, record.prefs.assigned_to (subject to Pydantic review)

## Open Items
- Unified card/record toolbar (one toolbar for all detail layouts)
- Push field_behaviors (select lists) to Andi
- db.card floating contact card (peek without navigation)
- Patent updated at today/patent-live-form-designer.md
- assigned_to Pydantic schema definition (subject to review)
