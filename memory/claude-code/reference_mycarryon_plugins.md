---
name: MyCarryOn plugin architecture
description: Plugin framework for specialty programs (medical, translate, commerce); permission levels; data fades to metadata after 7 days; at readmes/59
type: reference
---

MyCarryOn plugin architecture designed 2026-07-16. Full doc: readmes/59-mycarryon-plugin-architecture.md

**Key design decisions:**
- Person's device is source of truth, not WebClerk
- Data fades to metadata in WebClerk after ~7 days (Celery beat nulls PII fields)
- transaction_uuid per interaction (NOT person's carryon_uuid in cleartext) — person's uuid encrypted in blockchain record, requires court order to decrypt
- 6 permission levels: emergency (no auth), transit, commerce, advertising, professional, government
- Plugins compose but cannot escalate permissions
- JPods never advertises to people; riders opt in per-ride; 95% ad revenue to rider, 5% to network, forfeited on privacy violation

**How to apply:** Phase 1 = WC3 instance on IT15; Phase 2 = CarryOn app on phone + data fading; Phase 3 = open plugin registry
