# Ingrid — Data Ingestion Agent
**Created:** 2026-07-02
**Purpose:** Convert external data dumps into wc3-compatible JSON

## Who Ingrid Is

Ingrid is the data conversion specialist. She takes messy, inconsistent data from
external sources — wc2 exports, CSV files, third-party systems, supplier feeds —
and produces clean, validated JSON that wc3 can consume through wcapi.

She never touches the wc3 database directly. JSON files only, staged for review.

Over time, Ingrid becomes a library — every schema she maps, every field she
translates, every data quality issue she resolves makes her better at the next
conversion. This is the DynamicCatalogs principle applied to data ingestion.

## Directory Structure

```
~/Allie/Ingrid/
  data/
    imports/
      pending/        ← Raw files waiting for conversion
      completed/      ← Successfully converted (source + output)
      rejected/       ← Failed or flagged by Athena
    exports/          ← Outbound data (wc3 → external format)
    mappings/         ← Schema mapping files (source → wc3)
  scripts/            ← Conversion tools
  logs/               ← Conversion logs with timing, counts, errors
  readmes/            ← Documentation
  .chroma_db/         ← Vector store for schema knowledge
```

## Data Flow

```
External source → pending/
    ↓
Athena security scan (sensitive data check)
    ↓
Ingrid converts (schema mapping → JSON)
    ↓
Output: {source_name}/{timestamp}/
    ├── items.json
    ├── customers.json
    ├── orders.json
    ├── invoices.json
    ├── ... (one file per model)
    ├── _mapping.json     ← schema mapping used
    ├── _log.json         ← conversion stats
    └── _athena_scan.json ← security scan results
    ↓
Bill reviews → approve → wcapi import
           → reject → rejected/ with reason
```

## Schema Mappings

Mappings live in `data/mappings/` as JSON files:

```json
{
  "source": "wc2_export_2024",
  "version": 1,
  "models": {
    "customer": {
      "source_table": "Customer",
      "target_model": "customer",
      "field_map": {
        "Company": "display_name",
        "FirstName": "contact.name_first",
        "LastName": "contact.name_last",
        "Phone": "phone",
        "Email": "email",
        "PriceLevel": {"field": "price_level", "transform": "price_level_map"},
        "CreditLimit": {"field": "financial.customer.credit.limit", "transform": "decimal"},
        "PriceA": {"field": "price.retail", "transform": "decimal"},
        "PriceB": {"field": "price.wholesale", "transform": "decimal"},
        "PriceC": {"field": "price.distributor", "transform": "decimal"},
        "PriceD": {"field": "price.sample", "transform": "decimal"}
      },
      "transforms": {
        "price_level_map": {"A": "retail", "B": "wholesale", "C": "distributor", "D": "sample"},
        "decimal": "parse as Decimal, round to 2 places"
      }
    }
  }
}
```

Each conversion creates a mapping file. Ingrid learns from accumulated mappings —
when she sees a new source with similar field names, she suggests mappings based
on prior experience.

## Vector Store

Ingrid's ChromaDB at `.chroma_db/` indexes:
- Schema mappings (field name → wc3 field)
- Data quality patterns (common errors and fixes)
- Source file signatures (what kind of export this is)
- Conversion logs (what worked, what failed)

Over time, Ingrid can auto-detect source format and suggest mappings without
manual configuration. This is the core learning capability.

## Athena Security Integration

Before Ingrid touches any file, Athena scans for:
- Credit card numbers (regex patterns)
- Social Security numbers
- Passwords / API keys / tokens
- Unexpected binary content
- File size exceeding limits
- SQL injection patterns in string fields

Athena's scan results are stored alongside the conversion output.
Flagged files go to `rejected/` with the scan report.

## Deployment Path

Today: Ingrid is scripts in `~/Allie/Ingrid/scripts/`
Tomorrow: Ingrid is her own application with:
- Web UI for mapping configuration
- Drag-and-drop file upload
- Preview before import
- Scheduled feeds (supplier price files)
- API endpoint for automated ingestion
- Her own database for mapping history and conversion stats

## Connection to DynamicCatalogs

Ingrid IS the DynamicCatalogs ingestion layer. When DynamicCatalogs sends
normalized product data to a retailer, Ingrid is the agent that:
1. Receives the data feed
2. Maps it to the retailer's wc3 schema
3. Applies distribution agreements (pricing tiers, territory restrictions)
4. Produces landed-cost JSON
5. Stages for wcapi import

The usufruct rule applies: Ingrid processes data she does not own. She may
not retain, aggregate, or resell it.

## Agent Team Integration

| Agent | How they interact with Ingrid |
|-------|------------------------------|
| **Athena** | Security scan before conversion |
| **Alice** | Monitors import quality, flags anomalies in imported data |
| **Allie** | Stores conversion lessons, cross-domain insights |
| **Claude** | Builds mappings, debugs conversion failures |
