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
OVERLAY_LOCAL = Path.home() / "Documents" / "08_JPods" / "03_Technology" / "00_working_code" / "mesh_mobility" / "overlays"

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
    "va": {
        "lat": ["LAT"],
        "lon": ["LON"],
        "fatal": ["K_PEOPLE"],
        "injury": ["PERSONS_INJURED"],
        "pedestrian": ["PED_NONPED"],
        "bicycle": ["BIKE_NONBIKE"],
        "severity": ["CRASH_SEVERITY"],
        "collision_type": ["COLLISION_TYPE"],
        "road": ["ROUTE_OR_STREET_NM", "RTE_NM"],
        "year": ["CRASH_YEAR"],
        "fatal_flag": ["K_PEOPLE"],
        "injury_flag": ["PERSONS_INJURED"],
        "ped_killed": ["PEDESTRIANS_KILLED"],
        "ped_injured": ["PEDESTRIANS_INJURED"],
    },
    "fl": {
        "lat": ["LATITUDE", "SAFETYLAT"],
        "lon": ["LONGITUDE", "SAFETYLON"],
        "fatal": ["NUMBER_OF_KILLED"],
        "injury": ["NUMBER_OF_INJURED"],
        "pedestrian": ["NUMBER_OF_PEDESTRIANS"],
        "bicycle": ["NUMBER_OF_BICYCLISTS"],
        "severity": ["INJSEVER"],
        "collision_type": ["CRRATECD"],
        "road": ["ON_ROADWAY_NAME"],
        "year": ["CALENDAR_YEAR"],
    },
    "ia": {
        "lat": ["YCOORD"],
        "lon": ["XCOORD"],
        "fatal": ["FATALITIES"],
        "injury": ["INJURIES"],
        "pedestrian": [],
        "bicycle": [],
        "severity": ["CSEV"],
        "collision_type": ["CRCOMNNR"],
        "road": ["LITERAL"],
        "year": ["CRASH_DATE"],
    },
    "tn": {
        "lat": [],
        "lon": [],
        "fatal": ["TOTALKILLE"],
        "injury": ["TOTALINJUR"],
        "pedestrian": [],
        "bicycle": [],
        "severity": ["TYPEOFCRAS"],
        "collision_type": ["MANNEROFCO"],
        "road": ["NBR_RT2"],
        "year": ["YEAROFCRAS"],
    },
    "il": {
        "lat": ["TSCrashLatitude"],
        "lon": ["TSCrashLongitude"],
        "fatal": ["TotalFatals"],
        "injury": ["TotalInjured"],
        "pedestrian": [],
        "bicycle": [],
        "severity": ["CrashSeverityCd", "CrashSeverity"],
        "collision_type": ["CollisionTypeCode", "TypeOfFirstCrash"],
        "road": ["RouteNumber"],
        "year": ["CrashYr", "AgencyReportYear"],
    },
    "or": {
        "lat": ["LAT_DD"],
        "lon": ["LONGTD_DD"],
        "fatal": ["TOT_FATAL_CNT"],
        "injury": ["TOT_INJ_LVL_A_CNT"],
        "pedestrian": ["TOT_PED_CNT"],
        "bicycle": ["TOT_PEDCYCL_CNT"],
        "severity": ["HIGHEST_INJ_SVRTY_CD", "KABCO"],
        "collision_type": ["COLLIS_TYP_LONG_DESC", "CRASH_TYP_LONG_DESC"],
        "road": ["ST_FULL_NM", "RTE_NM"],
        "year": ["CRASH_YR_NO"],
    },
    "ak": {
        "lat": ["Latitude"],
        "lon": ["Longitude"],
        "fatal": ["Number_of_Fatalities"],
        "injury": ["Number_of_Serious_Injuries", "Number_of_Minor_Injuries"],
        "pedestrian": [],
        "bicycle": [],
        "severity": ["Crash_Severity", "COL_SEVERITY"],
        "collision_type": ["Manner_of_Collision", "COL_TYPE"],
        "road": ["Street"],
        "year": ["Year", "COL_YEAR_"],
    },
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
    "dc": {
        "lat": ["LATITUDE"],
        "lon": ["LONGITUDE"],
        "fatal": [],
        "fatal_sum": ["FATAL_DRIVER", "FATAL_PEDESTRIAN", "FATAL_BICYCLIST", "FATALPASSENGER", "FATALOTHER"],
        "injury": [],
        "injury_sum": ["MAJORINJURIES_DRIVER", "MINORINJURIES_DRIVER", "MAJORINJURIES_PEDESTRIAN", "MINORINJURIES_PEDESTRIAN", "MAJORINJURIES_BICYCLIST", "MINORINJURIES_BICYCLIST"],
        "pedestrian": ["TOTAL_PEDESTRIANS"],
        "bicycle": ["TOTAL_BICYCLES"],
        "severity": [],
        "collision_type": [],
        "road": ["ADDRESS", "NEARESTINTSTREETNAME"],
        "year": ["REPORTDATE"],
    },
    "ut": {
        "lat": ["lat_utm_y"],
        "lon": ["long_utm_x"],
        "fatal": ["number_fatalities"],
        "injury": [],
        "injury_sum": ["number_four_injuries", "number_three_injuries", "number_two_injuries", "number_one_injuries"],
        "pedestrian": ["pedestrian_involved"],
        "bicycle": ["bicyclist_involved"],
        "severity": ["crash_severity_desc"],
        "collision_type": ["manner_collision_desc"],
        "road": ["main_road_name"],
        "year": ["crash_datetime"],
    },
    "pa": {
        "lat": ["DEC_LAT"],
        "lon": ["DEC_LONG"],
        "fatal": ["FATAL_COUN", "FATAL"],
        "injury": ["TOT_INJ_CO", "INJURY"],
        "pedestrian": ["PEDESTRIAN", "PED_COUNT"],
        "bicycle": ["BICYCLE"],
        "severity": ["MAX_SEVERI"],
        "collision_type": ["COLLISION_"],
        "road": ["STREET_NAM"],
        "year": ["CRASH_YEAR"],
    },
    "ma": {
        "lat": ["Latitude"],
        "lon": ["Longitude"],
        "fatal": ["Fatalities"],
        "injury": ["Serious_Injuries", "Minor_Injuries", "Possible_Injuries"],
        "pedestrian": ["EA_Pedestrians"],
        "bicycle": ["EA_Bicyclists"],
        "severity": ["Crash_Severity"],
        "collision_type": ["Manner_of_Collision", "First_Harmful_Event"],
        "road": ["Roadway"],
        "year": ["Year"],
    },
    "id": {
        "lat": ["latitude"],
        "lon": ["longitude"],
        "fatal": ["fatalities"],
        "injury": ["numberofinjuries", "injuries"],
        "pedestrian": [],
        "bicycle": [],
        "severity": ["severity"],
        "collision_type": [],
        "road": ["street1", "statehighway"],
        "year": ["year"],
    },
    "de": {
        "lat": ["LATITUDE"],
        "lon": ["LONGITUDE"],
        "fatal": ["CRASH_CLASS"],
        "injury": ["CRASH_CLASS"],
        "pedestrian": ["PED_INVOLVED"],
        "bicycle": ["BIKE_INVOLVED"],
        "severity": ["CRASH_CLASS"],
        "collision_type": ["IMPACT_DESC"],
        "road": [],
        "year": ["YEAR"],
    },
    "co": {
        "lat": ["LATITUDE"],
        "lon": ["LONGITUDE"],
        "fatal": ["KILLED"],
        "injury": ["INJURED"],
        "pedestrian": ["PED_ACT1"],
        "bicycle": [],
        "severity": ["INJLEVEL_0"],
        "collision_type": ["ACCTYPE"],
        "road": ["LOC_01"],
        "year": ["YEAR"],
    },
    "wa": {
        "lat": ["Y"],
        "lon": ["X"],
        "fatal": ["tFatal"],
        "injury": ["tSinjury", "tEinjury", "tPinjury"],
        "pedestrian": ["tPeds", "Ped"],
        "bicycle": ["tBicycles", "PedBike"],
        "severity": ["fCrash"],
        "collision_type": [],
        "road": ["IndxPrimaryTrafficway", "PrimaryTrafficway"],
        "year": ["Year"],
    },
    "ny": {
        "lat": ["USER_LATITUDE", "Y"],
        "lon": ["USER_LONGITUDE", "X"],
        "fatal": ["USER_NUMBER_OF_PERSONS_KILLED"],
        "injury": ["USER_NUMBER_OF_PERSONS_INJURED"],
        "pedestrian": ["USER_NUMBER_OF_PEDESTRIANS_INJU", "USER_NUMBER_OF_PEDESTRIANS_KILL"],
        "bicycle": ["USER_NUMBER_OF_CYCLIST_INJURED", "USER_NUMBER_OF_CYCLIST_KILLED"],
        "severity": [],
        "collision_type": ["USER_CONTRIBUTING_FACTOR_VEHICL"],
        "road": ["USER_ON_STREET_NAME", "USER_CROSS_STREET_NAME"],
        "year": ["USER_CRASH_DATE"],
    },
    "in": {
        "lat": ["Latitude"],
        "lon": ["Longitude"],
        "fatal": [],
        "injury": [],
        "pedestrian": [],
        "bicycle": [],
        "severity": ["Incapacitated_Fatal"],
        "collision_type": ["Manner_of_Colision"],
        "road": ["Cross_Street"],
        "year": ["Year"],
        "fatal_flag": ["Incapacitated_Fatal"],
    },
    "md": {
        "lat": ["MSP_Y_COORDINATE"],
        "lon": ["MSP_X_COORDINATE"],
        "fatal": [],
        "injury": [],
        "pedestrian": [],
        "bicycle": [],
        "severity": [],
        "collision_type": ["CRASH_TYPE"],
        "road": ["ROUTE_PREFIX", "ROUTE_NUMBER"],
        "year": ["DATE_OF_CRASH"],
        "fatal_flag": [],
    },
}


def _get_field(props, field_names):
    """Try multiple field names, return first match."""
    for name in field_names:
        if name in props:
            return props[name]
    return None


def _sum_fields(props, field_names):
    """Sum all matching fields (for states like DC that split fatals by participant type)."""
    total = 0
    for name in field_names:
        if name in props:
            total += _to_int(props[name])
    return total


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
    return 1 if s in ("Y", "YES", "TRUE", "1", "FATAL", "INJURY", "INCAPACITATING") else 0


def load_raw(path):
    """Load raw GeoJSON from file."""
    with open(path) as f:
        return json.load(f)


def fetch_arcgis(url):
    """Fetch all features from an ArcGIS Feature Service."""
    # Detect if URL already ends with a layer number (e.g., .../MapServer/24)
    import re
    if re.search(r'/\d+$', url.rstrip('/')):
        layer_url = url.rstrip('/')
    else:
        layer_url = f"{url}/0"

    # Discover server's max record count
    page_size = 2000
    try:
        info_url = f"{layer_url}?f=json"
        req = urllib.request.Request(info_url, headers={"User-Agent": "Allie/CrashHarvester"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            info = json.loads(resp.read().decode())
        server_max = info.get("maxRecordCount", 2000)
        page_size = min(server_max, 2000)
        print(f"  Server max records per page: {server_max}, using {page_size}")
    except Exception as e:
        print(f"  Could not read server info ({e}), using page_size={page_size}")

    all_features = []
    offset = 0
    retries = 0
    max_retries = 3
    while True:
        query_url = f"{layer_url}/query?where=1%3D1&outFields=*&f=geojson&outSR=4326&resultRecordCount={page_size}&resultOffset={offset}"
        req = urllib.request.Request(query_url, headers={"User-Agent": "Allie/CrashHarvester"})
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                raw = resp.read()
                if raw[:2] == b'\x1f\x8b':
                    raw = gzip.decompress(raw)
                data = json.loads(raw.decode())
        except Exception as e:
            retries += 1
            if retries <= max_retries:
                import time
                print(f"  offset {offset}: retry {retries}/{max_retries} after error: {e}")
                time.sleep(5 * retries)
                continue
            print(f"  offset {offset}: giving up after {max_retries} retries ({e})")
            print(f"  Returning {len(all_features)} features collected so far")
            break
        retries = 0  # reset on success
        feats = data.get("features", [])
        if not feats:
            break
        all_features.extend(feats)
        print(f"  offset {offset}: +{len(feats)} (total {len(all_features)})")
        sys.stdout.flush()
        offset += page_size
        if len(feats) < page_size:
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

        # Extract fields — use _sum_fields if fatal_sum/injury_sum keys exist
        if fmap.get("fatal_sum"):
            fat = _sum_fields(props, fmap["fatal_sum"])
        else:
            fat = _to_int(_get_field(props, fmap.get("fatal", [])))
        if fmap.get("injury_sum"):
            inj = _sum_fields(props, fmap["injury_sum"])
        else:
            inj = _to_int(_get_field(props, fmap.get("injury", [])))
        ped_raw = _get_field(props, fmap.get("pedestrian", []))
        ped = _to_bool_int(ped_raw) if isinstance(ped_raw, str) and ped_raw.strip().upper() in ("Y", "YES", "N", "NO", "TRUE", "FALSE") else _to_int(ped_raw)
        bike_raw = _get_field(props, fmap.get("bicycle", []))
        bike = _to_bool_int(bike_raw) if isinstance(bike_raw, str) and bike_raw.strip().upper() in ("Y", "YES", "N", "NO", "TRUE", "FALSE") else _to_int(bike_raw)
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
                year_str = str(year).strip()
                # Handle ISO datetime strings (e.g., "2026-01-02T09:19:00+00:00")
                if 'T' in year_str or (len(year_str) >= 10 and year_str[4:5] == '-'):
                    y = int(year_str[:4])
                # Handle YYYYMMDD numeric dates (e.g., 20170712)
                elif len(year_str) == 8 and year_str.isdigit() and int(year_str[:4]) > 1990:
                    y = int(year_str[:4])
                else:
                    y = int(float(year))
                    # Handle epoch milliseconds (ArcGIS date fields)
                    if y > 1e12:
                        y = datetime.fromtimestamp(y / 1000, tz=timezone.utc).year
                    elif y > 1e9:
                        y = datetime.fromtimestamp(y, tz=timezone.utc).year
                if 0 <= y <= 99:
                    y += 2000 if y < 50 else 1900
                if 1990 <= y <= 2030:
                    years_seen.add(y)
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
