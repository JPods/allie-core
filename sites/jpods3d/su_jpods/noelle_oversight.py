#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def norm_bool(v, default=False):
    if isinstance(v, bool):
        return v
    if v is None:
        return default
    if isinstance(v, str):
        return v.strip().lower() in {"1", "true", "yes", "y", "on"}
    return bool(v)


def normalize_network(path: Path):
    fixed = 0
    removed = 0

    if not path.exists():
        return {"ok": False, "fixed": 0, "removed": 0, "message": f"network json not found: {path}"}

    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        return {"ok": False, "fixed": 0, "removed": 0, "message": "network json root is not an object"}

    conns = data.get("connections")
    if not isinstance(conns, list):
        conns = []
        data["connections"] = conns
        fixed += 1

    seen_ids = set()
    clean = []
    next_id = 1

    for row in conns:
        if not isinstance(row, dict):
            removed += 1
            continue

        conn = dict(row)
        raw_id = str(conn.get("id", "")).strip()
        if not raw_id:
            raw_id = f"seg_{next_id}"
            next_id += 1
            fixed += 1
        if raw_id in seen_ids:
            k = 2
            new_id = f"{raw_id}_{k}"
            while new_id in seen_ids:
                k += 1
                new_id = f"{raw_id}_{k}"
            raw_id = new_id
            fixed += 1
        seen_ids.add(raw_id)
        conn["id"] = raw_id

        frm = conn.get("from") if isinstance(conn.get("from"), dict) else {}
        to = conn.get("to") if isinstance(conn.get("to"), dict) else {}

        from_sid = str(frm.get("structure_id", "")).strip().upper()
        to_sid = str(to.get("structure_id", "")).strip().upper()

        try:
            from_stub = max(0, int(frm.get("stub", 0)))
        except Exception:
            from_stub = 0
            fixed += 1

        try:
            to_stub = max(0, int(to.get("stub", 0)))
        except Exception:
            to_stub = 0
            fixed += 1

        if not from_sid or not to_sid:
            removed += 1
            continue

        conn["from"] = {"structure_id": from_sid, "stub": from_stub}
        conn["to"] = {"structure_id": to_sid, "stub": to_stub}

        via = conn.get("via_markers", [])
        out_via = []
        if isinstance(via, list):
            for m in via:
                try:
                    out_via.append(int(m))
                except Exception:
                    fixed += 1
        else:
            fixed += 1
        conn["via_markers"] = out_via

        clean.append(conn)

    if len(clean) != len(conns):
        fixed += 1
    data["connections"] = clean

    ut = data.get("u_turns", [])
    if not isinstance(ut, list):
        data["u_turns"] = []
        fixed += 1

    rp = data.get("routing_policy", {})
    if not isinstance(rp, dict):
        rp = {}
        fixed += 1
    norm_rp = {
        "strict_vehicle_trips": norm_bool(rp.get("strict_vehicle_trips"), True),
        "allow_trip_fallback": norm_bool(rp.get("allow_trip_fallback"), False),
        "report_route_events": norm_bool(rp.get("report_route_events"), True),
        "record_console_to_project": norm_bool(rp.get("record_console_to_project"), False),
    }
    if norm_rp != rp:
        fixed += 1
    data["routing_policy"] = norm_rp

    trip_table = data.get("vehicle_trips", {})
    if not isinstance(trip_table, dict):
        data["vehicle_trips"] = {}
        fixed += 1

    path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return {"ok": True, "fixed": fixed, "removed": removed, "message": "network normalized"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--network-json", required=True)
    args = parser.parse_args()

    result = normalize_network(Path(args.network_json))
    print(json.dumps(result))


if __name__ == "__main__":
    main()
