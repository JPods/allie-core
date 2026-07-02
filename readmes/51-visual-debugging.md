# Visual Debugging — Screenshot + Inspect + Headless Capture
**Established:** 2026-07-01
**Updated:** 2026-07-01

## Overview

Three tiers of visual debugging, each feeding the same agent data stores. Together they de-mystify HTML/CSS/layout issues by connecting what the user sees to what the code produces.

## The Three Tiers

### Tier 1: Interactive Screenshot (User → Claude)

**When:** You see something wrong in the browser.
**How:** Cmd+Shift+4 → select area → drag file into Claude Code prompt.
**Annotate:** Open in Preview → Tools → Annotate → circles, arrows, text → save → drag in.
**Speed:** 3 seconds from problem to Claude seeing it.

Claude reads the image, identifies the component from visual context and `data-wc` attributes, traces to the source code, and fixes it.

### Tier 2: Inspect + Paste (User → Alice → Help)

**When:** You need help understanding a specific field or element.
**How:** Right-click element → Inspect → Copy Element → Cmd+/ → paste into GetHelpDialog.
**What happens:**
1. GetHelpDialog parses the `data-wc`, `data-wc-field`, `data-wc-model` attributes
2. Looks up field documentation (FIELD-DOC-* records)
3. Looks up AliceObservation records for that context
4. Looks up training documents matching the topic
5. Shows field info (blue), Alice notes (green), WCHQ training (blue)

**The key insight:** `data-wc` attributes are the bridge between the visual UI and Alice's knowledge. Every element has an identity. No guessing.

### Tier 3: Headless Capture (Alice Automated)

**When:** Automated UI regression checks, training video capture, documentation screenshots.
**How:** `browser-capture.py` uses Playwright (headless Chromium) to capture any page.
**Auth:** Alice and Allie have signin credentials — they can capture authenticated pages.

```bash
# Capture a specific page
~/Allie/source/bin/python ~/Allie/scripts/browser-capture.py --url /admin-wb

# Interactive selection
~/Allie/source/bin/python ~/Allie/scripts/browser-capture.py -i

# With annotation note
~/Allie/source/bin/python ~/Allie/scripts/browser-capture.py --url /admin-wb -a "checking layout after DataGrid migration"
```

**Authenticated capture** — Alice signs in headlessly:
```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    
    # Alice signs in
    page.goto('http://localhost:5173/signin')
    page.fill('[name="email"]', 'alice@jpods.com')
    page.fill('[name="password"]', 'pass1111')
    page.click('button[type="submit"]')
    page.wait_for_url('**/dashboard**')
    
    # Now capture any authenticated page
    page.goto('http://localhost:5173/admin-wb?model=order')
    page.wait_for_load_state('networkidle')
    page.screenshot(path='screenshot.png')
```

## How Data Flows

```
User sees problem
    ↓
Tier 1: Screenshot → Claude reads image → fixes code
Tier 2: Inspect+Paste → GetHelpDialog → Alice field docs + training
Tier 3: Headless capture → Alice automated regression check
    ↓
All three → allie.observations (logged)
    ↓
Alice pattern detection → "same UI issue reported 3 times → coaching opportunity"
    ↓
AliceObservation record → appears in AliceHintBar next time user visits that page
```

## data-wc Attribute Map

Every key UI element has a `data-wc` attribute for identification:

### DataBrowser
| Attribute | Element |
|-----------|---------|
| `data-wc="databrowser"` | Root container |
| `data-wc="db-header"` | Header bar |
| `data-wc="db-model-picker"` | Model selector button |
| `data-wc="db-search"` | Search input |
| `data-wc="db-layouts-label"` | Layouts section |
| `data-wc="db-font-size"` | Font size toggle |
| `data-wc="db-theme-toggle"` | Dark/light toggle |
| `data-wc="db-list-pane"` | Left list pane |
| `data-wc="db-list-toolbar"` | List toolbar (List Order, Sel All, etc.) |
| `data-wc="db-detail-pane"` | Right detail pane |
| `data-wc="db-detail-toolbar"` | Detail toolbar (+New, Form Order, Save, Delete) |
| `data-wc="db-layout-selector"` | Layout dropdown in FieldOrderDialog |

### Fields
| Attribute | Element |
|-----------|---------|
| `data-wc="field-{name}"` | Each BehaviorField wrapper |
| `data-wc-field="{name}"` | Field name for lookup |
| `data-wc-model="{model}"` | Model context for field docs |

### Other Components
| Attribute | Element |
|-----------|---------|
| `data-wc="lines-card"` | Transaction line items |
| `data-wc="alice-hint-bar"` | Alice coaching hints |
| `data-wc="help-menu"` | Help button area |
| `data-wc="get-help-dialog"` | GetHelpDialog modal |
| `data-wc="apply-payments"` | Apply Payments page |
| `data-wc="report-designer"` | Report Designer page |

## Alice Can Query Issues

Alice can use headless capture + DOM inspection to diagnose issues programmatically:

```python
# Alice checks if a field renders correctly
page.goto('http://localhost:5173/admin-wb?model=order')
element = page.query_selector('[data-wc="field-commission"]')
if element:
    bbox = element.bounding_box()
    if bbox['height'] < 10:
        # Field collapsed or invisible
        create_observation('commission field not rendering', model='order')
    
    # Check if it has the right value
    text = element.inner_text()
    if 'undefined' in text or 'null' in text:
        create_observation('commission field showing raw null/undefined', model='order')

# Alice checks for layout regressions
page.goto('http://localhost:5173/admin-wb?model=invoice')
list_pane = page.query_selector('[data-wc="db-list-pane"]')
detail_pane = page.query_selector('[data-wc="db-detail-pane"]')
if list_pane and detail_pane:
    list_width = list_pane.bounding_box()['width']
    detail_width = detail_pane.bounding_box()['width']
    total = list_width + detail_width
    if list_width / total < 0.3:
        create_observation('list pane too narrow — detail pane dominating', model='invoice')
```

## For Training Videos

When recording training videos:
1. Use headless capture to get clean screenshots at each step
2. The `--annotate` flag adds context notes that tie to the video timeline
3. Screenshots are logged to `allie.observations` so the training doc can reference them
4. Alice can verify the screenshots still match the current UI (regression check)

```bash
# Step-by-step capture for a training video
for step in signin dashboard select-order view-lines add-commission journalize; do
    ~/Allie/source/bin/python ~/Allie/scripts/browser-capture.py \
        --url "/path-for-$step" \
        -a "Training step: $step"
done
```

## Screenshots Directory

All captures stored in `~/Allie/screenshots/` with timestamps:
```
~/Allie/screenshots/
  20260701_212030_admin-wb.png
  20260701_212030_admin-wb.note.txt    # annotation sidecar
  20260701_212147_admin-wb.png
```

Included in standard Allie backup/sync (iCloud + 5TB).

## Dependencies

- **Playwright** — `~/Allie/source/bin/pip install playwright` + `playwright install chromium`
- **macOS screencapture** — built-in, no install needed
- **Preview.app** — built-in annotation tool
- **psycopg2** — for logging to allie database (already installed)
