---
name: Session documents in WC3
description: Create a WC3 Document record at session end listing goals and results; images go to ~/Allie/sessions/images/YYYY-MM-DD/
type: feedback
---

At session end, create a WC3 Document record summarizing the session.

**Why:** Bill wants durable, searchable session history that survives Claude's memory reset. Handoff files are for the next session; Document records are for the team's permanent memory. Alice can search them, Allie can synthesize them, and any future session can query what was tried and what was achieved.

**How to apply:**
- Create a Document record via wcapi: `model_name=docs.Document`, `name="Session YYYY-MM-DD"`, text content in the record body (goals + results)
- Text data stays in the record — no external files for text
- If screenshots or images were captured during the session, save them to `~/Allie/sessions/images/YYYY-MM-DD/` and reference the path in the Document record
- Do not create the image folder if there are no images to store
- This is part of the rightshoe/session-end protocol, alongside handoff.md and retrospection
