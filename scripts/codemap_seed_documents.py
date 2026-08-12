#!/usr/bin/env python3
"""
CodeMap — Add revision headers to .dot files and seed WC3 Document records.

1. Reads all wc3-*.dot files
2. Adds/updates a '// CodeMap revision: N — YYYY-MM-DD' line
3. Creates or updates a Document record in WC3 for each file (purpose='codemap-guru')

Usage:
    python3 scripts/codemap_seed_documents.py              # dry run
    python3 scripts/codemap_seed_documents.py --apply       # write changes
    python3 scripts/codemap_seed_documents.py --apply --re-enrich  # also re-enrich SVGs
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

# ── Paths ──
FLOWCHARTS_DIR = Path(__file__).resolve().parent.parent / "readmes" / "flowcharts"
CODEMAP_JSON = FLOWCHARTS_DIR / "codemap.json"
WC3_DIR = Path.home() / "Documents" / "CommerceExpert" / "webClerk3"

# ── Django setup ──
def setup_django():
    sys.path.insert(0, str(WC3_DIR))
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "webclerk3_api.settings")
    import django
    django.setup()


def get_dot_description(content: str) -> str:
    """Extract description from the first comment line."""
    for line in content.splitlines():
        line = line.strip()
        if line.startswith("//"):
            desc = line.lstrip("/").strip()
            # Remove "WC3 " prefix and " — " suffix for cleaner name
            desc = re.sub(r'^WC3\s+', '', desc)
            return desc
    return ""


def get_dot_title(filename: str) -> str:
    """Convert filename to title: wc3-inventory-buckets -> Inventory Buckets"""
    name = filename.replace("wc3-", "").replace(".dot", "")
    return name.replace("-", " ").title()


def count_nodes(content: str) -> int:
    """Count node definitions in a .dot file."""
    return len(re.findall(r'^\s+\w+\s*\[', content, re.MULTILINE))


def count_mapped_nodes(content: str, codemap_nodes: dict) -> int:
    """Count nodes that have codemap mappings."""
    return sum(1 for nid in codemap_nodes if re.search(rf'\b{nid}\b\s*\[', content))


def add_revision_header(content: str, revision: int, date: str) -> str:
    """Add or update the CodeMap revision line in a .dot file."""
    rev_line = f"// CodeMap revision: {revision} — {date}"

    # Check if revision line already exists
    rev_pattern = re.compile(r'^// CodeMap revision:.*$', re.MULTILINE)
    if rev_pattern.search(content):
        # Update existing
        return rev_pattern.sub(rev_line, content)

    # Insert before the digraph line
    digraph_pattern = re.compile(r'^(digraph\s+)', re.MULTILINE)
    match = digraph_pattern.search(content)
    if match:
        insert_pos = match.start()
        return content[:insert_pos] + rev_line + "\n\n" + content[insert_pos:]

    # Fallback: append after first blank line
    return content.replace("\n\n", f"\n{rev_line}\n\n", 1)


def main():
    parser = argparse.ArgumentParser(description="Seed CodeMap revision headers and WC3 Document records")
    parser.add_argument("--apply", action="store_true", help="Actually write changes (default: dry run)")
    parser.add_argument("--re-enrich", action="store_true", help="Re-run enrichment after updating .dot files")
    args = parser.parse_args()

    today = time.strftime("%Y-%m-%d")
    now_ms = int(time.time() * 1000)

    # Load codemap
    codemap = {}
    if CODEMAP_JSON.exists():
        with open(CODEMAP_JSON) as f:
            codemap = json.load(f)
    codemap_nodes = codemap.get("nodes", {})

    # Find all source .dot files
    dot_files = sorted(
        p for p in FLOWCHARTS_DIR.glob("wc3-*.dot")
        if ".enriched." not in p.name
    )

    print(f"Found {len(dot_files)} .dot files")
    print(f"CodeMap nodes: {len(codemap_nodes)}")
    print(f"Mode: {'APPLY' if args.apply else 'DRY RUN'}")
    print()

    # Setup Django if applying
    if args.apply:
        setup_django()
        from apps.docs.models import Document

    records = []
    for dot_path in dot_files:
        content = dot_path.read_text()
        filename = dot_path.name
        title = get_dot_title(filename)
        description = get_dot_description(content)
        total_nodes = count_nodes(content)
        mapped_nodes = count_mapped_nodes(content, codemap_nodes)
        has_svg = dot_path.with_name(dot_path.stem + ".enriched.svg").exists()

        # Check existing revision
        rev_match = re.search(r'// CodeMap revision:\s*(\d+)', content)
        current_rev = int(rev_match.group(1)) if rev_match else 0
        new_rev = current_rev + 1 if current_rev == 0 else current_rev

        print(f"  {filename}")
        print(f"    Title: {title}")
        print(f"    Nodes: {mapped_nodes}/{total_nodes} mapped")
        print(f"    Revision: {current_rev} → {new_rev}")

        if args.apply:
            # 1. Add revision header to .dot file
            updated = add_revision_header(content, new_rev, today)
            dot_path.write_text(updated)
            print(f"    ✓ Revision header written")

            # 2. Create or update Document record
            slug = dot_path.stem  # e.g., "wc3-inventory-buckets"
            doc, created = Document.objects.update_or_create(
                slug=slug,
                purpose="codemap-guru",
                defaults={
                    "name": f"CodeMap: {title}",
                    "description": description[:255] if description else f"Architecture flowchart: {title}",
                    "status": "published",
                    "body": f"Graphviz .dot flowchart for WC3 architecture.\n\nFile: readmes/flowcharts/{filename}\nNodes: {total_nodes} total, {mapped_nodes} mapped to code\nSVG: {'yes' if has_svg else 'no'}",
                    "path": {
                        "storage": "local",
                        "dot": f"readmes/flowcharts/{filename}",
                        "svg": f"readmes/flowcharts/{dot_path.stem}.enriched.svg" if has_svg else None,
                        "mapping": "readmes/flowcharts/codemap.json",
                    },
                    "mime_type": "text/vnd.graphviz",
                    "config": {
                        "revision": new_rev,
                        "revision_date": today,
                        "total_nodes": total_nodes,
                        "mapped_nodes": mapped_nodes,
                        "has_svg": has_svg,
                        "coverage_pct": round(mapped_nodes / total_nodes * 100, 1) if total_nodes else 0,
                    },
                    "refs": {
                        "keywords": ["codemap", "architecture", "flowchart", slug.replace("wc3-", "")],
                        "codemap": {"mapping_file": "codemap.json"},
                    },
                    "dt_modified": now_ms,
                },
            )
            action = "created" if created else "updated"
            print(f"    ✓ Document {action}: id={doc.id} slug={slug}")

        records.append({
            "file": filename,
            "title": title,
            "nodes": f"{mapped_nodes}/{total_nodes}",
            "revision": new_rev,
        })

    print(f"\n{'='*60}")
    print(f"Processed {len(records)} flowcharts")

    if args.apply and args.re_enrich:
        print("\nRe-enriching all flowcharts...")
        subprocess.run(
            [sys.executable, str(Path(__file__).parent / "codemap_enrich.py"), "--all", "--render"],
            cwd=str(FLOWCHARTS_DIR.parent.parent),
        )
        # Regenerate thumbnails
        print("\nRegenerating thumbnails...")
        thumb_dir = FLOWCHARTS_DIR / "thumbnails"
        thumb_dir.mkdir(exist_ok=True)
        for svg_path in sorted(FLOWCHARTS_DIR.glob("wc3-*.enriched.svg")):
            name = svg_path.name.replace(".enriched.svg", "")
            tmp_png = Path(f"/tmp/cm_{name}.png")
            jpg_path = thumb_dir / f"{name}.jpg"
            subprocess.run(["rsvg-convert", str(svg_path), "-h", "180", "-o", str(tmp_png)],
                           capture_output=True)
            subprocess.run(["sips", "-z", "90", "9999", "--resampleHeight", "90",
                           str(tmp_png), "-s", "format", "jpeg", "-s", "formatOptions", "80",
                           "--out", str(jpg_path)], capture_output=True)
        count = len(list(thumb_dir.glob("*.jpg")))
        print(f"  {count} thumbnails generated")

    if not args.apply:
        print("\nDry run complete. Use --apply to write changes.")


if __name__ == "__main__":
    main()
