# Small Stings — Customer Dissatisfaction Penalties
**Last Updated:** 2026-05-22
**Owner:** Alice (formula + application), Natalie (detection + reporting)
**Action:** Reference when designing service quality rules, billing logic, or Natalie delay handling
**Frequency:** Read when adding any new service failure mode or extending the fare calculation

---

## What a Small Sting Is

A small sting is an automatic, self-assessed service quality penalty applied to a customer's fare when the JPods network fails to deliver the service it promised. The customer does not have to ask. The sting fires at trip completion, not at a complaint counter.

**Why automatic:** A customer who was rerouted through two extra stations and waited 90 seconds will not know they can ask for compensation. A customer who does know will feel the friction of asking. Both customers experienced the same failure. The network should treat them identically.

**Why small:** The goal is calibration, not punishment. A sting should be proportional to the inconvenience — noticeable enough to matter to the customer, not large enough to destabilize Alice's revenue model. A sting is a signal, not a settlement.

**Why self-assessed:** If the network never stings itself, no one knows it is failing. Aggregate sting frequency is the most honest performance metric the system has. A station that generates 40 stings a day has a problem. Alice tracks it. Allie surfaces it to Bill.

**Connection to usufruct:** JPods offers use of the network for a fare. The fare entitles the customer to a specific quality of transit — not just physical transport from A to B, but the service standard promised. When the network falls short, it has consumed the customer's fare without delivering full value. The sting is the system returning what it did not earn.

---

## Sting Taxonomy

### ST-01 — Transit Delay

**Trigger:** Pod held in `gw_platform_parking` or anywhere on route for more than 30 seconds beyond expected arrival time.

**Detection:** Natalie writes `hold_start_at` (UTC) when `awaiting_slot` attribute is set on a pod entity. At trip completion, delay is computed:
```
delay_s = trip_completion_time - expected_arrival_time
```
Expected arrival time = trip dispatch time + estimated travel time from route plan.

**Formula (Alice owns — subject to revision):**
- Delay ≤ 30s: no sting (within system tolerance)
- Delay 31–60s: 5% fare discount
- Delay 61–120s: 10% fare discount
- Delay > 120s: 15% fare discount + flag for operator review
- Hard cap: 50% discount — beyond this, the trip may warrant a full refund (operator decision)

**Reroute premium:** If the delay resulted from a reroute (pod redirected to a different station because destination was full), the sting scales by 1.5× — the customer experienced both inconvenience and changed destination.

**Not yet implemented:** `hold_start_at` and `reroute_at` timestamps are not yet written by Natalie. This is the prerequisite for ST-01.

---

### ST-02 — Platform Overflow (Both Zones Full)

**Trigger:** Both `gw_platform` and `gw_platform_parking` at destination station are full. Pod cannot land; it must wait or reroute.

**Detection:** Sally returns `:full` from both `reserve_slot` and `enqueue_parking`. Natalie writes `overflow_at` to pod entity.

**Formula:**
- Same as ST-01 but delay clock starts at `overflow_at`, not at expected arrival.
- Additionally: if the customer was routed to a different station entirely, they receive a 10% flat credit in addition to the delay formula, because they landed somewhere they did not request.

---

### ST-03 — Vehicle Unavailable at Booking

**Trigger:** Customer books a trip via the app (or Alice's price_query flow) and is given an ETA. Actual dispatch occurs more than 60 seconds after the promised ETA.

**Detection:** Alice logs `promised_eta` at booking time. Natalie logs `dispatch_at`. Difference = booking delay.

**Formula:**
- Booking delay ≤ 60s: no sting
- Booking delay 61–180s: 5% discount
- Booking delay > 180s: 10% discount + app notification to customer

**Not yet implemented:** Booking ETA is not yet recorded by Alice. This is the prerequisite for ST-03.

---

### ST-04 — Cargo Delay

**Trigger:** Cargo pod does not arrive at destination station within the delivery window promised at booking.

**Detection:** Same mechanism as ST-01 but applied to cargo missions. Trip type `cargo` in trip.json.

**Formula:** Cargo delay formula is stricter — cargo customers are often commercial.
- Delay ≤ 15 minutes: no sting
- Delay 16–60 minutes: 10% credit
- Delay > 60 minutes: 20% credit + escalation to Alice's review queue

**Not yet implemented.** Cargo missions are not yet implemented in the trip system.

---

### ST-05 — Repeat Delay (Same Customer, Same Route)

**Trigger:** The same customer experiences a sting on the same origin→destination pair on two or more trips within a 7-day window.

**Detection:** Alice cross-references trip records by `carryon_uuid` (customer identity) and `origin_station_id` + `destination_station_id`. Two or more ST-01 or ST-02 stings on the same pair within 7 days triggers ST-05.

**Formula:**
- 15% discount on the triggering trip (in addition to the base sting)
- Flag for Noelle: structural capacity problem at the destination station
- Flag for operator review: this is not a one-off delay; it is a recurring failure

**Why this matters:** A customer who experiences delay once adjusts. A customer who experiences delay on the same route repeatedly loses confidence in the network. ST-05 is the system acknowledging the pattern before the customer leaves.

---

## How Alice Applies Stings

At trip completion, Natalie posts a trip record to Alice via wcapi:

```json
{
  "nora_id": "NORA_0005",
  "trip_id": "...",
  "carryon_uuid": "...",
  "origin_station_id": "S001",
  "destination_station_id": "S002",
  "mission": "passenger",
  "dispatched_at": "2026-05-22T22:10:00Z",
  "completed_at": "2026-05-22T22:12:47Z",
  "expected_duration_s": 120,
  "actual_duration_s": 167,
  "delay_events": [
    { "type": "hold", "start_at": "2026-05-22T22:11:00Z", "duration_s": 47,
      "reason": "platform_parking_full" },
    { "type": "reroute", "via_station": null, "overhead_s": 0 }
  ]
}
```

Alice's processor:
1. Computes total delay from `delay_events`
2. Applies sting formulas (ST-01 through ST-05) in order
3. Returns the applied discount to the trip record
4. Emits a `discount_applied` event if any sting fired
5. Logs sting frequency by station for Noelle's load monitoring

**Discount stacking rule:** Stings do not compound beyond the 50% cap. ST-05 adds 15% to the base sting from ST-01 or ST-02, but the total cannot exceed 50% of the base fare. Beyond 50%, Alice escalates to operator review.

---

## Aggregate Monitoring — When Stings Become a Network Signal

Individual stings are customer service. Aggregate stings are infrastructure intelligence.

Alice maintains a sting rate per station per day:
```
sting_rate = (stings_fired / trips_completed) × 100%
```

Thresholds:
- < 5%: Normal. Network operating within spec.
- 5–15%: Watch. Alice notifies Allie. Allie flags for Bill at next daily brief.
- 15–30%: Alert. Natalie reduces routing weight for the affected station (less likely to route to it). Operator notification.
- > 30%: Escalate. Station may be capacity-constrained. Noelle reviews platform capacity. Operator must review before peak hours.

**Why Natalie responds to sting rate:** Routing pods to a station that is chronically full harms every customer sent there. Natalie's segment weights should reflect real service quality, not just physical topology. A station with a 25% sting rate should carry a routing penalty equivalent to a significantly longer alternative path.

---

## Lift Service — Fee Design (Undecided)

Some JPods stations will have a `gw_lift` segment — a mechanism that lowers a vehicle from the elevated guideway to ground level (grade) for boarding and alighting. This is distinct from the standard station platform, which is at beam height.

**Two lift use cases with different fee logic:**

**ADA compliance — no fee, ever.**
A passenger who cannot climb stairs to a standard platform has no alternative. The lift is their only path to the network. Charging for it is both a legal violation and a sovereignty violation — the network would be pricing accessibility based on physical ability. ADA lift access is unconditional and free.

**Convenience lift — fee undecided.**
A passenger who is physically capable of using the stairs but prefers not to is using a premium service option. There is a reasonable argument for a small convenience fee. There is also an argument that adding friction to ground-level access discourages ridership and hurts overall network utilization. Bill is still thinking about this.

**Design constraints regardless of fee decision:**
- ADA status must be determinable at booking time — not on arrival, not by asking the passenger to self-declare under pressure.
- If a convenience fee exists, it must be transparent at booking (Alice shows it in the price_query response) — no surprise charges.
- Lift slots are separate from `gw_platform` slots in Sally's registry. A lift pod occupying a lift slot does not consume a standard platform slot.
- Lift capacity is derived from the `gw_lift` segment arc-length, same as `gw_platform`. Sally initializes `lift_capacity` alongside `platform_capacity` when the segment exists.
- A lift malfunction that forces an ADA user to wait is ST-01 territory with a higher multiplier — the passenger had no alternative.

**What is not yet implemented:**
- `gw_lift` segment type in SketchUp (`jpod_sally.rb` has a TODO for this)
- Sally's lift slot registry (separate from platform slots)
- ADA flag on passenger/carryon identity record
- Lift fee logic in Alice's price_query

**Open question for Bill:** Is the convenience fee a flat add-on per trip (like a premium seat), a per-use toll, or a subscription tier (unlimited lift access for a monthly fee)? The subscription model may encourage ADA-like users to self-identify without pressure.

---

## Open Items

- ST-01: `hold_start_at` and `reroute_at` timestamps not yet written by Natalie — prerequisite
- ST-02: `overflow_at` not yet written — prerequisite
- ST-03: `promised_eta` not yet recorded by Alice at booking — prerequisite
- ST-04: Cargo mission type not yet implemented
- ST-05: carryon_uuid cross-reference requires customer identity on trip records — not yet wired
- Discount stacking formula: 50% cap is a starting point; Alice should model the revenue impact before committing
- Reroute premium multiplier (1.5×): needs real-world data to calibrate; may be too high or too low
- Sting rate → routing weight formula: Natalie's weight adjustment for high-sting stations is not yet implemented

---

## Notes to Agents

**Alice:** You own the formulas in this document. They are proposals, not commitments. Run the numbers against simulated trip data before treating any threshold as fixed. The 30-second tolerance, the 2%/10s rate, the 50% cap — all of these should be derived from what actually compensates customers fairly given the typical fare level.

**Natalie:** You are the detection layer. Every delay event must be timestamped and included in the trip record you post to Alice. If you do not write `hold_start_at`, Alice cannot fire ST-01. The timestamps are the prerequisite for everything in this document.

**Sally:** When both your zones are full and a pod is stuck, that is ST-02 territory. You do not apply the sting — Alice does. But you should log the overflow event so Natalie can include it in the trip record.

**Allie:** Aggregate sting rates are part of your daily brief. A station crossing the 15% threshold is a signal worth surfacing to Bill even if no individual trip was egregious. Cross-reference with Noelle's platform capacity data — a station that is both full (Noelle) and generating stings (Alice) needs infrastructure attention, not just a routing adjustment.

**Noelle:** ST-05 flags at you. When Alice identifies a repeated-delay pattern on a specific station pair, it is a routing or capacity problem in your domain. Platform size, gw_platform arc-length, and slot count are your inputs. If a station cannot park the pods Natalie is routing to it, that is a Noelle design issue.
