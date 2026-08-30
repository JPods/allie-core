# Handoff — 2026-08-29 (Session 6: Upload + Touch + Panels)

## Where We Left Off

Major session covering upload fix, label behaviors, TouchToolbar, panel architecture, and touch templates. All changes uncommitted in WebClerk frontend + backend.

## What Was Built

### 1. Upload 500 Fix + Metadata Dialog
- Root cause: `_serialize_document()` referenced non-existent `doc.model_name` — fixed to read `doc.config["parent_model"]`
- Added `JWTAuthentication + SessionAuthentication + IsAuthenticated` to upload views
- FileUploadPanel: upload metadata dialog (purpose dropdown, description per file)
- Uploads append to `refs.links.document` with denormalized `{id, purpose, description, size_bytes, name, mime_type, lat, lng}`
- Geolocation captured in `metadata.address.geo`

### 2. Infinite Render Loop Fix
- `DynamicDetail.tsx:427` — removed `onActionsReady` from useEffect deps

### 3. label_href Field Behavior (Setting-Driven)
- `field_behaviors.name.label_href = "path.url"` in document Setting
- `fields/index.tsx` resolves dot-path from record → passes `labelHref` to widget
- `BaseField.tsx` renders `<a>` with `db-label--actionable` color when `labelHref` set
- `HorizontalField.tsx` supports `labelHref` prop for form layouts
- Works in both db.detail and db.form — declared once in Setting, rendered everywhere

### 4. Panel Architecture — + add / assign / remove
- **+ add**: creates new record, links to parent, opens in floating window (inherits contact_id, customer_id, project_id from parent)
- **assign**: searches existing records, links via refs.links (was the old "+ add" behavior)
- **Option+Cmd+click**: removes non-core panel (confirms if records linked)
- Both buttons in `db-section-header__actions` wrapper — aligned right, consistent spacing
- Clicking assign/add auto-expands collapsed panels
- Only one assign search open at a time (`panel-assign-opened` custom event dismisses others)
- ContactPanel updated with same + add / assign pattern

### 5. Panel Visibility Rules
- **Core panels** (contact, action, touch): always show, even if zero
- **Other panels** (document, item, invoice, etc.): only show if refs.links has records (length > 0)
- User can add any panel via "+ Link..." — it persists once added
- Core panels cannot be removed (Option+Cmd+click ignored)

### 6. Touch Templates (Report Records)
- 18 templates seeded: 11 email, 7 text
- Topics: sales, service, general
- `{{tokens}}`: contact_name, company_name, user_name, our_company, subject, record_ida, follow_up_date
- Stored as Report records with `category='touch_template'`, `purpose='email'|'text'`
- Template selector added to TouchForm (topic dropdown → template dropdown → fills subject + summary)
- Only `is_active=True` templates shown

### 7. Keyboard Modifier Standard (Memory Updated)
- Click = select
- Shift+click = help / range select
- Cmd/Ctrl+click = toggle / quick editor
- Cmd+Shift+click = full behavior override
- Option+Cmd+click = destroy panel (destructive, two modifier keys required)

### 8. Contact + Action Setting Layouts
- Created `wc:workbench_fields` Setting for contact (id=884) with curated detail + list layout
- Added `config.layout.form.default` sections to action Setting (id=658) — header rows + tabs
- Document Setting: `label_href` on name/slug fields

## Open Items
- Touch phone/text/email: URI handlers (tel:/sms:/mailto:) fire on Save — code is complete, needs testing with real contacts that have phone/email
- Touch template selector in TouchForm: wired but untested after page reload
- Action form layout (App mode): needs proper sections in Setting — current stub may need work
- TouchToolbar (inline version): built but reverted in favor of TouchForm dialog — file exists at `components/common/TouchToolbar.tsx` if needed later
- iPhone PWA testing

## TFTS Written
1. `20260829T044338-tfts.md` — Upload 500: curl reveals truth, auth was red herring
2. `20260829T125916-tfts.md` — Label behaviors belong in Setting, not per-layout

## Files Modified

### Backend
```
backend/apps/docs/views/upload_view.py
backend/apps/core/auth.py (read only — not modified)
backend/readmes/upload-auth-architecture.md (NEW)
```

### Frontend
```
frontend/src/components/common/DynamicDetail.tsx
frontend/src/components/common/FileUploadPanel.tsx
frontend/src/components/common/TouchToolbar.tsx (NEW — reverted from DataBrowser, standalone)
frontend/src/components/fields/index.tsx
frontend/src/components/fields/TextField.tsx
frontend/src/components/fields/BaseField.tsx
frontend/src/components/form/HorizontalField.tsx
frontend/src/apps/docs/models/document/pages/DocumentDisplay.tsx
frontend/src/apps/common/components/panels/LinkedRecordsPanel.tsx
frontend/src/apps/common/components/panels/ContactPanel.tsx
frontend/src/apps/common/components/panels/DbColumns.tsx
frontend/src/pages/admin/DataBrowser.tsx
frontend/src/pages/admin/DataBrowser.css
frontend/src/pages/admin/TouchForm.tsx
frontend/src/pages/admin/TouchBar.tsx (unchanged)
```
