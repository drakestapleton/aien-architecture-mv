#!/bin/sh
# test-spark-window-starve.sh [SCRIPT]: regression test for spark-window _hold.
# Uses only temp lock files and a temp window root; never touches /tmp/aien-quiet.lock
# or /tmp/aien-gb10.lock.
#   case 1 (no contention): opens fast.
#   case 2 (one shared holder through $SPARK_QUIET_GATE, no pause): opens within LIMIT.
#     Deterministic for the same reason as case 3: the gate keeps the holder's next turn out.
#   case 3 (two shared holders through $SPARK_QUIET_GATE, no pause): opens within LIMIT.
#     Same order as quiet-build, so the gate at spark-window:330-336 keeps new holders out
#     and the drain finishes.
#   case 4 (chip busy, one gated shared holder): waits for the chip, then opens.
#   case 2p (one plain flock -s holder, no gate) and case 5 (two plain flock -s holders,
#     no gate) run only with SPARK_STARVE_PLAIN=1. Linux flock gives an exclusive waiter no
#     priority: one plain holder leaves only a process-start gap (the L189 path), so whether
#     the window wins it depends on timing; two holders with no gap can starve the window.
# Exit 0 = every case that ran passed (a skip is not a failure). Pass an older script path to see it fail (red).
set -u
S=${1:-$(dirname "$0")/spark-window}; LIMIT=${LIMIT:-60}
T=$(mktemp -d /tmp/spark-window-starve.XXXXXX)
export SPARK_WINDOWS_ROOT=$T/win SPARK_QUIET_LOCK=$T/quiet.lock SPARK_GB10_LOCK=$T/gb10.lock
# The L405 gate path, want dir and board are temp too, and the idle check ignores the host load:
# these temp locks have no other users, so the real machine load says nothing about them.
export SPARK_QUIET_GATE=$T/quiet.gate SPARK_QUIET_WANT=$T/want.d SPARK_BOARD=$T/BOARD.md SPARK_IDLE_LOAD=100000
: > "$SPARK_QUIET_LOCK"; : > "$SPARK_GB10_LOCK"
: > "$SPARK_QUIET_GATE"
pids=""
cleanup() { for p in $pids; do kill "$p" 2>/dev/null; done; for h in "$T"/win/*/holder.pid; do [ -f "$h" ] && kill -- -"$(cat "$h")" 2>/dev/null; done; sleep 0.5; rm -rf "$T"; }
trap cleanup EXIT
fail=0
opens_within() {  # NAME SECONDS: run open, true if it prints a window id in time
  ( "$S" open "$1" --lease 5 > "$T/open.out" 2> "$T/open.err" ) & op=$!
  i=0; while [ $i -lt $(( $2 * 5 )) ]; do
    [ -f "$SPARK_WINDOWS_ROOT/OPEN" ] && [ -f "$SPARK_WINDOWS_ROOT/$(cat "$SPARK_WINDOWS_ROOT/OPEN")/held" ] && { wait $op; return 0; }
    sleep 0.2; i=$((i + 1)); done
  return 1
}
close_it() { "$S" close "$(cat "$SPARK_WINDOWS_ROOT/OPEN" 2>/dev/null)" > /dev/null 2>&1; }

if opens_within plain 10; then echo "PASS case 1: no contention opens"; close_it; else echo "FAIL case 1: no contention did not open"; fail=1; close_it; fi

# Shared holders, one after another. SECONDS is how long each hold lasts; GAP is the pause after it.
# gated: quiet-build order. Pass $SPARK_QUIET_GATE shared, then hold the quiet lock shared.
#   spark-window holds that gate exclusive while it drains (L322), so the next iteration waits
#   outside and does not take the quiet lock. The holders already inside finish, then the window wins.
# plain: flock -s on the quiet lock only, no gate. Two of these can starve an exclusive waiter.
stream_gated() {  # SECONDS GAP
  ( while :; do flock -s "$SPARK_QUIET_GATE" true; flock -s "$SPARK_QUIET_LOCK" sleep "$1"; sleep "$2"; done ) & pids="$pids $!"
}
stream_plain() {  # SECONDS GAP
  ( while :; do flock -s "$SPARK_QUIET_LOCK" sleep "$1"; sleep "$2"; done ) & pids="$pids $!"
}
stop_streams() { for p in $pids; do kill "$p" 2>/dev/null; done; pids=""; sleep 1.2; }
case_run() {  # LABEL: open under the running streams
  if opens_within "$1" "$LIMIT"; then echo "PASS $1: opened under shared quiet holders (tries $(cat "$SPARK_WINDOWS_ROOT/$(cat "$SPARK_WINDOWS_ROOT/OPEN")/tries" 2>/dev/null))"
  else echo "FAIL $1: no window in $LIMIT s under shared quiet holders back to back"; fail=1; fi
  close_it; stop_streams
}
stream_gated 1.0 0
case_run "case 2 one holder through the quiet gate, no pause"
stream_gated 0.9 0; stream_gated 0.6 0
case_run "case 3 two holders through the quiet gate, no pause"
# chip busy too: the window must wait for the chip, then open once it is free (no deadlock, no early open)
stream_gated 1.0 0
( flock -x "$SPARK_GB10_LOCK" sleep 6 ) & pids="$pids $!"; sleep 0.5; t0=$(date +%s)
# the open time comes from the window's own held file, not from when this loop noticed it (the poll is slow on a loaded box)
if opens_within "case 4 chip busy 6 s" "$LIMIT"; then
  dt=$(( $(stat -c %Y "$SPARK_WINDOWS_ROOT/$(cat "$SPARK_WINDOWS_ROOT/OPEN")/held") - t0 ))
  if [ $dt -ge 4 ]; then echo "PASS case 4 chip busy 6 s: opened only after the chip was free (window opened $dt s after the start)"
  else echo "FAIL case 4 chip busy 6 s: opened while the chip was held ($dt s)"; fail=1; fi
else echo "FAIL case 4 chip busy 6 s: no window in $LIMIT s"; fail=1; fi
close_it; stop_streams
# Plain flock -s holders, no gate: timing-dependent (one) or known-starvable (two). Opt in with SPARK_STARVE_PLAIN=1.
if [ "${SPARK_STARVE_PLAIN:-}" = 1 ]; then
  stream_plain 1.0 0
  case_run "case 2p timing-dependent: one plain flock -s holder, no gate"
  stream_plain 0.9 0; stream_plain 0.6 0
  case_run "case 5 known-starvable: two plain flock -s holders, no gate"
else
  echo "SKIP case 2p timing-dependent: one plain flock -s holder, no gate (set SPARK_STARVE_PLAIN=1 to run)"
  echo "SKIP case 5 known-starvable: two plain flock -s holders, no gate (set SPARK_STARVE_PLAIN=1 to run)"
fi
exit $fail
