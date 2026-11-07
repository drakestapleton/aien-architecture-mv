#!/bin/sh
# procsnap.sh ZLBUILD [PROCROOT]: one dated process-closure snapshot of this host, safe to publish.
# Runs ZLBUILD/elfclose proc, then prints (1) counts by owner, class and verdict, (2) one row per
# distinct executable of the scanning account that lives outside the OS distribution and the
# agent tool directories (the first-party candidates; shown as their last two path parts), with
# group, verdict, producer, link,
# process count and the sha256 of the running image (/proc/PID/exe) from ZLBUILD/sha256 (the
# seeded-Omega hasher; - when the image is over its 16 MiB cap or the process exited). No full
# path, home directory or command line is recorded.
set -u
zl=$1; proc=${2:-/proc}
raw=$(mktemp); trap 'rm -f "$raw"' EXIT
"$zl/elfclose" proc "$proc" > "$raw"
echo "# procsnap $(date -u +%Y-%m-%dT%H:%M:%SZ) elfclose $(sha256sum "$zl/elfclose" | cut -c1-16)"
grep '^# ' "$raw"
echo "# owner class verdict count"
awk -F'\t' '$1=="PROC"{o=($3=="self")?"self":"other"; print o"\t"$5"\t"$12}' "$raw" | sort | uniq -c \
  | awk '{print "COUNT\t"$2"\t"$3"\t"$4"\t"$1}'
echo "# group exe verdict producer link processes sha256"
awk -F'\t' -v h="$HOME" '$1=="PROC" && $3=="self" && $5=="ELF64LE" {
  p=$4; if (index(p, h"/")==1) p="~" substr(p, length(h)+1)
  g="";
  if (p ~ /^~\/work\// || p ~ /^~\/workspace\// || p ~ /^\/dev\/shm\// || p ~ /^~\/\.local\/share\// || p ~ /^\/usr\/local\//) g="first-party-candidate"
  if (g=="") next
  m=split(p, q, "/"); s2=(m>1)?q[m-1]"/"q[m]:p
  k=g"\t"s2"\t"$12"\t"$11"\t"$8
  if (!(k in n)) pid[k]=$2
  n[k]++
} END { for (k in n) print k"\t"n[k]"\t"pid[k] }' "$raw" | sort | while IFS='	' read -r g p v pr l c pid; do
  s=$("$zl/sha256" "$proc/$pid/exe" 2>/dev/null | cut -c1-64)
  printf 'EXE\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$g" "$p" "$v" "$pr" "$l" "$c" "${s:--}"
done
