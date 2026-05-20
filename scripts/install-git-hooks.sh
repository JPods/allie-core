#!/usr/bin/env bash
# install-git-hooks.sh — Install Allie capture hooks in all project git repos
#
# Each repo gets a .git/hooks/post-commit that calls the shared
# ~/Allie/scripts/git-post-commit.sh so updates to the shared script
# apply everywhere without reinstalling.
#
# Usage:
#   bash ~/Allie/scripts/install-git-hooks.sh          # install all
#   bash ~/Allie/scripts/install-git-hooks.sh --status # check current state

SHARED="$HOME/Allie/scripts/git-post-commit.sh"
chmod +x "$SHARED"

REPOS=(
  "$HOME/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods"
  "$HOME/Documents/08_JPods/03_Technology/00_working_code/route_time"
  "$HOME/Documents/08_JPods/03_Technology/00_working_code/JPodsSM_RPi"
  "$HOME/Documents/CommerceExpert/webClerk3"
  "$HOME/Allie"
)

HOOK_BODY='#!/usr/bin/env bash
# Allie capture hook — calls shared script
# Installed by: ~/Allie/scripts/install-git-hooks.sh
SHARED="$HOME/Allie/scripts/git-post-commit.sh"
[[ -f "$SHARED" ]] && bash "$SHARED"
exit 0
'

install_hook() {
  local repo="$1"
  local hook="$repo/.git/hooks/post-commit"

  if [[ ! -d "$repo/.git" ]]; then
    echo "  SKIP  $repo  (not a git repo)"
    return
  fi

  mkdir -p "$repo/.git/hooks"

  if [[ -f "$hook" ]]; then
    # Check if it's already our hook
    if grep -q "Allie capture hook" "$hook" 2>/dev/null; then
      echo "  OK    $(basename "$repo")  (already installed)"
      return
    fi
    # Back up existing hook
    cp "$hook" "${hook}.pre-allie"
    echo "  BAK   $(basename "$repo")  (existing hook backed up to post-commit.pre-allie)"
  fi

  printf '%s' "$HOOK_BODY" > "$hook"
  chmod +x "$hook"
  echo "  DONE  $(basename "$repo")"
}

status_hook() {
  local repo="$1"
  local hook="$repo/.git/hooks/post-commit"
  local name
  name=$(basename "$repo")

  if [[ ! -d "$repo/.git" ]]; then
    echo "  NOT_GIT  $name"
  elif [[ ! -f "$hook" ]]; then
    echo "  MISSING  $name  (no post-commit hook)"
  elif grep -q "Allie capture hook" "$hook" 2>/dev/null; then
    echo "  OK       $name"
  else
    echo "  OTHER    $name  (post-commit exists but not Allie's)"
  fi
}

case "${1:-install}" in
  --status|status)
    echo "Git hook status:"
    for repo in "${REPOS[@]}"; do
      status_hook "$repo"
    done
    ;;
  install|"")
    echo "Installing Allie post-commit hooks:"
    for repo in "${REPOS[@]}"; do
      install_hook "$repo"
    done
    echo ""
    echo "Done. Every commit in these repos now logs to ~/Allie/logs/events.jsonl"
    ;;
  *)
    echo "Usage: install-git-hooks.sh [--status]"
    exit 1
    ;;
esac
