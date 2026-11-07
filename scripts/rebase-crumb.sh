#!/usr/bin/env bash
# Rebase a PR branch onto origin/main, resolve conflicts that are only in .crumb files by taking
# main's copy, and push with a lease on the old head. Crumb compile/verify is retired (2026-11-07,
# DRA-97): the crumb tool is never run and no crumb commit is added; .crumb files are history.
#
# Usage: rebase-crumb.sh <worktree> <branch>
# Env:   GIT (default git), so tests can stub it.
# Exit:  0 done, 2 precondition refused, 3 CODE CONFLICT (rebase aborted), 4 checkout, rebase or push
#        failure (nothing pushed).
set -u
GIT=${GIT:-git}

refuse() { echo "REFUSED: $1" >&2; exit 2; }

[ $# -eq 2 ] || { echo "usage: rebase-crumb.sh <worktree> <branch>" >&2; exit 2; }
W=$1; B=$2
cd "$W" 2>/dev/null || refuse "worktree $W does not exist"
$GIT rev-parse --is-inside-work-tree >/dev/null 2>&1 || refuse "$W is not a git checkout"
[ -z "$($GIT status --porcelain)" ] || refuse "working tree is not clean"
[ "$B" != "main" ] || refuse "branch is main"
URL=$($GIT config --get remote.origin.url 2>/dev/null) || refuse "no origin remote"
case "$URL" in
  *github.com/aien-dev/*|*git@github.com:aien-dev/*) ;;
  *) refuse "origin URL is not under aien-dev: $URL" ;;
esac
$GIT fetch -q origin || refuse "fetch failed"
$GIT rev-parse -q --verify "refs/remotes/origin/$B" >/dev/null || refuse "origin/$B does not exist"

GD=$($GIT rev-parse --git-dir)
LOCK="$GD/rebase-crumb.lock"
if [ -e "$LOCK" ] && [ -z "$(find "$LOCK" -mmin +120 2>/dev/null)" ]; then
  refuse "lock $LOCK is fresh (another run, or younger than 2 hours)"
fi
echo $$ > "$LOCK" || refuse "cannot create lock"
trap 'rm -f "$LOCK"' EXIT

LEASE=$($GIT rev-parse "origin/$B")
$GIT checkout -q -B "$B" "origin/$B" || { echo "checkout failed" >&2; exit 4; }

rebasing() { [ -d "$($GIT rev-parse --git-path rebase-merge)" ] || [ -d "$($GIT rev-parse --git-path rebase-apply)" ]; }

# Advance past the commit that was just resolved. `rebase --continue` (and --skip) also exit non-zero
# when they stop at the NEXT commit's conflict; that is progress, not failure, so the loop must see it.
# Returns 0 when the loop should look again, 1 on a real failure.
advance() {
  GIT_EDITOR=true $GIT rebase --continue >/dev/null 2>&1 && return 0
  rebasing || return 0
  [ -z "$($GIT diff --name-only --diff-filter=U)" ] || return 0
  # A resolved commit that became empty cannot be continued; skip it.
  if [ -z "$($GIT diff --cached --name-only)" ]; then
    $GIT rebase --skip >/dev/null 2>&1 && return 0
    rebasing || return 0
    [ -z "$($GIT diff --name-only --diff-filter=U)" ] || return 0
  fi
  return 1
}
fail_rebase() { echo "rebase continue failed" >&2; $GIT status --short | head; $GIT rebase --abort; exit 4; }

$GIT rebase -q origin/main >/dev/null 2>&1
while rebasing; do
  C=$($GIT diff --name-only --diff-filter=U)
  if [ -z "$C" ]; then
    advance || fail_rebase
    continue
  fi
  NONCRUMB=$(echo "$C" | grep -v '\.crumb$' || true)
  if [ -n "$NONCRUMB" ]; then
    echo "CODE CONFLICT: $(echo "$NONCRUMB" | tr '\n' ' ')"
    $GIT rebase --abort
    exit 3
  fi
  # During a rebase "ours" is the branch being rebased onto, which is main.
  echo "$C" | while IFS= read -r f; do
    if $GIT cat-file -e "origin/main:$f" 2>/dev/null; then
      $GIT checkout -q --ours -- "$f" && $GIT add -- "$f"
    else
      $GIT rm -q -f -- "$f"
    fi
  done
  advance || fail_rebase
done

echo "crumb: retired (DRA-97), conflicting .crumb files keep main's copy; no compile, verify or crumb commit"

$GIT push -q --force-with-lease="refs/heads/$B:$LEASE" origin "$B" || { echo "push failed (lease or network)" >&2; exit 4; }
echo "rebased $B onto $($GIT rev-parse --short origin/main): $($GIT log --oneline -1 | cut -c1-70)"
