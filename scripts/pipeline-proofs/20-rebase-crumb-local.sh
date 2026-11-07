#!/usr/bin/env bash
# 20: scripts/rebase-crumb.sh keeps source changes and resolves a .crumb-only conflict with main's copy, with no
# GitHub and no crumb tool (crumb compile/verify retired 2026-11-07, DRA-97). A local bare repository stands in for
# origin (the script requires an aien-dev URL; url.insteadOf redirects it to the bare repo). Branch feat changes a
# leaf file, then hand-edits the root .crumb in a separate commit (an old-style crumb commit); main then moves with
# a change in another subtree and its own root .crumb edit, so the root .crumb conflicts in .crumb only.
# Expected: exit 0, feat's source change kept, main's change present, every .crumb equal to main's copy, no
# "crumb compile" commit added, last commit is feat's source commit, pushed. CRUMB and a `crumb` on PATH are stubs
# that record any call and exit 99; the proof checks they were never called.
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
proof_begin 20 "rebase-crumb.sh on a local bare origin keeps source, takes main's crumbs, runs no crumb tool" "${1:-}"
RB=${REBASE_CRUMB:-$here/../rebase-crumb.sh}; [ -x "$RB" ] || { echo "rebase-crumb.sh not found at $RB" >&2; exit 2; }
FAKEURL="https://github.com/aien-dev/proof-repo"
clone_repo "$TMP/seed"; git -C "$TMP/seed" checkout -q -B main
git clone -q --bare "$TMP/seed" "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/w"; W=$TMP/w
git clone -q "$TMP/origin.git" "$TMP/other"; O=$TMP/other
for r in "$W" "$O"; do git -C "$r" config user.name proof; git -C "$r" config user.email proof@example.invalid; done

L1=$(leaf_crumb_dir "$W") || { echo "no leaf crumb dir" >&2; exit 1; }
F1=$(tracked_file_in "$W" "$L1")
# a second subtree sharing only the root with L1
L2=""; for d in $(crumb_dirs "$W" | grep -v '^\.$' | awk -F/ '{print NF" "$0}' | sort -rn | cut -d' ' -f2); do
  case "$L1/" in "$d"/*) continue ;; esac; case "$d/" in "$L1"/*) continue ;; esac
  F2=$(tracked_file_in "$W" "$d"); [ -n "$F2" ] || continue; L2=$d; break
done
[ -n "$L2" ] || { F2=README.md; L2=.; }
num "feat_file=$F1"; num "main_file=$F2"

mkdir -p "$TMP/bin"
printf '#!/usr/bin/env bash\necho "$*" >> "%s/crumb-called"\nexit 99\n' "$TMP" > "$TMP/bin/crumb"
chmod +x "$TMP/bin/crumb"; export PATH="$TMP/bin:$PATH" CRUMB="$TMP/bin/crumb"

# feat: source change, then a hand-edited root .crumb as a separate last commit, pushed
git -C "$W" checkout -q -b feat
printf '\n# proof 20 FEAT MARKER\n' >> "$W/$F1"; git -C "$W" commit -qam "feat: change $F1"
printf '\n# proof 20 feat crumb\n' >> "$W/.crumb"; git -C "$W" commit -qam "crumb compile"
git -C "$W" push -q origin feat
git -C "$W" remote set-url origin "$FAKEURL"; git -C "$W" config "url.$TMP/origin.git.insteadOf" "$FAKEURL"
git -C "$W" checkout -q main

# main moves: change in another subtree plus its own root .crumb edit, pushed
printf '\n# proof 20 MAIN MARKER\n' >> "$O/$F2"; git -C "$O" commit -qam "main: change $F2"
printf '\n# proof 20 main crumb\n' >> "$O/.crumb"; git -C "$O" commit -qam "crumb edit (main)"
git -C "$O" push -q origin main
MAINSHA=$(git -C "$O" rev-parse HEAD)
check "root .crumb differs between feat and new main (a crumb conflict exists)" sh -c "! git -C '$O' diff --quiet origin/feat origin/main -- .crumb"

measure rebase_crumb "$RB" "$W" feat
note "$(echo "$OUT" | tail -1 | cut -c1-120)"
check_eq "rebase-crumb.sh exits 0" "$RC" 0
check "retired crumb notice printed" grep -qF "crumb: retired (DRA-97)" <<<"$OUT"
check "feat's source change survived" grep -q 'proof 20 FEAT MARKER' "$W/$F1"
check "main's change is present" grep -q 'proof 20 MAIN MARKER' "$W/$F2"
check_eq "feat now sits on the new main" "$(git -C "$W" merge-base HEAD origin/main)" "$MAINSHA"
check "every .crumb equals main's copy" git -C "$W" diff --quiet origin/main HEAD -- '*.crumb' '**/.crumb'
check "root .crumb is main's copy, not feat's" sh -c "grep -q 'proof 20 main crumb' '$W/.crumb' && ! grep -q 'proof 20 feat crumb' '$W/.crumb'"
check_eq "no crumb compile commit after the rebase" "$(git -C "$W" log --format=%s origin/main..HEAD | grep -c '^crumb compile' || true)" 0
check_eq "last commit is feat's source commit" "$(git -C "$W" log -1 --format=%s)" "feat: change $F1"
check_eq "pushed: origin/feat == local feat" "$(git -C "$TMP/origin.git" rev-parse refs/heads/feat)" "$(git -C "$W" rev-parse HEAD)"
check_eq "working tree clean" "$(git -C "$W" status --porcelain | wc -l)" 0
check "the crumb tool was never called" test ! -e "$TMP/crumb-called"
num "commits_on_main=$(git -C "$W" rev-list --count origin/main..HEAD)"
proof_end
