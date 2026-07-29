# ACTION — Connect Hostinger Sites to Git Deploy
**Owner:** Bill James
**Created:** 2026-07-29
**Due:** 2026-08-05 (next week)
**Status:** Open

## Task

Connect each Hostinger site to its GitHub repo for auto-deploy. Make a training video.

## Steps per site

1. Hostinger dashboard → select domain
2. Advanced → Git
3. Select repo from JPods org
4. Branch: main
5. Directory: public_html
6. Enable auto-deploy
7. Click Deploy to trigger first pull

## Sites to connect

| Domain | GitHub Repo | Status |
|--------|-----------|--------|
| cityroadkills.com | JPods/cityroadkills | DONE ✓ |
| primelawofnetworks.com | JPods/primelawofnetworks | Connect |
| personalizetransit.com | JPods/personalizetransit | Connect |
| jpods3d.com | JPods/jpods3d | Connect |
| physicalinternet.com | JPods/physicalinternet | Connect |
| 10xmakers.com | JPods/10xmakers | Connect |
| 5x5freemarket.com | JPods/5x5freemarket | Connect |
| smallstings.com | JPods/smallstings | Connect |

## After connecting

Workflow for all sites becomes:
```bash
cd ~/Allie/sites/[sitename]
git add -A && git commit -m "description" && git push
# Hostinger auto-deploys
```

## Training video

Record the process for one site (e.g., primelawofnetworks.com) showing:
- Hostinger dashboard navigation
- Git connection setup
- First deploy
- Edit → commit → push → verify live
