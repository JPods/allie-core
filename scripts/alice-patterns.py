#!/usr/bin/env python3
"""Alice Pattern Detection — runs every 4 hours via launchd.

Connects to commerce_expert to detect actionable patterns, writes
observations to the allie database, and sends agent messages to Alice.

Patterns detected:
  1. Items below reorder point
  2. Invoices past due (> 30 days, balance > 0)
  3. Credit overrides without reason
  4. MAP violations (invoice line price < item MSRP)
  5. Commission anomalies (effective rate > 20% off configured)
  6. Vendor delivery issues (receipt > 30 days after purchase)

Idempotent: uses observation dedup keys to avoid duplicates.
"""

import json
import logging
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import psycopg2
import psycopg2.extras

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

LOG_DIR = Path.home() / "Allie" / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-7s  %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "alice-patterns.log"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("alice-patterns")

DB_CE = dict(dbname="commerce_expert", user="williamjames", host="localhost")
DB_ALLIE = dict(dbname="allie", user="williamjames", host="localhost")

# All WC3 datetimes are epoch-milliseconds
THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000


def _now_ms():
    return int(time.time() * 1000)


def _epoch_ms_ago(days):
    """Return epoch-ms for N days ago."""
    return _now_ms() - (days * 24 * 60 * 60 * 1000)


# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

def _ce_conn():
    return psycopg2.connect(**DB_CE)


def _allie_conn():
    return psycopg2.connect(**DB_ALLIE)


def _dedup_key(category, identifier):
    """Build a dedup key: category::identifier.

    We store this in observations.metadata->>'dedup_key' and check before
    inserting to avoid duplicate observations for the same issue.
    """
    return f"{category}::{identifier}"


def _observation_exists(allie_cur, dedup_key):
    """Check if an unresolved observation with this dedup key already exists."""
    allie_cur.execute(
        """SELECT 1 FROM observations
           WHERE metadata->>'dedup_key' = %s AND NOT resolved
           LIMIT 1""",
        (dedup_key,),
    )
    return allie_cur.fetchone() is not None


def _insert_observation(allie_cur, observer, domain, category, content,
                        dedup_key, extra_metadata=None):
    """Insert an observation if no unresolved duplicate exists."""
    if _observation_exists(allie_cur, dedup_key):
        return False

    metadata = {"dedup_key": dedup_key}
    if extra_metadata:
        metadata.update(extra_metadata)

    allie_cur.execute(
        """INSERT INTO observations
           (dt_created, observer, domain, category, content, resolved, metadata)
           VALUES (%s, %s, %s, %s, %s, false, %s)""",
        (_now_ms(), observer, domain, category, content, json.dumps(metadata)),
    )
    return True


def _send_agent_message(allie_cur, subject, body="", category="pattern",
                        context=None):
    """Send an agent message to Alice."""
    allie_cur.execute(
        """INSERT INTO agent_messages
           (dt_created, from_agent, to_agent, subject, body,
            priority, category, context, read)
           VALUES (%s, %s, %s, %s, %s, %s, %s, %s, false)""",
        (_now_ms(), "alice-patterns", "alice", subject, body,
         0, category, json.dumps(context or {})),
    )


# ---------------------------------------------------------------------------
# Pattern detectors
# ---------------------------------------------------------------------------

def detect_below_reorder(ce_cur, allie_cur):
    """Items where on_hand < OrgItem.quantity_minimum."""
    count = 0
    ce_cur.execute("""
        SELECT oi.id, oi.item_id, i.name, i.sku,
               (i.quantity->>'on_hand')::numeric AS on_hand,
               oi.quantity_minimum
        FROM products_orgitem oi
        JOIN products_item i ON i.id = oi.item_id
        WHERE oi.quantity_minimum IS NOT NULL
          AND oi.quantity_minimum > 0
          AND i.is_active = true
          AND i.is_deleted = false
          AND (i.quantity->>'on_hand')::numeric < oi.quantity_minimum
    """)
    for row in ce_cur.fetchall():
        oi_id, item_id, name, sku, on_hand, qty_min = row
        dk = _dedup_key("reorder", f"item-{item_id}")
        content = (f"Item '{name}' (SKU: {sku or 'N/A'}) below reorder point: "
                   f"on_hand={on_hand}, minimum={qty_min}")
        if _insert_observation(allie_cur, "alice", "WC3", "reorder", content, dk,
                               {"item_id": item_id, "on_hand": float(on_hand or 0),
                                "minimum": float(qty_min)}):
            _send_agent_message(allie_cur, f"Reorder alert: {name}",
                                body=content, category="reorder",
                                context={"item_id": item_id, "sku": sku})
            count += 1
    return count


def detect_past_due_invoices(ce_cur, allie_cur):
    """Invoices with balance > 0 and older than 30 days."""
    count = 0
    cutoff = _epoch_ms_ago(30)
    ce_cur.execute("""
        SELECT id, ida, dt_created, balance, total, status
        FROM invoices
        WHERE balance > 0
          AND dt_created < %s
          AND status NOT IN ('canceled', 'complete')
          AND is_deleted = false
    """, (cutoff,))
    for row in ce_cur.fetchall():
        inv_id, ida, dt_created, balance, total, status = row
        age_days = (_now_ms() - dt_created) // (24 * 60 * 60 * 1000)
        dk = _dedup_key("past_due", f"invoice-{inv_id}")
        content = (f"Invoice {ida} past due: balance=${float(balance):.2f} "
                   f"of ${float(total):.2f}, age={age_days} days, status={status}")
        if _insert_observation(allie_cur, "alice", "WC3", "past_due", content, dk,
                               {"invoice_id": inv_id, "ida": ida,
                                "balance": float(balance),
                                "age_days": age_days}):
            _send_agent_message(allie_cur, f"Past due: Invoice {ida}",
                                body=content, category="past_due",
                                context={"invoice_id": inv_id, "balance": float(balance)})
            count += 1
    return count


def detect_credit_overrides_no_reason(ce_cur, allie_cur):
    """Transactions with metadata.credit_warnings where reason is empty."""
    count = 0
    # Check orders and invoices for credit warnings without reason
    for table, label in [("orders", "Order"), ("invoices", "Invoice")]:
        ce_cur.execute(f"""
            SELECT id, ida, metadata
            FROM {table}
            WHERE metadata IS NOT NULL
              AND metadata ? 'credit_warnings'
              AND is_deleted = false
        """)
        for row in ce_cur.fetchall():
            rec_id, ida, metadata = row
            if not isinstance(metadata, dict):
                continue
            warnings = metadata.get("credit_warnings", [])
            if not isinstance(warnings, list):
                continue
            for i, w in enumerate(warnings):
                reason = (w.get("reason") or "").strip() if isinstance(w, dict) else ""
                if not reason:
                    dk = _dedup_key("credit_no_reason", f"{table}-{rec_id}-{i}")
                    content = (f"{label} {ida} has credit override without reason: "
                               f"{json.dumps(w)}")
                    if _insert_observation(allie_cur, "alice", "WC3",
                                           "credit_no_reason", content, dk,
                                           {f"{label.lower()}_id": rec_id, "ida": ida}):
                        _send_agent_message(
                            allie_cur,
                            f"Credit override without reason: {label} {ida}",
                            body=content, category="credit_no_reason",
                            context={f"{label.lower()}_id": rec_id})
                        count += 1
    return count


def detect_map_violations(ce_cur, allie_cur):
    """Invoice lines where price < item MSRP (MAP violation)."""
    count = 0
    # Look at recent invoice lines (last 90 days)
    cutoff = _epoch_ms_ago(90)
    ce_cur.execute("""
        SELECT il.id, il.ida, il.item, il.invoice_id, inv.ida AS inv_ida,
               i.price->>'msrp' AS msrp, i.name, i.sku
        FROM invoice_lines il
        JOIN invoices inv ON inv.id = il.invoice_id
        JOIN products_item i ON i.id = (il.item->>'id_num')::bigint
        WHERE il.dt_created > %s
          AND il.is_deleted = false
          AND inv.is_deleted = false
          AND i.price->>'msrp' IS NOT NULL
          AND (i.price->>'msrp')::numeric > 0
          AND il.item->>'price_each' IS NOT NULL
          AND (il.item->>'price_each')::numeric > 0
          AND (il.item->>'price_each')::numeric < (i.price->>'msrp')::numeric
    """, (cutoff,))
    for row in ce_cur.fetchall():
        il_id, il_ida, item_json, inv_id, inv_ida, msrp, name, sku = row
        price_each = float((item_json or {}).get("price_each", 0))
        dk = _dedup_key("map_violation", f"invoice_line-{il_id}")
        content = (f"MAP violation: '{name}' (SKU: {sku or 'N/A'}) on Invoice {inv_ida}, "
                   f"line {il_ida}: sold at ${price_each:.2f}, MSRP=${float(msrp):.2f}")
        if _insert_observation(allie_cur, "alice", "WC3", "map_violation", content, dk,
                               {"invoice_line_id": il_id, "invoice_id": inv_id,
                                "price_each": price_each, "msrp": float(msrp)}):
            _send_agent_message(allie_cur, f"MAP violation: {name} on Inv {inv_ida}",
                                body=content, category="map_violation",
                                context={"invoice_line_id": il_id, "sku": sku})
            count += 1
    return count


def detect_commission_anomalies(ce_cur, allie_cur):
    """Invoice lines where effective commission rate differs > 20% from configured.

    Commission data lives in invoice_lines.item JSON — look for commission_rate
    vs the rep's configured rate in the invoice metadata or refs.
    """
    count = 0
    cutoff = _epoch_ms_ago(90)
    ce_cur.execute("""
        SELECT il.id, il.ida, il.item, il.invoice_id, inv.ida AS inv_ida,
               inv.metadata
        FROM invoice_lines il
        JOIN invoices inv ON inv.id = il.invoice_id
        WHERE il.dt_created > %s
          AND il.is_deleted = false
          AND inv.is_deleted = false
          AND inv.is_commission = true
    """, (cutoff,))
    for row in ce_cur.fetchall():
        il_id, il_ida, item_json, inv_id, inv_ida, inv_meta = row
        if not isinstance(item_json, dict) or not isinstance(inv_meta, dict):
            continue
        line_rate = item_json.get("commission_rate")
        configured_rate = inv_meta.get("configured_commission_rate")
        if line_rate is None or configured_rate is None:
            continue
        try:
            line_rate = float(line_rate)
            configured_rate = float(configured_rate)
        except (ValueError, TypeError):
            continue
        if configured_rate == 0:
            continue
        deviation = abs(line_rate - configured_rate) / configured_rate
        if deviation > 0.20:
            dk = _dedup_key("commission_anomaly", f"invoice_line-{il_id}")
            content = (f"Commission anomaly on Invoice {inv_ida}, line {il_ida}: "
                       f"effective rate={line_rate:.2%}, "
                       f"configured={configured_rate:.2%}, "
                       f"deviation={deviation:.1%}")
            if _insert_observation(allie_cur, "alice", "WC3",
                                   "commission_anomaly", content, dk,
                                   {"invoice_line_id": il_id,
                                    "effective_rate": line_rate,
                                    "configured_rate": configured_rate}):
                _send_agent_message(
                    allie_cur,
                    f"Commission anomaly: Inv {inv_ida} line {il_ida}",
                    body=content, category="commission_anomaly",
                    context={"invoice_line_id": il_id, "invoice_id": inv_id})
                count += 1
    return count


def detect_vendor_delivery_issues(ce_cur, allie_cur):
    """Receipts where dt_created - purchase.dt_created > 30 days."""
    count = 0
    ce_cur.execute("""
        SELECT r.id, r.ida AS receipt_ida,
               r.dt_created AS receipt_dt,
               p.id AS purchase_id, p.ida AS purchase_ida,
               p.dt_created AS purchase_dt
        FROM receipt r
        JOIN purchases p ON p.id = r.purchase_id
        WHERE r.purchase_id IS NOT NULL
          AND r.is_deleted = false
          AND p.is_deleted = false
          AND (r.dt_created - p.dt_created) > %s
    """, (THIRTY_DAYS_MS,))
    for row in ce_cur.fetchall():
        r_id, r_ida, r_dt, p_id, p_ida, p_dt = row
        delay_days = (r_dt - p_dt) // (24 * 60 * 60 * 1000)
        dk = _dedup_key("delivery_delay", f"receipt-{r_id}")
        content = (f"Vendor delivery delay: Receipt {r_ida} received "
                   f"{delay_days} days after Purchase {p_ida}")
        if _insert_observation(allie_cur, "alice", "WC3",
                               "delivery_delay", content, dk,
                               {"receipt_id": r_id, "purchase_id": p_id,
                                "delay_days": delay_days}):
            _send_agent_message(
                allie_cur,
                f"Delivery delay: {delay_days}d for PO {p_ida}",
                body=content, category="delivery_delay",
                context={"receipt_id": r_id, "purchase_id": p_id})
            count += 1
    return count


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    log.info("Alice pattern detection starting")
    ts_start = time.time()

    ce = None
    allie = None
    try:
        ce = _ce_conn()
        allie = _allie_conn()

        with ce.cursor() as ce_cur, allie.cursor() as allie_cur:
            results = {}
            detectors = [
                ("reorder", detect_below_reorder),
                ("past_due", detect_past_due_invoices),
                ("credit_no_reason", detect_credit_overrides_no_reason),
                ("map_violation", detect_map_violations),
                ("commission_anomaly", detect_commission_anomalies),
                ("delivery_delay", detect_vendor_delivery_issues),
            ]
            for name, fn in detectors:
                try:
                    results[name] = fn(ce_cur, allie_cur)
                except Exception:
                    log.exception("Detector %s failed", name)
                    results[name] = -1

            allie.commit()

        # 7. Code standards scan
        try:
            sys.path.insert(0, '/Users/williamjames/Documents/CommerceExpert/webClerk3')
            from apps.ai_assistant.services.code_standards import get_migration_report
            report = get_migration_report()
            violations = report.get('total_violations', 0)
            if violations > 0:
                dedup = f"code-standards-{datetime.now(timezone.utc).strftime('%Y-%m-%d')}"
                with allie.cursor() as cur:
                    cur.execute("SELECT 1 FROM observations WHERE category='code_quality' AND metadata->>'dedup_key'=%s", (dedup,))
                    if not cur.fetchone():
                        summary_items = report.get('summary', [])
                        msg = f"{violations} code standard violations: " + ", ".join(
                            f"{s['pattern_id']}({s['count']})" for s in summary_items[:5]
                        )
                        cur.execute("""
                            INSERT INTO observations (dt_created, observer, domain, category, content, metadata)
                            VALUES (%s, 'alice', 'WC3', 'code_quality', %s, %s)
                        """, (now_ms, msg, json.dumps({'dedup_key': dedup, 'report': report.get('summary', [])})))
                        allie.commit()
                        results['code_standards'] = 1
                        log.info("  Code standards: %d violations across %d files", violations, report.get('files_with_violations', 0))
                    else:
                        results['code_standards'] = 0
        except Exception:
            log.warning("Code standards scan skipped (import failed)")
            results['code_standards'] = -1

        total_new = sum(v for v in results.values() if v > 0)
        elapsed = time.time() - ts_start
        log.info("Pattern detection complete: %.1fs, %d new observations", elapsed, total_new)
        for name, count in results.items():
            status = f"{count} new" if count >= 0 else "FAILED"
            log.info("  %-25s %s", name, status)

    except Exception:
        log.exception("Fatal error in pattern detection")
        sys.exit(1)
    finally:
        if ce:
            ce.close()
        if allie:
            allie.close()


if __name__ == "__main__":
    main()
