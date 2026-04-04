# mycarryon — Product Vision
**Personal AI Context Portability**

---

## The Insight

Every person who uses AI for serious work runs into the same wall: **context doesn't travel**.

You build up a productive working relationship with an AI over a session. You've established who you are, what you're working on, how you think. Then the session ends. The next session, you start over.

The platforms know this is a problem. Their solutions — cloud memory, persistent threads, account-linked profiles — all have the same flaw: your context lives in their system, not yours.

mycarryon is the alternative.

---

## The Name

*Carry on.* As in luggage you take with you. As in continuing forward. As in: your context, in your bag, always with you.

A carryon is yours. You don't check it. You don't hand it to the airline. You keep it.

---

## The Product Concept

mycarryon is a personal AI context file — a structured document that travels with you and works across AI systems.

**What it contains:**
- Who you are (role, focus, preferences)
- What you're working on (active projects, current status)
- What's open (unresolved questions, pending decisions)
- What you know (pointers to your knowledge base)
- How you work (communication preferences, working style)

**What you do with it:**
- At the start of an AI session, load your carryon
- The AI reads it and knows you — immediately
- At the end of the session, update it
- Tomorrow, pick up where you left off

**Where it lives:**
- On your own drive — not in the cloud
- In a format you can read and edit
- Portable across AI systems and platforms

---

## Two Products, Two Audiences

### mycarryon.io
**For the serious knowledge worker.**
The full personal AI companion kit. External drive. Structured knowledge base. CarryOn protocol. Startup/shutdown rituals. Built for people who do serious work with AI and want their context to be their own.

Target: consultants, researchers, writers, founders, professionals who use AI daily

### mycarryon.ai
**For the AI-native user.**
A lighter-weight entry point. A CarryOn file generator and manager. Less about the full drive architecture, more about the context portability protocol. Works with any AI.

Target: AI power users who want context portability without the full kit

---

## Infrastructure & Deployment

### Domains
Both domains are owned and controlled by Bill James:
- **mycarryon.io** — primary product site (serious knowledge worker audience)
- **mycarryon.ai** — protocol/technical audience variant

### GitHub Repositories
Source code and site content live under the JPods GitHub organization:
- **mycarryon.io** → `github.com/JPods/mycarryon`
- **mycarryon.ai** → `github.com/JPods/mycarryon-ai`

Both repos deploy via **GitHub Pages** (current hosting).

### DNS Configuration
A records point both apex domains to GitHub Pages IPs:
```
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```
CNAME record for `www` subdomain:
```
www  CNAME  jpods.github.io
```

### Hosting Roadmap
- **Now:** GitHub Pages — free, simple, sufficient for static landing pages
- **Later:** Hostinger — when dynamic features, email, or more control is needed

---

## The Protocol Vision

Long-term, mycarryon could be a protocol — a standard format for personal AI context that any AI system can read and write.

Like RSS for feeds. Like vCard for contacts. A CarryOn file is a `carryon.json` — open format, human-readable, tool-agnostic.

Imagine:
- ChatGPT reads your carryon at session start
- Claude reads your carryon at session start
- Gemini reads your carryon at session start
- They all know who you are. You never start from zero.

The file is yours. The format is open. The context travels.

---

## What mycarryon Is Not

- Not a memory feature on a platform you don't control
- Not a sync service that stores your data in the cloud
- Not a subscription that can be revoked
- Not an AI product that requires you to trust another company with your context

---

## Current Status (2026-03-31)

mycarryon exists as:
- A working implementation (Allie, on this drive)
- Two landing page drafts (see `knowledge/writing/mycarryon-io/` and `knowledge/writing/mycarryon-ai/`)
- Two GitHub repos under JPods org (not yet pushed)
- Two owned domains with DNS configured for GitHub Pages
- A documented protocol (`09-carryon.md`)
- A vision document (this file)

Next steps:
- Push `knowledge/writing/mycarryon-io/` to `github.com/JPods/mycarryon` and enable Pages
- Push `knowledge/writing/mycarryon-ai/` to `github.com/JPods/mycarryon-ai` and enable Pages
- Decide: product, protocol, or essay?
- If product: define MVP, pricing, launch path
- If protocol: write spec, publish, evangelize
- If essay: write the definitive piece on personal AI context sovereignty

---

## The Bigger Picture

mycarryon sits at the intersection of two ideas:

1. **Personal AI sovereignty** — your data, your context, your AI
2. **Context as infrastructure** — the idea that accumulated context is the most valuable thing you build with an AI over time

Whoever solves context portability wins the trust of serious AI users. Most companies will solve it by locking it in. mycarryon solves it by setting it free.

---

## Connection to Digital Sovereignty

mycarryon is one implementation of a broader philosophy: digital sovereignty. The idea that individuals — not platforms — should own and control their digital lives.

See `knowledge/writing/digital-sovereignty/` for the full essay.
