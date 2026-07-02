#!/usr/bin/env python3
"""
Browser Capture — screenshot the running WebClerk app for Claude Code to read.

Usage:
    python3 browser-capture.py                    # capture full page
    python3 browser-capture.py --url /admin-wb    # capture specific page
    python3 browser-capture.py --element "data-wc=db-list-pane"  # capture specific element
    python3 browser-capture.py --annotate "red circle on the broken button"  # add note

Screenshots saved to ~/Allie/screenshots/ with timestamp.
Claude Code reads them via the Read tool (multimodal).

All three agents get the screenshot:
  - Claude: reads it directly for debugging
  - Alice: stores reference in alice_observations for UI pattern tracking
  - Allie: indexes in observations for cross-session knowledge
"""
import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

SCREENSHOTS_DIR = Path.home() / 'Allie' / 'screenshots'
SCREENSHOTS_DIR.mkdir(parents=True, exist_ok=True)

BASE_URL = os.environ.get('WC_URL', 'http://localhost:5173')

try:
    import psycopg2
    HAS_DB = True
except ImportError:
    HAS_DB = False


def _now_ms():
    return int(time.time() * 1000)


def capture_with_screencapture(output_path: str, region: str = None):
    """Use macOS screencapture for manual capture."""
    args = ['screencapture']
    if region:
        args.append('-R')  # capture region
        args.append(region)
    else:
        args.append('-i')  # interactive selection
    args.append(output_path)
    subprocess.run(args)
    return Path(output_path).exists()


def capture_with_webkit(url: str, output_path: str, width: int = 1440, height: int = 900):
    """Use Playwright for headless capture with authentication."""
    try:
        result = subprocess.run(
            [sys.executable, '-c', f"""
from playwright.sync_api import sync_playwright
import time

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={{'width': {width}, 'height': {height}}})

    # Sign in as Claude (superuser)
    page.goto('{BASE_URL}/signin')
    time.sleep(1)

    # Try to fill login form
    try:
        email_input = page.query_selector('input[type="email"], input[name="email"], input[name="username"]')
        pass_input = page.query_selector('input[type="password"]')
        if email_input and pass_input:
            email_input.fill('claude@jpods.com')
            pass_input.fill('pass1111')
            submit = page.query_selector('button[type="submit"], button:has-text("Sign"), button:has-text("Log")')
            if submit:
                submit.click()
                page.wait_for_load_state('networkidle', timeout=10000)
                time.sleep(2)
    except Exception:
        pass  # May already be on the right page

    # Navigate to target
    page.goto('{url}')
    page.wait_for_load_state('networkidle', timeout=15000)
    time.sleep(2)
    page.screenshot(path='{output_path}', full_page=False)
    browser.close()
"""],
            capture_output=True, text=True, timeout=45
        )
        if Path(output_path).exists():
            return True
    except Exception:
        pass

    # Fallback: use macOS screencapture (requires browser to be visible)
    print("Automated capture not available (install playwright for headless).")
    print("Using interactive screen capture instead — select the area to capture.")
    return capture_with_screencapture(output_path)


def log_capture(filepath: str, url: str, note: str = ''):
    """Log the capture to the allie database for team awareness."""
    if not HAS_DB:
        return

    try:
        conn = psycopg2.connect(dbname='allie', user=os.getlogin(), host='localhost')
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO observations (dt_created, observer, domain, category, content, metadata)
                VALUES (%s, 'claude', 'WC3', 'screenshot', %s, %s)
            """, (
                _now_ms(),
                f'Screenshot captured: {url} — {note}' if note else f'Screenshot captured: {url}',
                json.dumps({
                    'filepath': filepath,
                    'url': url,
                    'note': note,
                    'dt': datetime.now(timezone.utc).isoformat(),
                }),
            ))
            conn.commit()
        conn.close()
    except Exception:
        pass


def main():
    parser = argparse.ArgumentParser(description='Browser Capture for Claude Code')
    parser.add_argument('--url', default='/', help='URL path to capture (e.g., /admin-wb)')
    parser.add_argument('--element', help='data-wc attribute to highlight')
    parser.add_argument('--annotate', '-a', help='Annotation note for the screenshot')
    parser.add_argument('--interactive', '-i', action='store_true', help='Use interactive screen selection')
    parser.add_argument('--width', type=int, default=1440)
    parser.add_argument('--height', type=int, default=900)
    args = parser.parse_args()

    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    page_name = args.url.strip('/').replace('/', '_') or 'home'
    filename = f'{timestamp}_{page_name}.png'
    filepath = str(SCREENSHOTS_DIR / filename)

    full_url = f'{BASE_URL}{args.url}'

    if args.interactive:
        print(f'Interactive capture — select the area to screenshot...')
        success = capture_with_screencapture(filepath)
    else:
        print(f'Capturing {full_url} ...')
        success = capture_with_webkit(full_url, filepath, args.width, args.height)

    if success:
        print(f'\nScreenshot saved: {filepath}')
        print(f'Claude Code can read it: Read({filepath})')
        log_capture(filepath, full_url, args.annotate or '')

        if args.annotate:
            # Save annotation as a sidecar file
            note_path = filepath.replace('.png', '.note.txt')
            Path(note_path).write_text(f'URL: {full_url}\nNote: {args.annotate}\nDT: {datetime.now(timezone.utc).isoformat()}\n')
            print(f'Annotation: {note_path}')
    else:
        print('Capture failed or cancelled.')
        sys.exit(1)


if __name__ == '__main__':
    main()
