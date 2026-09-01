# Accepted Deviations

**Purpose:** Things we reviewed, understood, and decided are OK as-is. Do not re-investigate, refactor, or flag these in future sessions. If the situation changes, update or remove the entry.

**Rule:** Before flagging a structural issue, code smell, or inconsistency in any project, check this list first. If it's here, move on.

---

## React2025

### Inline Styles — Justified Remainders

| Pattern | Where | Why it's OK |
|---------|-------|-------------|
| Dynamic layout props (`padding`, `flex`, `gap`, `width`, `fontSize` from user preference) | Throughout — ~800 remaining after CSS class conversion | These are runtime-computed values that can't be CSS classes. Legitimate use of inline styles. |
| DevTools.tsx (26 inline styles) | `src/components/DevTools.tsx` | Intentionally distinct dev-overlay palette (Slate/Tailwind colors). Does not use db-* theme. Correct design decision — dev tools should look different from the app. |
| Conditional ternary styles (e.g., `color: isError ? 'red' : 'green'`) | Various panels | Dynamic state-driven colors. CSS classes don't handle ternaries without extra state classes that add complexity for no benefit. |

### Three Widget/Field Systems

| System | Location | Status |
|--------|----------|--------|
| `components/widgets/` (WidgetProps, WIDGETS registry) | Used by DynamicDetail, DataBrowser | Active — the display/read-mode system |
| `components/fields/` (FieldWidgetProps, WIDGET_REGISTRY) | Used by DataBrowser detail edit | Active — the edit-mode system with BaseField wrapper |
| `components/form/` (react-hook-form wrappers) | Used by legacy detail pages, SerialActionPanel | Legacy — will shrink as pages migrate to DataBrowser |

**Why three is OK for now:** Widgets (read) and Fields (edit) serve different purposes — merging them would force every widget to carry edit logic or every field to carry display logic. The form/ system is legacy and shrinking naturally. Forced consolidation would break working pages for no user benefit. Revisit when the last form/ consumer migrates.

### TextArea — Three Implementations

| File | System | Status |
|------|--------|--------|
| `components/fields/TextareaField.tsx` | Fields (edit mode) | Active — canonical |
| `components/widgets/TextAreaWidget.tsx` | Widgets (display/print) | Active — different purpose |
| `components/form/input/TextArea.tsx` | Form (react-hook-form) | Legacy — shrinking |

**Why:** Same reasoning as widget/field split above. Each serves a distinct purpose.

### dbThemes.ts Still Exists

The JS theme objects in `src/pages/admin/dbThemes.ts` are still imported by DataGrid.tsx and several sub-components that receive `theme` as a prop. Eliminating this requires converting DataGrid's internal rendering to use CSS variables — a deeper refactor that risks breaking the primary grid component. Leave until DataGrid gets its own dedicated rework.

### userProfile.ts — 3 Remaining Consumers

| File | What it imports | Why it's OK |
|------|----------------|-------------|
| `UserAddressCard.tsx` | `getAddress`, `getDomain` | User-profile-specific CRUD — not model CRUD that belongs in wcapi |
| `UserInfoCard.tsx` | `getAddress`, `getEmail`, `getPhone`, `patchUserProfile`, `postEmail`, `postPhone` | Same — user profile management |
| `useNotionProgress.ts` | 5 Notion integration functions | Notion uses a separate axios instance (`notionClient`) with its own auth — wcapi doesn't apply |

### authSlice.ts Reads localStorage on Init

`authSlice.ts` seeds initial Redux state from `localStorage.getItem("userProfile")`. This is a valid hydration pattern for instant page-reload auth state. `AuthInitializer.tsx` validates with the server and corrects if needed. All writes to localStorage are paired with Redux dispatches — no drift path exists.

### Empty Model Directories (No Source Files)

These model directories under `src/apps/` have no source files and empty barrel index.ts files: `soft_delete`, `pending`, `base_org_model`, `ledger`, `tax_jurisdiction`. They exist as placeholders for future models. Don't delete — they document the intended model inventory.

### `matrics` Model Name

The model is named `matrics` (not `metrics`). The empty `metrics/` directory was a placeholder that was cleaned up. The backend Django model is `InventoryMetricsSnapshot` but the wcapi model name is `matrics`. Don't "fix" the spelling — it's intentional.

---

## WebClerk3 (Django)

### Dual Hosting Model (Desktop + Cloud)

WebClerk runs on both desktop (local PostgreSQL) and cloud (Andi server). Conflict resolution uses `uuid/dt/pending` fields. This looks like unnecessary complexity but is the core sovereignty design — each instance is authoritative for its own data. See `readmes/topics/architecture/dual-hosting-model.md`.

### commerce_expert Database Name

The database is named `commerce_expert`, not `webclerk` or `wc3`. This is historical (from the CommerceExpert brand) and is used in runserver.sh, .env files, and deployment scripts. Don't rename.

### Payment Model — Signed Amounts

The Payment model uses signed amounts (`positive = received, negative = expense`). This looks like it should be separate models or a type field, but the signed-amount design supports the checkbook UI pattern and GL journal entry generation. See `readmes/` payment checkbook architecture.

---

## Cross-Project

### Two Utility Files (shared/utils.ts + utils/index.ts)

Both files export `formatPhoneNum`, `formatDate`, `emailValidator`, `convertToArray`, and search persistence functions. This is duplication that should be consolidated, but it's low-risk (pure functions, no state) and not worth the import-path churn right now. Consolidate when one of the files needs a significant edit.

---

*Last reviewed: 2026-08-15*
*Updated by: Claude Code + Bill James*
