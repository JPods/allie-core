#!/usr/bin/env python3
"""
Normalize podPresenter map.json into a JPods production line-map JSON.

Input (podPresenter):
  {
    "mapId": ...,
    "ezones": [ ... ],
    "lines": [
      {
        "id": 1,
        "startPoint": {"x": ..., "y": ...},
        "endPoint": {"x": ..., "y": ...},
        "segments": [
          {"xs":..., "ys":..., "xe":..., "ye":..., "...": ...}
        ]
      }
    ]
  }

Output (JPods production import):
  {
    "mapId": ...,
    "lines": [
      {
        "id": 1,
        "startPoint": {"x":..., "y":..., "z": ...},
        "endPoint": {"x":..., "y":..., "z": ...},
        "segments": [
          {"id":..., "xs":..., "ys":..., "xe":..., "ye":..., "zs":..., "ze":...}
        ]
      }
    ],
    "ezones": [ ... ]
  }

Notes:
- Coordinates are kept in millimeters to match existing production importer logic.
- If z is missing, defaults are added from --default-z-mm.
- Unknown fields are preserved by default; use --minimal to output only import keys.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List


def with_z(point: Dict[str, Any], default_z_mm: int) -> Dict[str, Any]:
    out = dict(point)
    out["z"] = int(out.get("z", default_z_mm))
    return out


def normalize_line(line: Dict[str, Any], default_z_mm: int, minimal: bool) -> Dict[str, Any]:
    src_start = line.get("startPoint", {})
    src_end = line.get("endPoint", {})
    start = with_z(src_start, default_z_mm)
    end = with_z(src_end, default_z_mm)

    segs_out: List[Dict[str, Any]] = []
    for idx, seg in enumerate(line.get("segments", []), start=1):
        if minimal:
            out_seg = {
                "id": seg.get("id", idx),
                "xs": seg.get("xs"),
                "ys": seg.get("ys"),
                "xe": seg.get("xe"),
                "ye": seg.get("ye"),
            }
        else:
            out_seg = dict(seg)
            out_seg["id"] = out_seg.get("id", idx)

        # Fill optional production Z stamps.
        out_seg["zs"] = int(out_seg.get("zs", start["z"]))
        out_seg["ze"] = int(out_seg.get("ze", end["z"]))
        segs_out.append(out_seg)

    if minimal:
        return {
            "id": line.get("id"),
            "startPoint": {
                "id": start.get("id"),
                "x": start.get("x"),
                "y": start.get("y"),
                "z": start.get("z"),
            },
            "endPoint": {
                "id": end.get("id"),
                "x": end.get("x"),
                "y": end.get("y"),
                "z": end.get("z"),
            },
            "segments": segs_out,
        }

    out_line = dict(line)
    out_line["startPoint"] = start
    out_line["endPoint"] = end
    out_line["segments"] = segs_out
    return out_line


def normalize_map(data: Dict[str, Any], default_z_mm: int, minimal: bool) -> Dict[str, Any]:
    out: Dict[str, Any]
    if minimal:
        out = {
            "mapId": data.get("mapId"),
            "lines": [],
            "ezones": data.get("ezones", []),
        }
    else:
        out = dict(data)
        out["ezones"] = data.get("ezones", [])

    out_lines = [normalize_line(line, default_z_mm, minimal) for line in data.get("lines", [])]
    out["lines"] = out_lines

    # Keep optional explicit dead-end declarations if present in source.
    if "dead_end_nodes" in data:
        out["dead_end_nodes"] = data["dead_end_nodes"]
    if "u_turns" in data:
        out["u_turns"] = data["u_turns"]

    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Normalize podPresenter map.json to JPods line-map JSON")
    parser.add_argument("input", type=Path, help="Source map.json")
    parser.add_argument("output", type=Path, help="Output JSON path")
    parser.add_argument("--default-z-mm", type=int, default=5500, help="Default z (mm) when absent")
    parser.add_argument(
        "--minimal",
        action="store_true",
        help="Write only fields required by JPods production importer + z stamps",
    )
    args = parser.parse_args()

    src = json.loads(args.input.read_text(encoding="utf-8"))
    if not isinstance(src, dict):
        raise SystemExit("Input root must be a JSON object.")

    norm = normalize_map(src, args.default_z_mm, args.minimal)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(norm, indent=2), encoding="utf-8")

    print(f"Wrote {args.output}")
    print(f"lines={len(norm.get('lines', []))}, ezones={len(norm.get('ezones', []))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
