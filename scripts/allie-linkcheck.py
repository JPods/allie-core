#!/usr/bin/env python3
"""Dead link checker — weekly site maintenance for all JPods web properties.

Crawls each site's key pages, tests every link, reports broken ones.
Creates Alice Action records for dead links found.

Usage:
    python3 allie-linkcheck.py                  # check all sites, report to stdout
    python3 allie-linkcheck.py --actions        # also create WC3 Action records
    python3 allie-linkcheck.py --site mm        # check only meshmobility.com
    python3 allie-linkcheck.py --json           # output JSON to process/inbox/

Sites: meshmobility.com, webclerk.com, jpods.com, 5x5FreeMarket.com,
       ClimateChangeRootCause.com, betterphysics.com, 10xmakers.com,
       library.jpods.com

Runs on Andi (IT15) via Celery beat, Monday 06:00 UTC.
"""
import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin, urlparse

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("Install: pip install requests beautifulsoup4")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Sites and their key pages to crawl
# ---------------------------------------------------------------------------

SITES = {
    "mm": {
        "name": "MeshMobility",
        "base": "https://meshmobility.com",
        "pages": ["/", "/app", "/library"],
        "customer_facing": True,
    },
    "pt": {
        "name": "Personalize Transit",
        "base": "https://personalizetransit.com",
        "pages": ["/"],
        "customer_facing": True,
    },
    "wc": {
        "name": "WebClerk",
        "base": "https://webclerk.com",
        "pages": ["/"],
        "customer_facing": True,
    },
    "jpods": {
        "name": "JPods",
        "base": "https://www.jpods.com",
        "pages": ["/", "/STEM"],
        "customer_facing": True,
    },
    "5x5": {
        "name": "5X5 FreeMarket",
        "base": "https://www.5x5FreeMarket.com",
        "pages": ["/"],
        "customer_facing": True,
    },
    "climate": {
        "name": "Climate Change Root Cause",
        "base": "https://www.ClimateChangeRootCause.com",
        "pages": ["/"],
        "customer_facing": True,
    },
    "bp": {
        "name": "BetterPhysics",
        "base": "https://betterphysics.com",
        "pages": ["/"],
        "customer_facing": False,
    },
    "10x": {
        "name": "10xMakers",
        "base": "https://10xmakers.com",
        "pages": ["/"],
        "customer_facing": False,
    },
    "lib": {
        "name": "JPods Library",
        "base": "https://library.jpods.com",
        "pages": ["/congressionalstudy/"],
        "customer_facing": False,
    },
    "sub": {
        "name": "JPods Substack",
        "base": "https://jpods.substack.com",
        "pages": ["/"],
        "customer_facing": False,
    },
}

# ---------------------------------------------------------------------------
# Link extraction
# ---------------------------------------------------------------------------

# JS patterns: window.open('url', ...) and window.location.href = 'url'
JS_LINK_RE = re.compile(
    r"""window\.open\s*\(\s*['"]([^'"]+)['"]"""
    r"""|window\.location\.href\s*=\s*['"]([^'"]+)['"]""",
    re.IGNORECASE,
)

# fetch() calls
FETCH_RE = re.compile(r"""fetch\s*\(\s*['"]([^'"]+)['"]""", re.IGNORECASE)


def extract_links(html: str, base_url: str) -> list[dict]:
    """Extract all links from HTML content."""
    soup = BeautifulSoup(html, "html.parser")
    links = []
    seen = set()

    def _add(url: str, kind: str, text: str = ""):
        if not url or url.startswith("#") or url.startswith("javascript:"):
            return
        if url.startswith("mailto:") or url.startswith("tel:"):
            return
        full = urljoin(base_url, url)
        if full in seen:
            return
        seen.add(full)
        links.append({"url": full, "raw": url, "kind": kind, "text": text.strip()[:80]})

    # <a href>
    for a in soup.find_all("a", href=True):
        _add(a["href"], "href", a.get_text())

    # <link href> (stylesheets, etc.)
    for link in soup.find_all("link", href=True):
        _add(link["href"], "resource", link.get("rel", [""])[0])

    # <script src>
    for script in soup.find_all("script", src=True):
        _add(script["src"], "script", "")

    # <img src>
    for img in soup.find_all("img", src=True):
        _add(img["src"], "image", img.get("alt", ""))

    # JS window.open and location.href
    for script in soup.find_all("script"):
        if script.string:
            for m in JS_LINK_RE.finditer(script.string):
                url = m.group(1) or m.group(2)
                _add(url, "js-open", "")

    # JS fetch() — these are API endpoints
    for script in soup.find_all("script"):
        if script.string:
            for m in FETCH_RE.finditer(script.string):
                _add(m.group(1), "fetch-api", "")

    # onclick attributes with window.open
    for el in soup.find_all(attrs={"onclick": True}):
        onclick = el["onclick"]
        for m in JS_LINK_RE.finditer(onclick):
            url = m.group(1) or m.group(2)
            _add(url, "onclick", el.get_text().strip()[:80])

    return links


# ---------------------------------------------------------------------------
# Link checking
# ---------------------------------------------------------------------------

SESSION = requests.Session()
SESSION.headers["User-Agent"] = "AllieLinkCheck/1.0 (JPods site maintenance)"


def check_url(url: str, timeout: int = 10) -> dict:
    """Check if a URL is reachable. Returns status dict."""
    try:
        # HEAD first (cheaper), fall back to GET
        r = SESSION.head(url, timeout=timeout, allow_redirects=True)
        # Some servers reject HEAD — retry with GET
        if r.status_code >= 400:
            r = SESSION.get(url, timeout=timeout, allow_redirects=True)

        # Detect CF Access redirect (login wall)
        cf_access = False
        if r.history:
            for redir in r.history:
                if "cloudflareaccess.com" in (redir.headers.get("Location", "")):
                    cf_access = True
                    break
        if "cloudflareaccess.com" in r.url:
            cf_access = True

        return {
            "status": r.status_code,
            "ok": 200 <= r.status_code < 400 and not cf_access,
            "cf_access": cf_access,
            "final_url": r.url if r.url != url else None,
            "error": None,
        }
    except requests.exceptions.Timeout:
        return {"status": 0, "ok": False, "cf_access": False, "final_url": None,
                "error": "timeout"}
    except requests.exceptions.ConnectionError as e:
        return {"status": 0, "ok": False, "cf_access": False, "final_url": None,
                "error": f"connection error: {str(e)[:100]}"}
    except Exception as e:
        return {"status": 0, "ok": False, "cf_access": False, "final_url": None,
                "error": str(e)[:100]}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def check_site(site_key: str, site_cfg: dict) -> list[dict]:
    """Check all links on a site. Returns list of results."""
    results = []
    base = site_cfg["base"]
    name = site_cfg["name"]

    for page_path in site_cfg["pages"]:
        page_url = base + page_path
        print(f"\n  Fetching {page_url} ...", end=" ", flush=True)

        page_check = check_url(page_url)
        if not page_check["ok"]:
            problem = "CF Access login wall" if page_check["cf_access"] else \
                      page_check["error"] or f"HTTP {page_check['status']}"
            results.append({
                "site": name, "page": page_path, "link_url": page_url,
                "raw": page_path, "kind": "page", "text": "",
                "status": page_check["status"], "ok": False,
                "problem": f"Page itself unreachable: {problem}",
                "customer_facing": site_cfg["customer_facing"],
                "cf_access": page_check["cf_access"],
            })
            print(f"BLOCKED ({problem})")
            continue

        # Fetch page content for link extraction
        try:
            r = SESSION.get(page_url, timeout=15)
            html = r.text
        except Exception as e:
            print(f"ERROR ({e})")
            continue

        links = extract_links(html, page_url)
        print(f"{len(links)} links found")

        for link in links:
            time.sleep(0.5)  # polite delay
            result = check_url(link["url"])

            entry = {
                "site": name, "page": page_path,
                "link_url": link["url"], "raw": link["raw"],
                "kind": link["kind"], "text": link["text"],
                "status": result["status"], "ok": result["ok"],
                "cf_access": result["cf_access"],
                "problem": None,
                "customer_facing": site_cfg["customer_facing"],
            }

            if not result["ok"]:
                if result["cf_access"]:
                    entry["problem"] = "Blocked by Cloudflare Access (login wall)"
                elif result["error"]:
                    entry["problem"] = result["error"]
                else:
                    entry["problem"] = f"HTTP {result['status']}"

            if entry["problem"]:
                sym = "🔴" if site_cfg["customer_facing"] else "🟠"
                print(f"    {sym} BROKEN: {link['raw'][:60]} → {entry['problem']}")
            results.append(entry)

    return results


def main():
    parser = argparse.ArgumentParser(description="Dead link checker for JPods web properties")
    parser.add_argument("--site", help="Check only this site key (mm, wc, jpods, etc.)")
    parser.add_argument("--actions", action="store_true",
                        help="Create WC3 Action records for dead links")
    parser.add_argument("--json", action="store_true",
                        help="Save JSON report to process/inbox/")
    args = parser.parse_args()

    sites = {args.site: SITES[args.site]} if args.site else SITES
    all_results = []

    print(f"Link check started: {datetime.now(timezone.utc).isoformat()}")
    print(f"Checking {len(sites)} site(s)...")

    for key, cfg in sites.items():
        print(f"\n{'='*60}")
        print(f"Site: {cfg['name']} ({cfg['base']})")
        results = check_site(key, cfg)
        all_results.extend(results)

    # Summary
    broken = [r for r in all_results if not r["ok"]]
    cf_blocked = [r for r in broken if r.get("cf_access")]
    dead = [r for r in broken if not r.get("cf_access")]
    red_flags = [r for r in broken if r["customer_facing"]]

    print(f"\n{'='*60}")
    print(f"SUMMARY")
    print(f"  Total links checked: {len(all_results)}")
    print(f"  OK:                  {len(all_results) - len(broken)}")
    print(f"  CF Access blocked:   {len(cf_blocked)}")
    print(f"  Dead links:          {len(dead)}")
    print(f"  Red flags (public):  {len(red_flags)}")

    if broken:
        print(f"\nBROKEN LINKS:")
        for r in broken:
            flag = "🔴" if r["customer_facing"] else "🟠"
            print(f"  {flag} [{r['site']}] {r['page']} → {r['raw'][:50]} — {r['problem']}")

    # Save JSON
    if args.json:
        inbox = Path.home() / "Allie" / "process" / "inbox"
        inbox.mkdir(parents=True, exist_ok=True)
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        path = inbox / f"linkcheck-{ts}.json"
        with open(path, "w") as f:
            json.dump({
                "checked_at": datetime.now(timezone.utc).isoformat(),
                "sites_checked": len(sites),
                "total_links": len(all_results),
                "broken_count": len(broken),
                "red_flags": len(red_flags),
                "results": [r for r in all_results if not r["ok"]],
            }, f, indent=2)
        print(f"\nJSON saved to {path}")

    # Create Action records
    if args.actions and broken:
        try:
            import django
            os.environ.setdefault("DJANGO_SETTINGS_MODULE", "webclerk3_api.settings")
            sys.path.insert(0, str(Path.home() / "Documents" / "CommerceExpert" / "webClerk3"))
            django.setup()
            from apps.core.models import Action

            now_ms = int(time.time() * 1000)
            created = 0
            for r in broken:
                flag = "Red" if r["customer_facing"] else "Orange"
                Action.objects.create(
                    task={"en": f"{flag} flag: dead link on {r['site']} — {r['raw'][:60]}"},
                    description={"en": f"Dead link found by weekly link checker.\n\n"
                                       f"Site: {r['site']}\n"
                                       f"Page: {r['page']}\n"
                                       f"Link: {r['link_url']}\n"
                                       f"Type: {r['kind']}\n"
                                       f"Problem: {r['problem']}\n"
                                       f"Text: {r['text']}\n\n"
                                       f"Fix: update or remove the link."},
                    kanban_column="Todo",
                    status="open",
                    priority=1 if r["customer_facing"] else 3,
                    project_name="Site Maintenance",
                    project_ida="site-maintenance",
                    dt_created=now_ms, dt_modified=now_ms,
                    metadata={"domain": "SYS", "agent": "Andi",
                              "link_url": r["link_url"], "site": r["site"]},
                )
                created += 1
            print(f"\nCreated {created} Action records for broken links.")
        except Exception as e:
            print(f"\nFailed to create Actions: {e}")

    return 1 if red_flags else 0


if __name__ == "__main__":
    sys.exit(main())
