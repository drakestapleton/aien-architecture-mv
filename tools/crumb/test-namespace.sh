#!/bin/sh
# Repository namespaces (layout 2), crumb check, lease generations (fencing) and enforcement mode (crumb924).
# usage: sh test-namespace.sh ./crumb. Scratch directories only; no network (origin URLs are set, never fetched).
# Clock: CRUMB_TEST_NOW (test-only, epoch seconds) pins "now" for the expiry boundary.
C=${1:-./crumb}; C=$(cd "$(dirname "$C")" && pwd)/$(basename "$C")
T=$(mktemp -d); trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
unset CRUMB_COORD_ROOT CRUMB_EXPECT_STORE_ID CRUMB_STRICT_STORE_ID CRUMB_ENFORCE CRUMB_REPO_ID CRUMB_SESSION CRUMB_TEST_NOW CC_STORE
fail=0; ok() { echo "PASS $1"; }; bad() { echo "FAIL $1"; fail=1; }
TO=""; command -v timeout >/dev/null 2>&1 && TO="timeout 20"
r() {   # r <dir> <command...>: RC, OUT (stdout), ERR (stderr); a hung command is killed after 20 s (rc 124)
  d=$1; shift
  OUT=$(cd "$d" && $TO "$@" 2>"$T/err" </dev/null); RC=$?; ERR=$(cat "$T/err")
}
why() { echo "    (rc=$RC) out: $(printf '%s' "$OUT" | head -2 | cut -c1-200) err: $(printf '%s' "$ERR" | head -2 | cut -c1-200)"; }
has() { printf '%s\n' "$OUT" | grep -Eq "$1"; }
herr() { printf '%s\n' "$ERR" | grep -Eq "$1"; }
mkrepo() {   # mkrepo <path> <origin-url or ->
  mkdir -p "$1/src/deep" && (cd "$1" && git init -q -b main . && echo a > src/a.c && echo b > src/b.c && echo d > src/deep/d.c &&
    git add -A && git -c user.name=t -c user.email=t@t commit -qm init && { [ "$2" = - ] || git remote add origin "$2"; }) >/dev/null 2>&1
}
enroll() {   # enroll <repo> <root>: shared root, layout 2 (store-init once per root), registered store id, enforcement on
  git -C "$1" config crumb.coordinationRoot "$2"
  [ -f "$2/LAYOUT" ] || (cd "$1" && "$C" store-init . >/dev/null 2>&1)
  git -C "$1" config crumb.storeId "$(cd "$1" && "$C" store-id . 2>/dev/null)"
  git -C "$1" config crumb.enforce true
}
sum() { find "$1" -type f -exec cksum {} + 2>/dev/null | sort; }
NOW=1800000000   # 2027-01-15T08:00:00Z

echo "crumb under test: $C"
# ---- N1 store-init / layout 2 ----
ROOT="$T/shared"; mkdir -p "$ROOT"
mkrepo "$T/one" https://github.com/Acme/One.git; mkrepo "$T/two" git@github.com:acme/two.git
git -C "$T/one" config crumb.coordinationRoot "$ROOT"
r "$T/one" "$C" store-init .
[ $RC -eq 0 ] && has '^STORE_INIT .* layout crumb-coord-layout/2 store [0-9a-f]{32}$' && [ "$(cat "$ROOT/LAYOUT" 2>/dev/null)" = crumb-coord-layout/2 ] && [ -d "$ROOT/repos" ] && ok "N1 store-init writes LAYOUT crumb-coord-layout/2 and repos/ under the shared root" || { why; bad "N1 store-init"; }
has '^repository acme/one \(from origin remote URL\)' && ok "N1 repo id derived from the origin URL as lowercase owner/repo" || { why; bad "N1 repo id from origin"; }
l0=$(cksum < "$ROOT/LAYOUT" 2>/dev/null); id0=$(cat "$ROOT/STORE_ID" 2>/dev/null)
r "$T/one" "$C" store-init .
[ $RC -eq 0 ] && has 'already layout 2' && [ "$(cksum < "$ROOT/LAYOUT")" = "$l0" ] && [ "$(cat "$ROOT/STORE_ID")" = "$id0" ] && ok "N1 store-init is idempotent (LAYOUT and STORE_ID unchanged)" || { why; bad "N1 store-init idempotent"; }
enroll "$T/one" "$ROOT"; enroll "$T/two" "$ROOT"

# ---- N2 cross-repository: two repositories, same relative path, one shared root ----
r "$T/one" "$C" claim alice . src/a.c "one's a.c" 600
[ $RC -eq 0 ] && has '^CLAIMED src/a.c .* generation 1$' && ok "N2 alice claims src/a.c in repo one (generation 1)" || { why; bad "N2 claim one"; }
r "$T/two" "$C" claim bob . src/a.c "two's a.c" 600
[ $RC -eq 0 ] && has '^CLAIMED src/a.c .* generation 1$' && ok "N2 bob claims src/a.c in repo two: no collision across repositories" || { why; bad "N2 cross-repo collision"; }
r "$T/two" "$C" check alice . src/a.c
[ $RC -eq 2 ] && has '^REFUSED held-by bob src/a.c key src/a.c ' && ok "N2 check in repo two sees only repo two's holder" || { why; bad "N2 check two"; }
r "$T/one" "$C" check alice . src/a.c
[ $RC -eq 0 ] && ok "N2 check in repo one: alice holds it" || { why; bad "N2 check one"; }
[ -f "$ROOT/repos/acme/one/dirs/src.json" ] && [ -f "$ROOT/repos/acme/two/dirs/src.json" ] && [ ! -e "$ROOT/dirs" ] && ok "N2 records live in repos/<owner>/<repo>/ namespaces, nothing flat at the root" || bad "N2 namespace layout"

# ---- N3 two independent clones of one repository sharing the root (origin URL spellings differ) ----
mkrepo "$T/origin-src" -; git clone -q --bare "$T/origin-src" "$T/origin.git" 2>/dev/null
git clone -q "$T/origin.git" "$T/c1" 2>/dev/null; git clone -q "$T/origin.git" "$T/c2" 2>/dev/null
git -C "$T/c1" remote set-url origin https://github.com/Acme/Widget.git; git -C "$T/c2" remote set-url origin git@github.com:acme/widget.git
enroll "$T/c1" "$ROOT"; enroll "$T/c2" "$ROOT"
i=1; while [ $i -le 8 ]; do d="$T/c$(( (i % 2) + 1 ))"; ( cd "$d" && "$C" claim "racer$i" . src/a.c race 600 >/dev/null 2>&1; echo $? > "$T/rc.$i" ) & i=$((i + 1)); done; wait
w=$(cat "$T"/rc.[1-8] | grep -c '^0$'); b=$(cat "$T"/rc.[1-8] | grep -c '^2$')
[ "$w" -eq 1 ] && [ "$b" -eq 7 ] && ok "N3 8 concurrent claims from two independent clones: exactly 1 exit 0, 7 exit 2" || bad "N3 clone race (wins=$w blocked=$b)"
win=$(for i in 1 2 3 4 5 6 7 8; do [ "$(cat "$T/rc.$i")" = 0 ] && echo "racer$i"; done | head -1)
r "$T/c2" "$C" check "${win:-none}" . src/a.c; a=$RC; r "$T/c1" "$C" check "${win:-none}" . src/a.c
[ $a -eq 0 ] && [ $RC -eq 0 ] && ok "N3 both clones agree on the single holder ($win)" || { why; bad "N3 clones disagree"; }
[ -d "$ROOT/repos/acme/widget" ] && [ "$(ls "$ROOT/repos/acme")" = "one
two
widget" ] && ok "N3 https://github.com/Acme/Widget.git and git@github.com:acme/widget.git are one namespace" || bad "N3 URL normalisation ($(ls "$ROOT/repos/acme" | tr '\n' ' '))"

# ---- N4 linked worktrees of one repository on the shared root ----
git -C "$T/one" worktree add -q -b wt "$T/one-wt" 2>/dev/null
r "$T/one-wt" "$C" claim carol . src/a.c "from the worktree"
[ $RC -eq 2 ] && has '^BLOCKED src/a.c held by alice' && ok "N4 linked worktree sees alice's lease (BLOCKED, exit 2)" || { why; bad "N4 worktree block"; }
r "$T/one-wt" "$C" check alice . src/a.c
[ $RC -eq 0 ] && has '^HELD src/a.c by alice key src/a.c generation 1 expires [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' && ok "N4 check from the linked worktree: HELD line shape" || { why; bad "N4 worktree check"; }
r "$T/one-wt" "$C" claim carol . src/b.c "other file"
[ $RC -eq 0 ] && ok "N4 a different file is free from the worktree" || { why; bad "N4 worktree other file"; }

# ---- N5 overlap: ancestor and descendant leases of another agent block a claim ----
r "$T/one" "$C" claim dave . src "whole src"
[ $RC -eq 2 ] && has '^BLOCKED src held by (alice|carol) .*\[overlapping lease on src/[ab].c\]' && ok "N5 claim of src refused: another agent holds a descendant (exit 2, BLOCKED shape)" || { why; bad "N5 descendant overlap"; }
r "$T/one" "$C" claim dave . . "whole repo"
[ $RC -eq 2 ] && has '^BLOCKED \. held by' && ok "N5 claim of . (whole repository) refused while any lease exists" || { why; bad "N5 root overlap"; }
r "$T/one" "$C" claim dave . src/deep "deep"
[ $RC -eq 0 ] && ok "N5 an unrelated subtree is free" || { why; bad "N5 unrelated subtree"; }
r "$T/one" "$C" claim erin . src/deep/d.c "under dave"
[ $RC -eq 2 ] && has 'overlapping lease on src/deep\]' && ok "N5 claim under another agent's directory lease refused (ancestor overlap)" || { why; bad "N5 ancestor overlap"; }
r "$T/one" "$C" check dave . src/deep/d.c
[ $RC -eq 0 ] && has '^HELD src/deep/d.c by dave key src/deep generation 1 ' && ok "N5 check covers a file through an ancestor directory lease" || { why; bad "N5 ancestor coverage"; }
r "$T/one" "$C" claim dave . src/deep/d.c "nested, same agent"
[ $RC -eq 0 ] && ok "N5 the same agent may nest a lease inside its own" || { why; bad "N5 same-agent nesting"; }
r "$T/one" "$C" check erin . src/deep/d.c
[ $RC -eq 2 ] && has '^REFUSED held-by dave src/deep/d.c key src/deep/d.c ' && ok "N5 check reports the nearest other holder" || { why; bad "N5 other holder"; }

# ---- N6 lease generation: increments on each new acquisition, kept on renewal, fenced by check --generation ----
G="$T/gen"; mkrepo "$G" https://github.com/acme/gen.git; enroll "$G" "$ROOT"
gen() { printf '%s\n' "$OUT" | sed -n 's/.* generation \([0-9][0-9]*\)$/\1/p'; }
r "$G" env CRUMB_TEST_NOW=$NOW "$C" claim alice . src/a.c g 100; g1=$(gen)
r "$G" env CRUMB_TEST_NOW=$((NOW + 10)) "$C" claim alice . src/a.c renew 100; g2=$(gen)
[ "$g1" = 1 ] && [ "$g2" = 1 ] && ok "N6 first acquisition is generation 1; renewal by the valid holder keeps it" || bad "N6 renewal ($g1 $g2)"
r "$G" env CRUMB_TEST_NOW=$((NOW + 20)) "$C" close alice . src/a.c; r "$G" env CRUMB_TEST_NOW=$((NOW + 21)) "$C" claim bob . src/a.c after-release 100; g3=$(gen)
[ "$g3" = 2 ] && ok "N6 takeover after release: generation 2" || { why; bad "N6 after release ($g3)"; }
r "$G" env CRUMB_TEST_NOW=$((NOW + 21 + 101)) "$C" claim alice . src/a.c after-expiry 100; g4=$(gen)
[ "$g4" = 3 ] && ok "N6 re-acquire after expiry: generation 3" || { why; bad "N6 after expiry ($g4)"; }
r "$G" env CRUMB_TEST_NOW=$((NOW + 130)) "$C" check alice . src/a.c --generation 3
[ $RC -eq 0 ] && has 'generation 3 ' && ok "N6 check --generation 3 matches (exit 0)" || { why; bad "N6 generation match"; }
r "$G" env CRUMB_TEST_NOW=$((NOW + 130)) "$C" check alice . src/a.c --generation 2
[ $RC -eq 2 ] && has '^REFUSED generation 3!=2 src/a.c key src/a.c' && ok "N6 check --generation 2 against generation 3: REFUSED generation 3!=2 (exit 2)" || { why; bad "N6 generation mismatch"; }
r "$G" "$C" check alice . src/a.c --generation x
[ $RC -eq 1 ] && herr "bad generation: x" && ok "N6 non-numeric --generation is a usage error (exit 1)" || { why; bad "N6 bad generation arg"; }
r "$G" "$C" check alice . src/a.c --gen 3
[ $RC -eq 1 ] && ok "N6 unknown check option is a usage error (exit 1)" || { why; bad "N6 bad option"; }

# ---- N7 expiry boundary (CRUMB_TEST_NOW): now - acquired_at == ttl still valid, ttl + 1 expired ----
E="$T/exp"; mkrepo "$E" https://github.com/acme/exp.git; enroll "$E" "$ROOT"
r "$E" env CRUMB_TEST_NOW=$NOW "$C" claim alice . src/a.c boundary 100
r "$E" env CRUMB_TEST_NOW=$((NOW + 100)) "$C" check alice . src/a.c
[ $RC -eq 0 ] && has 'expires 2027-01-15T08:01:40Z$' && ok "N7 check at acquired+ttl: still HELD (exit 0), expires = acquired+ttl" || { why; bad "N7 boundary valid"; }
r "$E" env CRUMB_TEST_NOW=$((NOW + 101)) "$C" check alice . src/a.c
[ $RC -eq 2 ] && has '^REFUSED expired src/a.c key src/a.c holder alice generation 1 expired 2027-01-15T08:01:40Z$' && ok "N7 check at acquired+ttl+1: REFUSED expired (exit 2)" || { why; bad "N7 boundary expired"; }
r "$E" env CRUMB_TEST_NOW=$((NOW + 100)) "$C" claim bob . src/a.c early 100
[ $RC -eq 2 ] && ok "N7 claim by another agent at acquired+ttl: BLOCKED" || { why; bad "N7 claim at boundary"; }
s0=$(sum "$ROOT/repos/acme/exp")
r "$E" env CRUMB_TEST_NOW=$((NOW + 101)) "$C" check bob . src/a.c
[ "$(sum "$ROOT/repos/acme/exp")" = "$s0" ] && grep -q '"holder": "alice"' "$ROOT/repos/acme/exp/dirs/src.json" && ok "N7 check never prunes the expired lease (store byte-identical)" || bad "N7 check pruned"
r "$E" env CRUMB_TEST_NOW=$((NOW + 101)) "$C" claim bob . src/a.c late 100
[ $RC -eq 0 ] && has 'generation 2$' && ok "N7 claim at acquired+ttl+1 succeeds with generation 2" || { why; bad "N7 claim after boundary"; }

# ---- N8 check: absent / other holder / expired / read-only on a store that does not exist ----
F="$T/fresh"; mkrepo "$F" -
r "$F" "$C" check alice . src/a.c
[ $RC -eq 2 ] && has '^REFUSED absent src/a.c' && [ ! -e "$F/.git/crumb" ] && ok "N8 check on a never-used store: REFUSED absent (exit 2), creates nothing" || { why; bad "N8 absent/read-only"; }
r "$F" "$C" claim alice . src/a.c x 600; r "$F" "$C" check bob . src/a.c
[ $RC -eq 2 ] && has '^REFUSED held-by alice ' && ok "N8 layout-1 store: check by another agent REFUSED held-by (exit 2)" || { why; bad "N8 v1 other holder"; }
r "$F" "$C" check alice . src
[ $RC -eq 2 ] && has '^REFUSED absent src ' && ok "N8 a lease on a file does not cover its directory" || { why; bad "N8 no upward coverage"; }
r "$F" "$C" check alice . "$T/elsewhere"
[ $RC -eq 1 ] && herr "outside the repository" && ok "N8 target outside the repository: exit 1" || { why; bad "N8 outside target"; }
r "$T" "$C" check alice "$T" x
[ $RC -eq 1 ] && herr "check needs a git repository" && ok "N8 check outside any git repository: exit 1 (no .crumb.local fallback)" || { why; bad "N8 check outside git"; }

# ---- N9 enforcement: agent identity verbatim, no aliases, one live session per id ----
A="$T/ag"; mkrepo "$A" https://github.com/acme/ag.git; enroll "$A" "$ROOT"
n=0; for id in "bad agent" "a/b" "_lead" ".hidden" "a:b" "$(printf 'x%.0s' $(seq 1 161))"; do
  r "$A" "$C" claim "$id" . src/a.c x 600; [ $RC -eq 1 ] && herr 'AGENT_ID_INVALID' && n=$((n + 1)); done
[ $n -eq 6 ] && ok "N9 enforcement refuses agent ids that would be rewritten (space, /, leading _ or ., :, 161 chars): exit 1" || bad "N9 invalid ids ($n of 6 refused)"
r "$A" "$C" claim "$(printf 'x%.0s' $(seq 1 160))" . src/deep/d.c x 600
[ $RC -eq 0 ] && ok "N9 a 160-character id is accepted" || { why; bad "N9 160 chars"; }
r "$A" "$C" claim a@b . src/a.c x 600; r1=$RC; r "$A" "$C" claim a_b . src/b.c y 600; r2=$RC
[ $r1 -eq 0 ] && [ $r2 -eq 0 ] && [ -f "$ROOT/repos/acme/ag/agents/a@b.json" ] && [ -f "$ROOT/repos/acme/ag/agents/a_b.json" ] && ok "N9 a@b and a_b are two identities with two records (no sanitising alias)" || bad "N9 alias records"
r "$A" "$C" check a_b . src/a.c
[ $RC -eq 2 ] && has 'REFUSED held-by a@b' && ok "N9 a_b does not inherit a@b's lease" || { why; bad "N9 alias lease"; }
r "$A" env CRUMB_SESSION=sess-1 "$C" claim w.dup . src/deep/x.c x 600; r1=$RC
r "$A" env CRUMB_SESSION=sess-2 "$C" claim w.dup . src/deep/y.c y 600
[ $r1 -eq 0 ] && [ $RC -eq 2 ] && has '^BLOCKED agent w.dup is live in session sess-1, not this session sess-2' && ok "N9 duplicate agent identity: a second session presenting the same id is refused (exit 2)" || { why; bad "N9 duplicate session"; }
r "$A" env CRUMB_SESSION=sess-1 "$C" claim w.dup . src/deep/y.c y 600
[ $RC -eq 0 ] && ok "N9 the owning session keeps working" || { why; bad "N9 owning session"; }
r "$A" "$C" claim alice2 . src/c.c x 0
[ $RC -eq 1 ] && ok "N9 enforcement refuses ttl 0 (ttl_seconds must be positive)" || { why; bad "N9 ttl 0"; }

# ---- N10 enforcement: malformed lease schema is exit 1, never pruned, never taken over ----
M="$T/mal"; mkrepo "$M" https://github.com/acme/mal.git; enroll "$M" "$ROOT"
r "$M" "$C" claim alice . src/a.c x 600; REC="$ROOT/repos/acme/mal/dirs/src.json"; cp "$REC" "$T/pristine.json"
n=0; tot=0
for f in '.ttl_seconds="600"' '.ttl_seconds=0' '.ttl_seconds=-5' '.acquired_at="yesterday"' '.acquired_at="2026-13-01T00:00:00Z"' '.holder=5' 'del(.holder)' 'del(.generation)' '.generation=-1' '.generation=1.5' '.generation=0'; do
  tot=$((tot + 1)); jq ".locks[\"src/a.c\"] |= ($f)" "$T/pristine.json" > "$REC"; s0=$(cksum < "$REC")
  r "$M" "$C" check alice . src/a.c; c1=$RC; e1=$ERR; r "$M" "$C" claim bob . src/a.c takeover 600; c2=$RC
  if [ $c1 -eq 1 ] && [ $c2 -eq 1 ] && printf '%s' "$e1" | grep -q MALFORMED_LEASE && [ "$(cksum < "$REC")" = "$s0" ]; then n=$((n + 1)); else echo "    malformed $f: check=$c1 claim=$c2 $e1"; fi
done
[ $n -eq $tot ] && ok "N10 $tot malformed lease variants: check and claim exit 1 (MALFORMED_LEASE), record untouched, no takeover" || bad "N10 malformed schema ($n of $tot)"
jq '.locks["src/a.c"].acquired_at="2000-01-01T00:00:00Z" | .locks["src/a.c"].holder=7' "$T/pristine.json" > "$REC"; s0=$(cksum < "$REC")
r "$M" "$C" claim bob . src/b.c other 600
[ $RC -eq 1 ] && [ "$(cksum < "$REC")" = "$s0" ] && ok "N10 an expired but malformed lease is not swept by an unrelated claim (exit 1)" || { why; bad "N10 malformed swept"; }
jq '.locks="nope"' "$T/pristine.json" > "$REC"
r "$M" "$C" check alice . src/a.c
[ $RC -eq 1 ] && herr MALFORMED_RECORD && ok "N10 locks of the wrong type: exit 1" || { why; bad "N10 locks type"; }
cp "$T/pristine.json" "$REC"; mkdir -p "$F/.git/crumb/v1/dirs"
printf '{"locks": {"src/a.c": {"acquired_at": "%s", "ttl_seconds": 600}}}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$F/.git/crumb/v1/dirs/src.json"
r "$F" "$C" check alice . src/a.c
[ $RC -eq 1 ] && herr MALFORMED_LEASE && ok "N10 outside enforcement too, check refuses a lease without a holder (exit 1)" || { why; bad "N10 lenient holderless"; }

# ---- N11 enforcement: an inaccessible store directory is exit 1, never empty state ----
if [ "$(id -u)" -eq 0 ]; then echo "NOT_RUN N11 inaccessible directory (running as root: chmod 000 does not deny)"; else
  P="$T/perm"; mkrepo "$P" https://github.com/acme/perm.git; enroll "$P" "$ROOT"; NS="$ROOT/repos/acme/perm"
  r "$P" "$C" claim alice . src/deep/d.c x 600; chmod 000 "$NS/dirs/src"
  r "$P" "$C" claim bob . src/b.c y 600
  [ $RC -eq 1 ] && herr 'STORE_UNREADABLE: cannot open directory .*/dirs/src' && ok "N11 chmod 000 dirs/src: enforcement-mode claim exits 1 (STORE_UNREADABLE), not empty" || { why; bad "N11 claim unreadable"; }
  r "$P" "$C" check alice . src/deep/d.c
  [ $RC -eq 1 ] && herr "Permission denied" && ok "N11 check through the unreadable directory: exit 1" || { why; bad "N11 check unreadable"; }
  r "$P" env CRUMB_REPO_ID=acme/perm "$C" sniff alice .
  [ $RC -eq 1 ] && ok "N11 sniff in enforcement mode: exit 1" || { why; bad "N11 sniff unreadable"; }
  git -C "$P" config crumb.enforce false
  r "$P" "$C" sniff alice .
  [ $RC -eq 0 ] && herr 'warning: cannot open directory .*/dirs/src' && ok "N11 outside enforcement: the same failure is a stderr warning, never silent" || { why; bad "N11 normal-mode warning"; }
  chmod 755 "$NS/dirs/src"; git -C "$P" config crumb.enforce true
fi

# ---- N12 store identity and hostile files: exit 3 / exit 4 for check ----
r "$T/one" env CRUMB_EXPECT_STORE_ID=0123456789abcdef0123456789abcdef "$C" check alice . src/a.c
[ $RC -eq 3 ] && herr STORE_ID_MISMATCH && ok "N12 STORE_ID mismatch: check exit 3" || { why; bad "N12 mismatch check"; }
r "$T/one" env CRUMB_EXPECT_STORE_ID=0123456789abcdef0123456789abcdef "$C" claim zed . src/z.c x
[ $RC -eq 3 ] && ok "N12 STORE_ID mismatch: claim exit 3" || { why; bad "N12 mismatch claim"; }
H="$T/host"; mkrepo "$H" https://github.com/acme/host.git; enroll "$H" "$ROOT"
r "$H" "$C" claim alice . src/a.c x 600; rm -f "$ROOT/repos/acme/host/dirs/src.json"; mkfifo "$ROOT/repos/acme/host/dirs/src.json"
r "$H" "$C" check alice . src/a.c
[ $RC -eq 4 ] && herr 'REFUSED_RECORD: .*src.json is a fifo' && ok "N12 FIFO planted as a record: check exit 4, no hang" || { why; bad "N12 fifo check"; }
rm -f "$ROOT/repos/acme/host/dirs/src.json"
U="$T/unreg-root"; mkrepo "$T/u" https://github.com/acme/u.git; git -C "$T/u" config crumb.coordinationRoot "$U"; (cd "$T/u" && "$C" store-init . >/dev/null 2>&1)
r "$T/u" env CRUMB_ENFORCE=1 "$C" check alice . src/a.c
[ $RC -eq 3 ] && herr STORE_UNREGISTERED && ok "N12 enforcement refuses an unregistered store (exit 3)" || { why; bad "N12 unregistered"; }
printf 'crumb-coord-layout/9\n' > "$T/bad-layout"; mkdir -p "$T/bl"; cp "$T/bad-layout" "$T/bl/LAYOUT"
r "$T/u" env CRUMB_COORD_ROOT="$T/bl" "$C" check alice . src/a.c
[ $RC -eq 3 ] && herr STORE_LAYOUT_UNSUPPORTED && ok "N12 unknown LAYOUT content: exit 3, never rewritten" || { why; bad "N12 bad layout"; }
mkdir -p "$ROOT/dirs"; echo '{}' > "$ROOT/dirs/stray.json"
r "$T/one" "$C" check alice . src/a.c
[ $RC -eq 3 ] && herr STORE_LAYOUT_MIXED && ok "N12 flat records written into a layout-2 root by an older tool: enforcement exit 3" || { why; bad "N12 mixed"; }
rm -rf "$ROOT/dirs"

# ---- N13 legacy .crumb.local fallback refused in enforcement mode ----
mkdir -p "$T/plain"
r "$T/plain" env CRUMB_ENFORCE=1 "$C" claim alice "$T/plain" x.c x
[ $RC -eq 1 ] && herr ENFORCE_NO_REPOSITORY && [ ! -e "$T/plain/.crumb.local" ] && ok "N13 CRUMB_ENFORCE=1 outside git: exit 1, no .crumb.local written" || { why; bad "N13 env fallback"; }
r "$T/plain" "$C" --enforce sniff alice "$T/plain"
[ $RC -eq 1 ] && [ ! -e "$T/plain/.crumb.local" ] && ok "N13 --enforce outside git: exit 1" || { why; bad "N13 flag fallback"; }
r "$T/plain" "$C" claim alice "$T/plain" x.c x
[ $RC -eq 0 ] && [ -f "$T/plain/.crumb.local" ] && ok "N13 control: without enforcement the RFC-0001 fallback still works" || { why; bad "N13 control"; }

# ---- N14 layout 1 is never reinterpreted ----
V="$T/v1"; mkrepo "$V" https://github.com/acme/v1.git
r "$V" "$C" claim alice . src/a.c "flat lease" 600
r "$V" "$C" store-init .
[ $RC -eq 1 ] && herr STORE_LAYOUT_V1_DATA && [ ! -e "$V/.git/crumb/v1/LAYOUT" ] && ok "N14 store-init refuses a root with layout-1 records (exit 1), no LAYOUT written" || { why; bad "N14 store-init on v1"; }
r "$V" "$C" claim bob . src/a.c x
[ $RC -eq 2 ] && ok "N14 the layout-1 lease still blocks after the refused init" || { why; bad "N14 v1 lease lost"; }
VID=$(cd "$V" && "$C" store-id . 2>/dev/null)
r "$V" env CRUMB_ENFORCE=1 CRUMB_EXPECT_STORE_ID="$VID" "$C" check alice . src/a.c
[ $RC -eq 3 ] && herr STORE_LAYOUT_V1 && ok "N14 enforcement refuses a layout-1 store (exit 3)" || { why; bad "N14 enforce on v1"; }
r "$V" env CRUMB_ENFORCE=1 CRUMB_EXPECT_STORE_ID="$VID" "$C" claim alice . src/b.c x
[ $RC -eq 3 ] && ok "N14 enforcement: claim on layout 1 exit 3" || { why; bad "N14 enforce claim v1"; }

# ---- N15 repository id rules ----
r "$T/u" env CRUMB_REPO_ID=a/b/c "$C" claim alice . src/a.c x
[ $RC -eq 3 ] && herr REPO_ID_INVALID && ok "N15 CRUMB_REPO_ID with three components refused (exit 3)" || { why; bad "N15 three components"; }
r "$T/u" env CRUMB_REPO_ID=acme/dirs "$C" claim alice . src/a.c x
[ $RC -eq 3 ] && herr REPO_ID_INVALID && ok "N15 a record directory name as second component refused (no nested namespaces)" || { why; bad "N15 reserved component"; }
mkrepo "$T/noorigin" -; git -C "$T/noorigin" config crumb.coordinationRoot "$U"
r "$T/noorigin" "$C" claim alice . src/a.c x
[ $RC -eq 3 ] && herr REPO_ID_MISSING && [ ! -e "$U/repos/noorigin" ] && ok "N15 layout 2 without origin or crumb.repoId: REPO_ID_MISSING (exit 3), nothing derived from the path" || { why; bad "N15 missing repo id"; }
git -C "$T/noorigin" remote add origin "$T/origin.git"
r "$T/noorigin" "$C" claim alice . src/a.c x
[ $RC -eq 3 ] && herr REPO_ID_MISSING && ok "N15 a local-path origin is never used as an identity" || { why; bad "N15 path origin"; }
git -C "$T/noorigin" config crumb.repoId acme/explicit
r "$T/noorigin" "$C" claim alice . src/a.c x
[ $RC -eq 0 ] && [ -d "$U/repos/acme/explicit/dirs" ] && ok "N15 git config crumb.repoId names the namespace" || { why; bad "N15 config repo id"; }
r "$T/noorigin" env CRUMB_REPO_ID=acme/envwins "$C" claim alice . src/a.c x
[ $RC -eq 0 ] && [ -d "$U/repos/acme/envwins/dirs" ] && ok "N15 CRUMB_REPO_ID overrides git config crumb.repoId" || { why; bad "N15 env precedence"; }

# ---- N16 a relative override root is anchored at the worktree top-level, not the cwd ----
RL="$T/rel"; mkrepo "$RL" https://github.com/acme/rel.git
(cd "$RL" && CRUMB_COORD_ROOT=../relroot "$C" store-init . >/dev/null 2>&1)
r "$RL/src/deep" env CRUMB_COORD_ROOT=../relroot "$C" claim alice "$RL/src/deep" d.c "from a subdirectory" 600
r2=$RC; r "$RL" env CRUMB_COORD_ROOT=../relroot "$C" check alice . src/deep/d.c
[ $r2 -eq 0 ] && [ $RC -eq 0 ] && [ -f "$T/relroot/LAYOUT" ] && [ ! -e "$RL/src/relroot" ] && [ ! -e "$RL/relroot" ] && ok "N16 CRUMB_COORD_ROOT=../relroot means one store whatever the cwd" || { why; bad "N16 relative root"; }

# ---- N17 concurrent claims in enforcement mode: same key, and nested keys ----
i=1; while [ $i -le 8 ]; do ( cd "$T/one" && CRUMB_REPO_ID=acme/race1 "$C" claim "r$i" . src/b.c race 600 >/dev/null 2>&1; echo $? > "$T/rr.$i" ) & i=$((i + 1)); done; wait
w=$(cat "$T"/rr.[1-8] | grep -c '^0$'); b=$(cat "$T"/rr.[1-8] | grep -c '^2$')
[ "$w" -eq 1 ] && [ "$b" -eq 7 ] && ok "N17 8 concurrent claims of one key: exactly 1 exit 0, 7 exit 2" || bad "N17 race (wins=$w blocked=$b)"
i=1; while [ $i -le 8 ]; do k=src; [ $((i % 2)) -eq 0 ] && k=src/a.c; ( cd "$T/one" && CRUMB_REPO_ID=acme/race2 "$C" claim "n$i" . "$k" race 600 >/dev/null 2>&1; echo $? > "$T/rn.$i" ) & i=$((i + 1)); done; wait
w=$(cat "$T"/rn.[1-8] | grep -c '^0$'); b=$(cat "$T"/rn.[1-8] | grep -c '^2$')
[ "$w" -eq 1 ] && [ "$b" -eq 7 ] && ok "N17 8 concurrent claims of src and src/a.c (overlapping keys): exactly 1 exit 0" || bad "N17 nested race (wins=$w blocked=$b)"

# ---- N18 key-qualified fencing token (trace found by the Lean model, evidence/proof-lean obs_number_only_check_accepts) ----
# Generations count per key, so a bare number can match a different covering lease: alice holds src/a.c at
# generation 1, it expires, bob takes it (2), that expires, alice claims the ancestor src (its own generation 1).
# check alice src/a.c --generation 1 is then HELD through src; --key src/a.c --generation 1 must be REFUSED.
K="$T/keytok"; mkrepo "$K" https://github.com/acme/keytok.git; enroll "$K" "$ROOT"
r "$K" env CRUMB_TEST_NOW=$NOW "$C" claim alice . src/a.c first 100
r "$K" env CRUMB_TEST_NOW=$((NOW + 101)) "$C" claim bob . src/a.c second 100; gb=$(gen)
r "$K" env CRUMB_TEST_NOW=$((NOW + 202)) "$C" claim alice . src third 100; ga=$(gen)
[ "$gb" = 2 ] && [ "$ga" = 1 ] && ok "N18 trace: bob re-acquires src/a.c (generation 2), alice then claims src (generation 1)" || { why; bad "N18 trace ($gb $ga)"; }
r "$K" env CRUMB_TEST_NOW=$((NOW + 210)) "$C" check alice . src/a.c --generation 1
[ $RC -eq 0 ] && has '^HELD src/a.c by alice key src generation 1 ' && ok "N18 a bare --generation 1 is satisfied by the ancestor lease (why a token must name its key)" || { why; bad "N18 bare number"; }
r "$K" env CRUMB_TEST_NOW=$((NOW + 210)) "$C" check alice . src/a.c --key src/a.c --generation 1
[ $RC -eq 2 ] && has '^REFUSED key src!=src/a.c src/a.c generation 1 by alice ' && ok "N18 --key src/a.c --generation 1 (the stale token): REFUSED key (exit 2)" || { why; bad "N18 keyed stale token"; }
r "$K" env CRUMB_TEST_NOW=$((NOW + 210)) "$C" check alice . src/a.c --generation 1 --key src
[ $RC -eq 0 ] && ok "N18 the current token (--key src --generation 1, either order) is HELD (exit 0)" || { why; bad "N18 keyed current token"; }
r "$K" "$C" check alice . src/a.c --key src --key src
[ $RC -eq 1 ] && ok "N18 a repeated --key is a usage error (exit 1)" || { why; bad "N18 repeated key"; }

echo "namespace/check/enforce: $( [ $fail -eq 0 ] && echo ALL PASS || echo FAILURES )"
exit $fail
