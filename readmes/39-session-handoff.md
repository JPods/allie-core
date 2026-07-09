# Session Handoff Protocol
**Last updated:** 2026-04-29
**Status:** Active — Claude Code writes at session end; Allie reads at session start

The handoff is a one-page briefing that closes the context gap between Claude Code sessions.
Claude Code writes it; Allie reads it and briefs Bill when he starts the next session.

Without a handoff, every session reconstructs context from the summary mechanism — which is
passive and lossy. The handoff is active and opinionated: it says exactly what to do next
and why.

---

## File Location

`/Users/williamjames/Allie/today/handoff.md`

One file. Overwritten at each session end. Allie archives the previous one to
`/Users/williamjames/Allie/today/handoff-YYYY-MM-DD.md` before overwriting.

---

## What Claude Code Writes

```markdown
# Handoff — YYYY-MM-DD

## Where We Left Off
One paragraph. What was the last thing completed. What state it is in.
Specific file path and line number if relevant.

## Do This First Next Session
Numbered list. Maximum 5 items. Most important first.
Each item: what to do, which file, why it matters.

1. Test the dispatch flow: start SketchUp, load plugin, run seed_jpods_demo,
   open /jpods/trip/, select Adult → S097 → S098 → Travel. Watch Ruby console.
   If platform_guideways is empty, run the platform recovery protocol (readme 29 step 3).

2. ...

## Open Problems
Bullets. Things that are known broken or incomplete.
- dispatch_server.rb: NORA_DISPATCH_1 must exist in the model — spawn manually first.
- MeshMobility travel time: requires sim to have been run for the O-D pair.

## What Was Decided (and Why)
Bullets. Non-obvious architectural decisions made this session.
Do not list obvious things. Only record what future-Claude might reverse without knowing.
- dispatch_server uses a Queue + UI.start_timer pattern (not direct model calls from WEBrick
  thread) because SketchUp's model API is not thread-safe.
- Port 5051 for SketchUp WEBrick; 5050 is MeshMobility — do not swap.

## Files Changed This Session
Brief list — path and one-line description.
- apps/jpods/services/dispatch.py — fire-and-log dispatch router (sketchup/route-time/physical)
- JPods/dispatch_server.rb — WEBrick on 5051, queued main-thread trip handler
- readmes/37-jpods-sketchup-dispatch-server.md — WEBrick integration doc
- readmes/38-talents.md — talent system for Claude Code and Allie
```

---

## What Allie Does With It

At the start of a new session (or when Bill asks "where did we leave off"):

1. Read `today/handoff.md`
2. Brief Bill in plain language — not a recitation, a briefing
3. Flag the first item on "Do This First" as the suggested starting point
4. If the handoff is more than 3 days old, note that it may be stale

Allie does not modify the handoff. She archives it and waits for Claude Code to overwrite it.

---

## When Claude Code Writes the Handoff

At any natural session end — when Bill indicates he is stopping, when a major milestone
is complete, or when the context approaches the summary threshold.

The retrospection (`retrospections/YYYY-MM-DD.md`) records what was done.
The handoff (`today/handoff.md`) says what to do next.
They serve different purposes. Both should be written.

---

## This Session's Handoff

# Handoff — 2026-04-29

## Where We Left Off

Built the complete JPods Alice trip API and browser phone app, then wired the SketchUp
dispatch server. The dispatch pipeline is:

```
Phone app (trip_app.html)
  → Django TravelView (views_ui.py)
    → Alice invoice (invoice_service.py)
    → dispatch.py → port 5051
      → dispatch_server.rb (WEBrick)
        → Natalie.route → trip record → start_animation
```

The Ruby code (`dispatch_server.rb`) is written and loaded in `main.rb`.
It requires SketchUp to have run `start_animation` once first (to generate followme.json).
SketchUp was having line-connection issues during the session — not yet fully resolved.

## Do This First Next Session

1. **Test the SketchUp line connections.** Recompute CPs, re-export FollowMe, check
   that `platforms[]` is non-empty in the resulting `.followme.json`. If empty, follow
   the platform recovery protocol in retrospection 2026-04-29.

2. **Test the full dispatch flow.** Start SketchUp, load plugin, open Ruby console.
   Run `seed_jpods_demo --reset` in Django. Open `/jpods/trip/`, select Adult → S097 → S098 → Travel.
   Watch Ruby console for `[JPods DispatchServer]` output.

3. **Spawn NORA_DISPATCH_1.** Before the dispatch test, ensure a pod component with
   `vehicle_id = NORA_DISPATCH_1` exists in the SketchUp model at station S097.
   If not, add it via the deploy tool or manually set the attribute.

4. **Build `/retrospection` skill.** Now that the talent system is documented (readme 38),
   the highest-ROI next talent is the retrospection skill so it is never skipped.

5. **Build session handoff as a Claude Code skill** (this file documents the protocol;
   the skill automates writing it).

## Open Problems

- `dispatch_server.rb` fallback nora_id is `NORA_DISPATCH_1` — must exist in model.
- SketchUp line connection issue during this session — `platforms[]` was empty;
  platform recovery protocol documented in retrospection 2026-04-29.
- WEBrick may not be available in all SketchUp Ruby runtimes — `dispatch_server.rb`
  now degrades gracefully if `require 'webrick'` fails.
- MeshMobility travel time in confirmation box requires a prior simulation run for the O-D pair.
- Physical dispatch (Natalie inbound API on RPi) is a placeholder — no implementation.

## What Was Decided (and Why)

- **dispatch_server uses Queue + UI.start_timer** — SketchUp's model API is not thread-safe;
  WEBrick runs on a background thread; all model calls must be deferred to main thread.
- **Port 5051 for WEBrick** — 5050 is MeshMobility Flask; never swap.
- **Item-based pricing** (not custom model) — trips flow through standard WC3 Item/Invoice
  stack; no new model needed; every trip is a full transaction record.
- **fire-and-log dispatch** — dispatch failure never cancels the invoice;
  Alice's record is authoritative.
- **myCarryOn token in contact metadata** — stable token per contact,
  stored in `contact.metadata["myCarryOn"]["token"]`; no separate auth model.

## Files Changed This Session

- `apps/jpods/models.py` — emptied (Item model replaces JpodPricingRule)
- `apps/jpods/services/pricing.py` — Item-based price lookup
- `apps/jpods/services/invoice_service.py` — Invoice + InvoiceLine with item_fk
- `apps/jpods/services/dispatch.py` — fire-and-log dispatch router
- `apps/jpods/views_ui.py` — ContactsView, IdentifyView, StationsView, UIPriceView, TravelView
- `apps/jpods/templates/jpods/trip_app.html` — mobile trip booking app
- `apps/jpods/urls.py` — ui/* endpoints + /jpods/trip/ route
- `apps/jpods/management/commands/seed_jpods_demo.py` — Items, myCarryOn contacts
- `route_time/gui/api.py` — POST /api/trip/dispatch endpoint
- `JPods/dispatch_server.rb` — WEBrick on 5051, queued main-thread handler
- `JPods/main.rb` — added dispatch_server to load list
- `readmes/35-jpods-alice-trip-api.md` — updated for Item model
- `readmes/36-jpods-dynamic-pricing-load-balancing.md` — new
- `readmes/37-jpods-sketchup-dispatch-server.md` — new
- `readmes/38-talents.md` — new (talent system)
- `readmes/39-session-handoff.md` — new (this protocol)
- `readmes/design-tokens.json` — new (shared UI design tokens)
