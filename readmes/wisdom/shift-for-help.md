# Shift-for-Help — Cross-Project Interaction Standard

**Established:** 2026-07-18
**Applies to:** All JPods projects — su_jpods, MeshMobility, WebClerk3, MyCarryOn, future efforts

---

## The Rule

**One modifier key. Two gestures. Universal.**

| Interaction | What happens |
|-------------|-------------|
| **Shift + hover** | Show a tooltip explaining what this element does, what it expects, or what will happen |
| **Shift + click** | Open contextual help — coaching content, related docs, or send a help request to an agent (Allie / Alice / Andi / WC_HQ) |

Users learn one thing: **hold Shift for help.**

---

## Why Shift

- Most natural modifier — index finger stays on the mouse, pinky finds Shift without looking
- Only one key to remember across all projects
- No conflict with OS shortcuts (Cmd+click = browser link behavior, Alt = OS menu access)
- Shift+hover has no browser default to override
- Shift+click on buttons has no browser default to override

### The Input Field Exception

Shift+click inside `<input>` and `<textarea>` selects text (browser default). Handle this by attaching Shift+click to the **label**, not the input — the same pattern WC3 already uses in `BehaviorField.tsx`. Shift+hover works on inputs without conflict.

---

## What to Show

### Shift+hover tooltip

Short. One or two sentences. Answers: "What is this? What does it do?"

- On a button: what the button does and what happens next
- On a field label: what this field means, what values are expected
- On a status indicator: what this state means
- On a list item: what this item represents

**Not** a user manual. Not a paragraph. If it needs more than two sentences, that's what Shift+click is for.

### Shift+click help

Deeper. Opens a panel, popup, or sends a request. Three tiers based on what's available:

1. **Local coaching** (immediate) — show stored help content: field rules, common mistakes, workflow position, related fields
2. **Agent request** (async) — send context to Allie / Alice / Andi for a tailored answer. Include: element ID, current state, user context
3. **WC_HQ docs** (external) — open relevant documentation from the knowledge base

Start with tier 1. Add tiers 2 and 3 as agent infrastructure matures.

---

## Implementation Pattern

### Content storage: help.json (su_jpods, MeshMobility) or alice_coaching Setting (WC3)

Help text lives in a **single JSON file per project**, not inline in the HTML. This makes it easy to maintain, translate, and polish without touching code.

**su_jpods / MeshMobility:** `dialogs/help.json` — keyed by section and element ID.
```json
{
  "nav": {
    "network": "Connects stations with guideways, manages the network...",
    "models": "Opens, places, and tests station templates..."
  },
  "model-table": {
    "open": "Opens this template's .skp file for editing...",
    "place": "Places this template as a new station instance..."
  }
}
```

**WC3:** `Setting` records with `purpose='alice_coaching'`, one per model. `config.field_help` dict keyed by field name. Fetched lazily via `useFieldHelp(model)` hook, cached in `sessionStorage`.

### HTML: Reference help by key

```html
<!-- su_jpods: data-help-key references help.json -->
<button class="mt-btn place-btn" data-help-key="model-table.place">Place</button>

<!-- Inline data-help is fallback if JSON hasn't loaded -->
<button data-help="Fallback text" data-help-key="nav.network">Network</button>
```

**WC3 React:** `BehaviorField` accepts a `fieldHelp` prop from the parent, provided via `useFieldHelp(model).getFieldHelp(fieldName)`.

### CSS: Visual feedback when Shift is held

```css
/* Applied via JS when Shift key is down */
body.shift-held [data-help-key],
body.shift-held [data-help] {
  cursor: help;
  outline: 1px dashed rgba(255, 200, 0, 0.4);
  outline-offset: 2px;
}

/* Tooltip */
.shift-tooltip {
  position: fixed;
  max-width: 280px;
  padding: 6px 10px;
  background: #1a1a2e;
  color: #e0e0e0;
  border: 1px solid #4a4a6a;
  border-radius: 4px;
  font-size: 12px;
  line-height: 1.4;
  z-index: 10000;
  pointer-events: none;
  box-shadow: 0 2px 8px rgba(0,0,0,0.4);
}
```

### JavaScript: The shared handler (vanilla — for su_jpods, MeshMobility)

```javascript
/* ── Shift-for-Help ─────────────────────────────────────────────
   Drop this block into any HTML dialog. Requires:
   - help.json in the same directory
   - data-help-key="section.element" on interactive elements
   - data-help="..." as inline fallback (optional)
   ──────────────────────────────────────────────────────────────── */
(function() {
  var helpData = {};
  var tooltip = null;
  var shiftHeld = false;

  // Load help.json
  fetch('help.json')
    .then(function(r) { return r.json(); })
    .then(function(data) { helpData = data; })
    .catch(function() { /* fall back to inline data-help */ });

  // Resolve: data-help-key from JSON first, inline data-help as fallback
  function resolveHelp(el) {
    var key = el.getAttribute('data-help-key');
    if (key && helpData) {
      var parts = key.split('.');
      var val = helpData;
      for (var i = 0; i < parts.length; i++) val = val && val[parts[i]];
      if (typeof val === 'string') return val;
    }
    return el.getAttribute('data-help') || null;
  }

  document.addEventListener('keydown', function(e) {
    if (e.key === 'Shift' && !shiftHeld) {
      shiftHeld = true;
      document.body.classList.add('shift-held');
    }
  });
  document.addEventListener('keyup', function(e) {
    if (e.key === 'Shift') {
      shiftHeld = false;
      document.body.classList.remove('shift-held');
      hideTooltip();
    }
  });
  window.addEventListener('blur', function() {
    shiftHeld = false;
    document.body.classList.remove('shift-held');
    hideTooltip();
  });

  document.addEventListener('mouseover', function(e) {
    if (!shiftHeld) return;
    var el = e.target.closest('[data-help-key],[data-help]');
    if (!el) return;
    var text = resolveHelp(el);
    if (text) showTooltip(text, e);
  });
  document.addEventListener('mouseout', function(e) {
    if (e.target.closest('[data-help-key],[data-help]')) hideTooltip();
  });
  document.addEventListener('mousemove', function(e) {
    if (tooltip) {
      tooltip.style.left = Math.min(e.clientX + 12, window.innerWidth - 300) + 'px';
      tooltip.style.top  = (e.clientY + 16) + 'px';
    }
  });

  document.addEventListener('click', function(e) {
    if (!e.shiftKey) return;
    var el = e.target.closest('[data-help-key],[data-help]');
    if (!el) return;
    e.preventDefault();
    e.stopPropagation();
    var text = resolveHelp(el);
    if (text) { showTooltip(text, e); setTimeout(hideTooltip, 3000); }
  }, true);

  function showTooltip(text, e) {
    hideTooltip();
    tooltip = document.createElement('div');
    tooltip.className = 'shift-tooltip';
    tooltip.textContent = text;
    tooltip.style.left = Math.min(e.clientX + 12, window.innerWidth - 300) + 'px';
    tooltip.style.top  = (e.clientY + 16) + 'px';
    document.body.appendChild(tooltip);
  }
  function hideTooltip() {
    if (tooltip) { tooltip.remove(); tooltip = null; }
  }

  // First-visit hint
  if (!localStorage.getItem('shiftHelpSeen')) {
    var hint = document.createElement('div');
    hint.className = 'shift-help-hint';
    hint.textContent = 'Hold Shift and hover any button for help';
    hint.onclick = function() { hint.remove(); localStorage.setItem('shiftHelpSeen', '1'); };
    document.body.appendChild(hint);
    setTimeout(function() { if (hint.parentNode) hint.remove(); }, 15000);
  }
})();
```

### React hook: useFieldHelp (for WC3)

```typescript
// src/hooks/useFieldHelp.ts — lazy-fetches alice_coaching Setting, caches in sessionStorage
import { useFieldHelp } from '@/hooks/useFieldHelp';

// In parent component:
const { getFieldHelp } = useFieldHelp(modelName);

// Pass to BehaviorField:
<BehaviorField name="total" fieldHelp={getFieldHelp('total')} ... />
```

---

## Per-Project Integration

### su_jpods (SketchUp HTML dialogs) — DONE 2026-07-18

- JS block + CSS in `console.html`
- `dialogs/help.json` — all help content keyed by section/element
- `data-help-key` attributes on nav, workflow, test toolbar, model table buttons
- First-visit hint bar auto-dismisses after 15s

### WebClerk3 (React) — DONE 2026-07-18

- `BehaviorField.tsx` simplified from Cmd+Option+Shift to just Shift
- `useFieldHelp` hook lazy-fetches `alice_coaching` Setting per model, caches in `sessionStorage`
- `BehaviorField` accepts `fieldHelp` prop for Shift+hover tooltips
- `HelpDashboard.tsx` shortcuts table updated
- Parent components wire up: `const { getFieldHelp } = useFieldHelp(model)` → `<BehaviorField fieldHelp={getFieldHelp(name)} />`

### MeshMobility — TODO

- Add the JS block + CSS to the main HTML
- Create `help.json` for toolbar buttons, station cards, simulation controls
- `data-help-key` on all interactive elements

### Future projects

- Copy the JS block + CSS. Create `help.json`. Add `data-help-key` attributes. Done.

---

## Content Rules

1. **Write help text in second person, present tense.** "Places this template..." not "This button is used to place..."
2. **Start with the verb.** "Opens...", "Shows...", "Connects...", "Removes..."
3. **State what happens, not how it works internally.** Users don't need to know about `NoelleNetworkBuilder.from_json`
4. **Include consequences.** "Removes this connection. Both guideways are deleted — cannot be undone."
5. **Keep tooltips under 30 words.** Deep help has no limit.
6. **Help content lives next to the element**, not in a separate file. `data-help` inline. Deep help topics can reference external content via `data-help-topic`.

---

## Discovery

Users need to learn that Shift exists as a help modifier. Three mechanisms:

1. **First-visit hint.** On first load, show a subtle bar: "Hold Shift and hover any element for help." Dismiss permanently on click. Store in localStorage.
2. **Cursor change.** When Shift is held, all `[data-help]` elements get a dashed outline and the cursor changes to `help`. Immediate visual signal that something is available.
3. **`?` key overlay.** Pressing `?` (when not in an input field) shows a small shortcuts panel that includes the Shift-for-Help pattern.

---

## Relationship to Agent Help Requests

When Shift+click sends a request to an agent (tier 2), the request includes:

```json
{
  "source": "su_jpods",
  "element": "place-btn",
  "topic": "template-placement",
  "help_text": "Places this template as a new station...",
  "context": { "current_tab": "models", "open_template": "cpb", "network": "MA_Boston_NS_Stations" },
  "user": "bill"
}
```

The agent (Allie, Alice, Andi) responds with tailored guidance based on the user's context and history. This is the bridge between static help content and adaptive coaching.

---

## Translation

Default: English. Translation is opt-in, not mandatory.

When a user's locale is not `en`, Shift+click can pass the help text through a language API before displaying. The English text shows immediately, then swaps when the translation returns. Cache translations in `sessionStorage` keyed by `{key}.{locale}`.

Do **not** pre-translate and store — every coaching edit would require re-translating. Translate on demand, cache the result.

Priority: JPods station ticketing (multilingual travelers at kiosks) first. Back-office field help can wait.

---

## What This Replaces

- WC3's Cmd+Option+Shift+click → simplified to Shift+click
- su_jpods' `title` attribute tooltips → Shift+hover (richer, styled, controlled)
- Native `title` tooltips remain for non-help hover info (element names, IDs)
- No existing MeshMobility help system → Shift-for-Help from the start
