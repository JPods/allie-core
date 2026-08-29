# Handoff — 2026-08-28 (Session 5: Touch + PWA)

## Where We Left Off

Touch/PWA/file-upload session. Three features built, two bugs open. All changes uncommitted in WebClerk/frontend/.

## What Was Built

### 1. PWA Manifest (iPhone Add-to-Home-Screen)
- `public/manifest.webmanifest` — standalone display, #465FFF theme
- `public/icons/` — icon-192x192.png, icon-512x512.png, apple-touch-icon.png (from logo-icon.svg)
- `index.html` — apple-mobile-web-app meta tags, viewport-fit=cover, manifest link
- `DataBrowser.css` — mobile responsive touch CSS (full-screen dialog on phones, 16px inputs prevent iOS zoom)

### 2. File Uploads on Actions
- `FileUploadPanel.tsx` — rewired to use real `uploadDocument()` from `documentUpload.ts` (FormData POST to `/wcapi/upload/`)
- Captures browser geolocation for on-site photos
- Image thumbnails in attachment list
- Download URL corrected to `/wcapi/document/<id>/`
- Compact mode shows file count badge

### 3. Touch-Contact-Action-Org Interplay
- `TouchBadge.tsx` — refreshKey prop for re-fetch after save; linkage_id query for transactions
- `TouchBar.tsx` — TOUCH_MODELS expanded with invoice/order/proposal/purchase/workorder/requisition; txLinkageId
- `TouchForm.tsx` — "Save + Action" button; mailto: open on Save when channel=email

## Open Bugs

1. **Upload error** — Bill got an error uploading an image. FileUploadPanel now calls `/wcapi/upload/` instead of creating metadata-only records. Check console errors + backend upload_view.py compatibility.
2. **Email on save** — mailto: added to handleSave but untested after reload. Verify it opens Gmail.

## TODO: Touch Records Working with Phone, Text, Gmail

**Goal:** When Save Touch is clicked, the touch is recorded AND the appropriate communication channel opens with the form data pre-filled.

### Email (Gmail)
- [x] mailto: opens on Save Touch when channel=email (added this session)
- [ ] Verify it works after page reload
- [ ] Verify Gmail opens (not Mail.app) — depends on Mac default mail handler
- [ ] Include CC contacts from linkedContacts in the mailto: URL
- [ ] Remove the duplicate mailto: that fires on form OPEN in TouchBar.openForm — should only fire on SAVE

### Phone
- [ ] On Save Touch when channel=call, fire `tel:` (or `facetime-audio:`) URI with contact phone
- [ ] Currently fires on form OPEN only (TouchBar.openForm) — move to fire on SAVE
- [ ] On iPhone PWA, `tel:` opens the dialer directly — verify this works
- [ ] Log call duration after the call ends (manual entry for now)

### Text (SMS)
- [ ] On Save Touch when channel=text, fire `sms:` URI with contact phone and subject as body
- [ ] Currently fires on form OPEN only — move to fire on SAVE  
- [ ] On iPhone, `sms:` opens iMessage — verify pre-filled body works
- [ ] Consider `sms:PHONE?body=SUBJECT` format for cross-platform

### Cross-Channel
- [ ] Unify: all URI handlers fire on SAVE, not on form OPEN — single place in handleSave
- [ ] Remove URI firing from TouchBar.openForm (lines 75-83) — openForm should only open the form
- [ ] TouchPrefs (phone_action, email_action, text_action) should control behavior at save time
- [ ] auto_log pref: if true, skip the form entirely — save touch + fire URI in one click
- [ ] Test on iPhone PWA (Add to Home Screen) — verify tel:/sms:/mailto: all work in standalone mode

### iPhone-Specific
- [ ] Verify PWA manifest works (Add to Home Screen)
- [ ] Verify camera capture works in PWA mode (FileUploadPanel capture="environment")
- [ ] Test touch form usability on iPhone screen — channel buttons, contact picker, impact dots

## Files Modified (Uncommitted)

```
frontend/index.html
frontend/public/manifest.webmanifest (NEW)
frontend/public/icons/icon-192x192.png (NEW)
frontend/public/icons/icon-512x512.png (NEW)
frontend/public/icons/apple-touch-icon.png (NEW)
frontend/src/pages/admin/DataBrowser.css
frontend/src/components/common/FileUploadPanel.tsx
frontend/src/pages/admin/TouchForm.tsx
frontend/src/pages/admin/TouchBar.tsx
frontend/src/pages/admin/TouchBadge.tsx
```

## Next Session Priority

1. Fix upload error (check console + backend)
2. Test email-on-save after reload
3. Unify URI handlers to fire on SAVE not OPEN
4. Test on iPhone
5. Commit all changes
