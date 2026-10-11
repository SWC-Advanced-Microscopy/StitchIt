#!/usr/bin/env bash
# Checks that the syncAndCrunch rsync calls skip directories named "scratch" (at any depth)
# but still copy files merely named like it. Uses synthetic trees in a temp dir whose path
# contains a space. Run with: bash tests/test_rsync_ignores_scratch.sh
#
# syncer.sh is run for real. The two rsync commands in syncAndCrunch.m live inside a MATLAB
# function, so they are checked textually in the source and then re-run here as equivalent
# shell commands (a copy of the arguments, not the MATLAB lines themselves).
#
# syncer.sh loops until a FINISHED file appears. Each run gets its own process group and a
# timeout; the group is killed on timeout, on Ctrl-C/TERM and on exit, so nothing keeps running.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
SYNCER="$REPO/code/processDuringAcquistion/syncer.sh"
MFILE="$REPO/code/processDuringAcquistion/syncAndCrunch.m"
FAILS=0
WORK=""
SYNCER_PID=""        # pid (= process group id) of the syncer.sh currently running, for cleanup
SYNCER_TIMEOUT=${SYNCER_TIMEOUT:-30}
TIMED_OUT=0          # set by run_syncer

check() { # check <description> <command...>
    local d="$1"; shift
    if "$@"; then echo "ok   - $d"; else echo "FAIL - $d"; FAILS=$((FAILS+1)); fi
}

# Prints the pids of every process in process group $1. ps failing is an error, no match is not.
group_members() {
    local table
    table=$(ps -A -o pid= -o pgid=) || { echo "ps failed" >&2; exit 1; }
    awk -v g="$1" '$2 == g { print $1 }' <<<"$table"
}

# Kills the syncer's process group (sleep and rsync children included). Without job control
# the group kill fails, so fall back to the single process. Waits at most 5 s for it to go.
kill_syncer() {
    [ -n "$SYNCER_PID" ] || return 0
    kill -- "-$SYNCER_PID" 2>/dev/null || kill -KILL "$SYNCER_PID" 2>/dev/null
    local i
    for ((i = 0; i < 50; i++)); do
        [ -z "$(group_members "$SYNCER_PID")" ] && return 0
        sleep 0.1
    done
    kill -KILL -- "-$SYNCER_PID" 2>/dev/null || true  # best effort; the group may already be gone
}

cleanup() {
    kill_syncer
    [ -n "$WORK" ] && rm -rf "$WORK"
}
trap cleanup EXIT
trap 'exit 130' INT   # exit runs the EXIT trap
trap 'exit 143' TERM

make_tree() { # make_tree <sample dir> [nofinish]: scratch folders at several depths plus normal files
    local s="$1"
    mkdir -p "$s/scratch/sub" "$s/a/scratch" "$s/rawData"
    echo x > "$s/scratch/x.txt"; echo y > "$s/scratch/sub/y.txt"; echo z > "$s/a/scratch/z.txt"
    echo f > "$s/scratchfile.txt"; echo n > "$s/normal.txt"; echo t > "$s/rawData/tile.txt"
    # FINISHED makes syncer.sh stop after its first rsync
    [ "${2:-}" = nofinish ] || touch "$s/FINISHED"
}

# The sample dir must really have been copied (normal.txt) so the absence checks cannot pass vacuously.
no_scratch_dirs() { [ -f "$1/normal.txt" ] && [ ! -e "$1/scratch" ] && [ ! -e "$1/a/scratch" ]; }
keeps_files() { [ -f "$1/scratchfile.txt" ] && [ -f "$1/normal.txt" ] && [ -f "$1/rawData/tile.txt" ]; }

# Runs syncer.sh with output in $LOG, in its own process group, giving up after
# $SYNCER_TIMEOUT s. Sets TIMED_OUT. The group is killed afterwards in every case.
run_syncer() { # run_syncer <server dir> <landing dir>
    TIMED_OUT=0
    set -m
    bash "$SYNCER" -r -a -s "$1" -l "$2" >"$LOG" 2>&1 &
    SYNCER_PID=$!
    set +m
    local i
    for ((i = 0; i < SYNCER_TIMEOUT; i++)); do kill -0 "$SYNCER_PID" 2>/dev/null || break; sleep 1; done
    kill -0 "$SYNCER_PID" 2>/dev/null && TIMED_OUT=1
    kill_syncer
    wait "$SYNCER_PID" 2>/dev/null
}

no_group_left() { test -z "$(group_members "$SYNCER_PID")"; }
finished_in_time() { [ "$TIMED_OUT" -eq 0 ]; }
timed_out() { [ "$TIMED_OUT" -eq 1 ]; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/scratch test.XXXXXX") || exit 1
LOG="$WORK/syncer.log"
# No doubled slashes (a trailing-slash TMPDIR gives them); syncer.sh collapses them in its log.
WORK=$(cd "$WORK" && pwd) || exit 1
LOG="$WORK/syncer.log"

make_tree "$WORK/server dir/sample"
SRC="$WORK/server dir/sample/"

echo "== 1. syncer.sh with a normal sample dir"
mkdir -p "$WORK/land dir"
run_syncer "$WORK/server dir/sample" "$WORK/land dir"
D="$WORK/land dir/sample"
check "finishes within ${SYNCER_TIMEOUT}s" finished_in_time
check "leaves no process in its process group" no_group_left
check "does not copy scratch dirs" no_scratch_dirs "$D"
check "copies scratchfile.txt, normal files and tiles" keeps_files "$D"
EXPECTED_LOG="RUNNING --> rsync -a --include=/scratch/ --exclude=scratch/ $(printf '%q %q' "$WORK/server dir/sample" "$WORK/land dir") <--"
check "logs the exact, pasteable rsync command" grep -qF -e "$EXPECTED_LOG" "$LOG"

echo "== 2. syncer.sh with a sample dir that is itself named scratch"
make_tree "$WORK/server dir/scratch"
run_syncer "$WORK/server dir/scratch" "$WORK/land dir"
D="$WORK/land dir/scratch"
check "finishes within ${SYNCER_TIMEOUT}s" finished_in_time
check "syncs the sample dir" keeps_files "$D"
check "does not copy its nested scratch dirs" no_scratch_dirs "$D"

echo "== 3. a syncer.sh that never sees FINISHED is killed with all its children"
make_tree "$WORK/server dir/stuck" nofinish
SYNCER_TIMEOUT=3 run_syncer "$WORK/server dir/stuck" "$WORK/land dir"
check "times out" timed_out
check "leaves no process in its process group" no_group_left

echo "== 4. syncAndCrunch.m rsync commands"
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
