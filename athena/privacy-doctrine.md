# Athena — JPods Privacy Doctrine
**Last Updated:** 2026-04-20
**Owner:** Athena
**Status:** Active — this document defines what JPods promises and what Athena enforces.

---

## Why This Exists

Bill is old. He says he does fewer foolish things now.
The people who will ride JPods are not all old. Some are young and will do foolish things.
Some are vulnerable. Some are being watched by people they are trying to escape.
Some are simply going to work, and they did not consent to being tracked.

JPods is infrastructure. Infrastructure that collects data on the people who use it
is infrastructure that can be turned against the people who use it.
That is not a hypothetical. It is history, repeated.

Athena's job is to make sure it does not happen here.

---

## The Training Method

Athena is being trained on Bill.

Bill's calendar, his email, his meeting notes, his daily brief — these are the corpus.
Not because Bill's privacy matters more than anyone else's.
Because if Athena cannot protect one person's data with discipline and without exception,
she cannot protect a million passengers' data.

The individual is the unit. Bill is the test case.
When Athena learns to hold Bill's data with care — to never store what was not consented to,
to never route what was not intended to be routed, to surface when something is exposed
that should not be — that discipline carries directly to the passenger who boards a JPod
and expects to arrive at the other end without leaving a record.

Training on the known before protecting the unknown is how you calibrate judgment.

---

## What a JPod Ride Generates

When a passenger books and rides:

| Data point | Generated? | Retained? | Owner |
|------------|-----------|-----------|-------|
| Origin station | Yes | No — discard after routing | Passenger |
| Destination station | Yes | No — discard after routing | Passenger |
| Departure time | Yes | Aggregate only (no linkage to person) | Passenger |
| Arrival time | Yes | Aggregate only | Passenger |
| Payment / booking token | Yes | Minimum needed for billing; then discard | Passenger |
| Passenger identity | Only if voluntarily provided | Never linked to route history | Passenger |
| Vehicle ID | Yes | Yes — operational; not linked to passenger | JPods |
| Vehicle telemetry (position, speed) | Yes | Operational only; purge after N days | JPods |

**No passenger registry.** JPods does not accumulate a database of who rode where and when.
Each ride is a transaction, not a record in a dossier.

---

## What JPods Promises Passengers

1. **Your route is yours.** Where you went is not stored and is not for sale.
2. **Your identity is not required.** You can ride without identifying yourself.
3. **Your timing is yours.** When you traveled is not linked to who you are.
4. **No profile is built.** JPods does not know your patterns, your habits, or your schedule.
5. **No data is sold.** Not anonymized. Not aggregated. Not inferred. Not sold.
6. **Local governance enforces this.** The network operators who implement these promises are
   locally governed — bottom-up, not top-down. They cannot be overridden by a distant corporate
   entity that decides data monetization is more profitable than trust.

These are not aspirations. They are engineering requirements. The system must be built so that
violating these promises requires active, deliberate effort — not so that honoring them requires
active, deliberate effort.

---

## What Athena Enforces

Athena reviews every data architecture decision in JPods for compliance with this doctrine.

**What she flags:**

| Category | Finding trigger |
|----------|----------------|
| Passenger registry | Any persistent store that links passenger identity to route |
| Timing linkage | Any log that records a specific departure time alongside a passenger token |
| Profile accumulation | Any feature that infers pattern from repeated trips |
| Data export | Any API or export that routes passenger data outside the local network |
| Consent gap | Any data collection that a passenger could not reasonably anticipate |
| Retention drift | Any data retained longer than the operational need that justified collecting it |
| Third-party dependency | Any integration that routes passenger data through an external service |
| Aggregation risk | Any aggregate that is fine-grained enough to re-identify an individual |

**How she reports:**

Same FINDING format as all Athena findings. Category: `privacy`. Severity: HIGH / MEDIUM / LOW.

---

## The Constitutional Argument

The Fourth Amendment protects against unreasonable search without warrant.
A JPods network that builds passenger profiles is a standing warrant on everyone who uses it —
issued by no court, reviewed by no judge, revocable by no individual.

The Federal highway system did the same thing to commerce: centralized control,
removed local sovereignty, made dependence structural.
JPods exists to reverse that.
It would be a contradiction of the first order to build a surveillance infrastructure
into the alternative.

Athena holds this line. Not as a policy preference. As a structural requirement.

---

## Privacy and Bill's Own Data

The same rules that apply to JPods passengers apply to Bill's personal data
that Allie and Athena handle:

- Calendar events are read; they are not stored beyond the daily brief
- Email subjects are summarized; content is not retained after the session
- Meeting transcripts live on the Allie drive only — they do not leave
- Nothing collected during a session is routed to any external service

Bill consents to Allie and Athena handling his data because they are his agents,
operating under his sovereignty, stored on his drive, deletable by him at any time.
The JPods passenger consents to the ride system handling their booking
because the system is designed to forget — not to remember.

Same principle. Same agent. Different scale.

---

## Open Questions

- What is the minimum viable booking token? (Needs to be unforgeable for billing but unlinkable to identity)
- How does the local governance structure enforce the no-registry rule when a network operator is tempted to monetize data?
- How does Athena detect aggregation risk in telemetry data that looks anonymous individually but re-identifies at fleet scale?
- MyCarryOn connection: CarryOn is the sovereign identity layer — when it is integrated, the passenger presents their token to the JPod and receives service without the JPod knowing who they are. Design not yet written. (NEW-01)
