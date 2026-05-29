# One-call teaching bundle for a symbolized model

`model_card()` returns the entire teachable package for a symbolized
model in a single S3 object: equation, symbol dictionary, assumptions,
notation bridge, formula bridge, per-coefficient interpretations,
extraction calls (R code to pull out blocks of the fit), and recommended
plots (one-line text recipes).

Use
[`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md)
when you want the first-time-user walkthrough of the symbols and
equations. Use `model_card()` when you also want a quick reference of
*what to extract from the fit and what to plot next*.

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
`symbols`, `assumptions`, `bridge`, `formula_bridge`, `interpretation`,
`variance_components` (NULL when the model has no random effects),
`warnings`, `extraction_calls`, `recommended_plots`, `marginal_means`
(NULL when the model has no factors), `marginal_slopes` (NULL when no
continuous-by-\* interaction is present).
