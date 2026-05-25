# Symbolize a gllvmTMB fit (Gaussian and binomial latent-variable models)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from a `gllvmTMB` fit. Covers the Gaussian and binomial B-tier
latent-variable families: per-trait intercepts (`0 + trait`), the
between-unit reduced-rank loading term
(`latent(0 + trait | unit, d = K)`), and the optional per-trait unique
variances (`unique(0 + trait | unit)`). Other families and covstructs
return capability errors via
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

## Confidence intervals

Fixed-effect estimates and Wald-style approximate CIs are pulled from
`summary(fit$sd_report, "fixed")`. Loadings (`\boldsymbol{\Lambda}_B`)
and the between-unit covariance (`\boldsymbol{\Sigma}_B`) are point
estimates; parametric-bootstrap uncertainty via
[`gllvmTMB::bootstrap_Sigma()`](https://itchyshin.github.io/gllvmTMB/reference/bootstrap_Sigma.html)
is on the deferred list.

## References

Nakagawa, S. (forthcoming). `gllvmTMB`: Generalized linear
latent-variable models in TMB. <https://itchyshin.github.io/gllvmTMB/>
