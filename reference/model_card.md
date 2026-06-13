# One-call teaching bundle for a symbolized model

`model_card()` is the entry point for **acting on** a fit. It returns
everything
[`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md)
shows – equation, symbol dictionary, assumptions, notation and formula
bridges, per-coefficient interpretations, factor-coding overview,
variance components – and adds the act-on-it layer: extraction calls (R
code to pull out blocks of the fit), recommended plots (one-line text
recipes), and the marginal estimates
([`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
/
[`group_slopes()`](https://itchyshin.github.io/symbolizer/reference/group_slopes.md)
/
[`group_contrasts()`](https://itchyshin.github.io/symbolizer/reference/group_contrasts.md)).

Use
[`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md)
when you only want to *understand* the model; use `model_card()` when
you also want a quick reference of *what to extract, what to plot, and
how the groups compare*.

The bundle is a plain list; print it at the console for a structured
walkthrough, or knit it inside a Quarto / R Markdown document for a
heading-and-table section per piece.

## Usage

``` r
model_card(x, ...)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
  (output of
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)).

- ...:

  Reserved for future use.

## Value

A `symbolizer_model_card` (a list) with elements: `meta`, `equation`,
`symbols`, `assumptions`, `notation_bridge` (and its deprecated alias
`bridge`), `formula_bridge`, `interpretation`, `factor_coding`,
`variance_components` (NULL when the model has no random effects),
`warnings`, `extraction_calls`, `recommended_plots`, `marginal_means`
(NULL when the model has no factors), `marginal_slopes` (NULL when no
continuous-by-\* interaction is present), and `marginal_contrasts` (NULL
when the model has no factor).

## See also

[`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md)
for the understand-only bundle.

## Examples

``` r
# model_card(symbolize(lm(mpg ~ wt, data = mtcars)))
```
