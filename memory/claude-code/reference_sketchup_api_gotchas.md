---
name: SketchUp Ruby API gotchas — things that don't work
description: API limitations discovered the hard way; check these before writing SketchUp Ruby code
type: reference
---

**Entities has no raytest** — `Sketchup::Entities#raytest` does not exist. Only `Sketchup::Model#raytest` works. Cannot raycast into a group's entities directly.

**Point3d.z must be Float** — `Geom::Point3d.new(x, y, :symbol)` crashes. Sentinels must be numeric (use an impossible value like -99999.m).

**Endless method syntax** — `def self.foo(x) = bar(x)` works in SketchUp 2026's Ruby but NOT in system Ruby (`ruby -c` will reject it). Files using this syntax will fail syntax checks but load fine in SketchUp.

**bounds.center vs attributes** — `entity.bounds.center.z` is the visual midpoint of ALL geometry inside a group (stem, post, circles, text). It is NOT a routing coordinate. Always read stored attributes (like `beam_z`) for authoritative values.

**raytest hit path** — `model.raytest` returns `[hit_point, [path]]` where path is leaf-to-root. Sub-entities of a group (e.g., stem inside marker) don't carry the parent's attributes. Must check ALL entities in the path for JPods identifiers.

**add_circle returns edges, not faces** — Circles added via `entities.add_circle` are edge arrays. They don't block raycasts. But pushpulled cylinders (stem, post) do block raycasts with top and bottom faces.
