# WC2 Data Export — Converting WC2 to Data
**Created:** 2026-07-16
**Status:** Reference — three export paths documented
**Owner:** Bill James
**Participants:** Claude Code, Allie, Alice

---

## Purpose

WC2 (WebClerk on 4D) contains ~250 tables of production business data accumulated over
20+ years. Before WC2 can be retired, all data must be exported in portable formats that
WC3 (Django/PostgreSQL) can consume. Three export mechanisms exist. **Try Method 1 first.**

---

## Export Method 1: 19Convert_ExportAllData (JSON) — Try This First

**File:** `Project_WebClerk/Sources/Methods/19Convert_ExportAllData.4dm`
**Last modified:** 2023-04-12 by Bill James
**Trigger:** Call from 4D method editor or menu

### This is the primary migration path

`19Convert_ExportAllData` with no parameters dumps the entire WC2 database as JSON files.
Each file is a JSON array that Python/Django can read directly with `json.load()`.
This is the data source for all WC3 migration scripts.

### Modes

| Call signature | Behavior |
|----------------|----------|
| `19Convert_ExportAllData()` (no params) | Prompts for folder, then exports **every valid table** as JSON |
| `19Convert_ExportAllData($tableName; $path; "xml")` | Single table export in 4D XML/binary format via `EXPORT DATA` |
| `19Convert_ExportAllData($tableName; $path; "")` | Single table export as **JSON** text file |

### JSON export (the useful one for WC3)

```
1. ds[$tableName].all()          — selects all records via ORDA
2. $sel.toCollection()           — converts entity selection to a 4D collection
3. JSON Stringify($collection)   — serializes to JSON text
4. TEXT TO DOCUMENT               — writes to <TableName>.txt
```

### Output

- One `.txt` file per table containing a JSON array of all records
- File named `<TableName>.txt` in the user-selected folder
- Every field in every record is included (no filtering)
- Iterates all valid tables: `For ($i; 1; Get last table number) ... Is table number valid($i)`

---

## Export Method 2: jExportMassive (Command Key)

**File:** `00WebClerk19/Project/Sources/Methods/jExportMassive.4dm`
**Written:** June 7, 2002
**Trigger:** Script with Command Key — invoke from within 4D

Fallback if `19Convert_ExportAllData` doesn't cover a specific need. Older method,
outputs tab-delimited text or 4D binary rather than JSON.

### Modes (determined by modifier key held)

| Modifier | Behavior |
|----------|----------|
| **Option (Alt)** | Single table — select table and records, export in reverse order to a named document |
| **Shift** | Single table — select table and records, export in forward order to a named file |
| **Command** | All tables — select a folder, exports every table with records as tab-delimited `.mex` files |
| **No modifier** | All tables — exports every table to `Storage.folder.jitF` as `zzzME_<TableName>.mdd` binary files |

### Output formats

- **`.mex` files** (Command key mode): Tab-delimited text, one file per table, named
  `NNN_Ex_<TableName>.mex` where NNN is the zero-padded table number. Uses `jArchExportRay`
  and `jArchExportAll` helper methods.
- **`.mdd` files** (no modifier mode): 4D binary SEND RECORD format. One file per table,
  named `zzzME_<TableName>.mdd`. These are 4D-native and require 4D to reimport.

### Key details

- Iterates all tables via `Get last table number` / `Table(n)`
- Uses 4D's `SEND RECORD` / `SET CHANNEL` for binary export
- Progress bar shows export progress per table
- Caps Lock key triggers `TRACE` (debugger) during all-table export
- Tab-delimited mode uses `\r` record delimiter, `\t` field delimiter, no quoting

### Where output goes

- Command mode: user-selected folder
- No-modifier mode: `Storage.folder.jitF` (4D's internal temp/export folder)

---

## WC2 Source Locations

| Item | Path |
|------|------|
| jExportMassive | `~/Documents/CommerceExpert/00WebClerk19/Project/Sources/Methods/jExportMassive.4dm` |
| 19Convert_ExportAllData | `~/Documents/CommerceExpert/Project_WebClerk/Sources/Methods/19Convert_ExportAllData.4dm` |
| Backup copy | `~/Documents/CommerceExpert/webclerk2/WebClerk20_over_2024-11-20_works_nolines/Project_WebClerk/Sources/Methods/19Convert_ExportAllData.4dm` |
| jArchExportAll (helper) | `~/Documents/CommerceExpert/00WebClerk19/Project/Sources/Methods/jArchExportAll.4dm` |
| WC2→WC3 translation plan | `~/Allie/knowledge/projects/webclerk-wc2-wc3-translation-plan.md` |
| WC2 flow charts | `/Volumes/Allie/allie/allie/inbox/domains/jpods.com/public_html/software/WebClerkComExFlowCharts.pdf` |

---

## Migration Workflow

```
WC2 (4D)                           WC3 (Django/PostgreSQL)
────────                           ──────────────────────
19Convert_ExportAllData()
  → <folder>/<TableName>.txt        Python reads JSON
     (JSON array per table)    →    Django management command
                                      → maps fields to WC3 models
                                      → validates + transforms
                                      → bulk_create into PostgreSQL
```

### What Alice needs from this

Alice tracks the gap analysis (15 gaps, GAP-01 through GAP-15). The JSON exports are
the source data for verifying that WC3 handles every WC2 workflow. Key tables:

- **Customers** → Contact + Organization (WC3)
- **Orders / OrderLines** → Order + OrderLine (WC3)
- **Invoices / InvoiceLines** → Invoice + InvoiceLine (WC3)
- **Payments** → Payment + PaymentApplication (WC3)
- **Inventory** → ItemVariant + InventoryReservation (WC3)
- **GL entries** → LedgerEntry (WC3)

Full mapping: `readmes/topics/wc2/todo.md` in the WC3 repo.

---

## Export Method 3: v17 Export Editor (Data to JSON Button)

**Platform:** 4D v17 Export Editor (GUI)
**Trigger:** Built-in "Data to JSON" button in the Export Editor interface

4D v17's Export Editor has a native data-to-JSON export button. This is a third path
if the scripted methods above don't cover a specific need. The syntax for driving this
programmatically is in the v17 source code — Bill would need to open that codebase to
extract the exact syntax.

**When to use this:** Only if `19Convert_ExportAllData` (Method 1) doesn't produce
the needed output for a specific table or if field-level export control is required
that the all-records dump doesn't provide.

**Status:** Available but not yet documented in detail. If needed, Bill will open the
v17 source to get the syntax.

---

## Next Steps

- [ ] Run `19Convert_ExportAllData()` on current WC2 database — capture full JSON dump
- [ ] Inventory all exported tables — count records, identify which map to WC3 models
- [ ] Write Django management command to import priority tables (Customers, Orders, Invoices, Payments)
- [ ] Validate imported data against WC2 originals
- [ ] Document any tables with no WC3 equivalent (candidates for archive or drop)
