---
name: Cross-domain scaling — lessons apply to all platforms and programs
description: Every engineering principle, TFTS arc, and design decision from any one platform must propagate to all others; the ecosystem is one idea expressed in multiple domains
type: project
---

Every lesson learned in one domain applies to all others. The platforms share physics, the programs share architecture, the process capture (TFTS) is the mechanism for propagation.

**Physical platforms (same physics, different scale):**
- SketchUp plugin (3D design) — where students learn, where designs originate
- Scale model (JPodsSM_RPi) — Nora/Natalie/Noelle on Pi fleet, physical validation
- 4WD (Baron mini-bots) — table-top demo, junction routing, ToF + Husky cam
- SkyRide — full-scale passenger JPods, the destination
- Full JPods network — the deployed system

**Programs (same data architecture, different domains):**
- MeshMobility — city mapping, travel estimates, network planning, O-D simulation
- WebClerk — enterprise software, Alice's domain, ticket sales, Small-Stings, pricing
- MyCarryOn — identity, context portability

**What scales:**
- Smooth guideways primary (g-forces matter at every scale)
- Waypoint Z as authoritative routing coordinate (terrain following at every scale)
- Grade envelopes between anchors (not between distant endpoints)
- BOM structure (components × cost_each = total; same template, different costs per scale)
- Capacity estimation (pods × trips/hr × pax = throughput; same math, different parameters)
- TFTS process capture (the reasoning chain is scale-independent)
- Camera follow offsets (visualization at every scale)

**Why:** Bill (CLAUDE.md): "These are not separate projects. They are the same idea expressed in multiple domains." A scar earned in SketchUp's terrain raycast prevents the same mistake in MeshMobility's elevation model. A grade limit principle from the build pipeline applies to the physical ezone speed protocol.

**How to apply:** When writing a TFTS, tag the domain but note cross-domain applicability. When Allie promotes an Understanding, check if it applies beyond the originating domain. Noelle's universal rules section carries cross-domain axioms.
