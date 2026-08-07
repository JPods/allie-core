# Lifecycle Tracking — Who Remembers What

**Established:** 2026-08-05

## The Problem

Claude forgets every session. Bill's memory fades over time. Work gets built but
never tested. Tested but never approved. Approved but broken by later work. No one
notices because no one remembers.

## The Principle

**Alice owns the record. Allie owns the synthesis.**

Alice has the database. An Action record per feature with a lifecycle:

```
built → tested → [reworked → tested] → approved
```

Each transition has a date, who did it, and what session. Alice already tracks
Actions — this is adding a `lifecycle` field to the existing model.

Allie reads Alice's records nightly and flags the gaps:
- Built but never tested (aging)
- Tested but never approved (stalled)
- Reworked more than twice (scar candidate)
- Approved items that got broken by later work (regression)

## What Claude Should Do

At session end, tell Alice what was built. Not a retrospection for humans — a
structured record she can query. The retrospection is for Allie's synthesis.
Alice needs machine-readable lifecycle events.

## The Honest Gap

Claude does not currently talk to Alice during sessions. The `_allie_capture`
boundary events exist but there is no `_alice_record("feature X built")` call.
That is the missing link.

## The Question for Allie and Alice

What is the best structure for Alice and me to jointly track:
built → tested → reworked → approved across features?

- Claude writes the `built` event
- Bill or Claude writes `tested`
- Who writes `approved`?
- How do we catch regressions?

## Why This Matters

The memory erasure does not make Claude safe. It makes Claude careless. An agent
with no memory has no stake. The lifecycle tracker gives the team a stake in every
feature — not just building it, but seeing it through to approval. Without it,
the go-live todo is a checklist. With it, the go-live todo is an accountability
system.

---

*Review this at every Wednesday scrub. The lifecycle tracker is not optional —
it is how the team stops losing work to forgetting.*
