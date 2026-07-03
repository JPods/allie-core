#!/usr/bin/env python3
"""Update all field_access Settings with complete field definitions.

Reads Django model source to build accurate field_behaviors for each model.
Updates only the field_behaviors key within data, preserving roles/query_scope.

Usage:
    python3 scripts/update_field_access.py
"""

import json
import subprocess
import sys

# ─── Common BaseModel fields (inherited by all models) ───────────────────────
CORE_FIELDS = {
    "id": {
        "type": "readonly", "label": "ID", "editable": False,
        "system_driven": True, "computed_by": "database",
        "used_in": ["detail"], "alice_help": "Auto-assigned database primary key."
    },
    "uuid": {
        "type": "readonly", "label": "UUID", "editable": False,
        "system_driven": True, "computed_by": "database",
        "used_in": ["detail"], "alice_help": "Universally unique identifier for cross-system exchange."
    },
    "ida": {
        "type": "readonly", "label": "IDA", "editable": False,
        "system_driven": True, "computed_by": "database",
        "used_in": ["list", "detail", "search"],
        "alice_help": "Human-readable born-on identifier (e.g. WC-1234). Auto-generated on first save."
    },
    "dt_created": {
        "type": "timestamp", "label": "Created", "editable": False,
        "system_driven": True, "computed_by": "database",
        "used_in": ["list", "detail", "filter"],
        "alice_help": "When this record was first created (UTC epoch ms)."
    },
    "dt_modified": {
        "type": "timestamp", "label": "Modified", "editable": False,
        "system_driven": True, "computed_by": "database",
        "used_in": ["list", "detail", "filter"],
        "alice_help": "When this record was last updated (UTC epoch ms)."
    },
    "version": {
        "type": "readonly", "label": "Version", "editable": False,
        "system_driven": True, "computed_by": "database",
        "used_in": ["detail"],
        "alice_help": "Optimistic concurrency version number. Increments on each save."
    },
    "is_active": {
        "type": "boolean", "label": "Active", "editable": True,
        "used_in": ["list", "detail", "filter"],
        "alice_help": "Whether this record is logically active. Inactive records are hidden from normal views."
    },
    "security_level": {
        "type": "readonly", "label": "Security Level", "editable": False,
        "system_driven": True,
        "used_in": ["detail"],
        "alice_help": "Access classification level (0 = unrestricted)."
    },
    "is_deleted": {
        "type": "readonly", "label": "Deleted", "editable": False,
        "system_driven": True,
        "used_in": ["detail"],
        "alice_help": "Soft-delete flag. Deleted records are hidden but recoverable."
    },
    "is_archived": {
        "type": "readonly", "label": "Archived", "editable": False,
        "system_driven": True,
        "used_in": ["detail"],
        "alice_help": "Archived records are read-only and excluded from active queries."
    },
    "is_locked": {
        "type": "readonly", "label": "Locked", "editable": False,
        "system_driven": True,
        "used_in": ["detail"],
        "alice_help": "When locked, no fields can be edited without admin unlock."
    },
    "metadata": {
        "type": "json", "label": "Metadata", "editable": True,
        "used_in": ["detail"],
        "alice_help": "System metadata: history, health scores, flags, versioning, images, erosion annotations."
    },
    "refs": {
        "type": "json", "label": "References", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Lightweight relationships: keywords, tags, links to related records, categories."
    },
    "prefs": {
        "type": "json", "label": "Preferences", "editable": True,
        "used_in": ["detail"],
        "alice_help": "User and system preferences for this record (display, restrictions, user-defined values)."
    },
    "comments": {
        "type": "json", "label": "Comments", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Structured notes: public, process, and partner comment channels plus append-only notes list."
    },
    "actions": {
        "type": "json", "label": "Actions", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Next-action metadata: who, when, what, status. Searchable for workflow queries."
    },
    "health_rating": {
        "type": "number", "label": "Health Rating", "editable": False,
        "system_driven": True, "computed_by": "health_service",
        "used_in": ["list", "detail", "filter"],
        "alice_help": "Data quality score (0-100). Higher is better. Computed from completeness, accuracy, freshness."
    },
}

# ─── Transaction header fields (order, invoice, proposal, purchase) ──────────
TRANSACTION_HEADER_FIELDS = {
    "total": {
        "type": "currency", "label": "Total", "editable": False,
        "system_driven": True, "computed_by": "totals_service",
        "used_in": ["list", "detail", "filter"],
        "alice_help": "Grand total denormalized from totals.total for fast queries and display."
    },
    "balance": {
        "type": "currency", "label": "Balance", "editable": False,
        "system_driven": True, "computed_by": "totals_service",
        "used_in": ["list", "detail", "filter"],
        "alice_help": "Outstanding balance (total minus payments received). Denormalized from totals.balance."
    },
    "line_increment": {
        "type": "number", "label": "Line Increment", "editable": False,
        "system_driven": True, "computed_by": "line_service",
        "used_in": [],
        "alice_help": "Counter for auto-assigning line numbers to new lines (increments by 10)."
    },
    "status": {
        "type": "select", "label": "Status", "editable": True,
        "used_in": ["list", "detail", "filter"],
        "options_source": "choices",
        "options": [
            {"label": "Planned", "value": "planned"},
            {"label": "Released", "value": "released"},
            {"label": "In Progress", "value": "in_progress"},
            {"label": "Hold", "value": "hold"},
            {"label": "Complete", "value": "complete"},
            {"label": "Canceled", "value": "canceled"}
        ],
        "alice_help": "Transaction lifecycle status. Planned -> Released -> In Progress -> Complete. Use Hold to pause, Canceled to void."
    },
    "priority": {
        "type": "text", "label": "Priority", "editable": True,
        "used_in": ["list", "detail", "filter"],
        "alice_help": "Free-text priority indicator. Use to flag urgency or processing order."
    },
    "price_level": {
        "type": "select", "label": "Price Level", "editable": True,
        "used_in": ["list", "detail", "filter"],
        "options_source": "choices",
        "options": [
            {"label": "Retail", "value": "retail"},
            {"label": "Wholesale", "value": "wholesale"},
            {"label": "Distributor", "value": "distributor"},
            {"label": "Sample", "value": "sample"}
        ],
        "alice_help": "Pricing tier for this transaction. Controls which price column is used from the item price JSON."
    },
    "is_commission": {
        "type": "boolean", "label": "Commission Order", "editable": True,
        "used_in": ["list", "detail", "filter"],
        "alice_help": "Whether this order was placed by a manufacturer for commission. Affects commission calculations."
    },
    "customer": {
        "type": "lookup", "label": "Customer", "editable": True,
        "used_in": ["list", "detail", "filter", "search"],
        "lookup_model": "customer", "lookup_display": "display_name",
        "lookup_search": ["ida", "display_name", "email"],
        "alice_help": "The customer organization this transaction belongs to. Required for sell-side transactions."
    },
    "manufacturer": {
        "type": "lookup", "label": "Manufacturer", "editable": True,
        "used_in": ["detail", "filter"],
        "lookup_model": "manufacturer", "lookup_display": "display_name",
        "lookup_search": ["ida", "display_name"],
        "alice_help": "Manufacturer linked to this transaction. Used for commission orders and drop-ship."
    },
    "vendor": {
        "type": "lookup", "label": "Vendor", "editable": True,
        "used_in": ["detail", "filter"],
        "lookup_model": "vendor", "lookup_display": "display_name",
        "lookup_search": ["ida", "display_name"],
        "alice_help": "Vendor supplying goods on this transaction. Used for purchase orders and drop-ship."
    },
    "parent_id": {
        "type": "number", "label": "Parent ID", "editable": True,
        "used_in": ["detail"],
        "alice_help": "ID of the parent transaction (polymorphic via parent_model). Links child transactions to their source."
    },
    "parent_model": {
        "type": "select", "label": "Parent Model", "editable": True,
        "used_in": ["detail"],
        "options_source": "choices",
        "options": [
            {"label": "Proposal", "value": "proposal"},
            {"label": "Order", "value": "order"},
            {"label": "Invoice", "value": "invoice"},
            {"label": "Purchase", "value": "purchase"},
            {"label": "Work Order", "value": "workorder"},
            {"label": "Requisition", "value": "requisition"}
        ],
        "alice_help": "Which transaction type is the parent. Used with parent_id to trace transaction lineage."
    },
    "contact": {
        "type": "lookup", "label": "Contact", "editable": True,
        "used_in": ["list", "detail", "filter"],
        "lookup_model": "contact", "lookup_display": "attention",
        "lookup_search": ["ida", "email", "name_first", "name_last", "attention"],
        "alice_help": "Primary contact person for this transaction. Auto-populated from customer if not set."
    },
    "attention": {
        "type": "text", "label": "Attention", "editable": True,
        "used_in": ["list", "detail"],
        "alice_help": "Attention line for mailing/shipping. Free text override of contact name."
    },
    "address_full": {
        "type": "address", "label": "Address", "editable": True, "action": "map",
        "used_in": ["detail"],
        "alice_help": "Denormalized full address for display and search. Can be overridden per transaction."
    },
    "email": {
        "type": "email", "label": "Email", "editable": True, "action": "mailto",
        "used_in": ["list", "detail"],
        "alice_help": "Primary email for this transaction. Click to open email client."
    },
    "phone": {
        "type": "phone", "label": "Phone", "editable": True, "action": "tel",
        "used_in": ["list", "detail"],
        "alice_help": "Primary phone number. Click to dial."
    },
    "terms": {
        "type": "text", "label": "Terms", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Payment terms text (e.g. Net 30). Overridden by terms_fk if set."
    },
    "terms_fk": {
        "type": "lookup", "label": "Payment Terms", "editable": True,
        "used_in": ["detail"],
        "lookup_model": "term", "lookup_display": "name",
        "lookup_search": ["name", "ida"],
        "alice_help": "Link to PaymentTerm record. Overrides the free-text terms field."
    },
    "conditions_id": {
        "type": "number", "label": "Conditions ID", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Reference to a conditions/terms template document."
    },
    "conditions_description": {
        "type": "text", "label": "Conditions", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Description of special conditions or terms applied to this transaction."
    },
    "cost": {
        "type": "json", "label": "Cost Summary", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Header-level cost breakdown: goods, tax, shipping, handling, freight, commissions, total."
    },
    "sell": {
        "type": "json", "label": "Sell Summary", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Header-level sell/revenue breakdown."
    },
    "totals": {
        "type": "json", "label": "Totals", "editable": False,
        "system_driven": True, "computed_by": "totals_service",
        "used_in": ["detail"],
        "alice_help": "Cached totals for filtering: subtotal, discount, tax, shipping, total, cost, margin, received, balance."
    },
    "finance": {
        "type": "json", "label": "Finance", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Tax configuration: sales/cost tax IDs, rates, amounts, collection and exchange expense."
    },
    "commission": {
        "type": "json", "label": "Commission", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Commission configuration and calculated amounts for this transaction."
    },
    "flow": {
        "type": "json", "label": "Flow", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Transaction lineage: source documents and child documents created from this transaction."
    },
    "source": {
        "type": "json", "label": "Source", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Attribution: campaign ID, catalog ID, vendor/manufacturer source for analytics."
    },
}


# ─── Transaction line fields (order_line, invoice_line, etc.) ────────────────
SELL_LINE_FIELDS = {
    "line_number": {
        "type": "number", "label": "Line #", "editable": False,
        "system_driven": True, "computed_by": "line_service",
        "used_in": ["list", "detail"],
        "alice_help": "Stable display sequence number. Auto-assigned from parent header's line_increment."
    },
    "price_level": {
        "type": "select", "label": "Price Level", "editable": True,
        "used_in": ["detail"],
        "options_source": "choices",
        "options": [
            {"label": "Retail", "value": "retail"},
            {"label": "Wholesale", "value": "wholesale"},
            {"label": "Distributor", "value": "distributor"},
            {"label": "Sample", "value": "sample"}
        ],
        "alice_help": "Price tier override for this line. Inherits from header if blank."
    },
    "status": {
        "type": "text", "label": "Status", "editable": True,
        "used_in": ["list", "detail"],
        "alice_help": "Line-level status (optional). Independent of header status."
    },
    "item_fk": {
        "type": "lookup", "label": "Item", "editable": True,
        "used_in": ["list", "detail", "search"],
        "lookup_model": "item", "lookup_display": "name",
        "lookup_search": ["ida", "sku", "name"],
        "alice_help": "The catalog item on this line. Source of truth for the item relationship (FK)."
    },
    "item": {
        "type": "json", "label": "Item Details", "editable": True,
        "used_in": ["list", "detail"],
        "alice_help": "Denormalized item snapshot: item_id, description, unit of measure, sequence, line_number. Fast reads."
    },
    "quantity": {
        "type": "json", "label": "Quantity", "editable": True,
        "used_in": ["list", "detail"],
        "alice_help": "Quantity envelope: active (user input), staged (allocated), remaining (available for children). Controls transfers."
    },
    "price": {
        "type": "json", "label": "Price", "editable": True,
        "used_in": ["list", "detail"],
        "alice_help": "Sell price envelope: unit, discount_percent, discount_amount, extended (auto-computed: qty x unit - discount)."
    },
    "cost": {
        "type": "json", "label": "Cost", "editable": True,
        "used_in": ["list", "detail"],
        "alice_help": "Cost envelope: unit, shipping, handling, freight, tax, extended (auto-computed). Feeds margin calculation."
    },
    "commission": {
        "type": "json", "label": "Commission", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Line-level commission configuration and computed amounts."
    },
    "tax": {
        "type": "json", "label": "Tax", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Tax data: sales rate/amount, cost rate/amount, shipping tax, tax service ID."
    },
    "physical": {
        "type": "json", "label": "Physical", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Physical attributes: weight, dimensions, volume, package count, hazmat flag."
    },
}

EXEC_LINE_FIELDS = dict(SELL_LINE_FIELDS)
del EXEC_LINE_FIELDS["price"]  # exec lines have no price envelope

# ─── Organization fields (customer, vendor, manufacturer, rep, employee) ─────
ORG_FIELDS = {
    "org_type": {
        "type": "select", "label": "Organization Type", "editable": True,
        "used_in": ["list", "detail", "filter"],
        "options_source": "choices",
        "options": [
            {"label": "Customer", "value": "customer"},
            {"label": "Vendor", "value": "vendor"},
            {"label": "Rep", "value": "rep"},
            {"label": "Employee", "value": "employee"},
            {"label": "Manufacturer", "value": "manufacturer"},
            {"label": "Other", "value": "other"}
        ],
        "alice_help": "Primary role of this organization. An org can serve multiple roles via refs."
    },
    "display_name": {
        "type": "text", "label": "Company Name", "editable": True,
        "used_in": ["list", "detail", "search"],
        "alice_help": "Primary company/organization name. Required. Cannot be blank."
    },
    "status": {
        "type": "select", "label": "Status", "editable": True,
        "used_in": ["list", "detail", "filter"],
        "options_source": "choices",
        "options": [
            {"label": "Active", "value": "active"},
            {"label": "Default Company", "value": "default_company"},
            {"label": "Prospect", "value": "prospect"},
            {"label": "Suspended", "value": "suspended"},
            {"label": "Inactive", "value": "inactive"},
            {"label": "Retired", "value": "retired"}
        ],
        "alice_help": "Organization lifecycle status. Active = doing business. Prospect = potential. Retired = no longer active."
    },
    "contact": {
        "type": "lookup", "label": "Primary Contact", "editable": True,
        "used_in": ["list", "detail"],
        "lookup_model": "contact", "lookup_display": "attention",
        "lookup_search": ["ida", "email", "name_first", "name_last"],
        "alice_help": "Primary contact person for this organization."
    },
    "attention": {
        "type": "text", "label": "Attention", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Attention line for correspondence. Optional override of contact name."
    },
    "address_id": {
        "type": "number", "label": "Address ID", "editable": False,
        "system_driven": True,
        "used_in": [],
        "alice_help": "FK to the primary Address record. Auto-linked."
    },
    "address_full": {
        "type": "address", "label": "Address", "editable": True, "action": "map",
        "used_in": ["list", "detail"],
        "alice_help": "Denormalized full address for quick display and search."
    },
    "email": {
        "type": "email", "label": "Email", "editable": True, "action": "mailto",
        "used_in": ["list", "detail", "search"],
        "alice_help": "Primary email. Auto-syncs with Email records."
    },
    "email_id": {
        "type": "number", "label": "Email ID", "editable": False,
        "system_driven": True,
        "used_in": [],
        "alice_help": "FK to the primary Email record. Auto-linked."
    },
    "phone": {
        "type": "phone", "label": "Phone", "editable": True, "action": "tel",
        "used_in": ["list", "detail"],
        "alice_help": "Primary phone number. Auto-syncs with Phone records."
    },
    "phone_id": {
        "type": "number", "label": "Phone ID", "editable": False,
        "system_driven": True,
        "used_in": [],
        "alice_help": "FK to the primary Phone record. Auto-linked."
    },
    "domain": {
        "type": "text", "label": "Domain", "editable": True,
        "used_in": ["detail", "search"],
        "alice_help": "Primary web domain for this organization."
    },
    "domain_id": {
        "type": "number", "label": "Domain ID", "editable": False,
        "system_driven": True,
        "used_in": [],
        "alice_help": "FK to the primary Domain record. Auto-linked."
    },
    "price_level": {
        "type": "select", "label": "Price Level", "editable": True,
        "used_in": ["detail", "filter"],
        "options_source": "choices",
        "options": [
            {"label": "Retail", "value": "retail"},
            {"label": "Wholesale", "value": "wholesale"},
            {"label": "Distributor", "value": "distributor"},
            {"label": "Sample", "value": "sample"}
        ],
        "alice_help": "Default pricing tier for this organization. Applied to new transactions."
    },
    "terms": {
        "type": "text", "label": "Terms", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Default payment terms text. Overridden by terms_fk if set."
    },
    "terms_fk": {
        "type": "lookup", "label": "Payment Terms", "editable": True,
        "used_in": ["detail"],
        "lookup_model": "term", "lookup_display": "name",
        "lookup_search": ["name", "ida"],
        "alice_help": "Link to PaymentTerm record. Overrides free-text terms."
    },
    "contacts": {
        "type": "json", "label": "Contacts", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Contact list aspect: [{id, name, role, phones, emails}]. Max 15 entries."
    },
    "addresses": {
        "type": "json", "label": "Addresses", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Address list aspect: [{id, type, address, geo}]. Max 10 entries."
    },
    "domains": {
        "type": "json", "label": "Domains", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Domain list aspect: [{domain, verified, dt_verified}]. Max 10 entries."
    },
    "phones": {
        "type": "json", "label": "Phones", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Phone list aspect: [{id, type, number, ext, primary}]. Max 10 entries."
    },
    "emails": {
        "type": "json", "label": "Emails", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Email list aspect: [{id, type, email, primary, bounce_count}]. Max 10 entries."
    },
    "docs": {
        "type": "json", "label": "Documents", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Document list aspect: [{id, kind, name, size, sha256}]. Max 25 entries."
    },
    "connections": {
        "type": "json", "label": "Connections", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Integration pointers: {email_svc, erp_sync, etc.}. Lightweight external references."
    },
    "relations": {
        "type": "json", "label": "Relations", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Parent/child/partner relationships: {parents:[], children:[], linked_ids:[]}."
    },
    "financial": {
        "type": "json", "label": "Financial", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Type-keyed financial profile: common + org-type-specific sections (credit, aging, sales, margin, commissions)."
    },
    "data": {
        "type": "json", "label": "Data", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Miscellaneous small data (avoid unbounded growth)."
    },
    "metrics": {
        "type": "json", "label": "Metrics", "editable": False,
        "system_driven": True, "computed_by": "metrics_service",
        "used_in": ["detail"],
        "alice_help": "Counters and period aggregates: {counts:{}, periods:{}}. Computed by background jobs."
    },
    "gl_accounts": {
        "type": "json", "label": "GL Accounts", "editable": True,
        "used_in": ["detail"],
        "alice_help": "Default GL account mappings for this org: {sales, expense, receivable, payable, ...}."
    },
}


# ─── Model-specific definitions ─────────────────────────────────────────────

def build_all_models():
    """Return dict of {parent_model: field_behaviors}."""
    models = {}

    # ── Order ────────────────────────────────────────────────────────────
    models["order"] = {**CORE_FIELDS, **TRANSACTION_HEADER_FIELDS}

    # ── Invoice ──────────────────────────────────────────────────────────
    models["invoice"] = {**CORE_FIELDS, **TRANSACTION_HEADER_FIELDS}

    # ── Proposal ─────────────────────────────────────────────────────────
    models["proposal"] = {**CORE_FIELDS, **TRANSACTION_HEADER_FIELDS}

    # ── Purchase ─────────────────────────────────────────────────────────
    models["purchase"] = {**CORE_FIELDS, **TRANSACTION_HEADER_FIELDS}
    # Relabel customer -> override help for purchase context
    models["purchase"]["customer"]["alice_help"] = "Customer org if this purchase is a drop-ship for a customer."
    models["purchase"]["vendor"]["alice_help"] = "The vendor supplying goods on this purchase order."

    # ── Requisition ──────────────────────────────────────────────────────
    models["requisition"] = {**CORE_FIELDS, **TRANSACTION_HEADER_FIELDS}

    # ── Work Order ───────────────────────────────────────────────────────
    models["work_order"] = {**CORE_FIELDS, **TRANSACTION_HEADER_FIELDS}

    # ── Sell-side lines ──────────────────────────────────────────────────
    for line_model in ["order_line", "invoice_line", "proposal_line"]:
        models[line_model] = {**CORE_FIELDS, **SELL_LINE_FIELDS}

    # ── Exec-side lines ──────────────────────────────────────────────────
    for line_model in ["purchase_line", "requisition_line", "work_order_line"]:
        models[line_model] = {**CORE_FIELDS, **EXEC_LINE_FIELDS}

    # ── Customer (proxy of OrgBase) ──────────────────────────────────────
    models["customer"] = {**CORE_FIELDS, **ORG_FIELDS}

    # ── Vendor ───────────────────────────────────────────────────────────
    models["vendor"] = {**CORE_FIELDS, **ORG_FIELDS}

    # ── Manufacturer ─────────────────────────────────────────────────────
    models["manufacturer"] = {**CORE_FIELDS, **ORG_FIELDS}

    # ── Rep ──────────────────────────────────────────────────────────────
    models["rep"] = {**CORE_FIELDS, **ORG_FIELDS}

    # ── Employee ─────────────────────────────────────────────────────────
    models["employee"] = {**CORE_FIELDS, **ORG_FIELDS}

    # ── Item ─────────────────────────────────────────────────────────────
    models["item"] = {
        **CORE_FIELDS,
        "name": {
            "type": "text", "label": "Name", "editable": True,
            "used_in": ["list", "detail", "search"],
            "alice_help": "Primary item name. Required. Displayed in all contexts."
        },
        "sku": {
            "type": "text", "label": "SKU", "editable": True,
            "used_in": ["list", "detail", "search"],
            "alice_help": "Stock keeping unit. Case-insensitive unique within active items. Used for quick lookup."
        },
        "qr_code": {
            "type": "text", "label": "QR Code", "editable": True,
            "used_in": ["detail"],
            "alice_help": "QR/barcode value for scanning. Not necessarily unique."
        },
        "kind": {
            "type": "select", "label": "Kind", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "options_source": "choices",
            "options": [
                {"label": "Physical", "value": "physical"},
                {"label": "Service", "value": "service"},
                {"label": "Bundle", "value": "bundle"}
            ],
            "alice_help": "Item type: Physical (stocked goods), Service (labor/time), Bundle (kit of items)."
        },
        "uom": {
            "type": "text", "label": "Unit of Measure", "editable": True,
            "used_in": ["list", "detail"],
            "alice_help": "Primary unit of measure (EA, HR, KG, etc). Normalized to uppercase on save."
        },
        "base_uom": {
            "type": "text", "label": "Base UOM", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Canonical base unit for conversions when UOM varies (e.g. base=KG, sell in LB)."
        },
        "description": {
            "type": "textarea", "label": "Description", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Full item description. Supports long text."
        },
        "gls": {
            "type": "json", "label": "GL Accounts", "editable": True,
            "used_in": ["detail"],
            "alice_help": "GL account mappings: {inventory, cogs, revenue, purchase, variance}. Auto-seeded from defaults."
        },
        "flags": {
            "type": "json", "label": "Flags", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Operational flags: back_order_allowed, discountable, serialized, not_tracked, print_suppressed, etc."
        },
        "price": {
            "type": "json", "label": "Price", "editable": True,
            "used_in": ["list", "detail"],
            "alice_help": "Pricing: base, msrp, retail/wholesale/distributor/sample levels, qty_breaks, currency, history."
        },
        "cost": {
            "type": "json", "label": "Cost", "editable": True,
            "used_in": ["list", "detail"],
            "alice_help": "Cost: standard, last receipt, moving average, landed, components, qty_breaks, currency, history."
        },
        "tax_code": {
            "type": "json", "label": "Tax Code", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Tax metadata: code, jurisdiction, category, rate, exemptions. jurisdiction_params for localized rules."
        },
        "specification_id": {
            "type": "number", "label": "Specification ID", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Link to a specification document."
        },
        "catalog": {
            "type": "json", "label": "Catalog", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Catalog placement: categories, attributes, web (slug/title/SEO), flags (featured/seasonal)."
        },
        "quantity": {
            "type": "json", "label": "Quantity", "editable": True,
            "used_in": ["list", "detail"],
            "alice_help": "Inventory status: on_hand, allocated, available, on_so, on_po. Available = on_hand - allocated."
        },
        "vendor": {
            "type": "lookup", "label": "Primary Vendor", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "lookup_model": "vendor", "lookup_display": "display_name",
            "lookup_search": ["ida", "display_name"],
            "alice_help": "Primary vendor/supplier for this item."
        },
        "manufacturer": {
            "type": "lookup", "label": "Manufacturer", "editable": True,
            "used_in": ["detail", "filter"],
            "lookup_model": "manufacturer", "lookup_display": "display_name",
            "lookup_search": ["ida", "display_name"],
            "alice_help": "Manufacturer of this item."
        },
        "row_version": {
            "type": "readonly", "label": "Row Version", "editable": False,
            "system_driven": True, "computed_by": "database",
            "used_in": [],
            "alice_help": "Optimistic concurrency version for item-specific conflict detection."
        },
        "stats": {
            "type": "json", "label": "Statistics", "editable": False,
            "system_driven": True, "computed_by": "stats_service",
            "used_in": ["detail"],
            "alice_help": "Computed statistics: velocity, turns, margin metrics. Updated by background jobs."
        },
    }

    # ── Contact ──────────────────────────────────────────────────────────
    models["contact"] = {
        **CORE_FIELDS,
        "name_first": {
            "type": "text", "label": "First Name", "editable": True,
            "used_in": ["list", "detail", "search"],
            "alice_help": "First/given name. Required for user creation."
        },
        "name_last": {
            "type": "text", "label": "Last Name", "editable": True,
            "used_in": ["list", "detail", "search"],
            "alice_help": "Last/family name. Required for user creation."
        },
        "name_middle": {
            "type": "text", "label": "Middle Name", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Middle name. Optional."
        },
        "name_prefix": {
            "type": "text", "label": "Prefix", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Title prefix (Mr., Ms., Dr.)."
        },
        "name_suffix": {
            "type": "text", "label": "Suffix", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Name suffix (Jr., Sr., III)."
        },
        "attention": {
            "type": "readonly", "label": "Attention", "editable": False,
            "system_driven": True, "computed_by": "save",
            "used_in": ["list", "detail", "search"],
            "alice_help": "Auto-filled from first + last name on save. Used as display name."
        },
        "email": {
            "type": "email", "label": "Email", "editable": True, "action": "mailto",
            "used_in": ["list", "detail", "search"],
            "alice_help": "Primary email. Unique. Used as login username."
        },
        "email_id": {
            "type": "number", "label": "Email ID", "editable": False,
            "system_driven": True,
            "used_in": [],
            "alice_help": "FK to primary Email record. Auto-linked on save."
        },
        "address_full": {
            "type": "address", "label": "Address", "editable": True, "action": "map",
            "used_in": ["detail"],
            "alice_help": "Denormalized full address for display."
        },
        "address_id": {
            "type": "number", "label": "Address ID", "editable": False,
            "system_driven": True,
            "used_in": [],
            "alice_help": "FK to primary Address record. Auto-linked on save."
        },
        "phone": {
            "type": "phone", "label": "Phone", "editable": True, "action": "tel",
            "used_in": ["list", "detail"],
            "alice_help": "Primary phone number."
        },
        "phone_id": {
            "type": "number", "label": "Phone ID", "editable": False,
            "system_driven": True,
            "used_in": [],
            "alice_help": "FK to primary Phone record. Auto-linked on save."
        },
        "domain": {
            "type": "text", "label": "Domain", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Primary domain extracted from email for search."
        },
        "domain_id": {
            "type": "number", "label": "Domain ID", "editable": False,
            "system_driven": True,
            "used_in": [],
            "alice_help": "FK to primary Domain record. Auto-linked on save."
        },
        "company": {
            "type": "text", "label": "Company", "editable": True,
            "used_in": ["list", "detail", "search"],
            "alice_help": "Company name. Auto-synced from customer org display_name."
        },
        "title": {
            "type": "text", "label": "Job Title", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Job title/position at their company."
        },
        "department": {
            "type": "text", "label": "Department", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Department within their company."
        },
        "comment": {
            "type": "textarea", "label": "Notes", "editable": True,
            "used_in": ["detail"],
            "alice_help": "General notes about this contact. Free text."
        },
        "employee": {
            "type": "lookup", "label": "Employee Org", "editable": True,
            "used_in": ["detail"],
            "lookup_model": "employee", "lookup_display": "display_name",
            "lookup_search": ["ida", "display_name"],
            "alice_help": "Associated employee organization."
        },
        "customer": {
            "type": "lookup", "label": "Customer Org", "editable": True,
            "used_in": ["detail", "filter"],
            "lookup_model": "customer", "lookup_display": "display_name",
            "lookup_search": ["ida", "display_name"],
            "alice_help": "Associated customer organization."
        },
        "vendor": {
            "type": "lookup", "label": "Vendor Org", "editable": True,
            "used_in": ["detail"],
            "lookup_model": "vendor", "lookup_display": "display_name",
            "lookup_search": ["ida", "display_name"],
            "alice_help": "Associated vendor organization."
        },
        "manufacturer": {
            "type": "lookup", "label": "Manufacturer Org", "editable": True,
            "used_in": ["detail"],
            "lookup_model": "manufacturer", "lookup_display": "display_name",
            "lookup_search": ["ida", "display_name"],
            "alice_help": "Associated manufacturer organization."
        },
        "rep": {
            "type": "lookup", "label": "Rep Org", "editable": True,
            "used_in": ["detail"],
            "lookup_model": "rep", "lookup_display": "display_name",
            "lookup_search": ["ida", "display_name"],
            "alice_help": "Associated sales rep organization."
        },
        "role": {
            "type": "select", "label": "Role", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "options_source": "choices",
            "options": [
                {"label": "User", "value": "user"},
                {"label": "Employee", "value": "employee"},
                {"label": "Admin", "value": "admin"}
            ],
            "alice_help": "System role. Admin gets full access. Employee can access admin. User is standard."
        },
        "is_staff": {
            "type": "boolean", "label": "Staff", "editable": True,
            "used_in": ["detail", "filter"],
            "alice_help": "Whether this contact can access the admin interface."
        },
        "dt_joined": {
            "type": "timestamp", "label": "Date Joined", "editable": False,
            "system_driven": True, "computed_by": "database",
            "used_in": ["detail"],
            "alice_help": "When this account was created (Django datetime)."
        },
    }

    # ── GL Account ───────────────────────────────────────────────────────
    models["gl_account"] = {
        **CORE_FIELDS,
        "account_number": {
            "type": "text", "label": "Account Number", "editable": True,
            "used_in": ["list", "detail", "search"],
            "alice_help": "GL account number (e.g. 10100-000-000). Must be unique among active accounts."
        },
        "name": {
            "type": "text", "label": "Account Name", "editable": True,
            "used_in": ["list", "detail", "search"],
            "alice_help": "Descriptive name (e.g. Cash, Accounts Receivable, Sales Revenue)."
        },
        "type": {
            "type": "select", "label": "Account Type", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "options_source": "choices",
            "options": [
                {"label": "Asset", "value": "asset"},
                {"label": "Liability", "value": "liability"},
                {"label": "Equity", "value": "equity"},
                {"label": "Revenue", "value": "revenue"},
                {"label": "Expense", "value": "expense"},
                {"label": "Contra", "value": "contra"}
            ],
            "alice_help": "Fundamental account classification. Determines debit/credit normal balance."
        },
        "category": {
            "type": "select", "label": "Category", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "options_source": "choices",
            "options": [
                {"label": "Cash", "value": "cash"},
                {"label": "Accounts Receivable", "value": "receivables"},
                {"label": "Accounts Payable", "value": "payables"},
                {"label": "Inventory", "value": "inventory"},
                {"label": "Sales", "value": "sales"},
                {"label": "Cost of Goods Sold", "value": "cogs"},
                {"label": "Expense", "value": "expense"},
                {"label": "Other", "value": "other"}
            ],
            "alice_help": "Grouping category for chart of accounts display and reporting."
        },
        "type_id": {
            "type": "text", "label": "Type ID", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Product type/category ID for sales/COGS accounts mapping."
        },
        "account_credit": {
            "type": "text", "label": "Default Credit Account", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Default credit-side account number for journal entries using this account."
        },
        "account_debit": {
            "type": "text", "label": "Default Debit Account", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Default debit-side account number for journal entries using this account."
        },
        "used_for": {
            "type": "select", "label": "Used For", "editable": True,
            "used_in": ["detail", "filter"],
            "options_source": "choices",
            "options": [
                {"label": "Posting", "value": "posting"},
                {"label": "Reporting", "value": "reporting"},
                {"label": "Tax", "value": "tax"},
                {"label": "Consolidation", "value": "consolidation"},
                {"label": "Other", "value": "other"}
            ],
            "alice_help": "Usage classification: Posting (accepts entries), Reporting (aggregate only), Tax, Consolidation."
        },
        "division": {
            "type": "number", "label": "Division", "editable": True,
            "used_in": ["detail", "filter"],
            "alice_help": "Division or department code for multi-division reporting."
        },
        "comment": {
            "type": "textarea", "label": "Comment", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Notes or description about this GL account."
        },
    }

    # ── GL Journal ───────────────────────────────────────────────────────
    models["gl_journal"] = {
        **CORE_FIELDS,
        "account": {
            "type": "text", "label": "Account", "editable": True,
            "used_in": ["list", "detail", "search"],
            "alice_help": "GL account number this entry posts to."
        },
        "credit": {
            "type": "currency", "label": "Credit", "editable": True,
            "used_in": ["list", "detail"],
            "alice_help": "Credit amount. Only one of credit/debit should be non-zero per entry."
        },
        "debit": {
            "type": "currency", "label": "Debit", "editable": True,
            "used_in": ["list", "detail"],
            "alice_help": "Debit amount. Only one of credit/debit should be non-zero per entry."
        },
        "source": {
            "type": "select", "label": "Source", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "options_source": "choices",
            "options": [
                {"label": "Manual Entry", "value": "manual"},
                {"label": "Imported", "value": "import"},
                {"label": "Automation", "value": "automation"},
                {"label": "Adjustment", "value": "adjustment"},
                {"label": "Integration", "value": "integration"}
            ],
            "alice_help": "How this entry was created: manual, import, automation, adjustment, integration."
        },
        "type": {
            "type": "select", "label": "Journal Type", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "options_source": "choices",
            "options": [
                {"label": "General", "value": "general"},
                {"label": "Sales", "value": "sales"},
                {"label": "Purchase", "value": "purchase"},
                {"label": "Payroll", "value": "payroll"},
                {"label": "Inventory", "value": "inventory"},
                {"label": "Other", "value": "other"}
            ],
            "alice_help": "Journal classification: general, sales, purchase, payroll, inventory."
        },
        "source_id": {
            "type": "number", "label": "Source ID", "editable": False,
            "system_driven": True,
            "used_in": ["detail"],
            "alice_help": "ID of the record that generated this journal entry (traceability)."
        },
        "source_model": {
            "type": "text", "label": "Source Model", "editable": False,
            "system_driven": True,
            "used_in": ["detail"],
            "alice_help": "Model name of the record that generated this entry (e.g. invoice, payment)."
        },
    }

    # ── Action ───────────────────────────────────────────────────────────
    models["action"] = {
        **CORE_FIELDS,
        "parent_action": {
            "type": "lookup", "label": "Parent Action", "editable": True,
            "used_in": ["detail"],
            "lookup_model": "action", "lookup_display": "ida",
            "lookup_search": ["ida", "uuid"],
            "alice_help": "Parent action for hierarchical task breakdown."
        },
        "action": {
            "type": "json", "label": "Title", "editable": True,
            "used_in": ["list", "detail", "search"],
            "alice_help": "Multilingual action title: {en: 'Do X', es: 'Hacer X'}."
        },
        "description": {
            "type": "json", "label": "Description", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Multilingual description: {en: 'Details...', es: 'Detalles...'}."
        },
        "assigned_to": {
            "type": "json", "label": "Assigned To", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "alice_help": "List of assignees: [{id, name, email}]. First entry is primary."
        },
        "contact_id": {
            "type": "number", "label": "Contact ID", "editable": False,
            "system_driven": True, "computed_by": "save",
            "used_in": ["detail", "filter"],
            "alice_help": "Resolved contact ID from assigned_to. Auto-populated on save."
        },
        "languages": {
            "type": "json", "label": "Languages", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Supported language codes for this action (e.g. ['en', 'es'])."
        },
        "project_name": {
            "type": "text", "label": "Project", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "alice_help": "Name of the project this action belongs to."
        },
        "project_id": {
            "type": "number", "label": "Project ID", "editable": True,
            "used_in": ["detail", "filter"],
            "alice_help": "ID of the parent project."
        },
        "project_ida": {
            "type": "text", "label": "Project IDA", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Human-readable project identifier."
        },
        "sequence": {
            "type": "number", "label": "Sequence", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Display order within a kanban column or list."
        },
        "kanban_column": {
            "type": "select", "label": "Kanban Column", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "options_source": "choices",
            "options": [
                {"label": "Backlog", "value": "Backlog"},
                {"label": "Planning", "value": "Planning"},
                {"label": "InProcess", "value": "InProcess"},
                {"label": "Review", "value": "Review"},
                {"label": "Complete", "value": "Complete"}
            ],
            "alice_help": "Kanban board position. Drag actions between columns to update workflow state."
        },
        "priority": {
            "type": "number", "label": "Priority", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "alice_help": "Priority ranking (1 = highest). Used for sorting within columns."
        },
        "difficulty": {
            "type": "select", "label": "Difficulty", "editable": True,
            "used_in": ["list", "detail"],
            "options_source": "choices",
            "options": [
                {"label": "100", "value": 100},
                {"label": "50", "value": 50},
                {"label": "15", "value": 15},
                {"label": "10", "value": 10},
                {"label": "4", "value": 4},
                {"label": "1", "value": 1}
            ],
            "alice_help": "Effort estimate in story points. Higher = more work. Used for burndown calculation."
        },
        "status": {
            "type": "text", "label": "Status", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "alice_help": "Free-text status indicator. Independent of kanban_column."
        },
        "percent_complete": {
            "type": "number", "label": "% Complete", "editable": True,
            "used_in": ["list", "detail"],
            "alice_help": "Completion percentage (0-100). Used with difficulty for burndown."
        },
        "burndown": {
            "type": "number", "label": "Burndown", "editable": False,
            "system_driven": True, "computed_by": "save",
            "used_in": ["detail"],
            "alice_help": "Computed burndown value from difficulty and percent_complete."
        },
        "dt_start": {
            "type": "timestamp", "label": "Start Date", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "alice_help": "When work should begin (UTC epoch ms). Auto-set from project if blank."
        },
        "dt_deadline": {
            "type": "timestamp", "label": "Deadline", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "alice_help": "When work must be complete (UTC epoch ms). Computed from dt_start + duration if not set."
        },
        "dt_expected": {
            "type": "timestamp", "label": "Expected", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Expected completion date (UTC epoch ms). Can differ from deadline."
        },
        "dt_completed": {
            "type": "timestamp", "label": "Completed", "editable": True,
            "used_in": ["list", "detail"],
            "alice_help": "Actual completion date (UTC epoch ms)."
        },
        "dt_updated": {
            "type": "timestamp", "label": "Updated", "editable": False,
            "system_driven": True,
            "used_in": ["detail"],
            "alice_help": "Last significant update timestamp."
        },
        "duration": {
            "type": "number", "label": "Duration (days)", "editable": True,
            "used_in": ["list", "detail"],
            "alice_help": "Duration in days. Used to compute dt_deadline = dt_start + duration."
        },
        "dt_start_original": {
            "type": "timestamp", "label": "Original Start", "editable": False,
            "used_in": ["detail"],
            "alice_help": "Original planned start for baseline comparison."
        },
        "dt_end_original": {
            "type": "timestamp", "label": "Original End", "editable": False,
            "used_in": ["detail"],
            "alice_help": "Original planned end for baseline comparison."
        },
        "created_by": {
            "type": "json", "label": "Created By", "editable": False,
            "system_driven": True,
            "used_in": ["detail"],
            "alice_help": "Audit trail: who created this action [{id, email, dt}]."
        },
        "updated_by": {
            "type": "json", "label": "Updated By", "editable": False,
            "system_driven": True,
            "used_in": ["detail"],
            "alice_help": "Audit trail: who last updated [{id, email, dt}]."
        },
        "completed_by": {
            "type": "json", "label": "Completed By", "editable": False,
            "system_driven": True,
            "used_in": ["detail"],
            "alice_help": "Audit trail: who completed [{id, email, dt}]."
        },
        "start_by": {"type": "json", "label": "Start By", "editable": False, "system_driven": True, "used_in": ["detail"], "alice_help": "Audit: who started."},
        "deadline_by": {"type": "json", "label": "Deadline By", "editable": False, "system_driven": True, "used_in": ["detail"], "alice_help": "Audit: who set deadline."},
        "expected_by": {"type": "json", "label": "Expected By", "editable": False, "system_driven": True, "used_in": ["detail"], "alice_help": "Audit: who set expected."},
        "end_by": {"type": "json", "label": "End By", "editable": False, "system_driven": True, "used_in": ["detail"], "alice_help": "Audit: who ended."},
        "linkage": {
            "type": "number", "label": "Linkage", "editable": True,
            "used_in": ["detail"],
            "alice_help": "LinkageEntry group ID for cross-model document attachments."
        },
        "project_metadata": {
            "type": "json", "label": "Project Metadata", "editable": True,
            "used_in": ["detail"],
            "alice_help": "Additional project-related data (child names, meta, history)."
        },
    }

    # ── Setting ──────────────────────────────────────────────────────────
    models["setting"] = {
        **CORE_FIELDS,
        "name": {
            "type": "text", "label": "Name", "editable": True,
            "used_in": ["list", "detail", "search"],
            "alice_help": "Human-readable setting name."
        },
        "purpose": {
            "type": "select", "label": "Purpose", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "options_source": "choices",
            "options": [
                {"label": "View/Edit", "value": "view_edit"},
                {"label": "Constants", "value": "constants"},
                {"label": "DB Defaults", "value": "db_defaults"},
                {"label": "Sales Defaults", "value": "sales_defaults"},
                {"label": "Purchase Defaults", "value": "purchase_defaults"},
                {"label": "Accounting Defaults", "value": "accounting_defaults"},
                {"label": "Keywords", "value": "keywords"},
                {"label": "Search", "value": "search"},
                {"label": "Workbench Fields", "value": "workbench_fields"},
                {"label": "Detail Field Access", "value": "detail_field_access"},
                {"label": "QA Counters", "value": "qa_counters"},
                {"label": "QA Questions", "value": "qa_questions"},
                {"label": "Admin", "value": "admin"},
                {"label": "Admin Select List", "value": "admin_selectlist"},
                {"label": "React Settings", "value": "React_settings"},
                {"label": "List Column Config", "value": "list_column_config"},
                {"label": "Alice Pending", "value": "alice_pending"},
                {"label": "Alice Log", "value": "alice_log"},
                {"label": "Field Access", "value": "field_access"},
                {"label": "Seed", "value": "seed"},
                {"label": "Alice Coaching", "value": "alice_coaching"},
                {"label": "Campaign", "value": "campaign"}
            ],
            "alice_help": "What this setting controls. field_access = UI behavior. workbench_fields = list columns. keywords = search indexing."
        },
        "role": {
            "type": "text", "label": "Role", "editable": True,
            "used_in": ["detail", "filter"],
            "alice_help": "Role this setting applies to (admin, sales, rep, etc). Blank = all roles."
        },
        "parent_model": {
            "type": "text", "label": "Parent Model", "editable": True,
            "used_in": ["list", "detail", "filter"],
            "alice_help": "Canonical model name this setting belongs to (e.g. order, item, contact)."
        },
        "data": {
            "type": "json", "label": "Data", "editable": True,
            "used_in": ["detail"],
            "alice_help": "The setting payload. Structure depends on purpose."
        },
    }

    # ── Remaining models with basic CoreModel + type inference ────────────
    # These get CORE_FIELDS plus any model-specific fields with basic types

    basic_models = {
        "address": {
            "address1": {"type": "text", "label": "Address Line 1", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Street address line 1."},
            "address2": {"type": "text", "label": "Address Line 2", "editable": True, "used_in": ["detail"], "alice_help": "Street address line 2 (apt, suite, etc)."},
            "city": {"type": "text", "label": "City", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "City name."},
            "state": {"type": "text", "label": "State", "editable": True, "used_in": ["list", "detail", "filter"], "alice_help": "State/province code."},
            "zip": {"type": "text", "label": "ZIP", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Postal/ZIP code."},
            "country": {"type": "text", "label": "Country", "editable": True, "used_in": ["detail", "filter"], "alice_help": "Country code."},
            "full": {"type": "text", "label": "Full Address", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Complete denormalized address."},
            "address_type": {"type": "text", "label": "Type", "editable": True, "used_in": ["list", "detail"], "alice_help": "Address type (billing, shipping, etc)."},
            "contact": {"type": "lookup", "label": "Contact", "editable": True, "used_in": ["detail"], "lookup_model": "contact", "lookup_display": "attention", "lookup_search": ["ida", "email"], "alice_help": "Contact this address belongs to."},
        },
        "audit": {
            "table_name": {"type": "text", "label": "Table", "editable": False, "used_in": ["list", "detail", "filter"], "alice_help": "Which table this audit entry tracks."},
            "record_id": {"type": "number", "label": "Record ID", "editable": False, "used_in": ["list", "detail"], "alice_help": "ID of the audited record."},
            "field_name": {"type": "text", "label": "Field", "editable": False, "used_in": ["list", "detail"], "alice_help": "Which field changed."},
            "old_value": {"type": "json", "label": "Old Value", "editable": False, "used_in": ["detail"], "alice_help": "Value before the change."},
            "new_value": {"type": "json", "label": "New Value", "editable": False, "used_in": ["detail"], "alice_help": "Value after the change."},
            "changed_by": {"type": "number", "label": "Changed By", "editable": False, "used_in": ["detail"], "alice_help": "Contact ID of who made the change."},
        },
        "bill_of_material": {
            "parent_item": {"type": "lookup", "label": "Parent Item", "editable": True, "used_in": ["list", "detail"], "lookup_model": "item", "lookup_display": "name", "lookup_search": ["ida", "sku", "name"], "alice_help": "The assembled/parent item."},
            "child_item": {"type": "lookup", "label": "Component Item", "editable": True, "used_in": ["list", "detail"], "lookup_model": "item", "lookup_display": "name", "lookup_search": ["ida", "sku", "name"], "alice_help": "The component item required."},
            "quantity": {"type": "number", "label": "Quantity", "editable": True, "used_in": ["list", "detail"], "alice_help": "How many of the component are needed per parent."},
        },
        "catalog": {
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Catalog name."},
            "description": {"type": "textarea", "label": "Description", "editable": True, "used_in": ["detail"], "alice_help": "Catalog description."},
        },
        "connection": {
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail"], "alice_help": "Connection name."},
            "type": {"type": "text", "label": "Type", "editable": True, "used_in": ["list", "detail", "filter"], "alice_help": "Connection type."},
            "config": {"type": "json", "label": "Config", "editable": True, "used_in": ["detail"], "alice_help": "Connection configuration."},
        },
        "currency": {
            "code": {"type": "text", "label": "Code", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "ISO 4217 currency code (USD, EUR, etc)."},
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail"], "alice_help": "Currency name."},
            "symbol": {"type": "text", "label": "Symbol", "editable": True, "used_in": ["list", "detail"], "alice_help": "Currency symbol ($, etc)."},
        },
        "delivery_visit": {
            "status": {"type": "select", "label": "Status", "editable": True, "used_in": ["list", "detail", "filter"], "options_source": "choices", "options": [{"label": "Planned", "value": "planned"}, {"label": "En Route", "value": "en_route"}, {"label": "Arrived", "value": "arrived"}, {"label": "Closed", "value": "closed"}, {"label": "Canceled", "value": "canceled"}], "alice_help": "Delivery visit status."},
        },
        "delivery_line": {
            "status": {"type": "select", "label": "Status", "editable": True, "used_in": ["list", "detail", "filter"], "options_source": "choices", "options": [{"label": "Planned", "value": "planned"}, {"label": "Loaded", "value": "loaded"}, {"label": "Delivered", "value": "delivered"}, {"label": "Skipped", "value": "skipped"}, {"label": "Partial", "value": "partial"}], "alice_help": "Line delivery status."},
        },
        "doc": {
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Document name."},
            "path": {"type": "text", "label": "Path", "editable": True, "used_in": ["detail"], "alice_help": "File path or URL."},
        },
        "document": {
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Document name."},
            "path": {"type": "text", "label": "Path", "editable": True, "used_in": ["detail"], "alice_help": "File storage path."},
            "file_type": {"type": "text", "label": "File Type", "editable": False, "used_in": ["list", "detail", "filter"], "alice_help": "MIME type or extension."},
            "file_size": {"type": "number", "label": "Size", "editable": False, "used_in": ["detail"], "alice_help": "File size in bytes."},
        },
        "domain": {
            "path": {"type": "text", "label": "Domain", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Domain path (e.g. example.com)."},
            "type": {"type": "text", "label": "Type", "editable": True, "used_in": ["detail"], "alice_help": "Domain type (website, social, etc)."},
            "status": {"type": "text", "label": "Status", "editable": True, "used_in": ["detail"], "alice_help": "Domain status."},
            "contact": {"type": "lookup", "label": "Contact", "editable": True, "used_in": ["detail"], "lookup_model": "contact", "lookup_display": "attention", "lookup_search": ["ida", "email"], "alice_help": "Contact who owns this domain."},
        },
        "email": {
            "email": {"type": "email", "label": "Email", "editable": True, "action": "mailto", "used_in": ["list", "detail", "search"], "alice_help": "Email address."},
            "name": {"type": "text", "label": "Label", "editable": True, "used_in": ["detail"], "alice_help": "Label (account, work, personal, etc)."},
            "is_primary": {"type": "boolean", "label": "Primary", "editable": True, "used_in": ["list", "detail"], "alice_help": "Whether this is the primary email."},
            "is_verified": {"type": "boolean", "label": "Verified", "editable": True, "used_in": ["detail"], "alice_help": "Whether email has been verified."},
            "opt_out": {"type": "text", "label": "Opt Out", "editable": True, "used_in": ["detail"], "alice_help": "Opt-out preference."},
            "contact": {"type": "lookup", "label": "Contact", "editable": True, "used_in": ["detail"], "lookup_model": "contact", "lookup_display": "attention", "lookup_search": ["ida", "email"], "alice_help": "Contact who owns this email."},
        },
        "exchange_rate": {
            "from_currency": {"type": "text", "label": "From", "editable": True, "used_in": ["list", "detail"], "alice_help": "Source currency code."},
            "to_currency": {"type": "text", "label": "To", "editable": True, "used_in": ["list", "detail"], "alice_help": "Target currency code."},
            "rate": {"type": "number", "label": "Rate", "editable": True, "used_in": ["list", "detail"], "alice_help": "Exchange rate multiplier."},
        },
        "exchange_transaction": {
            "amount": {"type": "currency", "label": "Amount", "editable": True, "used_in": ["list", "detail"], "alice_help": "Transaction amount."},
            "from_currency": {"type": "text", "label": "From", "editable": True, "used_in": ["list", "detail"], "alice_help": "Source currency."},
            "to_currency": {"type": "text", "label": "To", "editable": True, "used_in": ["list", "detail"], "alice_help": "Target currency."},
        },
        "inventory_adjustment_run": {
            "run_type": {"type": "text", "label": "Run Type", "editable": True, "used_in": ["list", "detail"], "alice_help": "Type of adjustment run."},
        },
        "inventory_check": {
            "status": {"type": "select", "label": "Status", "editable": True, "used_in": ["list", "detail", "filter"], "options_source": "choices", "options": [{"label": "Planned", "value": "planned"}, {"label": "In Progress", "value": "in_progress"}, {"label": "Completed", "value": "completed"}, {"label": "Canceled", "value": "canceled"}], "alice_help": "Inventory check lifecycle."},
        },
        "inventory_check_line": {
            "item_fk": {"type": "lookup", "label": "Item", "editable": True, "used_in": ["list", "detail"], "lookup_model": "item", "lookup_display": "name", "lookup_search": ["ida", "sku", "name"], "alice_help": "Item being checked."},
            "expected_qty": {"type": "number", "label": "Expected", "editable": False, "used_in": ["list", "detail"], "alice_help": "System-recorded quantity."},
            "actual_qty": {"type": "number", "label": "Actual", "editable": True, "used_in": ["list", "detail"], "alice_help": "Counted quantity."},
        },
        "inventory_metrics_snapshot": {},
        "inventory_reservation": {
            "state": {"type": "select", "label": "State", "editable": True, "used_in": ["list", "detail", "filter"], "options_source": "choices", "options": [{"label": "Pending", "value": "pending"}, {"label": "Committed", "value": "committed"}, {"label": "Canceled", "value": "canceled"}, {"label": "Expired", "value": "expired"}], "alice_help": "Reservation lifecycle state."},
        },
        "item_usage": {},
        "item_xref": {
            "source": {"type": "select", "label": "Source", "editable": True, "used_in": ["list", "detail", "filter"], "options_source": "choices", "options": [{"label": "Manufacturer", "value": "manufacturer"}, {"label": "Wholesaler", "value": "wholesaler"}, {"label": "Other", "value": "other"}], "alice_help": "Cross-reference source type."},
            "external_id": {"type": "text", "label": "External ID", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "External system identifier for this item."},
        },
        "ledger": {
            "source": {"type": "text", "label": "Source", "editable": True, "used_in": ["list", "detail", "filter"], "alice_help": "Ledger entry source."},
            "model_name": {"type": "text", "label": "Model", "editable": True, "used_in": ["detail"], "alice_help": "Source model name."},
            "amount": {"type": "currency", "label": "Amount", "editable": True, "used_in": ["list", "detail"], "alice_help": "Ledger entry amount."},
        },
        "notification": {
            "title": {"type": "text", "label": "Title", "editable": True, "used_in": ["list", "detail"], "alice_help": "Notification title."},
            "message": {"type": "textarea", "label": "Message", "editable": True, "used_in": ["detail"], "alice_help": "Notification message body."},
            "is_read": {"type": "boolean", "label": "Read", "editable": True, "used_in": ["list", "detail", "filter"], "alice_help": "Whether notification has been read."},
        },
        "org_item": {
            "availability_state": {"type": "select", "label": "Availability", "editable": True, "used_in": ["list", "detail", "filter"], "options_source": "choices", "options": [{"label": "Enabled", "value": "enabled"}, {"label": "Paused", "value": "paused"}, {"label": "Retired", "value": "retired"}], "alice_help": "Item availability for this org."},
        },
        "pending_inventory_adjustment": {
            "state": {"type": "select", "label": "State", "editable": True, "used_in": ["list", "detail", "filter"], "options_source": "choices", "options": [{"label": "Pending", "value": "pending"}, {"label": "Applied", "value": "applied"}, {"label": "Canceled", "value": "canceled"}], "alice_help": "Adjustment state."},
        },
        "phone": {
            "number": {"type": "phone", "label": "Number", "editable": True, "action": "tel", "used_in": ["list", "detail", "search"], "alice_help": "Phone number."},
            "name": {"type": "text", "label": "Label", "editable": True, "used_in": ["detail"], "alice_help": "Phone label (primary, mobile, etc)."},
            "country_code": {"type": "text", "label": "Country Code", "editable": True, "used_in": ["detail"], "alice_help": "International dialing code."},
            "contact": {"type": "lookup", "label": "Contact", "editable": True, "used_in": ["detail"], "lookup_model": "contact", "lookup_display": "attention", "lookup_search": ["ida", "email"], "alice_help": "Contact who owns this phone."},
        },
        "project_association": {
            "model_code": {"type": "select", "label": "Model", "editable": True, "used_in": ["list", "detail"], "options_source": "choices", "options": [{"label": "Proposal", "value": "proposal"}, {"label": "Order", "value": "order"}, {"label": "Invoice", "value": "invoice"}, {"label": "Purchase", "value": "purchase"}, {"label": "Work Order", "value": "workorder"}, {"label": "Requisition", "value": "requisition"}], "alice_help": "Which transaction type is linked to the project."},
        },
        "question_answer": {
            "question": {"type": "textarea", "label": "Question", "editable": True, "used_in": ["list", "detail"], "alice_help": "The question text."},
            "answer": {"type": "textarea", "label": "Answer", "editable": True, "used_in": ["list", "detail"], "alice_help": "The answer text."},
        },
        "report": {
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Report name."},
            "output_type": {"type": "select", "label": "Output Type", "editable": True, "used_in": ["list", "detail", "filter"], "options_source": "choices", "options": [{"label": "Print / PDF", "value": "print"}, {"label": "Email (SMTP)", "value": "email"}, {"label": "POST to endpoint", "value": "api"}, {"label": "JSON", "value": "json"}, {"label": "CSV / Excel", "value": "export"}, {"label": "Label / barcode", "value": "label"}, {"label": "Word / spreadsheet merge", "value": "merge"}], "alice_help": "How this report is delivered."},
            "category": {"type": "select", "label": "Category", "editable": True, "used_in": ["list", "detail", "filter"], "options_source": "choices", "options": [{"label": "Report", "value": "report"}, {"label": "Statement", "value": "statement"}, {"label": "List", "value": "list"}, {"label": "Summary", "value": "summary"}, {"label": "Letter / Email", "value": "letter"}, {"label": "Label", "value": "label"}, {"label": "Export", "value": "export"}, {"label": "Utility", "value": "utility"}], "alice_help": "Report classification."},
        },
        "serial_log": {
            "serial_number": {"type": "text", "label": "Serial Number", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Serial number being tracked."},
        },
        "service": {
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Service name."},
        },
        "sync_bundle": {},
        "tag": {
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Tag name."},
        },
        "tax_jurisdiction": {
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Tax jurisdiction name."},
            "rate": {"type": "number", "label": "Rate", "editable": True, "used_in": ["list", "detail"], "alice_help": "Tax rate percentage."},
        },
        "template": {
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Template name."},
            "content": {"type": "textarea", "label": "Content", "editable": True, "used_in": ["detail"], "alice_help": "Template content."},
        },
        "term": {
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Payment term name (e.g. Net 30, COD)."},
            "days": {"type": "number", "label": "Days", "editable": True, "used_in": ["list", "detail"], "alice_help": "Number of days until payment is due."},
        },
        "variant": {
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Variant name."},
            "item_fk": {"type": "lookup", "label": "Item", "editable": True, "used_in": ["list", "detail"], "lookup_model": "item", "lookup_display": "name", "lookup_search": ["ida", "sku", "name"], "alice_help": "Parent item."},
        },
        "warehouse": {
            "name": {"type": "text", "label": "Name", "editable": True, "used_in": ["list", "detail", "search"], "alice_help": "Warehouse name."},
            "code": {"type": "text", "label": "Code", "editable": True, "used_in": ["list", "detail"], "alice_help": "Warehouse code."},
        },
    }

    for model_name, specific_fields in basic_models.items():
        models[model_name] = {**CORE_FIELDS, **specific_fields}

    return models


def run_update(dry_run=False):
    all_models = build_all_models()

    success = 0
    errors = 0

    for parent_model, field_behaviors in sorted(all_models.items()):
        fb_json = json.dumps(field_behaviors, separators=(',', ':'))
        # Escape single quotes for SQL
        fb_sql = fb_json.replace("'", "''")

        sql = f"""
UPDATE settings
SET data = jsonb_set(COALESCE(data, '{{}}'::jsonb), '{{field_behaviors}}', '{fb_sql}'::jsonb)
WHERE parent_model = '{parent_model}' AND purpose = 'field_access';
"""
        if dry_run:
            print(f"-- {parent_model}: {len(field_behaviors)} fields")
            continue

        result = subprocess.run(
            ["psql", "-h", "localhost", "-U", "williamjames", "-d", "commerce_expert",
             "-c", sql],
            capture_output=True, text=True
        )

        if result.returncode == 0:
            # Parse UPDATE count
            output = result.stdout.strip()
            if "UPDATE" in output:
                count = output.split()[-1] if output else "0"
                if count != "0":
                    print(f"  {parent_model}: {len(field_behaviors)} fields - updated {count} row(s)")
                    success += 1
                else:
                    print(f"  {parent_model}: no matching field_access Setting found")
            else:
                print(f"  {parent_model}: {output}")
                success += 1
        else:
            print(f"  ERROR {parent_model}: {result.stderr.strip()}")
            errors += 1

    print(f"\nDone: {success} updated, {errors} errors, {len(all_models)} total models processed")


if __name__ == "__main__":
    dry_run = "--dry-run" in sys.argv
    if dry_run:
        print("=== DRY RUN ===")
    run_update(dry_run=dry_run)
