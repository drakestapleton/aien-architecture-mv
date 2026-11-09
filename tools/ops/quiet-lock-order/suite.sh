#!/bin/bash
# L217 model suite: suite.sh VARIANT_DIR  (VARIANT_DIR holds quiet-measure + quiet-build to test)
# Every lock, flag, gate, window dir and log is a model path under $ROOT/m-*; the live /tmp locks and
# ~/.local/state/quiet are never touched (HOME is redirected). The scripts' timing pin (cores 5-9,15-19)
# is rewritten to 16-18 in the model copies so nothing runs outside this lane's pool cores.
# Prints one PASS/FAIL line per check; exit status = number of FAILs.
V=$(cd "$1" && pwd); ROOT=${L217_ROOT:?set L217_ROOT to a scratch directory}; mkdir -p "$ROOT"
fails=0; pass=0
ok()  { echo "PASS $*"; pass=$((pass + 1)); }
bad() { echo "FAIL $*"; fails=$((fails + 1)); }
chk() { if eval "$2"; then ok "$1"; else bad "$1 [$3]"; fi; }
mk() {  # mk NAME: fresh model dir, exports the model environment, sets M B G Q
  M=$ROOT/m-$1; [ -d "$M" ] && mv "$M" "$ROOT/.old-$1-$$-$RANDOM"
  mkdir -p "$M/home" "$M/bin" "$M/win" "$M/want.d"
  for s in quiet-build quiet-measure; do sed 's/taskset -c 5-9,15-19/taskset -c 16-18/' "$V/$s" > "$M/bin/$s"; chmod +x "$M/bin/$s"; done
  B=$M/bin; G=$M/gb10.lock; Q=$M/quiet.lock; : > "$G"; : > "$Q"; : > "$M/gate"
  export HOME=$M/home SPARK_QUIET_LOCK=$Q SPARK_QUIET_WANT=$M/want.d SPARK_QUIET_GATE=$M/gate SPARK_WINDOWS_ROOT=$M/win
  export SPARK_FLAG_WAIT=3 SPARK_BUILD_MAX_WAIT=8 SPARK_DRAIN_MAX=300
  unset SPARK_WINDOW AIEN_GB10_LOCK_HELD
}
ms() { date +%s%3N; }
can_shared() { flock -n -s "$1" true; }      # is the lock free for a shared taker right now?
can_excl()   { flock -n -x "$1" true; }

# A. The L217 bug: a measurement queued for a busy chip must not stop builds.
mk A
flock "$G" sleep 20 & H=$!; sleep 0.5   # chip busy longer than the build cap (8 s): the live case is hours
$B/quiet-measure flock "$G" env AIEN_GB10_LOCK_HELD=1 sh -c 'echo "ran_ms=$(date +%s%3N) held=$AIEN_GB10_LOCK_HELD"' > $M/measure.out 2>$M/measure.err & MP=$!
sleep 1.5
can_shared "$Q"; q_free=$?                               # 0 = builds can take the quiet lock
nflags=$(ls "$M/want.d" | grep -c '^[0-9]')
t0=$(ms); $B/quiet-build sh -c 'echo BUILD-RAN' > $M/build.out 2>&1; t1=$(ms)
el=$(( t1 - t0 ))
wait $H; hend=$(ms); wait $MP; mrc=$?
chk "A1 quiet lock free while the measurement queues for the chip" '[ $q_free = 0 ]' "quiet lock busy"
chk "A2 no want flag raised while queued for the chip" '[ "$nflags" = 0 ]' "flags=$nflags"
chk "A3 build ran at once (<=2000 ms) behind a measurement queued for the chip" '[ $el -le 2000 ] && grep -q BUILD-RAN $M/build.out' "elapsed_ms=$el"
chk "A4 build took the lock, no bypass/intrusion" 'grep -q "how=lock" $HOME/.local/state/quiet/waits.log && [ ! -s $HOME/.local/state/quiet/intrusions.log ]' "$(cut -c1-80 $HOME/.local/state/quiet/waits.log 2>/dev/null | tr '\n' ' ')"
r=$(sed -n 's/.*ran_ms=\([0-9]*\).*/\1/p' $M/measure.out)
chk "A5 measurement ran after the chip holder left, rc 0, AIEN_GB10_LOCK_HELD=1" '[ "$mrc" = 0 ] && [ -n "$r" ] && [ "$r" -ge $((hend - 500)) ] && grep -q "held=1" $M/measure.out' "rc=$mrc out=$(cat $M/measure.out) err=$(head -c 200 $M/measure.err)"
echo "     A: build elapsed_ms=$el"

# B. No overlap: a build started during a measurement waits until the measurement ends.
mk B
$B/quiet-measure flock "$G" sh -c 'echo "M_start $(date +%s%3N)"; sleep 3; echo "M_end $(date +%s%3N)"' > $M/o 2>&1 & MP=$!
sleep 1
SPARK_FLAG_WAIT=0 SPARK_BUILD_MAX_WAIT=30 $B/quiet-build sh -c 'echo "B_start $(date +%s%3N)"' >> $M/o 2>&1
wait $MP
me=$(awk '$1=="M_end"{print $2}' $M/o); bs=$(awk '$1=="B_start"{print $2}' $M/o)
chk "B1 build waited for the running measurement (B_start >= M_end)" '[ -n "$me" ] && [ -n "$bs" ] && [ "$bs" -ge "$me" ]' "$(tr '\n' ' ' < $M/o)"
chk "B2 no bypass" '[ ! -s $HOME/.local/state/quiet/intrusions.log ]' "intrusion logged"

# C. CMD exit code kept; chip AND quiet lock held while CMD runs; both free afterwards.
mk C
$B/quiet-measure flock "$G" sh -c 'flock -n -x "$1" true && echo CHIP_FREE_INSIDE; flock -n -s "$2" true && echo QUIET_FREE_INSIDE; exit 7' x "$G" "$Q" > $M/o 2>&1; rc=$?
chk "C1 CMD exit code preserved (7)" '[ $rc = 7 ]' "rc=$rc"
chk "C2 chip lock held during CMD" '! grep -q CHIP_FREE_INSIDE $M/o' "$(cat $M/o)"
chk "C3 quiet lock held exclusive during CMD" '! grep -q QUIET_FREE_INSIDE $M/o' "$(cat $M/o)"
chk "C4 both locks free after" 'can_excl "$G" && can_excl "$Q"' "still held"
chk "C5 no want flag left" '[ -z "$(ls -A $M/want.d)" ]' "$(ls -A $M/want.d)"

# D. -o: CMD does not inherit the chip fd, the chip stays held for CMD's life.
mk D
$B/quiet-measure flock -o "$G" sh -c 'n=0; for f in /proc/$$/fd/*; do [ "$(readlink $f)" = "$1" ] && n=$((n+1)); done; echo "chipfds=$n"; flock -n -x "$1" true && echo CHIP_FREE_INSIDE; exit 0' x "$G" > $M/o 2>&1; rc=$?
chk "D1 -o: chip fd not passed to CMD, chip held, rc 0" '[ $rc = 0 ] && grep -q chipfds=0 $M/o && ! grep -q CHIP_FREE_INSIDE $M/o' "rc=$rc $(tr '\n' ' ' < $M/o)"

# E. Other forms.
mk E
flock -s "$G" sleep 3 & H=$!; sleep 0.3
t0=$(ms); $B/quiet-measure flock -s "$G" true; rc=$?; el=$(( $(ms) - t0 ))
chk "E1 -s beside another shared holder runs at once" '[ $rc = 0 ] && [ $el -le 1500 ]' "rc=$rc el=$el"
wait $H
flock -x "$G" sleep 4 & H=$!; sleep 0.3
t0=$(ms); $B/quiet-measure flock -n "$G" echo SHOULD-NOT-RUN > $M/n.out 2>&1; rcn=$?; eln=$(( $(ms) - t0 ))
t0=$(ms); $B/quiet-measure flock -w 1 "$G" echo SHOULD-NOT-RUN > $M/w.out 2>&1; rcw=$?; elw=$(( $(ms) - t0 ))
wait $H
chk "E2 -n on a busy chip: rc 1, quick, CMD not run" '[ $rcn = 1 ] && [ $eln -le 1500 ] && ! grep -q SHOULD-NOT-RUN $M/n.out' "rc=$rcn el=$eln"
chk "E3 -w 1 on a busy chip: rc 1 after ~1 s, CMD not run" '[ $rcw = 1 ] && [ $elw -ge 900 ] && [ $elw -le 3000 ] && ! grep -q SHOULD-NOT-RUN $M/w.out' "rc=$rcw el=$elw"
o=$($B/quiet-measure sh -c 'echo plain-ok' 2>&1); chk "E4 non-flock CMD (old path) works" '[ "$o" = plain-ok ]' "$o"
o=$($B/quiet-measure flock "$G" -c 'echo dash-c-ok' 2>&1); chk "E5 flock FILE -c (old path) works" '[ "$o" = dash-c-ok ]' "$o"
chk "E6 no want flag left" '[ -z "$(ls -A $M/want.d)" ]' "$(ls -A $M/want.d)"

# F. Deadlock guard: a build holds the quiet lock (shared) and its CMD then queues for the chip that the
#    measurement holds while draining the quiet lock. Without the guard the two wait on each other.
mk F
SPARK_DRAIN_MAX=60
$B/quiet-build sh -c 'sleep 2; flock "$1" sh -c "echo X_chip \$(date +%s%3N)"' x "$G" > $M/x.out 2>&1 & XP=$!
sleep 0.5
SPARK_DRAIN_MAX=60 timeout 25 $B/quiet-measure flock "$G" sh -c 'echo "M_ran $(date +%s%3N)"' > $M/m.out 2>$M/m.err & MP=$!
wait $MP; mrc=$?; timeout 10 sh -c "while kill -0 $XP 2>/dev/null; do sleep 0.2; done"; wait $XP; xrc=$?
xt=$(awk '$1=="X_chip"{print $2}' $M/x.out); mt=$(awk '$1=="M_ran"{print $2}' $M/m.out)
chk "F1 both finish (no deadlock): measurement rc 0, build rc 0" '[ "$mrc" = 0 ] && [ "$xrc" = 0 ] && [ -n "$xt" ] && [ -n "$mt" ]' "mrc=$mrc xrc=$xrc x=$(cat $M/x.out) m=$(cat $M/m.out) err=$(head -c 200 $M/m.err)"
chk "F2 the measurement let the chip go for the build (yield logged)" 'grep -q "holds the quiet lock open" $HOME/.local/state/quiet/measure-yields.log 2>/dev/null' "no yield line"
unset SPARK_DRAIN_MAX

# G. Drain cap: an unrelated exclusive holder of the quiet lock; the measurement lets the chip go after
#    SPARK_DRAIN_MAX s instead of sitting on the chip, then runs when the holder leaves.
mk G
flock -x "$Q" sleep 7 & H=$!; sleep 0.3
SPARK_DRAIN_MAX=2 timeout 30 $B/quiet-measure flock "$G" sh -c 'echo M_ran' > $M/m.out 2>$M/m.err & MP=$!
sleep 3.2; can_excl "$G"; chip_free_mid=$?
wait $H; wait $MP; mrc=$?
chk "G1 drain cap: yield logged ('did not drain')" 'grep -q "did not drain in 2s" $HOME/.local/state/quiet/measure-yields.log 2>/dev/null' "no yield line"
chk "G2 measurement ran after the holder left (rc 0)" '[ "$mrc" = 0 ] && grep -q M_ran $M/m.out' "rc=$mrc err=$(head -c 200 $M/m.err)"
echo "     G: chip lock free sampled mid-wait: $([ $chip_free_mid = 0 ] && echo yes || echo no) (informational)"

# H. A measurement killed (TERM to quiet-measure only) while queued for the chip never runs CMD once the
#    chip frees. The pre-fix trap only removed the flag and carried on.
mk H
flock "$G" sleep 4 & H=$!; sleep 0.3
$B/quiet-measure flock "$G" sh -c 'echo SHOULD-NOT-RUN' > $M/o 2>&1 & MP=$!
sleep 1; kill -TERM $MP
wait $H; wait $MP; mrc=$?; sleep 0.3
chk "H1 TERM while queued for the chip: CMD not run, rc 143, chip free, no flag" '! grep -q SHOULD-NOT-RUN $M/o && [ "$mrc" = 143 ] && can_excl "$G" && [ -z "$(ls -A $M/want.d)" ]' "rc=$mrc out=$(tr '\n' ' ' < $M/o) flags=$(ls -A $M/want.d)"

# I. With the chip in hand the gate is waited for at most SPARK_DRAIN_MAX s, then passed (fail open): a gate
#    holder must not keep the chip idle for the old 25 min gate wait.
mk I
flock -x "$M/gate" sleep 8 & H=$!; sleep 0.3
t0=$(ms); SPARK_DRAIN_MAX=2 timeout 20 $B/quiet-measure flock "$G" sh -c 'echo M_ran' > $M/o 2>&1; mrc=$?; el=$(( $(ms) - t0 ))
wait $H
chk "I1 gate held by another: with the chip, pass it after SPARK_DRAIN_MAX (2 s) and run, rc 0" '[ "$mrc" = 0 ] && grep -q M_ran $M/o && [ $el -ge 1500 ] && [ $el -le 5000 ]' "rc=$mrc el=$el"

echo "SUMMARY variant=$V pass=$pass fail=$fails"
exit $fails
