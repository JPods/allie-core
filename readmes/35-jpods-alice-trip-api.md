# JPods — Alice Trip API
**Last updated:** 2026-04-29
**Status:** Built — run seed command before first demo

Alice owns all trip pricing and invoicing for JPods. Natalie calls Alice before dispatching
a pod (price query) and again after the trip completes (invoice). Alice resolves the rider's
identity, applies their pricing tier and discounts, and posts the invoice to WebClerk.

---

## Architecture

```
User selects trip (UI)
  → Natalie: POST /wcapi/jpods/price/   (price query)
  ← Alice: { price, display, contact_id, item_id }
  → User sees price, confirms
  → Nora executes trip
  → Natalie: POST /wcapi/jpods/invoice/ (trip complete, passes item_id back)
  ← Alice: { invoice_id, status: complete }
```

**Authority boundaries:**
- Natalie owns routing and dispatch. She calls Alice for price and invoice only.
- Alice owns pricing, discounts, and commerce records. She does not route pods.
- Nora owns pod execution. She does not touch Alice directly.

---

## Pricing Model

Pricing uses the standard WC3 `Item` model (kind="service"). No custom pricing table.

**SKU convention:** `JPODS-{NETWORK_ID}-{ORIGIN}-{DESTINATION}`
- e.g. `JPODS-DEFAULT-S001-S003`

**Price level mapping** (Customer.price_level → Item.price key):

| Customer.price_level | Item.price key | Demo price |
|----------------------|---------------|------------|
| `demo`               | `wholesale`   | $0.50      |
| `retail`             | `retail`      | $2.00      |
| `employee`           | `sample`      | $0.25      |

Alice looks up the Item by SKU, reads the price key for the rider's level, and applies
any contact-level discounts from `Customer.financial["discounts"]`.

---

## Identity Model

| Layer | Model | What it carries |
|-------|-------|----------------|
| Access + Person | `Contact` | name, email (login), phone, uuid (CarryOn ID) |
| Billing | `Customer` (OrgBase) | price_level, discounts (financial JSON), invoice history |
| Invoice | `Invoice` | contact FK + customer FK + trip refs + total |
| Line | `InvoiceLine` | item_fk → Item, quantity=1, price.unit=fare |

Natalie identifies the rider by name → Alice resolves Contact → Customer → pricing.

**CarryOn:** When mycarryon.io WebClerk is ready, Alice posts the Contact record there
using `Contact.uuid` as the universal ID. Each JPods network operates on its local
`Contact.id`; the uuid enables cross-network recognition. The Customer (billing) is always
local to each network.

---

## API Endpoints

Both endpoints are mounted at `POST /wcapi/jpods/`.
Authentication: `Authorization: Bearer <natalie_token>`

### POST /wcapi/jpods/price/

**Request:**
```json
{
  "contact_uuid": "...",
  "email": "bill@jpods-demo.local",
  "name": "Bill James",
  "origin_station_id": "S001",
  "destination_station_id": "S003",
  "network_id": "default"
}
```
One of `contact_uuid`, `email`, or `name` is sufficient. All are optional — omitting all
returns the anonymous retail rate with no contact linked.

**Response:**
```json
{
  "contact_id": 5,
  "contact_name": "Bill James",
  "customer_id": 3,
  "item_id": 12,
  "price": "0.50",
  "currency": "USD",
  "price_level": "demo",
  "discount_applied": null,
  "display": "USD 0.50 (demo rate)",
  "origin_station_id": "S001",
  "destination_station_id": "S003",
  "network_id": "default"
}
```

### POST /wcapi/jpods/invoice/

**Request:**
```json
{
  "contact_id": 5,
  "item_id": 12,
  "origin_station_id": "S001",
  "destination_station_id": "S003",
  "price": "0.50",
  "currency": "USD",
  "trip_id": "T-20260429-001",
  "duration_actual_s": 102,
  "price_level": "demo",
  "discount_applied": null,
  "network_id": "default"
}
```
Pass `item_id` from the price response — Alice uses it to link the InvoiceLine to the Item.
If omitted, Alice falls back to a SKU lookup.

**Response:**
```json
{
  "invoice_id": 42,
  "status": "complete",
  "total": "0.50",
  "currency": "USD",
  "contact_name": "Bill James",
  "customer_id": 3,
  "trip_id": "T-20260429-001"
}
```

---

## Authentication

Natalie uses a Bearer token that Alice validates against the `Connection` record
named "natalie" in WebClerk (`Connection.config["token"]`).

**Token locations:**
- Natalie reads from: `JPodsSM_RPi/config/natalie-keys.json`
- Alice stores in: WebClerk Connection record (name="natalie", status="active")
- Allie reads both via: `/Users/williamjames/Allie/config/allie_api_keys.json`

**Security state: DEVELOPMENT (plaintext)**
All tokens are plaintext JSON during development.
Before release: encrypt Connection.config + add blockchain audit trail for key changes.
Alice action record created by seed command — review due **2026-05-29**.

---

## Setup — First Time

### 1. Run the migration

```bash
cd /Users/williamjames/Documents/CommerceExpert/webClerk3
python manage.py migrate apps.jpods
```

The jpods app has no custom models — this is a no-op migration. Products.Item already exists.

### 2. Seed demo data

```bash
python manage.py seed_jpods_demo
```

Creates:
- 8 Contact + Customer records (Bill James + Demo One–Four + Child/Adult/Elderly Traveler)
- 18 trip Items (6 original + 12 SketchUp S097–S100 pairs, with demo/retail/employee pricing in standard Item.price keys)
- 1 Connection record for Natalie's token
- 1 Alice action record (encryption review, 2026-05-29)

To reset and re-seed:
```bash
python manage.py seed_jpods_demo --reset
```

### 3. Test the endpoints

```bash
# Price query
curl -X POST http://localhost:8000/wcapi/jpods/price/ \
  -H "Authorization: Bearer wq80pbGbKmIHbhT24O9QbkpvWpbnYtMQ2wZASIEGtHY" \
  -H "Content-Type: application/json" \
  -d '{"name": "Bill James", "origin_station_id": "S001", "destination_station_id": "S003"}'

# Invoice (pass item_id from price response)
curl -X POST http://localhost:8000/wcapi/jpods/invoice/ \
  -H "Authorization: Bearer wq80pbGbKmIHbhT24O9QbkpvWpbnYtMQ2wZASIEGtHY" \
  -H "Content-Type: application/json" \
  -d '{"contact_id": 1, "item_id": 1, "origin_station_id": "S001", "destination_station_id": "S003", "price": "0.50", "currency": "USD", "trip_id": "T-001", "duration_actual_s": 95}'
```

---

## Demo UI — How to Use

For demos, the rider selection is a simple name picker. The pre-loaded contacts are:

| Name | Email | Price Level |
|------|-------|-------------|
| Bill James | bill@jpods-demo.local | demo ($0.50) |
| Demo One | demo1@jpods-demo.local | demo ($0.50) |
| Demo Two | demo2@jpods-demo.local | demo ($0.50) |
| Demo Three | demo3@jpods-demo.local | demo ($0.50) |
| Demo Four | demo4@jpods-demo.local | demo ($0.50) |
| Child Traveler | child@traveler.com | retail (set in WC3) |
| Adult Traveler | adult@traveler.com | retail (set in WC3) |
| Elderly Traveler | elderly@traveler.com | retail (set in WC3) |

**UI flow (to be built):**
1. Rider selects name from list (or enters on their phone)
2. UI calls Natalie with name + origin + destination
3. Natalie calls `POST /wcapi/jpods/price/` → gets price + item_id
4. UI shows price to rider (e.g. "USD 0.50 (demo rate)")
5. Rider confirms → pod dispatched
6. Trip completes → Natalie calls `POST /wcapi/jpods/invoice/` (passes item_id back)
7. Invoice + InvoiceLine posted to rider's account in WebClerk

**Self-entry on phone (future):**
Display a QR code at the station → rider opens URL on phone → types name and email →
Alice creates Contact + Customer → returns contact_id → normal flow continues.
Optionally: offer CarryOn account creation at this step.

---

## Files

| File | Purpose |
|------|---------|
| `webClerk3/apps/jpods/models.py` | No custom models — notes on pricing conventions |
| `webClerk3/apps/jpods/services/pricing.py` | Contact resolution + Item price lookup |
| `webClerk3/apps/jpods/services/invoice_service.py` | Invoice + InvoiceLine creation |
| `webClerk3/apps/jpods/views.py` | PriceQueryView, InvoiceView |
| `webClerk3/apps/jpods/urls.py` | URL routing |
| `webClerk3/apps/jpods/management/commands/seed_jpods_demo.py` | Demo seed command |
| `webClerk3/apps/products/models/item.py` | Item model (kind="service" for trip items) |
| `JPodsSM_RPi/config/natalie-keys.json` | Natalie's token + Alice endpoints |
| `JPodsSM_RPi/config/noelle-keys.json` | Noelle's token (reserved) |
| `JPodsSM_RPi/config/nora-keys.json` | Nora's token (reserved) |
| `Allie/config/allie_api_keys.json` | Allie's API keys (includes webclerk-alice token) |

---

## Load Balancing

Each station pair has its own Item record. This is intentional — each record is a demand
sensor. When a route becomes congested, Alice raises its price and lowers prices on nearby
alternative origins to spread demand without central scheduling.

See: `readmes/36-jpods-dynamic-pricing-load-balancing.md`

---

## Next Steps

1. **Add station pairs** — edit `seed_jpods_demo.py` `STATION_PAIRS` as the demo network grows
2. **Build the trip request UI** — see UI flow above; starts with a name picker
3. **Noelle endpoints** — construction and maintenance transaction endpoints (not yet built)
4. **Self-entry on phone** — QR code → mobile web form → Contact creation → CarryOn opt-in
5. **myCarryOn sync** — when mycarryon.io WebClerk is ready, post Contact.uuid there
6. **Encrypt keys** — before release, encrypt Connection.config + add blockchain audit trail
   (Alice action record review: 2026-05-29)
