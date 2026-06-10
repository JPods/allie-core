# Sally Standard Test
**Last Updated:** 2026-06-09
**Owner:** Sally (station behavior), Nora (vehicle animation)
**Location:** Console → Models tab → Model Testing → Sally Test button

---

## Purpose

The Standard Sally Test verifies the full parking-queue and station-behavior cycle for any station template. It is the canonical check that Sally's behavioral chains are correctly wired before a template is committed.

Run it on any station template model (the .skp must have been through Build Network so a placed station exists in the model).

---

## What It Tests

| Step | Agent | Behavior verified |
|------|-------|------------------|
| 1 | Sally | V1 placed at parking_1, shuffled to deepest parking slot |
| 2 | Sally | V2 placed at parking_1; V1 shuffles back, V2 takes front |
| 3 | Sally | V3 placed at parking_1; queue is full (V1=deepest, V2=middle, V3=front) |
| 4 | Nora  | Animation starts; all 3 vehicles enter Sally dispatch queue |
| 5 | Sally | V1 executes 3 hold-loop circuits; Sally announces each loop completion |
| 6 | Sally | While V1 loops, V2 and V3 shuffle forward toward platform (courtesy shuffle) |
| 7 | Nora  | V2 reaches platform, exits via nearest outbound CP — disappears |
| 8 | Nora  | V3 advances to platform, exits via nearest outbound CP — disappears |
| 9 | Sally | V1 completes 3rd loop; Sally promotes V1 to landing chain |
| 10 | Nora | V1 exits via CP — disappears |
| 11 | Sally | All 3 test vehicles gone → erase from model → test passes |

---

## How to Run

1. Open the template model (e.g. `traffic_circle7/model.skp`)
2. Build a network containing this template (Extensions → JPods → Console → Network → Build Network)
3. Open Console → **Models** tab
4. Click **Sally Test**

Sally and Nora post their intended behaviors in the log strip below the test buttons. Each line is prefixed `[Sally]` or `[Nora]`.

---

## Pass Criteria

- All 3 vehicles exit the station without routing errors
- V1 completes exactly 3 hold-loop circuits before promotion
- V2 and V3 demonstrate courtesy shuffle advancement
- No vehicles remain in the model after completion (auto-erased)

The Console Log (bottom strip) shows the Ruby-side puts() stream. Check it if the test fails.

---

## Stop Early

Click **Stop Animation** (header bar) to end the test at any time. The polling loop will timeout after 3 minutes and clean up remaining test vehicles automatically.

---

## Design Notes

**Why automatic cleanup:** Station template models must not be saved with vehicles in them. The test erases all entities tagged `station_test: true` on completion (or timeout). The `SaveCleanupObserver` in `main.rb` also erases them on any Cmd+S as a secondary guard.

**Why 3 vehicles:** One vehicle tests queue management in isolation. Three vehicles test:
- Queue fill and shuffle (structural integrity of parking_chain)
- Concurrent hold-loop + courtesy shuffle (Sally's multi-vehicle coordination)
- Sequential CP departure (Nora's dispatch after Sally promotion)

**V1 always deepest:** The first vehicle placed at parking_1 gets shuffled back with each subsequent placement. By the time all 3 are in, V1 is at parking_N (furthest from the platform). This is the vehicle that holds the loop — it has the longest wait and tests the full parking chain traversal.

---

## Relationship to Chain Definitions

The test exercises these chains from `lines.json`:

| Chain | Tested by |
|-------|----------|
| `parking_chain` | Steps 1–3: queue fill and shuffle |
| `hold_loop_chain` | Step 5: V1's 3 circuits |
| `landing_chains` | Step 9: V1 promotion after loop completion |
| `originating_chains` | Steps 7–8, 10: CP departure for all 3 vehicles |

If any chain is missing or incorrectly wired, the test will fail or timeout at the corresponding step. The `[Sally]` log entries identify which step failed.

---

## Related Files

- `readmes/agents/sally.md` — Sally's full behavioral chain specification
- `jpod_console.rb` → `cmd_sally_standard_test` — test implementation
- `jpod_sally.rb` → `init_sequencer_for_station`, `reserve_slot` — runtime Sally
- `lines.json` (per template) — the behavioral chain definitions being tested
