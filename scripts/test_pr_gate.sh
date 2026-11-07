#!/usr/bin/env bash
# Offline test for pr-gate.sh. A fake `gh` on PATH answers from fixture JSON chosen by $CASE and
# records any merge command line. Local and crumb steps use real temporary git repos (bare origin
# plus worktree). The crumb step is retired (DRA-97): a `crumb` stub that exits 99 is on PATH and in
# $CRUMB, and the test proves it is never called. No network, no auth.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
gate="$here/pr-gate.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export SLEEP_SECS=0
FX="$tmp/fx"; mkdir -p "$FX" "$tmp/bin"; export FX

cat > "$tmp/bin/gh" <<'S'
#!/usr/bin/env bash
d="$FX/$CASE"
case "$1 $2" in
  "pr view")
    if echo "$*" | grep -q mergeCommit && [ -e "$d/merged-flag" ]; then cat "$d/merged.json"
    elif [ -e "$d/updated.json" ] && [ -e "$d/viewed" ]; then cat "$d/updated.json"
    else
      touch "$d/viewed"
      cat "$d/pr.json"
    fi ;;
  "pr list") cat "$d/list.json" ;;
  "pr merge")
    echo "$*" > "$d/merge.cmd"
    if [ -e "$d/updated.json" ]; then
      want=$(jq -r .headRefOid "$d/updated.json")
      [[ " $* " == *" --match-head-commit $want "* ]] || { echo "head branch changed" >&2; exit 1; }
    fi
    touch "$d/merged-flag" ;;
  api\ repos/*)
    if [ -e "$d/prot404" ]; then echo "gh: Not Found (HTTP 404)" >&2; exit 1; fi
    cat "$d/prot.json" ;;
  *) echo "fake gh: unhandled: $*" >&2; exit 2 ;;
esac
S
cat > "$tmp/bin/crumb" <<'S'
#!/usr/bin/env bash
# retired: any call is a test failure (recorded, then exit 99)
echo "$*" >> "$FX/crumb-called"
exit 99
S
chmod +x "$tmp/bin/gh" "$tmp/bin/crumb"
export PATH="$tmp/bin:$PATH" CRUMB="$tmp/bin/crumb"
RETIRED='GATE crumb: SKIP retired 2026-11-07 \(DRA-97\); .crumb files are history'

pass=0; bad=0
ok() { pass=$((pass+1)); }
no() { bad=$((bad+1)); echo "TEST FAIL: $1"; }
run() { OUT=$("$gate" "$@" 2>&1); rc=$?; }
expect() { # expect <rc> <label> <gate args...>
  w=$1; l=$2; shift 2; run "$@"
  if [ "$rc" = "$w" ]; then ok; else no "$l (rc=$rc, want $w): $OUT"; fi
}
has() { # has <label> <pattern>   against $OUT
  if echo "$OUT" | grep -qE -- "$2"; then ok; else no "$1 (missing /$2/): $OUT"; fi
}
hasnot() { if echo "$OUT" | grep -qE -- "$2"; then no "$1 (unexpected /$2/): $OUT"; else ok; fi; }

# fixture builder: fx <case> [jq filter applied to the clean PR]
CLEANPR='{"number":7,"state":"OPEN","isDraft":false,"baseRefName":"main","headRefName":"feat","headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","reviewDecision":"","statusCheckRollup":[{"__typename":"CheckRun","name":"rust","status":"COMPLETED","conclusion":"SUCCESS"},{"__typename":"StatusContext","context":"legacy-ci","state":"SUCCESS"}]}'
fx() {
  mkdir -p "$FX/$1"
  echo "$CLEANPR" | jq "${2:-.}" > "$FX/$1/pr.json"
  echo '["rust","legacy-ci"]' > "$FX/$1/prot.json"
  echo '[{"number":7,"headRefName":"feat","mergeStateStatus":"CLEAN"},{"number":9,"headRefName":"other","mergeStateStatus":"BEHIND"},{"number":10,"headRefName":"third","mergeStateStatus":"CLEAN"}]' > "$FX/$1/list.json"
  echo '{"state":"MERGED","mergedAt":"2026-10-10T00:00:00Z","mergeCommit":{"oid":"cafebabecafebabecafebabecafebabecafebabe"}}' > "$FX/$1/merged.json"
}

# ---- GitHub-side cases (no worktree)
fx clean;      export CASE=clean;     expect 0 "clean PR passes dry run" repo1 7 --dry-run
has "dry run prints pr PASS" 'GATE pr: PASS'
has "local skipped without worktree" 'GATE local: SKIP no worktree given'
has "merge skipped in dry run" 'GATE merge: SKIP dry run'
has "crumb step retired without worktree" "$RETIRED"
has "queue marks BEHIND PR as needing rebase" 'QUEUE #9 other BEHIND needs scripts/rebase-crumb.sh'
has "queue shows clean PR plainly" 'QUEUE #10 third CLEAN$'
hasnot "queue omits the PR itself" 'QUEUE #7 '
check_nomerge() { if [ ! -e "$FX/$1/merge.cmd" ]; then ok; else no "$2"; fi; }
check_nomerge clean "dry run must not call gh pr merge"

fx behind '.mergeStateStatus="BEHIND"';       CASE=behind  expect 1 "BEHIND refuses" repo1 7 --dry-run
has "BEHIND reason" 'stale, rebase first'
fx dirty '.mergeStateStatus="DIRTY"';         CASE=dirty   expect 1 "DIRTY refuses" repo1 7 --dry-run
fx blocked '.mergeStateStatus="BLOCKED"';     CASE=blocked expect 1 "BLOCKED refuses" repo1 7 --dry-run
fx unstable '.mergeStateStatus="UNSTABLE"';   CASE=unstable expect 1 "UNSTABLE refuses" repo1 7 --dry-run
fx conflicting '.mergeable="CONFLICTING"';    CASE=conflicting expect 1 "mergeable CONFLICTING refuses" repo1 7 --dry-run
fx unknown '.mergeStateStatus="UNKNOWN"';     CASE=unknown expect 1 "UNKNOWN retries then refuses" repo1 7 --dry-run
has "UNKNOWN reason" 'has not computed mergeability'
fx hooks '.mergeStateStatus="HAS_HOOKS"';     CASE=hooks   expect 0 "HAS_HOOKS passes in dry run" repo1 7 --dry-run
CASE=hooks expect 1 "HAS_HOOKS refuses on a real merge" repo1 7
check_nomerge hooks "HAS_HOOKS real run must not merge"
fx draft '.isDraft=true';                     CASE=draft   expect 1 "draft refuses" repo1 7 --dry-run
fx closed '.state="CLOSED"';                  CASE=closed  expect 1 "closed refuses" repo1 7 --dry-run
fx wrongbase '.baseRefName="release"';        CASE=wrongbase expect 1 "non-main base refuses" repo1 7 --dry-run
fx missing '.statusCheckRollup=[{"__typename":"CheckRun","name":"rust","conclusion":"SUCCESS"}]'
CASE=missing expect 1 "required check absent from rollup refuses" repo1 7 --dry-run
has "names the missing check" 'legacy-ci'
fx failing '.statusCheckRollup[0].conclusion="FAILURE"'
CASE=failing expect 1 "required check present but FAILURE refuses" repo1 7 --dry-run
fx changes '.reviewDecision="CHANGES_REQUESTED"'; CASE=changes expect 1 "CHANGES_REQUESTED refuses" repo1 7 --dry-run
fx reqrev '.reviewDecision="REVIEW_REQUIRED"';    CASE=reqrev expect 1 "REVIEW_REQUIRED refuses" repo1 7 --dry-run
fx approved '.reviewDecision="APPROVED"';         CASE=approved expect 0 "APPROVED passes" repo1 7 --dry-run
fx noprot; touch "$FX/noprot/prot404";            CASE=noprot expect 0 "404 on protection gives SKIP and passes" repo1 7 --dry-run
has "no protection SKIP line" 'GATE checks: SKIP no branch protection'
has "no protection warning" 'WARNING'
fx noprotb '.mergeStateStatus="BEHIND"'; touch "$FX/noprotb/prot404"
CASE=noprotb expect 1 "404 protection does not rescue a BEHIND PR" repo1 7 --dry-run

# ---- merge cases
fx merge;  CASE=merge expect 0 "clean PR merges (non-dry-run)" repo1 7
has "merge PASS with sha" 'GATE merge: PASS squash; merge commit cafebabe'
if grep -q -- '--match-head-commit aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$FX/merge/merge.cmd"; then ok; else no "merge binds the inspected head"; fi
fx moved
echo "$CLEANPR" | jq '.headRefOid="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"' > "$FX/moved/updated.json"
CASE=moved expect 1 "moving head refuses at merge" repo1 7
has "moving head refuses merge" 'head branch changed'
check_notmerged() { if [ ! -e "$FX/$1/merged-flag" ]; then ok; else no "$2"; fi; }
check_notmerged moved "moving head was merged"
fx unknownmoved '.mergeStateStatus="UNKNOWN"'
echo "$CLEANPR" | jq '.headRefOid="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"' > "$FX/unknownmoved/updated.json"
CASE=unknownmoved expect 1 "UNKNOWN refresh changing head refuses before merge" repo1 7
has "UNKNOWN head changed reason" 'head changed during mergeability wait'
check_notmerged unknownmoved "UNKNOWN refresh merged changed head"
if grep -q -- '--squash --delete-branch' "$FX/merge/merge.cmd" && ! grep -q -- '--admin' "$FX/merge/merge.cmd"; then ok; else no "merge command has squash+delete-branch and no --admin: $(cat "$FX/merge/merge.cmd" 2>&1)"; fi
fx adm; CASE=adm expect 0 "authorized admin merge" repo1 7 --admin-authorized-by "Drake, 2026-10-10, test"
if grep -q -- '--admin' "$FX/adm/merge.cmd"; then ok; else no "--admin recorded when authorized"; fi
has "authorization text printed" 'authorized by: Drake, 2026-10-10, test'
fx admfail '.mergeStateStatus="BLOCKED"'; CASE=admfail expect 1 "--admin never overrides a BLOCKED PR" repo1 7 --admin-authorized-by "Drake, 2026-10-10, test"
check_nomerge admfail "no merge call for BLOCKED even with authorization"
fx notmerged; echo '{"state":"OPEN","mergedAt":null,"mergeCommit":null}' > "$FX/notmerged/merged.json"
CASE=notmerged expect 1 "merge not confirmed is a FAIL" repo1 7
has "reports not MERGED" 'not MERGED'
CASE=clean expect 2 "bad usage exits 2" repo1
CASE=clean expect 2 "non-numeric PR exits 2" repo1 abc

# ---- local and crumb cases with real git repos
# mkrepo <name> [nocrumb]: main has src.txt (+ .crumb); branch feat = commit "feat", then (crumbs) commit "crumb compile".
mkrepo() {
  d="$tmp/$1"; mkdir -p "$d"; git init -q --bare -b main "$d/origin.git"; git init -q -b main "$d/seed"
  ( cd "$d/seed" && echo base > src.txt && { [ "${2:-}" = nocrumb ] || echo c0 > .crumb; } && git add -A && git commit -q -m base \
    && git remote add origin "$d/origin.git" && git push -q origin main )
  git clone -q "$d/origin.git" "$d/w"
  ( cd "$d/w" && git checkout -q -b feat && echo feat > feat.txt && git add -A && git commit -q -m feat
    if [ "${2:-}" != nocrumb ]; then echo c1 > .crumb && git add -A && git commit -q -m "crumb compile"; fi
    git push -q origin feat )
  W="$d/w"
}
lfx() { # lfx <case> : fixture whose headRefOid is the worktree HEAD
  fx "$1" ".headRefOid=\"$(git -C "$W" rev-parse HEAD)\""
}
mkrepo l1; lfx l1; CASE=l1 expect 0 "local+crumb clean passes" repo1 7 --dry-run --worktree "$W"
has "local PASS" 'GATE local: PASS'
has "crumb step retired with worktree" "$RETIRED"

mkrepo l2; echo dirt >> "$W/feat.txt"; lfx l2; CASE=l2 expect 1 "dirty worktree refuses" repo1 7 --dry-run --worktree "$W"
has "dirty reason" 'worktree is dirty'

mkrepo l3; git -C "$W" checkout -q -b other; lfx l3; CASE=l3 expect 1 "wrong branch refuses" repo1 7 --dry-run --worktree "$W"
has "wrong branch reason" 'worktree is on other'

mkrepo l4
fx l4 '.headRefOid="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'; CASE=l4 expect 1 "local HEAD differs from GitHub head refuses" repo1 7 --dry-run --worktree "$W"
has "oid mismatch reason" 'differs from GitHub head'

mkrepo l5
( cd "$tmp/l5/seed" && echo more > more.txt && git add -A && git commit -q -m "main moves" && git push -q origin main )
lfx l5; CASE=l5 expect 1 "stale base refuses" repo1 7 --dry-run --worktree "$W"
has "stale base points at rebase script" 'run scripts/rebase-crumb.sh'

mkrepo l6; ( cd "$W" && echo src2 > src2.txt && git add -A && git commit -q --amend -m "mixed" )
lfx l6; CASE=l6 expect 0 "HEAD commit mixing source and .crumb no longer refuses (rule 2 retired)" repo1 7 --dry-run --worktree "$W"
has "mixed commit gives retired SKIP" "$RETIRED"
hasnot "mixed commit not refused by rule 2" 'must be separate and last'

mkrepo l7; lfx l7; CRUMB=/nonexistent/crumb CASE=l7 expect 0 "missing crumb tool does not matter" repo1 7 --dry-run --worktree "$W"
has "missing crumb tool gives retired SKIP" "$RETIRED"
hasnot "no crumb verify message" 'did not print OK'

mkrepo l8 nocrumb; lfx l8; CASE=l8 expect 0 "repo without crumbs passes" repo1 7 --dry-run --worktree "$W"
has "no crumbs gives retired SKIP" "$RETIRED"

# crumbs exist but this PR does not touch them: HEAD may be a source commit
mkrepo l9
( cd "$W" && git reset -q --hard HEAD~1 && git push -q -f origin feat )
lfx l9; CASE=l9 expect 0 "PR that does not touch crumbs may end on a source commit" repo1 7 --dry-run --worktree "$W"

# a PR that deletes a .crumb, or changes source after its crumb commit (stale crumbs), is not refused
mkrepo l10; ( cd "$W" && git rm -q .crumb && git commit -q -m "delete crumb" && git push -q origin feat )
lfx l10; CASE=l10 expect 0 "deleted .crumb does not refuse" repo1 7 --dry-run --worktree "$W"
has "deleted .crumb gives retired SKIP" "$RETIRED"
mkrepo l11; ( cd "$W" && echo later > later.txt && git add -A && git commit -q -m "source after crumb" && git push -q origin feat )
lfx l11; CASE=l11 expect 0 "source after the crumb commit does not refuse" repo1 7 --dry-run --worktree "$W"

if [ ! -e "$FX/crumb-called" ]; then ok; else no "crumb tool was called: $(cat "$FX/crumb-called")"; fi

echo "PASS $pass FAIL $bad"
[ "$bad" -eq 0 ]
