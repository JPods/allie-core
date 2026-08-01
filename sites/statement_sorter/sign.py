#!/usr/bin/env python3
"""Athena signing script for Statement Sorter.
Calculates SHA-256 of the payload (everything from '// ─── Toast' onward)
and embeds it in the ATHENA_SIG constant. Run before each deploy.

Usage: python3 sign.py
"""
import hashlib, re, sys

path = 'index.html'
html = open(path).read()

# Find the script content
match = re.search(r'<script>(.*?)</script>', html, re.DOTALL)
if not match:
    print('ERROR: No <script> block found'); sys.exit(1)

script = match.group(1)

# Find the payload start marker
marker = '// ─── Toast'
idx = script.find(marker)
if idx == -1:
    print('ERROR: Toast marker not found'); sys.exit(1)

payload = script[idx:]
h = hashlib.sha256(payload.encode()).hexdigest()

# Replace the placeholder or existing hash
old_html = html
html = re.sub(
    r"const ATHENA_SIG = '[^']*';",
    f"const ATHENA_SIG = '{h}';",
    html
)

if html == old_html:
    print('ERROR: Could not find ATHENA_SIG line'); sys.exit(1)

open(path, 'w').write(html)
print(f'Signed: {h}')
print(f'Payload: {len(payload)} bytes from "{marker}"')
