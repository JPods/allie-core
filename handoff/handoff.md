# Handoff — 2026-07-01

## Session Summary

Massive wc3 build session (June 28 → July 1). Commerce services, AI infrastructure, codebase documentation, and design decisions.

## Core Principle Established

"We cannot anticipate all user needs. Coaching allows creation with disciplined review." — Bill

Applied everywhere: Alice doesn't block, she coaches. Users create what they need. Alice watches patterns, enforces standards through observation, promotes what works, flags what drifts. The builder story: don't design sidewalks — watch where people walk, pave those paths.

## What Was Built

### Commerce (12 services, 50+ manage actions)
- GL journalization (line-level, wc2 pattern), commission system (level_factors, splits, GL accrual chain), pending inventory (CoreModel), pending payment (one-path), credit check (warnings + audit trail), vendor scorecard, suggest_purchase, campaign CAC, manufacturer rebate, MAP enforcement, PDF reports (8 templates), commission auto-accrual on journalize

### AI Infrastructure
- 3 ChromaDB vector stores (Alice 10,808 / Allie 2,291 / Claude 1,153 chunks)
- PostgreSQL `allie` database (12 tables — sessions, memory, agent logs, messages)
- Agent message bus + WC3 bridge
- Session start script + allie-db MCP server (available next session)
- Model router (qwen2.5:72b downloading to 5TB)
- Alice pattern detection (7 detectors, 4-hour cron, code standards)
- User behavior tracking (navigation, search, preset promotion, pruning)
- AliceContext + AliceHintBar + GetHelpDialog (React)
- Django signals → agent bus (5 transaction types)
- Alice models: AliceObservation, AlicePreset, AliceCoachingLog
- Code standards enforcement (7 anti-patterns, scheduled + on-demand + git hook)

### Documentation (531 records)
- 64 field docs (wc2 cross-referenced), 68 React docs, 160 v20 form assessments
- 156 v19 table forms, 56 method/feature assessments, 8 training docs, 19 reports, 8 action records

### DataBrowser
- Fixed model switching race condition, removed duplicate buttons, consolidated toolbars
- User prefs → contact.metadata, data-wc attributes everywhere, alice_guess + alphabetical layouts (62 models)
- Fixed workbench settings loading bug (parent_model not model_name)

### Data Model
- commission JSONField on all 12 transaction tables
- vendor_id + manufacturer_id FKs on Item
- AliceObservation, AlicePreset, AliceCoachingLog tables

## 16 Design Decisions Answered
1-2: conditions=legal docs w/ content_hash; terms varchar+FK both stay
3-4: priority=integer 1-5; finance schema=Setting
5-6: commission at earliest chain point; per-line (price levels differ)
7-8: org.data=freeform; org.relations=freeform (parent/vendor/rep common)
9-10: contact.other_id=delete; specification_id=active
11-12: warranty JSON defined; tax=MCP server pointer
13-14: status+kanban both stay; DocumentIndex=qqq_
15-16: specialty pages=Dashboards; migrate all lists to DataGrid

## In Progress
- DataGrid migration of 82 list pages + LinesCard (agents running)
- qwen2.5:72b model download
- wc2 scrub agents completing

## Next Session Priority
1. **Document conversion chain** — Proposal→Order→Invoice→Payment (THE #1 gap)
2. **Pricing engine** — price matrix, level resolution, qty breaks
3. **Inventory Dashboard** — receive/adjust/warehouse/reconcile consolidated
4. Test the services built tonight against real transactions
5. Walk through the wc2 flow charts with Allie and Alice
