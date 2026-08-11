---
name: Flight simulators for training
description: Interactive training windows that walk users through business flows step-by-step, showing data changes at each stage
type: feedback
---

Call interactive training windows "flight simulators" — Bill's term. These are step-by-step walkthrough UIs where the user performs real actions (create proposal, convert to order, etc.) and watches the data change at each stage. The first one is the inventory flow trainer: user watches pending records form and resolve as transactions flow through the system.

**Why:** Users need to understand WHY pending records exist and HOW inventory flows work. Reading documentation doesn't teach this — doing it while watching the data change does.

**How to apply:** When building any training/teaching UI, use the flight simulator pattern: guided steps, real actions, visible data changes. Name them "Flight Simulator: [domain]" in the UI.
