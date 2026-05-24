# Symbolize a glmmTMB fit (Gaussian, v0.7 first slice)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from a `glmmTMB` fit. v0.7 covers the Gaussian conditional submodel
(identity link) with optional `(1 | g)` random intercepts and an
optional distributional dispformula. Other families and zero-inflation
submodels return capability errors via
[`capability_check()`](https://itchyshin.github.io/symbolizer/reference/capability_check.md).

## Usage

``` r
# S3 method for class 'glmmTMB'
symbolize(
  fit,
  symbols = NULL,
  units = NULL,
  context = NULL,
  ci_method = "wald",
  ...
)
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

- ci_method:

  Confidence-interval method passed to
  [`glmmTMB::confint.glmmTMB`](https://rdrr.io/pkg/glmmTMB/man/confint.glmmTMB.html).
  One of `"wald"` (default, fast), `"profile"`, or `"uniroot"`.

- ...:

  Reserved for method-specific extra arguments.

## Value

A `symbolized_model` object.

## Confidence intervals

The returned `fixed_effects` and `interpretation` tibbles carry a
confidence band per coefficient: `confint_low`, `confint_high`,
`excludes_zero`, plus a `ci_method` column. The default
`ci_method = "wald"` is fast and matches
`confint(fit, method = "wald")`. `"profile"` and `"uniroot"` are
available for slower, more honest bands.
