# Symbolize an mgcv gam / bam fit (additive grammar, v0.14 first slice)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from an [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) or
[`mgcv::bam()`](https://rdrr.io/pkg/mgcv/man/bam.html) fit. The first
slice covers gaussian / poisson / binomial / Gamma families with smooth
specifications `s(x)`, `s(x, by = factor)`, and `te(x, z)`.

## Usage

``` r
# S3 method for class 'gam'
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

## Details

For [`mgcv::gamm()`](https://rdrr.io/pkg/mgcv/man/gamm.html) or
[`gamm4::gamm4()`](https://rdrr.io/pkg/gamm4/man/gamm4.html), both
return a list with a `$gam` component of class `"gam"`. Pass that
component to
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md):

    g <- mgcv::gamm(y ~ s(x), random = list(g = ~1), data = d)
    sym <- symbolize(g$gam)

Correlation structures and lme4-style random effects from `gamm` /
`gamm4` are reflected via the `$gam` object's smooth and
parametric-coefficient blocks; the GAMM-specific covariance structures
are not separately rendered in v0.14.
