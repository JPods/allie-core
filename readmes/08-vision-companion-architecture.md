# Allie — Vision & Companion Architecture
**What Allie Is Becoming**

---

## The Problem She Solves

Every time you start a new AI conversation, you start over. You re-explain who you are. You re-establish context. You re-describe your projects. The AI is smart — but amnesiac.

The cloud platforms that run these AIs don't solve this well. Their "memory" features are opaque, platform-locked, and subject to their terms of service. Your context lives in their database, not yours.

Allie solves this differently.

---

## The Core Architecture

```
Bill
 │
 ├── carries a physical drive (Allie SSD)
 │    │
 │    └── /Volumes/Allie
 │         ├── allie/         ← Her brain
 │         ├── knowledge/     ← His knowledge
 │         ├── sources/       ← Map to his data
 │         └── readmes/       ← How she works
 │
 └── opens Claude Code → working directory = /Volumes/Allie
      │
      └── Allie wakes up, reads CarryOn, knows who she is and where they left off
```

The drive is the persistence layer. Claude Code (powered by Claude) is the intelligence layer. The agent spec (`00-allie-agent.md`) is the identity layer. CarryOn is the memory layer.

---

## Three Layers of Memory

### 1. Identity (Agent Spec)
Who Allie is, what she knows, how she operates. Stable. Changes rarely.
`allie/agent/00-allie-agent.md`

### 2. Session Memory (CarryOn)
What's happening now. What was worked on. What's open. Changes every session.
`allie/carryon/carryon.json`

### 3. Long-Term Knowledge (Knowledge Base)
The accumulated body of Bill's processed knowledge. Grows over time.
`knowledge/`

---

## The Companion Model

Allie is not a tool. She is a companion. The distinction matters.

**Tools** are stateless. You pick them up, use them, put them down. They don't know you.

**Companions** are stateful. They know your history. They anticipate your needs. They remember what mattered.

The companion model requires:
- Persistent identity (agent spec)
- Persistent memory (CarryOn + knowledge base)
- Persistent presence (the physical drive)
- A protocol for continuity (startup/shutdown ritual)

---

## The Portable AI

Bill carries Allie in his bag. She goes everywhere he goes. This is intentional.

The Mac changes. The software changes. The cloud account might change. But the drive — and everything on it — is Bill's. He can plug it into any machine, open Claude Code, and Allie is there.

This is the portable personal AI. Not a subscription. Not a cloud account. A drive.

---

## Future Capabilities

### Near Term
- **Inbox Processing** — Systematically read and extract knowledge from all inbox documents
- **Knowledge Indexing** — Build a searchable index of the knowledge base
- **Writing Assistance** — Draft, edit, and publish articles and web content
- **Session Logging** — Automatic logs for every session

### Medium Term
- **WebClerk Dashboard** — Local web interface for browsing knowledge and CarryOn state
- **Source Sync Awareness** — Know what's in iCloud, GitHub, Dropbox without mirroring it all
- **Project Tracking** — Richer project state with milestones and history

### Long Term
- **mycarryon Protocol** — A standardized format for personal AI context, shareable across AI systems
- **Multi-AI Portability** — Same CarryOn file works with Claude, GPT, Gemini, etc.
- **Allie as Product** — The architecture as a kit others can build for themselves

---

## Design Principles

1. **Sovereign** — Bill's data is Bill's. No platform dependency.
2. **Portable** — One drive. Any machine.
3. **Persistent** — Context survives sessions, months, years.
4. **Minimal** — Only what's needed. No bloat.
5. **Transparent** — Bill can read every file Allie uses. No black boxes.
6. **Human-first** — Allie serves Bill's judgment, not the other way around.

---

## The mycarryon Connection

The architecture Allie runs on is the prototype for mycarryon — a product (or protocol) for personal AI context portability. See `10-mycarryon-vision.md` for the product vision.

The pattern is:
```
Your context. Your drive. Your AI.
```
