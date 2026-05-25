# Symbolize a metafor rma.mv fit (multilevel / multivariate meta-analysis, v0.13.1)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from an `rma.mv` fit. Covers the multi-tier random-effects structure
(`random = list(~ 1 | study, ~ 1 | id)` or nested
`~ 1 | district / study`), optional R-matrix structured random effects
(e.g., phylogenetic via `R = list(phylo = phylo.cor)`), and
meta-regression moderators.

## Usage

``` r
# S3 method for class 'rma.mv'
symbolize(fit, symbols = NULL, units = NULL, context = NULL, ...)
```

## Arguments

- fit:

  A fitted statistical model object.

- symbols:

  Optional named character vector mapping variable names to
  user-supplied LaTeX symbols, e.g.
  `c(body_mass = "W_i", temperature = "T_i")`.

- units:

  Optional named character vector mapping variable names to units, e.g.
  `c(body_mass = "g", temperature = "C")`.

- context:

  Optional short character description of the model, e.g.
  `"avian body-size location-scale model"`.

- ...:

  Reserved for method-specific extra arguments.

## Value

A `symbolized_model` object.

## Details

Each random-effect tier gets a row in `variance_components` with
`kind = "heterogeneity"` (unstructured) or `kind = "structured"` (when
an R-matrix is attached). Tiers with an R-matrix render as
`u_r ~ N(0, sigma^2_r * R_r)` in the LaTeX; structured tiers also appear
in `sym$metadata$structured_random` with their matrix dimension.
