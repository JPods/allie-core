---
name: Allie hardware — GEEKOM IT15 hybrid architecture
description: GEEKOM IT15 ordered 2026-07-16 as always-on app server (PostgreSQL, WC3, MeshMobility, Chroma, 5TB). MacBook keeps Ollama/Allie LLM. Ubuntu Server 24.04.
type: project
---

**Hybrid architecture decided 2026-07-16.** GEEKOM IT15 (Intel Ultra 9 285H, 32GB DDR5 upgradeable to 128GB, 1TB NVMe, 2.5GbE) ordered — expected ~2026-07-20.

**Split:**
- MacBook Pro M1 Max: Ollama (allie:latest 20b), allie-reflect, allie-whatif, iCloud sync, Claude Code, SketchUp, MCP servers (stdio)
- GEEKOM IT15: PostgreSQL, Django/WC3, React servers, MeshMobility, Chroma (Alice+Noelle), 5TB drive (USB4, always mounted, NFS shared)

**Why:** Closing MacBook kills database, WC3, and MeshMobility. GEEKOM stays on 24/7 for those services. Ollama stays on MacBook because Apple Silicon unified memory runs the 20b model efficiently.

**OS:** Wipe Windows 11 Pro, install Ubuntu Server 24.04 LTS headless.

**Future:** Mac Mini M4 Pro (48GB) may eventually replace MacBook as Allie's LLM home. GEEKOM stays permanent as app server.

**How to apply:** Migration plan at readmes/55-mac-mini-migration.md. Setup begins ~2026-07-20.
