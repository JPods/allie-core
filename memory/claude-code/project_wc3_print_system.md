---
name: WC3 print system — WC2 heritage
description: WC3 printing architecture reproducing WC2 Defined Reports flow; Cmd+P primary, Cmd+Opt+P selector, pdfme templates, Report model
type: project
---

WC3 print system built 2026-07-19, reproducing WC2's "Defined Reports" dialog and keyboard flow.

**WC2 heritage reproduced:**
- Cmd+P = print primary report (sort_order=0) without dialog; if no primary → opens selector
- Cmd+Opt+P or Print button = open Defined Reports selector dialog
- Double-click a report row = execute that report
- Report Setup button = open report for editing (PdfDesigner)
- New Report button = create new report

**Key files:**
- `React2025/src/components/common/ReportsDialog.tsx` — enhanced WC2-style dialog (grid layout, output_type column, primary badge, arrow key nav, footer buttons)
- `React2025/src/hooks/useReportShortcuts.ts` — Cmd+P / Cmd+Opt+P hook; intercepts browser print in capture phase
- `React2025/src/apps/transactions/components/TransactionDetailBase.tsx` — wired with Reports button + keyboard shortcuts + ReportsDialog
- `React2025/src/pages/admin/AdminWorkbench.tsx` — Cmd+P opens report selector in DataBrowser context
- `webClerk3/readmes/flowcharts/wc3-print-system.dot` — full system flow chart

**Report model fields that matter:**
- `sort_order=0` = primary report (Cmd+P target)
- `output_type`: print, email, export, label, letter, list, api, json, merge
- `category`: report, statement, list, summary, letter, label, export, utility
- `config.pdfme_template` — stored pdfme template JSON
- `role_required` — authority gating

**Why:** Bill wants WC3 printing to feel like WC2 — one-click from any record, multiple templates per document type, user-editable. WC2 had 17 print methods + SuperReport XML templates + multi-destination output. WC3 replaces all of that with pdfme client-side + Report model.

**How to apply:** When touching print flow, respect the Cmd+P=primary / Cmd+Opt+P=selector pattern. Primary report is sort_order=0. All report execution goes through the Report model, not hardcoded templates.

**Not yet connected:** The saved pdfme templates in Report.config.pdfme_template are not yet wired into the actual PDF generation path — generateCommercePdf.ts still uses programmatic templates. That's the next integration step.
