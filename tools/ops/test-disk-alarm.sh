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
: > "$T/proc/100/io"; echo bash > "$T/proc/100/comm"; ln -s "$T" "$T/proc/100/cwd"
printf '#!/bin/sh\nprintf "%%s\\n" "$1" >> "%s/linear.calls"\n' "$T" > "$T/fake-linear"
chmod +x "$T/fake-linear"
export DISK_ALARM_PROC="$T/proc" DISK_ALARM_BOARD="$T/BOARD.md" DISK_ALARM_STATE="$T/state" \
  DISK_ALARM_LINEAR_CMD="$T/fake-linear" DISK_ALARM_LINEAR_ISSUE=DRA-TEST
run() { DISK_ALARM_DF="echo $1" DISK_ALARM_NOW=$2 "$here/disk-alarm" --quiet; echo $?; }
calls() { sleep 0.5; [ -f "$T/linear.calls" ] && wc -l < "$T/linear.calls" || echo 0; }

# 1. plenty free: quiet, nothing posted anywhere
r=$(run 900000000000 1000)
[ "$r" = 0 ] && [ ! -s "$T/BOARD.md" ] && [ "$(calls)" = 0 ] && ok "quiet above 300 GB" || bad "quiet above 300 GB (exit $r)"

# 2. default floor is 300 GB: 290 GB free alarms, board line and one Linear post naming the issue
r=$(run 290000000000 2000)
[ "$r" = 3 ] && grep -q '\*\*ALARM disk\*\* / free 290.0 GB' "$T/BOARD.md" && [ "$(calls)" = 1 ] &&
  grep -q 'Linear issue DRA-TEST' "$T/linear.calls" && grep -q 'ALARM disk: / free 290.0 GB' "$T/linear.calls" &&
  ok "alarm below 300 GB reaches board and Linear" || bad "alarm below 300 GB (exit $r, calls $(calls))"

# 3. repeat after REPEAT_S with a small further fall: board repeats, Linear does not
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

# 7. a failing Linear route never changes the exit status or the board line
r=$(DISK_ALARM_LINEAR_CMD=false; export DISK_ALARM_LINEAR_CMD; run 100000000000 20000)
[ "$r" = 3 ] && grep -q 'free 100.0 GB' "$T/BOARD.md" && ok "Linear failure does not change the check" || bad "Linear failure (exit $r)"

# 8. negative control: the floor is a setting, 290 GB with MIN_GB=200 is quiet
rm -rf "$T/state" "$T/BOARD.md"; mkdir -p "$T/state"
r=$(DISK_ALARM_MIN_GB=200 run 290000000000 30000)
[ "$r" = 0 ] && [ ! -s "$T/BOARD.md" ] && ok "MIN_GB setting respected" || bad "MIN_GB setting (exit $r)"

echo "disk-alarm tests: $fails failed"
[ "$fails" = 0 ]
