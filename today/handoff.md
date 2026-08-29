# Handoff — 2026-08-29 (Session 6: Upload Fix + Label Behaviors + Touch)

## Where We Left Off

Upload and label behavior session. About to start on Touch phone/text/email URI handlers.

## What Was Built

### 1. Infinite Render Loop Fix
- `DynamicDetail.tsx:427` — removed `onActionsReady` from useEffect deps
- ActionFloatingWindow passed new arrow function every render → infinite loop

### 2. Upload 500 Fix
- Root cause: `_serialize_document()` referenced `doc.model_name` — doesn't exist on Document model
- Fix: reads from `doc.config["parent_model"]` instead
- Added explicit `JWTAuthentication + SessionAuthentication + IsAuthenticated` to upload views
- TFTS: the 500 was misdiagnosed as auth for a full session; curl would have found it in 30 seconds

### 3. Upload Metadata Dialog
- `FileUploadPanel.tsx` — purpose dropdown (photo/video/attachment/spec/drawing/receipt/qa/other) + description field per file
- Shows file size; Upload/Cancel buttons
- `fontSize: 16` prevents iOS Safari zoom

### 4. refs.links.document Denormalization
- Each upload appends `{id, purpose, description, size_bytes, name, mime_type, lat, lng}` to parent's `refs.links.document`
- Fires `refs-links-changed` event so LinkedRecordsPanel updates count
- Geolocation captured and stored in Document `metadata.address.geo`

### 5. label_href Field Behavior (Setting-Driven)
- `field_behaviors.name.label_href = "path.url"` in document Setting
- `fields/index.tsx` resolves dot-path from record, passes `labelHref` to widget
- `BaseField.tsx` renders label as `<a>` with `db-label--actionable` color
- `HorizontalField.tsx` supports `labelHref` prop for form layouts
- Works in both db.detail (Admin) and db.form (App) views
- TFTS: four failed attempts hardcoding per-layout before getting to Setting-driven

## Files Modified

### Backend
```
backend/apps/docs/views/upload_view.py — auth classes, model_name fix, geo in response
backend/readmes/upload-auth-architecture.md — NEW
```

### Frontend
```
frontend/src/components/common/DynamicDetail.tsx — infinite loop fix
frontend/src/components/common/FileUploadPanel.tsx — upload dialog, refs.links append
frontend/src/components/fields/index.tsx — label_href behavior resolution
frontend/src/components/fields/TextField.tsx — forward labelHref to BaseField
frontend/src/components/fields/BaseField.tsx — actionable color for label links
frontend/src/components/form/HorizontalField.tsx — labelHref prop
frontend/src/apps/docs/models/document/pages/DocumentDisplay.tsx — labelHref on Name/Slug
```

## TODO: Touch Records — Phone, Text, Email

**Goal:** When Save Touch is clicked, the touch is recorded AND the appropriate communication channel opens with the form data pre-filled.

### What Needs to Happen
1. All URI handlers (tel:, sms:, mailto:) fire on SAVE, not on form OPEN
2. TouchBar.openForm should only open the form — no URI firing
3. TouchForm.handleSave fires the URI after successful save
4. TouchPrefs (phone_action, email_action, text_action) control behavior at save time
5. auto_log pref: skip form, save + fire URI in one click

### Key Files
- `frontend/src/pages/admin/TouchForm.tsx` — handleSave needs URI firing
- `frontend/src/pages/admin/TouchBar.tsx` — openForm should NOT fire URIs
- `frontend/src/pages/admin/TouchBadge.tsx` — badge count display

## Next Session Priority
1. Touch phone/text/email — URI handlers on Save
2. iPhone PWA testing
3. Commit all WebClerk changes
