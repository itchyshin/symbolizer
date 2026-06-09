# Per-parameter interpretations for a symbolized model

Returns the per-coefficient reading tibble carried by a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
as a reader-friendly table. Each row corresponds to one fixed-effect
coefficient and pairs it with the prose readings already templated by
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md):
a link-scale reading, a natural-scale reading, an optional
variance-scale reading (for scale submodels), and a biological reading.

The renderer is a pure consumer of `x$interpretation`. All prose was
substituted from `inst/extdata/interpretation-templates.csv` at extract
time; this surface only displays it.

## Usage

``` r
parameter_interpretation(
  x,
  scale = c("all", "link", "natural", "variance", "biological"),
  ...
)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md).

- scale:

  One of `"all"` (default), `"link"`, `"natural"`, `"variance"`, or
  `"biological"`. `"all"` returns every reading column; the other values
  return just the identifier columns (`submodel`, `term_label`,
  `coefficient_role`, `estimate`) plus the matching single reading
  column.

- ...:

  Reserved for future use.

## Value

A tibble (S3 class `symbolizer_interpretation`) with `submodel`,
`term_label`, `coefficient_role`, `estimate`, and one or more reading
columns. The `"scale"` attribute records which scale was requested.

## Examples

``` r
# parameter_interpretation(symbolize(glm(am ~ wt, binomial(), data = mtcars)))
```
