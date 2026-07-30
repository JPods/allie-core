# Hostinger — Configuration Notes for JPods Sites

## Account

- **Plan:** Business Web Hosting (28 of 100 websites)
- **Account:** bill.james@jpods.com
- **Member since:** 2022-03-10
- **2FA:** Enabled
- **GitHub:** Connected to JPods organization

---

## Deployment — Use Git, Not SSH

**Use Git push → auto-deploy for all static sites.** Do not use SSH.

**Why Git, not SSH:**
- Git push → auto-deploy is one command, live in seconds
- Git gives version history — every deploy is a commit you can roll back
- Git is the backup — GitHub has the code, Hostinger serves it, Mac is source of truth
- SSH adds a manual step (rsync/scp) — unnecessary for static HTML sites
- Hostinger File Manager works for debugging if needed — no SSH required

**SSH would only matter if** running Python, Node, or a database on Hostinger. All JPods sites are static HTML/CSS/JS. Git deploy is the right tool.

**Workflow:**
```bash
cd ~/Allie/sites/cityroadkills
# edit files
git add -A && git commit -m "description" && git push
# Hostinger auto-deploys from GitHub
```

**Setup per site:**
1. Create GitHub repo under JPods org (e.g., JPods/cityroadkills)
2. Push site files to repo
3. In Hostinger dashboard for that domain → Advanced → Git
4. Connect repo, branch: main, directory: public_html
5. Enable auto-deploy

**GitHub repos for sites:**
- `JPods/cityroadkills` → cityroadkills.com

---

## Sites on Hostinger

| Domain | Source | Deploy method | Status |
|--------|--------|--------------|--------|
| jpods.com | WordPress + static | Manual / File Manager | Live (has malware-prone WP) |
| library.jpods.com | WordPress | Manual | Live (Divi theme compromised 3x) |
| cityroadkills.com | ~/Allie/sites/cityroadkills | Git auto-deploy | Live |
| jpods3d.com | ~/Allie/sites/jpods3d | Manual upload | Live |
| personalizetransit.com | ~/Allie/sites/personalizetransit | Manual upload | Needs deploy |
| primelawofnetworks.com | ~/Allie/sites/primelawofnetworks | Manual upload | Needs deploy |
| physicalinternet.com | ~/Allie/sites/physicalinternet | Manual upload | Needs deploy |
| 10xmakers.com | readmes/capital-pages/10xMakers.com | Manual upload | Live |
| meshmobility.com | Andi (Flask app) | Not on Hostinger | On Andi |
| webclerk.com | Andi (Django app) | Not on Hostinger | On Andi |

**Migration plan:** Create GitHub repos for each static site, connect to Hostinger, switch to git deploy. Priority: sites that change frequently.

---

## Security

- **Malware:** Hostinger scans automatically. 3 compromised Divi theme files found 2026-07-28, auto-cleaned.
- **Root cause:** Old WordPress installs at jpods.com — `/public_html/jpods-04-02-2026/` (deleted) and `/public_html/library/` (still active).
- **Action:** Migrate library.jpods.com from WordPress to static. 452 pages harvested 2026-07-29 to ~/Allie/knowledge/library/.
- **2FA:** Enabled on Hostinger account.

---

## Subdomain Redirects

When `library.jpods.com` shares the same Hostinger dashboard as `jpods.com`,
`.htaccess` exceptions on the root domain are **not sufficient** to prevent
the subdomain from intercepting requests. Use Hostinger's built-in Redirect
tool instead.

### How to Add a Redirect in Hostinger

1. Log into Hostinger dashboard
2. In the **left sidebar**, find the website name (e.g. `jpods.com`)
3. Click **Domain → Redirects**
4. Add source and destination URLs:

| Source (From) | Destination (To) |
|---|---|
| `https://library.jpods.com/70.html` | `https://jpods.com/70.html` |
| `https://library.jpods.com/personalizetransit.html` | `https://jpods.com/personalizetransit.html` |

5. Use **302 (temporary)** while testing
6. Switch to **301 (permanent)** once confirmed working

### When to Use This

Any new file served from the root `jpods.com` that was previously routed
through `library.jpods.com` will need a redirect entry here. This includes:
- New standalone HTML pages (e.g. `70.html`, `personalizetransit.html`)
- Any path that existed on the old WordPress library site

---

## Root Domain .htaccess — Exceptions List

Files served directly from `jpods.com` root must be whitelisted in
`/public_html/.htaccess` **before** the catch-all redirect rule.

```apache
RewriteEngine On
# Allow direct access to landing page assets
RewriteRule ^index\.html$    - [L]
RewriteRule ^70\.html$       - [L]
RewriteRule ^personalizetransit\.html$ - [L]
RewriteRule ^images/         - [L]
RewriteRule ^networks/       - [L]
RewriteRule ^favicon         - [L]
RewriteRule ^robots\.txt$    - [L]
RewriteRule ^sitemap         - [L]
# Redirect everything else to library subdomain
RewriteCond %{HTTP_HOST} ^(www\.)?jpods\.com$ [NC]
RewriteCond %{REQUEST_URI} !^/?$ [NC]
RewriteRule ^(.+)$ https://library.jpods.com/$1 [R=302,L]
# Redirect www → non-www
RewriteCond %{HTTP_HOST} ^www\.jpods\.com$ [NC]
RewriteRule ^(.*)$ https://jpods.com/$1 [R=301,L]
```

> **Note:** Use `R=302` on the library catch-all while actively making
> changes. Switch back to `R=301` once routing is stable to enable
> browser caching.

---

## Chrome Redirect Cache — Hard Reset

If Chrome keeps redirecting to a stale destination after `.htaccess` changes:

1. Open DevTools (`F12` or `Cmd+Option+I`)
2. Right-click the **refresh button**
3. Select **Empty Cache and Hard Reload**

Or clear HSTS/DNS cache:
- `chrome://net-internals/#hsts` → Delete domain security policies
- `chrome://net-internals/#dns` → Clear host cache

> Safari, Firefox, and incognito are unaffected by Chrome's cached 301s.
> If only Chrome shows the wrong redirect, this is always the fix.