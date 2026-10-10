# webupload (MATLAB)

The brainsaw web preview client, shared by BakingTray (source `acq`) and
StitchIt (source `analysis`): loads and validates the config file, stages the
preview files in a clean folder under the names the server keeps, writes
`status.json`, zips the folder, and uploads the zip to the brainsaw server,
using only built-in MATLAB (`imwrite`, `zip`, `matlab.net.http`), so it works
on Windows and Mac with no external tools. It knows nothing about BakingTray or
StitchIt: each calls `webupload.updateSectionImage` (below). Example call sites
for BakingTray are in `BakingTray/README.md`.

Requires MATLAB R2019b or later (the oldest release BakingTray supports):
`matlab.net.http.io.MultipartFormProvider` needs R2019b, and option parsing
uses `inputParser`, not `arguments` blocks. The Image Processing Toolbox is needed (imresize makes the thumbnails).

## Path

Add the `upload_core` folder (the one containing `+webupload`) to the MATLAB
path: `addpath('<path>/upload_core')`. Add the folder itself, not the
`+webupload` folder inside it, and not via `genpath`. In this repo, on a
development machine, `add_to_path` does this together with the simulator
folder.

## Config file

Copy `private/webpreview_config.example.json` to a location outside any repository
(the file holds the secret token) and fill it in. There is no default
location: the calling code decides where the file lives and passes its path to
`webupload.webConfig`. A copy inside a checkout must be named
`webpreview_config.json` so `.gitignore` protects it. Never commit a
filled-in copy.

```json
{
  "url": "https://your-server.example/brainsaw/upload.php",
  "siteID": "YOUR_SITE_ID",
  "token": "YOUR_SECRET_TOKEN"
}
```

`url` must be `https://`; plain `http://` is accepted only for `localhost` /
`127.0.0.1`, for testing against a local server. `siteID` must start with a letter and contain only
letters, digits, `_` and `-`. The server keeps one token per site, so `siteID`
and `token` must both match its settings file; any mismatch is an HTTP 403.
The microscope ID is not a config setting: it is `SYSTEM.ID` in the recipe (see
below). A config file with a `micID` field is refused (`webupload:configMicID`). Optional fields `connectTimeout`,
`responseTimeout`, `dataTimeout` (seconds; defaults 15, 60, 60) can be raised
for slow uplinks. It is unverified whether ResponseTimeout/DataTimeout cover
the transfer of the upload itself; a warning `webupload:postZip:noTimeout`
is issued if this release lacks either property. Redirects are never followed
(the token must not be re-sent elsewhere); a 3xx reply is a failure.

`updateSectionImage` builds the config object itself from `brainsaw_webpreview.json`, found on
the MATLAB path (it should appear in one place only; the first is used, with a warning if
there are more). To use another file, build the object once and pass it with `'cfg'`:

```matlab
cfg = webupload.webConfig(file);       % the path is required
```

Token: `webupload.webConfig` keeps the token private: it cannot be read by
property access, `disp` or `save` (`struct(cfg)` still can expose it, a MATLAB
limitation), and an object loaded from a MAT file has no token, so always build
it from the JSON. Code that needs the token calls `cfg.authHeader()` (the
`Authorization` header) or `cfg.scrub(msg)` (removes the token from a message).
The constructor always scrubs its own errors, using a regexp on the raw file
text, so they are safe even if the JSON cannot be parsed.

## Updating the web preview

`res = webupload.updateSectionImage(img, 'Source', src, ...)`
is the call instrument and analysis code make. Run it from the section folder:
it finds the recipe (StitchIt's `getRecipeFileName`) and the acquisition log (the one
`acqLog_*.txt` in the folder), and the config file (`brainsaw_webpreview.json`, found on the
MATLAB path; see `webupload.getConfigFilePath`). Pass `'recipePath'`, `'logPath'` or `'cfg'`
(a `webupload.webConfig` object) to use others. It stages the files, writes
`status.json`, zips and uploads, and **never throws**: any problem becomes a
warning `webupload:updateSectionImage:failed` (`id: message`) and `res.ok =
false`, so an acquisition is never interrupted. (It cannot catch a path
variable that does not exist in the caller: MATLAB raises that before the
function runs, so guard the call with `try`.) The call is synchronous and
holds the caller when the server is dead or stalled: by default up to about the
connect, response and data timeouts of the config (15 s, 60 s, 60 s). Pass
`'ConnectTimeout'`, `'ResponseTimeout'` and `'DataTimeout'` to shorten that for
a call that must not wait. A Finished call that is answered with a 429 waits
about 6 s and posts again, so it can block for about twice those timeouts plus
6 s.

`img` is one of:

| `img` | meaning |
| --- | --- |
| `[]` | no image. A staged image is deleted (after the new files are in place, before the upload), so an old sample's image never goes up with a new recipe. Use for the call at the start of a run. |
| numeric array (gray HxW or RGB HxWx3) | converted to a jpg (see below) |
| path of a `.jpg` file | copied in as `LastCompleteSection.jpg` |

Whenever an image is staged, a card thumbnail `tile_thumbnail.jpg` (500 px wide,
aspect ratio kept, made with imresize) is staged beside it; the server shows
it on the cards instead of the full image. With `[]`, or if the thumbnail cannot
be made (warning `webupload:stageFiles:thumbnailFailed`), no thumbnail is sent and
the card shows the full image.

Anything else makes the call fail. The microscope ID is `SYSTEM.ID` of the recipe
(`readRecipe`); if it is missing or invalid nothing is staged or sent.

| option | meaning |
| --- | --- |
| `recipePath` | path of the recipe file; default: the recipe found in the current folder |
| `logPath` | path of the acquisition log; default: the one `acqLog_*.txt` in the current folder |
| `cfg` | `webupload.webConfig` object; default: built from `brainsaw_webpreview.json` on the MATLAB path |
| `Source` | `'analysis'` (default, StitchIt) or `'acq'` (BakingTray must pass this). `'acq'` is the ground truth for the finished state: an `analysis` upload cannot undo it |
| `Montage` | image to send as `montage.jpg`, as for `img` (array or jpg path). Only with `Source` `'analysis'`: with `'acq'` the call fails and sends nothing |
| `Finished` | `true` writes `{"finished": true}` into `status.json` (default `false`). Only a Finished call is retried, once, after a 429, waiting this client's copy of the server's minimum upload interval (`serverLimits().minUploadIntervalSec`, 5 s) plus 1 s, with the same timeouts. A site that raises the interval on the server will answer the retry with another 429, and the Finished flag is lost (`ok` false, with the usual warning) |
| `ConnectTimeout`, `ResponseTimeout`, `DataTimeout` | seconds, for this call only (see `postZip`; whether `ResponseTimeout` and `DataTimeout` cover the upload transfer itself is unverified) |
| `ClearStage` | `true` empties the stage folder first; default `false` |
| `StageRoot` | parent of the stage folder; default `tempdir`; text options may be strings, paths are returned as char |
| `Poster` | function handle `poster(folder, cfg, micID, source, ...)` returning `struct(ok, httpStatus, message)`; default `@webupload.zipAndPost`; for tests |

Result fields: `ok`; `stage` (the `stageFiles` result); `post` (`ok`,
`httpStatus`, `message`); `stageDir`; `recipeFresh`, `logFresh` (this call
staged a new recipe/log); `stale` (either is false; a log that is permanently
absent keeps `stale` true on every call, with a notice each time); `error` (an
`MException` built from the scrubbed message, `[]` on success). The recipe is
always copied afresh: if it cannot be staged, any recipe left from an earlier
call is deleted and nothing is uploaded. If the log cannot be staged, the
previous one is uploaded only when the previously staged recipe has the same
sample ID as the new one; otherwise no log is uploaded. Either way the call is
reported as `stale` (`webupload:updateSectionImage:stale`). Messages,
including a custom `Poster`'s, are scrubbed with `cfg.scrub`, so the token
never appears in them.

The stage folder is `<StageRoot>/brainsaw_webpreview/<siteID>/<micID>/<source>`,
reused between calls so only the latest files exist; it is not deleted
afterwards. Where `tempdir` is shared between users (Linux `/tmp`), pass a
private folder as `StageRoot`. The sources (recipe, log, jpg) must not be inside
the stage folder: it holds fixed file names that are overwritten or deleted. Two MATLAB sessions using the same site, microscope ID, source and
`StageRoot` share it and will overwrite each other's files.
`webupload.clearStage(cfg, micID, 'Source', src)` empties it without
uploading anything; it never throws (warning `webupload:clearStage:failed`).

`webupload.stageFiles(img, recipePath, logPath, stageDir)` is usable alone and still takes the paths. It
writes `LastCompleteSection.jpg` and its thumbnail `tile_thumbnail.jpg`, `montage.jpg` (if given), `recipe.yml` and
`acqLog.txt` under temporary `.part` names and renames them into place, so a
zip taken meanwhile never sees a half-written file. Files in the stage with
other names are left alone: the server ignores them.

### Images that are not uint8

uint8 is used as is. uint16 and int16 are autoscaled to `[0 max(img)]`, so
11-14 bit camera data is not near-black; negatives clamp to 0. There is no option
to fix the mapping: scale the image before the call if brightness must not vary
between sections. Details: `help webupload.toUint8`.

## Uploading a folder

`webupload.zipAndPost(folder, cfg, micID, source)` zips a folder, uploads and
deletes the temp zip, returning `struct(ok, httpStatus, message)` and never
throwing. `zipFolder`, `postZip` and `selectUploadable` are also usable alone.

`source` is `'acq'` (BakingTray) or `'analysis'` (StitchIt). `micID`
must match the server's ID rule (`serverLimits().idRegexp`): a letter, then
letters, digits, `_` and `-`. `micID` and `source` may be char or string. If
either is wrong the result is `ok = false` with a message that says whether the
ID was missing or invalid, and shows it; no request is sent. Optional
`'ConnectTimeout'`, `'ResponseTimeout'` and `'DataTimeout'` (seconds) replace
the config values for that one call, for example `'ConnectTimeout', 5,
'ResponseTimeout', 10, 'DataTimeout', 10` for a call that must not block its
caller for long.

The folder must contain `recipe.yml` and `status.json`, or the server refuses
the upload (HTTP 400).

`[micID, sampleID] = webupload.readRecipe(recipeFile)` reads `SYSTEM.ID` and
`sample.ID` from a recipe, in block or flow YAML style, without a YAML parser.
A trailing ` #` comment is dropped, one pair of quotes is removed, and white
space is trimmed. The microscope ID has each space replaced with `_`, as the
server does (`Scope A` gives `Scope_A`). A field it cannot find is `''`, which
`postZip` then refuses. `tests/recipe_id_vectors.json` holds the cases, and the
server's tests use the same file.

`webupload.writeStatus(folder, finished)` writes `status.json`,
`{"finished": true|false}`.

Form fields sent: `site_id`, `microscope_id`, `source`, `data` (the zip), with
the token in an `Authorization: Bearer` header. Only files the server keeps are
zipped: the name whitelist (`allowedNames`) mirrors `BS_ZIP_ALLOWED_NAMES` in
`brainsaw/lib.php`; a test compares them when `lib.php` is present. Any other
name is skipped. Client-side limits (`serverLimits`, from
the server defaults): at most 500 files and a 200 MB zip. If the server's PHP
`post_max_size` is smaller than the zip, the failure can appear as an HTTP 403
rather than 413. `interpretResponse` turns the HTTP status and body into the
result structure.

## Windows notes

Only built-in MATLAB is used. Paths are built with `fullfile`. MATLAB does not
expand `%VAR%` in paths: use `getenv('USERPROFILE')` when you need the home
folder. The stage folder is under `tempdir` (normally the user's `Temp`).
Antivirus or a file held open elsewhere can make a rename fail; that is a
staging-failure warning (`webupload:stageFiles:stageFailed`), not an error.

## Tests

From the repo root:

```
/Applications/MATLAB_R2023b.app/bin/matlab -batch "add_to_path; r=runtests('upload_core/tests'); disp(table(r))"
```

(use your own MATLAB path). The tests add the packages to the path themselves. They
need no real server (one test posts to a refused `127.0.0.1` port). Two tests
wait about 6 s each: the two 429 retry tests of a Finished call.

Nothing in this module has been run against a live brainsaw server. Treat the
first real acquisition as the test, on a spare site ID.
