# Per-group marginal means for a symbolized model

`group_means()` returns categorical marginal means for the factors in a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md),
delegating to
[`emmeans::emmeans()`](https://rvlenth.github.io/emmeans/reference/emmeans.html)
under the hood. Each row is one combination of the requested factors'
levels with a point estimate, standard error, 95% confidence band, and
an `excludes_zero` indicator.

Use this alongside
[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
for any fit that contains a factor: the coefficient table shows
contrasts (differences from the reference level); `group_means()` shows
each group's expected response.

Not supported on bivariate Gaussian (`biv_gaussian`) fits — a marginal
mean in a bivariate fit is a joint 2-vector `(mu1, mu2)`, not a scalar,
so the emmeans abstraction does not apply. Use
[`drmTMB::predict_parameters()`](https://itchyshin.github.io/drmTMB/reference/predict_parameters.html)
on the fit directly, or refit each response as a univariate Gaussian and
call `group_means()` on each.

## Usage

``` r
group_means(x, by = NULL, scale = c("response", "link"), ci_method = NULL, ...)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
  whose underlying fit is retained on `x$metadata$fit`.

- by:

  Optional character vector of factor names to marginalize over.
  Defaults to all factors in the model.

- scale:

  One of `"response"` (default) or `"link"`. Controls the scale of the
  returned estimate and confidence band. For families with identity link
  on the mean (Gaussian, Student-t), the two are equivalent. For
  log-link families (Gamma, lognormal, Poisson, nbinom2) `"response"`
  reports back-transformed means; `"link"` reports the log-scale linear
  predictor. For the logit-link Beta family, `"response"` reports
  proportions and `"link"` reports log-odds.

- ci_method:

  Confidence-interval method. Defaults to the `ci_method` stored on
  `x$metadata$ci_method` so the band matches the symbolize() call.
  emmeans currently produces asymptotic Wald-style intervals regardless
  of this argument, but the column is propagated for consistency with
  [`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md).

- ...:

  Reserved for future use.

## Value

A tibble (S3 class `symbolizer_group_means`) with one row per level
combination. Columns: `level_combo`, one column per factor in `by`,
`estimate`, `std_error`, `confint_low`, `confint_high`, `excludes_zero`,
`ci_method`, `scale`.
