# Handoff — 2026-08-22 (Session 3: Flight Simulator Cleanup)

## Where We Left Off

All three open items from the previous handoff are fixed but **untested** — React dev server was not running.

## What Was Done

### 1. Renamed section headers — Inventory→Counts, Payments→Money
- `FlightSimConsole.tsx` — section headers, empty states, and comments updated
- Three domains every transaction touches: **Counts** (physical), **Money** (financial), **GL** (accounting)

### 2. Fixed invoice line save not persisting (DEV-105)
- **Root cause:** Converted lines injected via `initialLines` in `TransactionDetail.tsx:128` lacked `_dirty: true`
- `handleSave` checks `_dirty || _new` to decide between `saveTransactionWithLines` (strips read-only fields) and `saveRecord` (does not)
- Without `_dirty`, lines went through `saveRecord`, sending `uuid`, `dt_created`, `version` etc. to the backend, causing silent failures in line creation
- **Fix:** `TransactionDetail.tsx:130` — `initialLines.map(l => ({ ...l, _dirty: true }))`

### 3. Locked records → read-only form
- **Fix:** `TransactionDetail.tsx:139` — `if (data.is_locked === true) return 'closed'`
- Single line makes entire form read-only: header fields disabled, lines locked, Edit button hidden
- No schema changes needed — `is_locked` already exists on records

## What's Open

1. **Test all three fixes** — start React dev server, verify in browser
2. **Allie offline** — ollama wasn't running; teach_allie call failed; retry next session

## Key Files Changed
- `React2025/src/pages/admin/FlightSimConsole.tsx` — section renames
- `React2025/src/apps/transactions/components/TransactionDetail.tsx` — line save fix + locked record fix
