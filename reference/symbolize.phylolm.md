# Symbolize a phylolm fit (Gaussian PGLS, v0.21.4 first slice)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from a `phylolm` object. v0.21.4 covers BM and Pagel's lambda
evolutionary models; OU / EB / kappa / delta / trend produce a
`symbolized_model` but carry the model name in `metadata$phylo_model`
for downstream diagnostics rather than full template support.

## Usage

``` r
# S3 method for class 'phylolm'
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

  Optional data frame. If `NULL`, falls back to `fit$model.frame`
  (phylolm stores it there).

- ...:

  Reserved for method-specific extra arguments.

## Value

A `symbolized_model` object.

## Details

phylolm fits the PGLS marginal form
`y = X*beta + e, e ~ N(0, sigma^2 * C(alpha))` where `C(alpha)` is a
tree-derived correlation matrix. There is no explicit `u_p`
random-effect — the phylogenetic signal lives entirely in the residual
covariance. `metadata$phylo_representation` is set to `"pgls_marginal"`
so downstream renderers can phrase this correctly.

## Confidence intervals

phylolm reports Wald-type standard errors via `vcov(fit)`. The
`confint_low` / `confint_high` columns of `fixed_effects` are computed
as `estimate +/- 1.96 * std_error`, and `ci_method` is set to `"wald"`.

## References

Ho, L.S.T. & Ané, C. (2014). A linear-time algorithm for Gaussian and
non-Gaussian trait evolution models. *Systematic Biology*, 63(3),
397-408.

Tung Ho, L.S. & Ané, C. (2014). Intrinsic inference difficulties for
trait evolution with Ornstein-Uhlenbeck models. *Methods in Ecology and
Evolution*, 5(11), 1133-1146.
