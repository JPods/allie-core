# JPods3D — SketchUp Plugin

Solar-powered transit network design tool for [SketchUp](https://www.sketchup.com/). Design, validate, and animate JPods networks in 3D.

**JPods is the WiFi of the Physical Internet** — station-to-station, neighborhood-to-neighborhood mobility powered by solar, governed locally, built by students and cities.

## Install

1. Download this repository (Code → Download ZIP)
2. Unzip and copy the `su_jpods` folder to your SketchUp Plugins directory:
   - **Mac:** `~/Library/Application Support/SketchUp 2026/SketchUp/Plugins/`
   - **Windows:** `%AppData%/SketchUp/SketchUp 2026/SketchUp/Plugins/`
3. Restart SketchUp
4. JPods toolbar and menu appear under Extensions → JPods

## 8-Step Workflow

| Step | Tool | What it does |
|------|------|-------------|
| 1 | **Geolocate** | Places terrain and satellite imagery |
| 2 | **Place Stations** | Drag station structures from component library |
| 3 | **Calculate CPs** | Auto-detects connection points from station geometry |
| 4 | **Connect Guideways** | Click CPs to connect stations with guideways |
| 5 | **Waypoints** | Route guideways around obstacles |
| 6 | **Build** | Generates physical 3D beams, columns, and solar panels |
| 7 | **Review** | Noelle validates direction, connectivity, and platform tags |
| 8 | **Animate** | Pods run on the built guideways |

## Video Tutorials

### Secaucus, NJ
[![Secaucus NJ JPods Network](https://vumbnail.com/1211192072.jpg)](https://vimeo.com/1211192072)

### Hull, MA
[![Hull MA JPods Network](https://vumbnail.com/1210076038.jpg)](https://vimeo.com/1210076038)

### Greenville, SC
[![Greenville SC JPods Network](https://vumbnail.com/1207256064.jpg)](https://vimeo.com/1207256064)

## Design Standards

- All guideways are **one-way**
- All station circulation is **counter-clockwise (CCW)**
- **Red = inbound** (hot), **Blue = outbound** (cool)
- Guideway clearance: 5m minimum above grade

## Network Planner

Use [MeshMobility](https://meshmobility.com) to plan 2D networks with transit time simulation before building in 3D.

## License

[MIT License](LICENSE) — Copyright (c) 2026 JPods LLC

## Learn More

- [jpods.com](https://jpods.com) — About JPods
- [meshmobility.com](https://meshmobility.com) — Network planning tool
- [webclerk.com](https://webclerk.com) — Commerce platform
