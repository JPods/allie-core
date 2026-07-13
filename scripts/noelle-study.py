#!/usr/bin/env python3
"""
noelle-study.py — Analyze a .jpd network and save metrics to Noelle's study folder + vector store.

Noelle can't see the map. But she can learn by retrospection — comparing topology,
spacing, connectivity, and designer choices across all networks people build.

Usage:
  python3 noelle-study.py /path/to/network.jpd
  python3 noelle-study.py --all   # analyze all networks in mesh_mobility_maps/
  python3 noelle-study.py --ingest # re-ingest all study files into vector store
"""

import argparse
import json
import math
import os
import shutil
import sys
from collections import defaultdict, deque
from datetime import datetime, timezone
from pathlib import Path

STUDY_DIR = Path.home() / "Allie" / "facets" / "noelle" / "study"
MAPS_DIR = Path.home() / "Documents" / "08_JPods" / "03_Technology" / "00_working_code" / "mesh_mobility_maps"
CHROMA_DIR = str(Path.home() / "Allie" / ".chroma_db_noelle")
COLLECTION = "noelle_network_design"


def analyze_network(jpd_path):
    """Analyze a .jpd file and return structured metrics."""
    with open(jpd_path) as f:
        data = json.load(f)

    structs = data.get("structures", [])
    cps = data.get("cps", [])
    lines = data.get("lines", [])
    stations_data = data.get("stations", [])
    settings = data.get("settings", {})
    overlays = data.get("overlays", {})

    stations = [s for s in structs if s.get("structure_type") == "station"]
    circles = [s for s in structs if s.get("structure_type") == "traffic_circle"]

    # Get positions — try stations list, then CPs (center_lat/center_lon or lat/lon)
    lats, lons = [], []
    struct_positions = {}

    # Method 1: stations list has lat/lon
    for s in stations_data:
        if s.get("lat"):
            lats.append(s["lat"])
            lons.append(s["lon"])

    # Method 2: CPs have center_lat/center_lon — aggregate per structure
    if not lats:
        for cp in cps:
            lat = cp.get("center_lat") or cp.get("lat")
            lon = cp.get("center_lon") or cp.get("lon")
            sid = cp.get("structure_id", "")
            if lat and sid:
                if sid not in struct_positions:
                    struct_positions[sid] = {"lats": [], "lons": []}
                struct_positions[sid]["lats"].append(lat)
                struct_positions[sid]["lons"].append(lon)

        for sid, pos in struct_positions.items():
            lats.append(sum(pos["lats"]) / len(pos["lats"]))
            lons.append(sum(pos["lons"]) / len(pos["lons"]))

    # Method 3: structures have lat/lon directly
    if not lats:
        for s in structs:
            if s.get("lat"):
                lats.append(s["lat"])
                lons.append(s["lon"])

    # Connectivity
    connected_cps = sum(1 for cp in cps if cp.get("connected_to"))
    open_cps = sum(1 for cp in cps if not cp.get("connected_to"))

    # Orphans
    struct_cp_map = defaultdict(list)
    for cp in cps:
        struct_cp_map[cp.get("structure_id", "")].append(cp)
    orphans = [sid for sid, scps in struct_cp_map.items()
               if all(not cp.get("connected_to") for cp in scps)]

    # Connected components
    adj = defaultdict(set)
    cp_to_struct = {cp.get("cp_id"): cp.get("structure_id") for cp in cps}
    for cp in cps:
        if cp.get("connected_to"):
            s1 = cp.get("structure_id", "")
            s2 = cp_to_struct.get(cp["connected_to"], "")
            if s1 and s2:
                adj[s1].add(s2)
                adj[s2].add(s1)

    all_sids = set(s.get("structure_id") for s in structs)
    visited = set()
    components = []
    for sid in all_sids:
        if sid not in visited:
            comp = set()
            queue = deque([sid])
            while queue:
                current = queue.popleft()
                if current in visited:
                    continue
                visited.add(current)
                comp.add(current)
                for neighbor in adj.get(current, []):
                    if neighbor not in visited:
                        queue.append(neighbor)
            components.append(len(comp))
    components.sort(reverse=True)

    # Nearest-neighbor spacing
    nn_dists = []
    if len(lats) > 1:
        coords = list(zip(lats, lons))
        cos_lat = math.cos(math.radians(sum(lats) / len(lats)))
        for i in range(len(coords)):
            min_d = float('inf')
            for j in range(len(coords)):
                if i == j:
                    continue
                dlat = (coords[i][0] - coords[j][0]) * 69.0
                dlon = (coords[i][1] - coords[j][1]) * 69.0 * cos_lat
                d = math.sqrt(dlat ** 2 + dlon ** 2)
                min_d = min(min_d, d)
            nn_dists.append(min_d)

    # Extent
    ns_mi = (max(lats) - min(lats)) * 69.0 if lats else 0
    ew_mi = (max(lons) - min(lons)) * 69.0 * math.cos(math.radians(sum(lats) / len(lats))) if lats else 0

    # Parse filename for metadata
    name = Path(jpd_path).stem
    parts = name.split("_")
    state = parts[0] if len(parts[0]) == 2 and parts[0].isupper() else ""
    city = "_".join(parts[1:]).replace("_", " ") if state else name.replace("_", " ")

    metrics = {
        "filename": Path(jpd_path).name,
        "name": name,
        "state": state,
        "city": city,
        "analyzed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "topology": {
            "total_structures": len(structs),
            "stations": len(stations),
            "traffic_circles": len(circles),
            "station_to_circle_ratio": round(len(stations) / max(len(circles), 1), 1),
            "lines": len(lines),
            "cps_total": len(cps),
            "cps_connected": connected_cps,
            "cps_open": open_cps,
            "orphans": len(orphans),
            "orphan_ids": orphans[:10],
            "connected_components": len(components),
            "component_sizes": components[:5],
        },
        "spacing": {
            "extent_ns_mi": round(ns_mi, 1),
            "extent_ew_mi": round(ew_mi, 1),
            "area_sq_mi": round(ns_mi * ew_mi, 1),
            "nn_avg_mi": round(sum(nn_dists) / len(nn_dists), 2) if nn_dists else 0,
            "nn_min_mi": round(min(nn_dists), 2) if nn_dists else 0,
            "nn_max_mi": round(max(nn_dists), 2) if nn_dists else 0,
            "density_per_sq_mi": round(len(structs) / max(ns_mi * ew_mi, 0.01), 1),
        },
        "center": {
            "lat": round(sum(lats) / len(lats), 4) if lats else 0,
            "lon": round(sum(lons) / len(lons), 4) if lons else 0,
        },
        "overlays": {
            "city_label": overlays.get("city_label", ""),
            "files_loaded": overlays.get("files", []),
        },
        "quality": {},
    }

    # Quality scores (0-100)
    q = metrics["quality"]
    q["connectivity"] = 100 if len(components) == 1 and len(orphans) == 0 else max(0, 100 - len(orphans) * 10 - (len(components) - 1) * 20)
    q["spacing_uniformity"] = max(0, 100 - int((max(nn_dists) - min(nn_dists)) / max(sum(nn_dists) / len(nn_dists), 0.01) * 50)) if nn_dists else 0
    q["completeness"] = min(100, len(structs) * 2) if len(structs) < 50 else 100

    return metrics


def save_study(metrics, jpd_path):
    """Save metrics to Noelle's study folder and copy the .jpd."""
    STUDY_DIR.mkdir(parents=True, exist_ok=True)

    name = metrics["name"]

    # Save metrics JSON
    metrics_path = STUDY_DIR / f"{name}_metrics.json"
    with open(metrics_path, "w") as f:
        json.dump(metrics, f, indent=2)

    # Copy the .jpd to study folder
    jpd_dest = STUDY_DIR / Path(jpd_path).name
    shutil.copy2(jpd_path, jpd_dest)

    print(f"  Saved: {metrics_path.name}")
    print(f"  Copied: {jpd_dest.name}")

    return metrics_path


def build_study_text(metrics):
    """Build a text summary for vector store ingestion."""
    m = metrics
    t = m["topology"]
    s = m["spacing"]
    q = m["quality"]

    text = f"""Network Study: {m['name']}
State: {m['state']} | City: {m['city']}
Analyzed: {m['analyzed_at']}

TOPOLOGY:
{t['total_structures']} structures ({t['stations']} stations, {t['traffic_circles']} traffic circles)
Station-to-circle ratio: {t['station_to_circle_ratio']}
{t['lines']} lines, {t['cps_total']} CPs ({t['cps_connected']} connected, {t['cps_open']} open)
Orphans: {t['orphans']}
Connected components: {t['connected_components']} (sizes: {t['component_sizes']})

SPACING:
Extent: {s['extent_ns_mi']} × {s['extent_ew_mi']} mi ({s['area_sq_mi']} sq mi)
Nearest-neighbor: avg {s['nn_avg_mi']} mi, min {s['nn_min_mi']} mi, max {s['nn_max_mi']} mi
Density: {s['density_per_sq_mi']} structures/sq mi

QUALITY SCORES:
Connectivity: {q['connectivity']}/100
Spacing uniformity: {q['spacing_uniformity']}/100
Completeness: {q['completeness']}/100

OVERLAYS: {m['overlays']['city_label']}
Data loaded: {', '.join(m['overlays']['files_loaded']) or 'none'}
"""
    return text


def ingest_to_vectorstore(metrics, text):
    """Ingest study metrics into Noelle's vector store."""
    try:
        import chromadb
    except ImportError:
        print("  chromadb not installed — skipping vector store")
        return

    client = chromadb.PersistentClient(path=CHROMA_DIR)
    collection = client.get_or_create_collection(COLLECTION)

    doc_id = f"study/{metrics['name']}"

    # Chunk if needed
    chunks = [text[i:i + 1500] for i in range(0, len(text), 1300)]

    ids = [f"{doc_id}/chunk_{i}" for i in range(len(chunks))]
    metas = [{
        "domain": "RT",
        "category": "network_study",
        "doc_id": doc_id,
        "source": metrics["filename"],
        "state": metrics["state"],
        "city": metrics["city"],
        "structures": metrics["topology"]["total_structures"],
        "components": metrics["topology"]["connected_components"],
        "nn_avg_mi": metrics["spacing"]["nn_avg_mi"],
    } for _ in chunks]

    collection.upsert(ids=ids, documents=chunks, metadatas=metas)
    print(f"  Vector store: {len(chunks)} chunks → {COLLECTION}")


def process_file(jpd_path):
    """Analyze, save, and ingest a single .jpd file."""
    print(f"\n{'=' * 60}")
    print(f"  {Path(jpd_path).name}")
    print(f"{'=' * 60}")

    metrics = analyze_network(jpd_path)

    t = metrics["topology"]
    s = metrics["spacing"]
    q = metrics["quality"]
    print(f"  {t['total_structures']} structures ({t['stations']} sta, {t['traffic_circles']} cir)")
    print(f"  {t['connected_components']} component(s), {t['orphans']} orphans, {t['cps_open']} open CPs")
    print(f"  Spacing: avg {s['nn_avg_mi']} mi, extent {s['extent_ns_mi']}×{s['extent_ew_mi']} mi")
    print(f"  Quality: conn={q['connectivity']} spacing={q['spacing_uniformity']} complete={q['completeness']}")

    save_study(metrics, jpd_path)

    text = build_study_text(metrics)
    ingest_to_vectorstore(metrics, text)


def main():
    parser = argparse.ArgumentParser(description="Noelle network study — analyze and learn from .jpd files")
    parser.add_argument("jpd_file", nargs="?", help="Path to .jpd file to analyze")
    parser.add_argument("--all", action="store_true", help="Analyze all networks in mesh_mobility_maps/")
    parser.add_argument("--ingest", action="store_true", help="Re-ingest all existing study files")
    args = parser.parse_args()

    if args.all:
        for jpd in sorted(MAPS_DIR.glob("*.jpd")):
            try:
                process_file(str(jpd))
            except Exception as e:
                print(f"  ERROR: {e}")
    elif args.ingest:
        for metrics_file in sorted(STUDY_DIR.glob("*_metrics.json")):
            with open(metrics_file) as f:
                metrics = json.load(f)
            text = build_study_text(metrics)
            ingest_to_vectorstore(metrics, text)
            print(f"  Re-ingested: {metrics_file.name}")
    elif args.jpd_file:
        process_file(args.jpd_file)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
