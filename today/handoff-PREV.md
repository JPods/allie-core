# Handoff — 2026-08-24

## Where We Left Off

PJPV compliance sweep complete and shipped (commit 5c499c95, main + bill_dev). 66 files, -251 net lines. Customer seeding done — 6 customers with full contact/email/address/phone records in commerce_expert.

## Do This First Next Session

1. **Recommit the 7 reverted changes** — real fixes that were reverted to keep PJPV commit clean:
   - `base_line_model.py` — update_fields auto-expansion (bug fix)
   - `connection.py` — comment→comments (bug fix)
   - `payment_serializers.py` — payment_method FK cleanup
   - `transaction_views.py` — filterset fix
   - `urls.py` — DataBrowser legacy routes (blocks DataBrowser model loading)
   - `TransactionItemSearch.tsx` — DbColumns refactor
   - `wcapi-system-endpoints.md` — path correction

2. **Flight simulator live testing** — verify item search columns, DbColumns gear icon, full Proposal→Order→Invoice→Payment flow

3. **Statement Sorter connection + bundle review** — TODO sent to Alice (#1084)

## Open PJPV Gaps

- `ShoppingCart.tsx` — full client-side pricing engine, needs server cart totals endpoint
- No schema endpoint for Pydantic field titles (not urgent — lowercase field names are the standard)

## Key Decisions This Session

- **Labels = lowercase field names** — users learn case sensitivity by seeing real names
- **Same-envelope fallback = correct** — `totals.balance ?? totals.total` is business logic, not a PJPV violation
- **Print documents show $0.00 for null** — `printTypes.ts` wrapper; all other contexts show blank
- **Agent scrub is mandatory** — 3 of 4 agents exceeded scope; scrub caught 7 unrelated changes (Scar #71)
