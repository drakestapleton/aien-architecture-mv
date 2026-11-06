#!/bin/sh
# Bootstrap trust boundary, as in tools/capreg/gate.sh: authenticate AIEN_OMC against
# ../../zero-legacy/omega.pin before executing it. Judgments remain in gate.om and rows.om; the
# compiler cannot authenticate itself.
set -eu
cd "$(dirname "$0")"
not_run() { echo "gate.sh: AIEN_OMC is unavailable or not independently pinned (NOT_RUN)" >&2; exit 3; }
[ -n "${AIEN_OMC:-}" ] && [ -x "$AIEN_OMC" ] || not_run
want=$(sed -n 's/^omc_sha256: //p' ../../zero-legacy/omega.pin) || not_run
[ "${#want}" -eq 64 ] || not_run
case "$want" in *[!0-9a-f]*) not_run ;; esac
have=$(sha256sum -- "$AIEN_OMC") || not_run
have=${have%% *}
[ "$have" = "$want" ] || not_run
mkdir -p build
"$AIEN_OMC" < gate.om > build/gate
chmod +x build/gate
exec build/gate "$AIEN_OMC"
