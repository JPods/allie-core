# Handoff — 2026-08-20 morning session

## Where We Left Off

Payment model fully wired with four fields (amount, available, tendered, change) matching WC2. Ledger integration updated to use `available` not `amount`. Onboarding checklist and Phase 1 flight sims built. Bill added company-profile and admin-tools sim entries to the frontend — backend scenarios still needed.

## What Was Done This Session
- Payment model: added `available`, `tendered`, `change` fields, migrations applied
- Wired `available` into all behaviors (serializer, apply, unapply, validation, ledger, org financial)
- Ledger now uses `available` not `amount` — matches WC2 `Ledger_PaySave`
- `update_org_balances()` computes `available_payments` — matches WC2 `Ledger_TallyBal`
- Payment Lifecycle flight sim (8 steps) + flowchart (.dot + .svg) + readme
- Onboarding checklist readme (5 phases, 15 exercises)
- Three Phase 1 flight sims: Your First Customer, Your First Item, Your First Sale
- Bill added company-profile sim and admin-tools sim entries

## TODO — When We Get Back

### Must Test
- [ ] Payment system end-to-end: create payment, apply to invoice, check available decrements, check ledger, journal
- [ ] Phase 1 flight sims in browser: do all 3 load, can user create records, does quantity panel update
- [ ] Payment Lifecycle flight sim in browser

### Must Build
- [ ] Company Profile flight sim — backend scenario (Bill added frontend entry, needs `get_company_profile_scenario()`)
- [ ] Admin Tools flight sim — backend scenario (Bill added frontend entry, needs scenario)
- [ ] Data migration: set `available = amount` for existing Payment records created before field existed

### Should Review
- [ ] WC2 models not yet in WC3: Carrier, Marketing, Territory, Quota, Template, LoadTag
- [ ] Athena fault: `/var/www/webclerk-static/sort/index.html` MISSING on Andi (recurring)
- [ ] SessionGuard fault: `useDataBrowser.ts` contains JSX — rename to `.tsx`

## Key Files Touched
- `apps/transactions/models/payment.py` — 3 new fields + save() logic
- `apps/transactions/serializers/payment_serializers.py` — fields + read_only
- `apps/transactions/services/payment_pending.py` — _apply_one() decrements available
- `apps/transactions/services/payment_application.py` — unapply increments available
- `apps/transactions/models/payment_application.py` — clean() validates against available
- `apps/accounts/services/ledger_balance.py` — on_payment_save uses available, update_org_balances computes available_payments
- `apps/accounts/services/terms_ledger.py` — record_payment splits value_original vs value_available
- `apps/products/services/onboarding_flight_sim.py` — NEW: 3 Phase 1 scenarios
- `apps/products/services/inventory_flight_sim.py` — added get_payment_flight_scenario()
- `apps/core/views/manage_view.py` — 4 new manage actions
- `React2025/src/pages/admin/FlightSimConsole.tsx` — 3 new sims, itemIda-optional flow
- `React2025/src/components/cards/FlightSimCard.tsx` — 3 new card entries
- `readmes/topics/transactions/payment-lifecycle.md` — NEW
- `readmes/topics/transactions/onboarding-checklist.md` — NEW
- `readmes/flowcharts/wc3-payment-lifecycle.dot` + `.svg` — NEW
