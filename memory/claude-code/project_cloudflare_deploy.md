---
name: MeshMobility CloudFlare deployment
description: Serving MeshMobility via CloudFlare; webclerk.com already on CF; markmystation concept; tunnel login started 2026-07-07
type: project
---

**Status as of 2026-07-07:**
- webclerk.com already on CloudFlare
- `cloudflared tunnel login` initiated but browser auth pending
- Plan: serve MeshMobility publicly for network design + Noelle estimation

**MarkMyStation concept:**
- Users enter email, confirm, place markers where they want JPods stations
- Wisdom of the Many — no committees, just pins on a map
- Confirmed emails become Alice's first customer list per city
- Pin density becomes the third overlay (pedestrian/mobility demand)
- Multiple domain names (markmystation, etc.)

**Architecture:**
- Static frontend (HTML/JS/CSS) on CloudFlare Pages
- Python backend (Flask API) on VPS behind CloudFlare CDN, or Workers with Python
- .jpd files self-contained — no server state for viewing
- Noelle saves copy to server library; Alice creates Document record in WC3

**Why:** WC3 stores paths, never files. Document record points to library file. Files sovereign to their location. Security scanning at file system level.
