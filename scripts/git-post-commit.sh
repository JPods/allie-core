#!/usr/bin/env bash
# git-post-commit.sh — Shared post-commit hook for all JPods/Allie repos
#
# Installed by install-git-hooks.sh into each repo's .git/hooks/post-commit
# Each installed hook calls this shared script so updates apply everywhere.
#
# Writes one JSONL line to ~/Allie/logs/events.jsonl via allie-capture.py

CAPTURE="$HOME/Allie/scripts/allie-capture.py"
[[ -f "$CAPTURE" ]] || exit 0

REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
HASH=$(git log -1 --format="%H" 2>/dev/null)
MSG=$(git log -1 --format="%s" 2>/dev/null)
AUTHOR=$(git log -1 --format="%an" 2>/dev/null)
FILES=$(git diff-tree --no-commit-id -r --name-only HEAD 2>/dev/null \
        | head -20 | tr '\n' ',' | sed 's/,$//')
COUNT=$(git diff-tree --no-commit-id -r --name-only HEAD 2>/dev/null | wc -l | tr -d ' ')

DATA=$(python3 -c "
import json, sys
print(json.dumps({
    'hash':   '${HASH}',
    'author': '${AUTHOR}',
    'files':  '${FILES}',
    'count':  int('${COUNT}') if '${COUNT}'.isdigit() else 0,
}))
" 2>/dev/null || echo '{}')

python3 "$CAPTURE" \
  --source "git:${REPO}" \
  --event  "commit" \
  --message "${MSG}" \
  --data    "${DATA}" \
  2>/dev/null

exit 0
