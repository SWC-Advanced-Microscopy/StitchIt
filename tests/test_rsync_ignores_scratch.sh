#!/usr/bin/env bash
# Checks that the syncAndCrunch rsync calls skip directories named "scratch" (at any depth)
# but still copy files merely named like it. Uses a synthetic tree in a temp dir whose path
# contains a space. Run with: bash tests/test_rsync_ignores_scratch.sh
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
SYNCER="$REPO/code/processDuringAcquistion/syncer.sh"
MFILE="$REPO/code/processDuringAcquistion/syncAndCrunch.m"
FAILS=0

check() { # check <description> <command...>
    local d="$1"; shift
    if "$@"; then echo "ok   - $d"; else echo "FAIL - $d"; FAILS=$((FAILS+1)); fi
}

make_tree() { # make_tree <sample dir>: scratch folders at several depths plus normal files
    local s="$1"
    mkdir -p "$s/scratch/sub" "$s/a/scratch" "$s/rawData"
    echo x > "$s/scratch/x.txt"; echo y > "$s/scratch/sub/y.txt"; echo z > "$s/a/scratch/z.txt"
    echo f > "$s/scratchfile.txt"; echo n > "$s/normal.txt"; echo t > "$s/rawData/tile.txt"
    touch "$s/FINISHED"  # makes syncer.sh stop after its first rsync
}

no_scratch_dirs() { [ ! -e "$1/scratch" ] && [ ! -e "$1/a/scratch" ]; }
keeps_files() { [ -f "$1/scratchfile.txt" ] && [ -f "$1/normal.txt" ]; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/scratch test.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT

make_tree "$WORK/server dir/sample"
SRC="$WORK/server dir/sample/"

# 1. The real syncer.sh pulls the sample dir into the landing dir
mkdir -p "$WORK/land dir"
bash "$SYNCER" -r -a -s "$WORK/server dir/sample" -l "$WORK/land dir" >/dev/null
D="$WORK/land dir/sample"
check "syncer.sh does not copy scratch dirs" no_scratch_dirs "$D"
check "syncer.sh copies scratchfile.txt and normal files" keeps_files "$D"
check "syncer.sh copies tiles" test -f "$D/rawData/tile.txt"

# 2. The two rsync commands in syncAndCrunch.m. The arguments are checked in the source and
# then run in the form unix() would hand them to the shell (single-quoted paths).
pull_m_commands() { grep -E "rsync (-r --exclude|%s)" "$MFILE"; }
check "syncAndCrunch.m has exactly two rsync commands" test "$(pull_m_commands | wc -l)" -eq 2
check "both syncAndCrunch.m rsync commands exclude scratch/" test "$(pull_m_commands | grep -c -e "--exclude=''scratch/''")" -eq 2

DST="$WORK/exp dir"; mkdir -p "$DST"
eval "rsync -r --exclude=\"/*/\" --exclude='scratch/' '$SRC' '$DST'"
check "initial rsync does not copy scratch dirs" no_scratch_dirs "$DST"
check "initial rsync copies top-level files only" keeps_files "$DST"
check "initial rsync copies no directories" test ! -e "$DST/rawData"

DST2="$WORK/raw dir"; mkdir -p "$DST2"
eval "rsync -a --exclude='scratch/' '$SRC' '$DST2'"
check "first-batch rsync does not copy scratch dirs" no_scratch_dirs "$DST2"
check "first-batch rsync copies scratchfile.txt and normal files" keeps_files "$DST2"

[ "$FAILS" -eq 0 ] && echo "All passed" || { echo "$FAILS failed"; exit 1; }
