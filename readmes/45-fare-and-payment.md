# Fare and Payment — JPods Pricing Architecture
**Last Updated:** 2026-05-22
**Owner:** Alice (fare calculation, payment processing, account management)
**Related:** `readmes/44-small-stings.md`, `readmes/09-carryon.md`, `readmes/agents/alice.md`
**Action:** Reference when designing billing, ticketing, identity, or payment flows

---

## Fare Structure

Every trip has two components:

```
fare = minimum_fee + (distance_km × rate_per_km)
```

**Minimum fee** covers the fixed cost of dispatching and parking a vehicle regardless of distance — station overhead, vehicle wear, Natalie's routing computation. A one-stop trip and a cross-city trip both incur it.

**Per-km fee** covers the variable cost of travel — guideway use, energy, maintenance proportional to distance. Natalie reports the route distance at trip completion; Alice applies the rate.

**Rate table:** Alice owns it. Rates vary by:
- Time of day (peak/off-peak)
- Network load (Noelle's capacity signal)
- Mission type (passenger, cargo, waste)
- Special conditions (weather factor, event pricing)

The rate table is never hardcoded — Alice updates it. Natalie reads the current rate at dispatch time.

**Cargo and waste fares** follow the same formula but with different rate tables. Cargo rates reflect goods value and delivery urgency. Waste rates are typically subsidized — the network benefits from continuous waste flow, and the city benefits from reduced collection costs.

---

## Courtesy Discount — Advance Notification

If a customer notifies the network that they are coming before they arrive at the station, they receive a fare discount.

**Why this benefits both sides:**
- Customer: lower fare, vehicle pre-positioned on arrival, no wait
- Network: advance demand signal — Natalie can pre-position vehicles, Sally can pre-reserve a slot, Noelle can balance load before congestion builds

**How it works:**
1. Customer opens app and books a trip: origin station, destination, approximate departure time
2. Alice returns the fare estimate including the courtesy discount
3. Natalie routes a vehicle to the origin station for the expected time
4. Sally pre-reserves the highest available slot at the destination
5. Customer arrives, vehicle is waiting — or nearly so

**Discount amount:** TBD by Alice based on how far in advance the booking was made and how useful the signal was to the network. A booking 10 minutes out is more useful than one 30 seconds before arrival. A graduated discount is reasonable:
- > 5 minutes ahead: full courtesy discount (suggested 10–15%)
- 1–5 minutes ahead: partial discount (suggested 5%)
- < 1 minute / walk-up: no discount — full fare

**The courtesy discount is not a sting.** It is a positive signal — the customer helped the network. Alice tracks courtesy booking rate per station as a demand signal for Noelle's prepositioning model.

---

## Payment Methods

### 1. Phone (Primary)

Customer's phone carries their CarryOn identity (UUID + payment token). The app shows the fare before the customer boards — not after, not as a surprise at the destination. Transparent pricing is non-negotiable.

**Flow:**
1. Customer opens app → sees fare for requested trip
2. Accepts → CarryOn UUID authorizes payment
3. Boards pod → trip executes
4. Trip completion → Alice charges the authorized amount (± small-stings adjustments)
5. Receipt on phone

**Offline handling:** If the phone cannot reach the network at boarding, the trip executes anyway (fare is pre-authorized via cached CarryOn token) and reconciled when connectivity is restored. Never deny a trip because of a network hiccup.

---

### 2. Face Recognition (Biometric Identity)

Station cameras recognize the passenger. Face links to their account. No phone, no card needed. Expected to be the most common payment path alongside the phone — fast, frictionless, nothing to carry.

**How it works:**
1. Customer registers their face once — in the app, at a kiosk, or at a customer service point
2. Face is stored as a biometric hash linked to their CarryOn UUID (the actual image is not retained after hash generation — only the hash)
3. On arrival at a station, the camera identifies the customer
4. Fare is charged to their linked payment method
5. If payment fails → community account (see below)

**Biometric hash retention:**
- **Registered face** (linked to phone/CarryOn account): hash retained as long as the account is active. Customer can delete at any time.
- **Anonymous face** (no account, QR pass only): hash retained for **24–48 hours** after the trip, then purged. This window is long enough to respond to a law enforcement query if an incident is reported on or near the network; short enough that JPods is not a surveillance database. Policy is posted publicly at every station.
- No travel history is reconstructed from anonymous face hashes. The hash exists for incident response only.

**Privacy constraints:**
- The biometric hash is stored on the customer's CarryOn, not on a central server. The station camera computes the hash locally and queries CarryOn for a match.
- The customer controls their biometric data. They can delete it at any time.
- Allie never reads face data. Alice processes payment; the biometric identification is handled by the station's local processor (Sally's chip or a co-located identity module).
- No face data is shared with third parties. This is a JPods-only payment identifier.

**ADA note:** Face recognition must work reliably for customers with physical differences that affect camera angle or framing. A wheelchair user's face is at a different height than a standing passenger. Cameras must cover a range of heights. Failure to identify is not a trip denial — fall back to QR code or phone.

---

### 3. QR Code Pass (Anonymous Transit Account)

For customers who want to travel without identification. Functionally identical to a metro or transit pass — loaded with value at a station kiosk or via the phone app, scanned at departure to deduct the fare.

**Why this exists:** Some customers will not use face recognition or a phone app. A QR pass requires no registration, no phone, no identity. It is the cash equivalent for the network.

**How it works:**
- Customer loads value onto a QR pass at any station kiosk (cash or card) or via the phone app
- At boarding, customer scans QR code at kiosk, selects destination, kiosk shows fare, trip executes
- Fare deducted from pass balance; remaining balance shown on kiosk
- Pass is anonymous by default — no registration required. Lost pass = lost balance.
- Customer may optionally link a pass to their CarryOn UUID (via app or kiosk); linked passes can be replaced if lost

**Pass types:**
- **Value pass:** pre-loaded dollar amount; fare deducted per trip
- **Period pass:** unlimited rides for a defined window (day, week, month); no per-trip calculation

**No retail distribution.** JPods does not operate a retail card distribution network. Transit Oriented Development around stations — the natural commerce that grows up around a network — will find its own equilibrium. Customers load passes at station kiosks or by phone.

---

### 4. No Payment Available — Community Account

If a customer cannot pay at the moment of the trip — no phone, no card, no face registration, insufficient balance — the fare is recorded as a community account balance. The trip executes. The customer is not denied transit.

**Why:** Denying a trip to someone who cannot pay in the moment is a failure of the network's community function. A person who needs to get home and has no payment method in that moment should still be able to get home. The balance is small, the window is short, and the cost to the network is low. This is community service, not charity — the expectation is that the balance will be paid.

**Account terms:**
- Balance carried for a limited period (suggested: 30 days — open to revision)
- Customer receives a notification (text, app, or printed receipt at kiosk) stating the balance and due date
- If balance is not resolved within the window: account is flagged, but the trip is never retroactively denied
- Balance resolution options: pay via phone, card, or kiosk at any station; set up auto-payment linked to a future trip

**What "small" means:** The community account is not a credit line. It is a grace balance for a single trip or a few trips. Alice sets a maximum community account balance (suggested: $10–20 — open to revision). Above this threshold, Alice prompts for payment at the next station visit rather than extending further credit.

**Hardship cases:** Customers with documented hardship (social services connection, community organization voucher) may qualify for extended terms or fee waivers. This is handled at the operator level, not by Alice automatically. Alice flags the account; a human operator makes the determination.

**No interest, no penalty fees.** The balance is what the fare was. Alice does not add fees for late payment on community accounts — that would be a small sting in reverse, penalizing people for not having money in the moment. The network absorbs the short-term cost as a community service function.

**Balance warning — honest, not punitive.** When a community account balance is outstanding and the window is approaching, Alice notifies the customer clearly:

> *"Your JPods balance of $X is due by [date]. You can pay at any station kiosk, by app, or by card. If the balance is not resolved, your account will be paused — but you can always walk or bike, and JPods offers low-cost bike loans at every station."*

The tone matters. This is not a threat. It is a statement of the practical reality — the network cannot carry unlimited unpaid balances, but the customer is never stranded. Walking and biking are real, viable options, and JPods actively supports them (see Last-Mile section below). The warning acknowledges this: the network is a convenience, not a necessity you are trapped inside.

---

## Fare Display — Transparency Rules

The fare is always shown before the customer commits to the trip. No exceptions.

1. **App booking:** fare shown on the booking screen before confirmation
2. **Walk-up kiosk:** fare shown after destination selected, before trip dispatched
3. **QR card:** kiosk shows fare; customer confirms before deducting balance
4. **Face recognition:** kiosk confirms identity and shows fare before trip starts
5. **Community account:** kiosk or app shows the amount being added to the account balance

Alice never charges a fare the customer did not see first. If the actual fare differs from the displayed fare (e.g., because of a small-stings discount applied at completion), the difference is always in the customer's favor. Upward revisions at completion are not permitted.

---

## Alice's Role in Fare and Payment

Alice is the fare engine and the payment processor. She does not handle physical payment hardware (that is the station kiosk's job), but she owns:

- **Rate table:** current minimum_fee, rate_per_km, courtesy discount rates, peak/off-peak multipliers
- **Fare calculation:** given origin, destination (distance), mission type, advance notice, and load signal → fare
- **Payment authorization:** CarryOn payment token, card balance, community account
- **Small-stings adjustment:** post-trip discounts applied before final charge
- **Community account ledger:** balance, due date, notification schedule
- **Courtesy booking rate:** tracks advance booking rate per station as a demand signal

**Alice's price_query API** (already defined in `readmes/agents/alice.md`) is the single endpoint for all fare inquiries — whether from the app, the kiosk, or Natalie's dispatch system.

---

## Last-Mile — Bike Loans at Every Station

JPods is Middle-Mile. It moves people efficiently between stations — neighborhood to neighborhood, district to district. It does not pretend to go to your front door. The Last-Mile gap — from the station to your actual destination — is bridged by walking, cycling, and other short-range modes.

JPods actively supports Last-Mile by offering low-cost bike loans at every station.

**Two loan tiers:**

| Tier | Type | Who it serves | Cost model |
|------|------|--------------|------------|
| Basic | Mechanical bike | Anyone who can ride; no charging needed; lowest cost | Lowest loan rate; simple deposit |
| Premium | Electric bike | Longer last-mile distances; hills; passengers with limited stamina | Slightly higher loan rate; charged at station |

**Loan, not rental.** The word "loan" is deliberate. A rental implies a transaction between strangers. A loan implies a community relationship — the bike is available because someone in the network made it available, and you return it in the same or better condition. This is usufruct applied to bikes: use for profit without harm; return in better condition for the next person.

**Loan mechanics:**
- Bikes available at station storage racks, adjacent to the JPods platform
- Customer checks out via app, QR card, or face — same identity as their JPods account
- Loan fee is small and time-based (suggested: first 30 minutes free with any JPods trip, modest hourly rate after)
- Bike returned to any JPods station — not required to return to origin
- Mechanical damage beyond normal wear → deposit held; operator inspects; excess returned to customer if fault is wear, not neglect
- Electric bikes recharge at station automatically when racked

**Why every station:**
A JPods network where bikes are available at every station converts the network from a point-to-point service into a door-to-door service. The customer does not need a car for the Last-Mile gap. This is the Physical Internet completing its circuit: Middle-Mile (JPods) + Last-Mile (bike) = any origin to any destination without a private vehicle.

**Cargo bikes:**
Some stations will have cargo bikes — for small deliveries, grocery runs, or moving goods from the station to a home or business. Cargo bike loans follow the same model as standard loans. This is the outbound half of JPods cargo service: goods arrive at the station via JPods pod, travel the last mile by cargo bike.

**The redundancy is the design:**
A customer whose JPods account is paused (outstanding balance) can still borrow a bike with a cash deposit at the kiosk. They are never stranded. The network acknowledges that transit is infrastructure, not a luxury to be withheld.

**Connection to weather and Natalie:**
Natalie uses a weather factor (1–5) when dispatching. In good weather, Last-Mile by bike is easy — Natalie can route more efficiently knowing many customers will not need a pod all the way to the station exit. In bad weather, bike loan demand drops; pod demand increases. Natalie and Noelle adjust preposition decisions accordingly.

**Not yet implemented:**
- Bike inventory management system (Alice tracks bike count per station)
- Loan checkout via station kiosk
- Cargo bike fleet (post-initial deployment)
- Bike-to-station return routing (customer can see which nearby stations have available racks)

---

## Integration Points

| System | What it contributes |
|--------|-------------------|
| CarryOn | Customer identity (UUID), payment token, biometric hash pointer, ADA status |
| Natalie | Route distance, trip completion event, delay events for small-stings |
| Sally | Advance slot reservation for courtesy bookings |
| Noelle | Network load signal → rate multiplier |
| Station kiosk | QR reader, face camera, display, cash-out |
| WebClerk / Alice | Rate table, payment processing, account management, receipt |

---

## Open Questions

- Minimum fee amount: what is the right floor? Should it differ by network scale (small city vs. metro)?
- Per-km rate: what rate makes JPods competitive with ride-hail while covering operating costs?
- Courtesy discount tiers: is 10–15% the right range, or should it be higher to drive adoption of advance booking?
- Community account window: 30 days is a proposal. What does the local operator want?
- Community account cap: $10–20 is a proposal. What is the practical maximum before the network absorbs meaningful risk?
- Face registration: in-app only, or can a customer register at a station kiosk without an app?
- Anonymous face retention window: 24–48 hours is the working policy. Confirm with legal/operator before deployment.
- Cargo fare table: same formula as passenger, different rates? Volume discounts for regular shippers?
- Lift convenience fee (if any): see `readmes/44-small-stings.md` — still undecided
