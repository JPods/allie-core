# Handoff — 2026-08-27 (Final — 21 commits)

## Where We Left Off

21 commits on main, not yet pushed (need `gh auth login` then `git push origin main:bill_dev && git push origin main`).

## The Big Insight

The FK-to-values conversion is not a database cleanup — it's the infrastructure for MyCarryOn. Self-contained records with integer IDs and refs.links display data are portable bundles. FK-bound records can't travel between instances. Same principle at every layer: individual sovereignty → data portability → self-contained records → values not FKs → refs.links → Bundle → MyCarryOn.

## What Was Built (21 commits)

### Naming & Structure (1-8)
1. id_ prefix → _id suffix (5 fields, 3 models)
2. Segmented Kanban project selector (dt_kanban)
3. Backend naming refactor (366 files — behavioral subdirectories)
4. Scrub bundles/Settings/Reports
5. Service model deleted → Item.config.service
6. Kanban move-to-project + contact manager trigger
7. Lifecycle discipline doc
8. Transaction serializer mega-file split

### Architecture (9-13)
9. Item-linked models doc
10. Shared serializer behaviors (core + transactions)
11. Core behaviors module — universal validators
12. Action + Touch + OrgBase wired to behaviors
13. Shared behaviors architecture doc

### FK Discipline (14-21)
14. Touch + OrgBase FKs → values
15. Communication FKs → values (Email, Phone, Address, Domain)
16. FK discipline reference — complete by-model inventory
17. Remaining CASCADE FKs → values (Payment, Alice models, DeliveryVisit)
18. fk_discipline in all 27 Setting.model configs
19. ItemLinkedBase CASCADE → PROTECT
20. Serial split from ItemLinkedBase → independent BigIntegerField
21. MyCarryOn connection documented

## Do This First Next Session

1. Push to bill_dev
2. Run test suite
3. Fresh-context review of FK discipline + shared behaviors

## Still Open

- Management command renames (14 inconsistent)
- Contact org FKs (SET_NULL → BigInt for consistency)
- refs.links Pydantic schema
- resolve_price_legacy merge
- Alice: orphan scan, delete log, service onboarding, serial review
- Kanban: test move-to-project and contact manager in browser
- Phone normalization: pre_save_hook → save()
