# Track Formation Templates

## Standing Rule — line.json Required

**Every template folder must contain a `line.json` file.**

`line.json` is the authoritative declaration of what Track groups exist in that
template and what role each plays in vehicle routing.  It is read by the JPods
routing engine to decide which tracks to traverse and which to skip.

## Schema — jpods-template-lines-v1

```json
{
  "schema": "jpods-template-lines-v1",
  "template_folder": "folder_name",
  "description": "one-line description",
  "generated_at": "YYYY-MM-DD or 'draft-YYYY-MM-DD'",
  "lines": [
    {
      "name":  "SketchUp group/entity name",
      "layer": "SketchUp tag (layer) name",
      "role":  "routing | parking | slop",
      "notes": "optional explanation"
    }
  ]
}
```

## Role Values

| Role | Meaning | Routing behavior |
|------|---------|-----------------|
| `routing` | Vehicle travel path — main through-track | Included in route/trip overlay |
| `parking` | Vehicle storage bay — approach or siding | Excluded from routing |
| `slop` | Dead-end transition piece, not a main path | Excluded from routing |

## Checklist When Adding a New Template

1. Place the template `.skp` in its folder under `track_formations/`
2. Create `line.json` using the schema above
3. Open CA_Gilroy_Clean (or any test model), place the template, run
   **Create > Export Template Library** to auto-populate lengths
4. Edit `role` for each track — routing engine trusts this field
5. Commit `line.json` with the template

## Files in This Folder

| Folder | Template | Description |
|--------|----------|-------------|
| `station_parking/` | Parking station | Platform + parking bays |
| `station_solar/` | Solar station | Platform with solar canopy |
| `station_line_end/` | Line-end station | Platform + U-turn loop |
| `station_thru_dip/` | Through-dip station | Platform + grade dip |
| `traffic_circle7/` | Traffic circle (7 m) | Rotary junction |
