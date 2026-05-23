# Symbol dictionary as a reader-friendly table

Returns the symbol dictionary of a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
as a tibble suitable for tabular display. The dictionary lists every
mathematical symbol that appears in the rendered equations (response,
predictors, parameters, coefficients, and design matrices), together
with the original R variable, its units, and an abstract / concrete
dimension.

The renderer is a pure consumer of `x$symbol_dictionary`: it does not
parse formulas or invent prose. Use `notation` to control which symbol
column(s) are shown.

## Usage

``` r
symbol_table(x, notation = c("both", "index", "matrix"), ...)
```

## Arguments

- x:

  A `symbolized_model`.

- notation:

  One of `"both"` (default), `"index"`, or `"matrix"`. `"index"` keeps
  only the element-wise (`W_i`, `\mu_i`) form, `"matrix"` keeps only the
  bold matrix-form (`\mathbf{w}`, `\boldsymbol{\mu}`) and drops rows
  that have no matrix form (e.g., continuous predictors whose only
  symbol is an indexed scalar).

- ...:

  Reserved for future use.

## Value

A tibble (S3 class `symbolizer_symbol_table`) with `variable`, `units`,
`role`, `dimension`, `dimension_concrete`, and `description` columns
plus one or both of `symbol` and `symbol_matrix`.
