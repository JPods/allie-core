#!/usr/bin/env python3
"""
allie-crash-convert.py — Convert raw state crash data to Allie standard format.

Allie harvests. Noelle consumes. Raw state formats vary wildly.
This script normalizes everything to the standard crashes_all_{st}.geojson format.

Usage:
  python3 allie-crash-convert.py --state ok --source /path/to/raw.geojson
  python3 allie-crash-convert.py --state ok --arcgis URL
  python3 allie-crash-convert.py --list   # show known state field mappings
"""

import argparse
import json
import math
import os
import sys
import gzip
import urllib.request
from collections import defaultdict, Counter
from pathlib import Path
from datetime import datetime, timezone

OVERLAY_5TB = Path("/Volumes/Allie/data/overlays")
OVERLAY_LOCAL = Path(__file__).parent.parent / "Documents" / "08_JPods" / "03_Technology" / "00_working_code" / "route_time" / "overlays"

GRID_CELL_M = 200
CELL_DEG = GRID_CELL_M / 111000  # ~0.0018°

# State-specific field mappings — each state's raw data uses different column names
FIELD_MAPS = {
    "ok": {
        "lat": ["LATITUDE"],
        "lon": ["LONGITUDE"],
        "fatal": ["FAT"],
        "injury": ["INJ", "INJURED"],
        "pedestrian": ["PEDSTRIANS", "PedRelated"],
        "bicycle": ["PedalCyclist"],
        "severity": ["SEVERITY_C", "INJSEVER"],
        "collision_type": ["TYPE_COLL"],
        "road": ["HWY_NAME", "ON_STREET"],
        "year": ["YEAR_"],
        "fatal_flag": ["FAT_C"],
        "injury_flag": ["INJURED"],
    },
    # Add more states as we harvest them
    "nc": {
        "lat": ["LATITUDE", "lat"],
        "lon": ["LONGITUDE", "lon"],
        "fatal": ["FATALS", "fatals"],
        "injury": ["INJURIES", "injuries"],
        "pedestrian": ["PEDCOUNT", "pedestrian"],
        "bicycle": ["BIKECOUNT", "bicycle"],
        "severity": ["SEVERITY", "severity"],
        "collision_type": ["COLLISION_TYPE", "type"],
        "road": ["ROAD", "road_name"],
        "year": ["YEAR", "year"],
    },
}


def _get_field(props, field_names):
    """Try multiple field names, return first match."""
    for name in field_names:
        if name in props:
            return props[name]
    return None


def _to_int(val):
    """Convert to int, handling 'N', 'No', None, etc."""
    if val is None or val == "" or val == "N" or val == "No":
        return 0
    try:
        return int(float(val))
    except (ValueError, TypeError):
        return 0


def _to_bool_int(val):
    """Convert boolean-ish value to 0/1."""
    if val is None:
        return 0
    if isinstance(val, (int, float)):
        return 1 if val > 0 else 0
    s = str(val).strip().upper()
    return 1 if s in ("Y", "YES", "TRUE", "1") else 0


def load_raw(path):
    """Load raw GeoJSON from file."""
    with open(path) as f:
        return json.load(f)


def fetch_arcgis(url):
    """Fetch all features from an ArcGIS Feature Service."""
    all_features = []
    offset = 0
    while True:
        query_url = f"{url}/0/query?where=1%3D1&outFields=*&f=geojson&resultRecordCount=2000&resultOffset={offset}"
        req = urllib.request.Request(query_url, headers={"User-Agent": "Allie/CrashHarvester"})
        with urllib.request.urlopen(req, timeout=90) as resp:
            raw = resp.read()
            if raw[:2] == b'\x1f\x8b':
                raw = gzip.decompress(raw)
            data = json.loads(raw.decode())
        feats = data.get("features", [])
        if not feats:
            break
        all_features.extend(feats)
        print(f"  offset {offset}: +{len(feats)} (total {len(all_features)})")
        offset += 2000
        if len(feats) < 2000:
            break
    return {"type": "FeatureCollection", "features": all_features}


def convert(raw_geojson, state, source_info):
    """Convert raw state crash data to Allie standard gridded format."""
    fmap = FIELD_MAPS.get(state)
    if not fmap:
        print(f"No field mapping for state '{state}' — using generic")
        fmap = FIELD_MAPS.get("ok")  # default to OK mapping

    grid = defaultdict(lambda: {
        "crashes": 0, "injury": 0, "fatal": 0,
        "pedestrian": 0, "bicycle": 0,
        "severity_sum": 0, "types": Counter(), "roads": Counter(),
    })

    years_seen = set()
    skipped = 0

    for feat in raw_geojson.get("features", []):
        props = feat.get("properties", {})
        geom = feat.get("geometry", {})

        # Get coordinates
        lat, lon = None, None
        if geom and geom.get("coordinates"):
            lon, lat = geom["coordinates"][0], geom["coordinates"][1]
        if lat is None:
            lat_val = _get_field(props, fmap.get("lat", []))
            lon_val = _get_field(props, fmap.get("lon", []))
            if lat_val and lon_val:
                try:
                    lat, lon = float(lat_val), float(lon_val)
                except (ValueError, TypeError):
                    skipped += 1
                    continue

        if lat is None or lon is None or lat == 0 or lon == 0:
            skipped += 1
            continue

        # Snap to grid
        gx = round(lon / CELL_DEG) * CELL_DEG
        gy = round(lat / CELL_DEG) * CELL_DEG
        key = (round(gx, 6), round(gy, 6))

        grid[key]["crashes"] += 1

        # Extract fields
        fat = _to_int(_get_field(props, fmap.get("fatal", [])))
        inj = _to_int(_get_field(props, fmap.get("injury", [])))
        ped = _to_int(_get_field(props, fmap.get("pedestrian", [])))
        bike = _to_int(_get_field(props, fmap.get("bicycle", [])))
        sev = _to_int(_get_field(props, fmap.get("severity", [])))
        ctype = _get_field(props, fmap.get("collision_type", [])) or ""
        road = _get_field(props, fmap.get("road", [])) or ""
        year = _get_field(props, fmap.get("year", []))

        # Handle flag fields (Y/N vs numeric)
        if fat == 0:
            fat_flag = _get_field(props, fmap.get("fatal_flag", []))
            if _to_bool_int(fat_flag):
                fat = 1
        if inj == 0:
            inj_flag = _get_field(props, fmap.get("injury_flag", []))
            if _to_bool_int(inj_flag):
                inj = 1

        grid[key]["fatal"] += fat
        grid[key]["injury"] += (1 if inj > 0 or fat > 0 else 0)
        grid[key]["pedestrian"] += (1 if ped > 0 else 0)
        grid[key]["bicycle"] += (1 if bike > 0 else 0)
        grid[key]["severity_sum"] += sev if sev > 0 else 1
        if ctype:
            grid[key]["types"][str(ctype)] += 1
        if road:
            grid[key]["roads"][str(road)] += 1

        if year:
            try:
                years_seen.add(int(year))
            except (ValueError, TypeError):
                pass

    # Compute years span
    if years_seen:
        years = max(years_seen) - min(years_seen) + 1
    else:
        years = 4  # default

    # Build output features
    features = []
    for (lon, lat), cell in grid.items():
        c = cell["crashes"]
        density = round(c / max(years, 1), 1)
        sev_avg = round(cell["severity_sum"] / max(c, 1), 1)
        top_type = cell["types"].most_common(1)[0][0] if cell["types"] else ""
        top_road = cell["roads"].most_common(1)[0][0] if cell["roads"] else ""

        features.append({
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [lon, lat]},
            "properties": {
                "crashes": c,
                "injury": cell["injury"],
                "fatal": cell["fatal"],
                "pedestrian": cell["pedestrian"],
                "bicycle": cell["bicycle"],
                "density": density,
                "severity_avg": sev_avg,
                "top_type": top_type,
                "road": top_road,
            },
        })

    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    result = {
        "type": "FeatureCollection",
        "metadata": {
            "state": state,
            "source": source_info.get("source", ""),
            "source_url": source_info.get("url", ""),
            "years": f"{min(years_seen)}-{max(years_seen)}" if years_seen else "unknown",
            "harvested": ts,
            "total_raw": len(raw_geojson.get("features", [])),
            "total_cells": len(features),
            "grid_cell_m": GRID_CELL_M,
            "skipped": skipped,
            "converter": "allie-crash-convert.py",
        },
        "features": features,
    }

    return result


def save(data, state):
    """Save to both 5TB and local."""
    filename = f"crashes_all_{state}.geojson"
    for d in (OVERLAY_5TB, OVERLAY_LOCAL):
        try:
            d.mkdir(parents=True, exist_ok=True)
            with open(d / filename, "w") as f:
                json.dump(data, f)
            print(f"  Saved: {d / filename}")
        except OSError as e:
            print(f"  Skip: {d / filename} ({e})")

    meta = data.get("metadata", {})
    print(f"\n  State: {state.upper()}")
    print(f"  Source: {meta.get('source', '?')}")
    print(f"  Raw crashes: {meta.get('total_raw', '?')}")
    print(f"  Grid cells: {meta.get('total_cells', '?')}")
    print(f"  Years: {meta.get('years', '?')}")
    print(f"  Skipped: {meta.get('skipped', 0)}")


def main():
    parser = argparse.ArgumentParser(description="Convert raw state crash data to Allie standard format")
    parser.add_argument("--state", required=True, help="State abbreviation (e.g., ok, nc)")
    parser.add_argument("--source", help="Path to raw GeoJSON file")
    parser.add_argument("--arcgis", help="ArcGIS Feature Service URL")
    parser.add_argument("--source-name", default="", help="Human name for the source")
    parser.add_argument("--list", action="store_true", help="List known field mappings")
    args = parser.parse_args()

    if args.list:
        for st, fmap in sorted(FIELD_MAPS.items()):
            print(f"\n{st.upper()}:")
            for field, names in fmap.items():
                print(f"  {field}: {names}")
        return

    state = args.state.lower()

    if args.arcgis:
        print(f"Fetching from ArcGIS: {args.arcgis}")
        raw = fetch_arcgis(args.arcgis)
        source_info = {"source": args.source_name or "ArcGIS", "url": args.arcgis}
    elif args.source:
        print(f"Loading from file: {args.source}")
        raw = load_raw(args.source)
        source_info = {"source": args.source_name or os.path.basename(args.source), "url": ""}
    else:
        parser.print_help()
        return

    print(f"Raw features: {len(raw.get('features', []))}")
    result = convert(raw, state, source_info)
    save(result, state)


if __name__ == "__main__":
    main()
