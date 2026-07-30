#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def cp_key(token: str) -> str:
    t = (token or "").strip()
    if not t:
        return ""
    if "." in t:
        parts = t.split(".")
        if parts and parts[-1].isdigit():
            return ".".join(parts[:-1])
    return t


def equiv(a: str, b: str) -> bool:
    a = (a or "").strip()
    b = (b or "").strip()
    return bool(a and b and (a == b or cp_key(a) == cp_key(b)))


def endpoint_token(cp: str, track: int) -> str:
    return f"{cp}.{track + 1}"


def load_json(path: Path):
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def line_tracks(network_data: dict):
    tracks = {}
    for conn in network_data.get("connections", []):
        if not isinstance(conn, dict):
            continue
        cid = str(conn.get("id", "")).strip()
        frm = conn.get("from") if isinstance(conn.get("from"), dict) else {}
        to = conn.get("to") if isinstance(conn.get("to"), dict) else {}
        if not cid:
            continue
        fsid = str(frm.get("structure_id", "")).strip().upper()
        tsid = str(to.get("structure_id", "")).strip().upper()
        try:
            fstub = int(frm.get("stub", 0))
        except Exception:
            fstub = 0
        try:
            tstub = int(to.get("stub", 0))
        except Exception:
            tstub = 0

        from_cp = f"{fsid}.CP{fstub}"
        to_cp = f"{tsid}.CP{tstub}"
        tracks[cid] = {
            1: {
                "track": 1,
                "entry": endpoint_token(from_cp, 1),
                "exit": endpoint_token(to_cp, 1),
            },
            0: {
                "track": 0,
                "entry": endpoint_token(to_cp, 0),
                "exit": endpoint_token(from_cp, 0),
            },
        }
    return tracks


def normalize_lines(line_sequence):
    out = []
    for item in line_sequence or []:
        if isinstance(item, dict):
            line = str(item.get("line", "")).strip()
        else:
            line = str(item).strip()
        if line:
            out.append(line)
    if len(out) > 1 and out[0] == out[-1]:
        out = out[:-1]
    return out


def extract_entry_map(line_sequence):
    m = {}
    for idx, item in enumerate(line_sequence or []):
        if not isinstance(item, dict):
            continue
        entry = str(item.get("entry", "")).strip()
        if entry:
            m[idx] = entry
    return m


def rebuild_steps(lines, preferred_entries, tracks_by_line):
    steps = []
    fixed = 0
    errors = 0

    for i, cid in enumerate(lines):
        tmap = tracks_by_line.get(cid)
        if not tmap:
            errors += 1
            continue

        options = [tmap[1], tmap[0]]
        chosen = None

        preferred = preferred_entries.get(i, "")
        if preferred:
            chosen = next((o for o in options if equiv(o["entry"], preferred)), None)

        if chosen is None and i > 0:
            prev_exit = steps[-1]["exit"]
            chosen = next((o for o in options if equiv(o["entry"], prev_exit)), None)

        if chosen is None:
            chosen = options[0]
            fixed += 1

        steps.append({
            "line": cid,
            "entry": chosen["entry"],
            "exit": chosen["exit"],
            "track": chosen["track"],
        })

    if steps and not equiv(steps[-1]["exit"], steps[0]["entry"]):
        errors += 1

    return steps, fixed, errors


def process_itineraries(path: Path, tracks_by_line):
    data = load_json(path)
    if data is None:
        return {"ok": True, "vehicles": 0, "fixed": 0, "errors": 0, "message": "no itineraries file"}

    trips = data.get("vehicle_trips")
    if not isinstance(trips, list):
        return {"ok": False, "vehicles": 0, "fixed": 0, "errors": 0, "message": "vehicle_trips missing or invalid"}

    fixed = 0
    errors = 0
    vehicles = 0
    out = []

    for row in trips:
        if not isinstance(row, dict):
            continue
        vid = str(row.get("vehicle_id", "")).strip()
        if not vid:
            continue
        seq = row.get("line_sequence", [])
        lines = normalize_lines(seq)
        pref = extract_entry_map(seq if isinstance(seq, list) else [])
        steps, f, e = rebuild_steps(lines, pref, tracks_by_line)
        fixed += f
        errors += e
        vehicles += 1
        out.append({
            "vehicle_id": vid,
            "line_sequence": steps,
            "hop_count": len(steps),
        })

    data["vehicle_trips"] = out
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return {"ok": True, "vehicles": vehicles, "fixed": fixed, "errors": errors, "message": "itineraries normalized"}


def process_vehicles(path: Path, tracks_by_line):
    data = load_json(path)
    if data is None:
        return {"ok": True, "vehicles": 0, "fixed": 0, "errors": 0, "message": "no vehicles file"}

    itins = data.get("itineraries")
    if not isinstance(itins, list):
        return {"ok": True, "vehicles": 0, "fixed": 0, "errors": 0, "message": "no itineraries block"}

    fixed = 0
    errors = 0
    vehicles = 0
    out = []

    for row in itins:
        if not isinstance(row, dict):
            continue
        vid = str(row.get("vehicle_id", "")).strip()
        if not vid:
            continue
        seq = row.get("line_sequence", [])
        lines = normalize_lines(seq)
        pref = extract_entry_map(seq if isinstance(seq, list) else [])
        steps, f, e = rebuild_steps(lines, pref, tracks_by_line)
        fixed += f
        errors += e
        vehicles += 1
        out.append({
            "vehicle_id": vid,
            "line_sequence": steps,
            "hop_count": len(steps),
        })

    data["itineraries"] = out
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return {"ok": True, "vehicles": vehicles, "fixed": fixed, "errors": errors, "message": "vehicles itineraries normalized"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--network-json", required=True)
    parser.add_argument("--itineraries-json", required=True)
    parser.add_argument("--vehicles-json", required=True)
    args = parser.parse_args()

    network_path = Path(args.network_json)
    network_data = load_json(network_path)
    if not isinstance(network_data, dict):
        print(json.dumps({"ok": False, "vehicles": 0, "fixed": 0, "errors": 0, "message": "invalid network json"}))
        return

    tracks = line_tracks(network_data)

    r1 = process_itineraries(Path(args.itineraries_json), tracks)
    r2 = process_vehicles(Path(args.vehicles_json), tracks)

    out = {
        "ok": bool(r1.get("ok", False) and r2.get("ok", False)),
        "vehicles": int(r1.get("vehicles", 0)) + int(r2.get("vehicles", 0)),
        "fixed": int(r1.get("fixed", 0)) + int(r2.get("fixed", 0)),
        "errors": int(r1.get("errors", 0)) + int(r2.get("errors", 0)),
        "message": f"{r1.get('message', '')}; {r2.get('message', '')}",
    }
    print(json.dumps(out))


if __name__ == "__main__":
    main()
