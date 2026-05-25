# Symbolize an lme4 glmer() fit (binomial / poisson, v0.11 first slice)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from a `glmerMod` object. v0.11 covers binomial / poisson families with
their canonical links, plus optional `(1 | g)` random intercepts.

## Usage

``` r
# S3 method for class 'glmerMod'
symbolize(
  fit,
  symbols = NULL,
  units = NULL,
  context = NULL,
  ci_method = "Wald",
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
  [`lme4::confint.merMod`](https://rdrr.io/pkg/lme4/man/confint.merMod.html).
  One of `"Wald"` (default, fast), `"profile"`, or `"boot"`.

- ...:

  Reserved for method-specific extra arguments.

## Value

A `symbolized_model` object.
