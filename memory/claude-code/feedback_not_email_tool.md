---
name: WC3 is not an email/letter formatting tool
description: Users have Gmail, Word, Pages — WC3 provides data and {{tokens}}, not formatting; kill TinyMCE; export data in formats user tools consume
type: feedback
---

WC3 is not an email tool, not a word processor, not a print design tool. Users already have Gmail, Word, Pages, Affinity. WC3 is a data tool.

**What WC3 does:**
- Provide {{token}} fields users can copy/paste into their own programs
- Export data in formats those programs consume (CSV for mail merge, JSON, clipboard)
- For important templates: store the file path, open it populated via AppleScript (Mac) or terminal (Windows/Linux)

**What WC3 does NOT do:**
- Format emails — Gmail does that
- WYSIWYG HTML editing — Word/Pages does that
- Render HTML correspondence — unnecessary layer

**Why:** Bill mail merges with Gmail all the time. WC3 dumps data into the place Gmail eats. Same with Word or Pages. No reason to duplicate what users already have and prefer.

**How to apply:**
- Never install TinyMCE — kill the dependency before it starts
- MarkdownEditor stays for internal notes/documentation only, not customer correspondence
- Email output_type = "export data user's email client consumes"
- {{token}} clipboard is the key feature — copy tokens, paste into user's tool
- Template automation: store file path in Report.config, open via AppleScript/terminal pre-populated
- Same rule as print: SVG = design, CSS = plumbing, JSON = runtime config. For email: Gmail = design, WC3 = data.
