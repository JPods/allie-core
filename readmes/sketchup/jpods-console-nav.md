# JPods Console — Navigation Panel Reference
**Last Updated:** 2026-06-12

The JPods Console is the primary control interface for designing, building, and animating a JPods network in SketchUp. All functions are organized under a top navigation bar with four sections: **Network**, **Vehicles**, **Models**, and **Documentation**.

---

## Top Navigation Bar

Four buttons across the top. Each click executes a function directly — no sub-menus to navigate.

| Button | What it does |
|--------|-------------|
| **Network** | Runs CP Calculate — detects connection points on all placed stations, activates the Connect Guideways tool, restores any saved connections |
| **Vehicles** | Runs List Vehicles — shows the Vehicles table with all pods in the model, their assigned trips, speed, and route controls |
| **Models** | Opens the Models panel — one-click buttons for every station template and utility model |
| **Documentation** | Opens the Learning panel — checklist of testable behaviors for verifying the plugin works correctly |

---

## Network Display

Shown when **Network** is clicked.

### Primary Constraints (NE iframe — top section)
Key network parameters set in the Network Editor: speed, clearance height, beam width.

### Quick Actions Bar (NQA — green/teal strip)
Five buttons that execute immediately with no parameters:

| Button | What it does |
|--------|-------------|
| **Build** | Builds physical 3D guideway geometry along all connections in network.json |
| **Finder** | Opens the model's folder in macOS Finder |
| **Show Tracks** / **Hide Tracks** | Toggles the formation track overlay — draws colored path lines for all station and inter-station tracks (red=inbound, blue=outbound, yellow=ring, green=platform). Toggles on/off. |
| **Validate** | Runs Noelle validation — checks CP directions, platform guideways, connectivity; outputs a fault report |
| **Label Size** | Sets the size of guideway name labels in the 3D model |

### Runtime Console (NE iframe — bottom section)
Live log output from the plugin — build progress, validation faults, animation ticks, Sally slot events.

---

## Vehicles Display

Shown when **Vehicles** is clicked.

### Vehicles Table
One row per pod in the model.

| Column | Content |
|--------|---------|
| Vehicle ID | Nora ID (e.g., NORA_0001). Eye button zooms to the pod in the 3D view |
| Lines | Number of track segments in the assigned trip |
| Start | Origin platform (e.g., S002.P1) |
| End | Destination platform (e.g., S001.P1). Editable — type a platform ID and press Enter or blur to assign a trip |
| Actions | **📷** Camera follow toggle · **Clear/Assign** trip · **JSON** full trip detail modal · **Show Route / Hide Route** route overlay toggle |

### Route Button behavior
- **Show Route** — draws a gold overlay on all tracks in the vehicle's assigned trip, lifted 600mm above the guideway. Uses path.json geometry (works without Build). Hides any previously shown route for another vehicle.
- **Hide Route** — removes the gold route overlay.
- If no trip is assigned, clicking Show Route clears any displayed route and resets all buttons.
- Only one route is shown at a time.

### Camera Follow (📷)
Click to follow a pod in real time during animation. Click again to stop following.

---

## Models Display

Shown when **Models** is clicked.

Grid of one-click buttons, one per station template and utility model. Clicking a button places the component or opens the model — same behavior as the SketchUp component browser, but filtered to JPods-relevant models only.

---

## Documentation Display

Shown when **Documentation** is clicked.

A learning checklist of testable behaviors, organized by category (Console UI, Network, Build, Animation, etc.). Each item has:
- **Label** — what is being verified
- **Do** — the steps to test it
- **Expect** — what correct behavior looks like
- **Checkbox** — mark when verified

Use this during development or student demos to confirm the plugin is working correctly.

---

## Output Area

Below the top nav, above the Network Editor. Shows the result of the last executed action — success messages in green, errors in red, warnings in yellow. Appears automatically when a task runs and collapses when the Network Editor needs full height.

---

## Design Principles

- **One source of truth.** Every function is reachable from the top menu. No duplicate paths.
- **Execute on click.** Network and Vehicles execute their primary function the moment you click — no intermediate steps.
- **NQA buttons are immediate.** Build, Finder, Show Tracks, Validate, Label Size run with known defaults. No parameter dialogs.
- **Display area extends the top nav.** The Network display hosts the NQA bar and Runtime Console. The Vehicles display hosts the trip table and route controls. Additional controls go here, not in a separate sidebar.

---

## Adding New Functions

Per the one-source-of-truth rule: new functions go under the relevant top-menu display area, not in a separate panel. Options:

- **Network action** → add an NQA button in the Quick Actions Bar (network_editor.html `#nqa-btns`)
- **Vehicle action** → add a column or button in the Vehicles table (console.html `setTripTable`)
- **Model utility** → add a button in the Models panel grid
- **Reference / docs** → add an entry to the Learning checklist
