## Submission summary

`symbolizer` turns fitted statistical models into structured symbolic
specifications that render as LaTeX equations, assumption tables, parameter
interpretations, and teaching-oriented HTML widgets.

## R CMD check results

Local `R CMD check --as-cran` (macOS, R 4.x): **0 errors | 0 warnings | 2 notes**.

* **NOTE — New submission.** Expected for a first submission.

* **NOTE — `Suggests or Enhances not in mainstream repositories: drmTMB, gllvmTMB`.**
  These are companion packages by the same author, available from GitHub
  (`itchyshin/drmTMB`, `itchyshin/gllvmTMB`). All usage of them is fully
  conditional: every example, test, and vignette chunk that needs them is
  guarded by `requireNamespace()` / `skip_if_not_installed()` / chunk
  `eval = requireNamespace(...)`. The package installs, `R CMD check`s, and runs
  its full (non-suggested) test suite without either package present; on a
  machine lacking them, the relevant vignette sections render as conditional
  skips rather than errors. symbolizer is a notation/interpretation layer that
  is *complementary* to these modelling packages — supporting them as optional
  Suggests is the intended design.

(The local check also emits a third note, "checking HTML version of manual …
'tidy' doesn't look like recent enough HTML Tidy" — this is a property of the
local machine's HTML Tidy binary, not the package, and does not reproduce on
CRAN's check machines.)

## Pre-submission checklist (maintainer)

Before the actual upload, decide the CRAN strategy for the GitHub-only Suggests:

1. **Remove the `Remotes:` field** from `DESCRIPTION`. It is present only to let
   developers/CI auto-install the GitHub-only Suggests; CRAN flags it as an
   unknown field. Once removed, install `drmTMB`/`gllvmTMB` from GitHub manually
   for local development (see `CONTRIBUTING.md`).
2. **Resolve the non-mainstream-Suggests note** by either (a) submitting
   `drmTMB`/`gllvmTMB` to CRAN first, (b) keeping them as conditional Suggests
   and relying on this justification (CRAN sometimes accepts a well-justified
   GitHub-only Suggests), or (c) deciding symbolizer remains a GitHub/pkgdown
   product and is not submitted to CRAN.

## Test environments

* Local: macOS, R 4.x — `R CMD check --as-cran` (manual + vignettes built).
* (Add `win-builder` / R-hub / GitHub Actions ubuntu-macos-windows before upload.)

## Downstream dependencies

None (new submission).
