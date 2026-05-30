# Page audit: symbolizer-structural-dependence

Date: 2026-05-30. Read-only audit of `docs/articles/symbolizer-structural-dependence.html` + `vignettes/symbolizer-structural-dependence.Rmd`. Lenses: rendering, math, reader-flow, consistency.

## Summary

`symbolizer-structural-dependence: 0 blockers, 3 majors, 3 minors`

The core MATH ask passes: all three Faces render the phylogenetic effect with the A correlation matrix, not a bare iid RE. MCMCglmm Index/Matrix tabs show `u_species ~ N(0, sigma^2 A)` and the Cov(u) block renders `Cov(u) = sigma_p^2 . A_{116x116}` (bmatrix auto-sizes; brackets fine). brms `assumption_table` carries `phylo_random_effect: u_p ~ N(0, sigma_p^2 A)` + `phylo_A_positive_definite` + `phylo_tips_only_representation`. phylolm shows dense `Cov(e) = sigma_p^2 A` / `y ~ N(Xbeta, sigma_p^2 A)` (PGLS marginal), NOT diagonal. No false marginal-independence row anywhere; A never mislabeled as iid `u_p`. Single widget, unique id `sym-mcmc-1780105253`, no duplicate DOM. No literal LaTeX leaking; no `\n` in headings; matrix uses head+tail truncation (no 60-col overflow); no stripped-space species labels (matrix cells are numeric).

## Defects

- [MAJOR] Face 1 "Equations with data" tab (HTML ~660-690): worked row shows `zr_1 = beta_0 + epsilon_1` and stacked vector shows `zr = X beta + epsilon` with NO `u` column — the phylo random effect is silently folded into the residual, defeating the structural-dependence teaching point and contradicting the Index/Matrix tabs which correctly show `mu = X beta + u`.
- [MAJOR] Face 1 same tab caption (HTML 692-694) asserts "Middle: the prediction X beta-hat + u-hat = mu-hat", but the displayed middle term is `X[beta]` only with no u-hat — caption contradicts its own equation; also contradicts prose at HTML 390-392 claiming Tab 3 "shows the predicted per-observation random effect u_species(i) directly".
- [MAJOR] brms `assumption_table` injects two spurious scale/location-scale rows for a plain `gaussian()` fit with no distributional submodel: `linear_predictor: log(sigma_i) = gamma_0 + sum gamma_k Z_ki` ("scale-model predictors", HTML 874-880) and `positivity: sigma_i > 0 ... via the log link` (HTML 890-896). False assumptions for `Zr ~ 1 + (1|gr(species, cov=A))`.
- [MINOR] Face 1 worked row renders nonsensical equality `mu-hat_1 = 0.366 ~~ 0.214` (HTML 663): 0.366 is beta-hat_0 and 0.214 is mu-hat_1; they differ by ~70% (u-hat_1 ~ -0.152), so the `approx` sign is false math shown to the reader.
- [MINOR] Closing prose (HTML 1141-1144) claims all three fits produce "the same `metadata$detected_signals = "phylo"`", but phylolm's actual printed output is `[1] "phylo_marginal"` (HTML 990) — and its inline comment still says `# "phylo"`. Same-symbol/same-output consistency claim contradicted by the page's own output.
- [MINOR] MCMCglmm + brms variance-component tables label the phylo/species variance row `parameter = "mu"` (HTML 433, 818); opaque for a variance row (denotes the mean submodel, not the phylo variance). Systematic, not a one-off, but reads as mislabeled to a biologist.

## Notes (not defects)

- Reader-flow: Face 1 has a blue biology takeaway callout; light Faces 2/3 rely on the `assumption_table` "biological meaning" column (serviceable).
- A symbol is consistent across all Faces; sigma_e^2 vs v_i are explicitly distinguished (HTML 86-87, 347-355), not conflated.
