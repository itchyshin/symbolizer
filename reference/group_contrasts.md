# Pairwise and reference contrasts between factor levels

`group_contrasts()` compares the levels of a factor against each other
(or against a reference), delegating to
[`emmeans::contrast()`](https://rvlenth.github.io/emmeans/reference/contrast.html).
Use it for any multi-level factor where the coefficient table – which
only reports each level versus the reference – leaves "which levels
differ from each other?" unanswered.

Each row is one contrast with a point estimate, standard error, 95%
confidence band, and an `excludes_zero` flag. **No p-values are
reported**: symbolizer shows compatibility bands, not tests. For
families on a log or logit link the response-scale contrast is a *ratio*
(or odds ratio), whose null value is 1, not 0 – the `effect_type` column
records which, and the `excludes_zero` flag is computed against the
correct null.

Not supported on bivariate Gaussian (`biv_gaussian`) fits – see
[`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
for the limitation and alternatives.

## Usage

``` r
group_contrasts(
  x,
  by = NULL,
  method = c("pairwise", "trt.vs.ctrl", "revpairwise", "consec", "poly"),
  within = NULL,
  scale = c("response", "link"),
  ci_method = NULL,
  adjust = c("none", "tukey", "mvt"),
  ...
)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
  whose underlying fit is retained on `x$metadata$fit`.

- by:

  Character vector of factor name(s) whose levels are contrasted.
  Defaults to all factors in the model.

- method:

  Contrast family, passed to
  [`emmeans::contrast()`](https://rvlenth.github.io/emmeans/reference/contrast.html):
  `"pairwise"` (all pairs, default), `"trt.vs.ctrl"` (each level versus
  the reference), `"revpairwise"`, `"consec"` (consecutive levels), or
  `"poly"`.

- within:

  Optional factor name(s) to compute the contrasts *within each level
  of* (emmeans `by`). Use this for the multi-factor case: pairwise
  contrasts of one factor separately at each level of another.

- scale:

  One of `"response"` (default) or `"link"`. On `"link"` the contrast is
  an additive difference on the linear-predictor scale; on `"response"`
  it is back-transformed (a ratio for log links, an odds ratio for logit
  links).

- ci_method:

  Confidence-interval method label; defaults to `x$metadata$ci_method`.
  See
  [`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md).

- adjust:

  Multiplicity adjustment for the confidence bands: `"none"` (default;
  one per-contrast interval), `"tukey"` (family-wise), or `"mvt"`. This
  only widens the interval – it never produces a p-value.

- ...:

  Reserved for future use.

## Value

A tibble (S3 class `symbolizer_group_contrasts`) with one row per
contrast. Columns: `contrast`, one column per `within` factor,
`level_combo`, `estimate`, `std_error`, `confint_low`, `confint_high`,
`excludes_zero`, `ci_method`, `scale`, `method`, `adjust`,
`effect_type`.

## See also

[`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md),
[`group_slopes()`](https://itchyshin.github.io/symbolizer/reference/group_slopes.md)

## Examples

``` r
d <- transform(mtcars, gear = factor(gear))
sym <- symbolize(lm(mpg ~ gear, data = d))
if (requireNamespace("emmeans", quietly = TRUE)) {
  # which gears differ from each other (not just from the reference)?
  group_contrasts(sym, by = "gear")
}
#> 
#> ── Group contrasts (pairwise) ──
#> 
#> gear3 - gear4 estimate = "-8.43" (-12.2, -4.70) *
#> gear3 - gear5 estimate = "-5.27" (-10.2, -0.301) *
#> gear4 - gear5 estimate = "3.15" (-1.97, 8.28)
#> Intervals are per-contrast, not family-wise; pass adjust = "tukey" for
#> simultaneous bands. Scale: response. CI method: wald. Adjustment: none. Rows
#> marked `*` have a 95% interval that excludes the null.
```
