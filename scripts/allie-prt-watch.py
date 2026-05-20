#!/usr/bin/env python3
"""
allie-prt-watch.py — Weekly PRT / podcar / automated transit intelligence digest

Sources:
  1. Reddit — searches r/transit, r/urbanplanning, r/futurism, r/strongtowns + keyword sweep
  2. Google Alerts RSS — reads any alert feeds configured in config/prt_alerts.json
  3. (LinkedIn / Facebook — not automated; manual paste section at bottom of output)

Output:
  logs/prt-digest-YYYY-MM-DD.json  — structured weekly digest
  logs/prt-digest-YYYY-MM-DD.md    — human-readable summary (Claude-generated)

Setup:
  1. pip3 install feedparser anthropic
  2. Optional: set up Google Alerts for PRT keywords, get RSS URLs,
     add them to config/prt_alerts.json (see template below)
  3. Run weekly: python3 scripts/allie-prt-watch.py
     Or add to cron: 0 7 * * 1 /path/to/python3 /path/to/allie-prt-watch.py

No Reddit API key needed — uses Reddit's public RSS search feeds.

cron (weekly Monday 7am):
  0 7 * * 1 cd /Users/williamjames/Allie && /Users/williamjames/Allie/venv/bin/python3 scripts/allie-prt-watch.py
"""

import json
import datetime
import pathlib
import sys
import textwrap

ALLIE      = pathlib.Path("/Users/williamjames/Allie")
CREDS_PATH = ALLIE / "config" / "wc_credentials.json"
ALERTS_CFG = ALLIE / "config" / "prt_alerts.json"
LOGS_DIR   = ALLIE / "logs"
CITIES_DB  = ALLIE / "knowledge" / "research" / "cities-transit-innovation.json"

# ── Search configuration ──────────────────────────────────────────────────────

REDDIT_SUBREDDITS = [
    "transit",
    "urbanplanning",
    "futurism",
    "strongtowns",
    "fuckcars",
    "trains",
    "sustainable",
    "worldnews",
]

REDDIT_KEYWORDS = [
    "personal rapid transit",
    "PRT transit",
    "podcar",
    "podcars",
    "automated guideway",
    "automated transit",
    "JPods",
    "2getthere",
    "ULTra PRT",
    "Vectus PRT",
    "skysong",
    "gondola transit",
    "cable car transit",
]

# Minimum Reddit score to include a post
MIN_SCORE = 5

# How many days back to search (should match cron frequency)
LOOKBACK_DAYS = 7


# ── Credentials ───────────────────────────────────────────────────────────────

def load_creds() -> dict:
    if not CREDS_PATH.exists():
        return {}
    return json.loads(CREDS_PATH.read_text())


# ── Google News ───────────────────────────────────────────────────────────────
# Primary intelligence source. No API key. Searches all news sources.

GOOGLE_NEWS_QUERIES = [
    '"personal rapid transit" when:30d',
    'podcar OR podcars when:30d',
    '"automated guideway" transit when:30d',
    'JPods transit when:30d',
    '"PRT" transit city when:30d',
]

def fetch_google_news(lookback_days: int = LOOKBACK_DAYS) -> list[dict]:
    """
    Fetch PRT news via Google News RSS. No credentials required.
    Uses Google's when: operator for date filtering — more reliable than
    parsing feed entry dates which can be stale or missing.
    """
    try:
        import feedparser
    except ImportError:
        print("WARNING: feedparser not installed. Run: pip3 install feedparser")
        return []

    from urllib.parse import urlencode
    import time

    seen  = set()
    items = []

    for q in GOOGLE_NEWS_QUERIES:
        url = "https://news.google.com/rss/search?" + urlencode({
            "q": q, "hl": "en-US", "gl": "US", "ceid": "US:en"
        })
        try:
            feed = feedparser.parse(url)
            for entry in feed.entries:
                uid = entry.get("id", entry.get("link", ""))
                if uid in seen:
                    continue
                seen.add(uid)

                published = entry.get("published_parsed") or entry.get("updated_parsed")
                date_str = (datetime.datetime(*published[:6]).strftime("%Y-%m-%d")
                            if published else "unknown")

                items.append({
                    "source":  "google_news",
                    "query":   q,
                    "title":   entry.get("title", "").strip(),
                    "url":     entry.get("link", ""),
                    "date":    date_str,
                    "summary": entry.get("summary", "")[:500],
                })

            time.sleep(1)

        except Exception as e:
            print(f"  Google News error ({q}): {e}")

    items.sort(key=lambda x: x["date"], reverse=True)
    print(f"Google News: {len(items)} articles collected")
    return items


# ── Reddit (subreddit RSS — no API key, client-side keyword filter) ────────────

REDDIT_SUBREDDITS = [
    "transit", "urbanplanning", "futurism",
    "strongtowns", "fuckcars", "sustainable",
]

REDDIT_KEYWORDS = [
    "personal rapid transit", "prt", "podcar", "podcars",
    "automated guideway", "automated transit", "jpods",
    "2getthere", "ultra prt", "vectus", "skysong",
]

def fetch_reddit(lookback_days: int = LOOKBACK_DAYS) -> list[dict]:
    """
    Fetch new posts from PRT-adjacent subreddits and filter by keyword.
    Reddit's public search is broken; this uses per-subreddit new-post feeds instead.
    """
    try:
        import feedparser
    except ImportError:
        return []

    import time
    cutoff  = datetime.datetime.utcnow() - datetime.timedelta(days=lookback_days)
    seen    = set()
    posts   = []
    headers = {"User-Agent": "allie-prt-watch/1.0"}

    for sub in REDDIT_SUBREDDITS:
        url = f"https://www.reddit.com/r/{sub}/new.rss?limit=100"
        try:
            feed = feedparser.parse(url, request_headers=headers)
            for entry in feed.entries:
                uid = entry.get("id", entry.get("link", ""))
                if uid in seen:
                    continue

                text = (entry.get("title", "") + " " + entry.get("summary", "")).lower()
                if not any(kw in text for kw in REDDIT_KEYWORDS):
                    continue

                published = entry.get("published_parsed") or entry.get("updated_parsed")
                if published:
                    entry_dt = datetime.datetime(*published[:6])
                    if entry_dt < cutoff:
                        continue
                    date_str = entry_dt.strftime("%Y-%m-%d")
                else:
                    date_str = "unknown"

                seen.add(uid)
                link = entry.get("link", "")
                posts.append({
                    "source":    "reddit",
                    "subreddit": sub,
                    "title":     entry.get("title", "").strip(),
                    "url":       link,
                    "date":      date_str,
                    "text":      entry.get("summary", "")[:500],
                })

            time.sleep(2)

        except Exception as e:
            print(f"  Reddit RSS error (r/{sub}): {e}")

    print(f"Reddit: {len(posts)} keyword-matched posts")
    return posts


# ── RSS / Google Alerts ───────────────────────────────────────────────────────

def fetch_rss(lookback_days: int = LOOKBACK_DAYS) -> list[dict]:
    """
    Fetch from RSS feeds listed in config/prt_alerts.json.

    prt_alerts.json template:
    {
      "feeds": [
        {
          "label": "Google Alert — personal rapid transit",
          "url": "https://www.google.com/alerts/feeds/YOUR_ACCOUNT_ID/YOUR_FEED_ID"
        }
      ]
    }

    To get these URLs:
      1. Go to https://www.google.com/alerts
      2. Create alert for each keyword
      3. Delivery = RSS feed
      4. Copy the feed URL and paste into prt_alerts.json
    """
    try:
        import feedparser
    except ImportError:
        print("WARNING: feedparser not installed. Run: pip3 install feedparser")
        return []

    if not ALERTS_CFG.exists():
        # Create a template config
        template = {
            "_instructions": "Add Google Alert RSS feed URLs here. In Google Alerts, set Delivery=RSS and copy the feed URL.",
            "feeds": [
                {"label": "Google Alert — personal rapid transit (example)",
                 "url": "https://www.google.com/alerts/feeds/REPLACE_WITH_YOUR_FEED_ID"}
            ]
        }
        ALERTS_CFG.write_text(json.dumps(template, indent=2))
        print(f"Created RSS config template: {ALERTS_CFG}")
        print("  Edit it to add your Google Alert feed URLs, then re-run.")
        return []

    cfg = json.loads(ALERTS_CFG.read_text())
    feeds_list = [f for f in cfg.get("feeds", []) if "REPLACE" not in f.get("url", "")]

    cutoff = datetime.datetime.utcnow() - datetime.timedelta(days=lookback_days)
    items  = []

    for feed_cfg in feeds_list:
        try:
            feed = feedparser.parse(feed_cfg["url"])
            for entry in feed.entries:
                published = entry.get("published_parsed") or entry.get("updated_parsed")
                if published:
                    entry_dt = datetime.datetime(*published[:6])
                    if entry_dt < cutoff:
                        continue
                    date_str = entry_dt.strftime("%Y-%m-%d")
                else:
                    date_str = "unknown"

                items.append({
                    "source":  "rss",
                    "feed":    feed_cfg["label"],
                    "title":   entry.get("title", ""),
                    "url":     entry.get("link", ""),
                    "date":    date_str,
                    "summary": entry.get("summary", "")[:500],
                })
        except Exception as e:
            print(f"  RSS error ({feed_cfg.get('label', '?')}): {e}")

    print(f"RSS: {len(items)} items collected")
    return items


# ── Claude summary ────────────────────────────────────────────────────────────

def build_summary_prompt(posts: list[dict], rss_items: list[dict], week_str: str,
                         news_items: list[dict] | None = None) -> str:
    lines = [f"Weekly PRT Intelligence Digest — week of {week_str}", ""]

    if news_items:
        lines.append(f"## News ({len(news_items)} articles)")
        for n in news_items[:25]:
            lines.append(f"- [{n['title']}]({n['url']}) ({n['date']})")
            if n.get("summary"):
                lines.append(f"  {n['summary'][:200]}")
        lines.append("")

    if posts:
        lines.append(f"## Reddit ({len(posts)} posts)")
        for p in posts[:20]:
            lines.append(f"- [{p['title']}]({p['url']}) r/{p['subreddit']} ({p['date']})")
            if p.get("text"):
                lines.append(f"  {p['text'][:200]}")
        lines.append("")

    if rss_items:
        lines.append(f"## Google Alerts ({len(rss_items)} items)")
        for r in rss_items[:20]:
            lines.append(f"- [{r['title']}]({r['url']}) ({r['date']})")
            if r.get("summary"):
                lines.append(f"  {r['summary'][:200]}")
        lines.append("")

    prompt = "\n".join(lines)
    prompt += textwrap.dedent("""
    ---
    Please write a concise weekly intelligence summary for Bill James (JPods founder).
    Format as Markdown. Include:

    1. **Top Signal** — the single most relevant development for JPods this week (1-2 sentences)
    2. **City Watch** — any cities, regions, or transit authorities mentioned that show innovation interest (list)
    3. **Narrative Shifts** — any change in how people talk about PRT, automated transit, or car-dependence
    4. **Mentions of JPods or competitors** — direct references to JPods, 2getthere, ULTra, Vectus, Morgantown PRT
    5. **Recommended Action** — one specific thing Bill or Allie should do based on this week's signals

    Be specific. Name cities, projects, and people. Skip filler.
    """)

    return prompt


def generate_summary(posts: list[dict], rss_items: list[dict], week_str: str,
                     news_items: list[dict] | None = None) -> str:
    """Call Claude to summarize the week's PRT intelligence."""
    sys.path.insert(0, str(ALLIE / "scripts"))
    try:
        from allie_ask_claude import ask_claude
    except ImportError:
        return "(Claude summary unavailable — allie_ask_claude.py not found)"

    if not posts and not rss_items and not news_items:
        return "(No content collected this week — check Google News and RSS feed config)"

    prompt = build_summary_prompt(posts, rss_items, week_str, news_items=news_items)
    print("Generating Claude summary...")
    return ask_claude(
        prompt=prompt,
        mode="api",
        domain="universal",
        from_script="allie-prt-watch",
        log=True,
    )


# ── Output ────────────────────────────────────────────────────────────────────

def save_digest(posts: list[dict], rss_items: list[dict], summary: str, week_str: str,
                news_items: list[dict] | None = None):
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    news_items = news_items or []

    digest = {
        "schema":     "prt-digest-v2",
        "week":       week_str,
        "generated":  datetime.datetime.now().isoformat(timespec="seconds"),
        "counts": {
            "google_news": len(news_items),
            "reddit":      len(posts),
            "rss_alerts":  len(rss_items),
        },
        "summary":     summary,
        "google_news": news_items,
        "reddit":      posts,
        "rss_alerts":  rss_items,
    }

    json_path = LOGS_DIR / f"prt-digest-{week_str}.json"
    md_path   = LOGS_DIR / f"prt-digest-{week_str}.md"

    json_path.write_text(json.dumps(digest, indent=2))

    md = f"# PRT Intelligence Digest — {week_str}\n\n{summary}\n"
    md_path.write_text(md)

    print(f"\nDigest saved:")
    print(f"  JSON: {json_path}")
    print(f"  MD:   {md_path}")

    return json_path, md_path


# ── City cross-reference ──────────────────────────────────────────────────────

def flag_city_mentions(posts: list[dict], rss_items: list[dict]) -> list[str]:
    """Check if any posts mention cities in the tracker — quick cross-ref."""
    if not CITIES_DB.exists():
        return []

    db = json.loads(CITIES_DB.read_text())
    cities = db.get("cities", {})

    city_names = []
    for key, city in cities.items():
        city_names.append((city["name"].lower(), city["name"], key))
        if city.get("state"):
            city_names.append((f"{city['name'].lower()}, {city['state'].lower()}",
                               city["name"], key))

    all_text = " ".join(
        p["title"] + " " + p.get("text", "") for p in posts
    ) + " ".join(
        r["title"] + " " + r.get("summary", "") for r in rss_items
    )
    all_text = all_text.lower()

    hits = []
    for search_name, display_name, key in city_names:
        if search_name in all_text:
            hits.append(f"{display_name} ({key})")

    return list(set(hits))


# ── WebClerk ──────────────────────────────────────────────────────────────────

def post_to_webclerk(
    week_str: str,
    json_path: pathlib.Path,
    md_path: pathlib.Path,
    summary: str,
    post_count: int,
    rss_count: int,
    city_hits: list[str],
):
    """
    Create a weekly Action in WebClerk (PRT_reddit) assigned to Bill + Allie,
    plus a Document pointer to the digest JSON.
    """
    sys.path.insert(0, str(ALLIE / "scripts"))
    try:
        from allie_wc_client import WCClient, WCError
    except ImportError:
        print("WARNING: allie_wc_client.py not found — skipping WebClerk post")
        return

    wc = WCClient(agent="allie")

    # First line of Claude summary becomes the action description header
    summary_preview = summary.split("\n")[0].lstrip("#").strip() if summary else ""
    city_line = f"\nCities mentioned: {', '.join(city_hits)}" if city_hits else ""

    description = (
        f"Weekly PRT intelligence digest — {week_str}\n"
        f"Reddit: {post_count} posts | RSS: {rss_count} items{city_line}\n\n"
        f"{summary_preview}\n\n"
        f"JSON digest: {json_path}\n"
        f"MD summary:  {md_path}"
    )

    try:
        action_id = wc.create_action(
            title="PRT_reddit",
            description=description,
            kanban_column="InProcess",
            assigned_to=["bill", "allie"],
            deadline_days=7,
            priority=2,
        )
        print(f"\nWebClerk Action created: id={action_id} (PRT_reddit — {week_str})")
    except Exception as e:
        print(f"WARNING: WebClerk action failed (server may be down): {e}")
        action_id = None

    try:
        doc_id = wc.create_document_pointer(
            title=f"PRT Digest {week_str}",
            path=str(json_path),
            summary=f"Weekly PRT intelligence digest. {post_count} Reddit posts, {rss_count} RSS items.{city_line}",
            description=f"Finder: {json_path}",
            project_id=None,
            tags=["PRT", "transit", "intelligence", "weekly"],
            extra={
                "md_path":    str(md_path),
                "week":       week_str,
                "reddit":     post_count,
                "rss":        rss_count,
                "city_hits":  city_hits,
                "action_id":  action_id,
            },
        )
        print(f"WebClerk Document pointer created: id={doc_id}")
    except Exception as e:
        print(f"WARNING: WebClerk document pointer failed (server may be down): {e}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    week_str = datetime.date.today().strftime("%Y-%m-%d")
    print(f"allie-prt-watch — {week_str}")
    print("=" * 50)

    news_items = fetch_google_news()
    posts      = fetch_reddit()
    rss_items  = fetch_rss()

    all_items  = news_items + posts + rss_items
    city_hits  = flag_city_mentions(posts + news_items, rss_items)
    if city_hits:
        print(f"\nCity tracker mentions: {', '.join(city_hits)}")

    summary        = generate_summary(posts, rss_items, week_str, news_items=news_items)
    json_path, md_path = save_digest(posts, rss_items, summary, week_str)

    post_to_webclerk(
        week_str=week_str,
        json_path=json_path,
        md_path=md_path,
        summary=summary,
        post_count=len(posts) + len(news_items),
        rss_count=len(rss_items),
        city_hits=city_hits,
    )

    print("\n--- Summary Preview ---")
    print(summary[:800])
    if len(summary) > 800:
        print(f"... (see {md_path})")


if __name__ == "__main__":
    main()
