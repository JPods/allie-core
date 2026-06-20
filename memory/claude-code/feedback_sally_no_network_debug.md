---
name: Sally parking — no network-level debugging
description: Sally parking bugs must be fixed at the template (su_jpods/model) level; network-level debugging is rejected
type: feedback
---

Sally parking bugs are fixed at the **su_jpods/model (template) level**. Debugging Sally parking at the network level is directly rejected.

When a Sally parking problem appears, the correct response is:
1. Identify the misbehaving station template
2. Open that template's model.skp
3. Run station tests from Console → Models tab (platform_shuffle, departure_test, arrival_test)
4. Fix in lines.json, jpod_sally.rb, or the station test runner
5. Pass all station tests before touching the network

**Why:** Never accept a proposed network-level debug path for Sally. Route any such proposal back to the template level immediately.

**Why:** Network builds composite state from all templates at once. A parking bug at the network level looks like a routing problem, a Natalie problem, a timing problem — everything except what it is. Station tests isolate Sally to one template, one ps count, one chain definition set. The root cause is only visible there.

**How to apply:** If asked to investigate Sally parking behavior in a full network build, decline and redirect: "Sally parking is debugged at the template level. Which station template? Open its model.skp and run the station tests."

Full reference: `su_jpods/readmes/sally-behaviors.md` (Hard Rule section at top of file).
