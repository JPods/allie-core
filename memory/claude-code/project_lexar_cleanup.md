---
name: Lexar drive cleanup — archive sort pending
description: Lexar (116GB) is 98% full; archive sort + spam clear needed; sjobs content must be preserved
type: project
---

Lexar drive (`/Volumes/ALLIE_LEXAR`) is at 98% capacity (113GB used, 2.9GB free). Syncs fail with "no space left on device." The 5TB has all the same content, so nothing is at risk — but Lexar can't receive new files until space is freed.

**Why:** Bill wants to sort through the archive and clear spam rather than just delete large blocks. Duplications are intentional (redundancy). Leave them unless space is urgently needed.

**sjobs rule (critical):** Anything with "sjobs" in the name or content must be preserved — Bill flagged this as potentially very important. As of 2026-05-02, no files named "sjobs" exist on either drive yet. Watch for this during any sort/import work.

**How to apply:** When Bill says "clean up the Lexar" or "sort the archive," start here. Do NOT bulk-delete without reviewing. Present candidates; Bill decides.

---

## Archive breakdown (2026-05-02)

| Folder | Size | Notes |
|--------|------|-------|
| `archive/TextMessageBackup-2018-04-15/` | 52 GB | 8-year-old iMessage backup — largest single item, safe to delete from Lexar if space needed (5TB has it) |
| `archive/crm/act/` | 33 GB | Old ACT/Dropbox dump. Largest sub: Camera Uploads 27GB, PicturesFamily 1.6GB, Screenshots 798MB |
| `archive/video/` | 17 GB | Video files |
| `archive/pi/` | 1.6 GB | Pi images |
| `archive/jpods/` | 1.6 GB | Old JPods archive |
| `archive/personal/` | 1.5 GB | Google Drive legacy docs |
| `archive/email/` | 292 MB | Airmail export (bill@jpods.com) |
| `Allie/` | 7.5 GB | Working Allie copy — correct, keep |

**Spam candidates (to sort first):**
- `archive/crm/act/Bill James/Camera Uploads/` — 27GB of Dropbox camera photos; likely bulk duplicates
- `archive/crm/act/Bill James/Screenshots/` — 798MB of screenshots; likely mostly disposable
- `._` prefixed files throughout (macOS resource fork artifacts) — can be deleted safely

**If urgent space needed (in order):**
1. Delete `archive/TextMessageBackup-2018-04-15/` from Lexar only → frees 52GB
2. Delete Camera Uploads from Lexar only → frees 27GB immediately; exact duplicate confirmed on 5TB 2026-05-02; date range 2009–2017, mostly .mod video files
3. Sort remaining Camera Uploads for unique/important photos before touching 5TB copy
