#!/usr/bin/env python3
"""
CodeMap Enrichment Script — Layer 1
Reads a .dot file and codemap.json, outputs an enriched .dot with URL and tooltip
attributes on every mapped node. Graphviz renders these as clickable SVG.

Usage:
    python3 scripts/codemap_enrich.py readmes/flowcharts/wc3-inventory-buckets.dot
    python3 scripts/codemap_enrich.py readmes/flowcharts/wc3-inventory-buckets.dot --render
    python3 scripts/codemap_enrich.py --all --render
"""

import json
import re
import sys
import subprocess
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
DEFAULT_MAPPING = PROJECT_ROOT / "readmes" / "flowcharts" / "codemap.json"
STYLE_FILE = PROJECT_ROOT / "readmes" / "flowcharts" / "codemap-style.dot"

# Standard style block — injected after opening brace of every enriched .dot
_STYLE_BLOCK = """
    // ── CodeMap Standard Style ──
    fontname="Helvetica Neue,Helvetica,Arial,sans-serif"
    fontsize=12
    bgcolor="white"
    pad=0.4
    nodesep=0.5
    ranksep=0.6
    splines=true
    ratio=0.75

    node [
        fontname="Helvetica Neue,Helvetica,Arial,sans-serif"
        fontsize=10
        style="filled,rounded"
        shape=box
        penwidth=1.2
        color="#555555"
        margin="0.12,0.06"
    ]

    edge [
        fontname="Helvetica Neue,Helvetica,Arial,sans-serif"
        fontsize=10
        penwidth=2.0
        arrowhead=normal
        arrowsize=1.4
        color="#666666"
        fontcolor="#444444"
    ]
"""


def load_mapping(mapping_path: Path) -> dict:
    with open(mapping_path) as f:
        data = json.load(f)
    return data


def build_tooltip(node_id: str, node_data: dict) -> str:
    """Build a tooltip string from node mapping data."""
    parts = []

    desc = node_data.get("description", "")
    if desc:
        parts.append(desc)

    if "model" in node_data:
        parts.append(f"Model: {node_data['model']}")

    if "service" in node_data:
        parts.append(f"Service: {node_data['service']}")

    funcs = node_data.get("functions", [])
    if funcs:
        func_lines = []
        for f in funcs[:5]:  # cap at 5 for tooltip readability
            ctx = f" ({f['context']})" if "context" in f else ""
            func_lines.append(f"  {f['name']} @ {f['file']}:{f['line']}{ctx}")
        parts.append("Functions:\n" + "\n".join(func_lines))

    deltas = node_data.get("pending_deltas", {})
    if deltas:
        delta_str = ", ".join(f"{k}: {v}" for k, v in deltas.items())
        parts.append(f"Pending deltas: {delta_str}")

    gl = node_data.get("gl_impact", "")
    if gl:
        parts.append(f"GL: {gl}")

    return "\\n".join(parts)


def build_url(node_data: dict, base_path: str, vscode_scheme: str) -> str:
    """Build a VS Code URL for the primary code location."""
    # Prefer service entry point, then model, then first function
    if "service" in node_data:
        file_path = node_data["service"]
        entry = node_data.get("entry_point", "")
        # Find the line for the entry point
        line = 1
        for f in node_data.get("functions", []):
            if f["name"] == entry:
                line = f["line"]
                break
        return f"{vscode_scheme}{base_path}/{file_path}:{line}"

    if "model" in node_data:
        model = node_data["model"]
        if ":" in model:
            file_path, line = model.rsplit(":", 1)
            return f"{vscode_scheme}{base_path}/{file_path}:{line}"
        return f"{vscode_scheme}{base_path}/{model}"

    funcs = node_data.get("functions", [])
    if funcs:
        f = funcs[0]
        return f"{vscode_scheme}{base_path}/{f['file']}:{f['line']}"

    return ""


def find_attr_block_end(text: str, start: int) -> int:
    """Find the closing ] of a dot attribute block, respecting quoted strings."""
    i = start
    while i < len(text):
        ch = text[i]
        if ch == '"':
            # Skip quoted string
            i += 1
            while i < len(text) and text[i] != '"':
                if text[i] == '\\':
                    i += 1  # skip escaped char
                i += 1
            i += 1  # skip closing quote
        elif ch == ']':
            return i
        else:
            i += 1
    return -1


def inject_style(dot_content: str) -> str:
    """Inject the standard CodeMap style block after the opening digraph brace."""
    # Find the opening { of the digraph
    match = re.search(r'(digraph\s+\w+\s*\{)', dot_content)
    if not match:
        return dot_content

    insert_pos = match.end()

    # Remove existing per-file style declarations that conflict with standard
    # (these appear between { and the first node/subgraph/edge definition)
    # We keep: label, labelloc, rankdir (layout-specific, not style)
    # We replace: fontname, fontsize on graph level, node [...], edge [...]
    lines = dot_content[insert_pos:].split('\n')
    cleaned_lines = []
    skip_block = False
    for line in lines:
        stripped = line.strip()
        # Skip old global node/edge style blocks
        if re.match(r'^node\s*\[', stripped) and 'fontname' in stripped:
            skip_block = ']' not in stripped
            continue
        if re.match(r'^edge\s*\[', stripped) and 'fontname' in stripped:
            skip_block = ']' not in stripped
            continue
        if skip_block:
            if ']' in stripped:
                skip_block = False
            continue
        # Skip old graph-level fontname/fontsize/pad/nodesep/ranksep/bgcolor
        if re.match(r'^(fontname|fontsize|pad|nodesep|ranksep|bgcolor|splines)\s*=', stripped):
            continue
        cleaned_lines.append(line)

    cleaned_rest = '\n'.join(cleaned_lines)
    return dot_content[:insert_pos] + _STYLE_BLOCK + cleaned_rest


def enrich_dot(dot_content: str, mapping: dict) -> str:
    """Add URL and tooltip attributes to nodes in a .dot file."""
    meta = mapping.get("_meta", {})
    base_path = meta.get("base_path", "")
    vscode_scheme = meta.get("vscode_scheme", "vscode://file")
    nodes = mapping.get("nodes", {})

    # Match node definitions: leading whitespace, identifier, then [
    node_start_pattern = re.compile(r'^(\s+)(\w+)\s*\[', re.MULTILINE)

    result_parts = []
    last_end = 0

    for match in node_start_pattern.finditer(dot_content):
        indent = match.group(1)
        node_id = match.group(2)
        bracket_start = match.end() - 1  # position of [

        if node_id not in nodes:
            continue

        # Find the true closing ] respecting quotes
        block_end = find_attr_block_end(dot_content, bracket_start + 1)
        if block_end < 0:
            continue

        attrs = dot_content[bracket_start + 1:block_end]
        node_data = nodes[node_id]

        # Remove existing URL and tooltip if present (idempotent)
        attrs = re.sub(r'\s*URL="[^"]*"', '', attrs)
        attrs = re.sub(r'\s*tooltip="[^"]*"', '', attrs)
        attrs = re.sub(r'\s*target="[^"]*"', '', attrs)

        url = build_url(node_data, base_path, vscode_scheme)
        tooltip = build_tooltip(node_id, node_data)

        new_attrs = attrs.rstrip()
        if url:
            new_attrs += f' URL="{url}" target="_blank"'
        if tooltip:
            new_attrs += f' tooltip="{tooltip}"'

        # Rebuild: everything before this node + enriched node
        result_parts.append(dot_content[last_end:bracket_start + 1])
        result_parts.append(new_attrs)
        result_parts.append(']')
        last_end = block_end + 1

    result_parts.append(dot_content[last_end:])
    return ''.join(result_parts)


def render_svg(dot_path: Path, output_path: Path = None):
    """Render enriched .dot to SVG using Graphviz."""
    if output_path is None:
        output_path = dot_path.with_suffix(".svg")
    try:
        subprocess.run(
            ["dot", "-Tsvg", str(dot_path), "-o", str(output_path)],
            check=True, capture_output=True, text=True
        )
        print(f"  SVG: {output_path}")
    except FileNotFoundError:
        print("  ERROR: graphviz 'dot' not found — install with: brew install graphviz")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"  ERROR rendering: {e.stderr}")


def process_file(dot_path: Path, mapping: dict, do_render: bool = False):
    """Process a single .dot file."""
    print(f"Enriching: {dot_path.name}")

    content = dot_path.read_text()
    styled = inject_style(content)
    enriched = enrich_dot(styled, mapping)

    # Write enriched version
    enriched_path = dot_path.with_name(dot_path.stem + ".enriched.dot")
    enriched_path.write_text(enriched)
    print(f"  Output: {enriched_path.name}")

    # Count enriched nodes
    nodes = mapping.get("nodes", {})
    # Quick count of node IDs found in the file
    found = sum(1 for nid in nodes if re.search(rf'\b{nid}\b\s*\[', content))
    mapped = sum(1 for nid in nodes if re.search(rf'\b{nid}\b\s*\[', enriched) and nid in nodes)
    print(f"  Nodes mapped: {mapped}")

    if do_render:
        render_svg(enriched_path)

    return enriched_path


def main():
    import argparse
    parser = argparse.ArgumentParser(description="CodeMap enrichment — add URL/tooltip to .dot nodes")
    parser.add_argument("dot_file", nargs="?", help="Path to .dot file to enrich")
    parser.add_argument("--mapping", default=str(DEFAULT_MAPPING), help="Path to codemap.json")
    parser.add_argument("--render", action="store_true", help="Also render SVG via graphviz")
    parser.add_argument("--all", action="store_true", help="Process all wc3-*.dot files")
    args = parser.parse_args()

    mapping = load_mapping(Path(args.mapping))

    if args.all:
        flowcharts_dir = Path(args.mapping).parent
        dot_files = sorted(flowcharts_dir.glob("wc3-*.dot"))
        print(f"Processing {len(dot_files)} flowcharts...")
        for dot_path in dot_files:
            if ".enriched." in dot_path.name:
                continue
            process_file(dot_path, mapping, args.render)
        print(f"\nDone. {len(dot_files)} files enriched.")
    elif args.dot_file:
        dot_path = Path(args.dot_file)
        if not dot_path.exists():
            print(f"ERROR: {dot_path} not found")
            sys.exit(1)
        process_file(dot_path, mapping, args.render)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
