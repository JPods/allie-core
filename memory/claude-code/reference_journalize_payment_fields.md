---
name: Payment model has no dt_journaled field
description: Payment uses is_locked + dt_processed (DateTimeField) for journalize lock, NOT dt_journaled (which Invoice has as BigIntegerField)
type: reference
---

Payment model lock fields: `is_locked` (BooleanField) + `dt_processed` (DateTimeField).
Invoice model lock fields: `dt_journaled` (BigIntegerField, epoch ms) + `is_locked`.

**Why:** Scar from 2026-08-22 — `journalize_payment` crashed with `FieldDoesNotExist: Payment has no field named 'dt_journaled'`. Fixed to use `is_locked=True, dt_processed=timezone.now()`.

**How to apply:** When locking payments after GL posting, use `django.utils.timezone.now()` for `dt_processed` (it's a DateTimeField, not epoch ms). The `dt_modified` field IS BigIntegerField (`_now_ms()`). Don't mix them up.

File: `WebClerk/backend/apps/accounts/services/journalize.py` lines ~548 and ~468.
