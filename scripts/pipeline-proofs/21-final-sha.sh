#!/usr/bin/env bash
# 21: since the crumb retirement (2026-11-07, DRA-97) the final SHA is the last source commit; no crumb commit is
# needed. A source-only branch is rebased by the real scripts/rebase-crumb.sh onto a moved main (local bare origin,
# url.insteadOf for the aien-dev URL), then judged by the real scripts/pr-gate.sh --worktree --dry-run (fake `gh`
# answering from a fixture). Expected: the rebased head is one commit, the source commit itself (same subject and
# change, no "crumb compile" commit), the gate admits it with "GATE crumb: SKIP retired", and HEAD is unchanged by
# the gate. CRUMB and a `crumb` on PATH are stubs that record any call and exit 99; they must never be called.
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
proof_begin 21 "final SHA = the source commit, no crumb commit needed (retired, DRA-97)" "${1:-}"
RB=${REBASE_CRUMB:-$here/../rebase-crumb.sh}; [ -x "$RB" ] || { echo "rebase-crumb.sh not found at $RB" >&2; exit 2; }
GATE=${PR_GATE:-$here/../pr-gate.sh}; [ -x "$GATE" ] || { echo "pr-gate.sh not found at $GATE" >&2; exit 2; }
export SLEEP_SECS=0
FAKEURL="https://github.com/aien-dev/proof-repo"
clone_repo "$TMP/seed"; git -C "$TMP/seed" checkout -q -B main
git clone -q --bare "$TMP/seed" "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/a"; A=$TMP/a
git clone -q "$TMP/origin.git" "$TMP/other"; O=$TMP/other
for r in "$A" "$O"; do git -C "$r" config user.name proof; git -C "$r" config user.email proof@example.invalid; done
mkdir -p "$TMP/bin" "$TMP/fx"
printf '#!/usr/bin/env bash\necho "$*" >> "%s/crumb-called"\nexit 99\n' "$TMP" > "$TMP/bin/crumb"
cat > "$TMP/bin/gh" <<'S'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view") cat "$FXFILE" ;;
  "pr list") echo '[]' ;;
  api\ repos/*) echo '[]' ;;
  *) echo "fake gh: unhandled: $*" >&2; exit 2 ;;
esac
S
chmod +x "$TMP/bin/crumb" "$TMP/bin/gh"; export PATH="$TMP/bin:$PATH" CRUMB="$TMP/bin/crumb" FXFILE="$TMP/fx/pr.json"

L=$(leaf_crumb_dir "$A") || { echo "no leaf crumb dir" >&2; exit 1; }
F=$(tracked_file_in "$A" "$L")
S0=$(git -C "$A" rev-parse HEAD)
git -C "$A" checkout -q -b feat
printf '\n# proof 21 source change\n' >> "$A/$F"; git -C "$A" commit -qam "source change in $L"
S1=$(git -C "$A" rev-parse HEAD); num "source_sha=${S1:0:12}"
check "source commit differs from the base" [ "$S1" != "$S0" ]
git -C "$A" push -q origin feat
git -C "$A" remote set-url origin "$FAKEURL"; git -C "$A" config "url.$TMP/origin.git.insteadOf" "$FAKEURL"
git -C "$A" checkout -q main

# main moves (a commit outside the changed file), so the rebase rewrites the source commit
printf '\n# proof 21 main moves\n' >> "$O/README.md"; git -C "$O" commit -qam "main moves"; git -C "$O" push -q origin main

measure rebase_crumb "$RB" "$A" feat
check_eq "rebase-crumb.sh exits 0" "$RC" 0
S2=$(git -C "$A" rev-parse HEAD); num "final_sha=${S2:0:12}"
check "final SHA differs from the pre-rebase source SHA (rebased)" [ "$S2" != "$S1" ]
check_eq "final head is one commit on main" "$(git -C "$A" rev-list --count origin/main..HEAD)" 1
check_eq "final commit is the source commit" "$(git -C "$A" log -1 --format=%s)" "source change in $L"
check_eq "final commit carries the same change as the source commit" \
  "$(git -C "$A" diff HEAD~1 HEAD | git -C "$A" patch-id --stable | cut -d' ' -f1)" \
  "$(git -C "$A" diff "$S1~1" "$S1" | git -C "$A" patch-id --stable | cut -d' ' -f1)"
check_eq "no crumb compile commit" "$(git -C "$A" log --format=%s origin/main..HEAD | grep -c '^crumb compile' || true)" 0

printf '{"number":1,"state":"OPEN","isDraft":false,"baseRefName":"main","headRefName":"feat","headRefOid":"%s","mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","reviewDecision":"","statusCheckRollup":[]}\n' "$S2" > "$FXFILE"
git -C "$A" checkout -q feat
measure gate_final "$GATE" proof-repo 1 --worktree "$A" --dry-run
check_eq "pr-gate admits the final SHA (exit 0, dry run)" "$RC" 0
check "GATE crumb: SKIP retired" grep -qF 'GATE crumb: SKIP retired 2026-11-07 (DRA-97); .crumb files are history' <<<"$OUT"
note "$(grep '^GATE crumb' <<<"$OUT" | cut -c1-110)"
check_eq "the gate added no commit" "$(git -C "$A" rev-parse HEAD)" "$S2"
check_eq "working tree clean" "$(git -C "$A" status --porcelain | wc -l)" 0
check "the crumb tool was never called" test ! -e "$TMP/crumb-called"
proof_end
