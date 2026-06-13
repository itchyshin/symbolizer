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
