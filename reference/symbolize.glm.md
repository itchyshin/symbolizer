# Symbolize a base R glm() fit (Gaussian / binomial / poisson, v0.10 first slice)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from a base R `glm` object. v0.10 covers Gaussian / binomial / poisson
with their canonical links (identity / logit / log). Quasi-families,
offsets, and family-specific weights are deferred via the capability
registry.

## Usage

``` r
# S3 method for class 'glm'
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
