#!/usr/bin/env python3
"""
library-catalog.py — Build a rich catalog of the JPods library

Reads harvested markdown files from knowledge/library/,
produces a catalog.json with content analysis, cross-references,
quality scores, and categorization.

Run: python3 ~/Allie/scripts/library-catalog.py
"""

import json
import os
import re
from pathlib import Path
from datetime import datetime

LIBRARY_DIR = Path.home() / "Allie" / "knowledge" / "library"
INDEX_FILE = LIBRARY_DIR / "_index.json"
CATALOG_FILE = LIBRARY_DIR / "_catalog.json"

# Categories based on JPods ecosystem
CATEGORIES = {
    "cities": ["city", "metro", "county", "tulsa", "oklahoma", "greenville", "columbia",
               "austin", "dallas", "houston", "atlanta", "nashville", "macon", "arlington",
               "palo alto", "secaucus", "asheville", "bloomington", "minneapolis", "denver",
               "phoenix", "portland", "seattle", "chicago", "boston", "nyc", "new york",
               "san francisco", "los angeles", "detroit", "cleveland", "columbus"],
    "constitutional": ["constitution", "veto", "madison", "monroe", "jackson", "amendment",
                       "sovereignty", "post road", "article", "federalist", "framers",
                       "unconstitutional", "divided sovereignty"],
    "energy": ["solar", "energy", "oil", "coal", "windmill", "renewable", "carbon",
               "climate", "emission", "co2", "edison", "electrification", "fossil"],
    "safety": ["roadkill", "crash", "death", "injury", "pedestrian", "cyclist", "safety",
               "kindermoord", "child murder", "theme park", "morgantown", "wuppertal",
               "sovereign immunity", "jury", "accountability"],
    "technology": ["prt", "guideway", "pod", "automated", "robot", "patent", "5x5",
                   "physical internet", "mesh", "network", "transit", "rail", "freight"],
    "economics": ["cost", "revenue", "payback", "investment", "billion", "million",
                  "walkable", "walk score", "tax", "property", "land use", "parking"],
    "education": ["student", "kit", "10xmakers", "school", "university", "learn",
                  "shenzhen", "dfrobot"],
    "history": ["1916", "1936", "1956", "1972", "1973", "embargo", "war", "iraq",
                "afghanistan", "canal", "railroad", "highway act", "eisenhower"],
    "commerce": ["webclerk", "alice", "commerce", "retail", "inventory", "invoice",
                 "desktop hosting", "saas", "subscription"],
}

# Keywords that indicate high-value content
GEM_INDICATORS = [
    "patent", "5x5", "morgantown", "congressional study", "constitution",
    "edison", "jefferson", "madison", "usufruct", "divided sovereignty",
    "physical internet", "prime law", "metcalfe", "roadkill", "theme park",
    "3000", "3,000", "11,200", "sovereign immunity", "jury",
    "stop de kindermoord", "child murder", "climate change root cause",
    "walkable", "walk score", "freight railroad", "470 ton",
]

def load_index():
    with open(INDEX_FILE) as f:
        return json.load(f)

def analyze_page(slug, meta):
    """Analyze a single page and return rich metadata."""
    md_file = LIBRARY_DIR / f"{slug}.md"
    if not md_file.exists():
        return None

    content = md_file.read_text(errors="replace")

    # Extract frontmatter
    lines = content.split("\n")
    body_start = 0
    if lines[0].strip() == "---":
        for i, line in enumerate(lines[1:], 1):
            if line.strip() == "---":
                body_start = i + 1
                break
    body = "\n".join(lines[body_start:])
    body_lower = body.lower()

    # Size metrics
    char_count = len(body)
    word_count = len(body.split())
    line_count = len(body.strip().split("\n"))

    # Categorize
    cats = []
    for cat, keywords in CATEGORIES.items():
        score = sum(1 for kw in keywords if kw in body_lower)
        if score >= 2:
            cats.append({"category": cat, "score": score})
    cats.sort(key=lambda x: -x["score"])

    # Quality signals
    has_links = bool(re.findall(r'https?://\S+', body))
    has_numbers = bool(re.findall(r'\$[\d,.]+[BMK]?\b|\b\d{1,3}(?:,\d{3})+\b', body))
    has_quotes = '> ' in body or '"' in body
    has_images = '![' in body or '<img' in body.lower()
    link_count = len(re.findall(r'https?://\S+', body))

    # Gem score — how valuable is this page?
    gem_score = 0
    gem_matches = []
    for indicator in GEM_INDICATORS:
        if indicator.lower() in body_lower:
            gem_score += 1
            gem_matches.append(indicator)

    # Boost for length (substantive content)
    if word_count > 500: gem_score += 1
    if word_count > 1500: gem_score += 1
    if word_count > 3000: gem_score += 2

    # Boost for data
    if has_numbers: gem_score += 1
    if has_links: gem_score += 1
    if link_count > 5: gem_score += 1

    # Quality assessment
    if gem_score >= 8:
        quality = "gem"
    elif gem_score >= 5:
        quality = "valuable"
    elif gem_score >= 3:
        quality = "useful"
    elif word_count < 50:
        quality = "stub"
    elif word_count < 150:
        quality = "thin"
    else:
        quality = "standard"

    # Cross-references — which other pages does this link to?
    internal_links = re.findall(r'library\.jpods\.com/([a-z0-9\-]+)/?', body_lower)
    jpods_links = re.findall(r'jpods\.com/([a-zA-Z0-9\-/]+)', body)
    external_links = [l for l in re.findall(r'https?://([^/\s]+)', body) if 'jpods.com' not in l]

    # Age
    try:
        modified = datetime.fromisoformat(meta.get("modified", "2020-01-01"))
        age_days = (datetime.now() - modified).days
    except:
        age_days = 999

    if age_days > 730:
        freshness = "stale"
    elif age_days > 365:
        freshness = "aging"
    elif age_days > 90:
        freshness = "recent"
    else:
        freshness = "fresh"

    return {
        "id": meta["id"],
        "title": meta["title"],
        "slug": slug,
        "url": meta["url"],
        "date": meta.get("date", ""),
        "modified": meta.get("modified", ""),
        "path": str(md_file),
        "size": {
            "chars": char_count,
            "words": word_count,
            "lines": line_count,
        },
        "categories": [c["category"] for c in cats[:3]],
        "category_scores": cats[:5],
        "quality": quality,
        "gem_score": gem_score,
        "gem_matches": gem_matches[:10],
        "freshness": freshness,
        "age_days": age_days,
        "signals": {
            "has_links": has_links,
            "has_numbers": has_numbers,
            "has_quotes": has_quotes,
            "has_images": has_images,
            "link_count": link_count,
        },
        "cross_refs": {
            "internal": list(set(internal_links))[:10],
            "jpods": list(set(jpods_links))[:10],
            "external": list(set(external_links))[:10],
        },
    }


def main():
    index = load_index()
    print(f"Analyzing {len(index)} pages...")

    catalog = []
    quality_counts = {}
    category_counts = {}

    for i, meta in enumerate(index):
        slug = meta["slug"]
        entry = analyze_page(slug, meta)
        if entry:
            catalog.append(entry)

            q = entry["quality"]
            quality_counts[q] = quality_counts.get(q, 0) + 1

            for cat in entry["categories"]:
                category_counts[cat] = category_counts.get(cat, 0) + 1

        if (i + 1) % 100 == 0:
            print(f"  Analyzed {i + 1} pages...")

    # Sort by gem_score descending
    catalog.sort(key=lambda x: -x["gem_score"])

    # Summary
    summary = {
        "total_pages": len(catalog),
        "analyzed_at": datetime.now().isoformat(),
        "quality_distribution": quality_counts,
        "category_distribution": category_counts,
        "top_gems": [{"title": c["title"], "slug": c["slug"], "gem_score": c["gem_score"],
                       "quality": c["quality"], "categories": c["categories"]}
                      for c in catalog[:20]],
        "stubs": [c["slug"] for c in catalog if c["quality"] == "stub"],
        "stale_count": sum(1 for c in catalog if c["freshness"] == "stale"),
        "fresh_count": sum(1 for c in catalog if c["freshness"] == "fresh"),
    }

    output = {
        "summary": summary,
        "pages": catalog,
    }

    with open(CATALOG_FILE, "w") as f:
        json.dump(output, f, indent=2)

    print(f"\nCatalog written to {CATALOG_FILE}")
    print(f"\nQuality distribution:")
    for q, count in sorted(quality_counts.items(), key=lambda x: -x[1]):
        print(f"  {q:12s} {count:4d}")
    print(f"\nCategory distribution:")
    for cat, count in sorted(category_counts.items(), key=lambda x: -x[1]):
        print(f"  {cat:15s} {count:4d}")
    print(f"\nTop 10 gems:")
    for entry in catalog[:10]:
        print(f"  [{entry['gem_score']:2d}] {entry['title'][:60]:60s} ({entry['quality']})")


if __name__ == "__main__":
    main()
