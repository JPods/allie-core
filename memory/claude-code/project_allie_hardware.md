---
name: Allie + Alice hardware layout
description: Allie on MacBook; Alice runs 2 instances (Mac + Andi IT15 32GB Ubuntu); Hostinger VPS is shared DB only
type: project
---

**Hardware layout:**

| Agent | Machine | Notes |
|-------|---------|-------|
| **Allie** | MacBook Pro M1 Max | Ollama (allie:latest), allie-reflect, Claude Code, SketchUp, development |
| **Alice (dev)** | MacBook Pro M1 Max | Local instance for development |
| **Alice (prod)** | GEEKOM IT15 32GB Ubuntu ("Andi") | Always-on; runs WC3, React, MeshMobility, Chroma, Ollama, PostgreSQL, Redis, Nginx, Cloudflare tunnel |

**Hostinger VPS** (`76.13.185.210`, $155/yr, expires 2026-09-16): shared PostgreSQL for external access only. Does not run Alice or Allie. September 2026 renewal decision pending.

**Old VPS** (`85.31.234.194`): was Hostinger, now cancelled or under Antor's account. References in code are dead — clean up.

**Andi is also the product:** each business gets their own box with Andi pre-installed. Desktop Hosting realized. Opt-in sharing via CarryOn sovereignty model.

**How to apply:** `ssh andi` from Mac. Deploy via `deploy-wc3`, `deploy-mm`, `deploy-react` aliases. Full setup at readmes/61-it15-setup-log.md.
