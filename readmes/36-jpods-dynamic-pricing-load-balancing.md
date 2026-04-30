# JPods — Dynamic Pricing and Load Balancing
**Last updated:** 2026-04-29
**Status:** Concept documented — implementation via Alice pricing + Item model

---

## Why One Item Per Station Pair

Each directional station pair has its own `Item` record (SKU: `JPODS-DEFAULT-S001-S003`).
This will produce many Item records as networks grow — and that is intentional.

**Each Item record is a demand sensor.**

Alice's invoice history on that Item shows exactly how many trips were made on that route,
when, at what price level, and to whom. As the network grows:

| Records | Insight |
|---------|---------|
| Item per pair | Trip count, revenue, rider mix per route |
| InvoiceLine per trip | Full audit trail: rider, time, fare, price level |
| Customer.price_level | Rider-level price sensitivity |

This data feeds the load balancing loop.

---

## Load Balancing via Dynamic Pricing

When a station pair becomes congested (too many trip requests, vehicle queue forming),
Alice can raise the price for that pair and reduce prices on nearby alternative routes
to spread demand across the network.

### The Mechanism

```
Demand spike on S001→S003
  → Alice raises Item["retail"] on JPODS-DEFAULT-S001-S003
  → Alice lowers Item["retail"] on JPODS-DEFAULT-S002-S003  (nearby origin)
  → Riders choosing S002 over S001 experience shorter wait
  → Network self-balances
```

This is the Physical Internet® pricing model: price signals replace central scheduling.
Stations are interchangeable; the network routes around congestion through price.

### Price Adjustment Protocol

Alice reads congestion signal from Natalie (or a future load monitor):
```json
{
  "station": "S001",
  "direction": "outbound",
  "queue_depth": 8,
  "threshold": 3
}
```

Alice responds:
1. Raises `Item.price["retail"]` (and optionally `wholesale`, `sample`) on affected pairs
2. Lowers prices on adjacent origin → same destination pairs
3. Logs the change in `Item.price["history"]` (auto-tracked by Item model on save)
4. Creates an Alice action record noting the adjustment and the trigger

Price history is built into the Item model — every change to `Item.price` is logged
automatically in `price["history"]`, giving Alice a full price-change audit trail.

### Fallback: Manual Adjustment

Until automated signals are built, Alice or Bill can manually update any Item's price
in the WebClerk admin or via the API. The history field records who changed it and when.

---

## Discount Tiers as Demand Levers

`Customer.financial["discounts"]` is another lever. During off-peak periods:
- Add a temporary discount to all customers (`type: "percent", value: 20, label: "Off-Peak"`)
- Remove it during peak periods
- Apply it selectively by price_level (e.g. only retail customers get the off-peak discount)

This does not require changing Item prices — it applies at the Customer layer, leaving
the Item price record clean and the Customer record as the variable.

---

## Scale Projection

A 4-station network: 12 directional pairs → 12 Items
A 10-station network: 90 directional pairs → 90 Items
A 100-station network: 9,900 directional pairs → 9,900 Items

WebClerk's Item table handles this without modification. Each Item is a lightweight record
with a price JSONField. The load is in InvoiceLine (one row per completed trip), not Items.

---

## Route-Time Integration (Future)

Route-Time has travel time estimates per (origin, destination) pair. When integrated:
- Trip app shows estimated travel time before the rider confirms
- Alice can factor travel time into pricing (longer routes cost more)
- Natalie uses Route-Time estimates to schedule vehicle dispatch timing

---

## Next Steps

1. **Congestion signal from Natalie** — define the API call Natalie sends when a station queue exceeds threshold
2. **Alice price adjustment service** — `apps/jpods/services/load_balance.py`
   - `adjust_route_price(origin, destination, delta_percent)` — raises one pair, lowers neighbors
   - Triggered by Natalie signal or manual Alice action
3. **Off-peak discount automation** — cron or Natalie signal to toggle Customer discounts
4. **Route-Time travel time** — fetch estimate and show in trip app before Travel button
5. **Noelle integration** — construction and maintenance transactions also affect capacity;
   Noelle signals Alice when a station is offline or constrained
