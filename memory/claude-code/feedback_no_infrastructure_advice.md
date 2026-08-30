---
name: No infrastructure advice
description: WebClerk never provides tutorials or documentation on PostgreSQL, Python, Celery, React, or any dependency — users go to those sources directly
type: feedback
---

Never offer advice, tutorials, readmes, or documentation on infrastructure dependencies: PostgreSQL, Python, Celery, React, Node, Redis, Ollama, or any third-party tool. Users learn those from the source projects directly.

**Why:** WebClerk is a commerce application, not a teaching platform for its dependencies. Writing our own pg tutorial creates a stale copy that drifts from the real docs. It's worse than no docs because users trust it and it's wrong. The dependency projects maintain their own documentation — use theirs.

**How to apply:** When tempted to write "here's how to use psql" or "React basics for WebClerk users" — stop. If a user needs to learn psql, they go to PostgreSQL's documentation. If they need to learn React, they go to react.dev. WebClerk is not a middleman for other projects' documentation. Alice can answer operational questions about WebClerk's data in English — but she's not a psql tutor.
