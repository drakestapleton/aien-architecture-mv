#!/usr/bin/env bash
# test-spark-cleanup.sh [SPARK_CLEANUP]: offline test of spark-cleanup classes 1, 2, 5 and 8 and of
# --landed, each in a scratch HOME.
# Never touches the real home, ~/git or the team board: HOME, the git store and the board all point
# into a mktemp folder. Cases:
#   c2-store    a worktree whose HEAD is in the scratch ~/git store, no upstream: removed under --apply
#   c2-remote   a worktree whose HEAD was pushed to a bare repo OUTSIDE ~/git (it has an upstream and
#               `branch -r --contains` finds it): must be kept and logged not-in-git-store
#   c8-left     an idle clone whose every branch head is in the store: ALARM leftover-copy
#   c8-unst     an idle clone with a commit not in the store: ALARM unstored-copy
#   c8-dirty    an idle clone with an uncommitted change: ALARM dirty-copy
#   c8-model    a 1.1 GiB sparse .safetensors file under ~/work: ALARM model-copy
#   c8-fresh    a clone written now: no ALARM
#   c8-wt-own   in the dry run the idle worktree wt-store (HEAD in the store) is a leftover-copy, not
#               unstored because a sibling worktree's branch is missing from the store
#   c8-rerun    the alarms of the first (dry) run still fire on the second run: the checks themselves
#               must not rewrite a copy and make it look recently used
#   c8-board    the --apply run writes exactly one ALARM line to the scratch board; a dry run writes none
#   c8-nodel    class 8 deletes nothing
#   c8-stash    an idle clone whose only unsaved work is a stash: unstored-copy, not leftover
#   c8-ignored  an idle clone with results in a git-ignored folder: dirty-copy, not leftover
#   c8-unread   an idle linked worktree whose admin folder is gone (git cannot read it): unreadable-copy
#   c8-nested   an idle clone whose head is only in a nested store repo (git/sub/n.git): leftover-copy
#   c8-hardlink a weight file hard-linked from ~/models (2 links) is not called a copy
#   c8-dedupe   a second --apply run over the same copies adds no second board line
#   c8-badthr   SPARK_CLEANUP_LEFTOVER_ALARM_GB=0.5 is reported loudly, not a shell error
#   c8-nolock   with a quiet-build in the scratch home, an --apply run gives the locked run classes
#               without 8 and runs class 8 afterwards on its own (classes=8 line, after quiet-build ended)
#   store-empty an empty store gives the loud "holds no bare repositories" ALARM and one board line,
#               not a second one on the next run
#   c8-emerg    with free space under 10 % an --apply run still runs class 8 on its own, after the rest
#   c8-main     main clones (no '-' in the name, real .git folder) are still checked: the clean one
#               ~/workspace/ref is a SKIP main-clone line, ~/workspace/proj (branches not in the store) is an
#               ALARM marked "main clone"
#   c8-drymark  a dry --classes 8 run neither reads nor writes the --apply scan's start and finish marks
#   c2-nested   an idle clean worktree holding a repository in an ignored folder (.lake/packages/dep) is kept
#   c2-untracked a worktree whose status.showUntrackedFiles=no hides notes.txt: kept, file unchanged
#   c2-ignored  the same setting hides an ignored secret/: kept, file unchanged
#   c2-skipwt   a skip-worktree edit that status does not show: kept, the edit unchanged
#   c2-assume   an assume-unchanged edit that status does not show: kept, the edit unchanged
#   c2-bare     a bare repo .lake/packages/dep.git whose commit is not in ~/git: kept, not leftover
#   c8-nestbad  a nested repo in an ignored build/, one in .lake, and a submodule commit, none of them
#               in ~/git: unstored, not leftover, and the files still there
#   c8-remoteref a commit reachable only from refs/remotes/other/main, not in ~/git: unstored, not leftover
#   c8-fourbit  ~/work/hive/uxl-brief-20261113/FourBit is not deleted and not named for removal.
#               A verified cargo target under ~/handoffs/hive/factory-bays is removed; one under
#               evidence, and a plain file under ~/handoffs, stays.
#   c8-inner    an idle repository inside a copy that is in use now is not reported on its own
#   c8-hook     the test in-use hook says in the log that it was used
#   c8-agentwt  an idle linked worktree inside the main clone (proj/.claude/worktrees/agent-x) is reported
#   c8-dashwt   an idle linked worktree ~/workspace/kflow (no '-', but not a main clone) is reported
#   c8-unfin    a class 8 scan that started and never finished gives a loud ALARM and one board line
#   c8-maxh     SPARK_CLEANUP_CLASS8_MAX_H=1.5 is reported loudly, not a shell error
#   c8-only8    --apply --classes 8 does not go through quiet-build (no deleting run to lock)
#   c8-help     --help prints the whole header, through the Usage section
#   f1-bare-c2  a worktree holding a bare repository not named *.git (.lake/packages/dep): kept, unstored
#   f1-bare-c8  a clone holding such a bare repository: unstored-copy, the repository still there
#   f1-bare-c1  a cargo cache holding a bare repository named vendor: class 1 SKIP has-git
#   f2-subbranch a clone whose submodule has a branch not in ~/git (HEAD back on main): unstored-copy
#   f3-nestfile a clone whose nested checkout .lake/packages/dep has an untracked notes.txt: dirty-copy
#   f4-mode     an assume-unchanged file whose only change is the executable bit: worktree kept
#   f5-mktemp   TMPDIR that does not exist: loud ALARM, non-zero exit, nothing removed
#   --landed lrepo (own scratch home, ~/git/lrepo.git landed):
#   ld-exit     exit 0, nothing on stdout or stderr, one summary line: removed 4, archived 2, kept 7
#   ld-saved    a saved idle clone (an old CLAIM 30 days back, a fresh FETCH_HEAD) is removed
#   ld-root     a saved clone with no remote, matched by its root commit, is removed
#   ld-recent   a saved clone with a file written now is kept (written in the last 6 h)
#   ld-open     a saved clone that is a running process's working folder is kept (open)
#   ld-claim    a clone named by a current CLAIM line on the board is kept
#   ld-claims   a clone inside ~/work/lane2, a folder claimed in ~/handoffs/hive/CLAIMS.md ("~/work/lane2:"), is kept
#   ld-dashmain the dashed main clone ~/workspace/ld-main (store ld-main-mv.git, same root commit) is kept,
#               while the dashed task copy ~/workspace/task-lrepo is removed
#   ld-unsaved-recent a clone with a commit not in ~/git, written 1 day ago, is kept, not archived
#   ld-other    a clone of another repository is not looked at
#   ld-main     the main clone ~/workspace/lrepo is kept
#   ld-handoffs a clone under ~/handoffs is not looked at
#   ld-wt       a saved linked worktree with an ignored target/ is removed and pruned
#   ld-archive  an unsaved idle clone is archived, replaced by ARCHIVED.txt, and its restore line
#               brings back the commit and the untracked file
#   ld-wtarch   an unsaved idle linked worktree (detached commit, dirty file) is archived with a
#               bundle of its HEAD; after gc in the main clone, the one restore line brings it back
#   ld-badname  --landed '../x' is a loud ALARM and does nothing
#   --landed, second scratch home with no ~/handoffs/hive/CLAIMS.md (three landings: lrepo, brepo with a huge
#   archive reserve, orepo); the board's CLAIM lines count although the other claim file is missing:
#   l2-rootclaim a CLAIM of ~/work, ~/workspace/ and ~/.claude/jobs is not used: the saved idle copy under it
#               is removed and the log names the claim in an ALARM
#   l2-rootboard that claim is one ALARM line on the board, not repeated at the next two landings, and that
#               ALARM line is not itself read as a claim (no lane "?" naming the folders; still 2 claimed paths)
#   l2-release  a copy claimed by LaneR and then released by LaneR is removed
#   l2-otherlane a copy claimed by LaneS stays when only LaneT posts a RELEASE
#   l2-relfirst a copy claimed by LaneU after an earlier RELEASE of LaneU stays
#   l2-pending  a saved copy written now is kept and listed in landed-pending; the next landing (of brepo)
#               looks at it again; once it is idle the landing of orepo removes it ([kept at an earlier landing])
#   l2-buildout an unsaved idle copy is archived without its ignored cargo target/, ARCHIVED.txt names it
#               in a "left out" line, and an ignored .lake/ holding an unsaved nested repository stays in
#   l2-noroom   with SPARK_CLEANUP_ARCHIVE_RESERVE_GB=999999999 an unsaved idle copy stays, with a "not enough
#               free space" ALARM, and is listed in landed-pending
#   l2-recheck  the landing of orepo, with the default reserve, archives that copy; landed-pending then
#               lists only the copies still claimed
#   class 5 (own scratch home, a scratch folder in place of /tmp, SPARK_CLEANUP_TMP_MAX=1 ignored):
#   c5-hook     the test hook says class 5 read the scratch folder
#   c5-unsaved  a /tmp clone with a commit not in ~/git stays: class5 SKIP unsaved naming the commit
#   c5-nested   a /tmp folder holding a clone with an untracked file stays
#   c5-saved    a saved /tmp clone over the old size cap goes, no over-cap line
#   c5-junk     a /tmp folder with no repository goes
#   c5-bigalarm one ALARM line names each entry over SPARK_CLEANUP_BIG_ALARM, removed or kept, not the small one
# Then mutants of spark-cleanup must each make at least one case fail.
# Ends `TEST PASS cases=N mutants=M/M` (exit 0) or `TEST FAIL ...` (exit 1).
set -u
here=$(cd "$(dirname "$0")" && pwd)
sc=${1:-$here/spark-cleanup}
[ -f "$sc" ] || { echo "TEST FAIL no spark-cleanup at $sc" >&2; exit 2; }
top=$(mktemp -d) || exit 2
[ -n "${KEEP:-}" ] || trap 'rm -rf "$top"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_TERMINAL_PROMPT=0
unset GIT_DIR GIT_WORK_TREE
# nothing in the scratch home is open by another process; skip the machine-wide scan
: > "$top/inuse"; export SPARK_CLEANUP_TEST_INUSE_FILE="$top/inuse"

setup() {  # $1 scratch home
  local h=$1
  mkdir -p "$h/git" "$h/workspace" "$h/work/lane" "$h/elsewhere" "$h/handoffs"
  : > "$h/handoffs/BOARD.md"
  git init -q -b main "$h/workspace/proj"
  echo a > "$h/workspace/proj/a"; git -C "$h/workspace/proj" add a; git -C "$h/workspace/proj" commit -qm a
  git clone -q --bare "$h/workspace/proj" "$h/git/proj.git"
  # c2-store: worktree at a commit the store has, no upstream
  git -C "$h/workspace/proj" worktree add -q -b wt-store "$h/workspace/wt-store" main
  # c2-remote: worktree with a new commit pushed only to a bare repo outside ~/git
  git clone -q --bare "$h/workspace/proj" "$h/elsewhere/other.git"
  git -C "$h/workspace/proj" remote add other "$h/elsewhere/other.git"
  git -C "$h/workspace/proj" worktree add -q -b wt-remote "$h/workspace/wt-remote" main
  echo b > "$h/workspace/wt-remote/b"; git -C "$h/workspace/wt-remote" add b; git -C "$h/workspace/wt-remote" commit -qm b
  git -C "$h/workspace/wt-remote" push -q -u other wt-remote 2>/dev/null
  # class 8 clones
  git clone -q "$h/git/proj.git" "$h/work/lane/left"
  git clone -q "$h/git/proj.git" "$h/work/lane/unst"
  echo c > "$h/work/lane/unst/c"; git -C "$h/work/lane/unst" add c; git -C "$h/work/lane/unst" commit -qm c
  git clone -q "$h/git/proj.git" "$h/work/lane/dirty"; echo x >> "$h/work/lane/dirty/a"
  git clone -q "$h/git/proj.git" "$h/work/lane/stash"; echo s >> "$h/work/lane/stash/a"; git -C "$h/work/lane/stash" stash -q
  git clone -q "$h/git/proj.git" "$h/work/lane/ign"; mkdir -p "$h/work/lane/ign/secret"; echo r > "$h/work/lane/ign/secret/results"
  echo secret/ >> "$h/work/lane/ign/.git/info/exclude"
  git clone -q "$h/git/proj.git" "$h/workspace/ref"
  echo .lake/ >> "$h/workspace/proj/.git/info/exclude"
  git -C "$h/workspace/proj" worktree add -q -b wt-nest "$h/workspace/wt-nest" main
  git init -q -b main "$h/workspace/wt-nest/.lake/packages/dep"
  echo d > "$h/workspace/wt-nest/.lake/packages/dep/d"
  git -C "$h/workspace/wt-nest/.lake/packages/dep" add d
  git -C "$h/workspace/wt-nest/.lake/packages/dep" commit -qm d
  git -C "$h/workspace/proj" worktree add -q -b agent-x "$h/workspace/proj/.claude/worktrees/agent-x" main
  git -C "$h/workspace/proj" worktree add -q -b kflow "$h/workspace/kflow" main
  git -C "$h/workspace/proj" worktree add -q -b wt-orphan "$h/work/lane/orphan" main
  echo z > "$h/work/lane/orphan/z"; git -C "$h/work/lane/orphan" add z; git -C "$h/work/lane/orphan" commit -qm z
  rm -rf "$h/workspace/proj/.git/worktrees/orphan"
  mkdir -p "$h/git/sub" "$h/work/lane/nested-src"; git init -q -b main "$h/work/lane/nested-src"
  echo n > "$h/work/lane/nested-src/n"; git -C "$h/work/lane/nested-src" add n; git -C "$h/work/lane/nested-src" commit -qm n
  git clone -q --bare "$h/work/lane/nested-src" "$h/git/sub/n.git"; rm -rf "$h/work/lane/nested-src"
  git clone -q "$h/git/sub/n.git" "$h/work/lane/nested"

  mkdir -p "$h/work/lane/weights"; truncate -s 1100M "$h/work/lane/weights/m.safetensors"
  mkdir -p "$h/models"; truncate -s 1100M "$h/models/w.gguf"; ln "$h/models/w.gguf" "$h/work/lane/weights/linked.gguf"
  # hidden from a plain git status: untracked, ignored, and a skip-worktree edit. HEAD is in the store.
  git init -q -b main "$h/workspace/hide-repo"
  echo a > "$h/workspace/hide-repo/a"; git -C "$h/workspace/hide-repo" add a; git -C "$h/workspace/hide-repo" commit -qm a
  git clone -q --bare "$h/workspace/hide-repo" "$h/git/hide.git"
  git -C "$h/workspace/hide-repo" worktree add -q -b wt-untracked "$h/workspace/wt-untracked" main
  git -C "$h/workspace/hide-repo" worktree add -q -b wt-ignored "$h/workspace/wt-ignored" main
  git -C "$h/workspace/hide-repo" config status.showUntrackedFiles no
  echo notes > "$h/workspace/wt-untracked/notes.txt"
  mkdir -p "$h/workspace/wt-ignored/secret"; echo z > "$h/workspace/wt-ignored/secret/z"
  echo secret/ >> "$h/workspace/hide-repo/.git/info/exclude"
  git init -q -b main "$h/workspace/skip-repo"
  echo a > "$h/workspace/skip-repo/a"; git -C "$h/workspace/skip-repo" add a; git -C "$h/workspace/skip-repo" commit -qm a
  git clone -q --bare "$h/workspace/skip-repo" "$h/git/skip.git"
  git -C "$h/workspace/skip-repo" worktree add -q -b wt-skip "$h/workspace/wt-skip" main
  git -C "$h/workspace/wt-skip" update-index --skip-worktree a
  echo edited >> "$h/workspace/wt-skip/a"
  git -C "$h/workspace/skip-repo" worktree add -q -b wt-assume "$h/workspace/wt-assume" main
  git -C "$h/workspace/wt-assume" update-index --assume-unchanged a
  echo edited >> "$h/workspace/wt-assume/a"
  # bare repository inside an ignored .lake/, commit not in the store
  git -C "$h/workspace/proj" worktree add -q -b wt-bare "$h/workspace/wt-bare" main
  git init -q -b main "$h/elsewhere/bare-src"
  echo only > "$h/elsewhere/bare-src/only"
  git -C "$h/elsewhere/bare-src" add only; git -C "$h/elsewhere/bare-src" commit -qm only
  mkdir -p "$h/workspace/wt-bare/.lake/packages"
  git clone -q --bare "$h/elsewhere/bare-src" "$h/workspace/wt-bare/.lake/packages/dep.git"
  rm -rf "$h/elsewhere/bare-src"
  # nested repository inside an ignored build/, commit not in the store; the parent commit is
  git clone -q "$h/git/proj.git" "$h/work/lane/outer"
  printf 'build/\n' >> "$h/work/lane/outer/.gitignore"
  git -C "$h/work/lane/outer" add .gitignore; git -C "$h/work/lane/outer" commit -qm gi
  git -C "$h/work/lane/outer" push -q origin HEAD:main
  git init -q -b main "$h/work/lane/outer/build/mywork"
  echo w > "$h/work/lane/outer/build/mywork/w"
  git -C "$h/work/lane/outer/build/mywork" add w; git -C "$h/work/lane/outer/build/mywork" commit -qm w
  # submodule whose commit object lives only inside the clone
  git init -q -b main "$h/elsewhere/dep-src"
  echo d > "$h/elsewhere/dep-src/d"; git -C "$h/elsewhere/dep-src" add d; git -C "$h/elsewhere/dep-src" commit -qm d
  git clone -q "$h/git/proj.git" "$h/work/lane/super"
  git -C "$h/work/lane/super" -c protocol.file.allow=always submodule add -q "$h/elsewhere/dep-src" dep
  git -C "$h/work/lane/super" commit -qm sub
  git -C "$h/work/lane/super" push -q origin HEAD:main
  rm -rf "$h/elsewhere/dep-src"
  # commit reachable only from a remote-tracking ref
  git clone -q "$h/git/proj.git" "$h/work/lane/rem"
  git -C "$h/work/lane/rem" commit -q --allow-empty -m extra
  git -C "$h/work/lane/rem" update-ref refs/remotes/other/main HEAD
  git -C "$h/work/lane/rem" reset -q --hard origin/main
  # FourBit is excluded whole. A verified cargo target under factory-bays may go;
  # one under evidence, and any other file under handoffs, stays.
  local fb="$h/work/hive/uxl-brief-20261113/FourBit" bay="$h/handoffs/hive/factory-bays/job"
  mkdir -p "$fb/target/debug" "$bay/target/debug" "$bay/evidence/target/debug"
  printf 'Signature: 8a477f597d28d172789f06886806bc55\n' > "$fb/target/CACHEDIR.TAG"
  echo only > "$fb/target/ONLY-COPY.txt"; echo keep > "$fb/keep.txt"
  git clone -q "$h/git/proj.git" "$fb/checkout"
  printf 'Signature: 8a477f597d28d172789f06886806bc55\n' > "$bay/target/CACHEDIR.TAG"
  echo rebuild > "$bay/target/rebuild.txt"
  printf 'Signature: 8a477f597d28d172789f06886806bc55\n' > "$bay/evidence/target/CACHEDIR.TAG"
  echo keep > "$bay/evidence/target/keep.txt"
  echo keep > "$h/handoffs/keep.txt"
  # f1: bare repositories whose folder name does not end in .git, holding a commit in no store repo
  git init -q -b main "$h/elsewhere/nb-src"
  echo nb > "$h/elsewhere/nb-src/nb"; git -C "$h/elsewhere/nb-src" add nb; git -C "$h/elsewhere/nb-src" commit -qm nb
  git -C "$h/workspace/proj" worktree add -q -b wt-barenose "$h/workspace/wt-barenose" main
  mkdir -p "$h/workspace/wt-barenose/.lake/packages"
  git clone -q --bare "$h/elsewhere/nb-src" "$h/workspace/wt-barenose/.lake/packages/dep"
  git init -q -b main "$h/elsewhere/fx-src"
  echo f > "$h/elsewhere/fx-src/f"; git -C "$h/elsewhere/fx-src" add f; git -C "$h/elsewhere/fx-src" commit -qm f
  git clone -q --bare "$h/elsewhere/fx-src" "$h/git/fx.git"; rm -rf "$h/elsewhere/fx-src"
  git clone -q "$h/git/fx.git" "$h/work/lane/baren"; echo .lake/ >> "$h/work/lane/baren/.git/info/exclude"
  mkdir -p "$h/work/lane/baren/.lake/packages"
  git clone -q --bare "$h/elsewhere/nb-src" "$h/work/lane/baren/.lake/packages/dep"
  mkdir -p "$bay/cache-nosuffix/debug"
  printf 'Signature: 8a477f597d28d172789f06886806bc55\n' > "$bay/cache-nosuffix/CACHEDIR.TAG"
  git clone -q --bare "$h/elsewhere/nb-src" "$bay/cache-nosuffix/vendor"
  rm -rf "$h/elsewhere/nb-src"
  # f2: a submodule whose checked-out commit is stored, but whose branch wip is in no store repo
  git init -q -b main "$h/elsewhere/d2-src"
  echo e > "$h/elsewhere/d2-src/e"; git -C "$h/elsewhere/d2-src" add e; git -C "$h/elsewhere/d2-src" commit -qm e
  git clone -q --bare "$h/elsewhere/d2-src" "$h/git/dep2.git"; rm -rf "$h/elsewhere/d2-src"
  git clone -q "$h/git/fx.git" "$h/work/lane/super2"
  git -C "$h/work/lane/super2" -c protocol.file.allow=always submodule add -q "$h/git/dep2.git" dep
  git -C "$h/work/lane/super2" commit -qm sub2; git -C "$h/work/lane/super2" push -q origin HEAD:main
  git -C "$h/work/lane/super2/dep" checkout -q -b wip; git -C "$h/work/lane/super2/dep" commit -q --allow-empty -m wip
  git -C "$h/work/lane/super2/dep" checkout -q main
  # f3: a nested repository in an ignored .lake/, every commit stored, an untracked file inside it
  git init -q -b main "$h/elsewhere/nf-src"
  echo n > "$h/elsewhere/nf-src/n"; git -C "$h/elsewhere/nf-src" add n; git -C "$h/elsewhere/nf-src" commit -qm n
  git clone -q --bare "$h/elsewhere/nf-src" "$h/git/nf.git"; rm -rf "$h/elsewhere/nf-src"
  git clone -q "$h/git/fx.git" "$h/work/lane/nestfile"; echo .lake/ >> "$h/work/lane/nestfile/.git/info/exclude"
  git clone -q "$h/git/nf.git" "$h/work/lane/nestfile/.lake/packages/dep"
  echo mine > "$h/work/lane/nestfile/.lake/packages/dep/notes.txt"
  # f4: an assume-unchanged file whose bytes are stored but whose executable bit was turned on
  git -C "$h/workspace/skip-repo" worktree add -q -b wt-mode "$h/workspace/wt-mode" main
  git -C "$h/workspace/wt-mode" update-index --assume-unchanged a; chmod +x "$h/workspace/wt-mode/a"
  find "$h/workspace" "$h/work" "$h/elsewhere" "$h/handoffs" -exec touch -h -d '5 days ago' {} + 2>/dev/null
  git clone -q "$h/git/proj.git" "$h/work/lane/fresh"
  # c8-inner: a copy in use now (fresh files) holding an idle clone
  git clone -q "$h/git/proj.git" "$h/work/lane/active"; git clone -q "$h/git/proj.git" "$h/work/lane/active/sub/inner"
  find "$h/work/lane/active/sub" -exec touch -h -d '5 days ago' {} +
}

run() {  # $1 home, $2 spark-cleanup copy, rest: args; prints the log
  local h=$1 s=$2; shift 2
  HOME=$h SPARK_CLEANUP_QUIET=1 SPARK_CLEANUP_OFFLINE=1 SPARK_CLEANUP_GITSTORE=$h/git SPARK_CLEANUP_BOARD=$h/handoffs/BOARD.md \
    SPARK_CLEANUP_PROTECT=none-protected SPARK_CLEANUP_DRY_CLASSES= bash "$s" "$@" > "$h/out.txt" 2>&1
}

pass=0 fail=0
check() {  # $1 case name, $2 0|1 result (0 = holds)
  if [ "$2" = 0 ]; then pass=$((pass+1)); [ -n "${quiet:-}" ] || echo "PASS $1"; else fail=$((fail+1)); [ -n "${quiet:-}" ] || echo "FAIL $1"; fi
}
has() { grep -qE -- "$2" "$1"; }

# --landed lrepo in its own scratch home: which copies of the landed repository go, which are
# archived, which stay, and that an archive restores the unsaved work
landed_cases() {  # $1 spark-cleanup copy
  local s=$1 h n uc wc lrc sp i A
  h=$(mktemp -d "$top/l.XXXX")
  mkdir -p "$h/git" "$h/workspace" "$h/work/lane" "$h/work/lane2" "$h/handoffs/land" "$h/handoffs/hive" "$h/elsewhere"
  git init -q -b main "$h/workspace/lrepo"
  echo a > "$h/workspace/lrepo/a"; git -C "$h/workspace/lrepo" add a; git -C "$h/workspace/lrepo" commit -qm a
  git clone -q --bare "$h/workspace/lrepo" "$h/git/lrepo.git"
  git -C "$h/workspace/lrepo" remote add origin "$h/git/lrepo.git"; git -C "$h/workspace/lrepo" fetch -q origin
  echo target/ >> "$h/workspace/lrepo/.git/info/exclude"
  git init -q -b main "$h/elsewhere/o"
  echo o > "$h/elsewhere/o/o"; git -C "$h/elsewhere/o" add o; git -C "$h/elsewhere/o" commit -qm o
  git clone -q --bare "$h/elsewhere/o" "$h/git/orepo.git"; rm -rf "$h/elsewhere/o"
  for n in saved-idle saved-noremote saved-recent saved-open claimed unsaved-old unsaved-recent; do
    git clone -q "$h/git/lrepo.git" "$h/work/lane/$n"
  done
  git clone -q "$h/git/lrepo.git" "$h/work/lane2/child"
  git clone -q --bare "$h/git/lrepo.git" "$h/git/ld-main-mv.git"
  git clone -q "$h/git/ld-main-mv.git" "$h/workspace/ld-main"
  git clone -q "$h/git/lrepo.git" "$h/workspace/task-lrepo"
  printf '%s | CLAIM | lane-y | isolated ~/work/lane2: host only\n' "$(date -u +%FT%H:%M:%SZ)" > "$h/handoffs/hive/CLAIMS.md"
  git -C "$h/work/lane/saved-noremote" remote remove origin
  echo u > "$h/work/lane/unsaved-old/u"; git -C "$h/work/lane/unsaved-old" add u; git -C "$h/work/lane/unsaved-old" commit -qm u
  uc=$(git -C "$h/work/lane/unsaved-old" rev-parse HEAD); echo mine > "$h/work/lane/unsaved-old/notes.txt"
  git -C "$h/work/lane/unsaved-recent" commit -q --allow-empty -m r
  git clone -q "$h/git/orepo.git" "$h/work/lane/other"
  git clone -q "$h/git/lrepo.git" "$h/handoffs/land/x"
  git -C "$h/workspace/lrepo" worktree add -q --detach "$h/work/lane/wt-saved" main
  mkdir -p "$h/work/lane/wt-saved/target/debug"; echo o > "$h/work/lane/wt-saved/target/debug/o"
  git -C "$h/workspace/lrepo" worktree add -q --detach "$h/work/lane/wt-unsaved" main
  echo w > "$h/work/lane/wt-unsaved/w"; git -C "$h/work/lane/wt-unsaved" add w; git -C "$h/work/lane/wt-unsaved" commit -qm w
  wc=$(git -C "$h/work/lane/wt-unsaved" rev-parse HEAD); echo dirty > "$h/work/lane/wt-unsaved/d"
  printf '%s CLAIM omp lane-x ~/work/lane/claimed for a test\n' "$(date -u +%FT%H:%M:%SZ)" > "$h/handoffs/BOARD.md"
  printf '%s CLAIM omp lane-old ~/work/lane/saved-idle long ago\n' "$(date -u -d '30 days ago' +%FT%H:%M:%SZ)" >> "$h/handoffs/BOARD.md"
  find "$h/workspace" "$h/work" "$h/handoffs/land" -exec touch -h -d '5 days ago' {} +
  touch "$h/work/lane/saved-recent/a" "$h/work/lane/saved-idle/.git/FETCH_HEAD"
  find "$h/work/lane/unsaved-recent" -exec touch -h -d '1 day ago' {} +
  # a real process with its working folder in saved-open, as the in-use list
  (cd "$h/work/lane/saved-open" && exec sleep 600) & sp=$!
  for i in $(seq 50); do [ "$(readlink "/proc/$sp/cwd" 2>/dev/null)" = "$h/work/lane/saved-open" ] && break; sleep 0.1; done
  readlink "/proc/$sp/cwd" > "$h/inuse"
  HOME=$h SPARK_CLEANUP_QUIET=1 SPARK_CLEANUP_OFFLINE=1 SPARK_CLEANUP_GITSTORE=$h/git SPARK_CLEANUP_BOARD=$h/handoffs/BOARD.md \
    SPARK_CLEANUP_PROTECT=none-protected SPARK_CLEANUP_TEST_INUSE_FILE=$h/inuse bash "$s" --landed lrepo > "$h/out.txt" 2>&1; lrc=$?
  kill "$sp" 2>/dev/null; wait "$sp" 2>/dev/null
  cat "$h"/.local/state/spark-cleanup/*.log > "$h/l1.txt"
  HOME=$h SPARK_CLEANUP_QUIET=1 SPARK_CLEANUP_OFFLINE=1 SPARK_CLEANUP_GITSTORE=$h/git SPARK_CLEANUP_BOARD=$h/handoffs/BOARD.md \
    SPARK_CLEANUP_TEST_INUSE_FILE=$h/inuse bash "$s" --landed '../x' > "$h/out2.txt" 2>&1
  cat "$h"/.local/state/spark-cleanup/*.log > "$h/l2.txt"
  local L="$h/l1.txt" W="$h/work/lane"
  check ld-exit "$( [ "$lrc" = 0 ] && [ ! -s "$h/out.txt" ] && has "$L" "landed lrepo done: removed 4, archived 2, kept 7"; echo $?)"
  check ld-saved "$( [ ! -e "$W/saved-idle" ] && has "$L" "landed REMOVED .*$W/saved-idle "; echo $?)"
  check ld-root "$( [ ! -e "$W/saved-noremote" ] && has "$L" "landed REMOVED .*$W/saved-noremote "; echo $?)"
  check ld-recent "$( [ -f "$W/saved-recent/a" ] && has "$L" "landed KEEP $W/saved-recent \(written in the last 6 h\)"; echo $?)"
  check ld-open "$( [ -f "$W/saved-open/a" ] && has "$L" "landed KEEP $W/saved-open \(open by a running process\)"; echo $?)"
  check ld-claim "$( [ -f "$W/claimed/a" ] && has "$L" "landed KEEP $W/claimed \(claimed"; echo $?)"
  check ld-claims "$( [ -f "$h/work/lane2/child/a" ] && has "$L" "landed KEEP $h/work/lane2/child \(claimed"; echo $?)"
  check ld-dashmain "$( [ -f "$h/workspace/ld-main/a" ] && has "$L" "landed KEEP $h/workspace/ld-main \(main clone\)" \
    && [ ! -e "$h/workspace/task-lrepo" ] && has "$L" "landed REMOVED .*$h/workspace/task-lrepo "; echo $?)"
  check ld-unsaved-recent "$( [ -d "$W/unsaved-recent/.git" ] && [ ! -e "$W/unsaved-recent/ARCHIVED.txt" ] && has "$L" "landed KEEP $W/unsaved-recent \(unsaved"; echo $?)"
  check ld-other "$( [ -f "$W/other/o" ] && ! has "$L" "$W/other"; echo $?)"
  check ld-main "$( [ -d "$h/workspace/lrepo/.git" ] && has "$L" "landed KEEP $h/workspace/lrepo \(main clone\)"; echo $?)"
  check ld-handoffs "$( [ -d "$h/handoffs/land/x/.git" ] && ! has "$L" "handoffs/land"; echo $?)"
  check ld-wt "$( [ ! -e "$W/wt-saved" ] && [ ! -e "$h/workspace/lrepo/.git/worktrees/wt-saved" ] && has "$L" "landed REMOVED .*$W/wt-saved "; echo $?)"
  # the archived clone: only ARCHIVED.txt is left; its restore line brings back the commit and the file
  A=$(sed -n 's/^archive: //p' "$W/unsaved-old/ARCHIVED.txt" 2>/dev/null)
  check ld-archive "$( [ -f "$A" ] && [ "$(ls -A "$W/unsaved-old")" = ARCHIVED.txt ] && has "$L" "landed ARCHIVED .*$W/unsaved-old -> $A" \
    && (eval "$(sed -n 's/^restore: //p' "$W/unsaved-old/ARCHIVED.txt")") && git -C "$W/unsaved-old" cat-file -e "$uc" \
    && [ "$(cat "$W/unsaved-old/notes.txt")" = mine ] && [ ! -e "$W/unsaved-old/ARCHIVED.txt" ]; echo $?)"
  # the archived worktree: its detached commit is gone from the main clone after gc; the one restore line brings it back
  git -C "$h/workspace/lrepo" reflog expire --expire=now --all; git -C "$h/workspace/lrepo" gc -q --prune=now
  check ld-wtarch "$( [ -f "$W/wt-unsaved/ARCHIVED.txt" ] && ! git -C "$h/workspace/lrepo" cat-file -e "$wc" 2>/dev/null \
    && (eval "$(sed -n 's/^restore: //p' "$W/wt-unsaved/ARCHIVED.txt")") \
    && [ "$(git -C "$W/wt-unsaved" rev-parse HEAD)" = "$wc" ] && git -C "$W/wt-unsaved" cat-file -e "$wc" && [ "$(cat "$W/wt-unsaved/d")" = dirty ] \
    && [ -z "$(git -C "$W/wt-unsaved" status --porcelain -uno -- w)" ] && [ ! -e "$W/wt-unsaved.HEAD.bundle" ] && [ ! -e "$W/wt-unsaved/ARCHIVED.txt" ]; echo $?)"
  check ld-badname "$(has "$h/l2.txt" "landed ALARM bad repository name '\.\./x'"; echo $?)"
}

# --landed in a second scratch home: CLAIM/RELEASE, root-folder claims, copies kept for a passing reason
# looked at again at later landings, build output left out of archives, and the free-space check
landed2_cases() {  # $1 spark-cleanup copy
  local s=$1 h n W A P L1 L2 L3 now
  h=$(mktemp -d "$top/l2.XXXX"); W="$h/work"; P="$h/.local/state/spark-cleanup/landed-pending"
  mkdir -p "$h/git" "$h/workspace" "$W" "$h/handoffs/hive" "$h/src"
  for n in lrepo brepo orepo; do
    git init -q -b main "$h/src/$n"; echo "$n" > "$h/src/$n/f"; git -C "$h/src/$n" add f; git -C "$h/src/$n" commit -qm "$n"
    git clone -q --bare "$h/src/$n" "$h/git/$n.git"
  done
  rm -rf "$h/src"
  for n in rootlane/idle relr/cr rels/cs relu/cu fresh/cf arch/ca; do git clone -q "$h/git/lrepo.git" "$W/$n"; done
  git clone -q "$h/git/brepo.git" "$W/big/cb"
  echo u > "$W/arch/ca/u"; git -C "$W/arch/ca" add u; git -C "$W/arch/ca" commit -qm u
  printf 'target/\n.lake/\n' >> "$W/arch/ca/.git/info/exclude"
  mkdir -p "$W/arch/ca/target/debug"; echo o > "$W/arch/ca/target/debug/o"
  printf 'Signature: 8a477f597d28d172789f06886806bc55\n' > "$W/arch/ca/target/CACHEDIR.TAG"
  git init -q -b main "$W/arch/ca/.lake/packages/dep"; echo d > "$W/arch/ca/.lake/packages/dep/d"
  git -C "$W/arch/ca/.lake/packages/dep" add d; git -C "$W/arch/ca/.lake/packages/dep" commit -qm d
  echo b > "$W/big/cb/b"; git -C "$W/big/cb" add b; git -C "$W/big/cb" commit -qm b
  now=$(date -u +%FT%H:%M:%SZ)
  {
    printf '%s CLAIM omp RootLane sweeping ~/work, ~/workspace/ and ~/.claude/jobs\n' "$now"
    printf '%s RELEASE LaneU earlier work\n' "$now"
    printf '%s CLAIM omp LaneR ~/work/relr for a test\n' "$now"
    printf '%s CLAIM omp LaneS ~/work/rels for a test\n' "$now"
    printf '%s CLAIM omp LaneU ~/work/relu for a test\n' "$now"
    printf '%s RELEASE omp LaneR done\n' "$now"
    printf '%s LaneT RELEASE ~/work/rels\n' "$now"
  } > "$h/handoffs/BOARD.md"
  find "$W" -exec touch -h -d '5 days ago' {} +
  find "$W/fresh/cf" -exec touch -h {} +
  l2run() {  # $1 repo, rest: extra environment assignments for this landing
    local repo=$1; shift
    env "$@" HOME=$h SPARK_CLEANUP_QUIET=1 SPARK_CLEANUP_OFFLINE=1 SPARK_CLEANUP_GITSTORE=$h/git \
      SPARK_CLEANUP_BOARD=$h/handoffs/BOARD.md SPARK_CLEANUP_PROTECT=none-protected SPARK_CLEANUP_TEST_INUSE_FILE=$h/inuse \
      bash "$s" --landed "$repo" > "$h/out.txt" 2>&1
  }
  : > "$h/inuse"
  l2run lrepo; cat "$h"/.local/state/spark-cleanup/*.log > "$h/r1.txt"; cp "$P" "$h/p1.txt" 2>/dev/null
  l2run brepo SPARK_CLEANUP_ARCHIVE_RESERVE_GB=999999999
  cat "$h"/.local/state/spark-cleanup/*.log | tail -n +$(( $(wc -l < "$h/r1.txt") + 1 )) > "$h/r2.txt"; cp "$P" "$h/p2.txt" 2>/dev/null
  find "$W/fresh/cf" -exec touch -h -d '5 days ago' {} +
  l2run orepo
  cat "$h"/.local/state/spark-cleanup/*.log | tail -n +$(( $(wc -l < "$h/r1.txt") + $(wc -l < "$h/r2.txt") + 1 )) > "$h/r3.txt"
  L1="$h/r1.txt" L2="$h/r2.txt" L3="$h/r3.txt"
  check l2-rootclaim "$( [ ! -e "$W/rootlane/idle" ] && has "$L1" "landed REMOVED .*$W/rootlane/idle " \
    && has "$L1" "landed ALARM CLAIM of a whole copy folder not used .*RootLane names $h/work[;\$]" \
    && has "$L1" "RootLane names $h/workspace" && has "$L1" "RootLane names $h/.claude/jobs"; echo $?)"
  check l2-rootboard "$( [ "$(grep -c 'ALARM spark-cleanup --landed to all: a claim line names a whole copy folder' "$h/handoffs/BOARD.md")" = 1 ] \
    && has "$L2" "landed ALARM CLAIM of a whole copy folder" && has "$L3" "root-claim board line not repeated" \
    && ! grep -qF ' ? names ' "$L2" "$L3" && has "$L3" "landed: 2 claimed path\(s\) "; echo $?)"
  check l2-release "$( [ ! -e "$W/relr/cr" ] && has "$L1" "landed REMOVED .*$W/relr/cr "; echo $?)"
  check l2-otherlane "$( [ -f "$W/rels/cs/f" ] && has "$L1" "landed KEEP $W/rels/cs \(claimed"; echo $?)"
  check l2-relfirst "$( [ -f "$W/relu/cu/f" ] && has "$L1" "landed KEEP $W/relu/cu \(claimed"; echo $?)"
  check l2-pending "$( has "$L1" "landed KEEP $W/fresh/cf \(written in the last 6 h\)\$" && grep -qxF "$W/fresh/cf" "$h/p1.txt" \
    && has "$L2" "landed KEEP $W/fresh/cf \(written in the last 6 h\) \[kept at an earlier landing\]" \
    && [ ! -e "$W/fresh/cf" ] && has "$L3" "landed REMOVED .*$W/fresh/cf .*\[kept at an earlier landing\]"; echo $?)"
  A=$(sed -n 's/^archive: //p' "$W/arch/ca/ARCHIVED.txt" 2>/dev/null)
  check l2-buildout "$( [ -f "$A" ] && has "$L1" "landed ARCHIVED .*$W/arch/ca -> .*build output left out: 1 folder\(s\)" \
    && has "$W/arch/ca/ARCHIVED.txt" "^left out: build output, rebuild it after a restore: $W/arch/ca/target\$" \
    && zstd -dc "$A" | tar -tf - > "$h/a.list" && ! grep -q '/arch/ca/target' "$h/a.list" \
    && grep -q '/arch/ca/.lake/packages/dep/.git/HEAD$' "$h/a.list" && grep -q '/arch/ca/u$' "$h/a.list"; echo $?)"
  check l2-noroom "$( has "$L2" "landed ALARM not enough free space to archive $W/big/cb: " \
    && has "$L2" "landed KEEP $W/big/cb \(unsaved .*not enough free space to archive\)" && grep -qxF "$W/big/cb" "$h/p2.txt"; echo $?)"
  check l2-recheck "$( [ -f "$W/big/cb/ARCHIVED.txt" ] && has "$L3" "landed ARCHIVED .*$W/big/cb -> .*\[kept at an earlier landing\]" \
    && [ "$(cat "$P")" = "$(printf '%s\n%s' "$W/rels/cs" "$W/relu/cu")" ]; echo $?)"
}

# class 5 in its own scratch home, reading a scratch folder in place of /tmp: a /tmp git copy
# goes only when everything in it is saved in ~/git; size never decides; a big entry is named
# in one ALARM line
class5_cases() {  # $1 spark-cleanup copy
  local s=$1 h t L
  h=$(mktemp -d "$top/t5.XXXX"); t="$h/tmp"
  mkdir -p "$h/git" "$h/handoffs" "$h/src" "$t/junk" "$t/plain"
  : > "$h/handoffs/BOARD.md"
  git init -q -b main "$h/src/c5"
  head -c 300000 /dev/urandom > "$h/src/c5/big"; git -C "$h/src/c5" add big; git -C "$h/src/c5" commit -qm big
  git clone -q --bare "$h/src/c5" "$h/git/c5repo.git"; rm -rf "$h/src"
  git clone -q "$h/git/c5repo.git" "$t/saved"
  git clone -q "$h/git/c5repo.git" "$t/unsaved"
  echo u > "$t/unsaved/u"; git -C "$t/unsaved" add u; git -C "$t/unsaved" commit -qm u
  git clone -q "$h/git/c5repo.git" "$t/plain/sub"; echo mine > "$t/plain/sub/notes.txt"
  echo j > "$t/junk/j"
  find "$t" -exec touch -h -d '5 days ago' {} +
  : > "$h/inuse"
  HOME=$h SPARK_CLEANUP_QUIET=1 SPARK_CLEANUP_OFFLINE=1 SPARK_CLEANUP_GITSTORE=$h/git SPARK_CLEANUP_BOARD=$h/handoffs/BOARD.md \
    SPARK_CLEANUP_PROTECT=none-protected SPARK_CLEANUP_DRY_CLASSES= SPARK_CLEANUP_TEST_INUSE_FILE=$h/inuse \
    SPARK_CLEANUP_TEST_TMPROOT=$t SPARK_CLEANUP_BIG_ALARM=200000 SPARK_CLEANUP_TMP_MAX=1 \
    bash "$s" --apply --classes 5 > "$h/out.txt" 2>&1
  L=$h/out.txt
  check c5-hook "$(has "$L" "test hook: class 5 reads $t instead of /tmp"; echo $?)"
  check c5-unsaved "$( [ -f "$t/unsaved/u" ] && git -C "$t/unsaved" cat-file -e HEAD && has "$L" "class5 SKIP unsaved \(ref [0-9a-f]+ of $t/unsaved not in ~/git\) .*$t/unsaved$" && ! has "$L" "class5 REMOVED .*$t/unsaved "; echo $?)"
  check c5-nested "$( [ -f "$t/plain/sub/notes.txt" ] && has "$L" "class5 SKIP unsaved \(.*$t/plain/sub\) .*$t/plain$"; echo $?)"
  check c5-saved "$( [ ! -e "$t/saved" ] && has "$L" "class5 REMOVED .*$t/saved " && ! has "$L" 'over-cap'; echo $?)"
  check c5-junk "$( [ ! -e "$t/junk" ] && has "$L" "class5 REMOVED .*$t/junk "; echo $?)"
  check c5-bigalarm "$( [ "$(grep -c 'ALARM entries over' "$L")" = 1 ] && has "$L" "ALARM entries over .*$t/saved [0-9.]+G \(class5 removed\)" && has "$L" "ALARM entries over .*$t/unsaved [0-9.]+G \(class5 kept: unsaved\)" && ! has "$L" "ALARM entries over .*$t/junk "; echo $?)"
}

suite() {  # $1 spark-cleanup copy; sets pass/fail
  local s=$1 h
  h=$(mktemp -d "$top/h.XXXX"); setup "$h"
  # f5: no scratch folder (TMPDIR missing): loud, nonzero, nothing removed
  TMPDIR="$h/no-such-dir" run "$h" "$s" --apply --classes 2; local mk_rc=$?
  local mk_ok=1; [ "$mk_rc" != 0 ] && has "$h/out.txt" 'ALARM cannot create a scratch folder' && ! has "$h/out.txt" 'REMOVED' && [ -d "$h/workspace/wt-store" ] && mk_ok=0
  run "$h" "$s" --classes 2,8
  local dry="$h/out.txt"; cp "$dry" "$h/dry.txt"
  [ ! -s "$h/handoffs/BOARD.md" ]; local dryboard=$?
  run "$h" "$s" --apply --classes 2,8
  local o="$h/out.txt"; cp "$o" "$h/apply1.txt"
  run "$h" "$s" --apply --classes 8
  local o2="$h/apply2.txt"; cp "$h/out.txt" "$o2"
  SPARK_CLEANUP_LEFTOVER_ALARM_GB=0.5 run "$h" "$s" --classes 8
  local o3="$h/out.txt"; cp "$o3" "$h/badthr.txt"
  # c8-nolock: fake quiet-build records the env it ran with, then runs the command
  mkdir -p "$h/.local/bin"
  printf '#!/bin/bash\necho "qb SKIP8=${SPARK_CLEANUP_SKIP8:-} $(date +%%s%%N)" >> "%s/qb.log"\n"$@"\nrc=$?\necho "qb-end $(date +%%s%%N)" >> "%s/qb.log"\nexit $rc\n' "$h" "$h" > "$h/.local/bin/quiet-build"
  chmod +x "$h/.local/bin/quiet-build"
  HOME=$h SPARK_CLEANUP_TEST_FREE_PCT=50 SPARK_CLEANUP_GITSTORE=$h/git SPARK_CLEANUP_BOARD=$h/handoffs/BOARD.md \
    SPARK_CLEANUP_PROTECT=none-protected SPARK_CLEANUP_DRY_CLASSES= bash "$s" --apply --classes 2,8 > "$h/nolock.txt" 2>&1
  # store-empty: a separate scratch home whose store is empty
  local e; e=$(mktemp -d "$top/e.XXXX"); mkdir -p "$e/git" "$e/workspace" "$e/handoffs"; : > "$e/handoffs/BOARD.md"
  HOME=$e SPARK_CLEANUP_QUIET=1 SPARK_CLEANUP_GITSTORE=$e/git SPARK_CLEANUP_BOARD=$e/handoffs/BOARD.md bash "$s" --apply --classes 2,8 > "$e/out.txt" 2>&1
  HOME=$e SPARK_CLEANUP_QUIET=1 SPARK_CLEANUP_GITSTORE=$e/git SPARK_CLEANUP_BOARD=$e/handoffs/BOARD.md bash "$s" --apply --classes 2,8 > "$e/out2.txt" 2>&1
  # c8-unfin: a scan that started and never wrote its finish mark
  echo 1700000000 > "$h/.local/state/spark-cleanup/class8.started"; rm -f "$h/.local/state/spark-cleanup/class8.finished"
  SPARK_CLEANUP_CLASS8_MAX_H=1.5 run "$h" "$s" --apply --classes 8; cp "$h/out.txt" "$h/unfin.txt"
  # c8-drymark: a dry run with an unfinished --apply mark left in place
  echo 1700000001 > "$h/.local/state/spark-cleanup/class8.started"; rm -f "$h/.local/state/spark-cleanup/class8.finished"
  local bd0; bd0=$(wc -l < "$h/handoffs/BOARD.md")
  run "$h" "$s" --classes 8; cp "$h/out.txt" "$h/drymark.txt"
  local dm_ok=1; [ "$(cat "$h/.local/state/spark-cleanup/class8.started")" = 1700000001 ] && [ "$(wc -l < "$h/handoffs/BOARD.md")" = "$bd0" ] && ! has "$h/drymark.txt" 'did not finish' && dm_ok=0
  cp "$h/.local/state/spark-cleanup/class8.started" "$h/.local/state/spark-cleanup/class8.finished"   # leave no unfinished mark for later cases
  # c8-only8: --apply --classes 8 through the real wrapper (fake quiet-build present)
  local qb0; qb0=$(wc -l < "$h/qb.log" 2>/dev/null || echo 0)
  HOME=$h SPARK_CLEANUP_TEST_FREE_PCT=50 SPARK_CLEANUP_GITSTORE=$h/git SPARK_CLEANUP_BOARD=$h/handoffs/BOARD.md \
    SPARK_CLEANUP_PROTECT=none-protected SPARK_CLEANUP_DRY_CLASSES= bash "$s" --apply --classes 8 > "$h/only8.txt" 2>&1
  local qb1; qb1=$(wc -l < "$h/qb.log" 2>/dev/null || echo 0)
  bash "$s" --help > "$h/help.txt" 2>&1
  # c8-emerg: under 10 % free the deleting classes run without quiet-build; class 8 still runs alone after them
  local qbn; qbn=$(wc -l < "$h/qb.log" 2>/dev/null || echo 0)
  HOME=$h SPARK_CLEANUP_TEST_FREE_PCT=5 SPARK_CLEANUP_GITSTORE=$h/git SPARK_CLEANUP_BOARD=$h/handoffs/BOARD.md \
    SPARK_CLEANUP_PROTECT=none-protected SPARK_CLEANUP_DRY_CLASSES= bash "$s" --apply --classes 2,8 > "$h/emerg.txt" 2>&1
  run "$h" "$s" --apply --classes 1; cp "$h/out.txt" "$h/class1.txt"
  o="$h/apply1.txt"
  check c2-store "$( [ ! -d "$h/workspace/wt-store" ] && has "$o" 'class2 REMOVED .*wt-store'; echo $?)"
  check c2-remote "$( [ -d "$h/workspace/wt-remote" ] && has "$o" 'class2 SKIP not-in-git-store .*wt-remote'; echo $?)"
  check c8-left "$(has "$o" 'class8 ALARM leftover-copy .*/work/lane/left '; echo $?)"
  check c8-unst "$(has "$o" 'class8 ALARM unstored-copy .*/work/lane/unst '; echo $?)"
  check c8-dirty "$(has "$o" 'class8 ALARM dirty-copy .*/work/lane/dirty '; echo $?)"
  check c8-model "$(has "$o" 'class8 ALARM model-copy .*m\.safetensors'; echo $?)"
  check c8-fresh "$( ! has "$o" 'class8 ALARM .*/work/lane/fresh'; echo $?)"
  check c8-wt-own "$(has "$h/dry.txt" 'class8 ALARM leftover-copy .*/workspace/wt-store '; echo $?)"
  check c8-rerun "$(has "$h/dry.txt" 'class8 ALARM leftover-copy .*/work/lane/left ' && has "$o" 'class8 ALARM leftover-copy .*/work/lane/left '; echo $?)"
  check c8-board "$( [ "$dryboard" = 0 ] && [ "$(grep -c 'ALARM spark-cleanup class8 to all: [0-9]* agent copies left behind' "$h/handoffs/BOARD.md")" = 1 ]; echo $?)"
  check c8-stash "$(has "$o" 'class8 ALARM unstored-copy .*/work/lane/stash '; echo $?)"
  check c8-ignored "$(has "$o" 'class8 ALARM dirty-copy .*/work/lane/ign .*ignored files'; echo $?)"
  check c8-unread "$(has "$o" 'class8 ALARM unreadable-copy .*/work/lane/orphan '; echo $?)"
  check c8-nested "$(has "$o" 'class8 ALARM leftover-copy .*/work/lane/nested '; echo $?)"
  check c8-hardlink "$( ! has "$o" 'model-copy .*linked\.gguf'; echo $?)"
  check c8-dedupe "$(has "$o2" 'board line not repeated' && [ "$(grep -c 'ALARM spark-cleanup class8 to all: [0-9]* agent copies left behind' "$h/handoffs/BOARD.md")" = 1 ]; echo $?)"
  check c8-badthr "$(has "$h/badthr.txt" "class8 ALARM bad SPARK_CLEANUP_LEFTOVER_ALARM_GB='0.5'" && ! has "$h/badthr.txt" 'syntax error|arithmetic'; echo $?)"
  check c8-nolock "$(grep -q '^qb SKIP8=1 ' "$h/qb.log" 2>/dev/null && has "$h/nolock.txt" 'APPLY classes=2 ' && has "$h/nolock.txt" 'APPLY classes=8 ' && ! has "$h/nolock.txt" 'APPLY classes=2,8'; echo $?)"
  check store-empty "$(has "$e/out.txt" 'holds no bare repositories' && has "$e/out2.txt" 'holds no bare repositories' && [ "$(grep -c 'holds no bare repositories' "$e/handoffs/BOARD.md")" = 1 ]; echo $?)"
  check c8-emerg "$(has "$h/emerg.txt" 'APPLY classes=2 ' && has "$h/emerg.txt" 'APPLY classes=8 ' && ! has "$h/emerg.txt" 'APPLY classes=2,8' && [ "$(wc -l < "$h/qb.log")" = "$qbn" ]; echo $?)"
  check c8-main "$(has "$h/dry.txt" 'class8 SKIP main-clone .*/workspace/ref ' && has "$h/dry.txt" 'class8 ALARM unstored-copy .*/workspace/proj .*main clone:' && ! has "$h/dry.txt" 'class8 ALARM [a-z]+-copy .*/workspace/ref '; echo $?)"
  check c8-drymark "$dm_ok"
  check c2-nested "$( [ -d "$h/workspace/wt-nest" ] && has "$o" 'class2 SKIP nested-repo .*wt-nest'; echo $?)"
  check c2-untracked "$( [ -f "$h/workspace/wt-untracked/notes.txt" ] && [ "$(cat "$h/workspace/wt-untracked/notes.txt")" = notes ] && has "$o" 'class2 SKIP unsaved .*wt-untracked' && ! has "$o" 'class2 REMOVED .*wt-untracked' && ! has "$o" 'class8 ALARM leftover-copy .*/workspace/wt-untracked '; echo $?)"
  check c2-ignored "$( [ -f "$h/workspace/wt-ignored/secret/z" ] && [ "$(cat "$h/workspace/wt-ignored/secret/z")" = z ] && has "$o" 'class2 SKIP unsaved .*wt-ignored' && ! has "$o" 'class2 REMOVED .*wt-ignored' && ! has "$o" 'class8 ALARM leftover-copy .*/workspace/wt-ignored '; echo $?)"
  check c2-skipwt "$( [ -f "$h/workspace/wt-skip/a" ] && grep -q edited "$h/workspace/wt-skip/a" && has "$o" 'class2 SKIP unsaved .*wt-skip' && ! has "$o" 'class2 REMOVED .*wt-skip' && ! has "$o" 'class8 ALARM leftover-copy .*/workspace/wt-skip '; echo $?)"
  check c2-assume "$( [ -f "$h/workspace/wt-assume/a" ] && grep -q edited "$h/workspace/wt-assume/a" && has "$o" 'class2 SKIP unsaved .*wt-assume' && ! has "$o" 'class2 REMOVED .*wt-assume' && ! has "$o" 'class8 ALARM leftover-copy .*/workspace/wt-assume '; echo $?)"
  check c2-bare "$( [ -d "$h/workspace/wt-bare/.lake/packages/dep.git" ] && git -C "$h/workspace/wt-bare/.lake/packages/dep.git" cat-file -e HEAD && has "$o" 'class2 SKIP nested-repo .*wt-bare' && ! has "$o" 'class2 REMOVED .*wt-bare' && has "$o" 'class8 ALARM unstored-copy .*/workspace/wt-bare ' && ! has "$o" 'class8 ALARM leftover-copy .*/workspace/wt-bare '; echo $?)"
  check c8-nestbad "$( has "$o" 'class8 ALARM unstored-copy .*/work/lane/outer ' && ! has "$o" 'class8 ALARM leftover-copy .*/work/lane/outer ' && [ -f "$h/work/lane/outer/build/mywork/w" ] && has "$o" 'class8 ALARM unstored-copy .*/workspace/wt-nest ' && ! has "$o" 'class8 ALARM leftover-copy .*/workspace/wt-nest ' && [ -d "$h/workspace/wt-nest/.lake/packages/dep" ] && has "$o" 'class8 ALARM unstored-copy .*/work/lane/super ' && ! has "$o" 'class8 ALARM leftover-copy .*/work/lane/super ' && [ -f "$h/work/lane/super/dep/d" ]; echo $?)"
  check c8-remoteref "$( has "$o" 'class8 ALARM unstored-copy .*/work/lane/rem ' && ! has "$o" 'class8 ALARM leftover-copy .*/work/lane/rem ' && [ -d "$h/work/lane/rem" ]; echo $?)"
  check c8-fourbit "$( [ -f "$h/work/hive/uxl-brief-20261113/FourBit/target/ONLY-COPY.txt" ] && [ -f "$h/work/hive/uxl-brief-20261113/FourBit/keep.txt" ] && [ -d "$h/work/hive/uxl-brief-20261113/FourBit/checkout" ] && ! has "$h/class1.txt" 'REMOVED .*FourBit' && ! has "$o" 'leftover-copy .*FourBit' && [ ! -e "$h/handoffs/hive/factory-bays/job/target/rebuild.txt" ] && has "$h/class1.txt" 'class1 REMOVED .*factory-bays/job/target' && [ -f "$h/handoffs/hive/factory-bays/job/evidence/target/keep.txt" ] && has "$h/class1.txt" 'class1 SKIP protected .*evidence/target' && [ -f "$h/handoffs/keep.txt" ]; echo $?)"
  check c8-inner "$( ! has "$o" 'class8 ALARM .*/work/lane/active'; echo $?)"
  check c8-agentwt "$(has "$h/dry.txt" 'class8 ALARM [a-z]+-copy .*/workspace/proj/\.claude/worktrees/agent-x '; echo $?)"
  check c8-dashwt "$(has "$h/dry.txt" 'class8 ALARM [a-z]+-copy .*/workspace/kflow '; echo $?)"
  check c8-unfin "$(has "$h/unfin.txt" 'previous leftover-copy scan .*did not finish' && [ "$(grep -c 'did not finish' "$h/handoffs/BOARD.md")" = 1 ]; echo $?)"
  check c8-maxh "$(has "$h/unfin.txt" "ALARM bad SPARK_CLEANUP_CLASS8_MAX_H='1.5'" && ! has "$h/unfin.txt" 'syntax error|arithmetic'; echo $?)"
  check c8-only8 "$( [ "$qb0" = "$qb1" ] && has "$h/only8.txt" 'APPLY classes=8 '; echo $?)"
  check c8-help "$(has "$h/help.txt" '^Usage|^ *spark-cleanup --classes' && ! has "$h/help.txt" 'pipefail'; echo $?)"
  check c8-hook "$(has "$o" 'test hook: in-use list read from'; echo $?)"
  check c8-nodel "$( [ -d "$h/work/lane/left" ] && [ -d "$h/work/lane/unst" ] && [ -d "$h/work/lane/dirty" ] && [ -f "$h/work/lane/weights/m.safetensors" ]; echo $?)"
  check f1-bare-c2 "$( [ -d "$h/workspace/wt-barenose/.lake/packages/dep/objects" ] && has "$o" 'class2 SKIP nested-repo .*wt-barenose' && ! has "$o" 'class2 REMOVED .*wt-barenose' && has "$o" 'class8 ALARM unstored-copy .*/workspace/wt-barenose '; echo $?)"
  check f1-bare-c8 "$(has "$o" 'class8 ALARM unstored-copy .*/work/lane/baren ' && [ -d "$h/work/lane/baren/.lake/packages/dep/objects" ]; echo $?)"
  check f1-bare-c1 "$( [ -d "$h/handoffs/hive/factory-bays/job/cache-nosuffix/vendor/objects" ] && has "$h/class1.txt" 'class1 SKIP has-git .*cache-nosuffix'; echo $?)"
  check f2-subbranch "$(has "$o" 'class8 ALARM unstored-copy .*/work/lane/super2 ' && ! has "$o" 'leftover-copy .*/work/lane/super2 '; echo $?)"
  check f3-nestfile "$(has "$o" 'class8 ALARM dirty-copy .*/work/lane/nestfile .*nested repository has unsaved files' && [ -f "$h/work/lane/nestfile/.lake/packages/dep/notes.txt" ]; echo $?)"
  check f4-mode "$( [ -x "$h/workspace/wt-mode/a" ] && has "$o" 'class2 SKIP unsaved .*wt-mode' && ! has "$o" 'class2 REMOVED .*wt-mode'; echo $?)"
  check f5-mktemp "$mk_ok"
  landed_cases "$s"
  landed2_cases "$s"
  class5_cases "$s"
}

suite "$sc"
cases=$pass; real_fail=$fail
# mutants: each must make the suite fail
mutate() {  # $1 name, $2 perl substitution
  local m="$top/mut-$1"
  perl -0pe "$2" "$sc" > "$m"
  if cmp -s "$m" "$sc"; then echo "MUTANT $1 did not apply"; return 1; fi
  pass=0; fail=0; quiet=1; suite "$m"; quiet=
  if [ "$fail" -gt 0 ]; then echo "MUTANT $1 caught ($fail failing)"; return 0; fi
  echo "MUTANT $1 NOT caught"; return 1
}
mt=0 mc=0
for spec in \
  'store-always-true|s/(in_git_store\(\) \{  # \$1 commit sha[^\n]*\n)/$1  return 0\n/' \
  'old-pushed-check|s/if \[ -z "\$head" \] \|\| ! in_git_store "\$head" >\/dev\/null; then/if [ -z "\$(git -C "\$wt" branch -r --contains HEAD 2>\/dev\/null | head -1)" ] \&\& ! in_git_store "\$head" >\/dev\/null; then/' \
  'no-idle-check|s/    recent "\$r" "\$idle_min" && continue\n//' \
  'unreadable-is-leftover|s/kind=unreadable; why=/kind=leftover; why=/' \
  'heads-only|s#for-each-ref --format=.%\(objectname\) %\(refname\).#for-each-ref --format="%(objectname)" refs/heads#' \
  'no-dedupe|s/if \[ "\$sig" = "\$last" \]; then/if false; then/' \
  'class8-in-lock|s/SPARK_CLEANUP_SKIP8=1 "\$QB"/"\$QB"/' \
  'no-emerg-split|s/else SPARK_CLEANUP_SKIP8=1 "\$0" "\$@"; _rc=\$\?; fi/else exec "\$0" "\$@"; fi/' \
  'no-inner|s/    if \[ \$inner = 1 \] && ! grep -qs [^\n]*; then continue; fi\n//' \
  'main-clone|s/(is_main_clone\(\) \{\n)/$1  return 1\n/' \
  'inner-wt|s/if \[ \$inner = 1 \] && ! grep -qs [^\n]*; then continue; fi/[ \$inner = 1 ] \&\& continue/' \
  'main-by-name|s/  \[ -d "\$1\/\.git" \] \|\| return 1\n//' \
  'no-unfinished|s/if \[ -n "\$_st" \] && \[ "\$\(cat "\$STATE\/class8\.finished" 2>\/dev\/null\)" != "\$_st" \]; then/if false; then/' \
  'dry-marks|s/if \[ "\$CLASSES" = 8 \] && \[ \$APPLY = 1 \]; then/if [ "\$CLASSES" = 8 ]; then/' \
  'no-nested-check|s/      if \[ -n "\$inner" \]; then log "class2 SKIP nested-repo[^\n]*\n//' \
  'main-silent|s/main=0; is_main_clone "\$r" && main=1/is_main_clone "\$r" \&\& continue; main=0/' \
  'bare-by-name|s/-o -type f -name HEAD -print 2>/-o -type f -path "*.git\/HEAD" -print 2>/' \
  'wt-heads-only|s/  \[ "\$gd" != "\$cd" \] && return 0\n/  [ -f "\$1\/.git" ] \&\& return 0\n/' \
  'nested-unsaved|s/    if why=\$\(copy_unsaved "\$d" nested\); then [^\n]*\n//' \
  'no-mode-check|s/\{ echo "skip-worktree or assume-unchanged file executable bit differs from the saved copy \(\$path\)"; return 0; \}/true/' \
  'mktemp-continue|s/  \[ -n "\$LANDED" \] && exit 0\n  exit 1\nfi/fi/' \
  'landed-idle|s/if ! idle_outside_git "\$r" \$\(\(LANDED_IDLE_H\*60\)\); then/if false; then/' \
  'landed-inuse|s/if in_use "\$r"; then lwait/if false; then lwait/' \
  'landed-claim|s/if claimed "\$r" "\$TMPD\/claims"; then/if false; then/' \
  'claims-board-only|s/ "\$\{SPARK_CLEANUP_CLAIMS:-\$H\/handoffs\/hive\/CLAIMS\.md\}"//' \
  'claim-exact-only|s/    case "\$1\/" in "\$p"\/\*\) return 0 ;; esac\n/    [ "\$1" = "\$p" ] \&\& return 0\n/' \
  'main-dash-name|s/  \[ -n "\$\{STORE_NAME\[\$n\]:-\}" \] && return 0\n//' \
  'landed-unsaved-removed|s/if \[ "\$bad" = 0 \] && \[ -z "\$nest" \] && \[ -z "\$uns" \]; then landed_remove/if true; then landed_remove/' \
  'landed-archive-recent|s/if ! idle_outside_git "\$r" \$\(\(LANDED_ARCHIVE_D\*1440\)\); then/if false; then/' \
  'landed-no-bundle|s/    if \[ -n "\$head" \] && ! in_git_store "\$head"; then/    if false; then/' \
  'c5-no-git-check|s/if \[ -d "\$d" \] && why=\$\(repos_unsaved "\$d"\); then/if false; then/' \
  'c5-top-only|s/; each_nested_repo "\$1"\)\n  return 1/)\n  return 1/' \
  'c5-cap-back|s/(\n    remove_dir 5 )/\n    sz=\$(size_of "\$d"); [ "\$sz" -gt "\${SPARK_CLEANUP_TMP_MAX:-5368709120}" ] \&\& { log "class5 SKIP over-cap \$d"; continue; }$1/' \
  'no-big-alarm|s/\n\[ \$\{#BIG\[@\]\} -gt 0 \] && log/\n[ 0 = 1 ] \&\& log/' \
  'index-write|s/export GIT_OPTIONAL_LOCKS=0\n//' \
  'no-board|s/      "\$\(date -u \+%FT%H:%MZ\)" "\$n" "\$\(human "\$bytes"\)" "\$LOG" >> "\$board"/      "x" "\$n" "x" "x" >\/dev\/null/' \
  'root-claim-used|s/if \[ "\$root" = 1 \]; then printf/if false; then printf/' \
  'release-ignored|s/gone = rn\[j\] > cn\[i\]/gone = 0/' \
  'release-before-claim|s/gone = rn\[j\] > cn\[i\]/gone = 1/' \
  'release-any-lane|s/if \(cl\[i\] == "" \|\| rl\[j\] != cl\[i\]\) continue/if (cl[i] == "") continue/' \
  'pending-unread|s/grep -qxF -- "\$r" "\$pending"; then via=/false; then via=/' \
  'build-in-archive|s/(build_output\(\) \{  # \$1 copy\n)/$1  return 0\n/' \
  'no-room-check|s/ \|\| \[ "\$room" -lt "\$need" \]; then/; then/' \
  'claim-file-missing|s/if \[ -r "\$f" \]; then files\+=/if true; then files+=/' \
  'alarm-reads-as-claim|s/to all: a claim line names/to all: a CLAIM line names/' ; do
  name=${spec%%|*}; expr=${spec#*|}
  mt=$((mt+1)); mutate "$name" "$expr" && mc=$((mc+1))
done
if [ "$real_fail" = 0 ] && [ "$mc" = "$mt" ]; then echo "TEST PASS cases=$cases mutants=$mc/$mt"; exit 0; fi
echo "TEST FAIL failing=$real_fail mutants=$mc/$mt"; exit 1
