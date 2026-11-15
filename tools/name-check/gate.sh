#!/bin/sh
# Bootstrap trust boundary, as in ../doctrine/gate.sh: authenticate AIEN_OMC against
# ../zero-legacy/omega.pin before executing it. The judgments are made in namecheck.om and gate.om;
# this script only selects the change under review and hands its git diff to them.
#   gate.sh ROOT [BASE]   BASE defaults to origin/main when it exists, else HEAD~1; the change is
#                         merge-base(BASE, HEAD)..HEAD.
set -eu
root="${1:?usage: gate.sh ROOT [BASE]}"
base="${2:-}"
cd "$(dirname "$0")"
not_run() { echo "gate.sh: AIEN_OMC is unavailable or not independently pinned (NOT_RUN)" >&2; exit 3; }
[ -n "${AIEN_OMC:-}" ] && [ -x "$AIEN_OMC" ] || not_run
want=$(sed -n 's/^omc_sha256: //p' ../zero-legacy/omega.pin) || not_run
[ "${#want}" -eq 64 ] || not_run
case "$want" in *[!0-9a-f]*) not_run ;; esac
have=$(sha256sum -- "$AIEN_OMC") || not_run
have=${have%% *}
[ "$have" = "$want" ] || not_run
if [ -z "$base" ]; then
  if git -C "$root" rev-parse -q --verify origin/main >/dev/null; then base=origin/main; else base=HEAD~1; fi
fi
mb=$(git -C "$root" merge-base "$base" HEAD) || { echo "gate.sh: no merge base with $base" >&2; exit 2; }
mkdir -p build
# fixed prefixes and no textconv, whatever the user or repository config says (diff.noprefix,
# diff.mnemonicPrefix, textconv drivers): the judge must see the bytes git stores, under b/PATH
git -C "$root" -c core.quotePath=false diff --no-color --no-ext-diff --no-textconv \
  --src-prefix=a/ --dst-prefix=b/ -U0 "$mb" HEAD > build/change.diff
printf 'AIEN-OBS name_check_base "%s"\n' "$mb"
"$AIEN_OMC" < gate.om > build/gate
chmod +x build/gate
[ -s build/gate ] || { echo "gate.sh: AIEN_OMC produced no program from gate.om (NOT_RUN)" >&2; exit 3; }
exec build/gate "$AIEN_OMC" build/change.diff
