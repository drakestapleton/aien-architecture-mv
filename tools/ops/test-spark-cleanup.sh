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
#   c8-stash    an idle clone whose only unsaved work is a stash: unstored-copy, not leftover
#   c8-ignored  an idle clone with results in a git-ignored folder: dirty-copy, not leftover
#   c8-unread   an idle linked worktree whose admin folder is gone (git cannot read it): unreadable-copy
#   c8-nested   an idle clone whose head is only in a nested store repo (git/sub/n.git): leftover-copy
#   c8-hardlink a weight file hard-linked from ~/models (2 links) is not called a copy
#   c8-dedupe   a second --apply run over the same copies adds no second board line
#   c8-badthr   SPARK_CLEANUP_LEFTOVER_ALARM_GB=0.5 is reported loudly, not a shell error
#   c8-nolock   with a quiet-build in the scratch home, an --apply run gives the locked run classes
#               without 8 and runs class 8 afterwards on its own (classes=8 line, after quiet-build ended)
#   store-empty an empty store gives the loud "holds no bare repositories" ALARM and one board line,
#               not a second one on the next run
#   c8-emerg    with free space under 10 % an --apply run still runs class 8 on its own, after the rest
#   c8-main     main clones (no '-' in the name, real .git folder) are still checked: the clean one
#               ~/workspace/ref is a SKIP main-clone line, ~/workspace/proj (branches not in the store) is an
#               ALARM marked "main clone"
#   c8-drymark  a dry --classes 8 run neither reads nor writes the --apply scan's start and finish marks
#   c2-nested   an idle clean worktree holding a repository in an ignored folder (.lake/packages/dep) is kept
#   c8-inner    an idle repository inside a copy that is in use now is not reported on its own
#   c8-hook     the test in-use hook says in the log that it was used
#   c8-agentwt  an idle linked worktree inside the main clone (proj/.claude/worktrees/agent-x) is reported
#   c8-dashwt   an idle linked worktree ~/workspace/kflow (no '-', but not a main clone) is reported
#   c8-unfin    a class 8 scan that started and never finished gives a loud ALARM and one board line
#   c8-maxh     SPARK_CLEANUP_CLASS8_MAX_H=1.5 is reported loudly, not a shell error
#   c8-only8    --apply --classes 8 does not go through quiet-build (no deleting run to lock)
#   c8-help     --help prints the whole header, through the Usage section
# Then mutants of spark-cleanup must each make at least one case fail.
# Ends `TEST PASS cases=N mutants=M/M` (exit 0) or `TEST FAIL ...` (exit 1).
set -u
here=$(cd "$(dirname "$0")" && pwd)
sc=${1:-$here/spark-cleanup}
[ -f "$sc" ] || { echo "TEST FAIL no spark-cleanup at $sc" >&2; exit 2; }
top=$(mktemp -d) || exit 2
[ -n "${KEEP:-}" ] || trap 'rm -rf "$top"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_TERMINAL_PROMPT=0
unset GIT_DIR GIT_WORK_TREE
# nothing in the scratch home is open by another process; skip the machine-wide scan
: > "$top/inuse"; export SPARK_CLEANUP_TEST_INUSE_FILE="$top/inuse"

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
  git clone -q "$h/git/proj.git" "$h/work/lane/stash"; echo s >> "$h/work/lane/stash/a"; git -C "$h/work/lane/stash" stash -q
  git clone -q "$h/git/proj.git" "$h/work/lane/ign"; mkdir -p "$h/work/lane/ign/secret"; echo r > "$h/work/lane/ign/secret/results"
  echo secret/ >> "$h/work/lane/ign/.git/info/exclude"
  git clone -q "$h/git/proj.git" "$h/workspace/ref"
  echo .lake/ >> "$h/workspace/proj/.git/info/exclude"
  git -C "$h/workspace/proj" worktree add -q -b wt-nest "$h/workspace/wt-nest" main
  git init -q -b main "$h/workspace/wt-nest/.lake/packages/dep"
  git -C "$h/workspace/proj" worktree add -q -b agent-x "$h/workspace/proj/.claude/worktrees/agent-x" main
  git -C "$h/workspace/proj" worktree add -q -b kflow "$h/workspace/kflow" main
  git -C "$h/workspace/proj" worktree add -q -b wt-orphan "$h/work/lane/orphan" main
  echo z > "$h/work/lane/orphan/z"; git -C "$h/work/lane/orphan" add z; git -C "$h/work/lane/orphan" commit -qm z
  rm -rf "$h/workspace/proj/.git/worktrees/orphan"
  mkdir -p "$h/git/sub" "$h/work/lane/nested-src"; git init -q -b main "$h/work/lane/nested-src"
  echo n > "$h/work/lane/nested-src/n"; git -C "$h/work/lane/nested-src" add n; git -C "$h/work/lane/nested-src" commit -qm n
  git clone -q --bare "$h/work/lane/nested-src" "$h/git/sub/n.git"; rm -rf "$h/work/lane/nested-src"
  git clone -q "$h/git/sub/n.git" "$h/work/lane/nested"

  mkdir -p "$h/work/lane/weights"; truncate -s 1100M "$h/work/lane/weights/m.safetensors"
  mkdir -p "$h/models"; truncate -s 1100M "$h/models/w.gguf"; ln "$h/models/w.gguf" "$h/work/lane/weights/linked.gguf"
  find "$h/workspace" "$h/work" "$h/elsewhere" -exec touch -h -d '5 days ago' {} + 2>/dev/null
  git clone -q "$h/git/proj.git" "$h/work/lane/fresh"
  # c8-inner: a copy in use now (fresh files) holding an idle clone
  git clone -q "$h/git/proj.git" "$h/work/lane/active"; git clone -q "$h/git/proj.git" "$h/work/lane/active/sub/inner"
  find "$h/work/lane/active/sub" -exec touch -h -d '5 days ago' {} +
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
  local o="$h/out.txt"; cp "$o" "$h/apply1.txt"
  run "$h" "$s" --apply --classes 8
  local o2="$h/apply2.txt"; cp "$h/out.txt" "$o2"
  SPARK_CLEANUP_LEFTOVER_ALARM_GB=0.5 run "$h" "$s" --classes 8
  local o3="$h/out.txt"; cp "$o3" "$h/badthr.txt"
  # c8-nolock: fake quiet-build records the env it ran with, then runs the command
  mkdir -p "$h/.local/bin"
  printf '#!/bin/bash\necho "qb SKIP8=${SPARK_CLEANUP_SKIP8:-} $(date +%%s%%N)" >> "%s/qb.log"\n"$@"\nrc=$?\necho "qb-end $(date +%%s%%N)" >> "%s/qb.log"\nexit $rc\n' "$h" "$h" > "$h/.local/bin/quiet-build"
  chmod +x "$h/.local/bin/quiet-build"
  HOME=$h SPARK_CLEANUP_TEST_FREE_PCT=50 SPARK_CLEANUP_GITSTORE=$h/git SPARK_CLEANUP_BOARD=$h/handoffs/BOARD.md \
    SPARK_CLEANUP_PROTECT=none-protected SPARK_CLEANUP_DRY_CLASSES= bash "$s" --apply --classes 2,8 > "$h/nolock.txt" 2>&1
  # store-empty: a separate scratch home whose store is empty
  local e; e=$(mktemp -d "$top/e.XXXX"); mkdir -p "$e/git" "$e/workspace" "$e/handoffs"; : > "$e/handoffs/BOARD.md"
  HOME=$e SPARK_CLEANUP_QUIET=1 SPARK_CLEANUP_GITSTORE=$e/git SPARK_CLEANUP_BOARD=$e/handoffs/BOARD.md bash "$s" --apply --classes 2,8 > "$e/out.txt" 2>&1
  HOME=$e SPARK_CLEANUP_QUIET=1 SPARK_CLEANUP_GITSTORE=$e/git SPARK_CLEANUP_BOARD=$e/handoffs/BOARD.md bash "$s" --apply --classes 2,8 > "$e/out2.txt" 2>&1
  # c8-unfin: a scan that started and never wrote its finish mark
  echo 1700000000 > "$h/.local/state/spark-cleanup/class8.started"; rm -f "$h/.local/state/spark-cleanup/class8.finished"
  SPARK_CLEANUP_CLASS8_MAX_H=1.5 run "$h" "$s" --apply --classes 8; cp "$h/out.txt" "$h/unfin.txt"
  # c8-drymark: a dry run with an unfinished --apply mark left in place
  echo 1700000001 > "$h/.local/state/spark-cleanup/class8.started"; rm -f "$h/.local/state/spark-cleanup/class8.finished"
  local bd0; bd0=$(wc -l < "$h/handoffs/BOARD.md")
  run "$h" "$s" --classes 8; cp "$h/out.txt" "$h/drymark.txt"
  local dm_ok=1; [ "$(cat "$h/.local/state/spark-cleanup/class8.started")" = 1700000001 ] && [ "$(wc -l < "$h/handoffs/BOARD.md")" = "$bd0" ] && ! has "$h/drymark.txt" 'did not finish' && dm_ok=0
  cp "$h/.local/state/spark-cleanup/class8.started" "$h/.local/state/spark-cleanup/class8.finished"   # leave no unfinished mark for later cases
  # c8-only8: --apply --classes 8 through the real wrapper (fake quiet-build present)
  local qb0; qb0=$(wc -l < "$h/qb.log" 2>/dev/null || echo 0)
  HOME=$h SPARK_CLEANUP_TEST_FREE_PCT=50 SPARK_CLEANUP_GITSTORE=$h/git SPARK_CLEANUP_BOARD=$h/handoffs/BOARD.md \
    SPARK_CLEANUP_PROTECT=none-protected SPARK_CLEANUP_DRY_CLASSES= bash "$s" --apply --classes 8 > "$h/only8.txt" 2>&1
  local qb1; qb1=$(wc -l < "$h/qb.log" 2>/dev/null || echo 0)
  bash "$s" --help > "$h/help.txt" 2>&1
  # c8-emerg: under 10 % free the deleting classes run without quiet-build; class 8 still runs alone after them
  local qbn; qbn=$(wc -l < "$h/qb.log" 2>/dev/null || echo 0)
  HOME=$h SPARK_CLEANUP_TEST_FREE_PCT=5 SPARK_CLEANUP_GITSTORE=$h/git SPARK_CLEANUP_BOARD=$h/handoffs/BOARD.md \
    SPARK_CLEANUP_PROTECT=none-protected SPARK_CLEANUP_DRY_CLASSES= bash "$s" --apply --classes 2,8 > "$h/emerg.txt" 2>&1
  o="$h/apply1.txt"
  check c2-store "$( [ ! -d "$h/workspace/wt-store" ] && has "$o" 'class2 REMOVED .*wt-store'; echo $?)"
  check c2-remote "$( [ -d "$h/workspace/wt-remote" ] && has "$o" 'class2 SKIP not-in-git-store .*wt-remote'; echo $?)"
  check c8-left "$(has "$o" 'class8 ALARM leftover-copy .*/work/lane/left '; echo $?)"
  check c8-unst "$(has "$o" 'class8 ALARM unstored-copy .*/work/lane/unst '; echo $?)"
  check c8-dirty "$(has "$o" 'class8 ALARM dirty-copy .*/work/lane/dirty '; echo $?)"
  check c8-model "$(has "$o" 'class8 ALARM model-copy .*m\.safetensors'; echo $?)"
  check c8-fresh "$( ! has "$o" 'class8 ALARM .*/work/lane/fresh'; echo $?)"
  check c8-wt-own "$(has "$h/dry.txt" 'class8 ALARM leftover-copy .*/workspace/wt-store '; echo $?)"
  check c8-rerun "$(has "$h/dry.txt" 'class8 ALARM leftover-copy .*/work/lane/left ' && has "$o" 'class8 ALARM leftover-copy .*/work/lane/left '; echo $?)"
  check c8-board "$( [ "$dryboard" = 0 ] && [ "$(grep -c 'ALARM spark-cleanup class8 to all: [0-9]* agent copies left behind' "$h/handoffs/BOARD.md")" = 1 ]; echo $?)"
  check c8-stash "$(has "$o" 'class8 ALARM unstored-copy .*/work/lane/stash '; echo $?)"
  check c8-ignored "$(has "$o" 'class8 ALARM dirty-copy .*/work/lane/ign .*ignored files'; echo $?)"
  check c8-unread "$(has "$o" 'class8 ALARM unreadable-copy .*/work/lane/orphan '; echo $?)"
  check c8-nested "$(has "$o" 'class8 ALARM leftover-copy .*/work/lane/nested '; echo $?)"
  check c8-hardlink "$( ! has "$o" 'model-copy .*linked\.gguf'; echo $?)"
  check c8-dedupe "$(has "$o2" 'board line not repeated' && [ "$(grep -c 'ALARM spark-cleanup class8 to all: [0-9]* agent copies left behind' "$h/handoffs/BOARD.md")" = 1 ]; echo $?)"
  check c8-badthr "$(has "$h/badthr.txt" "class8 ALARM bad SPARK_CLEANUP_LEFTOVER_ALARM_GB='0.5'" && ! has "$h/badthr.txt" 'syntax error|arithmetic'; echo $?)"
  check c8-nolock "$(grep -q '^qb SKIP8=1 ' "$h/qb.log" 2>/dev/null && has "$h/nolock.txt" 'APPLY classes=2 ' && has "$h/nolock.txt" 'APPLY classes=8 ' && ! has "$h/nolock.txt" 'APPLY classes=2,8'; echo $?)"
  check store-empty "$(has "$e/out.txt" 'holds no bare repositories' && has "$e/out2.txt" 'holds no bare repositories' && [ "$(grep -c 'holds no bare repositories' "$e/handoffs/BOARD.md")" = 1 ]; echo $?)"
  check c8-emerg "$(has "$h/emerg.txt" 'APPLY classes=2 ' && has "$h/emerg.txt" 'APPLY classes=8 ' && ! has "$h/emerg.txt" 'APPLY classes=2,8' && [ "$(wc -l < "$h/qb.log")" = "$qbn" ]; echo $?)"
  check c8-main "$(has "$h/dry.txt" 'class8 SKIP main-clone .*/workspace/ref ' && has "$h/dry.txt" 'class8 ALARM unstored-copy .*/workspace/proj .*main clone:' && ! has "$h/dry.txt" 'class8 ALARM [a-z]+-copy .*/workspace/ref '; echo $?)"
  check c8-drymark "$dm_ok"
  check c2-nested "$( [ -d "$h/workspace/wt-nest" ] && has "$o" 'class2 SKIP nested-repo .*wt-nest'; echo $?)"
  check c8-inner "$( ! has "$o" 'class8 ALARM .*/work/lane/active'; echo $?)"
  check c8-agentwt "$(has "$h/dry.txt" 'class8 ALARM [a-z]+-copy .*/workspace/proj/\.claude/worktrees/agent-x '; echo $?)"
  check c8-dashwt "$(has "$h/dry.txt" 'class8 ALARM [a-z]+-copy .*/workspace/kflow '; echo $?)"
  check c8-unfin "$(has "$h/unfin.txt" 'previous leftover-copy scan .*did not finish' && [ "$(grep -c 'did not finish' "$h/handoffs/BOARD.md")" = 1 ]; echo $?)"
  check c8-maxh "$(has "$h/unfin.txt" "ALARM bad SPARK_CLEANUP_CLASS8_MAX_H='1.5'" && ! has "$h/unfin.txt" 'syntax error|arithmetic'; echo $?)"
  check c8-only8 "$( [ "$qb0" = "$qb1" ] && has "$h/only8.txt" 'APPLY classes=8 '; echo $?)"
  check c8-help "$(has "$h/help.txt" '^Usage|^ *spark-cleanup --classes' && ! has "$h/help.txt" 'pipefail'; echo $?)"
  check c8-hook "$(has "$o" 'test hook: in-use list read from'; echo $?)"
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
  'store-always-true|s/(in_git_store\(\) \{  # \$1 commit sha[^\n]*\n)/$1  return 0\n/' \
  'old-pushed-check|s/if \[ -z "\$head" \] \|\| ! in_git_store "\$head" >\/dev\/null; then/if [ -z "\$(git -C "\$wt" branch -r --contains HEAD 2>\/dev\/null | head -1)" ] \&\& ! in_git_store "\$head" >\/dev\/null; then/' \
  'no-idle-check|s/    recent "\$r" "\$idle_min" && continue\n//' \
  'unreadable-is-leftover|s/kind=unreadable; why=/kind=leftover; why=/' \
  'heads-only|s/awk .\$2 !~ \/\^refs\\\/remotes\\\/\/ \{print \$1\}./grep refs\/heads\/ | cut -d" " -f1/' \
  'no-dedupe|s/if \[ "\$sig" = "\$last" \]; then/if false; then/' \
  'class8-in-lock|s/SPARK_CLEANUP_SKIP8=1 "\$QB"/"\$QB"/' \
  'no-emerg-split|s/else SPARK_CLEANUP_SKIP8=1 "\$0" "\$@"; _rc=\$\?; fi/else exec "\$0" "\$@"; fi/' \
  'no-inner|s/    if \[ \$inner = 1 \] && ! grep -qs [^\n]*; then continue; fi\n//' \
  'main-clone|s/    if \[ -d "\$r\/\.git" \]; then case [^\n]*\n//' \
  'inner-wt|s/if \[ \$inner = 1 \] && ! grep -qs [^\n]*; then continue; fi/[ \$inner = 1 ] \&\& continue/' \
  'main-by-name|s/if \[ -d "\$r\/\.git" \]; then (case [^\n]*esac); fi/$1/' \
  'no-unfinished|s/if \[ -n "\$_st" \] && \[ "\$\(cat "\$STATE\/class8\.finished" 2>\/dev\/null\)" != "\$_st" \]; then/if false; then/' \
  'dry-marks|s/if \[ "\$CLASSES" = 8 \] && \[ \$APPLY = 1 \]; then/if [ "\$CLASSES" = 8 ]; then/' \
  'no-nested-check|s/      if \[ -n "\$inner" \]; then log "class2 SKIP nested-repo[^\n]*\n//' \
  'main-silent|s/"\$H"\/workspace\/\*\) main=1 ;;/"\$H"\/workspace\/*) continue ;;/' \
  'index-write|s/export GIT_OPTIONAL_LOCKS=0\n//' \
  'no-board|s/      "\$\(date -u \+%FT%H:%MZ\)" "\$n" "\$\(human "\$bytes"\)" "\$LOG" >> "\$board"/      "x" "\$n" "x" "x" >\/dev\/null/' ; do
  name=${spec%%|*}; expr=${spec#*|}
  mt=$((mt+1)); mutate "$name" "$expr" && mc=$((mc+1))
done
if [ "$real_fail" = 0 ] && [ "$mc" = "$mt" ]; then echo "TEST PASS cases=$cases mutants=$mc/$mt"; exit 0; fi
echo "TEST FAIL failing=$real_fail mutants=$mc/$mt"; exit 1
