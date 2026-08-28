# Handoff — 2026-08-27

## Where We Left Off

Full backend naming & structure cleanup complete (366 files). Services grouped into behavioral subdirectories (convert/, payment/, fulfillment/, pricing/, dashboard/, inventory/, serial/). All `id_` prefix fields renamed to `_id` suffix with migrations applied. Service model deleted — replaced with `Item.config.service` dictionary. Bundles, Settings, and Reports scrubbed for compliance. 5 commits on main, not yet pushed (GitHub auth needed).

Segmented Kanban project selector built — time-bucketed dropdown using `dt_kanban`. Still working on Kanban features.

## Do This First Next Session

1. **Push to bill_dev** — 5 commits on main need pushing. `git push origin main:bill_dev` (and main if requested). GitHub auth may need `gh auth login`.

2. **Kanban task card project move** — Bill wants a select list on task cards to move actions between projects. Two sections: same-parent projects + 4-week window projects.

3. **Kanban contact +add button** — wire to existing `ProjectContactManager` component.

4. **Transaction serializer dedup** — `transaction_serializers.py` mega-file has duplicate class definitions. Split into per-model files per naming plan.

5. **Verify UI renders correctly** — DataBrowser, Kanban with new segmented selector, confirm renamed fields display properly.

## Open Problems

- Duplicate serializer classes in `transactions/serializers/` — `InvoiceSerializer`, `OrderSerializer` etc. defined in two files
- `pricing.py` → `price_resolver.py` merge left `resolve_price_legacy` function — review needed
- Parallel agent import fixes missed 6 files — always run `manage.py check` (not just `django.setup()`) after refactoring

## Scars From This Session

- **Parallel agent import gap**: 9 agents reported clean but 6 files had stale imports. `django.setup()` doesn't load URLs. `manage.py check` is the correct verification.
- **Setting.config protection**: Surgical JSON updates require `_setting_update_authorized = True`. Never re-seed to fix field names — that destroys accumulated config.
