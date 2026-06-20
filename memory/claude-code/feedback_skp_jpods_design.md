---
name: skp_jpods folder design preferences
description: Bill's preferences for the student file management UX: unique folder names, no spaces, two-offer agreement, script in utilities not /tmp
type: feedback
---

When designing the student file-management system for su_jpods:

- **Folder name `skp_jpods`**, not `JPods Projects` or similar. Unique name avoids
  collisions with the many files students will have with "JPods" or "Projects" in their
  names. No spaces in folder names — Bill dislikes spaces in paths.

- **Two-offer agreement pattern:** Offer at startup; if NO, offer once more at first Build;
  if NO again, they're on their own. Never ask a third time. This is the right balance
  between guidance and respecting student autonomy.

- **Scripts go in `utilities/`, not `/tmp`.** Students should be able to inspect what
  the plugin ran on their behalf. `/tmp` is opaque; `utilities/organize.sh` is readable.

- **Both move options close SketchUp.** When offering to move files: YES = script does
  it; NO = user does it; both quit. CANCEL = keep working. Don't try to move files while
  SketchUp holds the .skp open.

**Why:** Bill is building a gamified city-design tool for students. Discipline in file
management must be taught gently, not imposed. Two chances respects their choice.
Unique names and no spaces are engineering discipline applied consistently.

**How to apply:** Any future file-management or onboarding UX in su_jpods should follow
the same two-offer, unique-name, utilities-folder pattern.
