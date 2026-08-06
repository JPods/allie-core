# Handoff — 2026-08-05 (evening session 4)

## Where We Left Off

Massive session: Matrix Builder, JSON Tree enhancements, 5 app dashboards, Statement Sorter Excel support (deployed to webclerk.com/sort), and complete Spreedly payment gateway backend. Go-live todo updated — Phase 1 complete, Phase 2 backend complete, Phase 3 packing complete.

## Do This First Next Session

1. **Deploy React2025 to Andi** — new app dashboards, JSON Tree enhancements, ProductsDashboard all need to reach production. Build + rsync + reload nginx.
2. **Deploy WC3 backend to Andi** — SelfConnection, payment_gateway Setting, seed_company_settings (paths.bundles), payment_gateways.py (Spreedly service), updated choices/urls/views. Run: `seed_self_connection`, `seed_payment_gateway`, `seed_company_settings`.
3. **Payment processing frontend UI** — Spreedly Web SDK hosted fields iframe. This is the only Phase 2 blocker. The backend is complete; the checkout UI needs the client-side SDK (script tag, iframe mount for card/CVV, token callback → POST /payments/process/).
4. **Review go-live todo for next items** — Phase 3 Shipping (#3) is the critical path. 4 carrier integrations unchecked. Or continue Phase 4 Product detail pages.

## Open Problems

- **Payment frontend not built** — backend complete, no client-side Spreedly SDK integration yet. Need: hosted fields iframe, token callback, Apple Pay/Google Pay/3D Secure (all optional but valuable).
- **Square not in Spreedly** — if a user needs Square, it would require a direct integration alongside Spreedly.
- **App dashboard stats are N+1** — one API call per model count. Works fine for now; could batch later.
- **Matrix Builder is standalone HTML** — not yet served from WC3. The Products dashboard links to it as `external`. When deployed to WC3, update the path.
- **Tax on shipping** — `tax.shipping` rate not populated by `applyCustomerDefaults` yet (jurisdiction's `tax_rate_on_shipping` needs to flow into transaction's `tax` envelope).
- **Design tokens vs DataBrowser CSS drift** — `design-tokens.json` palette vs `DataBrowser.css` palette. Not broken, inconsistent.

## What Was Decided (and Why)

- **Spreedly over direct gateway integrations** — one backend, 100+ gateways. User picks their gateway in Settings. Eliminates gateway-specific server code. Bill chose this over Stripe-only or multi-direct.
- **Token-in-a-token** — WC3 stores only reference IDs (pm_token, last4, brand, exp, fingerprint). Never card data. Bill: "I NEVER want to store credit card information again. If we have to, it needs to be in a token, in a token." Non-negotiable axiom.
- **App dashboards over model dashboards** — users think in domains (Products, Transactions, Orgs) not data models (Item, Variant, BOM). Sidebar shows domains; DataBrowser handles individual models. Sync folded into Support.
- **Bundle is the universal pipeline** — Matrix Builder, JSON Tree, conversion framework all produce bundles. One receive endpoint, many sources.
- **JPods volume note** — massive daily transactions will need async processing, connection pooling, batch settlement. Revisit before ticketing goes live.

## Files Changed This Session

**React2025:**
- `src/pages/tools/JsonTreeApplet.tsx` — save, post bundle, drop zone, file path, matrix-builder handoff
- `src/apps/products/pages/ProductsDashboard.tsx` — new: app dashboard
- `src/apps/transactions/pages/TransactionsDashboard.tsx` — new: app dashboard
- `src/apps/orgs/pages/OrgsDashboard.tsx` — new: app dashboard
- `src/apps/support/pages/SupportDashboard.tsx` — new: app dashboard (includes Sync)
- `src/apps/sync/pages/SyncDashboard.tsx` — new: app dashboard (standalone route still works)
- `src/routes/protectedRoutesConfig.tsx` — 5 new dashboard routes
- `src/layout/AppSidebar.tsx` — app dashboard entries, icons, routes, display names
- `readmes/topics/payments.md` — gateway architecture, token-in-a-token spec
- `readmes/todo-go-live.md` — Phase 2 payment complete, JPods volume note, phase summary

**webClerk3:**
- `apps/transactions/services/payment_gateways.py` — replaced Stripe/PayPal with SpreedlyService
- `apps/transactions/views/payment_views.py` — process_payment, refund_payment_view, spreedly_webhook
- `apps/transactions/urls.py` — refund endpoint, spreedly webhook
- `apps/transactions/choices.py` — gateway choices: manual + spreedly
- `apps/transactions/management/commands/seed_payment_gateway.py` — new: Setting #625
- `apps/sync/management/commands/seed_self_connection.py` — new: Connection #31
- `apps/core/management/commands/seed_company_settings.py` — config.paths.bundles
- `apps/core/choices.py` — payment_gateway added to SETTING_PURPOSE_CHOICES
- `readmes/payment-application-design.md` — Spreedly + token rule header

**Allie:**
- `sites/matrixbuilder/index.html` — new: standalone matrix builder applet
- `sites/statement_sorter/index.html` — Excel support (.xls/.xlsx), deployed to Andi
- `readmes/retrospections/2026-08-05.md` — Session 4 retrospection appended
