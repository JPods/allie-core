# Vehicle JSON Schema (Corrected)

**Date:** April 30, 2026  
**Purpose:** Define the complete structure for `<model>.vehicles.json` including all required fields for vehicle placement and routing

`<model>.vehicles.json` is the startup source of truth for Nora placement and assignment intent.
Per-run routing rejections and animation diagnostics are not startup inputs and do not belong in this file.

## Problem with Current File

**File:** `OK_LazyE_terrain.vehicles.json`

**Current structure (incomplete):**
```json
{
  "model_name": "OK_LazyE_terrain",
  "saved_at": "2026-05-01T01:33:48Z",
  "vehicles": [
    { "id": "ene_JPodBlue", "qty": 3 }
  ]
}
```

**Missing fields per vehicle instance:**
- `vehicle_ids` — Unique NORA_#### identifier for each instance
- `placements[]` — Where to place each vehicle (station, slot, guideway)
  - `platform_id` — Which loading platform
  - `station_id` — Which station
  - `parking_slot` — Slot number (1, 2, 3, etc.)
  - `coordinates` — Optional: specific 3D position override

---

## Corrected Full Schema

```json
{
  "schema": "jpods-vehicles-v1",
  "model_name": "OK_LazyE_terrain",
  "saved_at": "2026-05-01T01:33:48Z",
  "speed_ms": 8.3,
  "vehicles": [
    {
      "template_id": "ene_JPodBlue",
      "qty": 3,
      "instances": [
        {
          "vehicle_id": "NORA_0001",
          "placements": [
            {
              "placement_id": "p_blue_1",
              "order": 1,
              "station_id": "S001",
              "platform_id": "platform_S001_main",
              "parking_slot": 1,
              "destination_station_id": "S003",
              "destination_platform_id": "platform_S003_main",
              "notes": "Morning loop: S001 → S003"
            }
          ]
        },
        {
          "vehicle_id": "NORA_0002",
          "placements": [
            {
              "placement_id": "p_blue_2",
              "order": 1,
              "station_id": "S002",
              "platform_id": "platform_S002_loop",
              "parking_slot": 2,
              "destination_station_id": "S003",
              "destination_platform_id": "platform_S003_main",
              "notes": "Loop: S002 → S003"
            }
          ]
        },
        {
          "vehicle_id": "NORA_0003",
          "placements": [
            {
              "placement_id": "p_blue_3",
              "order": 1,
              "station_id": "S003",
              "platform_id": "platform_S003_siding",
              "parking_slot": 1,
              "destination_station_id": "S001",
              "destination_platform_id": "platform_S001_main",
              "notes": "Return: S003 → S001"
            }
          ]
        }
      ]
    },
    {
      "template_id": "ene_JPodGreen",
      "qty": 3,
      "instances": [
        {
          "vehicle_id": "NORA_0004",
          "placements": [
            {
              "placement_id": "p_green_1",
              "order": 1,
              "station_id": "S001",
              "platform_id": "platform_S001_main",
              "parking_slot": 2,
              "destination_station_id": "S002",
              "destination_platform_id": "platform_S002_loop",
              "notes": "Green cycle: S001 → S002"
            }
          ]
        },
        {
          "vehicle_id": "NORA_0005",
          "placements": [
            {
              "placement_id": "p_green_2",
              "order": 1,
              "station_id": "S002",
              "platform_id": "platform_S002_loop",
              "parking_slot": 1,
              "destination_station_id": "S003",
              "destination_platform_id": "platform_S003_main",
              "notes": "Green to hub"
            }
          ]
        },
        {
          "vehicle_id": "NORA_0006",
          "placements": [
            {
              "placement_id": "p_green_3",
              "order": 1,
              "station_id": "S003",
              "platform_id": "platform_S003_main",
              "parking_slot": 3,
              "destination_station_id": "S001",
              "destination_platform_id": "platform_S001_main",
              "notes": "Green return: S003 → S001"
            }
          ]
        }
      ]
    },
    {
      "template_id": "ene_JPodRed",
      "qty": 3,
      "instances": [
        {
          "vehicle_id": "NORA_0007",
          "placements": [
            {
              "placement_id": "p_red_1",
              "order": 1,
              "station_id": "S001",
              "platform_id": "platform_S001_main",
              "parking_slot": 3,
              "destination_station_id": "S003",
              "destination_platform_id": "platform_S003_main",
              "notes": "Red outbound"
            }
          ]
        },
        {
          "vehicle_id": "NORA_0008",
          "placements": [
            {
              "placement_id": "p_red_2",
              "order": 1,
              "station_id": "S002",
              "platform_id": "platform_S002_loop",
              "parking_slot": 3,
              "destination_station_id": "S003",
              "destination_platform_id": "platform_S003_main",
              "notes": "Red from west"
            }
          ]
        },
        {
          "vehicle_id": "NORA_0009",
          "placements": [
            {
              "placement_id": "p_red_3",
              "order": 1,
              "station_id": "S003",
              "platform_id": "platform_S003_siding",
              "parking_slot": 2,
              "destination_station_id": "S001",
              "destination_platform_id": "platform_S001_main",
              "notes": "Red return from hub"
            }
          ]
        }
      ]
    },
    {
      "template_id": "ene_JPodYellow",
      "qty": 3,
      "instances": [
        {
          "vehicle_id": "NORA_0010",
          "placements": [
            {
              "placement_id": "p_yellow_1",
              "order": 1,
              "station_id": "S001",
              "platform_id": "platform_S001_siding",
              "parking_slot": 1,
              "destination_station_id": "S002",
              "destination_platform_id": "platform_S002_main",
              "notes": "Yellow west line"
            }
          ]
        },
        {
          "vehicle_id": "NORA_0011",
          "placements": [
            {
              "placement_id": "p_yellow_2",
              "order": 1,
              "station_id": "S002",
              "platform_id": "platform_S002_main",
              "parking_slot": 2,
              "destination_station_id": "S001",
              "destination_platform_id": "platform_S001_main",
              "notes": "Yellow return"
            }
          ]
        },
        {
          "vehicle_id": "NORA_0012",
          "placements": [
            {
              "placement_id": "p_yellow_3",
              "order": 1,
              "station_id": "S003",
              "platform_id": "platform_S003_main",
              "parking_slot": 2,
              "destination_station_id": "S002",
              "destination_platform_id": "platform_S002_loop",
              "notes": "Yellow from hub to loop"
            }
          ]
        }
      ]
    }
  ],
  "metadata": {
    "description": "Vehicle placement and routing for OK_LazyE_terrain network",
    "created_by": "Bill James (JPods Foundation)",
    "notes": [
      "Schema: jpods-vehicles-v1",
      "Each vehicle instance gets unique vehicle_id (NORA_####)",
      "Each placement references an existing platform_id from followme.json stations",
      "Parking slot must be between 1 and station.platforms[].slot_count",
      "destination_station_id can differ from current station for one-way trips",
      "Natalie validates this on startup and reports any missing stations/platforms"
    ]
  }
}
```

---

## Field Reference

### Top Level
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema` | string | YES | Version identifier: "jpods-vehicles-v1" |
| `model_name` | string | YES | Must match SketchUp model filename |
| `saved_at` | ISO8601 | YES | When this file was created/updated |
| `speed_ms` | number | YES | Default vehicle speed in m/s (e.g., 8.3) |
| `vehicles[]` | array | YES | Array of vehicle template groups |
| `metadata` | object | NO | Documentation + notes |

### Vehicle Template (in `vehicles[]`)
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `template_id` | string | YES | Formation template ID (e.g., "ene_JPodBlue") |
| `qty` | integer | YES | Total instances of this template |
| `instances[]` | array | YES | Array of placement records for each instance |

### Vehicle Instance (in `instances[]`)
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `vehicle_id` | string | YES | Unique identifier (NORA_0001...NORA_9999) |
| `placements[]` | array | YES | Where to place this vehicle (supports multi-placement for shuttles) |

### Placement (in `placements[]`)
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `placement_id` | string | YES | Unique ID for this placement record (e.g., "p_blue_1") |
| `order` | integer | YES | Sequence order if multiple placements |
| `station_id` | string | YES | Starting station (e.g., "S001") |
| `platform_id` | string | YES | Loading platform at that station |
| `parking_slot` | integer | YES | Parking slot number (1-based, must be ≤ platform slot_count) |
| `destination_station_id` | string | YES | Where vehicle will be routed to |
| `destination_platform_id` | string | YES | Destination platform in that station |
| `coordinates` | object | NO | Optional 3D position override (use platform default if omitted) |
| `notes` | string | NO | Human-readable placement description |

---

## Validation Rules (Natalie Startup)

Natalie checks the following on plugin load:

1. **Schema version** — Must be "jpods-vehicles-v1"
2. **Model name** — Must match current SKP file name
3. **Vehicle templates** — Each template_id must exist as a SketchUp component definition
4. **Instances count** — qty must equal length of instances[]
5. **Vehicle IDs** — Each NORA_#### must be unique
6. **Station IDs** — Each station_id must exist in followme.json stations[]
7. **Platform IDs** — Each platform_id must exist in station.platforms[]
8. **Parking slots** — Each parking_slot must be ≤ platform.slot_count
9. **Destinations** — destination_station_id and destination_platform_id must both exist

### If Validation Fails

Natalie prints warnings to console but **does not block plugin load**:

```
⚠️  Natalie startup validation issues:
  • Missing schema field (expected: jpods-vehicles-v1)
  • Vehicle NORA_0001: station_id S099 not found in followme.json
  • Vehicle NORA_0002: platform_id platform_S001_missing not found
  • Vehicle NORA_0003: parking_slot 5 exceeds platform slot_count (4)

See <model>.vehicles.json and followme.json for details.
Run 'Validate Vehicle Placement JSON' from console to re-check.
```

---

## Example: OK_LazyE_terrain Corrected File

The corrected file is provided above. Key differences from original:

**Original:**
```json
{
  "model_name": "OK_LazyE_terrain",
  "vehicles": [
    { "id": "ene_JPodBlue", "qty": 3 }
  ]
}
```

**Corrected:**
- Added `schema` version field
- Renamed `id` → `template_id`
- Added `instances[]` with unique `vehicle_id` for each vehicle
- Added `placements[]` with complete station/platform/slot info
- Added `metadata` section with documentation

---

## Usage: Loading Vehicle Placement

```ruby
# In SketchUp console or task:
vehicles_json_path = File.join(File.dirname(model.path), "#{File.basename(model.path, '.skp')}.vehicles.json")
vehicle_data = JSON.parse(File.read(vehicles_json_path, encoding: 'utf-8'))

vehicle_data['vehicles'].each do |template_group|
  template_group['instances'].each do |instance|
    nora_id = instance['vehicle_id']
    instance['placements'].each do |placement|
      # Place vehicle at specified station/platform/slot
      ok, result = JPods::JPodVehicleRuntime.place_vehicle_at_platform(
        model,
        template_group['template_id'],
        origin_platform,
        destination_platform,
        slot_index: placement['parking_slot']
      )
      puts "Placed #{nora_id} at slot #{placement['parking_slot']}: #{ok}"
    end
  end
end
```

---

## Migration Guide: From Old to New Format

If you have an existing vehicles.json without instance/placement info:

1. Open the file in a text editor
2. Add `schema: "jpods-vehicles-v1"` at top
3. For each vehicle type and quantity:
   - Rename `id` → `template_id`
   - Add `instances: []` array
   - For each qty (1..qty):
     - Create instance with `vehicle_id: "NORA_####"` (increment ####)
     - Add `placements[]` with station/platform/slot
4. Save and validate in console: "Validate Vehicle Placement JSON"

---

## Status

- ✅ Schema defined
- ✅ Example with full 12-vehicle OK_LazyE_terrain setup
- ✅ Field reference with required/optional
- ✅ Validation rules enumerated
- 🔄 Need to add startup validation to Natalie (see next section)
