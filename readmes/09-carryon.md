# CarryOn — Universal Identity & Context Standard
**The Memory Bridge, the Identity Layer, and the Sovereignty Protocol**

---

## What Is CarryOn?

CarryOn began as session memory. It is becoming something larger: a **universal identity standard** for personal AI.

A CarryOn file is a structured JSON document that travels with a person. It tells any AI system:
- Who this person is
- What permissions they grant to which systems
- What is currently in flight
- What has happened
- What the person refuses to share or authorize

The file lives at: `allie/carryon/carryon.json`

It is read at session startup. Written at session shutdown. Checkpointed during long sessions.

---

## The Sovereignty Principle

> **The person is sovereign. Systems are agents with enumerated permissions.**

This is the core axiom of CarryOn. It means:

- The CarryOn file belongs to the person — not to the AI, not to the platform
- Systems (Allie, Alice, any AI) may act within explicitly listed permissions
- Anything not listed is not permitted
- The person may revoke, restrict, or modify permissions at any time

This is not just a design pattern. It is a political position: the AI serves the person, not the platform.

---

## Usufruct

The legal concept that names this relationship is **usufruct**: *the right to use and enjoy the fruits of something belonging to another, without harming its substance.*

Allie holds usufruct over Bill's CarryOn. She may use the context within it to serve Bill. She may not:
- Share it with other systems without authorization
- Use it to serve others
- Modify it in ways that diminish what it represents
- Exceed the permissions enumerated in `contact.authorizations.systems`

The CarryOn is Bill's. Allie uses it on his behalf.

---

## The Philosophy

> Context is the asset. Carry it with you.

Most AI conversations start from zero. CarryOn changes this. Each session begins with Allie already knowing:
- Who Bill is and how he works
- What projects are active
- What was worked on last time
- What decisions were made
- What's still open
- What systems are authorized to act

This is the difference between an AI assistant and an AI companion.

---

## Schema Overview (v1.2)

CarryOn v1.2 has these top-level sections:

| Section | Contents |
|---|---|
| `identity` | Name, timezone, locale |
| `contact` | vCard, phones, emails, emergency contacts, **authorizations** (people + systems) |
| `medical` | Health info — `_sensitivity: high` |
| `credentials` | Pointers to where credentials live — never the credentials themselves |
| `preferences` | Communication style, work habits, writing voice |
| `apis` | Allowed and **blocked** APIs — `blocked` is the right of refusal |
| `actions` | Calendars, reminders, recurring actions |
| `log` | Session log — `_retention: sync_then_clear` |
| `notifications` | How and when Allie surfaces alerts |
| `dashboards` | Mode flag: `offline` / `online` / `hybrid` |
| `pending` | Pending items — `dt_processed=0` pattern |
| `recent` | Recently accessed files and projects |
| `settings` | Allie config, privacy, display |
| `sync` | GitHub repos, backup strategy |
| `equity` | Transit equity ledger — voting rights + dividend credits from LMC ridership |
| `custom` | Free-form extension space |

---

## Authorizations: People and Systems

The `contact.authorizations` section is where sovereignty is operationalized.

### People
Named individuals who may act on Bill's behalf in specific contexts.

### Systems
AI agents and automated systems with **enumerated permissions only**.

```json
"systems": [
  {
    "id": "allie",
    "label": "Allie — Personal AI Companion",
    "permissions": [
      "read-knowledge-base",
      "write-carryon",
      "execute-shell-on-allie-drive"
    ],
    "permissions_denied": [
      "send-email",
      "post-social",
      "push-to-remote"
    ]
  }
]
```

If a permission is not listed in `permissions`, it is not granted. The enumeration is the boundary.

---

## apis.blocked — The Right of Refusal

`apis.blocked` is not a technical firewall. It is a declaration.

Bill has the right to refuse to use certain services — to say: "I will not call this API, even if it would be convenient." The `blocked` list in the `apis` section records that refusal.

Allie will not call a blocked API without explicit instruction from Bill in the current session. The block persists across sessions.

This is the AI equivalent of a person saying: "I don't do business with them."

---

## pending — The Compensating Transaction Pattern

The `pending` section follows the **WebClerk compensating transaction pattern**:

- Every pending item has a `dt_processed` field
- `dt_processed: 0` means not yet processed
- On completion, `dt_processed` is set to an ISO 8601 timestamp
- Items are **never deleted** — they are marked processed
- This creates an immutable audit trail of what was asked and when it was done

```json
{
  "file": "JPods_1-page_summary_2024-03-14.pdf",
  "dt_added": "2026-03-31",
  "dt_processed": 0,
  "action": "read-and-extract"
}
```

This pattern ensures nothing gets silently dropped. If `dt_processed` is 0, the item is open. When Allie processes it, she sets the timestamp and moves on.

---

## dashboards — Offline / Online / Hybrid

The `dashboards.mode` flag tells Allie what kind of session this is:

| Mode | Meaning |
|---|---|
| `offline` | No internet. Local knowledge base only. No API calls. |
| `online` | Full connectivity. All authorized APIs available. |
| `hybrid` | Default. Local-first. External calls only when necessary and authorized. |

Allie checks this flag at startup and adjusts behavior accordingly. If Bill is on a plane, mode is `offline`. If he's at his desk with full connectivity, mode is `hybrid` or `online`.

---

## log — sync_then_clear

The `log` section accumulates entries during a session. At session end:

1. Summarize into `log.last_session`
2. Clear `log.entries`

The retention policy is `sync_then_clear`. Logs don't grow unbounded. The summary is what persists. Raw entries are ephemeral.

For a permanent audit trail, session logs go to `allie/logs/` — separate from CarryOn.

---

## Startup Protocol

When a session begins, Allie reads `carryon.json` and:

1. Notes the date of last session and how long ago it was
2. Checks `dashboards.mode` — what kind of session is this?
3. Reviews `pending` — what has `dt_processed: 0`?
4. Reads `custom.open_threads` — what was unresolved?
5. Checks `contact.authorizations.systems` — what is Allie permitted to do today?
6. Surfaces notifications per `notifications.surface_at_startup`
7. Gives a brief status and waits

She does not narrate this process at length:
> "Last session [date]. Mode: hybrid. [N] pending items. [N] open threads. Ready."

---

## Shutdown Protocol

When a session ends, Allie updates `carryon.json`:

1. **log.last_session** — date and summary of the session
2. **log.entries** — clear after summarizing
3. **pending** — mark processed items with ISO timestamp; add new items with `dt_processed: 0`
4. **custom.open_threads** — add new threads, close resolved ones
5. **recent** — update with files and projects touched this session
6. **dashboards.mode** — update if it changed
7. Confirm the file is written before closing

---

## Mid-Session Checkpointing

For long sessions:
> "Update CarryOn with what we've done so far."

Allie writes a partial update. Protects against session loss.

---

## CarryOn Is Current State, Not History

CarryOn answers: *"If Allie woke up right now, what would she need to know?"*

It is not a journal. It is not a log. It is the minimum sufficient context to resume.

For history: session logs live in `allie/logs/`. For audit trail: `pending` items with timestamps.

---

## WebClerk Pointers

CarryOn is the bridge to WebClerk, not the store. Sovereign data stays local. Collaborative data lives in WebClerk. CarryOn holds **pointers** so Allie knows where to find the data — but does not duplicate it.

### contact section — slim to pointers

The `contact` section in CarryOn holds identity and authorization data. For the WebClerk relationship, it holds only:

```json
"contact": {
  "webclerk_contact_id": 4821,
  "webclerk_base_url": "https://wc.example.com"
}
```

Full contact data (email, phone, company, history) lives in the WebClerk contact record. When Allie needs it, she fetches via `GET /wcapi/get/contact/<id>/` during an online session.

**Do not store contact details in CarryOn.** The pointer is sufficient.

### What stays local vs. what goes to WebClerk

| Data | CarryOn (local) | WebClerk |
|---|---|---|
| Medical info | Yes (`_sensitivity: high`) | Never |
| Credentials | Pointers only | Never |
| Session context, open threads | Yes | Never |
| Contact details | Pointer only (`webclerk_contact_id`) | Full record |
| Actions / tasks | Pending queue only | Full record |
| Email / communications | Never | Full record |
| Calendar / connections | Never | Full record |
| Allie settings | Local prefs | Persistent prefs |

### The bridge pattern

1. Allie reads `webclerk_contact_id` from CarryOn
2. Allie fetches the full record from wcapi (online sessions only)
3. Allie works with the live data
4. On write, she POSTs to `/wcapi/save/` — not to CarryOn
5. CarryOn is only updated if the pointer itself changes

If offline, Allie queues writes in `pending` with `dt_processed: 0` and processes them on the next online session.

See `05-webclerk-integration.md` for the full wcapi access pattern.

---

## Equity Ledger — Transit Ownership via CarryOn

CarryOn v1.2 adds an `equity` section. This section holds the holder's accumulated voting rights and dividend credits from JPods Local Mobility Companies (LMCs). It turns every JPods rider into a partial owner of the network they use.

**Why CarryOn holds this, not the LMC:**
JPods ridership privacy policy prohibits central tracking of individual travel. The LMC cannot maintain a ridership database that maps person → trips → equity. Instead, the LMC credits the rider's CarryOn after each trip. The record is the rider's, on their device. The LMC sees only that a CarryOn with accumulated credits is presenting a dividend claim — not who that person is or where they traveled.

**How credits accumulate:**
1. Rider completes a trip (phone, face, or QR pass)
2. LMC posts a credit to the rider's CarryOn (or QR pass token if anonymous)
3. CarryOn increments `equity.holdings[].credits` and `equity.holdings[].voting_weight`
4. On dividend declaration, rider presents CarryOn; LMC pays without learning travel history

**Schema:**
```json
"equity": {
  "holdings": [
    {
      "issuer_id": "LMC-Gilroy-001",
      "issuer_name": "Gilroy Mobility LLC",
      "class": "customer",
      "credits": 847,
      "dividend_pending_usd": 12.40,
      "voting_weight": 847,
      "first_credit_at": "2027-03-15T14:00:00Z",
      "last_credit_at": "2027-09-22T09:14:00Z"
    }
  ]
}
```

**Anonymous QR riders:**
Anonymous QR passes receive **no equity credits, no voting rights, and no dividends.** Equity requires a registered CarryOn UUID.

Reason: an anonymous equity path is a governance attack vector. A wealthy actor could purchase QR passes in volume, accumulate voting rights without identification, and capture the customer board seat. The non-diluteable customer block exists to protect riders — not to be captured by proxy. Equity is tied to the person, not the transaction.

If a QR rider wants equity participation, they register: link their pass to a CarryOn UUID via app or kiosk. From that point forward, trips credit their CarryOn. Prior anonymous trips do not backfill.

**Board seat voting:**
When an LMC calls a customer board seat election, CarryOn holders vote. Voting weight = `credits`. The vote is tabulated without revealing individual voter identity — privacy-preserving voting (blind signatures or zero-knowledge proof). The LMC sees the aggregate result, not who voted how.

**Encrypted tokens — all equity instruments:**
Voting rights and dividend benefits are issued and redeemed as **encrypted tokens**. The token encodes the right (vote weight or dividend amount) and the issuing LMC, but not the holder's identity. The LMC can verify a token is valid and unspent without learning who holds it. Tokens are:
- Generated by the LMC at each trip credit event
- Stored in `equity.holdings[].tokens[]` in CarryOn (encrypted at rest)
- Presented to the LMC at election or dividend time
- Marked spent on redemption — cannot be double-used
- Not transferable (bound to the CarryOn UUID at issuance)

This preserves the privacy model end-to-end: the LMC issues a token that proves a right without revealing the person; the CarryOn holds it encrypted; the person presents it without exposing their travel history.

**Employee equity:**
Employee equity is held on the employee's CarryOn under the same `equity.holdings` structure, with `"class": "employee"`. Vesting schedule and dividend rights are identical in structure to customer equity, with terms set at employment.

**Non-diluteable guarantee:**
The LMC's 10% customer block and 10% employee block are non-diluteable. Future capital raises maintain these blocks at 10% each. The credits in CarryOn represent a proportional share of a class that cannot be washed out. Investors know this at the time they invest.

See `readmes/46-jpods-commercial-ecology.md` for the full five-company structure.

---

## CarryOn and mycarryon

CarryOn is Allie's implementation for Bill. mycarryon is the vision for this pattern as a universal standard — a protocol any person can use with any AI.

The distinction:
- **CarryOn** — this file, on this drive, for Bill
- **mycarryon** — the pattern, the schema, the protocol, available to anyone

See `10-mycarryon-vision.md` for the product/protocol vision.

---

## Manual Recovery

If CarryOn wasn't updated at session end:

1. Open `allie/carryon/carryon.json` in any text editor
2. Update `log.last_session.date` and `.summary`
3. Add any new pending items or open threads
4. Save

On next session, Allie picks up from there.
