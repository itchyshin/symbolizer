# Explain a model's factors and dummy coding in one call

`explain_factors()` is the recommended entry point for understanding the
categorical predictors in a fit. For every factor it states, in plain
language, the coding scheme (its levels, which level is the reference,
and how many indicator columns it contributes), then shows the per-group
means
([`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md))
and the pairwise comparisons
([`group_contrasts()`](https://itchyshin.github.io/symbolizer/reference/group_contrasts.md)).
For every interaction it gives the difference-of-differences reading
together with the inline cell means or per-group slopes.

Pass a fitted model (it is run through
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
for you) or an existing
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md).

Print the result at the console for a walkthrough, or knit it inside a
Quarto / R Markdown document for a heading-and-table section per factor.

## Usage

``` r
explain_factors(x, ...)
```

## Arguments

- x:

  A fitted model supported by
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md),
  or a
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md).

- ...:

  Passed to
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  when `x` is a fit.

## Value

A `symbolized_factor_explanation` object.

## See also

[`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md),
[`group_contrasts()`](https://itchyshin.github.io/symbolizer/reference/group_contrasts.md),
[`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md)

## Examples

``` r
d <- transform(mtcars, gear = factor(gear))
if (requireNamespace("emmeans", quietly = TRUE)) {
  # one call: coding scheme, group means, and pairwise contrasts per factor
  explain_factors(lm(mpg ~ gear, data = d))
}
#> 
#> ── Factors in your <lm> model ──────────────────────────────────────────────────
#> 
#> ── gear ──
#> 
#> `gear` has 3 levels (3, 4, 5). R uses 3 as the baseline and adds 2 indicator
#> column(s); each coefficient is the difference from 3, not that group's own
#> mean.
#> 
#> 
#> ── Group means ──
#> 
#> gear=3 estimate = "16.1" (13.6, 18.6) *
#> gear=4 estimate = "24.5" (21.8, 27.3) *
#> gear=5 estimate = "21.4" (17.1, 25.7) *
#> Scale: response. CI method: wald. Rows marked `*` have a 95% interval that
#> excludes zero.
#> 
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
