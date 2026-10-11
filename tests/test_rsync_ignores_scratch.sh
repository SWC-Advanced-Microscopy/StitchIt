#!/usr/bin/env bash
# Checks that the syncAndCrunch rsync calls skip directories named "scratch" (at any depth)
# but still copy files merely named like it. Uses synthetic trees in a temp dir whose path
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
keeps_files() { [ -f "$1/scratchfile.txt" ] && [ -f "$1/normal.txt" ] && [ -f "$1/rawData/tile.txt" ]; }

# Runs syncer.sh once with output in $LOG. It gets its own process group and is killed
# as a group after 30 s, so a stuck loop fails the test and leaves no sleep/rsync orphans.
SYNCER_TIMEOUT=30
run_syncer() { # run_syncer <server dir> <landing dir>
    set -m
    bash "$SYNCER" -r -a -s "$1" -l "$2" >"$LOG" 2>&1 &
    local pid=$!
    set +m
    local i
    for ((i = 0; i < SYNCER_TIMEOUT; i++)); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
    if kill -0 "$pid" 2>/dev/null; then
        kill -- "-$pid"
        echo "FAIL - syncer.sh did not finish in $SYNCER_TIMEOUT s"; FAILS=$((FAILS+1))
    fi
    wait "$pid" 2>/dev/null
}

WORK=$(mktemp -d "${TMPDIR:-/tmp}/scratch test.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT
WORK=$(cd "$WORK" && pwd)  # no doubled slashes (a trailing-slash TMPDIR gives them); syncer.sh collapses them in its log
LOG="$WORK/syncer.log"

make_tree "$WORK/server dir/sample"
SRC="$WORK/server dir/sample/"

echo "== 1. syncer.sh with a normal sample dir"
mkdir -p "$WORK/land dir"
run_syncer "$WORK/server dir/sample" "$WORK/land dir"
D="$WORK/land dir/sample"
check "does not copy scratch dirs" no_scratch_dirs "$D"
check "copies scratchfile.txt, normal files and tiles" keeps_files "$D"
EXPECTED_LOG="RUNNING --> rsync -a --include=/scratch/ --exclude=scratch/ $(printf '%q %q' "$WORK/server dir/sample" "$WORK/land dir") <--"
check "logs the exact, pasteable rsync command" grep -qF -e "$EXPECTED_LOG" "$LOG"

echo "== 2. syncer.sh with a sample dir that is itself named scratch"
make_tree "$WORK/server dir/scratch"
run_syncer "$WORK/server dir/scratch" "$WORK/land dir"
D="$WORK/land dir/scratch"
check "syncs the sample dir" keeps_files "$D"
check "does not copy its nested scratch dirs" no_scratch_dirs "$D"

echo "== 3. syncer.sh leaves no orphan processes"
check "no syncer.sh left running for this test" test -z "$(pgrep -f "syncer.sh -r -a -s $WORK" || true)"

echo "== 4. syncAndCrunch.m rsync commands"
# The arguments are checked in the source, then run in the form unix() hands them to the
# shell (single-quoted paths).
pull_m_commands() { grep -E "rsync (-r --exclude|%s)" "$MFILE"; }
check "exactly two rsync commands" test "$(pull_m_commands | wc -l)" -eq 2
check "both exclude scratch/" test "$(pull_m_commands | grep -c -e "--exclude=''scratch/''")" -eq 2

DST="$WORK/exp dir"; mkdir -p "$DST"
eval "rsync -r --exclude=\"/*/\" --exclude='scratch/' '$SRC' '$DST'"
check "initial rsync does not copy scratch dirs" no_scratch_dirs "$DST"
check "initial rsync copies top-level files" test -f "$DST/scratchfile.txt" -a -f "$DST/normal.txt"
check "initial rsync copies no directories" test ! -e "$DST/rawData"

DST2="$WORK/raw dir"; mkdir -p "$DST2"
eval "rsync -a --exclude='scratch/' '$SRC' '$DST2'"
check "first-batch rsync does not copy scratch dirs" no_scratch_dirs "$DST2"
check "first-batch rsync copies scratchfile.txt, normal files and tiles" keeps_files "$DST2"

[ "$FAILS" -eq 0 ] && echo "All passed" || { echo "$FAILS failed"; exit 1; }
