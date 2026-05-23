# Assumption table for a symbolized model

Returns the structured assumption tibble of a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
as a reader-friendly table. The rows come straight from the
template-substituted `x$assumptions` field; the renderer never invents
prose.

## Usage

``` r
assumption_table(x, ...)
```

## Arguments

- x:

  A `symbolized_model`.

- ...:

  Reserved for future use.

## Value

A tibble (S3 class `symbolizer_assumption_table`) with columns `family`,
`submodel`, `assumption`, `expression_latex`, `biological_meaning`, and
`status`.
