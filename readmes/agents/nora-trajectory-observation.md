# Nora Trajectory Observation System — Design Plan

**Status:** Design — not yet implemented  
**Applies to:** All Nora domains (SketchUp, Physical/RPi, Route-Time simulation)  
**Authored:** 2026-06-17  
**Context:** After gw_ animation fix (TFTS 20260617T150949), animation quality improved but defects remain. The idea: Nora is the one running the track. She is the best sensor for geometry defects. She reports what she experiences; Noelle and Natalie learn from it.

---

## What This Is

Nora observes her own trajectory at every track junction. If the transition from one track to the next is geometrically smooth, she says nothing. If it is not — heading discontinuity, Z jump, chord cut, position gap — she files a FAULT against the specific track pair and flushes it to Noelle.

This is not a build-time check. Noelle already validates structure at Build. This is runtime observation: the vehicle experienced something the static geometry scan could not predict. The vehicle is the highest-fidelity sensor.

**Why this matters:** Geometry defects discovered at Build are cheap. Geometry defects discovered at first animation run are acceptable. Geometry defects discovered at the 47th animation run because nobody told Noelle are waste. Nora closes that loop.

---

## What Nora Detects

At every track-to-track junction (current track's last point → next track's first point), compute four metrics:

### 1. Heading Discontinuity

```
exit_vec  = pts[-1] - pts[-2]          # last chord of departing track
entry_vec = next_pts[1] - next_pts[0]  # first chord of arriving track
cos_theta = (exit_vec · entry_vec) / (|exit_vec| × |entry_vec|)
```

- `cos_theta < COS_HEADING_WARN`  → `severity: :minor`   (> ~15° deviation)
- `cos_theta < COS_HEADING_FAULT` → `severity: :moderate` (> ~35° deviation)
- `cos_theta < COS_HEADING_SEVERE`→ `severity: :severe`   (> ~60° deviation — hard kink)

Constants (tunable):
```ruby
COS_HEADING_WARN   = Math.cos(15 * Math::PI / 180)   # 0.966
COS_HEADING_FAULT  = Math.cos(35 * Math::PI / 180)   # 0.819
COS_HEADING_SEVERE = Math.cos(60 * Math::PI / 180)   # 0.500
```

### 2. Z Jump at Junction

```
delta_z = (next_pts[0].z - pts[-1].z).abs   # mm
```

- `delta_z > Z_JUMP_WARN_MM`  → `:minor`
- `delta_z > Z_JUMP_FAULT_MM` → `:moderate`
- `delta_z > Z_JUMP_SEVERE_MM`→ `:severe`

Constants:
```ruby
Z_JUMP_WARN_MM   = 50    # 50mm — noticeable but possibly intentional grade
Z_JUMP_FAULT_MM  = 200   # 200mm — wrong Z level
Z_JUMP_SEVERE_MM = 500   # 500mm — clearly two different coordinate systems
```

### 3. Chord Cut (Two-Point Arc)

A track with only 2 points when it was generated from an arc is a chord, not the arc. Vehicles follow the chord; the physical guideway is the arc. The chord creates: heading error at both ends, wrong midpoint Z on banked curves.

```
if pts.size == 2
  chord_len = distance(pts[0], pts[-1])
  # Any arc subtended by this chord has sagitta = chord_len * (1 - cos(theta/2))
  # If arc_radius is known from network.json bezier, compute exact sagitta.
  # If not known: chord_len > CHORD_SUSPECT_MM on a gw_ track is diagnostic.
  if chord_len > CHORD_SUSPECT_MM
    severity = chord_len > CHORD_SEVERE_MM ? :severe : :minor
    observation(:chord_cut, track_id, severity, "2-pt track chord #{chord_len.round}mm")
  end
end
```

Constants:
```ruby
CHORD_SUSPECT_MM = 500   # 500mm chord with only 2 pts — suspect
CHORD_SEVERE_MM  = 2000  # 2m chord — definitely wrong
```

### 4. Position Gap at Junction

```
gap = distance(pts[-1], next_pts[0])   # mm — these should be coincident
```

- `gap > GAP_WARN_MM`  → `:minor`
- `gap > GAP_FAULT_MM` → `:moderate` 
- `gap > CHAIN_BREAK_MM`→ `:severe` (track chain is broken)

Constants:
```ruby
GAP_WARN_MM    = 5      # 5mm — small floating-point gap
GAP_FAULT_MM   = 50     # 50mm — connection not joined
CHAIN_BREAK_MM = 200    # 200mm — serious break; animation will jump
```

---

## Observation Record Format

Every detected defect becomes one observation record:

```ruby
{
  'track_id'    => track_id,         # e.g. "s001.gw_main_in" or "seg_001_002"
  'next_id'     => next_track_id,    # the track being entered
  'type'        => 'heading_kink',   # heading_kink | z_jump | chord_cut | position_gap
  'severity'    => 'moderate',       # minor | moderate | severe
  'value'       => 38.2,             # angle in degrees, or mm
  'location_t'  => 1.0,             # parametric — junction is always at 1.0 of current track
  'description' => "35.2° kink at gw_main_in → gw_main_thru",
  'logged_at'   => '2026-06-17T15:23:01Z',
  'logged_by'   => 'Nora.SU',       # Nora.SU | Nora.PH
  'pod_id'      => nil,             # nil in SU; pod name in Physical
}
```

---

## Flush Protocol

**Accumulate** — Nora collects observations in `@trajectory_observations = []` during the run.

**Flush triggers:**
- SU: animation stop (`stop_animation` callback in `jpod_vehicle_anim.rb`)
- Physical: trip complete (`trip_complete` event in `motor.py` / `ezone.py`)

**On flush:**

1. Write to `physical.json` (the established per-run observation file, same format as existing anomalies):

```ruby
# SU flush — append to {model_stem}.physical.json
phys_path = File.join(model_dir, "#{model_stem}.physical.json")
phys = File.exist?(phys_path) ? JSON.parse(File.read(phys_path)) : { 'observations' => [] }
phys['observations'].concat(@trajectory_observations)
# cap at 500 entries
phys['observations'] = phys['observations'].last(500)
File.write(phys_path, JSON.generate(phys))
```

2. Fire `_allie_capture`:

```ruby
self._allie_capture('nora_trajectory_flush',
  "#{@trajectory_observations.size} trajectory defect(s) flushed",
  { 'model' => model_stem, 'count' => @trajectory_observations.size,
    'severe' => @trajectory_observations.count { |o| o['severity'] == 'severe' } })
```

3. If any **severe** observations: write a FAULT file immediately:

```ruby
if @trajectory_observations.any? { |o| o['severity'] == 'severe' }
  write_trajectory_fault(@trajectory_observations.select { |o| o['severity'] == 'severe' })
end
```

FAULT file format:
```markdown
# FAULT — 2026-06-17T15:23:01Z

system:      SU
detected_by: Nora
fault:       Trajectory severe defect — 2 severe geometry defects at track junctions
context:     animation run on 2_thru_dip; 2 severe heading kinks on gw_ tracks
resolved_at: 
```

4. Report count in animation console output:
```
[Nora] Trajectory scan: 3 defect(s) (0 severe, 2 moderate, 1 minor) — written to physical.json
```

---

## SU Implementation — `jpod_vehicle_anim.rb`

### Where to hook in

The animation tick loop advances each vehicle through its track sequence. The junction moment is when a vehicle finishes one track and loads the next. That is precisely where to compute all four metrics.

In `jpod_vehicle_anim.rb`, the vehicle's track advancement logic:

```ruby
# Existing: when t >= 1.0 on current track, advance to next
# ADD: before loading next_track, run trajectory check

def advance_to_next_track(vehicle, next_track_id)
  # ── Trajectory observation at junction ─────────────────────────────────
  if vehicle.current_pts && vehicle.current_pts.size >= 2
    next_pts = @lookup[next_track_id]
    if next_pts && next_pts.size >= 2
      @trajectory_observer.observe_junction(
        vehicle.current_track_id, vehicle.current_pts,
        next_track_id, next_pts
      )
    end
  end
  # existing track advance code continues...
end
```

### `TrajectoryObserver` class (new — in `jpod_vehicle_anim.rb` or extracted to `jpod_trajectory_observer.rb`)

```ruby
module JPods
  class TrajectoryObserver
    COS_HEADING_WARN   = Math.cos(15 * Math::PI / 180)
    COS_HEADING_FAULT  = Math.cos(35 * Math::PI / 180)
    COS_HEADING_SEVERE = Math.cos(60 * Math::PI / 180)
    Z_JUMP_WARN_MM   = 50
    Z_JUMP_FAULT_MM  = 200
    Z_JUMP_SEVERE_MM = 500
    GAP_WARN_MM      = 5
    GAP_FAULT_MM     = 50
    CHAIN_BREAK_MM   = 200
    CHORD_SUSPECT_MM = 500
    CHORD_SEVERE_MM  = 2000

    def initialize(pod_id: nil)
      @pod_id       = pod_id
      @observations = []
    end

    def observe_junction(track_id, pts, next_id, next_pts)
      observe_heading(track_id, pts, next_id, next_pts)
      observe_z_jump(track_id, pts, next_id, next_pts)
      observe_gap(track_id, pts, next_id, next_pts)
      observe_chord(next_id, next_pts)
    end

    def flush(model_stem, model_dir)
      return if @observations.empty?
      write_to_physical_json(model_stem, model_dir)
      fire_allie_capture(model_stem)
      write_fault_if_severe(model_stem)
      count  = @observations.size
      severe = @observations.count { |o| o['severity'] == 'severe' }
      puts "[Nora] Trajectory: #{count} defect(s) (#{severe} severe) → physical.json"
      @observations = []
    end

    def observation_count; @observations.size; end
    def severe_count; @observations.count { |o| o['severity'] == 'severe' }; end

    private

    def observe_heading(tid, pts, nid, npts)
      return unless pts.size >= 2 && npts.size >= 2
      ev = vec3(pts[-1], pts[-2])
      iv = vec3(npts[0], npts[1])
      return if ev.nil? || iv.nil?
      cos_t = dot(ev, iv) / (mag(ev) * mag(iv))
      cos_t = cos_t.clamp(-1.0, 1.0)
      sev = if cos_t < COS_HEADING_SEVERE then :severe
             elsif cos_t < COS_HEADING_FAULT  then :moderate
             elsif cos_t < COS_HEADING_WARN   then :minor
             end
      return unless sev
      deg = (Math.acos(cos_t) * 180 / Math::PI).round(1)
      record(tid, nid, 'heading_kink', sev, deg, "#{deg}° kink at #{tid} → #{nid}")
    end

    def observe_z_jump(tid, pts, nid, npts)
      dz = (npts[0][2] - pts[-1][2]).abs
      sev = if dz > Z_JUMP_SEVERE_MM then :severe
             elsif dz > Z_JUMP_FAULT_MM  then :moderate
             elsif dz > Z_JUMP_WARN_MM   then :minor
             end
      return unless sev
      record(tid, nid, 'z_jump', sev, dz.round, "Z jump #{dz.round}mm at #{tid} → #{nid}")
    end

    def observe_gap(tid, pts, nid, npts)
      gap = dist3(pts[-1], npts[0])
      sev = if gap > CHAIN_BREAK_MM then :severe
             elsif gap > GAP_FAULT_MM  then :moderate
             elsif gap > GAP_WARN_MM   then :minor
             end
      return unless sev
      record(tid, nid, 'position_gap', sev, gap.round, "Gap #{gap.round}mm at #{tid} → #{nid}")
    end

    def observe_chord(nid, npts)
      return unless npts.size == 2
      chord = dist3(npts[0], npts[1])
      return unless chord > CHORD_SUSPECT_MM
      sev = chord > CHORD_SEVERE_MM ? :severe : :minor
      record(nid, nil, 'chord_cut', sev, chord.round, "2-pt chord #{chord.round}mm on #{nid}")
    end

    def record(tid, nid, type, sev, val, desc)
      @observations << {
        'track_id'    => tid.to_s,
        'next_id'     => nid.to_s,
        'type'        => type.to_s,
        'severity'    => sev.to_s,
        'value'       => val,
        'location_t'  => 1.0,
        'description' => desc,
        'logged_at'   => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'logged_by'   => 'Nora.SU',
        'pod_id'      => @pod_id,
      }
    end

    # ── Vector math (works on [x,y,z] arrays or Geom::Point3d) ─────────
    def vec3(a, b)
      [b[0]-a[0], b[1]-a[1], b[2]-a[2]]
    rescue; nil; end

    def dot(a, b);  a[0]*b[0] + a[1]*b[1] + a[2]*b[2]; end
    def mag(v);  Math.sqrt(v[0]**2 + v[1]**2 + v[2]**2); end
    def dist3(a, b); mag(vec3(a, b)); end

    def write_to_physical_json(stem, dir)
      path = File.join(dir, "#{stem}.physical.json")
      data = File.exist?(path) ? JSON.parse(File.read(path, encoding: 'utf-8')) : {}
      data['observations'] ||= []
      data['observations'].concat(@observations)
      data['observations'] = data['observations'].last(500)
      File.write(path, JSON.pretty_generate(data))
    rescue => ex
      puts "[Nora] physical.json write error: #{ex.message}"
    end

    def fire_allie_capture(stem)
      JPods::Noelle._allie_capture(
        'nora_trajectory_flush',
        "#{@observations.size} trajectory defect(s) flushed (#{severe_count} severe)",
        { 'model' => stem, 'count' => @observations.size, 'severe' => severe_count }
      ) rescue nil
    end

    def write_fault_if_severe(stem)
      severes = @observations.select { |o| o['severity'] == 'severe' }
      return if severes.empty?
      ts_str  = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      ts_file = Time.now.utc.strftime('%Y%m%dT%H%M%S')
      inbox   = File.expand_path('~/Allie/process/inbox')
      return unless File.directory?(inbox)
      types   = severes.map { |o| o['type'] }.uniq.join(', ')
      body = "# FAULT — #{ts_str}\n\n" \
             "system:      SU\n" \
             "detected_by: Nora\n" \
             "fault:       Trajectory severe defect — #{severes.size} severe junction(s): #{types}\n" \
             "context:     #{stem} animation; tracks: #{severes.map { |o| o['track_id'] }.uniq.join(', ')}\n" \
             "resolved_at: \n"
      File.write(File.join(inbox, "#{ts_file}-fault.md"), body)
    end
  end
end
```

### Wiring into animation lifecycle

```ruby
# In animation start (start_animation or equivalent):
@trajectory_observer = JPods::TrajectoryObserver.new(pod_id: nil)

# In animation stop callback:
if @trajectory_observer && model
  dir  = File.dirname(model.path)
  stem = File.basename(model.path, '.skp')
  @trajectory_observer.flush(stem, dir)
end
```

---

## Physical Implementation — `main.py` / `motor.py` on RPi

The physical Nora has a richer signal: she knows exact mm traveled per track segment (encoder dead-reckoning). But she only knows her track sequence after Natalie assigns it. The trajectory check runs at the same logical moment: when she transitions from one line to the next.

### Where to hook in

In `main.py` or `ezone.py`, the line transition happens when a TOF clearance or ezone trigger marks the end of one line and the start of the next. At that moment, Nora has:
- `current_line_id` — the line just completed
- `next_line_id` — the line just entered
- Both lines' pts from her local copy of `trip.json`

```python
class TrajectoryObserver:
    COS_HEADING_WARN   = math.cos(math.radians(15))
    COS_HEADING_FAULT  = math.cos(math.radians(35))
    COS_HEADING_SEVERE = math.cos(math.radians(60))
    Z_JUMP_WARN_MM     = 50
    Z_JUMP_FAULT_MM    = 200
    Z_JUMP_SEVERE_MM   = 500
    GAP_WARN_MM        = 5
    GAP_FAULT_MM       = 50
    CHAIN_BREAK_MM     = 200

    def __init__(self, pod_id: str):
        self.pod_id = pod_id
        self.observations = []

    def observe_junction(self, line_id, pts, next_id, next_pts):
        self._check_heading(line_id, pts, next_id, next_pts)
        self._check_z_jump(line_id, pts, next_id, next_pts)
        self._check_gap(line_id, pts, next_id, next_pts)

    def flush(self, trip_id: str):
        if not self.observations:
            return
        self._write_to_physical_json()
        self._fire_allie_capture(trip_id)
        self._write_fault_if_severe()
        n = len(self.observations)
        s = sum(1 for o in self.observations if o['severity'] == 'severe')
        print(f"[Nora] Trajectory: {n} defect(s) ({s} severe) → physical.json")
        self.observations = []

    def _check_heading(self, lid, pts, nid, npts):
        if len(pts) < 2 or len(npts) < 2:
            return
        ev = self._vec(pts[-2], pts[-1])
        iv = self._vec(npts[0], npts[1])
        if not ev or not iv:
            return
        cos_t = max(-1.0, min(1.0, self._dot(ev, iv) / (self._mag(ev) * self._mag(iv))))
        if cos_t < self.COS_HEADING_SEVERE:
            sev = 'severe'
        elif cos_t < self.COS_HEADING_FAULT:
            sev = 'moderate'
        elif cos_t < self.COS_HEADING_WARN:
            sev = 'minor'
        else:
            return
        deg = round(math.degrees(math.acos(cos_t)), 1)
        self._record(lid, nid, 'heading_kink', sev, deg, f"{deg}° kink at {lid} → {nid}")

    def _check_z_jump(self, lid, pts, nid, npts):
        dz = abs(npts[0][2] - pts[-1][2])
        if dz > self.Z_JUMP_SEVERE_MM:
            sev = 'severe'
        elif dz > self.Z_JUMP_FAULT_MM:
            sev = 'moderate'
        elif dz > self.Z_JUMP_WARN_MM:
            sev = 'minor'
        else:
            return
        self._record(lid, nid, 'z_jump', sev, round(dz), f"Z jump {round(dz)}mm at {lid} → {nid}")

    def _check_gap(self, lid, pts, nid, npts):
        gap = self._dist(pts[-1], npts[0])
        if gap > self.CHAIN_BREAK_MM:
            sev = 'severe'
        elif gap > self.GAP_FAULT_MM:
            sev = 'moderate'
        elif gap > self.GAP_WARN_MM:
            sev = 'minor'
        else:
            return
        self._record(lid, nid, 'position_gap', sev, round(gap), f"Gap {round(gap)}mm at {lid} → {nid}")

    def _record(self, tid, nid, typ, sev, val, desc):
        import datetime
        self.observations.append({
            'track_id':   str(tid),
            'next_id':    str(nid),
            'type':       typ,
            'severity':   sev,
            'value':      val,
            'location_t': 1.0,
            'description': desc,
            'logged_at':  datetime.datetime.now(datetime.timezone.utc)
                              .strftime('%Y-%m-%dT%H:%M:%SZ'),
            'logged_by':  'Nora.PH',
            'pod_id':     self.pod_id,
        })

    def _write_to_physical_json(self):
        import json, pathlib
        allie = pathlib.Path.home() / 'Allie' / 'process' / 'physical'
        local = pathlib.Path.home() / 'jpod_logs' / 'observations'
        inbox = allie if allie.parent.parent.exists() else local
        inbox.mkdir(parents=True, exist_ok=True)
        path = inbox / 'physical.json'
        data = json.loads(path.read_text()) if path.exists() else {}
        data.setdefault('observations', [])
        data['observations'].extend(self.observations)
        data['observations'] = data['observations'][-500:]
        path.write_text(json.dumps(data, indent=2))

    def _write_fault_if_severe(self):
        import json, pathlib, datetime
        severes = [o for o in self.observations if o['severity'] == 'severe']
        if not severes:
            return
        _write_fault(
            f"Trajectory severe defect — {len(severes)} severe junction(s)",
            context=f"tracks: {', '.join(set(o['track_id'] for o in severes))}",
            detected_by='Nora'
        )

    def _fire_allie_capture(self, trip_id):
        _allie_capture('nora_trajectory_flush',
            f"{len(self.observations)} trajectory defect(s) flushed",
            {'trip_id': trip_id, 'count': len(self.observations),
             'severe': sum(1 for o in self.observations if o['severity'] == 'severe')})

    @staticmethod
    def _vec(a, b): return [b[i]-a[i] for i in range(3)] if len(a) >= 3 and len(b) >= 3 else None
    @staticmethod
    def _dot(a, b): return sum(a[i]*b[i] for i in range(3))
    @staticmethod
    def _mag(v): return math.sqrt(sum(x**2 for x in v))
    @staticmethod
    def _dist(a, b): return TrajectoryObserver._mag(TrajectoryObserver._vec(a, b))
```

### Wiring into trip lifecycle

```python
# In main.py or motor.py, at trip start:
trajectory_observer = TrajectoryObserver(pod_id=POD_NAME)

# At each line transition (ezone exit / encoder completion of a line):
trip_lines = load_trip_lines()   # {line_id: [pts...]} from trip.json
if current_line_id in trip_lines and next_line_id in trip_lines:
    trajectory_observer.observe_junction(
        current_line_id, trip_lines[current_line_id],
        next_line_id,    trip_lines[next_line_id]
    )

# At trip complete:
trajectory_observer.flush(trip_id=current_trip_id)
```

---

## Noelle's Response

Noelle reads `physical.json` at two moments:

### 1. Before confirming a route (existing `review_recommendations` call)

```ruby
# In Noelle, before issuing a trip plan for a track:
def track_clear?(track_id)
  return true unless @physical_obs_loaded
  severe = @physical_observations.any? do |o|
    (o['track_id'] == track_id || o['next_id'] == track_id) &&
      o['severity'] == 'severe'
  end
  moderate = @physical_observations.count do |o|
    (o['track_id'] == track_id || o['next_id'] == track_id) &&
      o['severity'] == 'moderate'
  end
  return :blocked   if severe
  return :warned    if moderate >= 3
  :clear
end
```

Noelle surfaces this in the Review panel (not silently):
```
[Noelle] Track s001.gw_main_in: BLOCKED — severe heading kink (Nora.SU, 2026-06-17)
```

### 2. At Build / Validate

If `physical.json` exists when Build is run, Noelle reads it and promotes **severe** observations into `network.json` noelle.faults[]:

```ruby
# In generate_network_json, noelle section:
trajectory_faults = load_trajectory_faults_from_physical_json(model)
'noelle' => {
  ...
  'faults' => Array(build_context&.dig('faults')) + trajectory_faults,
  ...
}
```

This means trajectory defects persist in `network.json` — Natalie can read them during route planning.

### Natalie's Response

Natalie reads `network.json` noelle.faults[] during BFS:

```ruby
# Current: Natalie avoids tracks in noelle.faults[]
# New: trajectory defects in noelle.faults[] automatically participate in BFS avoidance
# No new code needed if fault format matches existing noelle.faults[] schema
```

---

## Route-Time (Simulation)

Route-Time Nora moves through a graph, not geometry pts. She does not have raw coordinate arrays at junction time.

**Not implemented in Route-Time v1.** The geometry is abstract (nodes + edge weights). A future Route-Time v2 that carries bezier geometry per edge could run the same heading check. Mark this as a WhatIf observation:

> If Route-Time edges carried geometry pts (not just distances), Nora could detect heading defects in the simulation before physical build.

---

## Implementation Sequence

1. **Write `TrajectoryObserver`** class in `jpod_trajectory_observer.rb` (new file, loaded by plugin)
2. **Wire into `jpod_vehicle_anim.rb`** — `observe_junction` at each track advance; `flush` at animation stop
3. **Rebuild 2_thru_dip** — run animation — read output in Console and physical.json
4. **If defects found** — examine which track pairs triggered; use that to guide geometry fix
5. **Physical (RPi)** — port `TrajectoryObserver` to Python; wire into `motor.py` or `ezone.py` trip lifecycle
6. **Noelle reads physical.json at Build** — promote severe observations to `network.json` noelle.faults[]
7. **Natalie avoids flagged tracks** — verify existing noelle.faults[] BFS avoidance covers trajectory faults

---

## Cross-Domain Summary

| Step | SU (SketchUp) | Physical (RPi) | Route-Time |
|------|--------------|----------------|-----------|
| **Detect** | Animation tick — each track advance | Line transition — ezone/encoder event | Not implemented v1 |
| **Accumulate** | `@trajectory_observer.observe_junction()` | `trajectory_observer.observe_junction()` | — |
| **Flush** | Animation stop callback | Trip complete event | — |
| **Output** | `{stem}.physical.json` + FAULT file | `~/Allie/process/physical/physical.json` + FAULT file | — |
| **Allie sees** | `_allie_capture('nora_trajectory_flush', ...)` | Same event | — |
| **Noelle acts** | Reads physical.json at Build; promotes to noelle.faults[] | Same | Reads network.json |
| **Natalie acts** | BFS avoids tracks in noelle.faults[] | Same | Same |

---

## Open Questions

- **Threshold tuning** — The constants above are first-pass estimates. After first real run on `2_thru_dip`, adjust based on what fires vs. what is background noise.
- **Route-Time geometry** — Should RT edges carry pts? This would close the loop between simulation and physical geometry defect detection.
- **Nora.PH pts source** — Physical Nora has her trip.json lines. Lines from trip.json are the same pts as network.json geometry. Confirmed: same source, safe to use for junction check.
- **`physical.json` accumulation cap** — 500 entries feels right; verify that a day of demo trips doesn't saturate it.
- **Noelle suppression** — Should Noelle suppress an observation after the track is fixed? Yes: a Build clears and rewrites `noelle.faults[]`. Old physical.json entries should be time-bounded — observations older than 30 days should not promote to faults.
