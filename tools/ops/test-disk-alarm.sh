#!/usr/bin/env bash
# test-disk-alarm.sh: disk-alarm in a sandbox (fake df, fake /proc, fake board, fake Linear route).
# Usage: bash tools/ops/test-disk-alarm.sh   exit 0 all pass, 1 any fail.
set -u
here=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/test-disk-alarm.XXXXXX")
trap 'rm -rf "$T"' EXIT
fails=0
ok() { echo "PASS $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }

mkdir -p "$T/proc/100" "$T/state"
: > "$T/proc/100/io"; printf 'ba`sh;$(x)\n' > "$T/proc/100/comm"; ln -s "$T" "$T/proc/100/cwd"
# the fake route: one line "ISSUE TEXT" per post, prints a comment id (a failing route: tests 7 and 8)
printf '#!/bin/sh\nprintf "%%s %%s\\n" "$1" "$2" >> "%s/linear.calls"\necho "fake-id-$$"\n' "$T" > "$T/fake-linear"
printf '#!/bin/sh\necho "HTTP 503 from Linear" >&2\nexit 1\n' > "$T/fail-linear"
chmod +x "$T/fake-linear" "$T/fail-linear"
export DISK_ALARM_PROC="$T/proc" DISK_ALARM_BOARD="$T/BOARD.md" DISK_ALARM_STATE="$T/state" \
  DISK_ALARM_LINEAR_CMD="$T/fake-linear" DISK_ALARM_LINEAR_ISSUE=DRA-TEST
run() { DISK_ALARM_DF="echo $1" DISK_ALARM_NOW=$2 "$here/disk-alarm" --quiet; echo $?; }
calls() { [ -f "$T/linear.calls" ] && wc -l < "$T/linear.calls" || echo 0; }

# 1. plenty free: quiet, nothing posted anywhere
r=$(run 900000000000 1000)
[ "$r" = 0 ] && [ ! -s "$T/BOARD.md" ] && [ "$(calls)" = 0 ] && ok "quiet above 300 GB" || bad "quiet above 300 GB (exit $r)"

# 2. default floor is 300 GB: 290 GB free alarms, board line and one confirmed Linear post naming the issue
mkdir -p "$T/proc/101"; printf 'write_bytes: 0\n' > "$T/proc/101/io"; printf 'ev`il$(id);\n' > "$T/proc/101/comm"
ln -s "$T" "$T/proc/101/cwd"
r=$(run 290000000000 2000)
[ "$r" = 3 ] && grep -q '\*\*ALARM disk\*\* / free 290.0 GB' "$T/BOARD.md" && [ "$(calls)" = 1 ] &&
  grep -q '^DRA-TEST .*ALARM disk: / free 290.0 GB' "$T/linear.calls" && grep -q 'posted on DRA-TEST, comment fake-id-' "$T/state/linear.log" &&
  [ -f "$T/state/last-linear" ] && ok "alarm below 300 GB reaches board and Linear, comment id recorded" || bad "alarm below 300 GB (exit $r, calls $(calls))"

# 3. repeat after REPEAT_S with a small further fall: board repeats, Linear does not (pid 101 now wrote 5 GB)
printf 'write_bytes: 5000000000\n' > "$T/proc/101/io"
r=$(run 285000000000 4000)
[ "$r" = 3 ] && [ "$(grep -c 'ALARM disk' "$T/BOARD.md")" = 2 ] && [ "$(calls)" = 1 ] &&
  ok "repeat alarm not reposted to Linear" || bad "repeat alarm (exit $r, calls $(calls))"

# 4. held repeat (inside REPEAT_S, under 25 GB fall): neither board nor Linear
r=$(run 284000000000 4100)
[ "$r" = 3 ] && [ "$(grep -c 'ALARM disk' "$T/BOARD.md")" = 2 ] && [ "$(calls)" = 1 ] &&
  ok "held alarm posts nothing" || bad "held alarm (exit $r, calls $(calls))"

# 5. a further 25 GB fall below the last Linear post: posted again
r=$(run 259000000000 4200)
[ "$r" = 3 ] && [ "$(calls)" = 2 ] && ok "25 GB further fall reposted to Linear" || bad "25 GB fall (exit $r, calls $(calls))"

# 6. recovery: one cleared line on the board and on Linear, then quiet with no more posts
r=$(run 900000000000 9000)
r2=$(run 900000000000 9100)
[ "$r" = 0 ] && [ "$r2" = 0 ] && [ "$(grep -c 'cleared' "$T/BOARD.md")" = 1 ] && [ "$(calls)" = 3 ] &&
  grep -q 'cleared' "$T/linear.calls" && ok "cleared once on board and Linear" || bad "cleared (exit $r/$r2, calls $(calls))"
# 7. a failing Linear route: exit status and board line unchanged, one board ALARM naming the failure,
#    the post kept as pending and nothing recorded as posted; a second failing check does not repeat the line
rm -f "$T/state/last-alarm"
r=$(DISK_ALARM_LINEAR_CMD="$T/fail-linear"; export DISK_ALARM_LINEAR_CMD; run 100000000000 20000)
r2=$(DISK_ALARM_LINEAR_CMD="$T/fail-linear"; export DISK_ALARM_LINEAR_CMD; run 99000000000 22000)
[ "$r" = 3 ] && [ "$r2" = 3 ] && grep -q 'free 100.0 GB' "$T/BOARD.md" &&
  [ "$(grep -c 'ALARM disk-alarm\*\*: the Linear comment on DRA-TEST failed (HTTP 503 from Linear)' "$T/BOARD.md")" = 1 ] &&
  [ -f "$T/state/linear-pending" ] && [ ! -f "$T/state/last-linear" ] && [ "$(calls)" = 3 ] &&
  ok "Linear failure: board ALARM once, post kept, not recorded" || bad "Linear failure (exit $r/$r2, calls $(calls))"

# 8. the next check with a working route sends the pending post first, then records it
r=$(run 99000000000 22100)
[ "$r" = 3 ] && [ ! -f "$T/state/linear-pending" ] && [ -f "$T/state/last-linear" ] && [ "$(calls)" = 4 ] &&
  tail -n 1 "$T/linear.calls" | grep -q 'free 99.0 GB' && ok "pending post sent at the next check" || bad "pending retry (exit $r, calls $(calls))"

# 9. names from /proc reach board and Linear only as a fixed character set (no backquote, $, ; or parentheses)
! grep -q '[`$]' "$T/linear.calls" && ! grep -q 'ev`il' "$T/BOARD.md" && grep -q '(ev?il??id??)' "$T/BOARD.md" &&
  ok "process names cut to a fixed character set" || bad "process names not sanitised: $(grep -o 'written ([^)]*' "$T/BOARD.md" | tail -1)"

# 10. negative control: the floor is a setting, 290 GB with MIN_GB=200 is quiet
rm -rf "$T/state" "$T/BOARD.md"; mkdir -p "$T/state"
r=$(DISK_ALARM_MIN_GB=200 run 290000000000 30000)
[ "$r" = 0 ] && [ ! -s "$T/BOARD.md" ] && ok "MIN_GB setting respected" || bad "MIN_GB setting (exit $r)"

# 11. a process whose io cannot be read (pid 100's io has no write_bytes line; pid 102's is mode 000) is counted
#     in the line, not taken as writing nothing; negative control: with every io readable and nobody writing,
#     the line says no readable process wrote
rm -rf "$T/state" "$T/BOARD.md"; mkdir -p "$T/state" "$T/proc/102"
printf 'write_bytes: 7\n' > "$T/proc/102/io"; chmod 000 "$T/proc/102/io"; printf 'root-svc\n' > "$T/proc/102/comm"
run 290000000000 40000 >/dev/null; r=$(run 290000000000 42000)
[ "$r" = 3 ] && tail -n 1 "$T/BOARD.md" | grep -qE 'Top writers by real directory: [0-9]+ process\(es\) whose writes could not be read' &&
  ! grep -q 'no readable process wrote\|no process wrote' "$T/BOARD.md" &&
  ok "unreadable process io counted, not taken as no writes" || bad "unreadable io (exit $r): $(tail -n 1 "$T/BOARD.md" | cut -c1-200)"
rm -rf "$T/proc/102" "$T/state" "$T/BOARD.md"; mkdir -p "$T/state"; printf 'write_bytes: 0\n' > "$T/proc/100/io"
run 290000000000 50000 >/dev/null; r=$(run 290000000000 52000)
[ "$r" = 3 ] && tail -n 1 "$T/BOARD.md" | grep -q 'Top writers by real directory: no readable process wrote (since' &&
  ok "every io readable, nobody wrote: says so (negative control)" || bad "readable io control (exit $r): $(tail -n 1 "$T/BOARD.md" | cut -c1-200)"

echo "disk-alarm tests: $fails failed"
[ "$fails" = 0 ]
