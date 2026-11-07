#!/usr/bin/env bash
# Offline test for rebase-crumb.sh. Real temporary git repos (a bare "origin" plus a worktree whose
# origin URL looks like an aien-dev URL, redirected to the bare repo with insteadOf). Crumb compile and
# verify are retired (DRA-97): a `crumb` stub that exits 99 is on PATH and in $CRUMB, and the test
# proves it is never called and no crumb commit is added. No network, no auth.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
script="$here/rebase-crumb.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
FAKEURL="https://github.com/aien-dev/fake-repo"

mkdir -p "$tmp/bin"
cat > "$tmp/bin/crumb" <<S
#!/usr/bin/env bash
# retired: any call is a test failure (recorded, then exit 99)
echo "\$*" >> "$tmp/crumb-called"
exit 99
S
chmod +x "$tmp/bin/crumb"
export PATH="$tmp/bin:$PATH" CRUMB="$tmp/bin/crumb"
RETIRED="crumb: retired (DRA-97), conflicting .crumb files keep main's copy; no compile, verify or crumb commit"
nocrumbcommit() { test "$(git -C "$1" log --format=%s origin/main..HEAD | grep -c '^crumb compile (after rebase onto main)$')" = 0; }

pass=0; bad=0
ok() { pass=$((pass+1)); }
no() { bad=$((bad+1)); echo "TEST FAIL: $1"; }
expect() { # expect <rc> <label> <worktree> <branch>   (output in $OUT)
  OUT=$("$script" "$3" "$4" 2>&1); rc=$?
  if [ "$rc" = "$1" ]; then ok; else no "$2 (rc=$rc, want $1): $OUT"; fi
}
check() { # check <label> <command...>
  l=$1; shift; if "$@" >/dev/null 2>&1; then ok; else no "$l"; fi
}

# mk <name> [nocrumb] : origin (bare) + worktree w on branch feat (pushed). main has src.txt and .crumb.
mk() {
  d="$tmp/$1"; mkdir -p "$d"; git init -q --bare -b main "$d/origin.git"
  git init -q -b main "$d/seed"
  ( cd "$d/seed" && echo base > src.txt && { [ "${2:-}" = nocrumb ] || echo c0 > .crumb; } \
    && git add -A && git commit -q -m base && git remote add origin "$d/origin.git" && git push -q origin main )
  git clone -q "$d/origin.git" "$d/w"
  ( cd "$d/w" && git checkout -q -b feat && echo feat > feat.txt && git add -A && git commit -q -m feat && git push -q origin feat \
    && git remote set-url origin "$FAKEURL" && git config "url.$d/origin.git.insteadOf" "$FAKEURL" )
  W="$d/w"; O="$d/origin.git"
}
advance_main() { # advance_main <seed-dir> <file> <content>
  ( cd "$1" && git checkout -q main && echo "$3" > "$2" && git add -A && git commit -q -m "main $2" && git push -q origin main )
}
ohead() { git -C "$O" rev-parse "refs/heads/feat"; }

# 1 dirty tree
mk t1; echo x >> "$W/feat.txt"
expect 2 "dirty tree refused" "$W" feat
# 2 branch main
mk t2
expect 2 "branch main refused" "$W" main
# 3 wrong remote
mk t3; git -C "$W" remote set-url origin https://github.com/other-org/x
expect 2 "wrong remote refused" "$W" feat
# 4 lock present (fresh)
mk t4; touch "$W/.git/rebase-crumb.lock"
expect 2 "fresh lock refused" "$W" feat
check "fresh lock left in place" test -e "$W/.git/rebase-crumb.lock"
# 5 not a git checkout
mkdir -p "$tmp/plain"
expect 2 "non-git directory refused" "$tmp/plain" feat
# 6 origin branch missing
mk t6
expect 2 "missing origin branch refused" "$W" nosuchbranch
# 7 clean rebase, push, no crumb commit
mk t7; advance_main "$tmp/t7/seed" main-only.txt m
before=$(ohead)
expect 0 "clean rebase succeeds" "$W" feat
check "push reached origin" test "$(ohead)" = "$(git -C "$W" rev-parse HEAD)"
check "origin head moved" test "$(ohead)" != "$before"
check "last commit is the feat source commit" test "$(git -C "$W" log -1 --format=%s)" = "feat"
check "no crumb compile commit added" nocrumbcommit "$W"
check "retired crumb notice printed" bash -c 'echo "$1" | grep -qF "$2"' _ "$OUT" "$RETIRED"
check "main commit is an ancestor" git -C "$W" merge-base --is-ancestor origin/main HEAD
check "lock removed on exit" test ! -e "$W/.git/rebase-crumb.lock"
check "final line format" bash -c 'echo "$1" | tail -1 | grep -q "^rebased feat onto "' _ "$OUT"
# 8 stale lock (older than 2h) does not block
mk t8; touch -d '3 hours ago' "$W/.git/rebase-crumb.lock"; advance_main "$tmp/t8/seed" main-only.txt m
expect 0 "stale lock ignored" "$W" feat
# 9 CODE CONFLICT
mk t9
( cd "$tmp/t9/w" && git checkout -q feat && echo featside > src.txt && git add -A && git commit -q -m "feat src" && git push -q origin feat )
advance_main "$tmp/t9/seed" src.txt mainside
before=$(ohead)
expect 3 "code conflict exits 3" "$W" feat
check "CODE CONFLICT message names file" bash -c "echo '$OUT' | grep -q 'CODE CONFLICT: src.txt'"
check "no rebase left in progress" test ! -d "$W/.git/rebase-merge"
check "code conflict pushed nothing" test "$(ohead)" = "$before"
check "lock removed after conflict" test ! -e "$W/.git/rebase-crumb.lock"
# 10 crumb-only conflict resolved with main's copy
mk t10
( cd "$tmp/t10/w" && echo featcrumb > .crumb && git add -A && git commit -q -m "feat crumb" && git push -q origin feat )
advance_main "$tmp/t10/seed" .crumb maincrumb
expect 0 "crumb-only conflict resolved" "$W" feat
check "main's crumb copy kept as is (not compiled)" test "$(cat "$W/.crumb")" = "maincrumb"
check "feat source change kept" test -f "$W/feat.txt"
check "t10 no crumb compile commit added" nocrumbcommit "$W"
# 11 no crumb tool at all (CRUMB points nowhere, PATH stub would exit 99): still exit 0 and pushed
mk t11; advance_main "$tmp/t11/seed" main-only.txt m; before=$(ohead)
OUT=$(CRUMB=/nonexistent/crumb "$script" "$W" feat 2>&1); rc=$?
if [ "$rc" = 0 ]; then ok; else no "missing crumb tool still rebases and exits 0 (rc=$rc): $OUT"; fi
check "missing crumb tool: push reached origin" test "$(ohead)" = "$(git -C "$W" rev-parse HEAD)"
check "missing crumb tool: origin head moved" test "$(ohead)" != "$before"
# 12 repo with no crumbs: same retired notice, no crumb commit
mk t12 nocrumb; advance_main "$tmp/t12/seed" main-only.txt m
expect 0 "no-crumb repo passes" "$W" feat
check "retired notice printed" bash -c 'echo "$1" | grep -qF "$2"' _ "$OUT" "$RETIRED"
check "no crumb commit made" test "$(git -C "$W" log -1 --format=%s)" = "feat"
# 13 lease protects against someone else's push between fetch and push
mk t13; advance_main "$tmp/t13/seed" main-only.txt m
cat > "$tmp/bin/racegit" <<S
#!/usr/bin/env bash
# real git, but just before the push another writer moves origin/feat
if [ "\$1" = push ]; then
  git clone -q "$tmp/t13/origin.git" "$tmp/t13/racer" && ( cd "$tmp/t13/racer" && git checkout -q feat && echo other > other.txt && git add -A && git commit -q -m other && git push -q origin feat )
fi
exec git "\$@"
S
chmod +x "$tmp/bin/racegit"
OUT=$(GIT="$tmp/bin/racegit" "$script" "$W" feat 2>&1); rc=$?
if [ "$rc" = 4 ]; then ok; else no "lease violation exits 4 (rc=$rc): $OUT"; fi
check "racer commit not overwritten" test "$(git -C "$O" log -1 --format=%s feat)" = "other"

# 14 branch history already holds a crumb-only commit that conflicts with main's .crumb change
mk t14
( cd "$tmp/t14/w" && echo oldcompile > .crumb && git add -A && git commit -q -m "crumb compile" && git push -q origin feat )
advance_main "$tmp/t14/seed" .crumb maincrumb
advance_main "$tmp/t14/seed" main-only.txt m
before=$(ohead)
expect 0 "prior crumb-only commit rebases" "$W" feat
check "t14 push reached origin" test "$(ohead)" = "$(git -C "$W" rev-parse HEAD)"
check "t14 origin head moved" test "$(ohead)" != "$before"
check "t14 rebased onto main" git -C "$W" merge-base --is-ancestor origin/main HEAD
check "t14 old crumb-only commit dropped" test "$(git -C "$W" log --format=%s origin/main..HEAD | grep -c '^crumb compile$')" = 0
check "t14 last commit is the feat source commit" test "$(git -C "$W" log -1 --format=%s)" = "feat"
check "t14 no crumb compile commit added" nocrumbcommit "$W"
check "t14 crumb is main's copy" test "$(cat "$W/.crumb")" = "maincrumb"
check "t14 feat source change kept" test -f "$W/feat.txt"
check "t14 no rebase left in progress" test ! -d "$W/.git/rebase-merge"

# 15 two commits in a row conflict on .crumb (a source commit touching .crumb, then a crumb-only commit),
#    so `rebase --continue` after the first resolution exits non-zero because it stops at the second conflict
mk t15
( cd "$tmp/t15/w" && mkdir -p docs && echo d0 > docs/.crumb && echo f2 > feat2.txt && echo srcside > .crumb && git add -A && git commit -q -m "feat2" \
  && echo oc1 > .crumb && echo od1 > docs/.crumb && git add -A && git commit -q -m "crumb compile" \
  && echo oc2 > .crumb && echo od2 > docs/.crumb && git add -A && git commit -q -m "crumb compile" && git push -q origin feat )
( cd "$tmp/t15/seed" && git checkout -q main && mkdir -p docs && echo mdoc > docs/.crumb && echo maincrumb > .crumb && git add -A && git commit -q -m m1 && git push -q origin main )
before=$(ohead)
expect 0 "consecutive crumb conflicts rebase" "$W" feat
check "t15 push reached origin" test "$(ohead)" = "$(git -C "$W" rev-parse HEAD)"
check "t15 origin head moved" test "$(ohead)" != "$before"
check "t15 no old crumb compile commits left" test "$(git -C "$W" log --format=%s origin/main..HEAD | grep -c '^crumb compile$')" = 0
check "t15 last commit is the feat2 source commit" test "$(git -C "$W" log -1 --format=%s)" = "feat2"
check "t15 no crumb compile commit added" nocrumbcommit "$W"
check "t15 crumbs are main's copy" test "$(cat "$W/.crumb") $(cat "$W/docs/.crumb")" = "maincrumb mdoc"
check "t15 feat2 source change kept" test -f "$W/feat2.txt"
check "t15 no rebase left in progress" test ! -d "$W/.git/rebase-merge"

# 16 stacked branch: feat sits on a base branch (source commit + crumb commit); base is squash-merged into main
mk t16
( cd "$tmp/t16/w" && git checkout -q -B feat origin/main && echo b > base.txt && git add -A && git commit -q -m "base src" \
  && echo basecrumb > .crumb && git add -A && git commit -q -m "crumb compile" \
  && echo f3 > feat3.txt && git add -A && git commit -q -m "child src" \
  && echo childcrumb > .crumb && git add -A && git commit -q -m "crumb compile" && git push -q -f origin feat )
( cd "$tmp/t16/seed" && git checkout -q main && echo b > base.txt && echo squashcrumb > .crumb && git add -A && git commit -q -m "squash of base" && git push -q origin main )
before=$(ohead)
expect 0 "stacked branch after base squash rebases" "$W" feat
check "t16 origin head moved" test "$(ohead)" != "$before"
check "t16 base source not duplicated" test "$(git -C "$W" log --format=%s origin/main..HEAD | grep -c '^base src$')" = 0
check "t16 child source kept" test -f "$W/feat3.txt"
check "t16 last commit is the child source commit" test "$(git -C "$W" log -1 --format=%s)" = "child src"
check "t16 no crumb compile commit added" nocrumbcommit "$W"
check "t16 crumb is main's copy" test "$(cat "$W/.crumb")" = "squashcrumb"
check "t16 no old crumb compile commits left" test "$(git -C "$W" log --format=%s origin/main..HEAD | grep -c '^crumb compile$')" = 0

if [ ! -e "$tmp/crumb-called" ]; then ok; else no "crumb tool was called: $(cat "$tmp/crumb-called")"; fi

echo "PASS $pass FAIL $bad"
[ "$bad" -eq 0 ]
