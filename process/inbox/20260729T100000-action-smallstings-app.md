# ACTION — Small Stings Phone App
**Owner:** Bill James
**Created:** 2026-07-29
**Status:** Concept — build after CityRoadkills deployed and capital raised
**Priority:** Medium-High — product with revenue model

## What

Universal accountability app. Upside-down Yelp. Real-time geolocated $1 fiscal events.

## Two Modes

### 1. CityRoadkills Mode (Roads)
- Citizen photographs unsafe crosswalk, files $1 sting against city
- GPS + timestamp + photo = constructive knowledge record
- Patterns aggregate → Noelle uses for network design
- If someone dies at that location → sting is exhibit A
- City can respond (fix it) or ignore (record accumulates)
- JPods pays citizens for sting data (network design input)

### 2. Commerce Mode (Stores/Orgs)
- "I'm in your store and can't find the toothpaste"
- WC3 store server receives sting via Alice
- Store responds: "Aisle 7, Shelf 3, left side" → sting resolved, no fine
- No response → $1 fine → escalating
- Pattern: 47 people couldn't find toothpaste → move it
- Every sting is an Alice observation improving the store

## Architecture

```
User Phone App (MyCarryOn identity)
    ↓ sting filed
Alice (routing + pattern detection)
    ↓ routes to
WC3 Store Server (if commerce) / City Portal (if roads)
    ↓ response or silence
    ↓ pattern accumulation
Noelle (network design from road stings)
Alice (store improvement from commerce stings)
Leftshoe (learning: what works, what doesn't)
```

## Key Design Decisions

- MyCarryOn identity — user owns their sting history
- $1 fiscal event — tiny but creates a record
- Escalating fines for no-response (optional per org)
- GPS + timestamp + photo required for every sting
- Open data: sting patterns are public (aggregated, anonymized)
- WC3 Desktop Hosting: any store can receive and respond to stings for free

## Revenue Model

- JPods pays citizens for road sting data (network design)
- Stores/orgs pay for pattern reports (what's failing, where, how often)
- Premium: real-time response routing (Alice intercept)
- Free tier: file stings, see aggregated patterns

## Connection to Ecosystem

- **CityRoadkills:** road stings feed the letter evidence and Noelle's network design
- **WC3:** store stings become Alice observations, improve inventory/service
- **MyCarryOn:** user identity travels with them, sting history is theirs
- **PersonalizeTransit:** sting density maps overlay with crash data
- **5x5 Free Market:** stings create the accountability record that makes 5x5 work

## Next Steps

1. Sketch the phone app UI (3 screens: file sting, my stings, city patterns)
2. Define the WC3 API endpoint for receiving stings
3. Define Alice's routing logic (which org gets which sting)
4. Build CityRoadkills mode first (road stings → Noelle)
5. Add commerce mode when WC3 open source launches
