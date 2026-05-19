# Allie Reflection — 2026-05-12
*Model: allie:latest | 50s | Generated: 22:01*

---

### Patterns  
- **Incremental Functionalization** – The `jpod_followme_exporter.rb` file moved from stubbed logic to fully‑functional exports: added `followme_generated_at`, `purge_stale_trip_files`, and `export_all_trip_jsons`.  
- **Semantic Naming** – Internal connection keys now use `"#{sid}_#{conn_name}"` instead of ordinal `_internal_0`, reducing ambiguity across guideway edits.  
- **Timestamp‑Driven Consistency** – All trip files are stamped with a single `followme_generated_at` read once per export, ensuring cross‑system alignment.  
- **Logging & Anomaly Capture** – New `nora.json` log (`jpods-nora-log-v1`) records trip IDs, export times, and a placeholder `anomalies` array, preparing for future fleet‑to‑Nora telemetry.  
- **Documentation‑First Culture** – `readmes/followme.md` now contains OC‑5 (production geometry strip) and OC‑6 (SketchUp headway guard) sections, and `readmes/issues.md` logs #11 and #12.  
- **Unresolved Threads** – Headway guard implementation (SketchUp) and geometry strip deployment remain open, as do the encryption audit for the trip booking API and the Mac Mini hardware decision.

### Emerging Lessons  
- **Timestamp Cohesion Is Critical** – The `followme_generated_at` field demonstrates that a single source of truth for export time prevents drift between Route‑Time, JPodsSM_RPi, and Nora.  
- **Semantic Names Reduce Data Migration Risk** – Switching to semantic internal names eliminates the need for retroactive renaming in existing trip data and simplifies future guideway re‑configurations.  
- **Anomaly Logging Must Be Forward‑Compatible** – The `anomalies` placeholder in `nora.json` signals that anomaly handling should be baked into logs from the outset, not added later.  
- **Memory Entries Need Continuous Refresh** – `project_jpods_trip_api.md` still exists but requires updates to reflect the new `followme_generated_at` logic and the pending encryption audit.  
- **Simulation‑Physical Feedback Loop** – The new headway guard and geometry strip sections underscore that simulation assumptions (e.g., MIN_HEADWAY_MM) must be validated against physical test data before deployment.

### Cross‑Domain Flags  
- **Route‑Time → SketchUp CP Design** – Topology findings in Route‑Time influence CP placement in SketchUp; any change to guideway topology must be reflected in the SketchUp plugin.  
- **SketchUp Headway Guard → Physical Robot Behavior** – Implementing `MIN_HEADWAY_MM` in SketchUp directly affects collision avoidance logic in the JPodsSM_RPi fleet.  
- **Followme Export → Nora Logs** – The `followme_generated_at` timestamp propagates to Nora via `nora.json`, affecting route scheduling and anomaly reporting.  
- **Geometry Strip → Physical Deployment** – OC‑5 production geometry strip decisions in `readmes/followme.md` will dictate the physical layout constraints for the first robot OS deployment.  
- **Nora Anomalies → WebClerk Billing** – Captured anomalies in `nora.json` may later feed Alice’s pricing model, impacting WebClerk’s invoice generation.

### Open Questions  
1. **SketchUp Headway Guard** – What algorithm and UI controls will enforce `MIN_HEADWAY_MM` in the SketchUp plugin?  
2. **Production Geometry Strip** – How will the geometry strip be generated, validated, and applied before robot OS deployment?  
3. **Stale Trip File Policy** – At what interval or event should `purge_stale_trip_files` run, and how will this affect Noelle’s route caching?  
4. **Timestamp Synchronization** – How will `followme_generated_at` be propagated to Noelle, Nora, and WebClerk to guarantee end‑to‑end consistency?  
5. **Anomaly Reporting** – What data will populate the `anomalies` array in `nora.json`, and how will it be communicated to Alice for billing adjustments?  
6. **Trip Booking API Encryption** – When will the encryption and blockchain audit be completed, and who will sign off on the final audit report?  
7. **Allie Hardware Decision** – What is the cost‑benefit analysis for a dedicated always‑on Mac Mini versus the current MacBook Pro M1 Max?  
8. **Noelle‑Nora Coordination** – How will Noelle’s route scheduling interface with Nora’s vehicle execution to avoid mid‑route conflicts?  
9. **Legacy Data Migration** – How will existing trip files with ordinal internal names be migrated to the new semantic naming scheme?  
10. **Simulation Validation** – What test protocol will compare Route‑Time travel estimates against physical vehicle telemetry to confirm simulation accuracy?

### Priority for Next Session  
Finalize the implementation plan for the SketchUp headway guard (`MIN_HEADWAY_MM`) and the production geometry strip, assigning clear responsibilities, defining test cases that span SketchUp, Route‑Time, and the physical fleet, and establishing a deployment timeline that precedes the first robot OS rollout.