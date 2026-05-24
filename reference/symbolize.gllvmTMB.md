# Symbolize a gllvmTMB fit (Gaussian latent-variable, v0.1)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from a `gllvmTMB` fit. v0.1 covers the Gaussian B-tier latent-variable
First slice: per-trait intercepts (`0 + trait`), the between-unit
reduced-rank loading term (`latent(0 + trait | unit, d = K)`), and the
optional per-trait unique variances (`unique(0 + trait | unit)`). Other
families and covstructs return capability errors via
[`capability_check()`](https://itchyshin.github.io/symbolizer/reference/capability_check.md).

## Usage

``` r
# S3 method for class 'gllvmTMB'
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
