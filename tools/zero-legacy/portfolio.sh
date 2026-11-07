#!/bin/sh
# portfolio.sh LIST OUT ZLBUILD: reproducible source/ELF closure snapshot of many repositories.
# LIST lines are "NAME<TAB>SHA<TAB>ARCHIVED" (aien-dev/NAME at commit SHA). For each line the
# repository is fetched at exactly SHA (depth 1) into OUT/work, ZLBUILD/closure classifies every
# file (transitional inventory mode), ZLBUILD/elfclose classifies every file closure reports as
# ELF, and one row is appended to OUT/summary.tsv. Per-repository rows stay in OUT/rows/NAME.tsv
# and OUT/elf/NAME.tsv. Rerunning with the same LIST reproduces the same rows (only the order of
# lines inside OUT/rows/*.tsv follows the filesystem). A fetch failure gives a FETCH_FAILED row.
# This driver is shell (an outstanding SHELL row under #316); the classification is seeded Omega.
set -u
list=$1; out=$2; zl=$3
mkdir -p "$out/rows" "$out/elf"
w=$out/work
[ -d "$w/.git" ] || git init -q "$w"
cats="OM C_H RUST PYTHON SHELL OSC HEXASM ELF ARCHIVE DOC OTHER HIDDEN WRAPPER DATA GENERATED EXTERNAL FOREIGN SYMLINK FORGED SKIP MAKE UNREADABLE"
{ printf 'repo\tsha\tarchived'; for c in $cats; do printf '\t%s' "$c"; done
  printf '\tOUTSTANDING\tUNKNOWN\tELF_FOREIGN\tELF_UNMARKED\tELF_UNKNOWN\n'; } > "$out/summary.tsv"
while IFS='	' read -r name sha arch; do
  case "$name" in ''|'#'*) continue ;; esac
  if ! git -C "$w" fetch -q --depth 1 "https://github.com/aien-dev/$name.git" "$sha" 2>"$out/fetch.err" \
     || ! git -C "$w" checkout -q -f --detach FETCH_HEAD 2>>"$out/fetch.err" \
     || [ "$(git -C "$w" rev-parse HEAD)" != "$sha" ]; then
    printf '%s\t%s\t%s\tFETCH_FAILED\n' "$name" "$sha" "$arch" >> "$out/summary.tsv"; continue
  fi
  git -C "$w" clean -q -ffdx
  (cd "$w" && "$zl/closure" .) > "$out/rows/$name.tsv"
  grep '^ELF	' "$out/rows/$name.tsv" | cut -f2 > "$out/elf.list"
  : > "$out/elf/$name.tsv"
  if [ -s "$out/elf.list" ]; then
    (cd "$w" && tr '\n' '\0' < "$out/elf.list" | xargs -0 "$zl/elfclose" elf) > "$out/elf/$name.tsv"
  fi
  row=$(printf '%s\t%s\t%s' "$name" "$sha" "$arch")
  for c in $cats OUTSTANDING UNKNOWN; do
    v=$(sed -n "s/^# $c \([0-9]*\)$/\1/p" "$out/rows/$name.tsv"); row="$row	${v:-0}"
  done
  for c in FOREIGN UNMARKED UNKNOWN; do
    v=$(sed -n "s/^# $c \([0-9]*\)$/\1/p" "$out/elf/$name.tsv"); row="$row	${v:-0}"
  done
  printf '%s\n' "$row" >> "$out/summary.tsv"
  git -C "$w" reflog expire --expire=now --all
  git -C "$w" gc -q --prune=now
done < "$list"
echo "PORTFOLIO rows=$(($(wc -l < "$out/summary.tsv") - 1)) failed=$(grep -c FETCH_FAILED "$out/summary.tsv")"
