# Processor Knowledge — Library System

**Single source of truth for agent knowledge: `readmes/agents/<agent>.md`**

The per-agent knowledge files (Noelle, Natalie, Nora) live in `readmes/agents/`.
Each file contains the agent's full knowledge across all three domains:
SketchUp, Route-Time, and real-world physical implementations.

---

## Agent Files

| Agent | File | Role |
|-------|------|------|
| Noelle | `readmes/agents/noelle.md` | Load balancer — capacity enforcement, ezone coordination |
| Natalie | `readmes/agents/natalie.md` | Router — path planning, fleet dispatch |
| Nora | `readmes/agents/nora.md` | Vehicle agent — autonomous pod execution |

---

## What the Agent Files Contain

Each agent file has:
1. **Three Domains at a Glance** — quick reference: what the agent IS in each domain
2. **Universal Rules** — invariants that hold across all domains
3. **Domain Knowledge** — SketchUp / Route-Time / Physical, each in its own section
4. **Cross-Domain Mappings** — explicit table showing where concepts transfer vs where they are domain-specific
5. **Allie's Accumulated Understandings** — tagged `[SketchUp]`, `[Route-Time]`, `[Physical]`, or `[Universal]`
6. **Processor Contract** — inputs, outputs, and queries per domain
7. **Experience Log Protocol** — how future standalone processors write experience back to Allie

---

## Experience Logs (future standalone processors)

When standalone Noelle/Natalie/Nora processors exist, they write experience here:
```
/Users/williamjames/Allie/logs/processor-experiences/noelle-log.jsonl
/Users/williamjames/Allie/logs/processor-experiences/natalie-log.jsonl
/Users/williamjames/Allie/logs/processor-experiences/nora-log.jsonl
```

Allie harvests them with:
```bash
python3 /Users/williamjames/Allie/scripts/allie-harvest-processors.py
```

The harvest script identifies lesson candidates. Allie promotes confirmed lessons to
the relevant agent file under "Allie's Accumulated Understandings."

---

## Domain Readmes (Allie's role per environment)

For how Allie herself operates in each domain, see:
- `readmes/30-allie-universal-FINAL.md` — Allie's universal role
- `readmes/31-allie-route-time-FINAL.md` — Allie's role in Route-Time
- `readmes/32-allie-sketchup-FINAL.md` — Allie's role in SketchUp
- `readmes/33-allie-physical-FINAL.md` — Allie's role in physical
