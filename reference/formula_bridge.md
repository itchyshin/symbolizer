# Formula bridge table for a symbolized model

Returns the R-syntax-to-mathematics translation table built by
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md).
Each row corresponds to one submodel formula (e.g., `mu ~ ...`,
`sigma ~ ...`) and pairs the literal R syntax with a one-line
statistical meaning and the matching mathematics in either index or
matrix form (or both).

## Usage

``` r
formula_bridge(x, notation = c("both", "index", "matrix"), ...)
```

## Arguments

- x:

  A `symbolized_model`.

- notation:

  One of `"both"` (default), `"index"`, or `"matrix"`. Controls which
  mathematics column(s) are returned.

- ...:

  Reserved for future use.

## Value

A tibble (S3 class `symbolizer_formula_bridge`) with columns `submodel`,
`r_syntax`, `statistical_meaning`, and one or both of `mathematics`
(index form) and `mathematics_matrix` (matrix form).
