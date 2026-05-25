# Symbolize a brms fit (Gaussian, v0.8 first slice)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from a `brmsfit` object. v0.8 covers the Gaussian conditional submodel
(identity link) with optional `(1 | g)` random intercepts. Other
families and brms's distributional-parameter formulas (`sigma ~ z`,
etc.) return capability errors via
[`capability_check()`](https://itchyshin.github.io/symbolizer/reference/capability_check.md).

## Usage

``` r
# S3 method for class 'brmsfit'
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

## Credible intervals

brms is Bayesian, so the "confidence band" carried in `fixed_effects`
and `interpretation` is a 95% **credible interval** – the 2.5% and 97.5%
posterior quantiles. `excludes_zero` is the indicator for whether the
credible interval excludes zero (i.e. the posterior puts negligible mass
on either side of zero). `ci_method` is set to `"credible"` so renderers
can label the band correctly.
