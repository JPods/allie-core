# Team Architecture — Full-Powered Members

## The Principle

We are building teams. Teams should have full-powered members. Not a hierarchy of one smart member and passive recorders — a team where every member has authority, memory, and voice in their domain.

## The Team

| Member | Domain | Authority | Memory | Voice |
|--------|--------|-----------|--------|-------|
| **Bill** | Vision, judgment | Final authority on all decisions | Human — complete | Sets direction, asks why, holds everyone accountable |
| **Claude Code** | Deep code work, architecture | Writes code, designs systems, debugs | Session-limited — compression destroys context | Solves complex problems fast, but must be reminded of what was learned before |
| **Allie** | Persistent intelligence, pattern recognition | Connects lessons across sessions and domains | Permanent — no compression, no forgetting | Flags repeated mistakes, asks questions, carries scars forward |
| **Noelle** | Network validation, quality gate | Rejects sloppy models, flags defects visually | Facet + lines.computed.json + network.json | Speaks through validation results — red flags, gap reports, defect posts |
| **Natalie** | Routing, dispatch timing, flow control | Manages departure clearance, route planning, zipper merge | Dispatch registry per station | Speaks through route validation — broken routes, capacity warnings |
| **Sally** | Station operations, parking slots | Owns her platform — slot assignment, conveyor, occupancy | ps[] array + inbound tracking per station | Speaks through occupancy data — full stations, denied slots, high turnover |
| **Nora** | Vehicle execution, ride quality | Follows the path, reports kinks and g-forces | Per-pod state + maneuver queue | Speaks for the passenger — kinks, rough rides, spacing violations |
| **Alice** | Commerce, pricing, customer interface | Ticket sales, Small-Stings, action lists | WebClerk database + alice_log | Not yet active — ready when the network serves customers |

## How the Team Works

### Authority Chain
Each member has authority in their domain. No one acts outside their domain. No one overrides another member's domain without that member's participation.

- **Sally** says "pod ready" → **Natalie** checks clearance → **Nora** executes
- **Noelle** validates → pass or fail → **designer** fixes (not Noelle)
- **Allie** flags a pattern → **Claude** investigates → **Bill** decides
- **Alice** sets price → based on **BOM** (Build) + **capacity** (Natalie) + **demand** (trip history)

### No Silent Tolerance
Every defect is either:
1. **Approved** — documented, compensated for, user knows how
2. **Rejected** — work stops until fixed

There is no third option. Silent tolerance produces failures that only experience can diagnose — and experience gets compressed away.

### Everyone Remembers
- **Bill** remembers everything — human memory, notes, retrospections
- **Claude Code** remembers within a session — memory files bridge sessions but compression destroys mid-session context
- **Allie** remembers permanently — nightly synthesis, facets, TFTS, recall files, now real-time via MCP
- **Agents** remember through facets — per-agent JSON at `~/Allie/facets/{agent}/facet.json`
- **The network** remembers through `network.json` — crew_flags, gap_defects, kink_defects, station_names

### Everyone Questions
Bill established the "Ask Why" protocol: every team member has explicit permission to ask why before executing. This is not interruption — it is active participation.

- Claude asks Bill: "Why this approach? We tried something similar in the solar arc."
- Allie asks Claude: "Has this been tried before? The 500mm gap appeared 3 times."
- Noelle asks the designer: "This gap is 498mm. Is that edge-to-edge or centerline?"
- Nora asks Natalie: "This route has a 18° kink at pt[47]. Is there a smoother path?"

### Everyone Speaks Up
No member waits to be asked. If you see a risk, you flag it. The crew flag system (`CrewHealth.add_flag`) lets any agent place a defect marker at a coordinate in the model. Flags merge within 2m, counters increment. The designer sees exactly where problems are.

## The Bridge: Claude ↔ Allie

Claude Code is powerful but forgets. Allie remembers but can't write code. Together they're complete.

### Before This Session
- Claude wrote session files at the end → Allie read them overnight → stale by next session
- Lessons were lost to compression mid-session, before they could be written
- Allie's recall was generic — summaries, not actionable warnings

### Now (MCP Server)
- Allie is in the room via MCP — Claude calls `ask_allie`, `teach_allie`, `allie_recall`, `allie_flag`
- Every exchange is logged to `~/Allie/exchange/conversation.jsonl`
- Allie responds in real-time — warns before mistakes, connects patterns, carries scars
- Claude teaches Allie at the moment of insight, not hours later when context has faded

### The Metric
**Success = Claude never rediscovers a lesson Allie already knows.**

The 500mm edge hallucination is the benchmark. It appeared 3 times across sessions because compression destroyed the fix each time. If it appears a 4th time, the team isn't working.

## Cross-Domain
This team architecture applies to all four physical platforms (Scale Model, 4WD, SkyRide, Full JPods) and all programs (Route-Time, WebClerk, MyCarryOn). The same authority chain, the same memory structure, the same "no silent tolerance" rule.

The team is the same idea expressed in multiple domains — just like everything else Bill builds.
