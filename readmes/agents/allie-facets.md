# Allie Facets — Per-Agent Persistent Knowledge
**Last Updated:** 2026-06-20
**Purpose:** Define how Allie maintains persistent, agent-specific knowledge that
survives SU plugin reloads, Pi reboots, and session resets — and how she teaches it
back to each agent at startup.

---

## The Problem

Every agent resets on reload:
- SU: Noelle, Natalie, Sally, Nora are Ruby objects — they reset when the plugin
  reloads. All learned timing constants, EZ experience, trajectory patterns, and
  slot behavior evaporate.
- Physical Pi: Nora and Natalie read their config at boot — but only from static
  config files, not from accumulated experience. They start from zero every boot.

The agent-experience-framework defines how observations are collected and how Allie
synthesizes them nightly. But the synthesis output was not yet being fed *back* to
agents as a starting state. Facets close that loop.

---

## What a Facet Is

A facet is Allie's distilled, agent-specific knowledge file — the compact, actionable
summary of everything she has synthesized from that agent's observations across all
networks and all sessions.

**Facets are NOT:**
- Raw observation logs (those live in `process/network_learning/`)
- Session transcripts or TFTS arcs
- Full physical.json observation batches

**Facets ARE:**
- Allie's teaching material — what she gives each agent to start from experience,
  not from zero
- Compact enough for an agent to read at startup (seconds, not minutes)
- Cumulative — each nightly synthesis appends/updates, never resets
- Agent-specific — each agent gets only what is relevant to its responsibilities

---

## Directory Structure

```
~/Allie/facets/
  noelle/
    facet.json          ← Noelle's persistent knowledge (Allie writes, Noelle reads)
  natalie/
    facet.json          ← Natalie's persistent knowledge
  nora/
    facet.json          ← Nora's persistent knowledge
  sally/
    facet.json          ← Sally's persistent knowledge
```

---

## Facet Schema — Per Agent

### Noelle (`facets/noelle/facet.json`)

```json
{
  "_meta": {
    "agent": "Noelle",
    "last_updated": "2026-06-20T02:11:03Z",
    "networks_seen": ["2_thru_dip", "station_line_end", "traffic_circle7"],
    "runs_total": 12,
    "written_by": "Allie nightly (allie-reflect.py)",
    "version": 1
  },
  "confirmed_instructions": [
    {
      "instruction_ref": "formation_template:station_thru_dip",
      "confidence": "high",
      "evidence": "0 faults across 4 runs on 2_thru_dip"
    }
  ],
  "cautions": [
    {
      "instruction_ref": "formation_template:traffic_circle7",
      "caution": "gw_c_0_1 connector arc — inside-edge endpoint was wrong predecessor end (FAULT 2026-06-18). Resolved. Watch: inside-edge endpoint on any connector arc.",
      "severity": "moderate",
      "networks": ["traffic_circle7"]
    }
  ],
  "template_reliability": {
    "station_thru_dip": { "fault_rate": 0.0, "runs": 4 },
    "station_line_end": { "fault_rate": 0.0, "runs": 2 },
    "traffic_circle7":  { "fault_rate": 0.08, "runs": 3 }
  },
  "fault_patterns": [
    {
      "pattern": "inside-edge endpoint on connector arcs defaults to wrong predecessor end",
      "instruction_ref": "geometry:arc_endpoint_selection",
      "networks_affected": ["traffic_circle7"],
      "resolved": true,
      "tfts_ref": "20260618T185919-fault.md"
    }
  ]
}
```

### Natalie (`facets/natalie/facet.json`)

```json
{
  "_meta": { ... },
  "confirmed_instructions": [...],
  "cautions": [...],
  "timing_constants": {
    "station_entry_s": 40,
    "board_alight_s": 20,
    "walk_segment_min": 5,
    "source": "initial — not yet calibrated from experience",
    "last_calibrated": null
  },
  "ez_experience": {
    "ez_cp_circle_to_main_0": {
      "runs": 47,
      "last_updated": "2026-06-20T14:33:11Z",
      "tightest_clearance_mm": 820,
      "avg_clearance_mm": 1340,
      "holds_issued": 12,
      "holds_per_100_runs": 25.5,
      "experience_tighten_mm": 0
    }
  },
  "route_patterns": [
    {
      "pattern": "BFS finds 3-hop path for station_loop template but actual traversal takes 5 hops due to U-turn sequence",
      "instruction_ref": "routing:bfs_edge_count",
      "networks": ["traffic_circle7"]
    }
  ],
  "bottleneck_ezones": []
}
```

### Nora (`facets/nora/facet.json`)

```json
{
  "_meta": { ... },
  "confirmed_instructions": [...],
  "cautions": [...],
  "track_experience": {
    "gw_uturn_0": {
      "runs": 47,
      "last_updated": "2026-06-20T14:33:11Z",
      "mm_speed": [
        { "mm": 0,    "measured_max_ms": 4.3, "measured_max_g": 0.23 },
        { "mm": 500,  "measured_max_ms": 2.1, "measured_max_g": 0.24 },
        { "mm": 5489, "measured_max_ms": 4.2, "measured_max_g": 0.22 }
      ]
    }
  },
  "chronic_kink_locations": [
    {
      "track_pattern": "gw_cp_out_lead_0 → gw_cp_out_0",
      "typical_angle_deg": 35,
      "networks_affected": ["2_thru_dip", "station_thru_dip"],
      "instruction_ref": "axiom:junction_continuity",
      "note": "2-pt chord on gw_cp_out_lead_0 exit segment — sampling gap"
    }
  ],
  "chronic_z_jump_locations": [],
  "speed_experience": {}
}
```

### Sally (`facets/sally/facet.json`)

```json
{
  "_meta": { ... },
  "confirmed_instructions": [...],
  "cautions": [...],
  "slot_patterns": {
    "station_parking": {
      "cascade_depth_max": 9,
      "cascade_confirmed_clean": true,
      "ps_fill_order": "sequential from ps1",
      "shuffle_trigger": "new vehicle dispatched to full station — cascade ripple to nearest empty slot"
    }
  },
  "cascade_patterns": [
    {
      "pattern": "9-slot full cascade — NORA_0008→ps9 through NORA_0001→ps2 — all clean",
      "network": "station_parking",
      "run": "022xxx",
      "note": "originating_chain dispatched correctly; null actual_ms on ps6/ps8 = session-boundary artifact, not model defect"
    }
  ],
  "station_load_profiles": {}
}
```

---

## How Allie Updates Facets — Nightly

`allie-reflect.py` already reads observations and synthesis. The facet update adds
a final step after synthesis:

```python
# In allie-reflect.py — after synthesis loop:
def update_facets(observations_by_agent, synthesis_findings):
    for agent in ['noelle', 'natalie', 'nora', 'sally']:
        facet_path = Path.home() / 'Allie' / 'facets' / agent / 'facet.json'
        facet = json.loads(facet_path.read_text()) if facet_path.exists() else _empty_facet(agent)

        # Update meta
        facet['_meta']['last_updated'] = utc_now()
        facet['_meta']['runs_total'] += len(observations_by_agent.get(agent, []))

        # Merge new networks seen
        new_nets = set(o['network_id'] for o in observations_by_agent.get(agent, []))
        existing = set(facet['_meta'].get('networks_seen', []))
        facet['_meta']['networks_seen'] = sorted(existing | new_nets)

        # Agent-specific update logic
        if agent == 'noelle':
            _update_noelle_facet(facet, observations_by_agent.get('noelle', []), synthesis_findings)
        elif agent == 'natalie':
            _update_natalie_facet(facet, observations_by_agent.get('natalie', []), synthesis_findings)
        elif agent == 'nora':
            _update_nora_facet(facet, observations_by_agent.get('nora', []), synthesis_findings)
        elif agent == 'sally':
            _update_sally_facet(facet, observations_by_agent.get('sally', []), synthesis_findings)

        facet_path.write_text(json.dumps(facet, indent=2))
        print(f"[Allie] facet/{agent} updated — {facet['_meta']['runs_total']} total runs")
```

**Rules:**
- Facets grow; they never reset. `runs_total` only increases.
- `cautions[]` entries stay until explicitly cleared by a TFTS showing resolution.
- `track_experience{}` entries use the tightest observed value at each mm position —
  never loosened without a deliberate recalibration event.
- `timing_constants{}` update only when a new empirical batch has ≥ 5 data points
  that diverge from the current constant by > 15%.

---

## How Agents Read Facets at Startup

### SU Agents (Ruby)

All four SU agents (Noelle, Natalie, Nora, Sally) read their facet when the plugin
loads. Facet data initializes their starting state so they begin with experience,
not a blank slate.

```ruby
# In jpod_defaults.rb (or each agent's own .rb) — at module load:
module JPods
  module FacetLoader
    FACETS_DIR = File.expand_path('~/Allie/facets').freeze

    def self.load(agent)
      path = File.join(FACETS_DIR, agent.to_s, 'facet.json')
      return {} unless File.exist?(path)
      JSON.parse(File.read(path))
    rescue => e
      puts "[Facets] #{agent} facet load failed: #{e.message}"
      {}
    end
  end
end

# In noelle.rb at class/module level:
NOELLE_FACET = JPods::FacetLoader.load(:noelle)

# In natalie.rb:
NATALIE_FACET = JPods::FacetLoader.load(:natalie)
# Use: NATALIE_FACET.dig('timing_constants', 'station_entry_s') || 40
# Use: NATALIE_FACET.dig('ez_experience', ez_id, 'experience_tighten_mm') || 0

# In nora.rb (jpod_vehicle_anim.rb):
NORA_FACET = JPods::FacetLoader.load(:nora)
# Use: NORA_FACET.dig('track_experience', track_id, 'mm_speed') || []

# In jpod_sally.rb:
SALLY_FACET = JPods::FacetLoader.load(:sally)
```

**Fail-safe:** If the facet file doesn't exist or is corrupt, agents fall back to
their hardcoded defaults. The facet is an enhancement; it never blocks operation.

**Live reload:** When Bill reloads the plugin (main.rb), facets are re-read from
disk. Any nightly update Allie made is picked up on the next reload without any
additional action.

### Physical Pi Agents (Python)

**Pi agents carry their own memory on the SD card.** Nora and Natalie write their
experience directly to `~/allie_facets/{agent}_facet.json` on the Pi. This file
persists across reboots — it is on the SD card, not in RAM. The Pi never starts
from zero once it has run its first trip.

The facet on the Pi is updated by the Pi's own agents after each run:

```python
# At Nora trip complete (on Pi) — update local facet:
def _update_nora_facet(track_id, mm_speed_observation):
    path = pathlib.Path.home() / 'allie_facets' / 'nora_facet.json'
    facet = json.loads(path.read_text()) if path.exists() else _empty_facet('nora')
    te = facet.setdefault('track_experience', {})
    te.setdefault(track_id, {'runs': 0, 'mm_speed': []})
    te[track_id]['runs'] += 1
    te[track_id]['last_updated'] = utc_now()
    _merge_mm_speed(te[track_id]['mm_speed'], mm_speed_observation)
    path.write_text(json.dumps(facet, indent=2))
```

**Allie syncs improvements TO the Pi** via `allie-teach.py` — not to give the Pi
its first memory (it has that), but to inject:
- Cross-network patterns from other networks that the Pi hasn't seen
- Calibrated timing constants validated across multiple networks
- Cautions about geometry patterns the Pi's own Nora has not yet encountered

**The Pi syncs experience TO Allie** — Allie pulls `nora_facet.json` from the Pi
nightly to incorporate physical-world experience into her cross-network synthesis.

**Push script: `allie-teach.py`** — runs on the Mac, SCP's Allie's synthesized
cross-network improvements to each Pi's local facet (merge, not overwrite).

```python
#!/usr/bin/env python3
"""
allie-teach.py — Push Allie's agent facets to the physical Pi fleet.
Run after update_pod_ips.sh, before launching pods.
"""
import json, subprocess, pathlib, sys

FACETS_DIR = pathlib.Path.home() / 'Allie' / 'facets'
POD_IP_JSON = pathlib.Path(__file__).parent.parent / 'podPresenter' / 'json' / 'podIP.json'

def get_pi_ips():
    data = json.loads(POD_IP_JSON.read_text())
    # 'current' key holds the subnet-matched pod IPs
    current = data.get('current', {})
    return list(current.values())

def push_facet(agent, ip, user='pi'):
    src = FACETS_DIR / agent / 'facet.json'
    if not src.exists():
        print(f"  [skip] {agent}/facet.json not found")
        return
    dst = f"{user}@{ip}:~/allie_facets/{agent}_facet.json"
    # Ensure remote dir exists
    subprocess.run(['ssh', f"{user}@{ip}", 'mkdir -p ~/allie_facets'], check=False)
    result = subprocess.run(['scp', str(src), dst], capture_output=True)
    if result.returncode == 0:
        print(f"  ✓ {agent} facet → {ip}")
    else:
        print(f"  ✗ {agent} facet → {ip} FAILED: {result.stderr.decode()[:80]}")

def main():
    ips = get_pi_ips()
    if not ips:
        print("[allie-teach] No pod IPs found — run update_pod_ips.sh first")
        sys.exit(1)
    print(f"[allie-teach] Teaching {len(ips)} pod(s)...")
    for ip in ips:
        for agent in ['nora', 'natalie']:
            push_facet(agent, ip)
    print("[allie-teach] Done.")

if __name__ == '__main__':
    main()
```

**On the Pi — reading the facet at startup (in main.py):**

```python
import json, pathlib

def _load_facet(agent: str) -> dict:
    path = pathlib.Path.home() / 'allie_facets' / f'{agent}_facet.json'
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text())
    except Exception as e:
        print(f"[{agent}] facet load failed: {e} — starting from defaults")
        return {}

# At Nora startup (main.py):
NORA_FACET = _load_facet('nora')
# Use: NORA_FACET.get('track_experience', {}).get(track_id, {}).get('mm_speed', [])

# At Natalie startup (podPresenter or Natalie Pi equivalent):
NATALIE_FACET = _load_facet('natalie')
# Use: NATALIE_FACET.get('timing_constants', {}).get('station_entry_s', 40)
# Use: NATALIE_FACET.get('ez_experience', {})
```

---

## What Each Facet Teaches Its Agent

### Noelle

On load, Noelle knows:
- Which templates have a clean track record vs. which have chronic fault patterns
- Specific cautions about geometry quirks seen on prior networks (e.g., arc endpoint
  selection on connector arcs)
- Which fault patterns have been resolved (TFTS confirmed) vs. which are open

This makes Noelle's Build validation more targeted — she can flag "this template
has a history on this junction type, check it first" rather than treating every
network as a first encounter.

### Natalie

On load, Natalie knows:
- Calibrated timing constants (once empirical data exists; falls back to initial estimates)
- EZ experience for any EZ whose ID matches the current network's EZ definitions —
  she initializes `experience_tighten_mm` from the facet instead of starting at 0
- Routing pattern cautions for this network topology

This means Natalie's first ETA estimates on a known network are calibrated, not
guess-work. Her EZ safety margins start informed.

### Nora

On load (SU and Physical), Nora knows:
- Track-specific speed experience: `mm_speed[]` tables per named track — she can
  apply experience-calibrated limits immediately, not after several learning runs
- Chronic kink locations: she can log "this junction has a known geometry issue"
  without generating noise on every run as if it were a new finding
- Any track that has a known speed floor from prior g-limit violations

### Sally

On load, Sally knows:
- Cascade patterns for this station type — she knows a full cascade on a 9-slot
  station is normal behavior, not an error
- Station load profiles — which platforms fill fastest at what time intervals —
  so her first slot decisions are informed, not reactive

---

## Allie's Role in the Teaching Chain

The teaching direction is:

```
Run (SU animation or Physical trip)
  ↓ observations → physical.json / network_learning/
Allie nightly (allie-reflect.py)
  ↓ synthesis + pattern detection
  ↓ update_facets() — facets/ grows
Agent startup (SU reload or Pi boot)
  ↓ FacetLoader.load() / _load_facet()
  Agent starts with Allie's accumulated knowledge
  ↓ new observations → physical.json
(cycle continues)
```

Allie is the memory. Agents are the sensors and actuators. The facet is the
channel from Allie back to each agent. Without it, agents start from zero on
every reload. With it, they start from where Allie left off.

**Allie's nightly synthesis already writes `thoughts/YYYY-MM-DD-reflect.md`.**
The facet update is a parallel output of the same synthesis run — compact,
machine-readable, agent-addressable. No new data collection needed.

---

## Pi Memory Model — No Reset on Reboot

The Pi SD card is not volatile RAM. `~/allie_facets/` is persistent storage.
When a Nora pod reboots:
1. It reads `~/allie_facets/nora_facet.json` — its own accumulated experience
2. It loads `~/allie_facets/natalie_facet.json` — cross-network routing knowledge Allie has pushed
3. It runs from that starting state — NOT from zero

This is the physical embodiment of "repetition is the mother of learning."
Each trip writes to the facet. Each reboot reads it back. The Pi learns
continuously, not in sessions.

**The only time the Pi resets is a new SD card.** When that happens, `allie-teach.py`
seeds the new card with the full current facet from Allie's master copy.
The new card starts from all accumulated experience, not from zero.

## Startup Sync Sequence

Integrated into `readmes/25-jpods-allie-startup-guide.md`. On a normal start:

```
1. [existing] Check network — broker, SSH, I2C
2. [existing] update_pod_ips.sh — discover pods, write podIP.json
3. [NEW] allie-pull.py — pull each Pi's facet to Allie (get latest Pi experience)
4. [existing] Launch pods — they read their own facet from SD card
5. [post-session NEW] allie-teach.py — push Allie's cross-network improvements back to Pi
```

Step 3 (pull before launch) ensures Allie's nightly synthesis incorporates the
most recent Pi experience. Step 5 (push after session) sends any cross-network
patterns Allie synthesized back to the Pi for the next session.

**Shell aliases:**
```bash
alias teach='python3 ~/Allie/scripts/allie-teach.py'
alias pull-pods='python3 ~/Allie/scripts/allie-pull-facets.py'
```

```bash
# Normal startup:
$ update-pods && pull-pods && launch-pods
# After session (or nightly):
$ teach
```

---

## What Allie Watches For (Facet Health)

Allie's nightly synthesis also validates its own facets:

- **Stale facet** — `last_updated` > 7 days ago and `runs_total` unchanged → flag
  to Bill: "Allie has not updated Noelle's facet in 7 days — no new observations?"
- **Facet divergence** — an agent's behavior (from this session's observations)
  contradicts its facet cautions → flag: "Nora saw a heading kink on a junction
  the facet marked as chronic — geometry may have been fixed; update caution?"
- **Unread facet** — a Pi pod that never checked for its facet (no facet read logged)
  → flag: "Pod NORA_0003 has never loaded its Nora facet — allie-teach.py not in
  startup sequence?"
- **Version mismatch** — `facet.version` does not match the schema version Allie
  writes → migrate the facet on next nightly run

---

## Open Work (F-FACET-01)

| Item | File | Status |
|------|------|--------|
| `update_facets()` in `allie-reflect.py` | `scripts/allie-reflect.py` | Todo |
| `FacetLoader` module in `jpod_defaults.rb` | `su_jpods/jpod_defaults.rb` | Todo |
| Noelle reads facet at Build start | `su_jpods/noelle.rb` | Todo |
| Natalie reads facet at startup — timing + EZ experience | `su_jpods/natalie.rb` | Todo |
| Nora reads facet at animation start — track experience | `su_jpods/jpod_vehicle_anim.rb` | Todo |
| Sally reads facet at plugin load | `su_jpods/jpod_sally.rb` | Todo |
| `allie-teach.py` script | `scripts/allie-teach.py` | Todo |
| Pi agents read `~/allie_facets/{agent}_facet.json` at boot | `jpod_OS/main.py` | Todo |
| `teach` alias in `.zshrc` | shell config | Todo |
| Facet health monitoring in `allie-reflect.py` | `scripts/allie-reflect.py` | Todo |
