# Handoff — 2026-08-11

## Where We Left Off

Built the documentation distribution layer: 33 enriched SVG flowcharts deployed to Andi (webclerk.com/wc-works/), codemap.guru flowchart library with summaries, jsondriven.com Design Mode animation, and Statement Sorter → Payment.expense codemap. Added nav links to webclerk.com landing page (How It Works, JSON Driven, CodeMap). Fixed the inventory bucket diagram — `available = on_hand - allocated` per Item.save line 493, added allocated/on_r buckets, WO Completion routes through Receipt, on_in drives on_hand change.

## Do This First Next Session

1. **Alice readme updates** — alice.md is stale (last updated 2026-07-03). Update with current MCP tool signatures. Create `alice-mcp-tools.md` documenting all 5 tools (ask_alice, alice_search, alice_observe, alice_recall, alice_quiz) with category enums and examples. Audit found: ask_alice has 7 undocumented category filters, quiz has 6 undocumented categories.
2. **Load seed fixture** — run `python manage.py loaddata wc_works_seed` on both local and Andi to create the "How WebClerk Works" Document record (purpose=wc-works, points to webclerk.com/wc-works/).
3. **Verify Hostinger deployments** — check codemap.guru and jsondriven.com rendered correctly after git push auto-deploy. The codemap.guru flowchart library section and jsondriven.com animation are new.
4. **Statement Sorter example** — load `sites/statement_sorter/example-statement.csv` into the sorter and classify the 36 transactions as a demo walkthrough. Consider screenshot for codemap.guru.
5. **Retrospection** — not written this session. Write to `readmes/retrospections/2026-08-11.md`.

## Open Problems

- Alice readme coverage is uneven — observations/dedup/escalation are current, main alice.md and coaching are stale
- codemap.json `purchase` node still flags GAP: +on_po pending record not created in order_to_purchase.py
- `on_reciept` typo in Item model canonical keys (line 168) — should be `on_receipt`
- webclerk.com landing page edit was done directly on Andi, not synced back to landing source at `/Volumes/Allie/webclerk.net/`

## What Was Decided (and Why)

- **One Document record per install** (not 64) — points to webclerk.com/wc-works/ index page. Reason: one pointer, zero maintenance per install, SVGs update at WC_HQ without sync.
- **Andi is the library** — edit in place via SSH, no deploy scripts. Zip locally for offline flights. Reason: eliminates rsync/deploy friction; local network SSH is fast.
- **codemap.guru and jsondriven.com stay on Hostinger** — git push auto-deploys. Andi hosts the SVGs at wc-works/. Reason: Hostinger handles DNS/SSL for those domains; Andi handles webclerk.com.
- **available = on_hand - allocated** (not on_hand - on_so + on_po + on_wo) — verified at Item.save line 493 and pending_inventory_processor.py line 268. The old formula was never in the code.

## Files Changed This Session

- `sites/jsondriven/index.html` — added 30s Design Mode drag-and-drop CSS/JS animation
- `sites/wc-works/index.html` — new: flowchart index page with 33 cards, search, categories
- `sites/codemap/index.html` — added flowchart library section (33 cards with summaries)
- `sites/statement_sorter/example-statement.csv` — new: 36 mixed business/personal transactions
- `readmes/flowcharts/wc3-inventory-buckets.dot` — fixed available formula, added allocated/on_r, arrow corrections
- `readmes/flowcharts/wc3-statement-sorter.dot` — new: Statement Sorter → Payment.expense pipeline
- `readmes/flowcharts/codemap.json` — added allocated, on_r, statement_sorter, payment, expense, action, document nodes
- `readmes/flowcharts/*.enriched.dot` + `*.enriched.svg` — all 33 flowcharts re-enriched
- `scripts/deploy-wc-works.sh` — new: deploy script (historical — Andi is now edited in place)
- `archive/wc-works.zip` — offline bundle (157K, not in git)
- `/opt/andi/apps/webclerk3/landing/index.html` (on Andi) — added How It Works, JSON Driven, CodeMap nav links
- `/var/www/webclerk-static/wc-works/` (on Andi) — new: index page + 33 SVGs + nginx location
- `/etc/nginx/sites-enabled/webclerk3` (on Andi) — added /wc-works/ location block
- WC3 `apps/docs/fixtures/wc_works_seed.json` — new: seed fixture for How WebClerk Works Document record
