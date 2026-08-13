# ACTION — Upgrade WC3 Superuser Passwords
**Owner:** Bill James
**Created:** 2026-07-27
**Due:** 2026-08-03 (1 week — after stable dataset)
**Status:** Open
**Project:** WC3

## Task

Replace temporary "leftshoe" passwords with production-strength passwords for all superuser Django accounts on both Mac and Andi.

## Current State

- `bill.james@jpods.com` — password "leftshoe" on Mac and Andi
- `bill@jpods.com` and `claude@jpods.com` — not Django Users yet (Contact records only)
- MeshMobility superuser list: bill@jpods.com, bill.james@jpods.com, claude@jpods.com, meshmobility@jpods.com

## When to Do This

After stable dataset — Bill said "in a week." Don't change before then — too much active debugging.

## What to Change

1. Set production passwords for bill.james@jpods.com (Mac + Andi)
2. Create Django User accounts for bill@jpods.com and claude@jpods.com if needed
3. Update the MeshMobility WC3 service password (currently mm-service-2026 in auth.py env vars)
4. Move passwords to environment variables, not source code
5. Consider: encrypt + blockchain audit before release (per trip API action from 2026-05-29)
