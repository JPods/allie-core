---
name: Fixed column widths — user allocation, not dynamic sizing
description: Never auto-size columns; users stack important info in first 20-30 chars; dynamic widths steal space from other visible columns
type: feedback
---

Column widths are the user's allocation decision. Never dynamically auto-size columns to fit content.

**Why:** Users put the important information in the first 20-30 characters of a field value. They know what's there. A 100px column for a 500-character description is intentional — they see enough to identify the record, and the rest of the screen goes to columns like project_name, status, priority. Dynamic auto-sizing steals that space and hides the columns the user chose to display.

**How to apply:** No auto-fit, no content-based column sizing, no "smart" width adjustment. The user sets the width (drag, type, or dialog). The system respects it. A 5px column is a presence marker. A 100px column on a long field is a deliberate truncation. Both are correct because the user decided.

**Do not overhelp.** If a user makes a column too wide and can't see the others, they'll fix it — that's learning. If the system auto-adjusts, the user never develops judgment about space allocation and gives up because they can't see enough to make decisions. The pain of a bad choice is the teacher.
