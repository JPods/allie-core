#!/usr/bin/env python3
"""
harvest.py
Allie's synthesis script. Reads the activity log and produces a structured
cross-project summary that Allie can read at session start.

Usage:
  python3 harvest.py              — summarize today's activity log
  python3 harvest.py YYYY-MM-DD  — summarize a specific day's log

Output: /Users/williamjames/Allie/today/YYYY-MM-DD-harvest.md
Allie reads this at session start (step 7 of startup-protocol.md).
"""

import sys
import re
import pathlib
import datetime
from collections import defaultdict

ALLIE = pathlib.Path("/Users/williamjames/Allie")

# Projects Allie cares about — must match watcher.sh PROJECTS keys
PROJECT_LABELS = {
    "jpods-plugin":  "JPods SketchUp Plugin",
    "jpods-docs":    "JPods Documents",
    "webclerk3":     "WebClerk3",
    "react2025":     "React2025 Frontend",
    "allie":         "Allie Infrastructure",
    "politics":      "Divided Sovereignty / Writing",
}

OSL_MUST_FIX = [
    ("OSL-02", "JPods privacy doctrine has no code enforcement", "jpods-plugin"),
    ("OSL-03", "Athena privacy calibration corpus not representative", "allie"),
    ("OSL-04", "A-06 trip log exposure — no mitigation", "jpods-plugin"),
    ("OSL-05", "No booking token design", "jpods-plugin"),
    ("OSL-06", "Vulnerable user threat modeling not done", "allie"),
]


def parse_log(log_path: pathlib.Path) -> dict:
    """Parse the activity log into structured data."""
    data = {
        "project_activity": defaultdict(list),  # project → [events]
        "apps": [],
        "calendar": [],
        "warnings": [],
        "start_time": None,
        "stop_time": None,
        "total_events": 0,
    }

    if not log_path.exists():
        return data

    pattern = re.compile(r"\[(\d{2}:\d{2}:\d{2})\] \[([^\]]+)\] (.+)")

    for line in log_path.read_text().splitlines():
        m = pattern.match(line)
        if not m:
            continue
        ts, level, msg = m.groups()
        data["total_events"] += 1

        if level == "START":
            data["start_time"] = data["start_time"] or ts
        elif level == "STOP":
            data["stop_time"] = ts
        elif level.startswith("CODE[") or level.startswith("MODEL[") or \
             level.startswith("DATA[") or level.startswith("WRITE[") or \
             level.startswith("FILE["):
            # Extract project name from level like CODE[jpods-plugin]
            proj_match = re.search(r"\[([^\]]+)\]", level)
            if proj_match:
                proj = proj_match.group(1)
                data["project_activity"][proj].append((ts, level.split("[")[0], msg))
        elif level == "ALLIE":
            data["project_activity"]["allie"].append((ts, "WRITE", msg))
        elif level == "APP":
            data["apps"].append((ts, msg))
        elif level == "CAL":
            data["calendar"].append((ts, msg))
        elif level == "WARN":
            data["warnings"].append((ts, msg))

    return data


def osl_check(active_projects: set) -> list:
    """Flag OSL items relevant to projects that were active today."""
    flags = []
    for osl_id, description, project in OSL_MUST_FIX:
        if project in active_projects or not active_projects:
            flags.append(f"- **{osl_id}** (Must Fix — {project}): {description}")
    return flags


def read_session(date_str: str) -> str:
    """Read today's session log if it exists."""
    path = ALLIE / "sessions" / f"{date_str}.md"
    if not path.exists():
        return ""
    text = path.read_text().strip()
    # Extract Accomplished and Next sections — skip frontmatter and boilerplate
    sections = {}
    current = None
    for line in text.splitlines():
        if line.startswith("## "):
            current = line[3:].strip()
            sections[current] = []
        elif current:
            sections[current].append(line)
    result = []
    for section in ("Accomplished", "Next", "Open Questions"):
        if section in sections:
            body = "\n".join(sections[section]).strip()
            if body and body not in ("_Nothing in progress._", "_None so far._", "_Not yet written._", "- "):
                result.append(f"### {section}\n{body}")
    return "\n\n".join(result)


def write_harvest(date_str: str, log_path: pathlib.Path, out_path: pathlib.Path):
    data = parse_log(log_path)

    session_notes = read_session(date_str)

    lines = [
        f"# Allie Harvest — {date_str}",
        f"*Generated from activity log. Read at session start.*",
        "",
    ]

    # Session notes first — debugging context is higher signal than file changes
    if session_notes:
        lines += ["## Session Notes", "", session_notes, ""]

    # Session window
    if data["start_time"] or data["stop_time"]:
        window = f"{data['start_time'] or '?'} → {data['stop_time'] or 'still running'}"
        lines += [f"**Watcher active:** {window}  ", f"**Events logged:** {data['total_events']}", ""]

    # App timeline
    if data["apps"]:
        lines += ["## App Activity", ""]
        for ts, msg in data["apps"]:
            lines.append(f"- `{ts}` {msg}")
        lines.append("")

    # Calendar
    cal_events = [m for _, m in data["calendar"] if not m.startswith("Upcoming:") and m.strip()]
    if cal_events:
        lines += ["## Calendar Events", ""]
        for item in cal_events:
            lines.append(f"- {item.strip()}")
        lines.append("")

    # Project activity — one section per active project
    active_projects = set(data["project_activity"].keys())
    if data["project_activity"]:
        lines += ["## Project Activity", ""]
        for proj, events in sorted(data["project_activity"].items()):
            label = PROJECT_LABELS.get(proj, proj)
            lines.append(f"### {label}")
            # Group by type, show last N of each
            by_type = defaultdict(list)
            for ts, etype, msg in events:
                by_type[etype].append(f"`{ts}` {msg}")
            for etype, items in sorted(by_type.items()):
                lines.append(f"**{etype}** ({len(items)} changes)")
                # Show last 5 of each type
                for item in items[-5:]:
                    lines.append(f"  - {item}")
            lines.append(f"*Total: {len(events)} events in {label}*")
            lines.append("")

    # OSL check — flag must-fix items for active projects
    osl_flags = osl_check(active_projects)
    if osl_flags:
        lines += ["## OSL Reminder — Must Fix Items for Today's Active Projects", ""]
        lines += osl_flags
        lines += ["", "*See readmes/system/ouch-list.md § Must Fix Now for full details.*", ""]

    # Warnings
    if data["warnings"]:
        lines += ["## Warnings", ""]
        for ts, msg in data["warnings"]:
            lines.append(f"- `{ts}` {msg}")
        lines.append("")

    # Cross-domain notice
    if len(active_projects) > 1:
        proj_names = [PROJECT_LABELS.get(p, p) for p in active_projects]
        lines += [
            "## Cross-Domain Notice",
            "",
            f"Activity in **{len(active_projects)} projects** today: {', '.join(sorted(proj_names))}.",
            "Allie: check for decisions in one project that have consequences in another.",
            "Athena: check for contradictions between what was built and what was promised.",
            "",
        ]

    # No activity
    if not data["project_activity"] and not data["apps"]:
        lines += ["*No activity recorded. Watcher may not have been running, or no files changed.*", ""]

    out_path.write_text("\n".join(lines))
    print(f"Harvest written: {out_path}")
    return out_path


def main():
    if len(sys.argv) > 1:
        date_str = sys.argv[1]
    else:
        date_str = datetime.date.today().isoformat()

    log_path = ALLIE / "today" / f"{date_str}-activity.log"
    out_path = ALLIE / "today" / f"{date_str}-harvest.md"

    if not (ALLIE / "today").exists():
        print(f"ERROR: /Users/williamjames/Allie/today/ not found. Is the Allie drive mounted?")
        sys.exit(1)

    write_harvest(date_str, log_path, out_path)


if __name__ == "__main__":
    main()
