# TFTS — 2026-06-13T15:56:53Z

problem:   Manual entity attribute edits in console had no effect on animation behavior

fault_ref: (observed: changing loops attribute on entities found by custom find_vehicles
            function did not change which pod departed — runner stayed wrong)

arc:
  - try:      Used a custom recursive `find_vehicles` console function that recurses into
              `e.definition.entities` for ComponentInstances to find Nora pods and
              set their `sally_hold_loop_loops` attribute.
    result:   Attribute appeared to be set in console output. Animation still used wrong
              pod as runner.
    revealed: `find_vehicles` recurses into `e.definition.entities` — it finds entities
              INSIDE the component definition (shared across all instances), not the
              top-level model entities. `all_nora_vehicles_in_model` searches `model.entities`
              (top-level). These are different Ruby object references with different entityIDs.
              Writing to the definition entity writes a shared template attribute, not the
              instance attribute that `build_fleet` reads.

  - try:      Use `JPods::JPodGuideway.all_nora_vehicles_in_model(model)` to find the exact
              entity objects, then set attributes on those.
    result:   Correct entityIDs confirmed (different from find_vehicles objects).
              BUT animation still showed wrong runner.
    revealed: The platform_shuffle test erases all `station_test=true` entities and creates
              NEW ones on EVERY animation start (jpod_console.rb lines 3123-3128 erase,
              3195-3203 place+tag). All set_attribute changes made after tag_vehicle are
              discarded when the next animation start runs erase+recreate. Manual console
              fixes cannot survive a restart.

  - try:      Edit the `tag_vehicle` lambda and vehicle placement code in jpod_console.rb
              to set correct attributes at creation time (before animation start).
    result:   succeeded — attributes survive restart because they are set by tag_vehicle
              on the freshly created entities each time.

principle: In any test harness that erases and recreates entities on each run, entity
           attributes must be set AT CREATION TIME via the setup lambda — not patched
           manually afterward. Console patches are discarded the moment the test restarts.
           Find the tag/setup function and fix it there. Manual entity edits on a
           recreating harness are always temporary.

domain:    SU
