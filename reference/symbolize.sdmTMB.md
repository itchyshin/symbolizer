# Symbolize an sdmTMB fit (Gaussian, v0.12 first slice)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from an `sdmTMB` fit. v0.12 first slice covers Gaussian models with
optional spatial random field (`spatial = "on"`) and / or spatiotemporal
random field via the `time` argument. Non-Gaussian families, delta
models, and `spatial_varying` slopes are routed through the capability
registry.

## Usage

``` r
# S3 method for class 'sdmTMB'
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

Fixed-effect CIs come from `sdmTMB::tidy(fit)` (Wald, 95% by default).
Random-parameter CIs (range, spatial SD, spatiotemporal SD) come from
`sdmTMB::tidy(fit, "ran_pars")` and appear in `variance_components`.

## References

Anderson, S. C., Ward, E. J., English, P. A., & Barnett, L. A. K.
(2022). sdmTMB: an R package for fast, flexible, and user-friendly
generalized linear mixed effects models with spatial and spatiotemporal
random fields. *bioRxiv*.
[doi:10.1101/2022.03.24.485545](https://doi.org/10.1101/2022.03.24.485545)
