#!/usr/bin/env python3
"""
Ingrid — Data Ingestion Agent

Converts external data dumps into wc3-compatible JSON.
Never touches the database directly — JSON files only.

Usage:
    python3 ingrid.py scan <file>              # Detect format, suggest mappings
    python3 ingrid.py convert <file> [mapping] # Convert using mapping
    python3 ingrid.py learn <mapping_file>     # Index mapping into vector store
    python3 ingrid.py suggest <file>           # Auto-suggest mapping from prior experience
    python3 ingrid.py stats                    # Show conversion history
"""
import argparse
import csv
import hashlib
import json
import os
import sys
import time
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path

INGRID_HOME = Path.home() / 'Allie' / 'Ingrid'
PENDING_DIR = INGRID_HOME / 'data' / 'imports' / 'pending'
COMPLETED_DIR = INGRID_HOME / 'data' / 'imports' / 'completed'
REJECTED_DIR = INGRID_HOME / 'data' / 'imports' / 'rejected'
MAPPINGS_DIR = INGRID_HOME / 'data' / 'mappings'
LOGS_DIR = INGRID_HOME / 'logs'
CHROMA_DIR = str(INGRID_HOME / '.chroma_db')

try:
    import chromadb
    HAS_CHROMA = True
except ImportError:
    HAS_CHROMA = False

try:
    import psycopg2
    HAS_DB = True
except ImportError:
    HAS_DB = False


def _now_ms():
    return int(time.time() * 1000)


def _file_hash(filepath):
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()[:16]


# ---------------------------------------------------------------------------
# Format Detection
# ---------------------------------------------------------------------------

def detect_format(filepath: str) -> dict:
    """Detect file format and structure.

    Returns: {format, encoding, delimiter, headers, row_count, sample_rows, file_hash}
    """
    path = Path(filepath)
    if not path.exists():
        return {'error': f'File not found: {filepath}'}

    result = {
        'filepath': str(path),
        'filename': path.name,
        'size_bytes': path.stat().st_size,
        'file_hash': _file_hash(filepath),
        'format': 'unknown',
        'headers': [],
        'row_count': 0,
        'sample_rows': [],
    }

    suffix = path.suffix.lower()

    if suffix in ('.csv', '.txt', '.tsv', '.tab'):
        try:
            with open(filepath, 'r', errors='replace') as f:
                # Detect delimiter
                sample = f.read(4096)
                f.seek(0)

                if '\t' in sample and sample.count('\t') > sample.count(','):
                    delimiter = '\t'
                    result['format'] = 'tsv'
                else:
                    delimiter = ','
                    result['format'] = 'csv'

                reader = csv.DictReader(f, delimiter=delimiter)
                result['headers'] = reader.fieldnames or []
                result['delimiter'] = delimiter

                rows = []
                for i, row in enumerate(reader):
                    if i < 5:
                        rows.append(dict(row))
                    result['row_count'] = i + 1

                result['sample_rows'] = rows
        except Exception as e:
            result['error'] = str(e)

    elif suffix == '.json':
        try:
            with open(filepath, 'r') as f:
                data = json.load(f)
            result['format'] = 'json'
            if isinstance(data, list):
                result['row_count'] = len(data)
                result['headers'] = list(data[0].keys()) if data else []
                result['sample_rows'] = data[:5]
            elif isinstance(data, dict):
                result['headers'] = list(data.keys())
                result['row_count'] = 1
                result['sample_rows'] = [data]
        except Exception as e:
            result['error'] = str(e)

    elif suffix in ('.xlsx', '.xls'):
        result['format'] = 'excel'
        result['note'] = 'Excel support requires openpyxl: pip install openpyxl'

    elif suffix == '.xml':
        result['format'] = 'xml'

    else:
        # Try as CSV anyway
        try:
            with open(filepath, 'r', errors='replace') as f:
                reader = csv.DictReader(f)
                result['headers'] = reader.fieldnames or []
                result['format'] = 'csv'
        except Exception:
            pass

    return result


# ---------------------------------------------------------------------------
# Security Scan (Athena)
# ---------------------------------------------------------------------------

import re

SENSITIVE_PATTERNS = [
    ('ssn', re.compile(r'\b\d{3}-\d{2}-\d{4}\b')),
    ('credit_card', re.compile(r'\b(?:4\d{3}|5[1-5]\d{2}|3[47]\d{2}|6(?:011|5\d{2}))[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b')),
    ('api_key', re.compile(r'(?:api[_-]?key|token|secret|password)\s*[=:]\s*\S+', re.IGNORECASE)),
    ('email_bulk', re.compile(r'[\w.-]+@[\w.-]+\.\w{2,}')),  # not necessarily sensitive, but track count
]


def security_scan(filepath: str) -> dict:
    """Athena security scan — check for sensitive data before conversion.

    Returns: {clean: bool, findings: [{type, count, sample_line}]}
    """
    findings = []
    try:
        with open(filepath, 'r', errors='replace') as f:
            for line_no, line in enumerate(f, 1):
                for name, pattern in SENSITIVE_PATTERNS:
                    if name == 'email_bulk':
                        continue  # emails are expected in customer data
                    matches = pattern.findall(line)
                    if matches:
                        findings.append({
                            'type': name,
                            'count': len(matches),
                            'line': line_no,
                            'sample': line[:100].strip(),
                        })
    except Exception as e:
        findings.append({'type': 'scan_error', 'error': str(e)})

    return {
        'clean': len(findings) == 0,
        'findings': findings,
        'scanned_at': datetime.now(timezone.utc).isoformat(),
        'filepath': filepath,
    }


# ---------------------------------------------------------------------------
# Schema Mapping
# ---------------------------------------------------------------------------

def load_mapping(mapping_path: str) -> dict:
    """Load a schema mapping file."""
    with open(mapping_path, 'r') as f:
        return json.load(f)


def suggest_mapping(headers: list[str]) -> dict:
    """Suggest field mappings based on header names.

    Uses common patterns and vector store knowledge.
    Returns: {field_map: {source_field: target_field}, confidence: float}
    """
    # Common mappings — built from wc2 experience
    COMMON_MAP = {
        # Customer/Contact fields
        'company': 'display_name', 'companyname': 'display_name', 'company_name': 'display_name',
        'firstname': 'contact.name_first', 'first_name': 'contact.name_first', 'fname': 'contact.name_first',
        'lastname': 'contact.name_last', 'last_name': 'contact.name_last', 'lname': 'contact.name_last',
        'email': 'email', 'emailaddress': 'email', 'e-mail': 'email',
        'phone': 'phone', 'phonenumber': 'phone', 'telephone': 'phone', 'tel': 'phone',
        'address': 'address_full', 'address1': 'address_full', 'streetaddress': 'address_full',
        'city': 'address.city', 'state': 'address.state', 'zip': 'address.zip', 'zipcode': 'address.zip',
        'country': 'address.country',
        'pricelevel': 'price_level', 'price_level': 'price_level',
        'creditlimit': 'financial.customer.credit.limit', 'credit_limit': 'financial.customer.credit.limit',
        'terms': 'terms', 'paymentterms': 'terms',

        # Item fields
        'itemnum': 'ida', 'itemnumber': 'ida', 'item_number': 'ida', 'sku': 'sku', 'partnumber': 'sku',
        'description': 'description', 'desc': 'description', 'name': 'name', 'itemname': 'name',
        'pricea': 'price.retail', 'priceb': 'price.wholesale', 'pricec': 'price.distributor', 'priced': 'price.sample',
        'price': 'price.base', 'unitprice': 'price.base', 'listprice': 'price.retail',
        'cost': 'cost.standard', 'unitcost': 'cost.standard', 'standardcost': 'cost.standard',
        'lastcost': 'cost.last', 'averagecost': 'cost.avg',
        'uom': 'uom', 'unitofmeasure': 'uom',
        'weight': 'weight', 'category': 'product_line',
        'vendor': 'vendor.display_name', 'manufacturer': 'manufacturer.display_name',
        'mfgpartno': 'xref.manufacturer_sku', 'vendorpartno': 'xref.vendor_sku',
        'upc': 'xref.upc', 'barcode': 'xref.upc',
        'onhand': 'quantity.on_hand', 'qtyonhand': 'quantity.on_hand',
        'onorder': 'quantity.on_po', 'qtyonorder': 'quantity.on_po',
        'reorderpoint': 'quantity.reorder_point', 'minqty': 'quantity.reorder_point',

        # Transaction fields
        'orderno': 'ida', 'invoiceno': 'ida', 'invoicenumber': 'ida',
        'orderdate': 'dt_created', 'invoicedate': 'dt_created',
        'total': 'total', 'subtotal': 'totals.subtotal',
        'tax': 'totals.tax', 'salestax': 'totals.tax',
        'shipping': 'totals.shipping', 'freight': 'totals.shipping',
        'balance': 'balance', 'amountdue': 'balance',
        'status': 'status',
        'quantity': 'quantity.active', 'qty': 'quantity.active',
    }

    field_map = {}
    matched = 0
    for header in headers:
        normalized = header.lower().replace(' ', '').replace('_', '').replace('-', '')
        if normalized in COMMON_MAP:
            field_map[header] = COMMON_MAP[normalized]
            matched += 1
        else:
            field_map[header] = f'_unmapped.{header}'

    confidence = matched / len(headers) if headers else 0

    return {
        'field_map': field_map,
        'matched': matched,
        'total': len(headers),
        'confidence': round(confidence, 2),
        'unmapped': [h for h in headers if field_map.get(h, '').startswith('_unmapped')],
    }


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------

def _apply_transform(value, transform, transforms_config=None):
    """Apply a transform to a value."""
    if value is None or value == '':
        return None
    if transform == 'decimal':
        try:
            return float(Decimal(str(value).replace(',', '').replace('$', '')))
        except (InvalidOperation, ValueError):
            return None
    if transform == 'integer':
        try:
            return int(float(str(value).replace(',', '')))
        except (ValueError, TypeError):
            return None
    if transform == 'boolean':
        return str(value).lower() in ('true', 'yes', '1', 'y', 't')
    if transform == 'date_mdy':
        # MM/DD/YYYY → epoch ms
        try:
            from datetime import datetime
            dt = datetime.strptime(str(value), '%m/%d/%Y')
            return int(dt.timestamp() * 1000)
        except Exception:
            return None
    if isinstance(transforms_config, dict) and transform in transforms_config:
        # Lookup table transform
        lookup = transforms_config[transform]
        if isinstance(lookup, dict):
            return lookup.get(str(value), value)
    return value


def convert_file(filepath: str, mapping: dict, output_dir: str = None) -> dict:
    """Convert a data file using a schema mapping.

    Args:
        filepath: source data file
        mapping: schema mapping dict with field_map and transforms
        output_dir: where to write JSON output (default: completed/{timestamp}/)

    Returns: {records_converted, errors, output_dir, output_files}
    """
    # Detect format
    info = detect_format(filepath)
    if 'error' in info:
        return info

    # Security scan
    scan = security_scan(filepath)
    if not scan['clean']:
        # Move to rejected
        source_name = Path(filepath).stem
        reject_dir = REJECTED_DIR / source_name
        reject_dir.mkdir(parents=True, exist_ok=True)
        (reject_dir / '_athena_scan.json').write_text(json.dumps(scan, indent=2))
        return {'error': 'Security scan failed', 'findings': scan['findings']}

    # Prepare output
    if not output_dir:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        source_name = Path(filepath).stem
        output_dir = str(COMPLETED_DIR / f'{source_name}_{timestamp}')
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    # Get field map
    models = mapping.get('models', {})
    if not models:
        # Simple flat mapping
        field_map = mapping.get('field_map', {})
        model_name = mapping.get('target_model', 'unknown')
        models = {model_name: {'field_map': field_map, 'transforms': mapping.get('transforms', {})}}

    results = {}
    total_converted = 0
    total_errors = 0

    for model_name, model_config in models.items():
        field_map = model_config.get('field_map', {})
        transforms = model_config.get('transforms', {})
        records = []
        errors = []

        # Read source data
        if info['format'] in ('csv', 'tsv'):
            delimiter = info.get('delimiter', ',')
            with open(filepath, 'r', errors='replace') as f:
                reader = csv.DictReader(f, delimiter=delimiter)
                for row_num, row in enumerate(reader, 1):
                    try:
                        record = {'_source_row': row_num}
                        for src_field, target in field_map.items():
                            value = row.get(src_field)
                            if isinstance(target, dict):
                                target_field = target.get('field', src_field)
                                transform = target.get('transform')
                                value = _apply_transform(value, transform, transforms)
                            else:
                                target_field = target

                            # Handle nested fields (e.g., 'price.retail')
                            if '.' in target_field and not target_field.startswith('_'):
                                parts = target_field.split('.')
                                obj = record
                                for part in parts[:-1]:
                                    obj = obj.setdefault(part, {})
                                obj[parts[-1]] = value
                            else:
                                record[target_field] = value

                        records.append(record)
                        total_converted += 1
                    except Exception as e:
                        errors.append({'row': row_num, 'error': str(e)})
                        total_errors += 1

        elif info['format'] == 'json':
            with open(filepath, 'r') as f:
                data = json.load(f)
            if isinstance(data, dict):
                data = [data]
            for row_num, item in enumerate(data, 1):
                try:
                    record = {'_source_row': row_num}
                    for src_field, target in field_map.items():
                        value = item.get(src_field)
                        if isinstance(target, dict):
                            target_field = target.get('field', src_field)
                            transform = target.get('transform')
                            value = _apply_transform(value, transform, transforms)
                        else:
                            target_field = target
                        if '.' in target_field and not target_field.startswith('_'):
                            parts = target_field.split('.')
                            obj = record
                            for part in parts[:-1]:
                                obj = obj.setdefault(part, {})
                            obj[parts[-1]] = value
                        else:
                            record[target_field] = value
                    records.append(record)
                    total_converted += 1
                except Exception as e:
                    errors.append({'row': row_num, 'error': str(e)})
                    total_errors += 1

        # Write output
        output_file = Path(output_dir) / f'{model_name}.json'
        output_file.write_text(json.dumps(records, indent=2, default=str))
        results[model_name] = {'count': len(records), 'errors': len(errors), 'file': str(output_file)}

    # Write metadata
    (Path(output_dir) / '_mapping.json').write_text(json.dumps(mapping, indent=2))
    (Path(output_dir) / '_athena_scan.json').write_text(json.dumps(scan, indent=2))
    log = {
        'source': filepath,
        'source_hash': info['file_hash'],
        'dt_converted': datetime.now(timezone.utc).isoformat(),
        'total_converted': total_converted,
        'total_errors': total_errors,
        'models': results,
    }
    (Path(output_dir) / '_log.json').write_text(json.dumps(log, indent=2))

    # Log to Ingrid's conversion log
    log_file = LOGS_DIR / f'{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
    log_file.write_text(json.dumps(log, indent=2))

    print(f'\nConversion complete: {total_converted} records, {total_errors} errors')
    print(f'Output: {output_dir}')
    for model, info in results.items():
        print(f'  {model}: {info["count"]} records → {info["file"]}')

    return log


# ---------------------------------------------------------------------------
# Vector Store
# ---------------------------------------------------------------------------

def get_vector_store():
    if not HAS_CHROMA:
        return None
    client = chromadb.PersistentClient(path=CHROMA_DIR)
    return client.get_or_create_collection(name='ingrid_knowledge', metadata={'hnsw:space': 'cosine'})


def learn_mapping(mapping_path: str):
    """Index a mapping file into Ingrid's vector store."""
    collection = get_vector_store()
    if not collection:
        print('ChromaDB not available')
        return

    mapping = load_mapping(mapping_path)
    content = json.dumps(mapping, indent=2)
    doc_id = f'mapping-{Path(mapping_path).stem}'

    collection.upsert(
        ids=[doc_id],
        documents=[content],
        metadatas=[{'source': str(mapping_path), 'type': 'mapping', 'dt_indexed': _now_ms()}],
    )
    print(f'Indexed mapping: {doc_id} ({len(content)} chars)')


def search_knowledge(query: str, n_results: int = 5):
    """Search Ingrid's vector store for relevant mappings."""
    collection = get_vector_store()
    if not collection:
        print('ChromaDB not available')
        return []

    results = collection.query(query_texts=[query], n_results=n_results)
    items = []
    if results and results['documents']:
        for i, doc in enumerate(results['documents'][0]):
            meta = results['metadatas'][0][i] if results['metadatas'] else {}
            dist = results['distances'][0][i] if results['distances'] else None
            items.append({'content': doc[:500], 'metadata': meta, 'distance': dist})
            print(f'\n--- Result {i+1} (distance: {dist:.4f}) ---')
            print(f'Source: {meta.get("source", "?")}')
            print(doc[:300])
    return items


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description='Ingrid — Data Ingestion Agent')
    parser.add_argument('command', choices=['scan', 'convert', 'learn', 'suggest', 'search', 'stats'])
    parser.add_argument('args', nargs='*')
    parser.add_argument('--mapping', '-m', help='Mapping file path')
    parser.add_argument('--output', '-o', help='Output directory')
    args = parser.parse_args()

    if args.command == 'scan':
        if not args.args:
            print('Usage: ingrid.py scan <file>')
            sys.exit(1)
        result = detect_format(args.args[0])
        print(json.dumps(result, indent=2, default=str))

        # Also run security scan
        scan = security_scan(args.args[0])
        if scan['clean']:
            print('\n✓ Athena security scan: CLEAN')
        else:
            print(f'\n⚠ Athena security scan: {len(scan["findings"])} findings')
            for f in scan['findings']:
                print(f'  {f["type"]}: line {f["line"]} — {f["sample"][:60]}')

        # Suggest mapping
        if result.get('headers'):
            suggestion = suggest_mapping(result['headers'])
            print(f'\nMapping suggestion (confidence: {suggestion["confidence"]:.0%}):')
            print(f'  Matched: {suggestion["matched"]}/{suggestion["total"]}')
            if suggestion['unmapped']:
                print(f'  Unmapped: {", ".join(suggestion["unmapped"][:10])}')

    elif args.command == 'convert':
        if not args.args:
            print('Usage: ingrid.py convert <file> [--mapping <mapping.json>]')
            sys.exit(1)
        if args.mapping:
            mapping = load_mapping(args.mapping)
        else:
            # Auto-suggest mapping
            info = detect_format(args.args[0])
            suggestion = suggest_mapping(info.get('headers', []))
            mapping = {'field_map': suggestion['field_map'], 'target_model': 'auto_detected'}
            print(f'Using auto-suggested mapping (confidence: {suggestion["confidence"]:.0%})')
        convert_file(args.args[0], mapping, output_dir=args.output)

    elif args.command == 'learn':
        if not args.args:
            print('Usage: ingrid.py learn <mapping.json>')
            sys.exit(1)
        learn_mapping(args.args[0])

    elif args.command == 'suggest':
        if not args.args:
            print('Usage: ingrid.py suggest <file>')
            sys.exit(1)
        info = detect_format(args.args[0])
        suggestion = suggest_mapping(info.get('headers', []))
        print(json.dumps(suggestion, indent=2))

    elif args.command == 'search':
        query = ' '.join(args.args) if args.args else 'field mapping'
        search_knowledge(query)

    elif args.command == 'stats':
        logs = sorted(LOGS_DIR.glob('*.json'))
        print(f'Conversion history ({len(logs)} runs):')
        for log_file in logs[-10:]:
            log = json.loads(log_file.read_text())
            print(f'  {log.get("dt_converted", "?")} — {log.get("total_converted", 0)} records from {Path(log.get("source", "?")).name}')


if __name__ == '__main__':
    main()
