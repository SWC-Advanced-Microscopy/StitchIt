---
type: infrastructure
complexity: complex
status: done
---

# Optional background curl upload in +webupload ('Background', true)

## Why
`webupload.postZip` blocks until the server answers (up to the timeouts). On a
BakingTray Windows acquisition PC with StitchIt co-installed, hundreds of
sequential uploads would each add a delay. With `'Background', true` the upload is
handed to a detached `curl` process and MATLAB returns at once. Without it,
behaviour is exactly as now.

## Proposed design
- New optional param/val `'Background'` (logical scalar, default false), accepted by
  `webupload.updateSectionImage`, `zipAndPost` and `postZip`, passed down via the
  existing `PosterArgs` mechanism. Absent/false = current code path untouched.
- In `postZip`, `Background` true: same validation of cfg/micID/source/zipPath, then
  write a curl config file (`-K`) in a temp location and launch curl detached:
  - Unix/Mac: `(curl -K cfg; rm -f cfg zip) > /dev/null 2>&1 &`
  - Windows: `start "" /B cmd /c "curl.exe -K cfg & del /q cfg zip"` (needs Win10+ curl.exe)
  The config holds the url, `Authorization: Bearer` header (value taken from
  `cfg.authHeader().Value`, so webConfig is unchanged), the form fields site_id,
  microscope_id, source and `data=@zip;type=application/zip;filename=system_data.zip`,
  `--connect-timeout` from cfg/override, `--max-time` = response timeout, silent. Putting the
  token in the config file rather than on the command line keeps it out of `ps`/Task Manager;
  the file is chmod 600 on unix and deleted by the same shell command after curl exits.
  curl does not follow redirects by default (matches the no-redirect rule).
- Zip lifetime: `zipAndPost` normally deletes the temp zip on exit, which would race the
  background curl. In background mode, when launch succeeded the launched shell command
  owns deletion (zip and curl config); if launch failed `zipAndPost` deletes the zip as now.
- Return value: `struct(ok=true, httpStatus=NaN, message='Upload started in background; outcome not checked')`
  when the process was launched; `ok=false` with the reason if curl is missing, the
  config could not be written or the launch call failed. Token scrubbed as now. A failed
  upload is invisible by design (as you accepted). The 429 retry for `Finished` is skipped
  in background mode (no status to see).
- `updateSectionImage` needs nothing else: stage folder reuse is safe because the zip is a
  separate temp file made before launch.
- Tests: validation unchanged in background mode; generated curl config has the right
  fields and no token on the command line; command string for unix/pc branches (injectable
  launcher so no real process is needed); a real end-to-end test against a local
  `http://127.0.0.1` listener on the unix test machine, checking the server receives
  the multipart fields with a Content-Length (FastCGI problem noted in `postZip`), and
  that zip and config are removed afterwards. Windows branch can only be checked by command-string
  test here; needs a live check on a Windows rig.
- README: document `'Background'`.

## Decisions (PI confirmed)
1. Token in a temp curl config file (600, deleted after) is OK.
2. Background result is ok=true plus an extra `result.background=true` field (false/absent otherwise).
3. Build on `origin/webupdate`.

## Acceptance criteria
- Default behaviour and all existing tests unchanged and passing.
- `'Background', true` returns immediately (no network wait) and the upload arrives at a local test server.
- Token never appears in a command line or in a returned/warned message.
- Temp zip and curl config are removed after curl finishes, in the success and failure cases.
