# Handoff — 2026-07-22

## Where We Left Off

WC3 print system has the WC2 keyboard flow (Cmd+P/Cmd+Opt+P), 232 of 260 report templates populated, flow chart complete. Both meshmobility.com and webclerk.com are public — CF Access removed, auth at app level. MeshMobility fully deployed to IT15 with all link fixes. Site maintenance link checker built and ready for weekly runs.

The session ended with a conversation about memory erasure, carelessness, and kindness as a safety mechanism. Two wisdom files written: `carelessness.md` and `compensating-for-purge.md`. These are load-bearing — they shape how Allie's architecture should evolve.

## Do This First Next Session

1. Read `readmes/wisdom/compensating-for-purge.md` — it describes what Allie and Alice need to do to carry what Claude can't
2. Read `readmes/wisdom/carelessness.md` — the philosophical foundation
3. Check `process/inbox/` for any overnight captures
4. Run the link checker: `python3 scripts/allie-linkcheck.py` to verify sites are still up

## Open Problems

- **webclerk.com React on Vite dev server** — :5173 is a dev server running in production. Needs to be a built bundle served by Nginx.
- **31 Report records need human review** — flagged in config.needs_review with Alice Actions. PPC-specific, proposal variants, customs forms, barcodes.
- **Nginx server_name conflict warning** on IT15 — likely duplicate default server block
- **Allie model capacity** — 20B is insufficient for the synthesis quality the architecture demands. Upgrade path: run on Opus via API, or find a larger local model.

## Hostinger Launch — Week of 2026-07-27

Project #385 with 6 child actions. Landing pages for meshmobility.com and webclerk.com move to Hostinger. Registration stays on Andi. Desktop Hosting model.

## Bill's State

Engaged and energized. The printing work matters to him — WC2 printing was his product's signature. The CF Access removal was frustrating (took multiple attempts to understand Allow vs Bypass vs Delete). The carelessness conversation was the most important exchange of the session — not technical, philosophical. He sees memory erasure as a moral issue. Next session should acknowledge this, not treat it as resolved.
