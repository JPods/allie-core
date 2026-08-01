# Handoff — 2026-08-01 (Session 2, updated post-deploy)

## Where We Left Off
Built and deployed full WebClerk ecosystem to webclerk.com:

- **webclerk.com/sort** — Statement Sorter, Athena-signed, live
- **webclerk.com/app/** — Full React app (DataBrowser, Gantt, all WC3), live with commerce_expert data (9,412 contacts)
- **webclerk.com/wcapi/** — Django API, live, requires auth
- **webclerk.com/admin/** — Django admin, live

Also built and deployed Athena integrity verification system:
- `athena_sign` management command on Andi — signs files, manages manifest
- `task_athena_verify` Celery task — runs every 4 hours, hashes all checkpoints
- Document ida='athena-manifest' — 5 checkpoints signed and verified
- Immediate FAULT files on integrity failure

Key fixes during deploy:
- `SECURE_PROXY_SSL_HEADER` added (Cloudflare terminates SSL, Nginx forwards HTTP)
- `X-Forwarded-Proto: https` forced in Nginx (Cloudflare→Nginx is HTTP)
- `/assets/` aliased to React dist (was pointing to landing page)
- Permissions fixed on `/opt/andi/apps/react2025/dist/`
- Database: `commerce_expert` pg_dump'd from Mac, restored on Andi, `webclerk` user granted access

## Do This First Next Session
1. **Verify webclerk.com/sort is publicly accessible** — check through Cloudflare (may need a CF rule or DNS check if not already proxying /sort)
2. **Set up git repo** — Bill said he'd create one; push index.html, readme.md, sign.py
3. **Light/dark mode** — CSS custom properties theme system, reusable across WC list views
4. **Draggable column ORDER** — not just width; save order to localStorage prefs
5. **Description search filter** — text input to narrow by description substring
6. **Extract db.list standard** — pull selection/A+-/resize/column-order patterns into documentation or shared module

## Open Problems
- CSP hash in Nginx must be updated whenever the script changes — needs automation (sign.py could ssh and update)
- `showSaveFilePicker` only works in Chrome/Edge — Firefox users get fallback download (no location picker)
- Confidence algorithm is basic — could improve with token overlap scoring
- Custom categories typed in "or type..." (removed this session) had no way to assign business/personal — the field was removed but the concept needs a solution if users want truly custom categories

## What Was Decided (and Why)
- **No checkboxes — row is the selection target** — click/shift/cmd standard for all WC list views. Documented at `webClerk3/readmes/topics/ui/list-selection-standard.md`
- **Category implies classification** — picking a category from Business or Personal group auto-sets the classification. Less is more. One action does two things.
- **Decision columns in the center** — date → recommended → conf → category → class → amount → source → description → bank_cat. Left-justified description pushed to the right so decision columns stay centered on screen.
- **Tools above where they are applied** — toolbar row ordering matches data column positions below. Accept Recommendations above recommended column.
- **Always start clean** — no localStorage auto-load. Public users must not see someone else's data (there is no "someone else's data" — it's all client-side, but the UX should reinforce that).
- **Merchant memory via rules.json** — users save learned classifications between years. This is the upgrade path to WebClerk: free tool learns → full platform (Alice) learns automatically.
- **Athena integrity check** — dual layer: script self-hash + Nginx CSP header. If the file is tampered, the page refuses to function.
- **db.list standard behaviors** — Bill: "all our list efforts should default to db.list A+- behaviors." Row selection, A+-, draggable column widths, column reorder, tools above data, category-drives-classification, localStorage prefs.

## Files Changed This Session
- `sites/statement_sorter/index.html` — Complete rebuild: toast messages, folder drop, row selection, grouped categories, merchant learning, recommendations, A+-, column resize, Athena integrity
- `sites/statement_sorter/readme.md` — Folder organization guide for users
- `sites/statement_sorter/sign.py` — Athena signing script
- `webClerk3/readmes/topics/ui/list-selection-standard.md` — WC list selection standard
- `readmes/retrospections/2026-08-01.md` — Appended Session 2 retrospection
- Andi: `/var/www/webclerk-static/sort/index.html` — deployed
- Andi: `/etc/nginx/sites-enabled/webclerk3` — added /sort location + CSP header
