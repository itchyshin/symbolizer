# Changelog

## symbolizer 0.1.1.9000 (development)

### v0.2 (in progress) — bivariate Gaussian and structural comparison

- [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  reads bivariate Gaussian fits — the `biv_gaussian(y2 ~ ...)` family
  from drmTMB — through the same structured surface used for univariate
  fits. The response becomes a 2-vector `(Y_{1i}, Y_{2i})`, the
  conditional distribution becomes `MVN_2((mu_{1i}, mu_{2i}), Sigma_i)`,
  and the symbolic story now carries five submodels (`mu1`, `mu2`,
  `sigma1`, `sigma2`, `rho12`).
- New capability rows:
  `drmTMB,biv_gaussian,{mu1,mu2,sigma1,sigma2,rho12}` flip from “Planned
  or reserved” to “First slice”.
- Per-submodel response handling: `interpretation` rows for `mu1` /
  `sigma1` substitute `response_1`; `mu2` / `sigma2` substitute
  `response_2`; `rho12` rows reference both.
- `formula_bridge` carries one row per submodel including the new `mu1`,
  `mu2`, `sigma1`, `sigma2`, `rho12` parts; the `rho12` meaning reads as
  “Fisher-z residual correlation between {response_1} and {response_2}
  is a linear function of the correlation-model predictors”.
- Interpretation templates and assumption templates gain `biv_gaussian`
  rows (`inst/extdata/interpretation-templates.csv` and
  `inst/extdata/assumption-templates.csv`).
- New: `compare_symbolic(sym_a, sym_b, metrics = FALSE)` returns a
  structural diff between two `symbolized_model` objects. Slots: `meta`
  (left / right model summaries — class, family, response, n_obs),
  `diff_submodels` (presence per submodel: `left_only` / `right_only` /
  `both`), `diff_terms` (presence per (submodel, term_label) pair), and
  `diff_assumptions` (status on each side plus a `same_status` flag). S3
  class `symbolic_comparison`;
  [`print()`](https://rdrr.io/r/base/print.html) produces a structured
  cli block and `knit_print()` produces side-by-side markdown tables.
  Passing `metrics = TRUE` adds a fifth slot `diff_metrics` with AIC,
  BIC, log-likelihood, and df on each side plus their delta (right -
  left); the metrics block refuses to compute deltas when the two fits
  are obviously incomparable (different family, response, or n_obs) and
  instead carries a `comparable = FALSE` attribute plus a `note`
  explaining why. For fit-time identifiability and convergence
  diagnostics, run
  [`drmTMB::check_drm()`](https://itchyshin.github.io/drmTMB/reference/check_drm.html)
  (or the gllvmTMB analogue) per fit before interpreting the structural
  diff.

## symbolizer 0.1.1

### v0.1.1 — confidence bands, marginal estimates, and categorical pedagogy

#### Inference

- [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  gains a `ci_method = "wald"` argument and populates five new columns
  on `fixed_effects` and `interpretation`: `std_error`, `confint_low`,
  `confint_high`, `excludes_zero`, `ci_method`. Existing callers see
  additive columns only. Confidence bands come from
  `stats::confint(fit, parm, method, level)` dispatched on
  `confint.drmTMB`; passing `ci_method = "profile"` is honest
  (asymmetric) but slow. Satterthwaite / Kenward-Roger corrections wait
  on drmTMB.
- `print(parameter_interpretation(sym))` shows the band as `(lo, hi)`
  with a trailing `*` marker on rows whose 95% interval excludes zero;
  `knit_print()` adds a `95% CI` column to the rendered table and a
  footer naming the CI method. Renderers consume `metadata$ci_method`.

#### Marginal estimates (new)

- `group_means(sym, by = NULL)` — categorical marginal means via
  [`emmeans::emmeans()`](https://rvlenth.github.io/emmeans/reference/emmeans.html).
  By default returns one row per combination of factor levels in the
  model. Returns a tibble classed `symbolizer_group_means` with the same
  column shape as the interpretation rows (`estimate`, `std_error`,
  `confint_low`, `confint_high`, `excludes_zero`).
- `group_slopes(sym, continuous, at = NULL)` — per-group slopes for a
  continuous predictor via
  [`emmeans::emtrends()`](https://rvlenth.github.io/emmeans/reference/emtrends.html).
  Handles both cont × factor (one row per factor level) and cont × cont
  (`at = list(other_predictor = c(...))` returns one row per value).
- `model_card(sym)` extraction calls and bundle gain `marginal_means`
  and `marginal_slopes` slots so the teaching bundle includes the
  derived per-group views alongside the contrasts.
- Adds `emmeans` to Suggests.

#### Categorical pedagogy

- Interaction interpretation templates (`gaussian/mu/interaction_*`) now
  end with the call hint that takes the reader to the derived per-group
  view: `group_slopes(sym, continuous = ...)` for cont × factor,
  `group_means(sym, by = c(...))` for factor × factor,
  `group_slopes(sym, continuous, at = list(...))` for cont × cont.
- Intercept-less fits (`y ~ 0 + factor`) now produce cell-means
  descriptions in `symbol_table`: factor rows say
  `"factor (level_a, level_b — cell-means parameterisation)"` instead of
  marking a reference level. The interpretation rows pick a new
  `cell_mean` role with prose like “Expected {response} for {variable} =
  {level}”.
- `inst/extdata/interpretation-templates.csv` adds the
  `gaussian/mu/cell_mean` row.
- `vignettes/symbolizer-factors.Rmd` grows by +341 lines: a new Step 5
  walking through a continuous × continuous interaction end to end, and
  a new “Common pitfalls” section presenting six pitfalls (intercept ≠
  average; contrast ≠ group mean; interaction ≠ effect of A on B; Wald
  CIs can be too narrow; dropping the intercept doesn’t always do what
  you think; `poly(x, 2)` ≠ `I(x^2)`) in the Symptom / Diagnosis /
  WRONG-vs-RIGHT code / Rule format borrowed from the gllvmTMB pitfalls
  page.

#### API consolidation

- [`validate_symbolized_model()`](https://itchyshin.github.io/symbolizer/reference/validate_symbolized_model.md)
  is now `@keywords internal`, removed from the public NAMESPACE, and
  reachable as `symbolizer:::validate_symbolized_model()` for advanced
  users hand-building objects. Still listed under the pkgdown reference
  page’s “Internal: object construction” section.

#### Documentation

- Adds `VISION.md`: mission, audience priorities, ten core principles,
  what symbolizer is and is not, long-term direction.

### v0.1 surface (Stable)

- [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  builds a structured `symbolized_model` from a fitted `drmTMB` Gaussian
  location-scale model with fixed effects in both the mu and sigma
  submodels. Reads `fit$formula$entries`, `fit$family`,
  `fit$coefficients`, and
  [`drmTMB::fixef()`](https://itchyshin.github.io/drmTMB/reference/fixef.html)
  per dpar.
- [`extract_terms()`](https://itchyshin.github.io/symbolizer/reference/extract_terms.md)
  is the term-grammar / model-matrix bridge: every renderer consumes
  this layer and never re-parses formulas.
- Capability registry
  ([`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md))
  gates
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  with the five-level status vocabulary borrowed from drmTMB.

### Dual notation (index ↔︎ matrix)

- Every component carries both index-form and matrix-form LaTeX, with
  lowercase bold for vectors (`\mathbf{w}`, `\boldsymbol{\beta}`) and
  uppercase bold for matrices (`\mathbf{X}`, `\mathbf{Z}`).
- Symbol dictionary carries two dimension columns: abstract
  (`\mathbb{R}^n`) and concrete (e.g. `\mathbb{R}^{80}`).
- [`notation_bridge()`](https://itchyshin.github.io/symbolizer/reference/notation_bridge.md)
  returns an educator-facing translation table that pairs each model
  piece across both notations with its dimension.

### Renderers

- `equations(sym, notation)` returns the per-row LaTeX in either or both
  forms.
- `as_latex(sym, notation, env)` returns a single string ready to splice
  into a LaTeX document; stacks both forms when `notation = "both"`.
- `symbol_table(sym, notation)`, `assumption_table(sym)`,
  `formula_bridge(sym, notation)`.
- `parameter_interpretation(sym, scale)` exposes per-coefficient
  readings on link / natural / variance / biological scales.

### Random intercepts (First slice)

- `(1 | group)` on the mu submodel is supported. The mu linear predictor
  gains a `+ u_{group(i)}` term (index) / `+ \mathbf{u}` (matrix), a new
  random-effect distribution row appears in `components`, and the new
  `random_effects` and `variance_components` tibbles register the term.
- Random slopes and random effects on the sigma submodel raise a clear
  capability error pointing at the registry.
