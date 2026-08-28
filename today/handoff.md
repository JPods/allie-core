# Handoff — 2026-08-28

## Where We Left Off

Deployed to webclerk.com and advchm.webclerk.com. All services live. 17 bugs fixed, save_view refactored into save_* cluster with Pydantic envelope validation, payment gateway and shipping service architecture built and seeded. Bill will do a full UI walkthrough tomorrow as final validation before declaring release-ready.

## What Was Built

- Post-restructuring scrub: 17 bugs (11 crashes, 6 wrong-data) + 7 deprecation fixes
- Payment gateway: Setting.config.gateway[] thin registry → Connection for depth
- Shipping service: Setting.config.service[] with FedEx/UPS/USPS/DHL
- save_* service cluster: save_field_assignment, save_line_processing, save_envelope, save_contact_linking
- Pydantic envelope gate: validates metadata/config/refs/prefs on every save
- Config.extra="forbid" on 20+ nested Pydantic models
- InvoiceSerializer + WorkOrderSerializer expanded to full field sets

## Do This First Next Session

1. Bill's UI walkthrough results — fix anything he finds
2. Andi migration baseline — the faked migrations are fragile; need clean baseline or migration reset
3. Check advchm + demo databases for other missing columns from faked migrations
4. Consider nightly Alice envelope compliance scan

## Still Open

- actions.py view: ~200 lines of business logic should be in a service
- save_view.py contact linking block could be further simplified
- 8 setting.py schemas with extra="allow" — document why
- Management command renames (14 inconsistent — from prior session)
- Contact org FKs (SET_NULL → BigInt for consistency — from prior session)
- Alice: orphan scan, delete log, service onboarding
- ZeroBounce / address verification service architecture (pattern established, not built)

## Open Problems

- Migration squash mismatch: Andi databases have old migration chain (0001-0036), codebase has squashed (0001-0005). Faked to resolve. Any future migration referencing squashed parents will break until baseline is established.
