---
name: Allie hardware — MacBook + IT15 (Andi) split
description: MacBook runs Ollama/Allie/Claude Code/SketchUp; IT15 (Andi) runs WC3, MeshMobility, Chroma, PostgreSQL always-on; deployed 2026-07-21
type: project
---

**Deployed 2026-07-21.** GEEKOM IT15 running as "Andi" — always-on app server.

**Split:**
- MacBook Pro M1 Max: Ollama (allie:latest), allie-reflect, Claude Code, SketchUp, development
- IT15 (Andi): WC3, React frontend, MeshMobility, Chroma, Ollama (deepseek-r1:8b), PostgreSQL, Redis, Nginx, Cloudflare tunnel

**Andi is also the product:** Each business gets their own box (Mac Mini, IT15, etc.) with Andi pre-installed. Desktop Hosting realized. Opt-in sharing with Allie via CarryOn sovereignty model.

**How to apply:** `ssh andi` from Mac. Deploy via `deploy-wc3`, `deploy-mm`, `deploy-react` aliases. Full setup at readmes/61-it15-setup-log.md.
