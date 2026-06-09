# Structural comparison of two symbolized models

Compares two
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
objects and returns a structured diff covering:

- **meta** — class, family, response, and `n_obs` for each side.

- **submodels** — which submodels appear only on the left, only on the
  right, or on both sides.

- **terms** — within each shared submodel, which term labels appear only
  on one side or on both.

- **assumptions** — for each assumption, the statuses on each side and
  whether they match.

- **metrics** *(optional, when `metrics = TRUE`)* — AIC, BIC, log-
  likelihood, and residual degrees of freedom on each side plus their
  delta. The metrics block refuses to compute deltas when the two fits
  are obviously incomparable (different family, different response,
  different `n_obs`) and instead carries a `note` column explaining why.

Use it to ask questions like "what's different between this fit and the
previous one?" — a structural answer rather than a numeric one.
Coefficient values are not compared; this is the structural-symbolic
diff. For coefficient-level differences, use the
[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
tibbles directly. For fit-level identifiability and convergence
diagnostics, run
[`drmTMB::check_drm()`](https://itchyshin.github.io/drmTMB/reference/check_drm.html)
(or the analogous diagnostic for `gllvmTMB`) on each fit before
interpreting the structural diff.

## Usage

``` r
compare_symbolic(sym_a, sym_b, metrics = FALSE, ...)
```

## Arguments

- sym_a, sym_b:

  Two `symbolized_model` objects.

- metrics:

  Logical, default `FALSE`. When `TRUE`, joins the AIC / BIC /
  log-likelihood / df from each side as a fifth slot `diff_metrics` and
  adds a `delta` column. Requires that each side carries its fit object
  on `metadata$fit` (this is the default for
  [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  and
  [`symbolize.gllvmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.gllvmTMB.md)).

- ...:

  Reserved for future use.

## Value

A list classed `c("symbolic_comparison", "list")` with four slots
(`meta`, `diff_submodels`, `diff_terms`, `diff_assumptions`), plus a
fifth `diff_metrics` slot when `metrics = TRUE`.

## Examples

``` r
# a <- symbolize(lm(mpg ~ wt, data = mtcars))
# b <- symbolize(lm(mpg ~ wt + hp, data = mtcars))
# compare_symbolic(a, b)
```
