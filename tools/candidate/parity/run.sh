#!/usr/bin/env bash
# tools/candidate/parity/run.sh: the byte-for-byte parity oracle of the candidate checkers.
# usage: run.sh <check_candidate-bin> <check_pins-bin> [record|record-extensions]
# Every directory under cases/candidate and cases/pins is one case: m.toml (plus amendments or a
# files/ tree), `mode` (sha | shawords | emptysha | gh | files: how the checker reaches commits and
# lock files, all offline stubs under mktemp) and an optional `args` file (one argument per line,
# default m.toml). A case runs with its directory as the working directory; stdout and stderr are
# captured in order through one pipe and the exit code is appended as "rc=N"; in gh mode the fake
# gh's argv log follows. The expected files were recorded from the bash scripts this corpus
# froze (scripts/check_candidate.sh and scripts/check_candidate_pins.sh at 1dd84d1) with the
# word `record`; without it the outputs are compared and any difference is printed. A case with a
# `limit` file is a named, documented difference (README "Limits"): it is shown, not counted as a
# failure, and reported if it ever becomes identical.
# Six candidate cases also assert the exact kernel-repository rename against the frozen oracle;
# unlike a limit, any other byte difference (or the old repository name) fails.
# A case with an `extension` file tests behaviour added after the bash was deleted (-mv sources and
# in-tree contracts, DRA-46): its expected file comes from `record-extensions` (the .om, reviewed by
# hand), it is counted on its own "extensions:" line and any difference fails; `record` skips it.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cand="$1"; pins="$2"; mode="${3:-compare}"
cand="$(cd "$(dirname "$cand")" && pwd)/$(basename "$cand")"
pins="$(cd "$(dirname "$pins")" && pwd)/$(basename "$pins")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/stub" <<'S'
#!/usr/bin/env bash
[ "$2" != "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" ]
S
cat > "$tmp/stubw" <<'S'
#!/usr/bin/env bash
[ "$1" = "--flag" ] || exit 9
[ "$3" != "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" ]
S
cat > "$tmp/stubf" <<'S'
#!/usr/bin/env bash
cat "$PARITY_FILES/$1/$2/$3" 2>/dev/null || { echo "{\"message\":\"No commit found for the ref $2\"}"; exit 1; }
S
cat > "$tmp/stubfw" <<'S'
#!/usr/bin/env bash
[ "$1" = "--flag" ] || exit 9
cat "$PARITY_FILES/$2/$3/$4" 2>/dev/null || { echo "{\"message\":\"No commit found for the ref $3\"}"; exit 1; }
S
cat > "$tmp/bin/gh" <<'S'
#!/usr/bin/env bash
echo "$*" >> "$GH_STUB_LOG"
[ "$1" = "api" ] || exit 2
sha="${2##*/}"
if [ "$sha" = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" ]; then echo "gh: Not Found (HTTP 404)" >&2; exit 1; fi
echo "$sha"
S
chmod +x "$tmp/stub" "$tmp/stubw" "$tmp/stubf" "$tmp/stubfw" "$tmp/bin/gh"
same=0; diff=0; limits=0; renames=0; xsame=0; xdiff=0
one() { # one <group> <bin> <casedir>
  local g="$1" bin="$2" d="$3" name; name="$(basename "$d")"
  local m; m="$(cat "$d/mode")"
  local args=(m.toml); [ -f "$d/args" ] && mapfile -t args < "$d/args"
  : > "$tmp/gh.log"
  ( cd "$d" && unset CAND_SHA_CHECK CAND_FILE_AT
    case "$m" in
      sha) export CAND_SHA_CHECK="$tmp/stub" ;;
      shawords) export CAND_SHA_CHECK="$tmp/stubw  --flag" ;;
      emptysha) export CAND_SHA_CHECK="" PATH="$tmp/bin:$PATH" GH_STUB_LOG="$tmp/gh.log" ;;
      gh) export PATH="$tmp/bin:$PATH" GH_STUB_LOG="$tmp/gh.log" ;;
      files) export CAND_FILE_AT="$tmp/stubf" PARITY_FILES="$d/files" ;;
      fileswords) export CAND_FILE_AT="$tmp/stubfw	--flag" PARITY_FILES="$d/files" ;;
    esac
    "$bin" "${args[@]}" 2>&1; echo "rc=$?"
    if [ -s "$tmp/gh.log" ]; then echo "-- gh calls --"; cat "$tmp/gh.log"; fi
  ) | sed "s|$bin|<bin>|g" > "$tmp/out"
  local exp="$here/expected/$g/$name.out"
  if [ -f "$d/extension" ]; then
    # An extension case (README "Extension cases"): behaviour the bash never had, so its expected
    # file was recorded from the .om (record-extensions) and reviewed by hand. Counted apart from the
    # frozen oracle; `record` (the bash oracle) never touches it.
    if [ "$mode" = record ]; then return; fi
    if [ "$mode" = record-extensions ]; then mkdir -p "$here/expected/$g"; cp "$tmp/out" "$exp"; xsame=$((xsame+1)); return; fi
    if cmp -s "$tmp/out" "$exp"; then xsame=$((xsame+1))
    else xdiff=$((xdiff+1)); echo "DIFF (extension): $g/$name"; diff "$exp" "$tmp/out" | sed 's/^/    /'; fi
    return
  fi
  if [ "$mode" = record ]; then mkdir -p "$here/expected/$g"; cp "$tmp/out" "$exp"; same=$((same+1)); return; fi
  case "$g/$name" in
    candidate/gh-404-contract|candidate/gh-404|candidate/gh-good|candidate/gh-live-cand0|candidate/nonexistent-sha|candidate/sha-check-unset-empty)
      # Transform only complete API/diagnostic lines, never manifest keys or arbitrary text.
      sed -E \
        -e 's|^(api repos/aien-dev/)aienos(/commits/[0-9a-f]{40} -q \.sha)$|\1aienux\2|' \
        -e 's|^(FAIL: commit [0-9a-f]{40} not found in aien-dev/)aienos$|\1aienux|' \
        "$exp" > "$tmp/renamed"
      if ! cmp -s "$exp" "$tmp/renamed" && cmp -s "$tmp/out" "$tmp/renamed"; then
        renames=$((renames+1)); echo "RENAME (exact delta): $g/$name"
      else
        diff=$((diff+1)); echo "DIFF (required exact naming delta): $g/$name"
        diff "$tmp/renamed" "$tmp/out" | sed 's/^/    /'
      fi
      return ;;
  esac
  if cmp -s "$tmp/out" "$exp"; then
    if [ -f "$d/limit" ]; then echo "LIMIT CLOSED (now identical, drop the limit file): $g/$name"; fi
    same=$((same+1))
  elif [ -f "$d/limit" ]; then
    limits=$((limits+1)); echo "LIMIT (named, expected to differ): $g/$name: $(cat "$d/limit")"; diff "$exp" "$tmp/out" | sed 's/^/    /'
  else diff=$((diff+1)); echo "DIFF: $g/$name"; diff "$exp" "$tmp/out" | sed 's/^/    /'; fi
}
for d in "$here"/cases/candidate/*/; do one candidate "$cand" "${d%/}"; done
for d in "$here"/cases/pins/*/; do one pins "$pins" "${d%/}"; done
echo "parity: $same identical, $renames exact naming deltas, $limits named limits, $diff different"
echo "extensions: $xsame identical, $xdiff different"
[ "$diff" -eq 0 ] && [ "$xdiff" -eq 0 ]
