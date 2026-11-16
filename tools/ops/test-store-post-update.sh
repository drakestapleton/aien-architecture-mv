#!/usr/bin/env bash
# test-store-post-update.sh: the store hook in a scratch home (its own ~/.gitconfig, git store, sync,
# spark-cleanup and disk-alarm stand-ins). Real pushes; nothing outside the scratch folder is read or written.
# Usage: bash tools/ops/test-store-post-update.sh   exit 0 all pass, 1 any fail.
set -u
here=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/test-store-hook.XXXXXX")
trap 'rm -rf "$T"' EXIT
fails=0
ok() { echo "PASS $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }

H="$T/home"
mkdir -p "$H/.local/bin" "$H/.local/lib/store-hooks" "$H/.local/lib/bazinga-git" "$H/.config/git" "$H/git/nest" "$H/elsewhere"
cp "$here/store-post-update" "$H/.local/lib/store-hooks/post-update"
# the install, as README "Store hook" gives it
printf '[includeIf "gitdir:~/git/"]\n\tpath = .config/git/store.inc\n[user]\n\tname = t\n\temail = t@t\n[init]\n\tdefaultBranch = main\n' > "$H/.gitconfig"
printf '[core]\n\thooksPath = %s/.local/lib/store-hooks\n' "$H" > "$H/.config/git/store.inc"
# stand-ins: each records its arguments, every GIT_ variable it can see, and its working folder
for f in spark-cleanup disk-alarm; do
  printf '#!/bin/sh\n[ -f "%s/%s.fail" ] && exit 9\nprintf "%%s|%%s|%%s\\n" "$*" "$(env | grep -c "^GIT_")" "$(pwd)" >> "%s/%s.calls"\n' \
    "$T" "$f" "$T" "$f" > "$H/.local/bin/$f"
done
printf '#!/bin/sh\n[ -f "%s/sync.fail" ] && exit 9\necho "$1" >> "%s/sync.calls"\n' "$T" "$T" > "$H/.local/lib/bazinga-git/sync.sh"
chmod +x "$H/.local/bin/"* "$H/.local/lib/bazinga-git/sync.sh" "$H/.local/lib/store-hooks/post-update"

export HOME="$H" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
unset XDG_CONFIG_HOME GIT_DIR GIT_WORK_TREE
git init -q --bare "$H/git/alpha.git"
git init -q --bare "$H/git/nest/beta.git"
git init -q --bare "$H/elsewhere/gamma.git"
git init -q "$T/w"
git -C "$T/w" commit -q --allow-empty -m one
n=0
push() { n=$((n + 1)); git -C "$T/w" commit -q --allow-empty -m "c$n"; git -C "$T/w" push -q "$1" HEAD:main 2> "$T/push.err"; }
# the detached steps finish within a moment; wait for the expected count of lines, at most 10 s
lines() { local i=0; while [ "$i" -lt 100 ]; do [ "$(cat "$T/$1.calls" 2>/dev/null | wc -l)" -ge "$2" ] && break; sleep 0.1; i=$((i + 1)); done
  cat "$T/$1.calls" 2>/dev/null | wc -l; }

# 1. a landing on a store repository: sync, spark-cleanup --landed NAME, then disk-alarm --quiet; no GIT_ variable leaks
push "$H/git/alpha.git"; r=$?
[ "$r" = 0 ] && [ "$(lines spark-cleanup 1)" = 1 ] && [ "$(lines disk-alarm 1)" = 1 ] &&
  grep -qx 'alpha' "$T/sync.calls" && grep -qx -- '--landed alpha|0|/' "$T/spark-cleanup.calls" &&
  grep -qx -- '--quiet|0|/' "$T/disk-alarm.calls" && ok "landing runs sync, spark-cleanup --landed, disk-alarm" ||
  bad "landing (push $r): $(cat "$T"/*.calls 2>/dev/null | tr '\n' ' ')"

# 2. a repository in a nested store folder, created after the install, gets the hook with no step of its own
push "$H/git/nest/beta.git"
[ "$(lines spark-cleanup 2)" = 2 ] && grep -qx -- '--landed beta|0|/' "$T/spark-cleanup.calls" &&
  ok "nested store repository" || bad "nested store repository: $(cat "$T/spark-cleanup.calls" | tr '\n' ' ')"

# 3. negative control: a bare repository outside the store runs none of it
push "$H/elsewhere/gamma.git"; sleep 1
[ "$(lines spark-cleanup 2)" = 2 ] && ! grep -qx gamma "$T/sync.calls" && ok "repository outside the store: no hook" ||
  bad "repository outside the store ran the hook"

# 4. every step failing still lands the push (exit 0), and the steps after a failed one still run
touch "$T/sync.fail" "$T/spark-cleanup.fail"
push "$H/git/alpha.git"; r=$?
[ "$r" = 0 ] && [ "$(lines disk-alarm 3)" = 3 ] && ok "failing steps never fail the push" || bad "failing steps (push $r, alarms $(lines disk-alarm 3))"
rm -f "$T/sync.fail" "$T/spark-cleanup.fail"

# 5. the push does not wait for a slow step
printf '#!/bin/sh\nsleep 5\n' > "$H/.local/bin/spark-cleanup"
s=$(date +%s); push "$H/git/alpha.git"; e=$(( $(date +%s) - s ))
[ "$e" -lt 4 ] && ok "push does not wait for the clean-up (${e} s)" || bad "push waited ${e} s"

# 6. mutant: the same hook without its GIT_ variable reset must fail case 1's check
grep -v '^for v in ' "$here/store-post-update" > "$H/.local/lib/store-hooks/post-update"
for f in spark-cleanup; do
  printf '#!/bin/sh\nprintf "%%s|%%s\\n" "$*" "$(env | grep -c "^GIT_")" >> "%s/mut.calls"\n' "$T" > "$H/.local/bin/$f"
done
push "$H/git/alpha.git"; lines mut 1 > /dev/null
grep -qx -- '--landed alpha|0' "$T/mut.calls" && bad "mutant without the GIT_ reset passed" || ok "mutant without the GIT_ reset caught"

[ "$fails" = 0 ] && echo "TEST PASS store-post-update" || echo "TEST FAIL store-post-update fails=$fails"
[ "$fails" = 0 ]
