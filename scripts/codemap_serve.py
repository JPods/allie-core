#!/usr/bin/env python3
"""
Serve the CodeMap viewer locally.

Usage:
    python3 scripts/codemap_serve.py          # serves on port 8787
    python3 scripts/codemap_serve.py 9000     # custom port

Opens the viewer in your default browser.
"""

import http.server
import os
import sys
import webbrowser
from pathlib import Path

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
FLOWCHARTS_DIR = Path(__file__).resolve().parent.parent / "readmes" / "flowcharts"

os.chdir(FLOWCHARTS_DIR)
print(f"CodeMap serving {FLOWCHARTS_DIR}")
print(f"Open: http://localhost:{PORT}/codemap-viewer.html")

webbrowser.open(f"http://localhost:{PORT}/codemap-viewer.html")

handler = http.server.SimpleHTTPRequestHandler
with http.server.HTTPServer(("", PORT), handler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
