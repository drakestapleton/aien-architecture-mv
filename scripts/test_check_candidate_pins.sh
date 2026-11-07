#!/usr/bin/env bash
# Test for tools/candidate/check_pins.om. Offline: lock files are served from a temp tree by a CAND_FILE_AT stub.
# The checker is compiled here with the pinned seeded compiler named by AIEN_OMC (exit 3 = NOT_RUN without it).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../tools/candidate/check_pins.om"
omc="${AIEN_OMC:-}"
[ -n "$omc" ] && [ -x "$omc" ] || { echo "test_check_candidate_pins: AIEN_OMC is not an executable omc (NOT_RUN)" >&2; exit 3; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
chk="$tmp/check_pins"
"$omc" < "$src" > "$chk" && chmod +x "$chk" || { echo "TEST FAIL: $src does not compile with $omc"; exit 1; }
OM=1111111111111111111111111111111111111111; SC=2222222222222222222222222222222222222222
AO=3333333333333333333333333333333333333333; PH=4444444444444444444444444444444444444444
PR=5555555555555555555555555555555555555555; CS=6666666666666666666666666666666666666666
SP=7777777777777777777777777777777777777777; AR=8888888888888888888888888888888888888888
OTHER=9999999999999999999999999999999999999999
cat > "$tmp/stub.sh" <<S
#!/usr/bin/env bash
# like gh api on a missing file or commit: an error body that contains the requested ref, and exit 1
cat "$tmp/files/\$1/\$2/\$3" 2>/dev/null || { echo "{\"message\":\"No commit found for the ref \$2\"}"; exit 1; }
S
chmod +x "$tmp/stub.sh"; export CAND_FILE_AT="$tmp/stub.sh"

serve() { mkdir -p "$(dirname "$tmp/files/$1")"; cat > "$tmp/files/$1"; }
tree() { # tree : the consistent lock files
  rm -rf "$tmp/files"
  echo "$OM" | serve "aien-sovereign-core/$SC/omega.lock"
  serve "aien-sovereign-core/$SC/Cargo.lock" <<L
[[package]]
name = "aien-protocol-types"
source = "git+https://github.com/aien-dev/aien-protocols?rev=$PR#$PR"

[[package]]
name = "aien-probe"
source = "git+https://github.com/aien-dev/aien-protocols?rev=$PR#$PR"

[[package]]
name = "crumb-spec"
source = "git+https://github.com/aien-dev/crumb-spec?rev=$CS#$CS"

[[package]]
name = "spark-crumbs"
source = "git+https://github.com/aien-dev/spark-crumbs?rev=$SP#$SP"

[[package]]
name = "serde"
source = "registry+https://github.com/rust-lang/crates.io-index"
L
  echo "$PH" | serve "omega/$OM/physics.lock"
  echo "$AO" | serve "omega/$OM/aienos.lock"
  printf '%s\n# argus pin, comment with no hex\n' "$AR" | serve "omega/$OM/argus.lock"
}
manifest() { # manifest <out> : manifest that agrees with tree
  cat > "$1" <<M
schema = "CandidateManifestV1"
id = "CAND-T"
[commits]
omega = "$OM"
aienos = "$AO"
aien-sovereign-core = "$SC"
aien-protocols = "$PR"
physics = "$PH"
[contracts]
crumb-spec = "$CS"
spark-crumbs = "$SP"
[consumed_pins]
sovereign-core-omega-lock = "$OM"
sovereign-core-cargo-lock-aien-protocols = "$PR"
omega-physics-lock = "$PH"
omega-aienos-lock = "$AO"
omega-argus-lock = "$AR"
something-else = "not read"
M
}
pass=0; bad=0
expect() { # expect <0|1> <label> <file> [grep pattern that the output must contain]
  out=$("$chk" "$3" 2>&1); rc=$?
  if [ "$rc" = "$1" ] && { [ -z "${4:-}" ] || grep -q -- "$4" <<<"$out"; }; then pass=$((pass+1))
  else bad=$((bad+1)); echo "TEST FAIL: $2 (rc=$rc)"; echo "$out" | sed 's/^/    /'; fi
}
tree; manifest "$tmp/m.toml"
expect 0 "consistent pins agree" "$tmp/m.toml" "PINS AGREE"
sed "s/^crumb-spec = .*/crumb-spec = \"$OTHER\"/" "$tmp/m.toml" > "$tmp/a.toml"
expect 1 "contract pinned to a revision the code does not consume" "$tmp/a.toml" "contracts.crumb-spec: manifest pins $OTHER"
sed "s/^aien-protocols = .*/aien-protocols = \"$OTHER\"/" "$tmp/m.toml" > "$tmp/b.toml"
expect 1 "aien-protocols pin differs from Cargo.lock" "$tmp/b.toml" "aien-protocols -> commits.aien-protocols"
sed "s/^aienos = .*/aienos = \"$OTHER\"/" "$tmp/m.toml" > "$tmp/c.toml"
expect 1 "aienos pin differs from omega aienos.lock" "$tmp/c.toml" "omega aienos.lock"
sed "s/^physics = .*/physics = \"$OTHER\"/" "$tmp/m.toml" > "$tmp/d.toml"
expect 1 "physics pin differs from omega physics.lock" "$tmp/d.toml" "omega physics.lock"
sed "s/^omega-argus-lock = .*/omega-argus-lock = \"$OTHER\"/" "$tmp/m.toml" > "$tmp/e.toml"
expect 1 "consumed_pins entry differs" "$tmp/e.toml" "consumed_pins.omega-argus-lock"
sed '/^physics = /d;/^omega-physics-lock/d' "$tmp/m.toml" > "$tmp/f.toml"
expect 0 "physics unpinned is allowed" "$tmp/f.toml"
sed '/^spark-crumbs = /d' "$tmp/m.toml" > "$tmp/g.toml"
expect 1 "contract missing from the manifest" "$tmp/g.toml" "not pinned"
# lock-file side
echo "$OTHER" | serve "aien-sovereign-core/$SC/omega.lock"
expect 1 "sovereign-core omega.lock points elsewhere" "$tmp/m.toml" "omega.lock -> commits.omega"
tree; rm "$tmp/files/aien-sovereign-core/$SC/Cargo.lock"
expect 1 "unreadable Cargo.lock" "$tmp/m.toml" "cannot read Cargo.lock"
tree; rm "$tmp/files/omega/$OM/aienos.lock"
expect 1 "unreadable aienos.lock" "$tmp/m.toml" "cannot read aienos.lock"
tree; printf '\n[[package]]\nname = "crumb-spec-extra"\nsource = "git+https://github.com/aien-dev/crumb-spec?rev=%s#%s"\n' "$OTHER" "$OTHER" \
  >> "$tmp/files/aien-sovereign-core/$SC/Cargo.lock"
expect 1 "two revisions of one repo in Cargo.lock" "$tmp/m.toml" "several"
tree; sed -i "s/crumb-spec?rev=$CS#$CS/crumb-spec-fork?rev=$CS#$CS/" "$tmp/files/aien-sovereign-core/$SC/Cargo.lock"
expect 1 "a repo whose name only starts with the contract name does not count" "$tmp/m.toml" "crumb-spec: git revision none"
tree
# a missing lock whose error body carries the omega ref must not read as "argus.lock pins omega"
tree; rm "$tmp/files/omega/$OM/argus.lock"; sed "s/^omega-argus-lock = .*/omega-argus-lock = \"$OM\"/" "$tmp/m.toml" > "$tmp/i.toml"
expect 1 "error body with the ref is not a lock file" "$tmp/i.toml" "consumed_pins.omega-argus-lock: its lock file could not be read"
tree; printf '# pinned after %s\n%s\n' "$OTHER" "$AO" | serve "omega/$OM/aienos.lock"
expect 0 "a leading comment with a sha is skipped" "$tmp/m.toml"
tree; printf '%s %s\n' "$AO" "trailing words" | serve "omega/$OM/aienos.lock"
expect 1 "first line must be exactly the sha" "$tmp/m.toml" "cannot read aienos.lock"
tree
sed '/^aien-sovereign-core = /d' "$tmp/m.toml" > "$tmp/h.toml"
expect 1 "manifest without sovereign-core" "$tmp/h.toml" "lacks"
# -mv sources (issue 815, sovereign-core #906): the -mv name is the same pin; both names together are one pin
lock="$tmp/files/aien-sovereign-core/$SC/Cargo.lock"
tree; sed -i -e 's|aien-dev/aien-protocols?|aien-dev/aien-protocols-mv?|' -e 's|aien-dev/crumb-spec?|aien-dev/crumb-spec-mv?|' \
  -e 's|aien-dev/spark-crumbs?|aien-dev/spark-crumbs-mv.git?|' "$lock"
expect 0 "every pin under its -mv name agrees" "$tmp/m.toml" "PINS AGREE"
cp -r "$tmp/files" "$tmp/files-mv"   # kept for the -mv mutant below
tree; sed -i "s|aien-protocols?rev=$PR#$PR|aien-protocols-mv?rev=$OTHER#$OTHER|" "$lock"
expect 1 "-mv at a wrong revision is refused" "$tmp/m.toml" "aien-protocols -> commits.aien-protocols: manifest pins $PR, the code consumes $OTHER"
tree; printf '\n[[package]]\nname = "aien-provenance"\nsource = "git+https://github.com/aien-dev/aien-protocols-mv?rev=%s#%s"\n' "$OTHER" "$OTHER" >> "$lock"
expect 1 "old and -mv name at two revisions are refused" "$tmp/m.toml" "aien-protocols: git revision several:$PR $OTHER"
tree; sed -i 's|aien-dev/crumb-spec?|aien-dev/crumb-spec-mvx?|' "$lock"
expect 1 "a -mvx repo is not the -mv name" "$tmp/m.toml" "crumb-spec: git revision none"
# in-tree contracts (sovereign-core #892): contracts.<name>-consumed = "in-tree" needs a path package and no git source
intree() { tree; sed -i "/spark-crumbs?rev=$SP#$SP/d" "$lock"; }
sed 's/^spark-crumbs = .*/&\nspark-crumbs-consumed = "in-tree"/' "$tmp/m.toml" > "$tmp/t.toml"
intree
expect 0 "in-tree stated with a path package and no git source agrees" "$tmp/t.toml" "contracts.spark-crumbs-consumed = in-tree (a path package"
cp -r "$tmp/files" "$tmp/files-intree"   # kept for the in-tree word mutant below
expect 1 "a path package the manifest does not state as in-tree is refused" "$tmp/m.toml" "does not state with contracts.spark-crumbs-consumed"
intree; head -n -4 "$lock" > "$tmp/l"; cat "$tmp/l" > "$lock"
expect 0 "the in-tree path package may be the last block" "$tmp/t.toml" "PINS AGREE"
intree; printf '\n[[package]]\nname = "spark-crumbs"\nversion = "0.0.9"\nsource = "git+https://github.com/aien-dev/spark-crumbs?rev=%s#%s"\n' "$OTHER" "$OTHER" >> "$lock"
expect 1 "in-tree with a git source is refused" "$tmp/t.toml" "in-tree, but Cargo.lock has a git source for it at $OTHER"
cp -r "$tmp/files" "$tmp/files-git"   # kept for the git-source mutant below
intree; printf '\n[[package]]\nname = "x"\nsource = "git+https://github.com/aien-dev/spark-crumbs-mv?rev=%s#%s"\n' "$SP" "$SP" >> "$lock"
expect 1 "in-tree with a -mv git source is refused" "$tmp/t.toml" "has a git source for it at $SP"
intree; sed -i 's/^name = "spark-crumbs"$/name = "spark-crumbs-extra"/' "$lock"
expect 1 "in-tree with no package of that name is refused" "$tmp/t.toml" "no path package named spark-crumbs"
cp -r "$tmp/files" "$tmp/files-nopkg"   # kept for the path-package mutant below
tree; sed -i "s|^source = \"git+https://github.com/aien-dev/spark-crumbs?rev=$SP#$SP\"|source = \"registry+https://github.com/rust-lang/crates.io-index\"|" "$lock"
expect 1 "in-tree with a registry package of that name is refused" "$tmp/t.toml" "no path package named spark-crumbs"
cp -r "$tmp/files" "$tmp/files-reg"   # kept for the source-line mutant below
intree; sed 's/^spark-crumbs-consumed = .*/spark-crumbs-consumed = "intree"/' "$tmp/t.toml" > "$tmp/w.toml"
expect 1 "a misspelt in-tree word is refused" "$tmp/w.toml" "the only accepted value is"
# --- mutants. Each broken copy of the checker (one sed edit of the .om source, recompiled) must give the
# wrong verdict on the case it names, proving the test above depends on that check.
mutant() { # mutant <label> <sed-expr> <files-dir> <manifest> <wrong-rc>
  sed "$2" "$src" > "$tmp/mut.om"
  if cmp -s "$src" "$tmp/mut.om"; then bad=$((bad+1)); echo "TEST FAIL: mutant '$1' did not change the checker"; return; fi
  "$omc" < "$tmp/mut.om" > "$tmp/mut" 2>/dev/null && chmod +x "$tmp/mut" || { bad=$((bad+1)); echo "TEST FAIL: mutant '$1' does not compile"; return; }
  rm -rf "$tmp/files"; cp -r "$3" "$tmp/files"
  "$tmp/mut" "$4" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$5" ]; then pass=$((pass+1)); else bad=$((bad+1)); echo "TEST FAIL: mutant '$1' gave rc=$rc, not the wrong $5: the test does not bite"; fi
}
mutant "-mv name not read" '/^p = add p capk p z 38$/d' "$tmp/files-mv" "$tmp/m.toml" 1
mutant "in-tree git source not checked" '/^fn itcheck /,/^oflush 1$/s/^if gt get revn 0 0$/if false/' "$tmp/files-git" "$tmp/t.toml" 0
mutant "in-tree path package not required" '/^fn itcheck /,/^oflush 1$/s/^if not pathpkg p$/if false/' "$tmp/files-nopkg" "$tmp/t.toml" 0
mutant "source line of the package ignored" '/^fn pathpkg /,/^ret and nm not sr$/s/^sr = true$/sr = false/' "$tmp/files-reg" "$tmp/t.toml" 0
mutant "in-tree word not checked" '/^fn itcheck /,/^oflush 1$/s/^if not valis e 41$/if false/' "$tmp/files-intree" "$tmp/w.toml" 0
echo "check_candidate_pins tests: $pass passed, $bad failed"
[ "$bad" -eq 0 ]
