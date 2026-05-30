# Audit: symbolizer-roadmap

Read-only audit of `docs/articles/symbolizer-roadmap.html` + `vignettes/symbolizer-roadmap.Rmd` on 2026-05-30.
Cross-checked against `inst/extdata/capabilities.csv`, `DESCRIPTION` (0.22.3), `NAMESPACE`, `_pkgdown.yml`, `NEWS.md`.

## Defects

- [BLOCKER] Version drift: navbar/DESCRIPTION = 0.22.3 but the "What's covered today" H2 says "(v0.1 – v0.18.x)" (HTML L133) and the release-history table stops at v0.18.3 (HTML L476). Four-plus shipped minor versions are absent: phylogenetic flagship (phylolm + drmTMB/brms/MCMCglmm/glmmTMB phylo, all `First slice` since 0.21.0/0.21.4), gam poisson/binomial/Gamma smooths (0.22.5), meta-analytic bridges meta_known_vi / meta_phylo_multilevel (0.22.1), gllvmTMB within-unit Lambda_W/Psi_W/Sigma_W/Repeatability (0.21.6). The v0.18.3 line "roadmap article rewritten to match shipped reality" is itself now stale.
- [MAJOR] Flagship status wrong: "Considered" row (HTML L333) still lists the Phylogenetic flagship (phylolm, phyloglm, ...) as future, but capabilities.csv shows phylolm gaussian/phylo and phylo bridges across 5 classes shipped `First slice` (0.21.x). The shipped flagship is filed under not-yet-built.
- [MAJOR] Backslash-pipe leaks in rendered table cells: HTML L404 `(1 \| g)`, L451 `(1 \| site)`, L479 `(1 \| group)` show literal `\|` to the reader. L479 is the very entry claiming the pipe-encoding bug was fixed. Model-classes table (L166/L172) uses bare `(1|g)` and renders fine — inconsistent escaping.
- [MAJOR] Cross-cutting-surfaces table (HTML L228-306) and "Core public functions" list (L498-508) both omit exported core functions: `variance_partition()`, `icc()` (the dev-version NEWS headline surface), `as_pdf_three_views()`, `explain()`, `notation_bridge()`. The list claims to be "the things users actually call" yet drops 5 exports.
- [MINOR] mgcv coverage understated: model-classes table (L215) lists smooths generically with no signal that poisson/binomial/Gamma smooths are now open (capabilities.csv L119-121, shipped 0.22.5). A reader cannot tell these moved from planned to working.
- [MINOR] Stale counts: "10 package families, 14 fitted-class methods" (L221) and "all 10 extractors" (L464) undercount — phylolm adds an 11th class method (symbolize.phylolm in NAMESPACE + _pkgdown.yml).

## Clean

- RENDERING: MathJax loaded site-wide (HTML L14); article has no display math, no un-typeset equations, no literal `\n`. Tables carry colgroup width specs — no untyped/clipping tables.
- propto() described correctly: v0.16 row (L444) frames propto as phylogenetic / structured-covariance, explicitly NOT the meta-analysis bridge — matches capabilities.csv L71.
