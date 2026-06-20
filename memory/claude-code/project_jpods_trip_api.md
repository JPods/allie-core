---
name: JPods trip booking API — Alice endpoints + encryption ToDo
description: Alice owns pricing for Natalie; two endpoints (price_query, invoice); customer identity model with local_id + carryon_uuid; API keys plain JSON now, encrypt + blockchain audit before release; 30-day review action due 2026-05-29
type: project
---

## JPods Trip Booking API

Alice owns all pricing and commerce. Natalie calls Alice — not the other way around.

**Two Alice endpoints:**
- `POST /api/alice/price_query` — Natalie asks before dispatch; Alice returns personalized price for that specific person
- `POST /api/alice/invoice` — Natalie posts after trip completes; Alice creates WebClerk record

**Customer identity — two IDs always:**
- `local_id` — this network's WebClerk identifier (used for all local operations)
- `carryon_uuid` — universal identifier (null until mycarryon.io WebClerk is configured)

When mycarryon.io is ready: Alice posts customer record there, stores returned uuid locally. Each JPods network operates on local_id; uuid enables cross-network recognition. Person owns their identity.

**API key storage:**
- Alice: uses existing Connections table in WebClerk
- Allie: `/Users/williamjames/Allie/config/allie-keys.json`
- Natalie/Noelle/Nora: `/Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi/config/<agent>-keys.json`
- Plain JSON during development; encrypt + blockchain audit trail before release

**30-day review due: 2026-05-29**
- Allie: flag at session start if date is approaching
- Alice: action record created in WebClerk when endpoints are built (sunset 2026-05-29)

**Why:** Blockchain audit for key changes = immutable record of who changed what and when. Fits sovereignty/usufruct model — every change has an owner and a record.

**Build order:** data model → two endpoints → readme + UI instructions → JSON key files → Alice action record for encryption review
