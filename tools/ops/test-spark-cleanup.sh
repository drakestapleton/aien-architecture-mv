#!/usr/bin/env bash
# test-spark-cleanup.sh [SPARK_CLEANUP]: offline test of spark-cleanup classes 2 and 8 in a scratch HOME.
# Never touches the real home, ~/git or the team board: HOME, the git store and the board all point
# into a mktemp folder. Cases:
#   c2-store    a worktree whose HEAD is in the scratch ~/git store, no upstream: removed under --apply
#   c2-remote   a worktree whose HEAD was pushed to a bare repo OUTSIDE ~/git (it has an upstream and
#               `branch -r --contains` finds it): must be kept and logged not-in-git-store
#   c8-left     an idle clone whose every branch head is in the store: ALARM leftover-copy
#   c8-unst     an idle clone with a commit not in the store: ALARM unstored-copy
#   c8-dirty    an idle clone with an uncommitted change: ALARM dirty-copy
#   c8-model    a 1.1 GiB sparse .safetensors file under ~/work: ALARM model-copy
#   c8-fresh    a clone written now: no ALARM
#   c8-wt-own   in the dry run the idle worktree wt-store (HEAD in the store) is a leftover-copy, not
#               unstored because a sibling worktree's branch is missing from the store
#   c8-rerun    the alarms of the first (dry) run still fire on the second run: the checks themselves
#               must not rewrite a copy and make it look recently used
#   c8-board    the --apply run writes exactly one ALARM line to the scratch board; a dry run writes none
#   c8-nodel    class 8 deletes nothing
# Then five mutants of spark-cleanup must each make at least one case fail.
# Ends `TEST PASS cases=N mutants=M/M` (exit 0) or `TEST FAIL ...` (exit 1).
set -u
here=$(cd "$(dirname "$0")" && pwd)
sc=${1:-$here/spark-cleanup}
[ -f "$sc" ] || { echo "TEST FAIL no spark-cleanup at $sc" >&2; exit 2; }
top=$(mktemp -d) || exit 2
[ -n "${KEEP:-}" ] || trap 'rm -rf "$top"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_TERMINAL_PROMPT=0
unset GIT_DIR GIT_WORK_TREE

setup() {  # $1 scratch home
  local h=$1
  mkdir -p "$h/git" "$h/workspace" "$h/work/lane" "$h/elsewhere" "$h/handoffs"
  : > "$h/handoffs/BOARD.md"
  git init -q -b main "$h/workspace/proj"
  echo a > "$h/workspace/proj/a"; git -C "$h/workspace/proj" add a; git -C "$h/workspace/proj" commit -qm a
  git clone -q --bare "$h/workspace/proj" "$h/git/proj.git"
  # c2-store: worktree at a commit the store has, no upstream
  git -C "$h/workspace/proj" worktree add -q -b wt-store "$h/workspace/wt-store" main
  # c2-remote: worktree with a new commit pushed only to a bare repo outside ~/git
  git clone -q --bare "$h/workspace/proj" "$h/elsewhere/other.git"
  git -C "$h/workspace/proj" remote add other "$h/elsewhere/other.git"
  git -C "$h/workspace/proj" worktree add -q -b wt-remote "$h/workspace/wt-remote" main
  echo b > "$h/workspace/wt-remote/b"; git -C "$h/workspace/wt-remote" add b; git -C "$h/workspace/wt-remote" commit -qm b
  git -C "$h/workspace/wt-remote" push -q -u other wt-remote 2>/dev/null
  # class 8 clones
  git clone -q "$h/git/proj.git" "$h/work/lane/left"
  git clone -q "$h/git/proj.git" "$h/work/lane/unst"
  echo c > "$h/work/lane/unst/c"; git -C "$h/work/lane/unst" add c; git -C "$h/work/lane/unst" commit -qm c
  git clone -q "$h/git/proj.git" "$h/work/lane/dirty"; echo x >> "$h/work/lane/dirty/a"
  mkdir -p "$h/work/lane/weights"; truncate -s 1100M "$h/work/lane/weights/m.safetensors"
  find "$h/workspace" "$h/work" "$h/elsewhere" -exec touch -h -d '5 days ago' {} + 2>/dev/null
  git clone -q "$h/git/proj.git" "$h/work/lane/fresh"
}

run() {  # $1 home, $2 spark-cleanup copy, rest: args; prints the log
  local h=$1 s=$2; shift 2
  HOME=$h SPARK_CLEANUP_QUIET=1 SPARK_CLEANUP_GITSTORE=$h/git SPARK_CLEANUP_BOARD=$h/handoffs/BOARD.md \
    SPARK_CLEANUP_PROTECT=none-protected SPARK_CLEANUP_DRY_CLASSES= bash "$s" "$@" > "$h/out.txt" 2>&1
}

pass=0 fail=0
check() {  # $1 case name, $2 0|1 result (0 = holds)
  if [ "$2" = 0 ]; then pass=$((pass+1)); [ -n "${quiet:-}" ] || echo "PASS $1"; else fail=$((fail+1)); [ -n "${quiet:-}" ] || echo "FAIL $1"; fi
}
has() { grep -qE -- "$2" "$1"; }

suite() {  # $1 spark-cleanup copy; sets pass/fail
  local s=$1 h
  h=$(mktemp -d "$top/h.XXXX"); setup "$h"
  run "$h" "$s" --classes 2,8
  local dry="$h/out.txt"; cp "$dry" "$h/dry.txt"
  [ ! -s "$h/handoffs/BOARD.md" ]; local dryboard=$?
  run "$h" "$s" --apply --classes 2,8
  local o="$h/out.txt"
  check c2-store "$( [ ! -d "$h/workspace/wt-store" ] && has "$o" 'class2 REMOVED .*wt-store'; echo $?)"
  check c2-remote "$( [ -d "$h/workspace/wt-remote" ] && has "$o" 'class2 SKIP not-in-git-store .*wt-remote'; echo $?)"
  check c8-left "$(has "$o" 'class8 ALARM leftover-copy .*/work/lane/left '; echo $?)"
  check c8-unst "$(has "$o" 'class8 ALARM unstored-copy .*/work/lane/unst '; echo $?)"
  check c8-dirty "$(has "$o" 'class8 ALARM dirty-copy .*/work/lane/dirty '; echo $?)"
  check c8-model "$(has "$o" 'class8 ALARM model-copy .*m\.safetensors'; echo $?)"
  check c8-fresh "$( ! has "$o" 'class8 ALARM .*/work/lane/fresh'; echo $?)"
  check c8-wt-own "$(has "$h/dry.txt" 'class8 ALARM leftover-copy .*/workspace/wt-store '; echo $?)"
  check c8-rerun "$(has "$h/dry.txt" 'class8 ALARM leftover-copy .*/work/lane/left ' && has "$o" 'class8 ALARM leftover-copy .*/work/lane/left '; echo $?)"
  check c8-board "$( [ "$dryboard" = 0 ] && [ "$(grep -c 'ALARM spark-cleanup class8' "$h/handoffs/BOARD.md")" = 1 ]; echo $?)"
  check c8-nodel "$( [ -d "$h/work/lane/left" ] && [ -d "$h/work/lane/unst" ] && [ -d "$h/work/lane/dirty" ] && [ -f "$h/work/lane/weights/m.safetensors" ]; echo $?)"
}

suite "$sc"
cases=$pass; real_fail=$fail
# mutants: each must make the suite fail
mutate() {  # $1 name, $2 perl substitution
  local m="$top/mut-$1"
  perl -0pe "$2" "$sc" > "$m"
  if cmp -s "$m" "$sc"; then echo "MUTANT $1 did not apply"; return 1; fi
  pass=0; fail=0; quiet=1; suite "$m"; quiet=
  if [ "$fail" -gt 0 ]; then echo "MUTANT $1 caught ($fail failing)"; return 0; fi
  echo "MUTANT $1 NOT caught"; return 1
}
mt=0 mc=0
for spec in \
  'store-always-true|s/in_git_store\(\) \{  # \$1 commit sha; true \(and prints the bare repo\) if a ref there reaches it\n/in_git_store() { return 0;\n/' \
  'old-pushed-check|s/if \[ -z "\$head" \] \|\| ! in_git_store "\$head" >\/dev\/null; then/if [ -z "\$(git -C "\$wt" branch -r --contains HEAD 2>\/dev\/null | head -1)" ] \&\& ! in_git_store "\$head" >\/dev\/null; then/' \
  'no-idle-check|s/    recent "\$r" "\$idle_min" && continue\n//' \
  'index-write|s/export GIT_OPTIONAL_LOCKS=0\n//' \
  'no-board|s/      "\$\(date -u \+%FT%H:%MZ\)" "\$n" "\$\(human "\$bytes"\)" "\$LOG" >> "\$board"/      "x" "\$n" "x" "x" >\/dev\/null/' ; do
  name=${spec%%|*}; expr=${spec#*|}
  mt=$((mt+1)); mutate "$name" "$expr" && mc=$((mc+1))
done
if [ "$real_fail" = 0 ] && [ "$mc" = "$mt" ]; then echo "TEST PASS cases=$cases mutants=$mc/$mt"; exit 0; fi
echo "TEST FAIL failing=$real_fail mutants=$mc/$mt"; exit 1
