# 59 — MyCarryOn Plugin Architecture
**Created:** 2026-07-16
**Status:** Design — framework for specialty programs
**Owner:** Bill + team

---

## The Problem

We are building many specialty programs — crash data, network planning,
ticketing, identity, medical records, translation. Each is useful alone,
but the real value is when they compose. A traveler's medical record,
translated to the local language, accessible by emergency responders
without a security barrier — that's not one program. That's three programs
(medical records, translation, emergency access) composed through a
common framework.

We need a plugin architecture, not a monolith.

---

## The Framework: CarryOn Plugins

A MyCarryOn plugin is a small program that:
1. **Reads from the CarryOn** — only fields the person has granted access to
2. **Does one thing** — translate, format, filter, serve, sync
3. **Returns a result** — to the person, to a requesting system, or to another plugin
4. **Respects permissions** — the person's permission grants are the API boundary

```
Person's CarryOn
  │
  ├── Plugin: medical-emergency
  │     Reads: medical section
  │     Does: serves emergency-relevant fields
  │     Permission: "emergency" — no auth barrier, auto-translate
  │
  ├── Plugin: translate
  │     Reads: any text field
  │     Does: translates to target language
  │     Permission: called by other plugins, not directly
  │
  ├── Plugin: jpods-rider
  │     Reads: identity, payment method
  │     Does: presents rider profile to JPods vehicle
  │     Permission: "jpods" — granted per-ride
  │
  ├── Plugin: webclerk-sync
  │     Reads: identity, transaction history
  │     Does: syncs with a WebClerk instance via Connection + Bundle
  │     Permission: "webclerk:<instance>" — granted per-store
  │
  └── Plugin: advertising-opt-in
        Reads: interests (only if rider volunteers)
        Does: serves ads, credits rider
        Permission: "advertising" — per-ride, revocable by closing screen
```

---

## Plugin Contract

Every plugin implements the same interface:

```python
class CarryOnPlugin:
    """Base contract for all MyCarryOn plugins."""

    name: str               # "medical-emergency"
    version: str            # "1.0.0"
    required_fields: list   # ["medical.conditions", "medical.allergies", ...]
    permission_scope: str   # "emergency" — matches CarryOn permission grants

    def can_run(self, carryon: dict) -> bool:
        """Check if the person has granted the required permissions."""

    def execute(self, carryon: dict, context: dict) -> dict:
        """Do the work. Return the result."""

    def describe(self) -> dict:
        """Human-readable description of what this plugin does,
        what it reads, and what it returns. Shown to the person
        before they grant permission."""
```

**Rules:**
- A plugin CANNOT read fields outside its `required_fields`
- A plugin CANNOT run if `can_run()` returns False
- A plugin MUST declare what it reads and returns in `describe()`
- The person sees `describe()` before granting permission
- Permissions are revocable at any time — the plugin stops working

---

## Permission Levels

Not all data access is the same. A medical emergency is not the same as
an advertising opt-in.

| Level | Auth Required | Example | Revocation |
|-------|--------------|---------|------------|
| **emergency** | None — NFC/QR scan is sufficient | EMT scans wristband → medical record in local language | Cannot revoke (life safety) |
| **transit** | Tap/scan at boarding | JPods vehicle reads rider profile | Auto-revokes at trip end |
| **commerce** | Explicit grant per store | WebClerk sync for a purchase | Revoke anytime, data fades in 7 days |
| **advertising** | Explicit opt-in per ride | Show ads, credit rider | Close screen = revoked |
| **professional** | Explicit grant + time limit | Share credentials with employer/client | Sunset date required |
| **government** | Court order + key holder | Law enforcement access to transaction blockchain | Requires legal process |

**The emergency level is special.** It has no auth barrier because the
person may be unconscious. The trade-off is that only life-safety fields
are exposed — medical conditions, allergies, blood type, emergency contacts,
medications. Nothing else. No financial data, no ride history, no identity
beyond what's needed to save a life.

---

## The Medical Emergency Plugin — Worked Example

### What the person configures (once, in their CarryOn app)

```json
{
  "permissions": {
    "emergency": {
      "fields": [
        "medical.conditions",
        "medical.allergies",
        "medical.blood_type",
        "medical.medications",
        "medical.emergency_contacts",
        "identity.name",
        "identity.date_of_birth"
      ],
      "translate": true,
      "auth_required": false,
      "note": "Accessible by EMTs without login. I may be unconscious."
    }
  }
}
```

### What the EMT sees (Tokyo, 3 AM)

EMT scans NFC wristband or QR code on phone lock screen. No login. No app.
The CarryOn serves a translated medical card:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EMERGENCY MEDICAL INFORMATION
  緊急医療情報
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Name / 名前:        William James
  DOB / 生年月日:      1950-06-15
  Blood Type / 血液型:  A+

  Conditions / 病状:
    • Type 2 diabetes / 2型糖尿病
    • Hypertension / 高血圧

  Allergies / アレルギー:
    • Penicillin / ペニシリン

  Medications / 薬:
    • Metformin 500mg 2x daily
    • Lisinopril 10mg daily

  Emergency Contact / 緊急連絡先:
    • Sarah James: +1-555-0123
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**What the EMT does NOT see:** financial records, ride history, home address,
email, advertising preferences, transaction history, CarryOn permissions,
or anything not in the `emergency` field list.

**Translation:** The `translate` plugin detects the device locale of the
scanner (Japanese) and renders bilingual. The person set `translate: true`
once. It works in any language, anywhere.

---

## Plugin Registry

Plugins are registered in the CarryOn app. The person browses available
plugins, reads `describe()`, and chooses which to enable.

**Core plugins (ship with MyCarryOn):**

| Plugin | What it does | Permission level |
|--------|-------------|-----------------|
| `medical-emergency` | Serves medical card, auto-translated | emergency |
| `translate` | Translates any text field to target language | utility (called by others) |
| `identity-card` | Basic identity for check-in, boarding | transit |
| `webclerk-sync` | Sync with WebClerk instances via Connection + Bundle | commerce |
| `jpods-rider` | Rider profile for JPods vehicles | transit |

**Future plugins (community/vendor):**

| Plugin | What it does | Permission level |
|--------|-------------|-----------------|
| `advertising-opt-in` | Serve ads in vehicle, credit rider | advertising |
| `hotel-checkin` | Share ID + loyalty info with hotel | commerce |
| `rental-car` | Share license + insurance with rental | commerce |
| `conference-badge` | Share name + affiliation at events | professional |
| `prescription-refill` | Share Rx with foreign pharmacy | professional |
| `insurance-claim` | Share accident/medical data with insurer | professional |
| `customs-declaration` | Pre-fill customs forms | government |

**Anyone can write a plugin.** The person decides which to install.
The `describe()` method is the informed consent mechanism — the person
sees exactly what the plugin reads and returns before enabling it.

---

## How Plugins Compose

Plugins call other plugins. The medical-emergency plugin calls the
translate plugin. The jpods-rider plugin calls webclerk-sync. The
advertising plugin calls translate for multilingual ads.

```
medical-emergency
  └── calls: translate (locale detection → bilingual output)

jpods-rider
  ├── calls: webclerk-sync (push rider profile to wc_jpods)
  └── calls: translate (station signage in rider's language)

advertising-opt-in
  ├── calls: translate (ad in rider's language)
  └── calls: webclerk-sync (credit rider's account)
```

**Composition rule:** A composed plugin cannot exceed the permissions of
its parent. If `jpods-rider` has `transit` permission, the `translate`
plugin it calls can only access fields that `jpods-rider` already has
access to. No privilege escalation through composition.

---

## Relationship to Existing Systems

| System | Role in plugin architecture |
|--------|---------------------------|
| **MyCarryOn** | The platform — hosts plugins, enforces permissions |
| **WebClerk** | A plugin consumer — receives data via `webclerk-sync` plugin |
| **CrashHarvester** | A library — feeds MeshMobility, no CarryOn interaction |
| **MeshMobility** | Could have a plugin — "share my network designs" |
| **Alice** | Manages commerce plugins — pricing, credits, Small-Stings |
| **JPods vehicle** | Reads `jpods-rider` plugin output at boarding |

---

## Framework Implementation (future)

**Phase 1 (IT15 launch):** No plugin framework yet. MyCarryOn is a WC3
database. The Connection + Bundle sync is the plugin prototype — it already
does field-level permission control and audited exchanges.

**Phase 2:** Extract the plugin contract from Connection + Bundle. Build
the CarryOn app (phone PWA) with plugin registry. Medical-emergency is
the first plugin because it has the clearest value proposition and the
simplest permission model.

**Phase 3:** Open the plugin registry to third parties. The `describe()`
method + permission levels + composition rules are the governance framework.
No app store review needed — the person decides. The plugin declares what
it does, the person reads it, the person chooses.

---

## The Principle

> The person is sovereign. Plugins are agents with enumerated permissions.
> The person sees what the plugin reads, grants access, and can revoke at
> any time. No plugin runs without consent. No data moves without a record.

This is Divided Sovereignty applied to software: the individual is
sovereign, programs are agents with limited, enumerated, revocable
permissions. The plugin architecture is how that principle becomes code.
