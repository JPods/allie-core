# Handoff — 2026-08-29 (Session 6 Final: Upload + Touch + Panels + Templates)

## Where We Left Off

Touch URI firing works for phone and text (createElement('a').click()). Email (mailto:) works when browser has handler registered — debug Chrome needed handler setup at chrome://settings/handlers. All three fire synchronously before async save to preserve user gesture context.

## What Was Built

### 1. Upload Fix + Metadata Dialog
- `_serialize_document()` → `doc.config["parent_model"]` (was `doc.model_name`)
- JWTAuthentication + IsAuthenticated on upload views
- FileUploadPanel: purpose dropdown + description per file
- refs.links.document denormalized: {id, purpose, description, size_bytes, name, mime_type, lat, lng}
- Geolocation captured in metadata.address.geo

### 2. Infinite Render Loop Fix
- Removed onActionsReady from useEffect deps in DynamicDetail

### 3. label_href (Setting-Driven)
- field_behaviors.name.label_href = "path.url" in document Setting
- Resolved in fields/index.tsx → BaseField renders <a> with db-label--actionable
- Works in both db.detail and db.form

### 4. Panel Architecture
- Core panels (contact, action, touch): always show
- Other panels: only show if refs.links has records (length > 0)
- assign: search existing → link. No +add button
- Option+Cmd+click: remove non-core panel (confirm if records linked)
- Clicking assign auto-expands collapsed panels
- panel-assign-opened event: only one assign search open at a time
- ContactPanel: both assign and +add buttons (consistent with LinkedRecordsPanel)

### 5. Touch Templates (18 Report Records)
- category='touch_template', purpose='email'|'text'
- Topics: sales (7), service (4), general (7)
- {{tokens}}: contact_name, company_name, user_name, our_company, subject, record_ida, follow_up_date
- Template fills subject only (>3 chars typed = user's subject preserved)
- Summary field is for user notes, not template content

### 6. TouchForm Unified
- ContactPanel now uses TouchForm inline mode (was separate TouchInlineForm)
- Template selector shows when channel is email or text
- Send button: fires URI synchronously (createElement('a').click()) then saves async
- Form stays open after send: user adds notes, email_message_id, outcome → Save & Close
- Log Only: saves without firing URI

### 7. Protocol URI Pattern
- tel: and sms: work via createElement('a').click() — confirmed
- mailto: works via same pattern when browser has handler registered
- CRITICAL: URI must fire synchronously BEFORE any async call (handleSave) — browser requires user gesture context
- Debug Chrome profile needs handler setup: chrome://settings/handlers or Gmail address bar icon

### 8. Keyboard Modifier Standard (Memory Updated)
- Click = select | Shift = help/range | Cmd = toggle | Option+Cmd = destroy panel

## TFTS Written
1. 20260829T044338-tfts.md — Upload 500: curl reveals truth
2. 20260829T125916-tfts.md — Label behaviors belong in Setting, not per-layout

## Files Modified

### Backend
- backend/apps/docs/views/upload_view.py
- backend/readmes/upload-auth-architecture.md (NEW)

### Frontend
- frontend/src/components/common/DynamicDetail.tsx
- frontend/src/components/common/FileUploadPanel.tsx
- frontend/src/components/common/TouchToolbar.tsx (NEW — standalone, not wired)
- frontend/src/components/fields/index.tsx
- frontend/src/components/fields/TextField.tsx
- frontend/src/components/fields/BaseField.tsx
- frontend/src/components/form/HorizontalField.tsx
- frontend/src/apps/docs/models/document/pages/DocumentDisplay.tsx
- frontend/src/apps/common/components/panels/LinkedRecordsPanel.tsx
- frontend/src/apps/common/components/panels/ContactPanel.tsx
- frontend/src/apps/common/components/panels/DbColumns.tsx
- frontend/src/pages/admin/DataBrowser.tsx
- frontend/src/pages/admin/DataBrowser.css
- frontend/src/pages/admin/TouchForm.tsx

## Next Session Priority
1. Test email send in regular browser (handler already registered there)
2. Test touch template selector end-to-end
3. Commit all WebClerk changes
4. Action form layout in Setting (needs proper sections)
5. iPhone PWA testing
