# Network Change Protocol

**Purpose:** Prevent running animation on a stale network. Every structural change requires a Build before the network is operational again.

---

## The Rule

**After Build, the network is locked. Changes require unlock → modify → Build.**

Animation will refuse to start if `build_required` is set in network.json. This flag is set automatically whenever the network structure changes.

---

## What Sets the Build-Required Flag

| Action | Why | Flag set by |
|--------|-----|-------------|
| **Place Structure** | New station added — no connections, no guideways | Place Structure tool |
| **Delete Station** | Connections orphaned, guideways stale, routes broken | CP Calculate (purge) |
| **Add Connection** | New CP pair wired — no guideway geometry exists yet | Connect tool |
| **Remove Connection** | Guideway geometry is now orphaned | Connect tool / Network Editor |

## What Clears the Flag

| Action | What it does |
|--------|-------------|
| **Build** | Regenerates all guideways from network.json. Clears `build_required`. |

---

## Station Locking

After Build completes, every station entity is **locked**:
- `e.set_attribute('JPods', 'locked', true)`

### Why Lock?

Deleting a built station has cascading consequences:
- Connections referencing that station become stale
- Built guideways (seg_ groups) reference CPs that no longer exist
- Sally's station registry has a ghost entry
- Natalie's route graph has dead ends
- Animation will crash or jam at the missing station

### Unlock Before Delete

To delete a locked station:
1. **Unlock** — right-click → JPods → Unlock Station, or Console unlock button
2. **Delete** — SketchUp delete as normal
3. **CP Calculate** — detects missing structure, purges stale connections from network.json, sets `build_required`
4. **Reconnect** — wire the replacement station's CPs
5. **Build** — regenerates guideways, clears flag, re-locks all stations

### What Unlock Does NOT Do

Unlock does not delete connections or guideways. It only removes the delete protection. The user is responsible for the consequences — CP Calculate will clean up stale data on next run.

---

## Student Workflow — Changing a Station

1. **Unlock** the station you want to replace
2. **Delete** it in SketchUp
3. **Place** the new station at the same location
4. **CP Calculate** — purges old connections, shows new CPs
5. **Connect** the new station's CPs to neighboring stations
6. **Build** — generates guideways, clears flag, locks all stations
7. **Populate → Animate** — network is operational again

### Common Mistake

> "I deleted a station, placed a new one, and started animation without rebuilding."

This is the scenario the build-required flag prevents. The old station's data is still in network.json. The new station has no connections. Animation tries to route pods through connections that reference a station that doesn't exist. Pods jam, routes fail, entities corrupt.

**The fix is always the same: CP Calculate → Connect → Build.**

---

## What Gets Purged on CP Calculate

When CP Calculate detects a missing station:

| Data | Location | Action |
|------|----------|--------|
| Connections referencing missing station | network.json `connections{}` | Deleted |
| Friendly name for missing station | network.json `station_names{}` | Deleted |
| Built guideways (seg_ groups) | Model entities | Remain until next Build purges them |
| Sally station registry | In-memory | Rebuilt on next animation start |

---

## For Developers

The `build_required` flag lives in network.json as a top-level boolean:

```json
{
  "schema": "...",
  "build_required": true,
  "connections": { ... },
  "station_names": { ... }
}
```

### Setting the flag (Ruby)

```ruby
nj_path = JPods::NetworkEditor.default_network_json_path(model)
if nj_path && File.exist?(nj_path)
  nj = JSON.parse(File.read(nj_path, encoding: 'utf-8'))
  nj['build_required'] = true
  File.write(nj_path, JSON.pretty_generate(nj), encoding: 'utf-8')
end
```

### Checking the flag (Ruby — animation gate)

```ruby
if nj['build_required']
  puts "⚠ BUILD REQUIRED"
  return false
end
```

### Station lock attribute

```ruby
# Lock (after Build)
entity.set_attribute('JPods', 'locked', true)

# Check before delete
if entity.get_attribute('JPods', 'locked', false)
  UI.messagebox("Station is locked. Unlock before deleting.")
end

# Unlock
entity.set_attribute('JPods', 'locked', false)
```
