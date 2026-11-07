#!/usr/bin/env bash
# 19: since the crumb retirement (2026-11-07, DRA-97) stale, missing or mixed crumbs no longer block admission.
# The real scripts/pr-gate.sh (with a fake `gh` that answers from fixtures: open PR, CLEAN, no required contexts)
# is run with --worktree on a clone whose PR branch (a) changed source without recompiling (formerly STALE),
# (b) deleted a .crumb (formerly MISSING), (c) changed source only, with no crumb commit, (d) changed source and
# a .crumb in one last commit (formerly refused by rule 2). Every case must exit 0 with
# "GATE crumb: SKIP retired". The crumb tool is never needed: CRUMB and a `crumb` on PATH are stubs that record
# any call and exit 99, and the proof checks they were never called. No network.
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
proof_begin 19 "pr-gate.sh no longer refuses stale, missing or mixed crumbs (retired, DRA-97)" "${1:-}"
GATE=${PR_GATE:-$here/../pr-gate.sh}; [ -x "$GATE" ] || { echo "pr-gate.sh not found at $GATE" >&2; exit 2; }
export SLEEP_SECS=0
clone_repo "$TMP/seed"; git -C "$TMP/seed" checkout -q -B main
git clone -q --bare "$TMP/seed" "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/w"; W=$TMP/w
git -C "$W" config user.name proof; git -C "$W" config user.email proof@example.invalid
FX="$TMP/fx"; mkdir -p "$FX" "$TMP/bin"; export FX
cat > "$TMP/bin/gh" <<'S'
#!/usr/bin/env bash
d="$FX/$CASE"
case "$1 $2" in
  "pr view") cat "$d/pr.json" ;;
  "pr list") echo '[]' ;;
  api\ repos/*) echo '[]' ;;
  *) echo "fake gh: unhandled: $*" >&2; exit 2 ;;
esac
S
printf '#!/usr/bin/env bash\necho "$*" >> "%s/crumb-called"\nexit 99\n' "$TMP" > "$TMP/bin/crumb"
chmod +x "$TMP/bin/gh" "$TMP/bin/crumb"; export PATH="$TMP/bin:$PATH" CRUMB="$TMP/bin/crumb"
fx() {   # fx <case> <branch> <sha>
  mkdir -p "$FX/$1"
  printf '{"number":1,"state":"OPEN","isDraft":false,"baseRefName":"main","headRefName":"%s","headRefOid":"%s","mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","reviewDecision":"","statusCheckRollup":[]}\n' "$2" "$3" > "$FX/$1/pr.json"
}
L=$(leaf_crumb_dir "$W") || { echo "no leaf crumb dir" >&2; exit 1; }
F=$(tracked_file_in "$W" "$L")
MAIN=main
branch() { git -C "$W" checkout -q -b "$1" "origin/$MAIN"; }
push() { git -C "$W" push -q origin "$1"; git -C "$W" rev-parse HEAD; }
admitted() {   # admitted <label> : last gate run exited 0 with the retired SKIP and no crumb FAIL
  check_eq "$1: pr-gate exits 0 (dry run)" "$RC" 0
  check "$1: GATE crumb: SKIP retired" grep -qF 'GATE crumb: SKIP retired 2026-11-07 (DRA-97); .crumb files are history' <<<"$OUT"
  check "$1: no GATE crumb: FAIL" bash -c '! grep -q "^GATE crumb: FAIL" <<<"$1"' _ "$OUT"
}

# (a) formerly stale: source change committed without recompiling
branch stale; printf '\n# proof 19 stale\n' >> "$W/$F"; git -C "$W" commit -qam "source change, no crumb compile"
SHA=$(push stale); fx stale stale "$SHA"
export CASE=stale; measure gate_stale "$GATE" proof-repo 1 --worktree "$W" --dry-run
admitted "stale tree"
note "$(grep '^GATE crumb' <<<"$OUT" | cut -c1-110)"

# (b) formerly missing: a .crumb deleted (immediate child of a crumbed parent, and a deep one if present)
IMM=""; DEEP=""
for d in $(crumb_dirs "$W" | grep -v '^\.$'); do
  p=${d%/*}; [ "$p" = "$d" ] && p=.
  if [ -f "$W/$p/.crumb" ]; then [ -n "$IMM" ] || IMM=$d; else [ -n "$DEEP" ] || DEEP=$d; fi
done
num "immediate_child_crumb=$IMM"; num "deep_crumb_without_crumbed_parent=${DEEP:-none}"
branch missing-immediate; git -C "$W" rm -q "$IMM/.crumb"; git -C "$W" commit -qm "delete $IMM/.crumb"
SHA=$(push missing-immediate); fx missing missing-immediate "$SHA"
export CASE=missing; measure gate_missing_immediate "$GATE" proof-repo 1 --worktree "$W" --dry-run
admitted "missing immediate-child crumb"
if [ -n "$DEEP" ]; then
  branch missing-deep; git -C "$W" rm -q "$DEEP/.crumb"; git -C "$W" commit -qm "delete $DEEP/.crumb"
  SHA=$(push missing-deep); fx deep missing-deep "$SHA"
  export CASE=deep; measure gate_missing_deep "$GATE" proof-repo 1 --worktree "$W" --dry-run
  admitted "missing deep crumb"
else
  note "no deep crumb without a crumbed parent in this repository; (b2) not applicable"
fi

# (c) source change only, no crumb commit: the final SHA is the source commit
branch ok; printf '\n# proof 19 ok\n' >> "$W/$F"; git -C "$W" commit -qam "source change"
SHA=$(push ok); fx ok ok "$SHA"
export CASE=ok; measure gate_ok "$GATE" proof-repo 1 --worktree "$W" --dry-run
admitted "source-only head"
note "$(grep '^GATE crumb' <<<"$OUT" | cut -c1-110)"

# (d) formerly refused: source and a .crumb changed in the same last commit
branch mixed; printf '\n# proof 19 mixed\n' >> "$W/$F"; printf '\n' >> "$W/$L/.crumb"
git -C "$W" add -A; git -C "$W" commit -qm "source + crumb together"
SHA=$(push mixed); fx mixed mixed "$SHA"
export CASE=mixed; measure gate_mixed "$GATE" proof-repo 1 --worktree "$W" --dry-run
admitted "mixed last commit"
check "mixed last commit: not refused by rule 2" bash -c '! grep -q "crumb commit must be separate and last" <<<"$1"' _ "$OUT"

check "the crumb tool was never called" test ! -e "$TMP/crumb-called"
proof_end
