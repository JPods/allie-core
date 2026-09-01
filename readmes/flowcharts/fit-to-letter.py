#!/usr/bin/env python3
"""Fit all WC3/WC2 .dot files to US Letter (8.5x11).
Portrait or landscape. 2 pages if shrinking would make fonts unreadable.
Minimum effective font size: 7pt (from 10pt base = 0.7 scale floor)."""

import subprocess, re, os, glob, shutil

DIR = os.path.dirname(os.path.abspath(__file__))

# Scale floor — below this, fonts become unreadable
MIN_SCALE = 0.65  # 10pt * 0.65 = 6.5pt minimum

def get_natural_size_inches(dot_file):
    """Render to SVG, return (width_in, height_in)."""
    result = subprocess.run(['dot', '-Tsvg', dot_file], capture_output=True, text=True)
    if result.returncode != 0:
        return None, None
    svg = result.stdout
    w = re.search(r'width="([\d.]+)pt"', svg)
    h = re.search(r'height="([\d.]+)pt"', svg)
    if w and h:
        return float(w.group(1)) / 72.0, float(h.group(1)) / 72.0
    return None, None


def set_page_attrs(dot_file, orientation, two_page):
    """Set size/page attributes. Two-page charts keep full font size."""
    with open(dot_file) as f:
        content = f.read()

    # Strip existing sizing attributes
    for attr in ['size', 'page', 'ratio', 'rotate', 'margin', 'landscape']:
        content = re.sub(rf'\n\s*{attr}\s*=\s*[^\n]*', '', content)

    if orientation == 'landscape':
        draw_w, draw_h = 10.0, 7.5  # letter landscape with 0.5" margins
    else:
        draw_w, draw_h = 7.5, 10.0  # letter portrait with 0.5" margins

    if two_page:
        # No size constraint — let chart render at natural size with full fonts
        # page= tells Graphviz to tile across letter pages
        if orientation == 'landscape':
            attrs = '    page="11,8.5"\n'
        else:
            attrs = '    page="8.5,11"\n'
    else:
        # Fit on one page — scale is safe for readability
        attrs = f'    size="{draw_w},{draw_h}"\n    ratio="compress"\n'

    content = re.sub(
        r'(digraph\s+\w+\s*\{)',
        r'\1\n' + attrs,
        content, count=1
    )

    with open(dot_file, 'w') as f:
        f.write(content)


def render(dot_file, svg_out, pdf_out):
    subprocess.run(['dot', '-Tsvg', dot_file, '-o', svg_out], check=True)
    subprocess.run(['dot', '-Tpdf', dot_file, '-o', pdf_out], check=True)


def decide_layout(dot_file):
    """Determine orientation and whether chart needs 2 pages."""
    w, h = get_natural_size_inches(dot_file)
    if w is None:
        return None, None, None, None

    aspect = w / h if h > 0 else 1.0

    # Choose orientation based on natural shape
    if aspect > 1.0:
        orientation = 'landscape'
        draw_w, draw_h = 10.0, 7.5
    else:
        orientation = 'portrait'
        draw_w, draw_h = 7.5, 10.0

    # What scale factor would be needed to fit on 1 page?
    scale_w = draw_w / w
    scale_h = draw_h / h
    scale = min(scale_w, scale_h)

    # If scale would shrink fonts below readable, use 2 pages
    two_page = scale < MIN_SCALE

    return orientation, two_page, scale, (w, h)


def build_name_map():
    return {
        'wc3-master-flow': 'wc3-01-overview-a-master-flow',
        'wc3-signin-register': 'wc3-02-security-a-signin-register',
        'wc3-request-security': 'wc3-02-security-b-request-security',
        'wc3-contact': 'wc3-03-contacts-a-contact',
        'wc3-products-item-support': 'wc3-04-products-a-products-item-support',
        'wc3-inventory-buckets': 'wc3-04-products-b-inventory-buckets',
        'wc3-serial-tracking': 'wc3-04-products-c-serial-tracking',
        'wc3-serial-actions': 'wc3-04-products-d-serial-actions',
        'wc3-customer-centered-sales': 'wc3-05-sales-a-customer-centered-sales',
        'wc3-order-to-invoice': 'wc3-05-sales-b-order-to-invoice',
        'wc3-po-so-bundle': 'wc3-05-sales-c-po-so-bundle',
        'wc3-big4-transactions': 'wc3-05-sales-d-big4-transactions',
        'wc3-payment-gl': 'wc3-06-finance-a-payment-gl',
        'wc3-exchange-rates': 'wc3-06-finance-b-exchange-rates',
        'wc3-statement-sorter': 'wc3-06-finance-c-statement-sorter',
        'wc3-pending-records': 'wc3-06-finance-d-pending-records',
        'wc3-action': 'wc3-07-actions-a-action',
        'wc3-action-documents': 'wc3-07-actions-b-action-documents',
        'wc3-action-touches': 'wc3-07-actions-c-action-touches',
        'wc3-project': 'wc3-07-actions-d-project',
        'wc3-document-library': 'wc3-08-content-a-document-library',
        'wc3-qa-entity': 'wc3-08-content-b-qa-entity',
        'wc3-refs-linkage': 'wc3-08-content-c-refs-linkage',
        'wc3-conn-accounting': 'wc3-09-connectors-a-conn-accounting',
        'wc3-conn-banking': 'wc3-09-connectors-b-conn-banking',
        'wc3-conn-calendar': 'wc3-09-connectors-c-conn-calendar',
        'wc3-conn-communication': 'wc3-09-connectors-d-conn-communication',
        'wc3-conn-deploy': 'wc3-09-connectors-e-conn-deploy',
        'wc3-conn-identity': 'wc3-09-connectors-f-conn-identity',
        'wc3-conn-internal': 'wc3-09-connectors-g-conn-internal',
        'wc3-conn-payment': 'wc3-09-connectors-h-conn-payment',
        'wc3-conn-shipping': 'wc3-09-connectors-i-conn-shipping',
        'wc3-conn-tax': 'wc3-09-connectors-j-conn-tax',
        'wc3-celery-pipeline': 'wc3-10-infra-a-celery-pipeline',
        'wc3-data-conversion-pipeline': 'wc3-10-infra-b-data-conversion-pipeline',
    }


def main():
    enriched_dots = sorted(glob.glob(os.path.join(DIR, 'wc3-*.enriched.dot')))
    source_dots = sorted(glob.glob(os.path.join(DIR, 'wc3-[0-9]*.dot')))
    wc2_dots = sorted(glob.glob(os.path.join(DIR, 'wc2-*.dot')))
    name_map = build_name_map()

    combined_pdfs = []

    # ── Enriched .dot → enriched SVG + PDF ──
    print('Enriched .dot files (final output):')
    print(f'  {"Orient":9s} {"Pg":3s} {"Scale":5s} {"Natural":>12s}  File')
    print(f'  {"-"*9} {"-"*3} {"-"*5} {"-"*12}  {"-"*40}')

    for dot_file in enriched_dots:
        name = os.path.basename(dot_file)
        base = name.replace('.enriched.dot', '')

        orientation, two_page, scale, dims = decide_layout(dot_file)
        if orientation is None:
            print(f'  SKIP {name}')
            continue

        set_page_attrs(dot_file, orientation, two_page)

        svg_out = os.path.join(DIR, f'{base}.enriched.svg')
        pdf_out = os.path.join(DIR, f'{base}.pdf')
        render(dot_file, svg_out, pdf_out)

        pages = '2' if two_page else '1'
        w, h = dims
        print(f'  {orientation:9s} {pages:>3s} {scale:5.2f} {w:5.1f}x{h:4.1f}in  {name}')

        # Copy to numbered name
        numbered = name_map.get(base)
        if numbered:
            numbered_svg = os.path.join(DIR, f'{numbered}.enriched.svg')
            shutil.copy2(svg_out, numbered_svg)

        combined_pdfs.append(pdf_out)

    # ── Source .dot files (update sizing only, no render) ──
    print('\nSource .dot files (sizing updated):')
    for dot_file in source_dots:
        name = os.path.basename(dot_file)
        orientation, two_page, scale, dims = decide_layout(dot_file)
        if orientation is None:
            continue
        set_page_attrs(dot_file, orientation, two_page)
        pages = '2' if two_page else '1'
        w, h = dims
        print(f'  {orientation:9s} {pages:>3s} {scale:5.2f} {w:5.1f}x{h:4.1f}in  {name}')

    # ── WC2 .dot → SVG + PDF ──
    print('\nWC2 .dot files:')
    for dot_file in wc2_dots:
        name = os.path.basename(dot_file)
        base = name.replace('.dot', '')

        orientation, two_page, scale, dims = decide_layout(dot_file)
        if orientation is None:
            continue

        set_page_attrs(dot_file, orientation, two_page)

        svg_out = os.path.join(DIR, f'{base}.svg')
        pdf_out = os.path.join(DIR, f'{base}.pdf')
        render(dot_file, svg_out, pdf_out)

        pages = '2' if two_page else '1'
        w, h = dims
        print(f'  {orientation:9s} {pages:>3s} {scale:5.2f} {w:5.1f}x{h:4.1f}in  {name}')
        combined_pdfs.append(pdf_out)

    # ── Rebuild combined PDF ──
    print(f'\nRebuilding wc3-all-flowcharts.pdf ({len(combined_pdfs)} charts)...')
    combined = os.path.join(DIR, 'wc3-all-flowcharts.pdf')
    subprocess.run(['pdfunite'] + combined_pdfs + [combined], check=True)
    size_mb = os.path.getsize(combined) / 1048576
    print(f'  {size_mb:.1f} MB')
    print('Done.')


if __name__ == '__main__':
    main()
