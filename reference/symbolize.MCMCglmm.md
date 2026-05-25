# Symbolize an MCMCglmm fit (Gaussian, v0.9 first slice)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from an `MCMCglmm` fit. v0.9 covers the Gaussian conditional submodel
(identity link) with optional `~ g` random intercepts. Other families
and MCMCglmm's flexible covariance structures return capability errors
via
[`capability_check()`](https://itchyshin.github.io/symbolizer/reference/capability_check.md).

## Usage

``` r
# S3 method for class 'MCMCglmm'
symbolize(fit, symbols = NULL, units = NULL, context = NULL, data = NULL, ...)
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

- data:

  The data frame used to fit. Required: MCMCglmm does not keep the data
  on the fitted object.

- ...:

  Reserved for method-specific extra arguments.

## Value

A `symbolized_model` object.

## Details

MCMCglmm does NOT keep the data frame on the fitted object, so `data` is
a mandatory argument here.

## Credible intervals

MCMCglmm is Bayesian. The CI band in `fixed_effects` and
`interpretation` is a 95% **credible interval** (`l-95% CI` / `u-95% CI`
from `summary(fit)$solutions`). `ci_method` is set to `"credible"`.
