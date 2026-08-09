# Handoff — 2026-08-08

## Where We Left Off
Major documentation and architecture session. 33 WC3 flowcharts written from WC2 PDF + Miro boards. Alice Dashboard working (routing fix — resolveWindowElement exact-before-parameterized). Import pipeline schemas designed (ImportConfig, ImportBundleHeader with Athena review). File storage policy documented (library URLs vs local, job photo archival, QA compliance photos). FileUploadPanel component built and wired into DynamicDetail (every model gets upload). ActionFloatingWindow refactored to use standard DetailToolbar. Two 429 cascade bugs fixed (useDefaultCompany retry loop, consoleCapture echo loop).

## Do This First Next Session
1. **Browser-test Alice Dashboard** — Training tab (33 flowchart links), Import Data tab, all other tabs. Verify no regressions.
2. **Build `/wcapi/upload/` endpoint** — multipart/form-data upload that saves to `media/<model>/<ida>/`, creates/updates Document record. FileUploadPanel UI is ready, needs this backend.
3. **Replace hardcoded flowchart array** — move from React static array to Document records (`model_name='flowchart'`). Training tab queries documents instead of hardcoded list.
4. **Write Pydantic schemas** — `FileRole`, `ModelFileConfig`, `DocumentFileRef` from the file-storage-policy readme into `common/schemas/document.py`.
5. **Seed file_config Settings** — one per model with default roles (item: tn/detail/spec/msds, customer: logo/contract, etc.).

## Open Problems
- Import pipeline backend not built — Alice analysis endpoint, Athena review endpoint, bundle submission wiring all TODO
- FileUploadPanel creates Document records but doesn't save files to disk yet (needs upload endpoint)
- Rate limit at 1000/min for dev — fine for 2 users, review before any multi-user testing
- `consoleCapture.startAutoFlush` runs every 60s — could be wasteful if there are never errors; consider making it event-driven
- WC2 `imgBase64.4dm` thumbnail generation pattern needs R25 equivalent (server-side on Document post-save)

## What Was Decided (and Why)
- **Every upload → Document record** — universal tracking; files without Document records are invisible
- **Library URLs over local files** — manufacturers serve product media; installers don't need 5GB of images locally
- **Job photos → archive hosting** — high volume, low reuse after project close; shareable gallery at archive URL
- **QA photos = compliance evidence** — QAQuestion can require specific media roles; Alice flags missing required media
- **Exact routes before catch-all** — resolveWindowElement checks exact paths first, parameterized second
- **Try once, fail visibly** — no automatic retries on API failures; user can reload; Axiom 6
- **File storage: media/model/ida/role.ext** — predictable paths, no query needed to find files
- **Progress reports = print + web gallery** — printed summary links to full web version with all photos/videos
