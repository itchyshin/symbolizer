# Page audit: symbolizer-compare

Date: 2026-05-30
Sources read: `docs/articles/symbolizer-compare.html`, `vignettes/symbolizer-compare.Rmd`
Cross-checked: `R/compare-symbolic.R` (print + knit_print methods), `R/knit-print.R`.

## Summary

`symbolizer-compare: 0 blockers, 2 majors, 2 minors`

## Lens 1 — RENDERING

- Clean. No un-typeset LaTeX in the body; the only math (`\(\boldsymbol{\Lambda}_B\)`, HTML line 884) is inside a `<span class="math inline">` and MathJax-handled. No literal `\n`, no raw kable pipe rows (`|:---|`), no duplicated DOM (1 `<h1>`, 3 "Model summaries" blocks = one per worked example). All six tables typeset.

## Lens 2 — MATH (structural diff accuracy vs the two fits shown)

- Ex1 submodels/terms diff accurate: `log(food)` left_only in mu, `temperature` left_only in sigma; intercepts + `temperature` both. Matches fit_full vs fit_reduced.
- Ex2 assumption-flip accurate: `independence` left=implied/right=NA and `independence_given_random_effects` left=NA/right=stated correctly reflect adding `(1 | site)`. df delta +1, AIC delta +2.000 consistent (1 extra df, ~zero logLik gain).
- Ex3 submodels/terms/assumptions diff accurate: univariate `mu, sigma` left_only; bivariate `mu1/mu2/sigma1/sigma2/rho12` right_only; metrics delta all NA with correct incomparable note. Arithmetic of all displayed deltas reconciles with the full-precision underlying values.
- [MAJOR] HTML line 546 / Rmd line 158: prose claims `compare_symbolic` "marks the change with `*` in the print output and surfaces both rows," but the rendered article (and every other vignette) renders the comparison via `knit_print.symbolic_comparison` (`R/compare-symbolic.R:351`), which emits a plain `knitr::kable` of `diff_assumptions` with NO `*` marker. The ` *` marker exists ONLY in the console `print.symbolic_comparison` method (`R/compare-symbolic.R:294`). A reader sees the `same_status = FALSE` / `NA` cells in the table but no `*` anywhere — the instruction points at a marker absent from the rendered output.

## Lens 3 — READER-FLOW

- Strong overall: intro blockquote gives a one-sentence hook; every section (1–5) ends with a bold **Takeaway**; "When NOT to use" section is well scoped.
- [MAJOR] HTML lines 340–343 (Ex1): the delta-sign explainer reads "A negative AIC delta means the *right* fit (here, the reduced model) has lower AIC than the *left* (here, the full model)" — but the displayed AIC delta is **+46.54** (positive), i.e. the reduced model has the *higher* AIC and the full model is preferred. Teaching the convention with the opposite sign to the actual table actively mis-cues which model won; the immediately preceding paragraph already (correctly) says AIC picks the balanced model. Reword to describe the positive delta actually shown.
- [MINOR] HTML line 528 (Ex2 logLik delta) renders as `-0.00000004182` (formatC `format="fg"` expands the ~ -4.2e-08 float to fixed notation). Visually noisy and easy to misread as a real difference; would read better as `~0` / scientific notation. The near-zero logLik delta also signals a boundary/degenerate site-intercept variance — the vignette's own convergence caveat — but is left uncommented (interpretation gap, not flagged separately).

## Lens 4 — CONSISTENCY

- Symbols and submodel names consistent across prose and tables; family/response/n_obs columns match the fits. Navbar version `0.22.3` current; no stale version refs in body.
- [MINOR] HTML line 10: favicon `<link rel="icon" type="”image/svg+xml”" ...>` uses curly quotes inside the `type` attribute (invalid MIME type). Site-wide template defect — shared by 13 articles — not specific to this page; flag for the template, not this Rmd.
