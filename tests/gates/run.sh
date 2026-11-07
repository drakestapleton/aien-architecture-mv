#!/usr/bin/env bash
# tests/gates/run.sh: the one entry point for the local verification gates of aien-architecture.
# Every step runs the SAME command as the hosted job it mirrors (.github/workflows/crumb.yml and
# qualification-status.yml) or the repository's own offline scripts. Manifests under tests/gates/
# name this script plus one step word, so no manifest needs shell expansion (ADR 0028 P6).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
step="${1:?usage: tests/gates/run.sh <step>}"
obs() { printf 'AIEN-OBS %s %s\n' "$1" "$2"; }

case "$step" in
  crumb-verify)
    # Hosted crumb.yml step "Crumbs must be exactly what the compiler produces now", with the
    # same make target. The binary is built in a private copy of tools/crumb, not in place:
    # crumb-tool-test builds and runs tools/crumb/crumb at the same time, and two gates writing
    # and executing one file raced ("Text file busy", failed tool tests; SANDBOX lane 2026-10-11).
    tool=$(mktemp -d)
    trap 'rm -rf "$tool"' EXIT
    cp tools/crumb/Makefile tools/crumb/crumb.c "$tool/"
    make -C "$tool" crumb
    "$tool/crumb" verify .
    ;;
  crumb-tool-test)
    # Hosted crumb.yml step "Build and test the crumb tool".
    make -C tools/crumb test
    ;;
  qualification-status)
    # Hosted qualification-status.yml checks out aien-spark/omega (default branch, unpinned)
    # as omega-evidence and runs the script against it. Locally the sibling ../omega plays
    # that role; its commit is recorded so the receipt says which evidence was read.
    if [ ! -d ../omega/evidence ]; then
      echo "run.sh: ../omega is missing; the hosted job checks out aien-dev/omega as omega-evidence" >&2
      exit 3
    fi
    obs sibling_omega_commit "\"$(git -C ../omega rev-parse HEAD 2>/dev/null || echo unknown)\""
    sh scripts/verify-r16-status.sh ../omega
    ;;
  doctrine)
    # aien-architecture#7 in seeded .om (#316): tools/doctrine/doctrine.om makes every judgment;
    # gate.sh independently checks the compiler pin before invoking AIEN_OMC; gate.om
    # repeats the native hash check and runs the checker on $ROOT. NOT_RUN (exit 3) without the
    # pinned compiler. The retired bash oracle is scripts/check_doctrine.sh before this commit.
    exec sh tools/doctrine/gate.sh "$ROOT"
    ;;
  script-tests)
    # The offline tests of the repository's own operator scripts. Each builds temporary git
    # repos and fake gh/crumb tools under mktemp; no network, no auth (see their headers).
    # The candidate checkers are seeded .om (tools/candidate, #316): their suites and the
    # byte-for-byte parity corpus compile them with the compiler named by AIEN_OMC, which must
    # hash as tools/zero-legacy/omega.pin says; otherwise NOT_RUN (exit 3).
    omc="${AIEN_OMC:-}"
    if [ -z "$omc" ] || [ ! -x "$omc" ]; then
      echo "run.sh: AIEN_OMC is not an executable omc (NOT_RUN)" >&2
      exit 3
    fi
    want=$(sed -n 's/^omc_sha256: //p' tools/zero-legacy/omega.pin)
    have=$(sha256sum "$omc" | cut -d' ' -f1)
    if [ "$have" != "$want" ]; then
      echo "run.sh: AIEN_OMC hashes $have, tools/zero-legacy/omega.pin pins $want (NOT_RUN)" >&2
      exit 3
    fi
    export AIEN_OMC="$omc"
    obs omc_sha256 "\"$have\""
    build=$(mktemp -d)
    trap 'rm -rf "$build"' EXIT
    "$omc" < tools/candidate/check_candidate.om > "$build/check_candidate"
    "$omc" < tools/candidate/check_pins.om > "$build/check_pins"
    chmod +x "$build/check_candidate" "$build/check_pins"
    parity_rc=0
    bash tools/candidate/parity/run.sh "$build/check_candidate" "$build/check_pins" > "$build/parity.log" || parity_rc=$?
    cat "$build/parity.log"
    parity=$(sed -n 's/^parity: //p' "$build/parity.log")
    obs candidate_parity_identical "${parity%% *}"
    obs candidate_parity_naming_deltas "$(printf '%s' "$parity" | sed 's/.*identical, \([0-9]*\) exact naming deltas.*/\1/')"
    obs candidate_parity_limits "$(printf '%s' "$parity" | sed 's/.*deltas, \([0-9]*\) named limits.*/\1/')"
    obs candidate_parity_different "$(printf '%s' "$parity" | sed 's/.*limits, \([0-9]*\) different$/\1/')"
    ext=$(sed -n 's/^extensions: //p' "$build/parity.log")
    obs candidate_extensions_identical "${ext%% *}"
    obs candidate_extensions_different "$(printf '%s' "$ext" | sed 's/.*identical, \([0-9]*\) different$/\1/')"
    [ "$parity_rc" -eq 0 ]
    for t in scripts/test_pr_gate.sh scripts/test_rebase_crumb.sh scripts/test_check_candidate.sh scripts/test_check_candidate_pins.sh; do
      echo "== $t"
      bash "$t"
    done
    obs script_tests_run 4
    ;;
  zero-legacy)
    # #316: gate.sh independently checks the compiler pin before executing AIEN_OMC.
    # Fixture judgments and the additional native hash check live in gate.om.
    # Missing/mismatched compiler remains NOT_RUN (exit 3).
    exec sh tools/zero-legacy/gate.sh
    ;;
  capreg)
    # The org CUDA capability register (docs/capability-register/): every judgment is made by
    # tools/capreg/gate.om (seeded .om), which checks AIEN_OMC against tools/zero-legacy/omega.pin,
    # builds capreg.om, runs its fixtures, verifies register.tsv against REGISTER.md and expects a
    # planted bad row to be refused. NOT_RUN (exit 3) without the pinned compiler.
    exec sh tools/capreg/gate.sh
    ;;
  *)
    echo "run.sh: unknown step '$step'" >&2
    exit 2
    ;;
esac
