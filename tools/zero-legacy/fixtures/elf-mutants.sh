#!/bin/sh
# elf-mutants.sh ZLDIR OMC WORK (sh tools/zero-legacy/fixtures/elf-mutants.sh "$PWD/tools/zero-legacy" OMC DIR): each mutant is one sed edit of elfclose.om in a fresh copy of
# tools/zero-legacy; the gate must exit 1 for every one (a surviving mutant is a FAIL here).
zl=$1; omc=$2; work=$3
mkdir -p "$work"
killed=0 survived=0
mut() {
  name=$1; expr=$2
  d=$work/$name
  mkdir -p "$d"
  (cd "$zl" && tar --exclude=./build -cf - .) | (cd "$d" && tar -xf -)
  sed -i "$expr" "$d/elfclose.om"
  if cmp -s "$zl/elfclose.om" "$d/elfclose.om"; then echo "MUTANT $name INVALID (edit did not apply)"; survived=$((survived+1)); return; fi
  (cd "$d" && AIEN_OMC=$omc sh ./gate.sh > gate.out 2>&1); rc=$?
  if [ "$rc" -eq 1 ]; then killed=$((killed+1)); echo "MUTANT $name killed (gate rc=1): $(grep -E '_exit [1-9]|refused 0' "$d/gate.out" | tr '\n' ' ')"
  else survived=$((survived+1)); echo "MUTANT $name SURVIVED (gate rc=$rc)"; fi
}
mut no-needed 's/^put ndn 0 add m n$/put ndn 0 0/'
mut dyn-not-foreign '/^fx = true$/d'
mut no-class-check 's/^if ne get hb 4 2$/if eq get hb 4 9/'
mut no-map-dedupe 's/^if same$/if false/'
mut perms-byte 's/^ret eq get mp add i 3 120$/ret eq get mp add i 2 120/'
mut vaddr-as-offset 's/^ret add p64 add b 8 sub v va$/ret v/'
mut no-gnu-phdr 's/^if ge t 1685382480$/if ge t 1685382484/'
mut no-comment-scan 's/^r = comment b$/r = ulong 0/'
mut no-path-escape 's/^if esc$/if false/'
mut needed-ctl-ok 's/^if ctlb c$/if false/'
mut needed-comma-ok 's/^if eq c 44$/if false/'
mut interp-ctl-ok 's/^if ctlb get ib i$/if false/'
mut del-not-ctl 's/^ret eq c 127$/ret false/'
mut load-unchecked 's/^if not inrange p64 add b 8 p64 add b 32$/if false/'
mut nonregular-ok 's/^if ne and m 61440 32768$/if false/'
echo "MUTANTS killed=$killed survived=$survived"
[ "$survived" -eq 0 ]
