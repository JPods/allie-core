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

### 2. QR Code Card (Physical)

A physical card purchasable at retail stores — grocery stores, pharmacies, convenience stores, anywhere that sells transit passes or gift cards.

**Why retail distribution matters:** Not everyone has a smartphone. Not everyone wants to install an app. A card in a wallet is sovereign — the customer controls it, it works offline, it requires no registration. This is the same principle as cash applied to transit.

**Card types:**
- **Value card:** pre-loaded with a dollar amount. Tap or scan at the station kiosk. Fare deducted per trip. Balance shown on kiosk.
- **Pass card:** unlimited rides for a time period (day, week, month). No fare calculation per trip.
- **Anonymous card:** no registration required. Lost card = lost balance. Customer accepts this tradeoff.
- **Registered card:** customer optionally links the card to their identity (phone number or CarryOn UUID). Lost card can be replaced; balance transferred.

**Station kiosk:** Each station has a QR reader. Customer scans card on arrival, selects destination, kiosk shows fare, trip executes. No app needed.

**Retail integration:** Cards sold through Alice's WebClerk integration. Retail stores scan a QR at point of sale; Alice activates the card and records the initial value. The retailer earns a small commission. This is the same model used by prepaid phone cards and gift cards — well understood by retailers.

---

### 3. Face Recognition (Biometric Identity)

Station cameras recognize the passenger. Face links to their account. No phone, no card needed.

**How it works:**
1. Customer registers their face once — in the app, at a kiosk, or at a customer service point
2. Face is stored as a biometric hash linked to their CarryOn UUID (the actual image is not retained after hash generation — only the hash)
3. On arrival at a station, the camera identifies the customer
4. Fare is charged to their linked payment method
5. If payment fails → account balance (see below)

**Privacy constraints:**
- The biometric hash is stored on the customer's CarryOn, not on a central server. The station camera computes the hash locally and queries CarryOn for a match.
- The customer controls their biometric data. They can delete it at any time.
- Allie never reads face data. Alice processes payment; the biometric identification is handled by the station's local processor (Sally's chip or a co-located identity module).
- No face data is shared with third parties. This is a JPods-only payment identifier.

**ADA note:** Face recognition must work reliably for customers with physical differences that affect camera angle or framing. A wheelchair user's face is at a different height than a standing passenger. Cameras must cover a range of heights. Failure to identify is not a trip denial — fall back to QR code or phone.

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

## Integration Points

| System | What it contributes |
|--------|-------------------|
| CarryOn | Customer identity (UUID), payment token, biometric hash pointer, ADA status |
| Natalie | Route distance, trip completion event, delay events for small-stings |
| Sally | Advance slot reservation for courtesy bookings |
| Noelle | Network load signal → rate multiplier |
| Station kiosk | QR reader, face camera, display, cash-out |
| WebClerk / Alice | Rate table, payment processing, account management, receipt |
| Retail stores | QR card activation and distribution |

---

## Open Questions

- Minimum fee amount: what is the right floor? Should it differ by network scale (small city vs. metro)?
- Per-km rate: what rate makes JPods competitive with ride-hail while covering operating costs?
- Courtesy discount tiers: is 10–15% the right range, or should it be higher to drive adoption of advance booking?
- Community account window: 30 days is a proposal. What does the local operator want?
- Community account cap: $10–20 is a proposal. What is the practical maximum before the network absorbs meaningful risk?
- Face registration: in-app only, or can a customer register at a station kiosk without an app?
- QR card retail distribution: which retail chains? Regional variation? JPods works with local operators — the retail network will differ by city.
- Cargo fare table: same formula as passenger, different rates? Volume discounts for regular shippers?
- Lift convenience fee (if any): see `readmes/44-small-stings.md` — still undecided
