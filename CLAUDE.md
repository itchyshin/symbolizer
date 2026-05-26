# Claude Code project instructions for symbolizer

@AGENTS.md

## Top discipline rule (non-negotiable; supersedes everything else)

**Accuracy over speed. Never rush. Never ship without looking.**

Repeated failure pattern: I generate user-facing HTML / widgets / vignettes,
the surface compiles cleanly, I describe what it "should" look like, and
I declare it shipped without opening it visually. The user then opens it,
finds bugs, and I owe them an audit.

Hard rule for every Claude session in this repo:

1. **Florence visual-check is mandatory** for any user-facing rendered
   output (HTML widget, vignette, README, pkgdown page, PDF). "Florence
   visual check" means: I open the actual rendered file in a browser /
   viewer / read the actual PDF bytes / fetch the deployed page and look
   at it. Not "the source looks right". Not "the LaTeX string is what I
   expected". The actual rendered page.
2. **One bug surfaced by the user means ten more in the same pattern.**
   The Rose convention: if I find one mistake, scan the codebase for the
   same pattern before fixing the visible one. The visible bug is the tip.
3. **No "let me just ship it and we'll iterate"**. If something needs
   verification, verify it. If verification can't be done in this session,
   commit only with WIP labels and explicit "not Florence-checked" in the
   commit message.
4. **Demos that show data must be biologically coherent.** See Darwin's
   rule in `.memory/MEMORY.md` (comparative analyses use log-transformed
   traits with values clustering around -2 to 2, not raw single-species
   ranges).

When in doubt, stop. Ask. Re-read. The user's time spent telling me
"this is broken" costs more than the time I would have spent looking.

## Adopted protocols (from drmTMB + gllvmTMB sister repos)

symbolizer follows the same review-process conventions as drmTMB and
gllvmTMB. Source-of-truth files for the protocols:
`/Users/z3437171/Dropbox/Github Local/drmTMB/AGENTS.md` and
`/Users/z3437171/Dropbox/Github Local/gllvmTMB/CLAUDE.md`.

### Default mode: read-only audits

Claude's default mode in this repo is to **gather evidence, write
read-only audits, draft decisions, and identify the smallest safe PR
shape**. The maintainer chooses what ships. I do not silently expand
implementation scope. I do not start large refactors without an
explicit "go" from the maintainer.

### Definition of Done

A feature is done only when ALL of these are present:

1. Implementation
2. Tests (helper fixture + per-package + cross-package where relevant)
3. Roxygen2 documentation
4. Examples or vignette section
5. `rcmdcheck` 0 / 0 / 0
6. **Florence visual-check** on every user-facing rendered surface
7. After-task report under `.memory/reports/YYYY-MM-DD-<topic>.md`
8. NEWS.md entry

A WIP commit is fine; "shipped" requires all 8.

### Surface review touchpoints at stopping points

At every natural stopping point — task end, waiting on CI, waiting on
maintainer decision, end of phase, before switching context — surface:

1. **Open PR links** the maintainer can click to read.
2. **Commit hashes** that landed this session (with WIP / Release tags).
3. **After-task report path(s)** that just landed or are about to.
4. **Anything blocking** the maintainer needs to decide. Prefix with
   🔴 **Needs you:**

Default assumption: if a stopping point arrives and the message does
not surface links, the maintainer cannot review.

### After-task reports are the closure rule

Every completed task or phase writes
`.memory/reports/YYYY-MM-DD-<short-tag>.md` with:

- **Scope**: what was in / out.
- **Outcome**: what landed (commits, tags, issues).
- **Checks**: which Florence checks were done; which were skipped and why.
- **Follow-up**: what's deferred to the next session, what's blocked.

The reports are how the shared team learns without re-reading the diff.
This file is gitignored (stays local) per AGENTS.md.

### Florence is a named role

Add to the team roster (`.github/VISION.md`):

**Florence** — Scientific figure / widget / vignette visualization
reviewer. Primary questions: Are rendered surfaces (HTML widgets,
pkgdown pages, PDF exports, README plots) publication-quality,
interpretable, accessible, and honest? Florence leads the final
visual standard, but every role contributes: Pat (reader flow),
Fisher (uncertainty honesty), Rose (stale claims), Darwin (biology),
Grace (render evidence), Boole (syntax), Noether (math correctness).

### widget-visual-audit protocol

For every render of `as_html_three_views()`, `as_pdf_three_views()`,
`equations()`, `model_card()`, or any vignette, run this checklist
BEFORE saying it's done:

- [ ] Open the rendered file in a browser / PDF viewer (or `Read`
      tool for PDF bytes).
- [ ] Confirm math renders (no raw `\(...\)`, `\sigma_{...}`,
      `\\begin{aligned}` leaking as text).
- [ ] Confirm symbols are consistent across panels (e.g. response
      symbol matches between worked-row and matrix block).
- [ ] Confirm captions use `$...$` delimiters (the only inline-math
      form the standalone HTML's MathJax config recognises).
- [ ] Confirm the biology gloss matches the model context (phylo
      models need across-species reading; spatial models need
      geographic reading; default Gaussian gloss is wrong for both).
- [ ] Confirm data values are biologically coherent for the context
      (Darwin's rule).
- [ ] If the structured-covariance matrix exists, confirm it's
      surfaced in EVERY view (distribution line in index form, matrix
      form, AND data view) — not just one.
- [ ] Confirm `metadata$phylo_representation` /
      `metadata$spatial_representation` is set when expected.

## symbolizer-specific notes

- **Architectural rule**: every prose output is templated from `inst/extdata/*.csv`. Never write string-spliced prose in `R/`.
- **Term-grammar bridge** in `R/extract-terms.R` is first-priority infrastructure; tests come before implementation.
- Match drmTMB and gllvmTMB code conventions: kebab-case files, snake_case functions, `cli::cli_*` messaging, roxygen2 markdown, testthat 3 + snapshots.
- For any new `(class, family, component)` tuple, add a row to `inst/extdata/capabilities.csv` with one of the five status words **before** exporting a method.
- The fitted-object source of truth for the v0.1 extractor is `R/symbolize-drmtmb.R` — the header comments document the real `drmTMB` object shape (`fit$formula$entries`, `fixef(fit, dpar)`, `fit$family$family`, etc.).
