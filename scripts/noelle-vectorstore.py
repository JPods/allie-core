#!/usr/bin/env python3
"""
Noelle Vector Store — network design intelligence across all JPods programs.

Noelle validates and reasons about network design across three programs:
  - MeshMobility (RT): network topology, simulation results, travel times
  - SketchUp (SU): 3D geometry, station templates, build pipeline
  - Physical (PH): scale model behavior, ezone faults, trip telemetry

Three data layers feed network placement decisions:
  1. Traffic density (AADT) — corridors with 10,000+ trips/day = payback candidates
  2. Accident heat maps (NHTSA FARS) — safety argument for JPods
  3. Pedestrian density (WalkScore, cellphone) — dense walking = demand nodes

Usage:
    python3 noelle-vectorstore.py index             # Index all knowledge
    python3 noelle-vectorstore.py seed              # Seed foundational design rules
    python3 noelle-vectorstore.py ingest-network URL # Ingest a MeshMobility network descriptor
    python3 noelle-vectorstore.py search "query"    # Search
    python3 noelle-vectorstore.py stats             # Show statistics
"""
import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import chromadb

ALLIE_HOME = Path.home() / "Allie"
CHROMA_DIR = str(ALLIE_HOME / ".chroma_db_noelle")
COLLECTION = "noelle_network_design"

# Directories to index for network design knowledge
INDEX_DIRS = [
    ("readmes", ALLIE_HOME / "readmes"),
    ("agents", ALLIE_HOME / "readmes" / "agents"),
    ("wisdom", ALLIE_HOME / "readmes" / "wisdom"),
    ("tfts", ALLIE_HOME / "process" / "inbox"),
    ("facets_noelle", ALLIE_HOME / "facets" / "noelle"),
]

# Also index MeshMobility readmes
RT_DIR = Path.home() / "Documents" / "08_JPods" / "03_Technology" / "00_working_code" / "mesh_mobility" / "readmes"
if RT_DIR.exists():
    INDEX_DIRS.append(("mesh_mobility", RT_DIR))

EXTENSIONS = {".md", ".txt", ".json"}
CHUNK_SIZE = 1500
CHUNK_OVERLAP = 200


def _chunk_text(text, chunk_size=CHUNK_SIZE, overlap=CHUNK_OVERLAP):
    if len(text) <= chunk_size:
        return [text]
    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunk = text[start:end]
        if chunk.strip():
            chunks.append(chunk)
        start = end - overlap
    return chunks


def _content_hash(content):
    return hashlib.md5(content.encode()).hexdigest()[:12]


def get_collection():
    client = chromadb.PersistentClient(path=CHROMA_DIR)
    return client.get_or_create_collection(
        name=COLLECTION,
        metadata={"hnsw:space": "cosine"},
    )


def _upsert_doc(collection, doc_id, content, metadata):
    """Chunk and upsert a document into the collection."""
    chunks = _chunk_text(content)
    ids = []
    documents = []
    metadatas = []
    for i, chunk in enumerate(chunks):
        chunk_id = f"{doc_id}::chunk_{i}::{_content_hash(chunk)}"
        ids.append(chunk_id)
        documents.append(chunk)
        meta = {
            "doc_id": doc_id,
            "chunk_index": i,
            "total_chunks": len(chunks),
            "indexed_at": datetime.now(timezone.utc).isoformat(),
        }
        meta.update(metadata)
        metadatas.append(meta)
    if ids:
        collection.upsert(ids=ids, documents=documents, metadatas=metadatas)
    return len(ids)


def seed():
    """Seed foundational network design rules into the vector store."""
    collection = get_collection()
    total = 0

    rules = [
        {
            "id": "rule/payback-threshold",
            "domain": "economics",
            "content": (
                "JPods 7-Year Payback Threshold\n\n"
                "For a JPods network segment to achieve payback within 7 years, "
                "it must replace approximately 10,000 car-trips per day. This is "
                "the fundamental economic threshold for network placement decisions.\n\n"
                "Data source: Government AADT (Annual Average Daily Traffic) maps "
                "report traffic density by road segment. Corridors at or above "
                "10,000 AADT are candidates for JPods.\n\n"
                "Below 10,000 AADT: the segment may still be viable as part of a "
                "larger network (connecting higher-demand nodes) but cannot justify "
                "standalone investment."
            ),
        },
        {
            "id": "rule/three-overlay-layers",
            "domain": "network_design",
            "content": (
                "Three Data Layers for Network Placement\n\n"
                "1. TRAFFIC DENSITY (AADT): Where are the cars? Government traffic "
                "counting stations report Annual Average Daily Traffic. Segments "
                "with 10,000+ AADT are primary candidates. SC DOT data available "
                "at scdottrafficdata.drakewell.com and info2.scdot.org.\n\n"
                "2. ACCIDENT HEAT MAPS: Where are people dying? High accident "
                "corridors are the strongest safety argument for JPods. NHTSA FARS "
                "API provides crash data with lat/lon. SC DPS maintains state crash "
                "database. Every accident on a JPods corridor is an accident that "
                "JPods eliminates.\n\n"
                "3. PEDESTRIAN DENSITY: Where are people walking? Dense pedestrian "
                "activity = demand nodes that need connecting. Sources: WalkScore.com "
                "(API available), StreetLight Data (cellphone-derived), Replica "
                "(activity-based model). Slow cellphone movement = pedestrians = "
                "demand signal. Dense walking speed clusters are the nodes JPods "
                "connects."
            ),
        },
        {
            "id": "rule/station-spacing",
            "domain": "network_design",
            "content": (
                "Station Spacing and Last-Mile Rule\n\n"
                "Station placement is correct when the Last-Mile distance from any "
                "station is bikeable in under 7 minutes or walkable in under 15 "
                "minutes in dense urban areas.\n\n"
                "Walking speed: ~4.8 km/h → 15 min = 1.2 km radius.\n"
                "Biking speed: ~15 km/h → 7 min = 1.75 km radius.\n\n"
                "JPods is Middle-Mile — station-to-station. Last-Mile modes "
                "(walking, bikes, e-scooters) bridge stations to doors.\n\n"
                "Natalie uses weather factor (1-5) and price factor (1-5) to "
                "maintain equilibrium: JPods fills demand in bad weather; bikes "
                "and walking reclaim share when conditions are good."
            ),
        },
        {
            "id": "rule/network-shape-patterns",
            "domain": "network_design",
            "content": (
                "Network Shape Patterns\n\n"
                "GRID: Rectangular mesh of traffic circles at intersections with "
                "stations mid-block. Best for flat urban areas with regular street "
                "patterns. Provides maximum redundancy — multiple paths between "
                "any two stations.\n\n"
                "LINEAR: Single corridor connecting two endpoints. Lowest cost "
                "to build. Appropriate for connecting two high-demand nodes "
                "(airport ↔ downtown, campus ↔ transit hub).\n\n"
                "HUB-SPOKE: Central station (airport, downtown) with radial lines. "
                "Efficient when demand concentrates at one point. Risk: hub "
                "becomes bottleneck.\n\n"
                "RING: Circular route connecting a series of stations. Good for "
                "CBD or campus loops. Every station reachable in both directions.\n\n"
                "Degree distribution signals network type:\n"
                "  - All degree-2 = linear or ring\n"
                "  - Mix of degree-2 and degree-4 = grid\n"
                "  - One high-degree node + many degree-1 = hub-spoke"
            ),
        },
        {
            "id": "rule/cargo-waste-demand",
            "domain": "economics",
            "content": (
                "Cargo and Waste — The Undervalued Half\n\n"
                "JPods moves passengers AND cargo. The cargo/waste case is often "
                "stronger than the passenger case:\n\n"
                "INBOUND: Pre-sorted goods from warehouses to neighborhood stations, "
                "distributed by cargo bike to the door.\n\n"
                "OUTBOUND: Waste streamed continuously out of the city for sorting. "
                "Fresh waste sorted on arrival supports far higher recycling rates "
                "than weekly mixed collection.\n\n"
                "UPS, FedEx, DHL, Amazon are natural allies: JPods cuts their "
                "Middle-Mile truck cost, eliminates dead-head miles in traffic.\n\n"
                "Fiscal argument to cities: reduced parking demand converts low-tax "
                "parking lots to high-tax productive land (sales tax + property tax); "
                "reduced vehicle trips extend pavement life."
            ),
        },
        {
            "id": "rule/color-standard",
            "domain": "all",
            "content": (
                "JPods Color Standard — All Programs\n\n"
                "Red = inbound (hot end — vehicle arriving)\n"
                "Blue = outbound (cool end — vehicle departing)\n\n"
                "Applied to: MeshMobility guideway polylines, CP stub-pair dots, "
                "SketchUp 3D geometry, animation, physical model LEDs.\n"
                "Never reverse. Never monochrome for directional elements."
            ),
        },
        {
            "id": "rule/connection-points",
            "domain": "network_design",
            "content": (
                "Connection Point (CP) Rules\n\n"
                "Every structure (station, traffic circle) exposes stub-pairs. "
                "CPs connect to CPs — never individual lines. Breaking a connection "
                "removes both guideways of the pair.\n\n"
                "When connecting two structures, the system finds the closest pair "
                "of open CPs between them automatically. The user clicks any CP on "
                "structure A, then any CP on structure B.\n\n"
                "All guideways are one-way. All station circulation is CCW.\n\n"
                "Traffic circles have 4 CPs (N/E/S/W or 45° rotated). "
                "Stations have 2 CPs (CP_near_far and CP_far_near)."
            ),
        },
        {
            "id": "rule/walkscore-demand",
            "domain": "network_design",
            "content": (
                "WalkScore as Demand Proxy\n\n"
                "WalkScore.com rates walkability on a 0-100 scale. High WalkScore "
                "areas have dense pedestrian activity — these are the nodes JPods "
                "needs to connect.\n\n"
                "WalkScore also provides Transit Score and Bike Score. A location "
                "with high Walk Score but low Transit Score is an underserved market "
                "— strong demand, weak supply.\n\n"
                "Greenville SC: Walk Score 81 (Very Walkable), Transit Score 30 "
                "(Some Transit), Bike Score 80 (Very Bikeable). The gap between "
                "Walk Score and Transit Score (81 vs 30) signals unmet transit demand.\n\n"
                "WalkScore API available for programmatic access."
            ),
        },
        {
            "id": "rule/network-descriptor",
            "domain": "network_design",
            "content": (
                "Network Descriptor — What Noelle Sees\n\n"
                "The /api/network/describe endpoint generates a structured view:\n"
                "- Spatial: center lat/lon, N-S and E-W extent in km\n"
                "- Topology: station/circle counts, connected/open CPs, orphans, "
                "connected components, degree distribution\n"
                "- Spacing: nearest-neighbor avg/min/max in meters\n"
                "- Per-structure: position, heading, connection count, neighbors, "
                "open CPs\n\n"
                "Quality signals from the descriptor:\n"
                "- Orphaned structures (all CPs open) = unfinished connections\n"
                "- Multiple components = disconnected sub-networks\n"
                "- Degree-1 nodes = dead ends (may be intentional at terminal stations)\n"
                "- Large nn_spacing gaps = coverage holes\n"
                "- High open CP count relative to total = under-connected network"
            ),
        },
        {
            "id": "data-source/scdot-aadt",
            "domain": "data",
            "content": (
                "SC DOT AADT Data Sources\n\n"
                "Interactive map: https://scdottrafficdata.drakewell.com/publicmultinodemap.asp\n"
                "Station data includes: site ID, lat/lon, direction, lanes, speed limit, "
                "AADT, truck percentage, real-time volume.\n"
                "Export formats: PDF, Excel. Reports: daily/weekly/monthly volume, speed "
                "analytics, classification breakdowns.\n\n"
                "Shapefile downloads: https://info2.scdot.org/sites/GIS/SitePages/GISFiles.aspx\n"
                "Available: Statewide Traffic Lines and Points (2009-2017 as shapefiles).\n"
                "Newer data via ArcGIS: scdot.maps.arcgis.com\n\n"
                "For MeshMobility overlay: convert shapefile to GeoJSON, filter to map bounds, "
                "save as mesh_mobility/overlays/aadt.geojson"
            ),
        },
        {
            "id": "data-source/nhtsa-fars",
            "domain": "data",
            "content": (
                "NHTSA FARS Crash Data\n\n"
                "API: https://crashviewer.nhtsa.dot.gov/CrashAPI\n"
                "Provides: crash location (lat/lon), severity, date, vehicle types, "
                "contributing factors. Queryable by state and year.\n\n"
                "SC DPS also maintains state-level crash database at "
                "scdps.sc.gov/ohsjp/stat_services\n\n"
                "For MeshMobility overlay: query FARS API for South Carolina, "
                "extract lat/lon and severity, save as mesh_mobility/overlays/accidents.geojson\n\n"
                "High-accident corridors are the strongest safety and political "
                "argument for JPods. Every accident on a JPods corridor is one that "
                "JPods prevents by removing cars from the road."
            ),
        },
        {
            "id": "data-source/walkscore",
            "domain": "data",
            "content": (
                "WalkScore Pedestrian Density Data\n\n"
                "Website: https://www.walkscore.com\n"
                "API: available at walkscore.com/professional (requires API key)\n"
                "Returns: Walk Score, Transit Score, Bike Score for any lat/lon.\n\n"
                "Use case: identify dense pedestrian clusters as demand nodes.\n"
                "High Walk Score + low Transit Score = underserved market.\n\n"
                "Alternative sources for pedestrian density:\n"
                "- StreetLight Data: cellphone-derived pedestrian volumes, API available\n"
                "- Replica: activity-based travel model with walking trip data\n"
                "- Both are commercial; WalkScore API is the most accessible.\n\n"
                "For MeshMobility overlay: query WalkScore API on a grid across map "
                "bounds, interpolate to heat map, save as mesh_mobility/overlays/mobility.geojson"
            ),
        },
    ]

    for rule in rules:
        n = _upsert_doc(
            collection,
            rule["id"],
            rule["content"],
            {"domain": rule["domain"], "category": "seed"},
        )
        total += n
        print(f"  {rule['id']}: {n} chunks")

    print(f"\nSeeded {total} chunks into {COLLECTION}")
    print(f"Store: {collection.count()} total chunks in {CHROMA_DIR}")


def index_files():
    """Index knowledge files from all configured directories."""
    collection = get_collection()
    total_files = 0
    total_chunks = 0

    for category, directory in INDEX_DIRS:
        if not directory.exists():
            continue
        for path in sorted(directory.rglob("*")):
            if not path.is_file():
                continue
            if path.suffix.lower() not in EXTENSIONS:
                continue
            if any(part.startswith(".") for part in path.parts):
                continue
            if "archive" in str(path).lower():
                continue

            try:
                content = path.read_text(errors="replace")
            except Exception:
                continue

            if not content.strip():
                continue

            doc_id = f"file/{category}/{path.name}"
            n = _upsert_doc(
                collection,
                doc_id,
                content,
                {
                    "category": category,
                    "filename": path.name,
                    "path": str(path),
                    "domain": _guess_domain(path),
                },
            )
            total_chunks += n
            total_files += 1
            print(f"  {doc_id}: {n} chunks")

    print(f"\nIndexed {total_files} files, {total_chunks} chunks")
    print(f"Store: {collection.count()} total chunks in {CHROMA_DIR}")


def _guess_domain(path):
    """Guess domain from file path."""
    s = str(path).lower()
    if "mesh_mobility" in s or "route_time" in s or "route-time" in s:
        return "RT"
    if "sketchup" in s or "su_jpods" in s or "jpod_" in s:
        return "SU"
    if "physical" in s or "jpodssm" in s or "nora" in s:
        return "PH"
    if "noelle" in s:
        return "noelle"
    if "natalie" in s:
        return "natalie"
    if "sally" in s:
        return "sally"
    return "CROSS"


def ingest_network(url="http://localhost:5050/api/network/describe"):
    """Ingest a network descriptor from MeshMobility into the vector store."""
    import urllib.request

    try:
        with urllib.request.urlopen(url) as r:
            data = json.loads(r.read())
    except Exception as e:
        print(f"Failed to fetch network descriptor: {e}")
        sys.exit(1)

    if "error" in data:
        print(f"Error: {data['error']}")
        sys.exit(1)

    collection = get_collection()
    net_id = data.get("network_id", "unknown")
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
    total = 0

    # Ingest summary
    n = _upsert_doc(
        collection,
        f"network/{net_id}/{ts}/summary",
        data["summary"],
        {"domain": "RT", "category": "network", "network_id": net_id},
    )
    total += n

    # Ingest topology as structured text
    topo = data.get("topology", {})
    topo_text = (
        f"Network topology for {net_id}:\n"
        f"Stations: {topo.get('stations', 0)}, Circles: {topo.get('circles', 0)}\n"
        f"Connected CPs: {topo.get('connected_cps', 0)}, Open CPs: {topo.get('open_cps', 0)}\n"
        f"Connected components: {topo.get('components', 0)} "
        f"(largest: {topo.get('largest_component', 0)})\n"
        f"Orphans: {', '.join(topo.get('orphans', []))}\n"
        f"Degree distribution: {topo.get('degree_distribution', {})}"
    )
    n = _upsert_doc(
        collection,
        f"network/{net_id}/{ts}/topology",
        topo_text,
        {"domain": "RT", "category": "network", "network_id": net_id},
    )
    total += n

    # Ingest structure list (chunked by groups of 20)
    structures = data.get("structures", [])
    for i in range(0, len(structures), 20):
        batch = structures[i:i + 20]
        lines = []
        for s in batch:
            nbs = ", ".join(s.get("neighbors", []))
            open_cps = ", ".join(s.get("open_cps", []))
            lines.append(
                f"{s['id']} ({s['type']}, {s.get('heading', 0)}°) "
                f"at ({s['lat']}, {s['lon']}) "
                f"connections={s.get('connections', 0)} "
                f"neighbors=[{nbs}] "
                f"open_cps=[{open_cps}]"
            )
        batch_text = f"Structures in {net_id} (batch {i // 20 + 1}):\n" + "\n".join(lines)
        n = _upsert_doc(
            collection,
            f"network/{net_id}/{ts}/structures_{i // 20}",
            batch_text,
            {"domain": "RT", "category": "network", "network_id": net_id},
        )
        total += n

    print(f"\nIngested network '{net_id}': {total} chunks")
    print(f"Store: {collection.count()} total chunks in {CHROMA_DIR}")


def search(query, n_results=5, domain=None):
    """Search the vector store, optionally filtering by domain."""
    collection = get_collection()
    kwargs = {"query_texts": [query], "n_results": n_results}
    if domain:
        kwargs["where"] = {"domain": domain}
    results = collection.query(**kwargs)

    if not results or not results["documents"]:
        print("No results found.")
        return

    for i, doc in enumerate(results["documents"][0]):
        meta = results["metadatas"][0][i] if results["metadatas"] else {}
        dist = results["distances"][0][i] if results["distances"] else None
        print(f"\n--- Result {i + 1} (distance: {dist:.4f}) ---")
        print(f"Source: {meta.get('doc_id', '?')} [{meta.get('domain', '?')}]")
        print(doc[:500])


def stats():
    """Show store statistics."""
    collection = get_collection()
    print(f"Collection: {COLLECTION}")
    print(f"Persist dir: {CHROMA_DIR}")
    print(f"Total chunks: {collection.count()}")

    # Domain breakdown
    all_meta = collection.get(include=["metadatas"])
    if all_meta and all_meta["metadatas"]:
        domains = {}
        categories = {}
        for m in all_meta["metadatas"]:
            d = m.get("domain", "unknown")
            c = m.get("category", "unknown")
            domains[d] = domains.get(d, 0) + 1
            categories[c] = categories.get(c, 0) + 1
        print("\nBy domain:")
        for d, n in sorted(domains.items()):
            print(f"  {d}: {n} chunks")
        print("\nBy category:")
        for c, n in sorted(categories.items()):
            print(f"  {c}: {n} chunks")


def main():
    parser = argparse.ArgumentParser(description="Noelle Network Design Vector Store")
    parser.add_argument("command", choices=["index", "seed", "ingest-network", "search", "stats"])
    parser.add_argument("query", nargs="?", default="")
    parser.add_argument("--n", type=int, default=5)
    parser.add_argument("--domain", type=str, default=None,
                        help="Filter search by domain (RT, SU, PH, CROSS, economics, etc.)")
    parser.add_argument("--url", type=str,
                        default="http://localhost:5050/api/network/describe",
                        help="MeshMobility describe endpoint URL")
    args = parser.parse_args()

    if args.command == "seed":
        seed()
    elif args.command == "index":
        index_files()
    elif args.command == "ingest-network":
        ingest_network(args.url if args.query == "" else args.query)
    elif args.command == "search":
        if not args.query:
            print("Usage: noelle-vectorstore.py search 'your query'")
            sys.exit(1)
        search(args.query, n_results=args.n, domain=args.domain)
    elif args.command == "stats":
        stats()


if __name__ == "__main__":
    main()
