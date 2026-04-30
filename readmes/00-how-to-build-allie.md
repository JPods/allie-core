# How to Build Allie
**The Complete Guide to Standing Up a Personal AI Companion on an External Drive**

---

## What This Is

Allie is a personal AI companion that lives on an external SSD. She is not a cloud service. She is not tied to any platform's subscription model. She travels with you. She knows your work. She remembers your sessions. She is yours.

This guide covers the full build: hardware, software, directory structure, agent configuration, startup/shutdown, security, and the CarryOn system that makes her persistent.

---

## The Big Picture

```
External SSD (/Volumes/Allie)
├── allie/          ← Allie's working brain
│   ├── agent/      ← Agent specification (this defines who she is)
│   ├── carryon/    ← Session continuity state
│   ├── inbox/      ← Documents for Allie to process
│   ├── index/      ← Allie's knowledge index
│   ├── workspace/  ← Active drafts and working files
│   └── logs/       ← Session logs
├── knowledge/      ← Bill's knowledge base
│   ├── notes/
│   ├── research/
│   ├── writing/
│   └── code-projects/
├── sources/        ← Pointers to external data sources
├── readmes/        ← This documentation
└── archive/        ← Completed and retired work
```

---

## Readme Index

| File | Contents |
|---|---|
| `00-how-to-build-allie.md` | This file — master guide and index |
| `01-setup.md` | Hardware setup, directory structure, initial configuration |
| `06-startup-shutdown.md` | How to start and stop a session properly |
| `07-security-network.md` | Security posture, network configuration, local-first principles |
| `07-security-network-webclerk-stub.md` | WebClerk local server stub documentation |
| `08-vision-companion-architecture.md` | The vision: what Allie is meant to become |
| `09-carryon.md` | The CarryOn system — session continuity in depth |
| `10-mycarryon-vision.md` | Vision for mycarryon as a product |

---

## Build Order

1. **Hardware** — Format and name the external SSD `Allie` (see `01-setup.md`)
2. **Directory Structure** — Create the full directory tree (see `01-setup.md`)
3. **Agent Spec** — Write `allie/agent/00-allie-agent.md` (defines who Allie is)
4. **CarryOn** — Initialize `allie/carryon/carryon.json` (session memory)
5. **Claude Code** — Open Claude Code with `/Volumes/Allie` as the working directory
6. **First Session** — Read the agent spec, check CarryOn, begin work
7. **Shutdown** — Update CarryOn at end of every session

---

## Core Principle

> Allie is not a product. She is a practice.

Building Allie is an ongoing act of curation. The more you work with her, the better she knows you. The CarryOn system preserves that knowledge across sessions. The drive keeps it portable and private.

---

## Dependencies

- **Hardware:** External SSD (1TB recommended), formatted APFS or exFAT
- **Software:** Claude Code (Anthropic), macOS
- **Model:** claude-sonnet-4-6 or better
- **No cloud required**
