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

# ---- N19 a Hermes-style session identity (<agent-name>.<YYYYMMDD_HHMMSS_hex>, with `_`) is a valid verbatim id ----
HI="worker.20261106_173039_c44e6c"
r "$K" env CRUMB_TEST_NOW=$((NOW + 220)) CRUMB_SESSION="$HI" "$C" claim "$HI" . docs/h.md hermes 100
r2=$RC; r "$K" env CRUMB_TEST_NOW=$((NOW + 221)) "$C" check "$HI" . docs/h.md
[ $r2 -eq 0 ] && [ $RC -eq 0 ] && has "^HELD docs/h.md by $HI key docs/h.md generation 1 " && ok "N19 Hermes session identity with '_' claims and checks verbatim in enforcement mode" || { why; bad "N19 underscore identity"; }

# ---- N20 (review B1) a symlinked directory inside the record tree: refused in enforcement mode, never skipped, never followed ----
SL="$T/symdesc"; mkrepo "$SL" https://github.com/acme/symdesc.git; enroll "$SL" "$ROOT"; NS="$ROOT/repos/acme/symdesc"
r "$SL" "$C" claim alice . src/deep/a.c deep 600
mv "$NS/dirs/src" "$T/hidden-src"; ln -s "$T/hidden-src" "$NS/dirs/src"; h0=$(sum "$T/hidden-src"); s0=$(sum "$NS")
r "$SL" "$C" claim bob . src ancestor 600
[ $RC -eq 4 ] && herr 'REFUSED_RECORD: .*/dirs/src is a symbolic link' && [ "$(sum "$NS")" = "$s0" ] && ok "N20 ancestor claim over a symlinked descendant record directory: exit 4, not granted, store unchanged" || { why; bad "N20 symlinked descendant record directory skipped"; }
r "$SL" "$C" claim bob . . whole 600; c1=$RC; r "$SL" "$C" claim bob . other.c unrelated 600; c2=$RC
[ $c1 -eq 4 ] && [ $c2 -eq 4 ] && [ "$(sum "$NS")" = "$s0" ] && ok "N20 claims of . and of an unrelated key exit 4 too (the record walk never skips)" || bad "N20 other claims over the link ($c1 $c2)"
r "$SL" "$C" check bob . src
[ $RC -eq 2 ] && has '^REFUSED absent src ' && ok "N20 check bob src: REFUSED absent (no ancestor lease was granted)" || { why; bad "N20 check after the refused claim"; }
[ "$(sum "$T/hidden-src")" = "$h0" ] && [ -L "$NS/dirs/src" ] && ok "N20 the link is never followed: link and target left as found" || bad "N20 link followed or changed"
git -C "$SL" config crumb.enforce false
r "$SL" "$C" sniff alice .
[ $RC -eq 0 ] && herr 'warning: .*/dirs/src is a symbolic link; it is not walked' && ok "N20 outside enforcement the unwalked link is a stderr warning, never silent" || { why; bad "N20 normal-mode warning"; }
git -C "$SL" config crumb.enforce true; rm -f "$NS/dirs/src"; mv "$T/hidden-src" "$NS/dirs/src"

# ---- N21 (review B2) a top-level directory named _root never shares the repository root's record (layout 2) ----
RT="$T/rootname"; mkrepo "$RT" https://github.com/acme/rootname.git; enroll "$RT" "$ROOT"; NS="$ROOT/repos/acme/rootname"
r "$RT" env CRUMB_TEST_NOW=$NOW "$C" claim alice . _root/a.c under 600; a1=$RC; ga=$(gen)
r "$RT" env CRUMB_TEST_NOW=$NOW "$C" claim alice . README.md top 600; a2=$RC; gr=$(gen)
[ $a1 -eq 0 ] && [ $a2 -eq 0 ] && [ "$ga" = 1 ] && [ "$gr" = 1 ] && grep -q '"_root/a.c"' "$NS/dirs/__root.json" 2>/dev/null && ! grep -q '"_root/a.c"' "$NS/dirs/_root.json" && grep -q '"README.md"' "$NS/dirs/_root.json" && ok "N21 _root/a.c lives in dirs/__root.json, root-level README.md in dirs/_root.json (generation 1 each)" || { why; bad "N21 _root mapping"; }
r "$RT" env CRUMB_TEST_NOW=$((NOW + 1)) "$C" check alice . _root/a.c; c1=$RC; o1=$OUT
r "$RT" env CRUMB_TEST_NOW=$((NOW + 1)) "$C" check alice . README.md
[ $c1 -eq 0 ] && [ $RC -eq 0 ] && printf '%s\n' "$o1" | grep -q '^HELD _root/a.c by alice key _root/a.c generation 1 ' && has '^HELD README.md by alice key README.md generation 1 ' && ok "N21 check: _root/a.c and README.md both HELD" || { why; bad "N21 check"; }
r "$RT" env CRUMB_TEST_NOW=$((NOW + 2)) "$C" claim alice . _root/a.c renew 600; c1=$RC; g1=$(gen)
r "$RT" env CRUMB_TEST_NOW=$((NOW + 2)) "$C" claim alice . README.md renew 600; g2=$(gen)
[ $c1 -eq 0 ] && [ $RC -eq 0 ] && [ "$g1" = 1 ] && [ "$g2" = 1 ] && ok "N21 renewals of _root/a.c and README.md keep generation 1" || { why; bad "N21 renew ($g1 $g2)"; }
r "$RT" env CRUMB_TEST_NOW=$((NOW + 3)) "$C" claim bob . src/b.c unrelated 600; c1=$RC
r "$RT" env CRUMB_TEST_NOW=$((NOW + 3)) "$C" claim bob . other.c root-level 600
[ $c1 -eq 0 ] && [ $RC -eq 0 ] && ok "N21 unrelated claims (src/b.c, root-level other.c) still work" || { why; bad "N21 unrelated claims"; }
r "$RT" env CRUMB_TEST_NOW=$((NOW + 4)) "$C" claim bob . _root dir 600; c1=$RC; o1=$OUT
r "$RT" env CRUMB_TEST_NOW=$((NOW + 4)) "$C" check bob . _root/a.c
[ $c1 -eq 2 ] && printf '%s\n' "$o1" | grep -q 'overlapping lease on _root/a.c\]' && [ $RC -eq 2 ] && has '^REFUSED held-by alice _root/a.c key _root/a.c ' && ok "N21 bob: claim of _root BLOCKED by the descendant, check REFUSED held-by alice" || { why; bad "N21 overlap on _root"; }
r "$RT" env CRUMB_TEST_NOW=$((NOW + 5)) "$C" close alice . _root/a.c; c1=$RC
r "$RT" env CRUMB_TEST_NOW=$((NOW + 5)) "$C" close alice . README.md; c2=$RC
r "$RT" env CRUMB_TEST_NOW=$((NOW + 6)) "$C" claim bob . _root/a.c next 600
[ $c1 -eq 0 ] && [ $c2 -eq 0 ] && [ $RC -eq 0 ] && has 'generation 2$' && ok "N21 close of both, then bob takes _root/a.c at generation 2" || { why; bad "N21 close and re-acquire ($c1 $c2)"; }
r "$RT" env CRUMB_TEST_NOW=$((NOW + 7)) "$C" check bob . _root/a.c --key _root/a.c --generation 2
[ $RC -eq 0 ] && ok "N21 check of the new token (--key _root/a.c --generation 2): HELD" || { why; bad "N21 new token"; }
echo '{}' > "$NS/dirs/_old.json"; s0=$(sum "$NS")
r "$RT" "$C" claim carol . src/a.c x 600
[ $RC -eq 1 ] && herr 'MALFORMED_RECORD: .*dirs/_old.json is not a directory record name of layout 2' && [ "$(sum "$NS")" = "$s0" ] && ok "N21 a '_' record name no key maps to (old layout-2 mapping): enforcement exit 1, store unchanged" || { why; bad "N21 unmapped name"; }
rm -f "$NS/dirs/_old.json"; mkdir -p "$NS/dirs/_root"; echo '{}' > "$NS/dirs/_root/x.json"
r "$RT" "$C" claim carol . src/a.c x 600
[ $RC -eq 1 ] && herr 'dirs/_root/x.json is not a directory record name' && ok "N21 a dirs/_root/ subtree is never a key directory: exit 1" || { why; bad "N21 dirs/_root subtree"; }
rm -rf "$NS/dirs/_root"
L1="$T/rootname1"; mkrepo "$L1" -
r "$L1" "$C" claim alice . _root/a.c v1 600
[ $RC -eq 0 ] && grep -q '"_root/a.c"' "$L1/.git/crumb/v1/dirs/_root.json" && [ ! -e "$L1/.git/crumb/v1/dirs/__root.json" ] && ok "N21 control: layout 1 keeps its historical mapping (dirs/_root.json) byte for byte" || { why; bad "N21 layout 1 mapping changed"; }

# ---- N22 (review B3) a lease belongs to the session that took it: heartbeat expiry and malformed metadata never hand it over ----
SE="$T/sess"; mkrepo "$SE" https://github.com/acme/sess.git; enroll "$SE" "$ROOT"; NS="$ROOT/repos/acme/sess"
r "$SE" env CRUMB_TEST_NOW=$NOW CRUMB_SESSION=first "$C" claim worker . other.c long 600
r "$SE" env CRUMB_TEST_NOW=$NOW CRUMB_SESSION=first "$C" update worker . heartbeat 1; s0=$(sum "$NS")
r "$SE" env CRUMB_TEST_NOW=$((NOW + 2)) CRUMB_SESSION=second "$C" claim worker . other.c takeover 600
[ $RC -eq 2 ] && has '^BLOCKED agent worker is live in session first, not this session second \(live lease on other.c generation 1' && ok "N22 heartbeat expired, lease live: another session of the same id cannot renew it (exit 2)" || { why; bad "N22 session takeover after heartbeat expiry"; }
r "$SE" env CRUMB_TEST_NOW=$((NOW + 2)) CRUMB_SESSION=second "$C" close worker . other.c; c1=$RC
r "$SE" env CRUMB_TEST_NOW=$((NOW + 2)) CRUMB_SESSION=second "$C" update worker . mine 600; c2=$RC
r "$SE" env CRUMB_TEST_NOW=$((NOW + 2)) CRUMB_SESSION=second "$C" claim worker . src/new.c new 600; c3=$RC
[ $c1 -eq 2 ] && [ $c2 -eq 2 ] && [ $c3 -eq 2 ] && [ "$(sum "$NS")" = "$s0" ] && ok "N22 the other session's close, update and new claim: exit 2 each, store unchanged" || bad "N22 other session ($c1 $c2 $c3)"
r "$SE" env CRUMB_TEST_NOW=$((NOW + 3)) CRUMB_SESSION=first "$C" claim worker . other.c renew 600
[ $RC -eq 0 ] && has 'generation 1$' && ok "N22 the owning session renews its lease after its heartbeat expired (generation 1)" || { why; bad "N22 owner renew"; }
AR="$NS/agents/worker.json"; cp "$AR" "$T/agent-pristine.json"; n=0; tot=0
for f in '.session=42' 'del(.session)' '.session=""' '.updated_at="yesterday"' '.ttl_seconds=0' '.ttl_seconds="600"'; do
  tot=$((tot + 1)); jq "$f" "$T/agent-pristine.json" > "$AR"; s0=$(sum "$NS")
  r "$SE" env CRUMB_TEST_NOW=$((NOW + 4)) CRUMB_SESSION=second "$C" claim worker . other.c takeover 600; c1=$RC; e1=$ERR
  r "$SE" env CRUMB_TEST_NOW=$((NOW + 4)) CRUMB_SESSION=first "$C" claim worker . other.c renew 600; c2=$RC
  if [ $c1 -eq 1 ] && [ $c2 -eq 1 ] && printf '%s' "$e1" | grep -q 'MALFORMED_RECORD: .*agents/worker.json: agent record' && [ "$(sum "$NS")" = "$s0" ]; then n=$((n + 1)); else echo "    malformed agent $f: second=$c1 first=$c2 $e1"; fi
done
[ $n -eq $tot ] && ok "N22 $tot malformed agent-record variants (session 42/absent/empty, updated_at, ttl): exit 1 for every session, store unchanged" || bad "N22 malformed agent metadata ($n of $tot)"
cp "$T/agent-pristine.json" "$AR"; LR="$NS/dirs/_root.json"; cp "$LR" "$T/lease-pristine.json"
jq 'del(.locks["other.c"].session)' "$T/lease-pristine.json" > "$LR"
r "$SE" env CRUMB_TEST_NOW=$((NOW + 4)) "$C" check worker . other.c; c1=$RC; e1=$ERR
r "$SE" env CRUMB_TEST_NOW=$((NOW + 4)) CRUMB_SESSION=second "$C" claim worker . other.c takeover 600
[ $c1 -eq 1 ] && printf '%s' "$e1" | grep -q 'MALFORMED_LEASE: .*session is not a non-empty string' && [ $RC -eq 1 ] && ok "N22 a lease without its session: check and claim exit 1 (MALFORMED_LEASE)" || { why; bad "N22 sessionless lease"; }
cp "$T/lease-pristine.json" "$LR"

# ---- N23 (review B4) crumb check on an initialized store whose .lock is missing: exit 1, lock never created ----
NL="$T/nolock"; NLR="$T/nolock-root"; mkrepo "$NL" https://github.com/acme/nolock.git; enroll "$NL" "$NLR"
r "$NL" "$C" claim alice . src/a.c x 600; rm -f "$NLR/.lock"
r "$NL" "$C" check alice . src/a.c --key src/a.c --generation 1
[ $RC -eq 1 ] && herr 'STORE_LOCK_MISSING' && [ ! -e "$NLR/.lock" ] && ok "N23 enforced layout-2 store without .lock: check exit 1 (no HELD), lock not created" || { why; bad "N23 enforced missing lock"; }
git -C "$NL" config crumb.enforce false
r "$NL" "$C" check alice . src/a.c
[ $RC -eq 1 ] && herr 'STORE_LOCK_MISSING' && [ ! -e "$NLR/.lock" ] && ok "N23 the same layout-2 store outside enforcement: exit 1" || { why; bad "N23 layout-2 missing lock"; }
git -C "$NL" config crumb.enforce true
N1R="$T/nolock1"; mkrepo "$N1R" -
r "$N1R" "$C" claim alice . src/a.c x 600; rm -f "$N1R/.git/crumb/v1/.lock"
r "$N1R" "$C" check alice . src/a.c
[ $RC -eq 1 ] && herr 'STORE_LOCK_MISSING' && [ ! -e "$N1R/.git/crumb/v1/.lock" ] && ok "N23 a used layout-1 store without .lock: exit 1, lock not created" || { why; bad "N23 layout-1 missing lock"; }
N0R="$T/nolock0"; mkrepo "$N0R" -
r "$N0R" "$C" check alice . src/a.c
[ $RC -eq 2 ] && has '^REFUSED absent src/a.c' && [ ! -e "$N0R/.git/crumb" ] && ok "N23 control: a never-used compatibility store is still REFUSED absent (exit 2), nothing created" || { why; bad "N23 never-used store"; }

# ---- N24 (review B5) ttl: the writer accepts exactly what the strict reader accepts (1..315360000 in enforcement) ----
TT="$T/ttl"; mkrepo "$TT" https://github.com/acme/ttl.git; enroll "$TT" "$ROOT"; NS="$ROOT/repos/acme/ttl"
r "$TT" "$C" claim alice . src/a.c base 600; s0=$(sum "$NS"); n=0; tot=0
for v in 9223372036854775807 99999999999999999999999 2305843009213693952 315360001 -5 +5; do
  tot=$((tot + 1)); r "$TT" "$C" claim bob . src/b.c x "$v"
  if [ $RC -eq 1 ] && herr 'bad ttl' && [ "$(sum "$NS")" = "$s0" ]; then n=$((n + 1)); else echo "    ttl $v: rc=$RC $OUT"; fi
done
[ $n -eq $tot ] && ok "N24 $tot out-of-range or malformed ttls (LONG_MAX, overflow, LONG_MAX/4+1, 315360001, -5, +5): exit 1, store unchanged" || bad "N24 ttl range ($n of $tot)"
r "$TT" env CRUMB_TEST_NOW=$NOW "$C" claim bob . src/b.c max 315360000; c1=$RC
r "$TT" env CRUMB_TEST_NOW=$NOW "$C" check bob . src/b.c
[ $c1 -eq 0 ] && [ $RC -eq 0 ] && has 'expires 2037-01-12T08:00:00Z$' && ok "N24 ttl 315360000 (3650 days) is accepted and checks HELD, expires 2037-01-12T08:00:00Z" || { why; bad "N24 max ttl"; }
r "$TT" env CRUMB_TEST_NOW=$NOW "$C" claim carol . src/deep/d.c after 600
[ $RC -eq 0 ] && ok "N24 the namespace is not poisoned: an unrelated claim succeeds" || { why; bad "N24 poisoned"; }
s0=$(sum "$NS"); r "$TT" "$C" update carol . focus 0; c1=$RC; r "$TT" "$C" update carol . focus 315360001
[ $c1 -eq 1 ] && [ $RC -eq 1 ] && [ "$(sum "$NS")" = "$s0" ] && ok "N24 update with ttl 0 or 315360001 in enforcement: exit 1, store unchanged" || { why; bad "N24 update ttl ($c1)"; }
TL="$T/ttl1"; mkrepo "$TL" -
r "$TL" "$C" claim alice . src/a.c x 9223372036854775807
[ $RC -eq 1 ] && herr 'bad ttl' && [ ! -e "$TL/.git/crumb/v1/dirs/src.json" ] && ok "N24 layout 1 refuses an over-range ttl too (no record written)" || { why; bad "N24 layout-1 ttl"; }

# ---- N25 (review B6) the generations high-water mark never decreases ----
GW="$T/hwm"; mkrepo "$GW" https://github.com/acme/hwm.git; enroll "$GW" "$ROOT"; REC="$ROOT/repos/acme/hwm/dirs/src.json"
r "$GW" "$C" claim alice . src/a.c g 600; cp "$REC" "$T/hwm-pristine.json"
jq '.generations["src/a.c"]=10' "$T/hwm-pristine.json" > "$REC"; s0=$(cksum < "$REC")
r "$GW" "$C" claim alice . src/a.c renew 600; c1=$RC; e1=$ERR; r "$GW" "$C" check alice . src/a.c
[ $c1 -eq 1 ] && printf '%s' "$e1" | grep -q 'MALFORMED_LEASE: .*differs from the record.s generations counter' && [ $RC -eq 1 ] && [ "$(cksum < "$REC")" = "$s0" ] && ok "N25 enforcement: a live lease (generation 1) with counter 10: renewal and check exit 1, counter kept" || { why; bad "N25 enforced counter mismatch"; }
H1="$T/hwm1"; mkrepo "$H1" -; R1="$H1/.git/crumb/v1/dirs/src.json"
r "$H1" "$C" claim alice . src/a.c g 600; jq '.generations["src/a.c"]=10' "$R1" > "$T/r1.json" && cp "$T/r1.json" "$R1"
r "$H1" "$C" claim alice . src/a.c renew 600; g1=$(gen); c10=$(jq -r '.generations["src/a.c"]' "$R1")
r "$H1" "$C" close alice . src/a.c; r "$H1" "$C" claim bob . src/a.c next 600; g2=$(gen)
[ "$g1" = 1 ] && [ "$c10" = 10 ] && [ "$g2" = 11 ] && ok "N25 layout 1: renewal keeps generation 1 and counter 10; the next acquisition is 11, never a reused 2" || bad "N25 high-water mark lowered (renew $g1 counter $c10 next $g2)"
sed -e 's/"generation": 1$/"generation": 18446744073709551615/' -e 's/"src\/a.c": 1$/"src\/a.c": 18446744073709551615/' "$T/hwm-pristine.json" > "$REC"
r "$GW" "$C" claim alice . src/a.c renew 600
[ $RC -eq 0 ] && has 'generation 18446744073709551615$' && grep -q '"src/a.c": 18446744073709551615$' "$REC" && ok "N25 control: renewal at generation 2^64-1 keeps it" || { why; bad "N25 max renew"; }
r "$GW" "$C" close alice . src/a.c; s0=$(cksum < "$REC"); r "$GW" "$C" claim bob . src/a.c next 600
[ $RC -eq 1 ] && herr 'exhausted' && [ "$(cksum < "$REC")" = "$s0" ] && ok "N25 control: after 2^64-1 the counter is exhausted (exit 1), store unchanged, never wraps to 0 or 1" || { why; bad "N25 exhausted"; }

# ---- N26 (review N1) git config crumb.enforce uses git's boolean conversion ----
BO="$T/bool"; mkrepo "$BO" https://github.com/acme/bool.git; enroll "$BO" "$ROOT"; git -C "$BO" config --unset-all crumb.enforce
printf '[crumb]\n\tenforce\n' >> "$BO/.git/config"
r "$BO" "$C" claim alice . src/a.c x 0
[ $RC -eq 1 ] && herr 'enforcement mode needs a positive ttl' && ok "N26 a valueless crumb.enforce key is true (git --bool): ttl 0 refused" || { why; bad "N26 valueless key ignored"; }
git -C "$BO" config --unset-all crumb.enforce; git -C "$BO" config crumb.enforce maybe
r "$BO" "$C" claim alice . src/a.c x 600
[ $RC -eq 1 ] && herr 'crumb.enforce' && ok "N26 control: a non-boolean crumb.enforce is an error (exit 1), never absent" || { why; bad "N26 bad boolean"; }
git -C "$BO" config crumb.enforce yes; r "$BO" "$C" claim alice . src/a.c x 0; c1=$RC
git -C "$BO" config crumb.enforce off; r "$BO" "$C" claim alice . src/a.c x 0
[ $c1 -eq 1 ] && [ $RC -eq 0 ] && ok "N26 control: yes enforces, off does not" || { why; bad "N26 yes/off ($c1)"; }
git -C "$BO" config crumb.enforce true

# ---- N27 (review N2) a repository id must start with an alphanumeric character (no '/single' alias of 'single') ----
RI="$T/rid"; mkrepo "$RI" https://github.com/acme/rid.git; enroll "$RI" "$ROOT"
r "$RI" env CRUMB_REPO_ID=single "$C" claim alice . src/a.c x 600; n=0
for id in /single /acme/rid -single _single .single; do r "$RI" env CRUMB_REPO_ID="$id" "$C" check alice . src/a.c; [ $RC -eq 3 ] && herr REPO_ID_INVALID && n=$((n + 1)) || echo "    repo id $id: rc=$RC $OUT"; done
[ $n -eq 5 ] && ok "N27 repo ids /single, /acme/rid, -single, _single, .single: REPO_ID_INVALID (exit 3)" || bad "N27 leading non-alphanumeric repo id ($n of 5)"
git -C "$RI" config crumb.repoId /single; r "$RI" "$C" claim bob . src/b.c x 600; c1=$RC; git -C "$RI" config --unset crumb.repoId
r "$RI" env CRUMB_REPO_ID=single "$C" check alice . src/a.c
[ $c1 -eq 3 ] && [ $RC -eq 0 ] && ok "N27 git config crumb.repoId /single refused (exit 3); control: CRUMB_REPO_ID=single still HELD" || { why; bad "N27 config repo id ($c1)"; }

# ---- N28 (review B7) a repository-discovery failure is an error, never "outside git" (no .crumb.local fallback) ----
# every coordination command in a repository whose .git/config git cannot read: exit 1 GIT_DISCOVERY_FAILED, nothing written
disc_all() {   # disc_all <repo> <label> [env...]: n = commands refused with exit 1 GIT_DISCOVERY_FAILED and no .crumb.local
  dr=$1; dl=$2; shift 2; n=0
  for cmd in "claim bob . src/a.c takeover 600" "update bob . focus 600" "whisper bob . - finding" "close alice . src/a.c modify msg" "check alice . src/a.c" "sniff bob ." "list ."; do
    # shellcheck disable=SC2086
    r "$dr" env "$@" "$C" $cmd
    [ $RC -eq 1 ] && herr '^crumb: GIT_DISCOVERY_FAILED' && [ ! -e "$dr/.crumb.local" ] && n=$((n + 1)) || { echo "    $dl: $cmd"; why; }
  done
}
DB="$T/disc"; mkrepo "$DB" https://github.com/acme/disc.git; enroll "$DB" "$ROOT"
r "$DB" "$C" claim alice . src/a.c live 600
[ $RC -eq 0 ] && has 'generation 1$' && ok "N28 setup: alice holds src/a.c in a repository enforced only by git config" || { why; bad "N28 setup"; }
cp "$DB/.git/config" "$T/disc-config"; s0=$(sum "$ROOT")
printf '[broken\n' >> "$DB/.git/config"
disc_all "$DB" malformed CRUMB_X=0
[ $n -eq 7 ] && [ "$(sum "$ROOT")" = "$s0" ] && ok "N28 malformed .git/config: claim/update/whisper/close/check/sniff/list exit 1 GIT_DISCOVERY_FAILED, no .crumb.local, shared store byte-identical" || bad "N28 malformed config ($n of 7)"
disc_all "$DB" malformed-env CRUMB_ENFORCE=1
[ $n -eq 7 ] && [ "$(sum "$ROOT")" = "$s0" ] && ok "N28 malformed .git/config with CRUMB_ENFORCE=1: the same refusal (a discovery error, not ENFORCE_NO_REPOSITORY)" || bad "N28 malformed config, env enforce ($n of 7)"
cp "$T/disc-config" "$DB/.git/config"
r "$DB" "$C" check alice . src/a.c
[ $RC -eq 0 ] && has '^HELD src/a.c by alice key src/a.c generation 1 ' && ! herr 'crumb.local' && ok "N28 control: config restored, alice's shared-store lease is intact (HELD generation 1, no stray .crumb.local)" || { why; bad "N28 restored"; }
if [ "$(id -u)" = 0 ]; then
  echo "NOT_RUN N28 unreadable .git/config (running as root: chmod 000 does not deny root)"
else
  chmod 000 "$DB/.git/config"; s0=$(sum "$ROOT")
  disc_all "$DB" unreadable CRUMB_X=0; chmod 644 "$DB/.git/config"
  [ $n -eq 7 ] && [ "$(sum "$ROOT")" = "$s0" ] && ok "N28 unreadable .git/config (chmod 000): all seven commands exit 1 GIT_DISCOVERY_FAILED, no .crumb.local, shared store byte-identical" || bad "N28 unreadable config ($n of 7)"
fi
PB="$T/disc-plain"; mkrepo "$PB" -; printf '[broken\n' >> "$PB/.git/config"
r "$PB" "$C" claim alice . src/a.c x 600
[ $RC -eq 1 ] && herr GIT_DISCOVERY_FAILED && [ ! -e "$PB/.crumb.local" ] && [ ! -e "$PB/.git/crumb" ] && ok "N28 malformed .git/config in a repository with no crumb configuration: exit 1, no .crumb.local, no store created (every mode)" || { why; bad "N28 plain malformed"; }
GF="$T/disc-gitfile"; mkdir -p "$GF"; echo "gitdir: $T/nowhere" > "$GF/.git"
r "$GF" "$C" claim alice . x.c x 600
[ $RC -eq 1 ] && herr GIT_DISCOVERY_FAILED && [ ! -e "$GF/.crumb.local" ] && ok "N28 a .git file naming no repository: exit 1 GIT_DISCOVERY_FAILED, no .crumb.local" || { why; bad "N28 dangling gitdir"; }
r "$DB/.git" "$C" claim alice . x.c x 600
[ $RC -eq 1 ] && herr GIT_DISCOVERY_FAILED && [ ! -e "$DB/.git/.crumb.local" ] && ok "N28 inside .git (no work tree): exit 1 GIT_DISCOVERY_FAILED, no .crumb.local written into .git" || { why; bad "N28 inside .git"; }
NR="$T/disc-norepo"; mkdir -p "$NR"
r "$NR" "$C" claim alice . x.c x 600
[ $RC -eq 0 ] && [ -f "$NR/.crumb.local" ] && ! herr GIT_DISCOVERY_FAILED && ok "N28 compatibility control: a genuine non-repository directory still takes the RFC-0001 .crumb.local fallback" || { why; bad "N28 non-repo control"; }
mkdir -p "$DB/ceil"; r "$DB/ceil" env GIT_CEILING_DIRECTORIES="$DB" "$C" claim alice . x.c x 600
[ $RC -eq 0 ] && [ -f "$DB/ceil/.crumb.local" ] && ok "N28 compatibility control: git's own discovery ends at GIT_CEILING_DIRECTORIES (\"not a git repository\"): fallback, despite a .git above" || { why; bad "N28 ceiling control"; }
rm -f "$DB/ceil/.crumb.local"; rmdir "$DB/ceil"
# re-review of B7: diagnostic text inside a file name or GIT_DIR must not count as "outside any repository"
DN="$T/disc-name"; mkrepo "$DN" -; git -C "$DN" config crumb.repoId acme/discname; enroll "$DN" "$ROOT"
r "$DN" "$C" claim alice . src/a.c first 600
INC="$T/not a git repository (or any"; printf '[core]\n' > "$INC"; git -C "$DN" config include.path "$INC"
r "$DN" "$C" check alice . src/a.c; r1=$RC
printf '[broken\n' > "$INC"; s0=$(sum "$ROOT")
r "$DN" "$C" claim bob . src/a.c takeover 600
[ $r1 -eq 0 ] && [ $RC -eq 1 ] && herr GIT_DISCOVERY_FAILED && [ ! -e "$DN/.crumb.local" ] && [ "$(sum "$ROOT")" = "$s0" ] && ok "N28 a malformed included config whose file name contains git's non-repository words: exit 1 GIT_DISCOVERY_FAILED, no .crumb.local, store unchanged" || { why; bad "N28 diagnostic in a file name"; }
printf '[core]\n' > "$INC"
r "$DN" "$C" check alice . src/a.c --key src/a.c --generation 1
[ $RC -eq 0 ] && ok "N28 control: include restored, alice still HELD at generation 1" || { why; bad "N28 include restored"; }
r "$NR" env GIT_DIR="$T/not a git repository (or any of the parent directories)" "$C" claim bob . z.c z 600
[ $RC -eq 1 ] && herr GIT_DISCOVERY_FAILED && [ ! -e "$NR/z.c" ] && ok "N28 an explicit GIT_DIR naming nothing (with the diagnostic words in its name): exit 1 GIT_DISCOVERY_FAILED" || { why; bad "N28 GIT_DIR words"; }
r "$NR" env CRUMB_ENFORCE=1 "$C" claim bob . y.c y 600
[ $RC -eq 1 ] && herr ENFORCE_NO_REPOSITORY && ok "N28 control: a genuine non-repository under enforcement is still ENFORCE_NO_REPOSITORY" || { why; bad "N28 non-repo enforced"; }

echo "namespace/check/enforce: $( [ $fail -eq 0 ] && echo ALL PASS || echo FAILURES )"
exit $fail
