# WC3 Connection Classes

**Created:** 2026-08-09
**Seed command:** `./manage.py seed_connections [--force]`

---

## What WC3 Is and Is Not

| WC3 IS | WC3 IS NOT |
|--------|------------|
| CRM — via Actions and Contacts | HR / payroll |
| Project management — nested projects, kanban sprints | Checkbook / payables |
| Commerce — orders, invoices, inventory, pricing | P&L / balance sheet |
| GL journal entry producer | Accounting program |
| Record-keeping engine | Payment processor (delegates to Stripe/Square/PayPal) |
| Served via Cloudflare + nginx + Django + React | Cloud-dependent (runs local on Mac Mini / IT15) |

**Boundary rule:** WC3 produces clean, double-entry-ready GL journal entries from production data (sales, payments, inventory). Accounting programs consume them. Payable feedback (purchase receipts) imports back for landed cost tracking.

---

## Connection Classes — Summary

| Class | Connections | Type | Purpose | Status | Flowchart |
|-------|------------|------|---------|--------|-----------|
| **Internal** | alice-claude, wchq-upstream, self | internal | sync | Active | `wc3-conn-internal.dot` |
| **Deploy** | Local Server (Andi) | api | deploy | Draft | `wc3-conn-deploy.dot` |
| **Shipping** | UPS, FedEx, USPS, DHL | api | sync | Draft | `wc3-conn-shipping.dot` |
| **Tax** | Avalara / TaxJar / Vertex | api | sync | Draft | `wc3-conn-tax.dot` |
| **Communication** | Gmail, Outlook | api | sync | Draft | `wc3-conn-communication.dot` |
| **Calendar** | Google Calendar, Outlook Calendar | api | sync | Draft | `wc3-conn-calendar.dot` |
| **Payment** | Stripe, Square, PayPal | api | sync | Draft | `wc3-conn-payment.dot` |
| **Accounting** | QuickBooks, Xero | api | export | Draft | `wc3-conn-accounting.dot` |
| **Banking** | Bank Feed Import (Statement Sorter) | manual | ingest | Draft | `wc3-conn-banking.dot` |
| **Identity** | MyCarryOn | api | sync | Draft | `wc3-conn-identity.dot` |

---

## Class Details

### Internal

Agent-to-agent communication within the WC3 ecosystem.

| Connection | What flows | Direction |
|-----------|-----------|-----------|
| **alice-claude** | Action records exceeding Alice's model capability | Alice → Claude Code |
| **wchq-upstream** | Template contributions, schema feedback, layout submissions | Instance → WC_HQ |
| **self** | Internal tool posting (JSON Tree, Matrix Builder) | Within instance |

No external credentials. Protocol is Action records with `config.escalation`.

### Deploy

Local server deployment — the sovereign installation.

| Connection | What flows | Direction |
|-----------|-----------|-----------|
| **Local Server** | Django, React, Alice, static files | Dev Mac → Andi |

Stack: nginx (80/443) → gunicorn (8000) → Django + PostgreSQL (5432) + Redis (6379). Cloudflare tunnel optional for public access. User owns the hardware, the data, and the server. WC_HQ has no access.

### Shipping

Rate calculation, label generation, and tracking.

| Connection | API | What WC3 sends | What WC3 receives |
|-----------|-----|----------------|-------------------|
| **UPS** | developer.ups.com | Ship-from, ship-to, weight, dimensions | Rates, labels (PDF), tracking events |
| **FedEx** | developer.fedex.com | Same | Same |
| **USPS** | developer.usps.com | Same | Same |
| **DHL** | developer.dhl.com | Same | Same |

All carriers use the same pattern: WC3 sends package details, receives rates and labels. Alice monitors for rate changes and carrier performance patterns. Markup and handling charges configurable per carrier.

### Tax

Sales tax calculation and compliance.

| Connection | When it fires | What WC3 sends | What WC3 receives |
|-----------|--------------|----------------|-------------------|
| **Avalara / TaxJar / Vertex** | Invoice line calculation | Ship-to address, item tax codes, amounts | Tax rate, tax amount, jurisdiction breakdown |

**Simple case:** Single jurisdiction, single rate — uses TaxJurisdiction records directly, no external API needed. External tax service activates when multi-jurisdiction complexity exceeds built-in capability.

### Communication

Email — inbound threads create Actions, outbound sends transactional messages.

| Connection | Auth | Inbound | Outbound |
|-----------|------|---------|----------|
| **Gmail** | OAuth2 (Google Workspace) | New thread from Contact → create Action | Order confirmations, shipping notifications, invoice delivery |
| **Outlook** | OAuth2 (Microsoft Graph) | Same | Same |

User chooses one email provider — not both simultaneously. Alice sees metadata only (subject, sender, timestamp), never email body content. PII stays local.

### Calendar

Bidirectional sync — WC3 Actions with due dates ↔ calendar events.

| Connection | Auth | WC3 → Calendar | Calendar → WC3 |
|-----------|------|----------------|----------------|
| **Google Calendar** | OAuth2 | Action due date → event | Event with [WC3] prefix → Action |
| **Outlook Calendar** | OAuth2 (Graph) | Same | Same |

WC3 is source of truth. On conflict, WC3 wins. Deletes do not sync (prevent accidental data loss). Alice monitors for overdue Actions visible in calendar.

### Payment

Payment processing — WC3 creates intents, processors handle cards.

| Connection | Auth | What WC3 sends | What WC3 receives | GL Entry |
|-----------|------|----------------|-------------------|----------|
| **Stripe** | API keys + webhook secret | Payment intent (amount, currency) | Payment confirmation, refund events, disputes | Debit Cash, Credit AR |
| **Square** | OAuth2 + webhook key | Same | Same | Same |
| **PayPal** | Client ID/secret + IPN | Redirect to PayPal | IPN/webhook confirmation | Same |

**PCI boundary:** WC3 never stores card data. Tokenization only. The payment processor holds PCI scope. WC3 produces GL journal entries from completed payments — refunds reverse the entry.

### Accounting

GL journal entry export — WC3 produces, accounting programs consume.

| Connection | Auth | WC3 exports | WC3 imports |
|-----------|------|-------------|-------------|
| **QuickBooks** | OAuth2 | Journal entries, customers, invoices | Purchase receipts, vendor bills, chart of accounts |
| **Xero** | OAuth2 | Journal entries, contacts, invoices | Purchase receipts, bills, chart of accounts |

**Hard boundary:** WC3 does not do checkbooks, payables, P&L, or balance sheets. Those belong to the accounting program. Payable feedback (purchase receipts, vendor bills) imports back to WC3 for landed cost tracking — this is the only inbound flow. AR collection is sales (WC3's job). AP is accounting (QuickBooks/Xero's job).

### Banking

Bank statement import via Statement Sorter.

| Connection | Method | What comes in | What WC3 does |
|-----------|--------|--------------|---------------|
| **Bank Feed** | Manual upload (CSV, OFX, QFX, QBO) | Bank transactions | Classify, match to invoices/payments, categorize |

No direct bank API — user controls what data enters the system. Statement Sorter (`/sort/`) is the tool. Alice learns categorization patterns over time (confidence threshold 0.85). Personal transactions never enter the database. Unmatched transactions flagged for human review.

### Identity

Portable sovereign identity via MyCarryOn.

| Connection | Auth | What syncs | Sovereignty rule |
|-----------|------|-----------|-----------------|
| **MyCarryOn** | API key | Contact ↔ CarryOn identity | Person owns identity; WC3 holds pointer |

Permissions are enumerated, revocable, and sunset. Context travels with the person. WC3 stores `carryon_uuid` on Contact records — a pointer, not a copy of identity. No data hoarding.

---

## Future Classes (not day-one)

| Class | When needed | Why not day-one |
|-------|------------|-----------------|
| **WMS / 3PL** | Warehouse exceeds in-house capacity | WC3 tracks inventory internally; external WMS for multi-warehouse |
| **Catalog Sync** | Multi-channel selling | DynamicCatalogs handles upstream; Shopify/Amazon sync is growth-stage |
| **Marketing Automation** | Scaled email campaigns | WC3 is the CRM; Mailchimp/Klaviyo for bulk campaigns at scale |
| **Customs / Broker** | International shipping | Add when cross-border trade volume justifies |

---

## Alice's Role Across All Classes

Alice monitors every connection class:

- **Shipping:** Rate change alerts, carrier performance degradation
- **Tax:** Jurisdiction changes, exemption handling anomalies
- **Communication:** Unanswered threads, repeat complaints
- **Calendar:** Overdue Actions, scheduling conflicts
- **Payment:** Failed payments, dispute patterns, refund velocity
- **Accounting:** Journal entry imbalances, sync drift
- **Banking:** Categorization confidence, unmatched transaction patterns
- **Identity:** Permission expirations approaching, sync failures

Alice creates Action records when patterns emerge. She does not fix — she flags.

---

## Credential Security

All connection credentials live in `connection.config.credentials`. Rules:

1. **Draft connections** have empty credential fields — user fills in their own
2. **Never store credentials in plain text in production** — encrypt at production cutover
3. **Test mode defaults to True** on all connections — go live is a deliberate act
4. **Alice never sees raw credentials** — she sees connection status and metadata only
5. **User owns their credentials** — WC_HQ has no access to instance credentials
