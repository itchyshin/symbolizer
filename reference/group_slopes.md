# Per-group slopes for a continuous predictor

`group_slopes()` returns the slope of a continuous predictor stratified
by one or more factors (or by values of another continuous predictor),
delegating to
[`emmeans::emtrends()`](https://rvlenth.github.io/emmeans/reference/emtrends.html).
Each row is one stratum with a point estimate, standard error, 95%
confidence band, and an `excludes_zero` indicator.

Use this alongside
[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
for any fit with a continuous-by-categorical interaction (or
continuous-by-continuous): the coefficient table reports contrast slopes
(differences from the reference group's slope); `group_slopes()` reports
each group's slope directly.

Not supported on bivariate Gaussian (`biv_gaussian`) fits — see
[`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
for the same limitation and the recommended alternatives.

## Usage

``` r
group_slopes(
  x,
  continuous,
  at = NULL,
  scale = c("response", "link"),
  ci_method = NULL,
  ...
)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
  whose underlying fit is retained on `x$metadata$fit`.

- continuous:

  Name of the continuous predictor whose slope is wanted.

- at:

  How to stratify. Three accepted shapes:

  - `NULL` (default): use every factor in the model that interacts with
    `continuous` (determined from `x$terms`).

  - A character vector of factor names: stratify by those factors'
    levels.

  - A named list (e.g. `list(z = c(-1, 0, 1))`): for continuous-by-
    continuous interactions, get the slope at those values of `z`.

- scale:

  One of `"response"` (default) or `"link"`. For identity-link families
  the two are equivalent. For other families the slope is reported on
  the requested scale: `"link"` gives the linear-predictor slope (which
  is what the coefficient table shows), `"response"` gives the slope
  after back-transformation. Note that for non-identity links the
  response-scale slope depends on the level of the predictor.

- ci_method:

  Confidence-interval method. Defaults to `x$metadata$ci_method`. See
  [`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
  for details.

- ...:

  Reserved for future use.

## Value

A tibble (S3 class `symbolizer_group_slopes`) with one row per stratum.
Columns: `predictor`, `level_combo`, one column per stratifying
variable, `estimate`, `std_error`, `confint_low`, `confint_high`,
`excludes_zero`, `ci_method`, `scale`.

## See also

Other marginal estimates:
[`group_contrasts()`](https://itchyshin.github.io/symbolizer/reference/group_contrasts.md),
[`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
