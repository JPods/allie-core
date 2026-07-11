---
name: MeshMobility platform features — library, tokens, support
description: Next phase: network library (browse/clone/fork), user tokens for points, protected JPods_primary networks, for-fee support line; turns tool into platform
type: project
---

## MeshMobility Platform — Next Phase Features

Established 2026-07-10. These turn MeshMobility from a tool into a platform.

### 1. Network Library (`/library`)
- Browse networks already built (by city, by team, by score)
- Anyone can clone and modify a network, saving their own version (fork)
- Each save gets a unique URL: `meshmobility.com/library/{city}/{user}/{version}`
- Show score, structure count, coverage %, creator name, date
- Thumbnail map preview per network

### 2. Protected Networks
- `JPods_primary` networks are read-only for public — only authorized users can edit
- Authorization via token (see below)
- Clone creates a new copy under the user's token — original untouched
- JPods_primary networks are the "reference designs" for each city

### 3. User Tokens
- Simple token system — user creates an account (email + name), gets a token
- Token stored in browser localStorage, sent with API calls
- Points accumulate per token: designs saved, GPS surveys submitted, kits purchased, retrospections written
- Leaderboard on 10xMakers.com ranks by points
- Token is the seed for CarryOn identity when MyCarryOn is ready

### 4. For-Fee Support Line
- Paid support tier — "Get help designing your city's network"
- Alice handles the commerce (WebClerk)
- Could be live chat, scheduled video call, or async (submit question, get expert response)
- Revenue stream from day one — even before kit sales
- Pricing TBD: per-session ($50?) or subscription ($20/month?)

### 5. Landing Page Routes (established)
- `meshmobility.com` → landing page
- `meshmobility.com/app` → MeshMobility design tool
- `meshmobility.com/citytool` → CityTool
- `meshmobility.com/library` → network library (to build)

**Why:** The library + tokens + support creates the viral loop. Student designs a network → saves to library → shares link → friend clones it → improves it → Noelle learns from both. Points incentivize quality. Support generates revenue. Protected primaries ensure JPods' reference designs stay authoritative.

**How to apply:** Build library first (it's the most visible feature on the landing page). Tokens second (needed for save/clone/points). Support third (needs tokens for identity). All flow through WebClerk for commerce.
