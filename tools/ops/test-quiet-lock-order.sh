#!/bin/bash
# L217 replay: quiet-measure lock order. Scratch locks only: never touches /tmp/aien-quiet.lock,
# /tmp/aien-gb10.lock, the gate, the want flags or ~/.local/state/quiet (HOME is redirected per case).
# Runs quiet-lock-order/suite.sh on several copies of quiet-measure, each beside this directory's quiet-build:
#   new      ./quiet-measure: must pass every check
#   orig     quiet-lock-order/quiet-measure.pre-L217, the installed copy before L217 (sha256 c838569e...):
#            must FAIL A1-A3, the reproduction (queued for the chip it holds the quiet lock and stops builds)
#   mutants  ./quiet-measure with one part of the fix undone: each must FAIL its own check
# Exit 0 only when all of that holds. The suite pins commands to cores 16-18; run it under that pool lock:
#   flock -o ~/handoffs/hive/queen/pool-16-18.lock taskset -c 16-18 nice -n 10 bash tools/ops/test-quiet-lock-order.sh
# About 80 s per copy, 8 copies.
set -u
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=$(mktemp -d "${TMPDIR:-/tmp}/l217-replay.XXXXXX")
trap 'rm -rf "$root"' EXIT
variant() {  # variant NAME QUIET-MEASURE: a directory with that quiet-measure and the current quiet-build
  mkdir -p "$root/$1"; cp "$2" "$root/$1/quiet-measure"; cp "$here/quiet-build" "$root/$1/quiet-build"
}
mut() {  # mut NAME SED-EXPR: the new quiet-measure with one change; refuses if the sed changed nothing
  variant "$1" "$here/quiet-measure"; sed -i "$2" "$root/$1/quiet-measure"
  if cmp -s "$here/quiet-measure" "$root/$1/quiet-measure"; then echo "MUTANT $1 did not change the script"; exit 98; fi
}
variant new "$here/quiet-measure"
variant orig "$here/quiet-lock-order/quiet-measure.pre-L217"
mut flagfirst 's|^  exec 9<"$RL"$|  exec 9<"$RL"; echo "$(date -u +%FT%TZ) $all" > "$f"|'   # want flag up while queued
mut noguard   's|^chip_waiter_holds_quiet() {$|chip_waiter_holds_quiet() { return 1;|'          # no deadlock guard
mut chipdrop  's|^  tsf="$W/.$$.held"; date -u|  flock -u 9; tsf="$W/.$$.held"; date -u|'          # chip let go before CMD
mut noquiet   's|flock -x -w 5 8 \&\& { got=1; break; }|got=1; break|'                          # quiet lock never taken
mut gatewait  's|flock -s -w "$DRAIN" "$GATE" true|flock -s -w 1500 "$GATE" true|'               # 25 min gate wait with the chip
mut oldtrap   "s|; trap 'exit 130' INT; trap 'exit 143' TERM| INT TERM|"                         # TERM only removes the flag
bad=0
run() {  # run NAME [CHECK-ID...]: no ids = every check must pass; else each id must FAIL
  v=$1; shift
  out=$(L217_ROOT=$root/run-$v bash "$here/quiet-lock-order/suite.sh" "$root/$v")
  printf '=== %s (quiet-measure sha256 %s)\n%s\n' "$v" "$(sha256sum < "$root/$v/quiet-measure" | cut -c1-16)" "$out"
  if [ $# -eq 0 ]; then
    if printf '%s\n' "$out" | grep -q '^FAIL '; then echo "VERDICT $v: WRONG, a check failed"; bad=$((bad + 1)); else echo "VERDICT $v: ok, every check passed"; fi
    return
  fi
  miss=
  for id; do printf '%s\n' "$out" | grep -q "^FAIL $id " || miss="$miss $id"; done
  if [ -n "$miss" ]; then echo "VERDICT $v: WRONG, expected to FAIL but passed:$miss"; bad=$((bad + 1)); else echo "VERDICT $v: ok, failed as expected: $*"; fi
}
run new
run orig A1 A2 A3
run flagfirst A2
run noguard F1
run chipdrop C2
run noquiet C3
run gatewait I1
run oldtrap H1
echo "RESULT $([ $bad = 0 ] && echo PASS || echo "FAIL ($bad wrong verdicts)")"
exit $bad
