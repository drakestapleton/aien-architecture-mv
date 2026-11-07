#!/usr/bin/env bash
# PR merge gate for aien-dev repositories. Reads GitHub state at the moment of the call, checks
# docs/REPOSITORY_EXECUTION_RULES.md rules 4 and 5, then (unless --dry-run) squash-merges. Rule 2
# (crumb compile/verify) is retired (2026-11-07, DRA-97): step 3 always SKIPs and never runs crumb.
# It does not replace a human read of the diff, and it never rebases anything by itself.
#
# Usage: pr-gate.sh <repo> <pr-number> [--worktree DIR] [--dry-run] [--admin-authorized-by "<who, date, reason>"]
# Env:   GH (default gh), GIT (default git), SLEEP_SECS (default 10, UNKNOWN retry).
# Output: one line per step, "GATE <step>: PASS|FAIL|SKIP <reason>". Exit 1 at the first FAIL.
set -u
GH=${GH:-gh}
GIT=${GIT:-git}
SLEEP_SECS=${SLEEP_SECS:-10}

usage() { echo 'usage: pr-gate.sh <repo> <pr-number> [--worktree DIR] [--dry-run] [--admin-authorized-by "<who, date, reason>"]' >&2; exit 2; }
[ $# -ge 2 ] || usage
REPO=$1; N=$2; shift 2
WT=""; DRY=0; ADMIN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --worktree) [ $# -ge 2 ] || usage; WT=$2; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --admin-authorized-by) [ $# -ge 2 ] || usage; ADMIN=$2; shift 2 ;;
    *) usage ;;
  esac
done
case "$N" in ''|*[!0-9]*) usage ;; esac
FULL="aien-dev/$REPO"

pass() { echo "GATE $1: PASS $2"; }
skip() { echo "GATE $1: SKIP $2"; }
fail() { echo "GATE $1: FAIL $2"; exit 1; }

FIELDS=number,state,isDraft,baseRefName,headRefName,headRefOid,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup
view() { $GH pr view "$N" -R "$FULL" --json "$FIELDS" 2>&1; }

# 1. pr
PR=$(view) || fail pr "could not read PR: $(echo "$PR" | head -1)"
echo "$PR" | jq -e . >/dev/null 2>&1 || fail pr "gh did not return JSON"
f() { echo "$PR" | jq -r "$1"; }
STATE=$(f .state); DRAFT=$(f .isDraft); BASE=$(f .baseRefName); HEADREF=$(f .headRefName); HEADOID=$(f .headRefOid)
[ "$STATE" = OPEN ] || fail pr "state is $STATE, not OPEN"
[ "$DRAFT" = false ] || fail pr "PR is a draft"
[ "$BASE" = main ] || fail pr "base is $BASE, not main"
pass pr "#$N $HEADREF at ${HEADOID:0:8}, open, not draft, base main"

# 2. local
if [ -z "$WT" ]; then
  skip local "no worktree given"
else
  G="$GIT -C $WT"
  $G rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail local "$WT is not a git checkout"
  $G fetch -q origin 2>/dev/null || fail local "fetch failed in $WT"
  [ -z "$($G status --porcelain)" ] || fail local "worktree is dirty"
  CUR=$($G rev-parse --abbrev-ref HEAD)
  [ "$CUR" = "$HEADREF" ] || fail local "worktree is on $CUR, PR branch is $HEADREF"
  [ "$($G rev-parse HEAD)" = "$HEADOID" ] || fail local "local HEAD $($G rev-parse --short HEAD) differs from GitHub head ${HEADOID:0:7}"
  [ "$($G merge-base origin/main HEAD)" = "$($G rev-parse origin/main)" ] || fail local "stale base, branch is not on current origin/main; run scripts/rebase-crumb.sh"
  pass local "clean, on $CUR, HEAD matches GitHub, based on current origin/main"
fi

# 3. crumb: rule 2 is retired. No crumb verify, no crumb-commit-last check; .crumb files are history.
skip crumb "retired 2026-11-07 (DRA-97); .crumb files are history"

# 4. base
TRIES=0
while :; do
  MSS=$(f .mergeStateStatus); MRG=$(f .mergeable)
  [ "$MSS" = UNKNOWN ] || break
  TRIES=$((TRIES+1))
  [ "$TRIES" -le 5 ] || fail base "GitHub has not computed mergeability"
  sleep "$SLEEP_SECS"
  PR=$(view) || fail base "could not re-read PR"
  [ "$(f .headRefOid)" = "$HEADOID" ] || fail base "PR head changed during mergeability wait; restart inspection"
done
[ "$MRG" != CONFLICTING ] || fail base "mergeable is CONFLICTING (merge conflicts)"
case "$MSS" in
  CLEAN) pass base "mergeStateStatus CLEAN" ;;
  BEHIND) fail base "stale, rebase first" ;;
  DIRTY) fail base "merge conflicts" ;;
  BLOCKED) fail base "required checks or reviews missing" ;;
  UNSTABLE) fail base "a check is failing" ;;
  HAS_HOOKS)
    if [ "$DRY" = 1 ]; then pass base "HAS_HOOKS (accepted in dry run only)"
    else fail base "merge queue or hooks present, check by hand"; fi ;;
  *) fail base "unexpected mergeStateStatus $MSS" ;;
esac

# 5. checks
RD=$(f '.reviewDecision // ""')
case "$RD" in
  CHANGES_REQUESTED) fail checks "reviewDecision is CHANGES_REQUESTED" ;;
  REVIEW_REQUIRED) fail checks "reviewDecision is REVIEW_REQUIRED" ;;
esac
PROT=$($GH api "repos/$FULL/branches/main/protection/required_status_checks" --jq .contexts 2>&1); PRC=$?
if [ "$PRC" -ne 0 ]; then
  if echo "$PROT" | grep -qE '404|Not Found'; then
    echo "WARNING: $FULL main has no branch protection; no required contexts to verify" >&2
    skip checks "no branch protection"
  else
    fail checks "could not read required checks: $(echo "$PROT" | head -1)"
  fi
else
  echo "$PROT" | jq -e 'type=="array"' >/dev/null 2>&1 || fail checks "required checks response is not a list"
  MISSING=$(echo "$PR" | jq -r --argjson req "$PROT" '
    (.statusCheckRollup // []) as $r
    | $req[] as $c
    | select(([$r[] | select((.name == $c or .context == $c) and (.conclusion == "SUCCESS" or .state == "SUCCESS"))] | length) == 0)
    | $c')
  [ -z "$MISSING" ] || fail checks "required check not green: $(echo "$MISSING" | tr '\n' ',' | sed 's/,$//')"
  pass checks "$(echo "$PROT" | jq 'length') required contexts green, reviewDecision ${RD:-none}"
fi

# 6. merge
if [ "$DRY" = 1 ]; then
  skip merge "dry run"
else
  ARGS=(pr merge "$N" -R "$FULL" --squash --delete-branch --match-head-commit "$HEADOID")
  NOTE="squash"
  if [ -n "$ADMIN" ]; then ARGS+=(--admin); NOTE="squash with --admin, authorized by: $ADMIN"; fi
  MOUT=$($GH "${ARGS[@]}" 2>&1) || fail merge "gh pr merge failed: $(echo "$MOUT" | head -1)"
  POST=$($GH pr view "$N" -R "$FULL" --json state,mergedAt,mergeCommit 2>&1) || fail merge "merge ran but state could not be re-read"
  [ "$(echo "$POST" | jq -r .state)" = MERGED ] || fail merge "after merge, state is $(echo "$POST" | jq -r .state), not MERGED"
  pass merge "$NOTE; merge commit $(echo "$POST" | jq -r '.mergeCommit.oid // "unknown"')"
fi

# 7. queue
LIST=$($GH pr list -R "$FULL" --json number,headRefName,mergeStateStatus 2>&1) || fail queue "could not list open PRs: $(echo "$LIST" | head -1)"
echo "$LIST" | jq -r --argjson me "$N" '.[] | select(.number != $me)
  | "QUEUE #\(.number) \(.headRefName) \(.mergeStateStatus)" + (if (.mergeStateStatus == "BEHIND" or .mergeStateStatus == "DIRTY") then " needs scripts/rebase-crumb.sh" else "" end)'
pass queue "$(echo "$LIST" | jq --argjson me "$N" '[.[] | select(.number != $me)] | length') other open PRs listed, none rebased"
exit 0
