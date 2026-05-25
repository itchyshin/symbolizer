# Symbolize a base R lm() fit (Gaussian, v0.10 first slice)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from a base R `lm` object. v0.10 covers the Gaussian conditional
submodel only (the only family [`lm()`](https://rdrr.io/r/stats/lm.html)
fits). The residual standard deviation (`summary(fit)$sigma`) is exposed
as the `sigma` variance component but is not modelled –
[`lm()`](https://rdrr.io/r/stats/lm.html) doesn't support distributional
regression on sigma.

## Usage

``` r
# S3 method for class 'lm'
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

## Confidence intervals

CIs come from `stats::confint(fit)`. The method is "Wald-t" – the usual
frequentist t-based CI you'd see in `summary(fit)`. `ci_method` is set
to `"wald"` for consistency with the other frequentist extractors.
