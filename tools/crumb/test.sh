#!/bin/sh
# crumb self-test. usage: sh test.sh ./crumb. Uses a scratch dir only.
C=${1:-./crumb}; C=$(cd "$(dirname "$C")" && pwd)/$(basename "$C")
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail=0; ok() { echo "PASS $1"; }; bad() { echo "FAIL $1"; fail=1; }
mkdir -p "$T/r/src/deep" "$T/r/docs" "$T/r/old"; cd "$T/r" || exit 1
git init -q . 2>/dev/null; echo 'int main(void){return 0;}' > src/a.c; echo x > docs/n.md; echo y > src/deep/b.h
echo '{"version":1,"dir_path":"x","history":[]}' > old/.crumb; echo z > old/f.c

"$C" seed . >/dev/null; "$C" seed . | grep -q 'created 0, updated 0' && ok "seed idempotent" || bad "seed idempotent"
grep -q '^.crumb.local$' .gitignore && ok "gitignore has .crumb.local" || bad "gitignore"
grep -q 'version' old/.crumb && ! grep -q schema_version old/.crumb && ok "legacy .crumb untouched" || bad "legacy"
"$C" validate . | grep -q 'INVALID' && bad "validate" || ok "validate"
sed -i 's|"purpose": "Directory src. Purpose not yet described by a human."|"purpose": "Hand written C sources", "invariants": ["no globals"]|' src/.crumb
"$C" seed . >/dev/null; grep -q 'Hand written C sources' src/.crumb && grep -q 'no globals' src/.crumb && ok "hand edits survive reseed" || bad "hand edits"
echo w > src/new.c; "$C" seed . | grep -q 'updated 1' && grep -q new.c src/.crumb && ok "reseed picks up new file" || bad "reseed update"

"$C" claim laneA src src/a.c "refactor a" 600 | grep -q CLAIMED && ok claim || bad claim
"$C" claim laneB src src/a.c "also a" >/dev/null; [ $? -eq 2 ] && ok "second claim blocked (exit 2)" || bad "block"
"$C" claim laneB src src/b.c "other file" | grep -q CLAIMED && ok "claim different target" || bad "claim2"
"$C" update laneA src "still on a.c" | grep -q SCENT && ok update || bad update
"$C" whisper laneA src laneB "a.c done soon" high src/a.c | grep -q WHISPER && ok whisper || bad whisper
"$C" sniff laneB src | grep -q 'whisper laneA -> laneB' && ok "sniff sees whisper" || bad sniff
"$C" sniff laneB src | grep -q 'invariant: no globals' && ok "sniff shows invariants" || bad "sniff inv"
"$C" list . | grep -q 'lock .*src/a.c' && ok list || bad list
"$C" close laneB src src/a.c >/dev/null; [ $? -eq 2 ] && ok "close by non-holder refused" || bad "close refuse"
"$C" close laneA src src/a.c modify "done, ready" | grep -q CLOSED && ok close || bad close
"$C" list . | grep -q 'src/a.c' && bad "lock released" || ok "lock released"
grep -q '"history"' .git/crumb/v1/dirs/src.json && grep -q '"action": "modify"' .git/crumb/v1/dirs/src.json && [ ! -e src/.crumb.local ] && ok "history vector written" || bad history
# expiry sweep
"$C" claim laneC src src/c.c "short" 1 >/dev/null; sleep 2; "$C" claim laneD src src/c.c "takes over" | grep -q CLAIMED && ok "expired lock swept" || bad sweep
echo '{broken' > docs/.crumb.local; "$C" sniff x docs >/dev/null 2>&1; [ $? -ne 0 ] && ok "bad local refused" || bad "bad local"

# ---- RFC-0002 common coordination plane: two real linked worktrees ----
cd "$T" || exit 1
mkdir rc && cd rc && git init -q -b main . && mkdir src && echo a > src/runtime.c && echo b > src/other.c && echo c > src/legacy.c
git add -A && git -c user.name=t -c user.email=t@t commit -qm init
git worktree add -q -b A "$T/wa" && git worktree add -q -b B "$T/wb"
STORE=$(cd "$T/rc" && cd "$(git rev-parse --git-common-dir)" && pwd)/crumb/v1
# T1 cross-worktree visibility
(cd "$T/wa" && "$C" claim agent-a src runtime.c "rewrite runtime" | grep -q CLAIMED) && ok "T1 claim in worktree A" || bad "T1 claim A"
out=$(cd "$T/wb" && "$C" sniff agent-b src)
echo "$out" | grep -q 'shared coordination: ACTIVE' && echo "$out" | grep -q "held by agent-a \[A\]" && echo "$out" | grep -q 'src/runtime.c' && ok "T1 B sniff sees A's claim (branch A)" || bad "T1 visibility"
echo "$out" | grep -q 'CONFLICT: src/runtime.c' && ok "T1 sniff OTHER WORKTREES reports conflict" || bad "T1 other worktrees"
[ -f "$STORE/dirs/src.json" ] && [ ! -e "$T/wa/src/.crumb.local" ] && ok "T1 state lives in common store, no .crumb.local written" || bad "T1 store"
# T2 conflict, deterministic
(cd "$T/wb" && "$C" claim agent-b src runtime.c "also" >/dev/null); [ $? -eq 2 ] && ok "T2 B claim refused (exit 2)" || bad "T2 refuse"
(cd "$T/wb" && "$C" claim agent-b . src/runtime.c "also, repo-relative form" >/dev/null); [ $? -eq 2 ] && ok "T2 refused via repo-relative form" || bad "T2 refuse2"
(cd "$T/wa" && "$C" whisper agent-a src agent-b "runtime half done" high | grep -q WHISPER) && (cd "$T/wb" && "$C" sniff agent-b src | grep -q 'whisper agent-a -> agent-b') && ok "T2 whisper crosses worktrees" || bad "T2 whisper"
# T3 release
(cd "$T/wb" && "$C" close agent-b src runtime.c >/dev/null); [ $? -eq 2 ] && ok "T3 non-holder close refused" || bad "T3 nonholder"
(cd "$T/wa" && "$C" close agent-a src runtime.c modify "done" | grep -q CLOSED) && ok "T3 A closes" || bad "T3 close"
(cd "$T/wb" && "$C" claim agent-b src runtime.c "my turn" | grep -q CLAIMED) && ok "T3 B claim succeeds after release" || bad "T3 claim"
(cd "$T/wb" && "$C" close agent-b src runtime.c >/dev/null)
# T4 independent targets
(cd "$T/wa" && "$C" claim agent-a src one.c "one" >/dev/null) && (cd "$T/wb" && "$C" claim agent-b src two.c "two" >/dev/null) && \
  out=$(cd "$T/wa" && "$C" sniff agent-a src) && echo "$out" | grep -q 'src/one.c' && echo "$out" | grep -q 'src/two.c' && ok "T4 independent targets both survive" || bad "T4 independent"
(cd "$T/wa" && "$C" close agent-a src one.c >/dev/null); (cd "$T/wb" && "$C" close agent-b src two.c >/dev/null)
# T5 concurrent mutation: 8 different targets, then 8 agents on one target
i=1; while [ $i -le 8 ]; do ( cd "$T/w$( [ $((i%2)) -eq 0 ] && echo b || echo a )" && "$C" claim "cagent$i" src "c$i.c" "par" >/dev/null ) & i=$((i+1)); done; wait
n=$(cd "$T/wa" && "$C" sniff x src | grep -c '^  lock .*src/c[1-8].c')
[ "$n" -eq 8 ] && ok "T5 8 concurrent claims on 8 targets: 8 locks survive" || bad "T5 lost updates ($n of 8)"
i=1; while [ $i -le 8 ]; do ( cd "$T/w$( [ $((i%2)) -eq 0 ] && echo b || echo a )" && "$C" claim "sagent$i" src same.c "race" >/dev/null; echo $? > "$T/rc$i" ) & i=$((i+1)); done; wait
w=$(cat "$T"/rc[1-8] | grep -c '^0$'); b=$(cat "$T"/rc[1-8] | grep -c '^2$')
[ "$w" -eq 1 ] && [ "$b" -eq 7 ] && ok "T5 8 racers on one target: exactly 1 wins, 7 exit 2" || bad "T5 race (wins=$w blocked=$b)"
nl=$(cd "$T/wa" && "$C" sniff x src | grep -c '^  lock .*src/same.c'); [ "$nl" -eq 1 ] && ok "T5 exactly one lock record for raced target" || bad "T5 lock count"
# T6 TTL / crash recovery: holder never closes
(cd "$T/wa" && "$C" claim dead-agent src ttl.c "crashes" 1 >/dev/null); sleep 2
(cd "$T/wb" && "$C" claim live-agent src ttl.c "takes over" | grep -q CLAIMED) && ok "T6 expired lock pruned, other worktree claims" || bad "T6 ttl"
(cd "$T/wb" && "$C" sniff x src | grep -q 'lock .*ttl.c.*held by dead-agent') && bad "T6 dead lock still listed" || ok "T6 dead agent's lock gone from sniff"
# T7 path normalization: two absolute worktree paths of the same file are one lock
(cd "$T/wa" && "$C" claim agent-a . "$T/wa/src/abs.c" "abs" | grep -q 'CLAIMED src/abs.c') && ok "T7 absolute path in A normalised to src/abs.c" || bad "T7 abs A"
(cd "$T/wb" && "$C" claim agent-b src "$T/wb/src/abs.c" "abs b" >/dev/null); [ $? -eq 2 ] && ok "T7 same file via B's absolute path is the same lock" || bad "T7 abs B"
(cd "$T/wb" && "$C" claim agent-b src ../src/./abs.c "dots" >/dev/null); [ $? -eq 2 ] && ok "T7 ../ and ./ collapse to the same lock" || bad "T7 dots"
(cd "$T/wb" && "$C" claim agent-b . "$T/wa/elsewhere.c" "x" >/dev/null 2>&1); [ $? -eq 1 ] && ok "T7 path outside this worktree refused" || bad "T7 outside"
# agent identity is never a PID alone
grep -q '"session": "agent-a@' "$STORE/agents/agent-a.json" && ok "agent record carries session id (agent@host), not a PID" || bad "agent session id"
(cd "$T/wa" && CRUMB_SESSION=sess-123 "$C" update agent-a src "pinned session" >/dev/null) && grep -q '"session": "sess-123"' "$STORE/agents/agent-a.json" && ok "CRUMB_SESSION overrides session id" || bad "CRUMB_SESSION"
# T8 legacy .crumb.local: read, import once with provenance, never overridden, file kept
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
(cd "$T/wb" && "$C" claim agent-new src legacy2.c "fresh shared" >/dev/null)
cat > "$T/wa/src/.crumb.local" <<JSON
{"schema_version":"1.0.0","directory":"x","active_scents":{"old-agent":{"focus":"legacy work","updated_at":"$NOW","ttl_seconds":600}},
 "locks":{"src/legacy.c":{"holder":"old-agent","intent":"legacy lock","acquired_at":"$NOW","ttl_seconds":600},
          "src/legacy2.c":{"holder":"old-agent","intent":"stale view","acquired_at":"$NOW","ttl_seconds":600}},
 "whispers":[{"from":"old-agent","message":"legacy note","timestamp":"$NOW"}]}
JSON
(cd "$T/wa" && "$C" sniff agent-a src | grep -q 'held by old-agent.*imported from') && ok "T8 sniff reads legacy .crumb.local (in memory)" || bad "T8 legacy read"
[ ! -e "$STORE/agents/old-agent.json" ] && ok "T8 sniff does not write the store" || bad "T8 sniff wrote"
(cd "$T/wa" && "$C" update agent-a src "trigger import" >/dev/null)
out=$(cd "$T/wb" && "$C" sniff agent-b src)
echo "$out" | grep -q "src/legacy.c.*held by old-agent.*imported from $T/wa" && ok "T8 legacy lock imported with provenance (worktree path)" || bad "T8 import"
echo "$out" | grep -q 'src/legacy2.c.*held by agent-new' && ok "T8 legacy never overrides newer shared lock" || bad "T8 override"
echo "$out" | grep -q 'whisper old-agent' && ok "T8 legacy whisper imported" || bad "T8 whisper"
(cd "$T/wb" && "$C" claim agent-b src legacy.c "x" >/dev/null); [ $? -eq 2 ] && ok "T8 imported lock blocks other worktree" || bad "T8 block"
[ -f "$T/wa/src/.crumb.local" ] && ok "T8 legacy file left in place" || bad "T8 file kept"
n1=$(grep -c old-agent "$STORE/dirs/src.json"); (cd "$T/wa" && "$C" update agent-a src "again" >/dev/null); n2=$(grep -c old-agent "$STORE/dirs/src.json")
[ "$n1" -eq "$n2" ] && ok "T8 import is one-time (no duplicates)" || bad "T8 duplicates"
# outside any git repo: legacy behaviour kept, sniff says so
mkdir -p "$T/plain" && "$C" claim p1 "$T/plain" x.c "plain" | grep -q CLAIMED && [ -f "$T/plain/.crumb.local" ] && "$C" sniff p1 "$T/plain" | grep -q 'shared coordination: none (not a git repository)' && ok "non-git dir keeps .crumb.local, sniff reports none" || bad "non-git"
cd "$T/r" || exit 1
# backfill: known commit with a PR number lands in the right dir with the right sha; second run changes nothing
git add -A >/dev/null 2>&1; git -c user.name=t -c user.email=t@t commit -qm "feat: add b (#7)" >/dev/null 2>&1
sha=$(git rev-parse --short=7 HEAD)
HOME="$T/home" "$C" backfill . >/dev/null
grep -q '"pr": 7' src/.crumb && grep -q "\"sha\": \"$sha\"" src/.crumb && grep -q backfill-git src/.crumb && ok "backfill: PR 7 + sha in src/.crumb" || bad "backfill entry"
grep -q "$sha #7" docs/crumbs/BACKFILL.md && ok "BACKFILL.md lists commit" || bad "BACKFILL.md"
HOME="$T/home" "$C" backfill . | grep -q 'updated 0' && HOME="$T/home" "$C" backfill . | grep -q 'BACKFILL.md: unchanged' && ok "backfill idempotent" || bad "backfill idempotent"
# ---- RFC-0002 section 7: crumb explain ----
cd "$T/r" || exit 1
ex=$("$C" explain src)
for h in 'NEAREST CRUMB' 'INHERITED INVARIANTS' 'SHARED COORDINATION' 'RECENT COMMITS' 'EVIDENCE REFERENCES' 'NEWEST CONTINUATION'; do
  echo "$ex" | grep -q "^== $h ==" && ok "explain prints section: $h" || bad "explain section: $h"
done
echo "$ex" | grep -q 'purpose: Hand written C sources' && echo "$ex" | grep -q 'invariant: no globals' && ok "explain shows nearest .crumb purpose + invariants" || bad "explain nearest"
echo "$ex" | grep -q 'feat: add b (#7)' && ok "explain lists commits touching the path" || bad "explain commits"
"$C" explain src/a.c | grep -q 'repository path: src/a.c' && ok "explain accepts a file" || bad "explain file"
# The path is tracked repository data, not a shell command. A quoted Git argument
# must preserve the apostrophe and metacharacters without touching the marker.
evil="src/quote'; touch EXPLAIN_INJECTED; echo '"
printf 'test\n' > "$evil"
git add -- "$evil" && git -c user.name=t -c user.email=t@t commit -qm "explain hostile pathname"
ex=$("$C" explain "$evil")
echo "$ex" | grep -q 'explain hostile pathname' && [ ! -e EXPLAIN_INJECTED ] && ok "explain quotes hostile tracked pathname" || bad "explain shell injection or missing commit"
plain=$("$C" explain src/a.c)
echo "$plain" | grep -q 'repository path: src/a.c' && [ ! -e EXPLAIN_INJECTED ] && ok "explain ordinary pathname control" || bad "explain ordinary pathname control"
echo "$ex" | grep -q '(none touches this path)' && ok "explain: no continuation yet" || bad "explain none"
echo '{"version":1,"dir_path":"x","history":[]}' > /dev/null
"$C" claim agent-x src a.c "explain test" >/dev/null; "$C" whisper agent-x src - "explain whisper" >/dev/null
ex=$("$C" explain src); echo "$ex" | grep -q 'held by agent-x' && echo "$ex" | grep -q 'whisper agent-x -> all: explain whisper' && ok "explain shows shared locks + whispers" || bad "explain coordination"
STORE=$(git rev-parse --absolute-git-dir)/crumb/v1; mkdir -p "$STORE/continuations"
cat > "$STORE/continuations/cc-9001-test.json" <<JSON
{"acr_version":1,"identity":{"checkpoint_id":"cc-9001-test","created_by":"tester","sealed_at":"2026-10-04T10:00:00Z","reason":"explain test"},
 "state":{"items":[{"tag":"PROVEN","claim":"src parser works","evidence":["commit:abc1234"]}]},
 "evidence":{"commits":["abc1234"],"prs":["repo#7"],"receipts":[],"tests":[{"name":"parser","result":"PASS"}]},
 "coordination":{"owned_paths":["src/"],"scope":[],"do_not_touch":[]},"revalidation":{"status":"UNVERIFIED"}}
JSON
cat > "$STORE/continuations/cc-9002-other.json" <<JSON
{"identity":{"checkpoint_id":"cc-9002-other","sealed_at":"2026-10-04T11:00:00Z"},"state":{"items":[{"tag":"OPEN","claim":"docs thing"}]},"coordination":{"scope":["docs/.crumb"]}}
JSON
ex=$("$C" explain src)
echo "$ex" | grep -q 'id: cc-9001-test' && echo "$ex" | grep -q '\[PROVEN\] src parser works' && echo "$ex" | grep -q 'continuation test: parser -> PASS' && ok "explain surfaces continuation whose owned_paths match" || bad "explain continuation"
echo "$ex" | grep -q 'cc-9002-other' && bad "explain ignores continuation about another path" || ok "explain ignores continuation about another path"
"$C" explain docs | grep -q 'id: cc-9002-test\|id: cc-9002-other' && ok "explain matches via coordination.scope" || bad "explain scope"
"$C" explain "$T/nonexistent" >/dev/null 2>&1; [ $? -ne 0 ] && ok "explain on missing path fails" || bad "explain missing"
# ---- RFC-0003: Crumb Compiler (compile / verify / status / propose / context) ----
printf 'abc' | "$C" sha256 | grep -q '^ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad$' && ok "C3 sha256 known vector (abc)" || bad "C3 sha256 vector"
head -c 300000 /dev/urandom > "$T/rand.bin"
[ "$("$C" sha256 < "$T/rand.bin")" = "$(sha256sum < "$T/rand.bin" | cut -c1-64)" ] && ok "C3 sha256 matches sha256sum on 300 KB" || bad "C3 sha256 vs sha256sum"
CC3="$T/cc3"; mkdir -p "$CC3/src/deep" "$CC3/docs" "$CC3/evidence" && cd "$CC3" || exit 1
git init -q -b main . && echo 'int a;' > src/a.c && echo 'int b;' > src/deep/b.c && echo n > docs/n.md && echo r > evidence/r.json && echo top > README
"$C" seed . >/dev/null; git add -A && git -c user.name=t -c user.email=t@t commit -qm init
"$C" status . | grep -q 'UNCOMPILED' && ok "C3 status: fresh crumbs are UNCOMPILED" || bad "C3 status uncompiled"
"$C" verify . >/dev/null; [ $? -eq 1 ] && ok "C3 verify exits 1 on uncompiled crumbs" || bad "C3 verify uncompiled"
"$C" compile . | grep -q 'rewritten' && ok "C3 compile runs" || bad "C3 compile"
git add -A && git -c user.name=t -c user.email=t@t commit -qm compiled
"$C" compile . | grep -q ', 0 rewritten' && ok "C3 fixed point: second compile rewrites 0" || bad "C3 fixed point"
"$C" verify . | grep -q 'OK' && ok "C3 verify OK after compile" || bad "C3 verify OK"
git -c user.name=t -c user.email=t@t commit -q --allow-empty -m "empty" && "$C" verify . >/dev/null && ok "C3 empty commit keeps verify OK (stamps are not inputs)" || bad "C3 empty commit"
echo 'int b2;' > src/deep/b.c; git add -A
out=$("$C" verify .); st=$(echo "$out" | grep '^STALE' | awk '{print $2}' | sort | tr '\n' ' ')
[ "$st" = ". src src/deep " ] && ok "C3 touching src/deep/b.c: STALE is exactly src/deep, src and the root (ancestors only)" || bad "C3 ancestor-only staleness (got: $st)"
echo "$out" | grep -q 'docs\|evidence' && bad "C3 sibling dirs stay current" || ok "C3 sibling dirs stay current"
"$C" compile . >/dev/null; "$C" verify . >/dev/null && ok "C3 compile after the change: verify OK again" || bad "C3 recompile"
git add -A; git -c user.name=t -c user.email=t@t commit -qm "change + compile"; "$C" verify . >/dev/null && ok "C3 verify stays OK after the compiled change is committed (last_commit is not an input, D3a)" || bad "C3 D3a last_commit"
before=$(jq -r .purpose docs/.crumb); sem0=$(jq -cS '{purpose,layer,invariants,exports,related,boundaries}' src/.crumb)
"$C" propose docs "Design notes and decision records" | grep -q PROPOSED && ok "C3 propose prints PROPOSED" || bad "C3 propose"
[ "$(jq -r .purpose docs/.crumb)" = "$before" ] && [ "$(jq -r .extensions.proposed.purpose docs/.crumb)" = "Design notes and decision records" ] && [ "$(jq -r .extensions.proposed.status docs/.crumb)" = PROPOSED ] && ok "C3 propose never changes .purpose, writes extensions.proposed" || bad "C3 propose purpose"
[ "$sem0" = "$(jq -cS '{purpose,layer,invariants,exports,related,boundaries}' src/.crumb)" ] && ok "C3 compile never touches the semantic kernel" || bad "C3 kernel"
ctx=$("$C" context src/deep/b.c)
for h in 'TREE' 'YOUR TASK TOUCHES' 'READ THESE CRUMBS' 'CURRENT CONFLICTS' 'RELEVANT CONTINUATION'; do
  echo "$ctx" | grep -q "^== $h" && ok "C3 context prints section: $h" || bad "C3 context section: $h"
done
"$C" verify . >/dev/null && ok "C3 propose does not stale crumbs (proposal is not a digest input)" || bad "C3 propose stale"
echo x >> src/a.c; git add -A; "$C" context src/a.c | grep -q "^Crumbs STALE: 2 .*run crumb compile" && ok "C3 context freshness: STALE: n (run crumb compile)" || bad "C3 context stale line"
"$C" compile . >/dev/null; "$C" context src | grep -q '^Crumbs CURRENT at HEAD' && ok "C3 context freshness: CURRENT at HEAD <sha>" || bad "C3 context current line"
"$C" context src/deep/b.c | grep -q 'src/.crumb' && "$C" context src/deep/b.c | grep -q 'src/deep/.crumb' && ok "C3 context recommends the path's ancestor crumbs" || bad "C3 context ancestors"
"$C" context . | grep -q 'PROPOSED: Design notes' && ok "C3 context shows PROPOSED purpose for a child without .purpose" || bad "C3 context proposed"
"$C" claim lane-x src src/a.c "ctx test" >/dev/null; "$C" context src/a.c | grep -q 'held by lane-x' && ok "C3 context lists a shared-store lock on the path" || bad "C3 context conflict"
"$C" context docs | grep -q 'held by lane-x' && bad "C3 context ignores locks elsewhere" || ok "C3 context ignores locks elsewhere"
"$C" close lane-x src src/a.c >/dev/null
[ "$("$C" context src | wc -l)" -lt 80 ] && ok "C3 context output is bounded" || bad "C3 context bounded"
# orphan crumbs (lane CRUMB proof 19 b2, 2026-10-11): a .crumb under a directory that has NO .crumb is a child of the
# nearest crumbed ancestor (D7 amended), so deleting it is visible to verify and to pr-gate.sh
"$C" compile . >/dev/null; git add -A; git -c user.name=t -c user.email=t@t commit -qm "pre-orphan"
mkdir -p src/mid/leaf && echo 'int l;' > src/mid/leaf/l.c && "$C" create src/mid/leaf leaf "leaf under an uncrumbed directory" code >/dev/null
git add -A; st=$("$C" verify . | grep '^STALE' | awk '{print $2}' | sort | tr '\n' ' ')
[ "$st" = ". src src/mid/leaf " ] && ok "C3 D7 new crumb under an uncrumbed dir stales itself, its nearest crumbed ancestor and the root" || bad "C3 D7 orphan stale set (got: $st)"
"$C" compile . >/dev/null; git add -A; git -c user.name=t -c user.email=t@t commit -qm "orphan compiled"
"$C" verify . >/dev/null && ok "C3 D7 verify OK after compiling the deep crumb" || bad "C3 D7 verify after deep crumb"
"$C" compile . | grep -q ', 0 rewritten' && ok "C3 D7 fixed point holds with a deep child" || bad "C3 D7 fixed point deep child"
jq -e '.extensions.generated.children | map(.name) | index("mid/leaf") != null' src/.crumb >/dev/null && ok "C3 D7 deep crumb is listed as child \"mid/leaf\" of src (path relative to the parent crumb)" || bad "C3 D7 deep child not listed"
jq -e '.extensions.generated.children | map(.name) | index("mid") == null' src/.crumb >/dev/null && ok "C3 D7 the uncrumbed directory itself is not a child" || bad "C3 D7 uncrumbed dir listed"
git rm -q src/mid/leaf/.crumb; st=$("$C" verify . | grep '^STALE' | awk '{print $2}' | sort | tr '\n' ' ')
[ "$st" = ". src " ] && ok "C3 D7 deleting the deep crumb stales src and the root (orphan deletion is visible)" || bad "C3 D7 orphan deletion invisible (got: $st)"
"$C" verify . >/dev/null; [ $? -eq 1 ] && ok "C3 D7 verify exits 1 after the orphan deletion" || bad "C3 D7 verify exit after orphan deletion"
"$C" compile . >/dev/null; "$C" verify . >/dev/null && ok "C3 D7 recompile after the deletion returns to OK" || bad "C3 D7 recompile after deletion"
jq -e '.extensions.generated.children | map(.name) | index("mid/leaf") == null' src/.crumb >/dev/null && ok "C3 D7 deleted deep crumb is gone from src children" || bad "C3 D7 deleted deep child still listed"
git add -A; git -c user.name=t -c user.email=t@t commit -qm "orphan removed"
# D10: .crumbignore subtrees never participate in compile/verify/status (omega evidence/, physics nvrm, m16)
"$C" compile . >/dev/null; git add -A; git -c user.name=t -c user.email=t@t commit -qm "pre-ignore"
ev0=$(cat src/deep/.crumb); printf '# guarded tree\nsrc/deep/\n' > .crumbignore
st=$("$C" verify . | grep '^STALE' | awk '{print $2}' | sort | tr '\n' ' ')
[ "$st" = ". src " ] && ok "C3 D10 adding .crumbignore stales only the parent and its ancestors (children list changed)" || bad "C3 D10 ignore stale set (got: $st)"
"$C" compile . >/dev/null
[ "$(cat src/deep/.crumb)" = "$ev0" ] && ok "C3 D10 compile never rewrites a .crumb under an ignored subtree" || bad "C3 D10 ignored crumb rewritten"
jq -e '.extensions.generated.children | map(.name) | index("deep") == null' src/.crumb >/dev/null && ok "C3 D10 ignored directory is not a child of its parent" || bad "C3 D10 ignored child listed"
"$C" status . | grep -q 'src/deep' && bad "C3 D10 status lists ignored dir" || ok "C3 D10 status does not list the ignored directory"
echo 'int b3;' > src/deep/b.c; git add -A; st=$("$C" verify . | grep '^STALE' | awk '{print $2}' | sort | tr '\n' ' ')
[ "$st" = ". src " ] && ok "C3 D10 a file under the ignored subtree still stales the enclosing crumbs, never the ignored one" || bad "C3 D10 enclosing stale (got: $st)"
"$C" compile . >/dev/null; [ "$(cat src/deep/.crumb)" = "$ev0" ] && ok "C3 D10 ignored crumb still untouched after that compile" || bad "C3 D10 ignored crumb touched"
rm .crumbignore; "$C" compile . >/dev/null; "$C" verify . >/dev/null && ok "C3 D10 removing .crumbignore and recompiling returns to OK" || bad "C3 D10 remove ignore"
git add -A; git -c user.name=t -c user.email=t@t commit -qm "post-ignore"
# sovereign-core#355: generated build directories never take part in compile/verify/status (one shared policy)
SAVE=$(pwd); cd "$T" || exit 1; rm -rf g355; mkdir g355 && cd g355 && git init -q -b main .
mkdir -p src target/debug/build/x/out/auth node_modules/pkg out/cache keep/target
echo 'int main(void){return 0;}' > src/a.c; echo 'fn x(){}' > target/debug/build/x/out/auth/a.rs; echo 'y' > node_modules/pkg/i.js; echo 'z' > out/cache/o.c; echo 's' > keep/target/real.c
for d in . src target/debug/build/x/out/auth node_modules/pkg out/cache keep/target; do printf '{"schema_version":1,"purpose":"p %s"}\n' "$d" > "$d/.crumb"; done
printf 'out/\n' > .gitignore
git add .gitignore .crumb src keep; git -c user.name=t -c user.email=t@t commit -qm init   # target/ and node_modules/ stay untracked and NOT gitignored: the built-in names must suffice
tgt0=$(sha256sum target/debug/build/x/out/auth/.crumb node_modules/pkg/.crumb out/cache/.crumb)
"$C" compile . >/dev/null
[ "$(sha256sum target/debug/build/x/out/auth/.crumb node_modules/pkg/.crumb out/cache/.crumb)" = "$tgt0" ] && ok "355 .crumb under target/, node_modules/ and a gitignored dir are byte-identical after compile" || bad "355 build-dir crumbs rewritten"
jq -e '.extensions.generated' src/.crumb >/dev/null && jq -e '.extensions.generated' .crumb >/dev/null && ok "355 source crumbs are still compiled" || bad "355 source crumb not compiled"
jq -e '.extensions.generated' keep/target/.crumb >/dev/null && ok "355 a directory named target that holds tracked files is real source and is still compiled" || bad "355 tracked target skipped"
"$C" status . | grep -Eq 'target/debug|node_modules|out/cache' && bad "355 status lists a build dir" || ok "355 status ignores the build dirs"
"$C" verify . | grep -Eq 'target/debug|node_modules|out/cache' && bad "355 verify lists a build dir" || ok "355 verify ignores the build dirs"
"$C" status . | grep -q 'keep/target' && ok "355 status still lists the tracked target dir" || bad "355 status lost tracked target"
jq -e '[.extensions.generated.children[].name] | (index("node_modules") == null and index("out") == null and index("target") == null)' .crumb >/dev/null && ok "355 build dirs are not children of the root crumb" || bad "355 build dir listed as child"
git add .gitignore .crumb src keep; git -c user.name=t -c user.email=t@t commit -qm compiled
"$C" verify . >/dev/null && ok "355 verify OK after compile" || bad "355 verify after compile"
echo 'int q;' >> target/debug/build/x/out/auth/a.rs; echo 'more' > out/cache/more.c
"$C" verify . >/dev/null && ok "355 changing files inside build dirs does not stale anything" || bad "355 build-dir change staled crumbs"
cd "$SAVE" || exit 1
# ---- RFC-0003 amendment 1 (2026-10-18): generated data derived on demand, never committed ----
# The regression this guards: two PRs touching unrelated files both rewrite the root crumb's roll-up lines
# (source_tree, children_root, digest, stamps), so after the first squash-merges the second CONFLICTS on GitHub.
SAVE=$(pwd); AM="$T/am1"; rm -rf "$AM"; mkdir -p "$AM/src/deep" "$AM/docs" "$AM/evidence" && cd "$AM" || exit 1
gc() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
git init -q -b main . && echo 'int a;' > src/a.c && echo 'int b;' > src/deep/b.c && echo n > docs/n.md && echo r > evidence/r.json && echo top > README
"$C" seed . >/dev/null; git add -A; "$C" compile . >/dev/null; git add -A; gc commit -qm "legacy compiled"
[ "$("$C" verify .)" = "crumb verify: OK: 4 crumbs current" ] && ok "AM1 legacy repo (no root marker): verify output unchanged" || bad "AM1 legacy verify output changed"
twoprs() {  # twoprs <tag>: PR A edits src/a.c, PR B edits docs/n.md, each compiled per protocol; A squash-lands; prints B's conflicts
  for b in A B; do gc checkout -q -b "$1$b" main; [ $b = A ] && echo "/* $1 */" >> src/a.c || echo "$1" >> docs/n.md
    gc commit -qam "$1$b edit"; "$C" compile . >/dev/null; [ -n "$(git status --porcelain)" ] && { git add -A; gc commit -qm "crumb compile"; }; gc checkout -q main; done
  gc merge -q --squash "$1A" >/dev/null 2>&1; gc commit -qm "squash $1A"
  git merge-tree --write-tree --name-only main "$1B" | sed -n '2,/^$/p' | grep -v '^$' | tr '\n' ' '
}
conf=$(twoprs leg); [ -n "$conf" ] && ok "AM1 RED reproduced on legacy: unrelated PR conflicts after the first lands (in: $conf)" || bad "AM1 legacy conflict not reproduced (test cannot go red)"
gc reset -q --hard HEAD~1
legacy_root=$(jq -r .extensions.generated.digest .crumb); sem0=$(for f in $(git ls-files '*.crumb' '**/.crumb'); do jq -cS '{purpose,layer,invariants,exports,related,boundaries}' "$f"; done)
"$C" migrate . | grep -q '^crumb migrate: 4 crumbs, 4 rewritten' && ok "AM1 migrate rewrites every crumb once" || bad "AM1 migrate"
"$C" migrate . | grep -q ', 0 rewritten' && ok "AM1 migrate is idempotent" || bad "AM1 migrate idempotent"
[ "$(git ls-files '*.crumb' '**/.crumb' | xargs cat | grep -c '"generated"')" = 0 ] && ok "AM1 no committed crumb carries extensions.generated" || bad "AM1 generated left behind"
[ "$(jq -r .extensions.generated_policy .crumb)" = on-demand ] && ok "AM1 root crumb carries generated_policy on-demand" || bad "AM1 root marker"
[ "$sem0" = "$(for f in $(git ls-files '*.crumb' '**/.crumb'); do jq -cS '{purpose,layer,invariants,exports,related,boundaries}' "$f"; done)" ] && ok "AM1 migrate never touches the semantic kernel" || bad "AM1 kernel changed"
v=$("$C" verify .); [ $? -eq 0 ] && echo "$v" | grep -q "^crumb verify: OK: 4 crumbs current at HEAD .*root digest $legacy_root$" && ok "AM1 verify OK and prints the same root digest the legacy root crumb held (provenance kept)" || bad "AM1 verify/root digest ($v vs $legacy_root)"
[ "$(echo "$v" | wc -l)" = 1 ] && ok "AM1 verify prints one line (verify.rs readiness note)" || bad "AM1 verify lines"
[ "$("$C" digest . | jq -r .digest)" = "$legacy_root" ] && "$C" digest src | jq -e '.children | map(.name) == ["deep"]' >/dev/null && ok "AM1 digest prints the generated block on demand" || bad "AM1 digest"
gc commit -qam "crumb migrate"
conf=$(twoprs od); [ -z "$conf" ] && ok "AM1 GREEN: after migration the unrelated PR merges cleanly" || bad "AM1 on-demand still conflicts (in: $conf)"
gc merge -q --squash odB >/dev/null 2>&1 && gc commit -qm "squash odB"; "$C" verify . >/dev/null && ok "AM1 GREEN: merged main verifies with no recompile" || bad "AM1 merged main does not verify"
[ -z "$(git diff --name-only HEAD~2 HEAD | grep '\.crumb$')" ] && ok "AM1 neither PR changed any .crumb" || bad "AM1 PRs touched crumbs"
d1=$("$C" digest . | jq -r .digest); echo x >> src/deep/b.c; "$C" verify . >/dev/null && [ "$("$C" digest . | jq -r .digest)" != "$d1" ] && ok "AM1 a source change keeps verify OK and moves the computed root digest" || bad "AM1 source change"
git checkout -q -- src/deep/b.c
git show HEAD~3:src/.crumb > src/.crumb; out=$("$C" verify .); rc=$?
[ $rc -eq 1 ] && echo "$out" | grep -q '^STALE      src (committed generated data' && ok "AM1 a re-added generated block (old tool) fails verify, exit 1" || bad "AM1 re-added generated block passed ($rc)"
"$C" compile . | grep -q 'STRIPPED   src' && "$C" verify . >/dev/null && ok "AM1 compile strips it and verify is OK again" || bad "AM1 compile strip"
"$C" status . | grep -c '^CURRENT' | grep -qx 4 && "$C" context src | grep -q '^Crumbs CURRENT at HEAD' && ok "AM1 status and context report CURRENT" || bad "AM1 status/context"
d1=$("$C" digest . | jq -r .digest); git rm -q docs/.crumb; "$C" verify . >/dev/null && [ "$("$C" digest . | jq -r .digest)" != "$d1" ] && ok "AM1 deleting a crumb moves the root digest (D7 deletion still visible)" || bad "AM1 crumb deletion"
gc reset -q --hard HEAD; echo '{broken' > docs/.crumb; "$C" verify . >/dev/null; [ $? -eq 1 ] && ok "AM1 a crumb that is not JSON fails verify" || bad "AM1 broken crumb passed"
git checkout -q -- docs/.crumb
cd "$SAVE" || exit 1
# differential vs the shell reference (needs jq, git, sha256sum)
REF="$HERE/crumb-compile.sh"
if command -v jq >/dev/null 2>&1 && [ -f "$REF" ]; then
  # compile from nothing, so last_commit is fresh in both. The differential compares the LEGACY generator (the shell
  # reference has no on-demand mode), so the RFC-0003 amendment 1 root marker is dropped from the scratch clones too;
  # the on-demand path is covered by the AM1 cases above.
  wipe() { for f in $(cd "$1" && find . -name .crumb -not -path "./.git/*"); do jq -S "del(.extensions.generated, .extensions.generated_policy)" "$1/$f" > "$1/$f.t" && mv "$1/$f.t" "$1/$f"; done; }
  diffgen() { # $1 repoA (shell) $2 repoB (C): every .crumb extensions.generated minus stamps must match
    r=0; for f in $(cd "$1" && find . -name .crumb -not -path './.git/*'); do
      a=$(jq -cS '.extensions.generated | del(.generated_at_commit, .compiled_at)' "$1/$f"); b=$(jq -cS '.extensions.generated | del(.generated_at_commit, .compiled_at)' "$2/$f")
      [ "$a" = "$b" ] || { echo "DIFF $f"; r=1; }
    done; return $r; }
  cd "$T" || exit 1; rm -rf dA dB; git clone -q --no-hardlinks "$CC3" dA && git clone -q --no-hardlinks "$CC3" dB
  wipe "$T/dA"; wipe "$T/dB"
  (cd dA && sh "$REF" compile . >/dev/null) && (cd dB && "$C" compile . >/dev/null)
  diffgen "$T/dA" "$T/dB" >/dev/null && ok "C3 differential on scratch repo: generated blocks identical to crumb-compile.sh" || bad "C3 differential scratch"
  (cd dB && sh "$REF" verify . >/dev/null) && (cd dA && "$C" verify . >/dev/null) && ok "C3 each tool verifies the other's output" || bad "C3 cross verify"
  TOP=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$TOP" ]; then
    rm -rf eA eB; git clone -q --no-hardlinks "$TOP" eA && git clone -q --no-hardlinks "$TOP" eB
    wipe "$T/eA"; wipe "$T/eB"
    (cd eA && sh "$REF" compile . >/dev/null) && (cd eB && "$C" compile . >/dev/null)
    diffgen "$T/eA" "$T/eB" > "$T/diff.out" && ok "C3 differential on this repo: generated blocks identical" || { cat "$T/diff.out"; bad "C3 differential this repo"; }
    cmp -s "$T/eA/.crumb" "$T/eB/.crumb" 2>/dev/null; sed '/compiled_at/d' "$T/eA/tools/.crumb" > "$T/ta"; sed '/compiled_at/d' "$T/eB/tools/.crumb" > "$T/tb"
    cmp -s "$T/ta" "$T/tb" && ok "C3 whole .crumb file byte-identical apart from compiled_at (same commit stamp)" || bad "C3 file bytes"
  else echo "NOT_RUN differential on this repo (not in a git checkout)"; fi
else echo "NOT_RUN C3 differential (jq or crumb-compile.sh missing)"; fi
# ---- #234 store identity: outputs and record bytes unchanged, before vs after, unregistered and registered ----
# Same scripted session in the same path with the pre-#234 tool (built from BASE) and this tool, unregistered and
# registered: stdout of claim/update/whisper/close/sniff/list and every dirs/ and agents/ record must match byte for
# byte once ISO timestamps and heartbeat ages are masked. Only STORE_ID (and the stderr dry-run line) is new.
# crumb924 added lease generations (fencing tokens): the " generation N" suffix of CLAIMED, each lease's "generation"
# and the record's "generations" map are masked too (nogen: jq prints these records in the tool's own layout, so the
# rest is still compared byte for byte); test-namespace.sh covers generations themselves.
nogen() { jq 'del(.generations) | if (.locks | type) == "object" then .locks |= map_values(del(.generation)) else . end' "$1"; }
BASE=e6e48a0
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null; unset CRUMB_COORD_ROOT CRUMB_EXPECT_STORE_ID CRUMB_STRICT_STORE_ID
if git -C "$HERE" cat-file -e "$BASE:tools/crumb/crumb.c" 2>/dev/null; then
  git -C "$HERE" show "$BASE:tools/crumb/crumb.c" > "$T/base.c" && cc -std=c11 -O2 -o "$T/crumb-base" "$T/base.c"
  session() {   # session <crumb> <out-dir> [registered]: fresh repo at one fixed path, fixed commit dates
    rm -rf "$T/same"; mkdir -p "$T/same/src" && cd "$T/same" || exit 1
    git init -q -b main . && echo a > src/a.c && git add -A && GIT_AUTHOR_DATE=2026-01-01T00:00:00Z GIT_COMMITTER_DATE=2026-01-01T00:00:00Z git -c user.name=t -c user.email=t@t commit -qm init
    git worktree add -q -b wb "$T/same-wb" 2>/dev/null || { rm -rf "$T/same-wb"; git worktree prune; git worktree add -q -b wb "$T/same-wb"; }
    if [ -n "${3:-}" ]; then git config crumb.storeId "$("$1" store-id . 2>/dev/null)"; fi
    mkdir -p "$2"
    { "$1" claim agent-a src a.c "rewrite a" 600; (cd "$T/same-wb" && "$1" claim agent-b src a.c "also a"); echo "rc=$?"
      "$1" update agent-a src "still on a"; "$1" whisper agent-a src agent-b "half done" high src/a.c
      (cd "$T/same-wb" && "$1" sniff agent-b src); "$1" close agent-b src a.c; echo "rc=$?"
      "$1" close agent-a src a.c modify "done"; (cd "$T/same-wb" && "$1" claim agent-b src a.c "my turn"); "$1" list .
      (cd "$T/same-wb" && "$1" sniff agent-b src); } 2>"$2/stderr" | sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z/TS/g; s/heartbeat [0-9-]+s/heartbeat Ns/g; s/ generation [0-9]+$//' > "$2/stdout"
    S=$(git rev-parse --absolute-git-dir)/crumb/v1
    (cd "$S" && find dirs agents -type f | sort | while read -r f; do echo "== $f"; case $f in dirs/*) nogen "$f";; *) cat "$f";; esac | sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z/TS/g'; done) > "$2/records"
    [ -f "$S/STORE_ID" ] && cp "$S/STORE_ID" "$2/STORE_ID"
    cd "$T" || exit 1; rm -rf "$T/same" "$T/same-wb"
  }
  session "$T/crumb-base" "$T/s-base"; session "$C" "$T/s-new"; session "$C" "$T/s-reg" registered
  cmp -s "$T/s-base/stdout" "$T/s-new/stdout" && ok "#234 unregistered: claim/update/whisper/close/sniff/list stdout identical to $BASE" || { diff "$T/s-base/stdout" "$T/s-new/stdout" | head; bad "#234 unregistered stdout differs"; }
  cmp -s "$T/s-base/records" "$T/s-new/records" && ok "#234 unregistered: every dirs/ and agents/ record byte-identical to $BASE (timestamps masked)" || { diff "$T/s-base/records" "$T/s-new/records" | head; bad "#234 unregistered records differ"; }
  cmp -s "$T/s-base/stdout" "$T/s-reg/stdout" && cmp -s "$T/s-base/records" "$T/s-reg/records" && ok "#234 registered: stdout and records identical to $BASE" || { diff "$T/s-base/stdout" "$T/s-reg/stdout" | head; bad "#234 registered output differs"; }
  [ ! -f "$T/s-base/STORE_ID" ] && grep -Eqx 'crumb-coord-store-id/1 [0-9a-f]{32}' "$T/s-new/STORE_ID" && ok "#234 only addition on disk: STORE_ID marker (synapse-coord format)" || bad "#234 STORE_ID addition"
  grep -q 'STORE_UNREGISTERED (dry run)' "$T/s-new/stderr" && ! grep -q STORE_UNREGISTERED "$T/s-reg/stderr" && [ ! -s "$T/s-base/stderr" ] && ok "#234 dry-run warning only on stderr, only when unregistered" || bad "#234 stderr warning"
  grep -q 'STORE_ID' "$T/s-new/records" && bad "#234 STORE_ID leaked into records" || ok "#234 STORE_ID never appears in records"
else echo "NOT_RUN #234 before/after differential (no $BASE in this checkout's history)"; fi
exit $fail
