#!/usr/bin/env python3
"""Harvest all pages from library.jpods.com via WP REST API."""

import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

try:
    import html2text
    H2T = html2text.HTML2Text()
    H2T.ignore_links = False
    H2T.body_width = 0  # no wrapping
    USE_H2T = True
except ImportError:
    USE_H2T = False

API_URL = "https://library.jpods.com/wp-json/wp/v2/pages"
OUT_DIR = Path("/Users/williamjames/Allie/knowledge/library")
OUT_DIR.mkdir(parents=True, exist_ok=True)

def sanitize_slug(slug):
    """Make slug safe for filename."""
    slug = re.sub(r'[^\w\-]', '-', slug)
    slug = re.sub(r'-+', '-', slug).strip('-')
    return slug or 'untitled'

def fetch_pages(page_num, per_page=100):
    """Fetch a batch of pages from the API."""
    url = f"{API_URL}?per_page={per_page}&page={page_num}&_fields=id,title,slug,content,date,modified,link"
    req = urllib.request.Request(url, headers={'User-Agent': 'Allie/1.0'})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode('utf-8'))

def html_to_md(html):
    """Convert HTML to markdown."""
    if USE_H2T:
        return H2T.handle(html)
    return f"```html\n{html}\n```"

def save_page(page):
    """Save a single page as markdown."""
    slug = sanitize_slug(page.get('slug', 'untitled'))
    title = page.get('title', {}).get('rendered', 'Untitled')
    content_html = page.get('content', {}).get('rendered', '')
    page_id = page.get('id', 0)
    link = page.get('link', '')
    date = page.get('date', '')[:10]
    modified = page.get('modified', '')[:10]

    # Clean title for YAML frontmatter (escape quotes)
    title_escaped = title.replace('"', '\\"')

    content_md = html_to_md(content_html)

    frontmatter = f"""---
id: {page_id}
title: "{title_escaped}"
slug: {slug}
url: {link}
date: {date}
modified: {modified}
---
"""
    filepath = OUT_DIR / f"{slug}.md"
    filepath.write_text(frontmatter + "\n" + content_md, encoding='utf-8')
    return {
        'id': page_id,
        'title': title,
        'slug': slug,
        'url': link,
        'date': date,
        'modified': modified
    }

def main():
    all_meta = []
    errors = []
    total = 0
    page_num = 1

    print(f"Harvesting pages from {API_URL}")
    print(f"Output: {OUT_DIR}")
    print(f"html2text: {'yes' if USE_H2T else 'no (raw HTML in fences)'}")
    print()

    while True:
        try:
            print(f"Fetching page batch {page_num} (per_page=100)...")
            pages = fetch_pages(page_num)
        except urllib.error.HTTPError as e:
            if e.code == 400:
                # Past the last page
                print(f"  Batch {page_num}: no more pages (HTTP 400)")
                break
            errors.append(f"HTTP error fetching batch {page_num}: {e}")
            print(f"  ERROR: {e}")
            break
        except Exception as e:
            errors.append(f"Error fetching batch {page_num}: {e}")
            print(f"  ERROR: {e}")
            break

        if not pages:
            print(f"  Batch {page_num}: empty response")
            break

        for p in pages:
            total += 1
            try:
                meta = save_page(p)
                all_meta.append(meta)
            except Exception as e:
                pid = p.get('id', '?')
                errors.append(f"Page {pid}: {e}")
                print(f"  ERROR saving page {pid}: {e}")

            if total % 50 == 0:
                print(f"  Progress: {total} pages saved")

        if len(pages) < 100:
            print(f"  Batch {page_num}: {len(pages)} pages (last batch)")
            break

        page_num += 1
        time.sleep(0.5)  # polite pause

    # Save index
    index_path = OUT_DIR / "_index.json"
    index_path.write_text(json.dumps(all_meta, indent=2, ensure_ascii=False), encoding='utf-8')

    print()
    print(f"=== COMPLETE ===")
    print(f"Total pages harvested: {total}")
    print(f"Index saved: {index_path}")
    if errors:
        print(f"Errors ({len(errors)}):")
        for e in errors:
            print(f"  - {e}")
    else:
        print("No errors.")

if __name__ == '__main__':
    main()
