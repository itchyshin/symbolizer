# Symbolize a metafor rma.uni fit (meta-analysis / meta-regression, v0.13 first slice)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from an `rma.uni` fit. v0.13 covers random / mixed-effects meta-analysis
with optional moderators. The fitted object's `yi` and `vi` slots are
treated as known (sampling variances are not parameters), and the
between-study heterogeneity `tau^2` appears in the `variance_components`
tibble.

## Usage

``` r
# S3 method for class 'rma.uni'
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
