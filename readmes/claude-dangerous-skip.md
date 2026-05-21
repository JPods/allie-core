# Claude Code — dangerously-skip-permissions

## What It Does

`--dangerously-skip-permissions` bypasses ALL Claude Code permission prompts for the session.
No confirmation dialogs. No "Contains backslash-escaped whitespace" blocks. No approval
required for any tool call — Read, Write, Edit, Bash, or otherwise.

---

## Why We Use It

Bill's working directories include paths with spaces:

```
/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/
```

Claude Code's built-in safety layer flags any Bash command containing backslash-escaped
whitespace (`Application\ Support`, `SketchUp\ 2026`). This fires on nearly every
SketchUp plugin operation. There is no `allow` rule that suppresses this specific check —
it cannot be turned off per-path, only globally.

---

## How It Is Set

An alias in `~/.zshrc` (`/Users/williamjames/.zshrc`):

```bash
alias claude='claude --dangerously-skip-permissions'
```

Every `claude` invocation from a terminal automatically includes the flag.

**To view the file:** In Terminal: `open ~/.zshrc`  
**To find it in Finder:** Cmd+Shift+G → paste `/Users/williamjames/.zshrc` → Enter

---

## How to Undo

Remove the alias:

```bash
grep -n "dangerously" ~/.zshrc        # find the line number (e.g., line 12)
sed -i '' '12d' ~/.zshrc              # delete that line (replace 12 with actual number)
source ~/.zshrc                       # reload
```

Or: `open ~/.zshrc`, delete the alias line, save, then `source ~/.zshrc`.

---

## What This Means in Practice

- Claude Code will execute any tool call without asking
- The `allow` rules in `~/.claude/settings.json` are still present but irrelevant —
  they are superseded by the flag
- Athena's signing and review protocol is unaffected — that runs at the application
  layer, not the Claude Code permission layer
- This is safe on Bill's Mac because Claude Code runs in a session Bill initiates;
  it is not a server or daemon

---

## Risk Register Entry

`CL-SKIP-01` — No permission guardrails on Claude Code tool calls.  
**Mitigations:** Single-user machine. Bill initiates every session. Athena reviews
non-standing actions. Git history is the audit trail. All destructive operations
(push, drop, delete) still require explicit instruction.

**Do not run Claude Code with `--dangerously-skip-permissions` on a shared machine
or in any automated/unattended context.**
