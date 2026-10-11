---
type: infrastructure
complexity: simple
status: done
---

# Make syncAndCrunch's rsync calls ignore a folder named "scratch"

A `scratch` folder will in future hold files that must stay on the acquisition
machine and never be copied to the analysis machine. Add `--exclude='scratch/'`
(directory-only match, any depth) to all three rsync invocations used by
syncAndCrunch: the initial rsync and the first-batch rsync in
`code/processDuringAcquistion/syncAndCrunch.m`, and the loop in
`code/processDuringAcquistion/syncer.sh`. Nothing else changes.

Base branch: `origin/webupdate`.

## Acceptance criteria
- All three rsync calls exclude a directory named `scratch`.
- Test (shell or MATLAB, whichever fits the repo; rsync is available locally): build
  a temp source tree containing `scratch/x.txt`, `scratch/sub/y.txt`, `a/scratch/z.txt`,
  a file named `scratchfile.txt` and normal files; run the same rsync args; assert the
  scratch directories are not copied and `scratchfile.txt` and normal files are.
- The quoting survives `unix(CMD)` and the `syncer.sh` argument handling (spaces in paths still work).
