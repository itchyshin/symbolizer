# Symbolize a drmTMB fit (Gaussian and bivariate Gaussian, v0.1)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from a `drmTMB` fit. v0.1 covers the Gaussian location-scale
fixed-effects path (with optional `(1 | group)` random intercepts on
`mu`) and the bivariate Gaussian
([`biv_gaussian()`](https://itchyshin.github.io/drmTMB/reference/biv_gaussian.html))
location-scale-correlation path. Other families and components return
capability errors via
[`capability_check()`](https://itchyshin.github.io/symbolizer/reference/capability_check.md).

## Usage

``` r
# S3 method for class 'drmTMB'
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
  [`drmTMB::confint`](https://itchyshin.github.io/drmTMB/reference/confint.drmTMB.html).
  One of `"wald"` (default, fast), `"profile"` (slower, more honest), or
  `"bootstrap"`.

- ...:

  Reserved for method-specific extra arguments.

## Value

A `symbolized_model` object.

## Confidence intervals

The returned `fixed_effects` and `interpretation` tibbles carry a
confidence band per coefficient: `confint_low`, `confint_high`,
`excludes_zero`, plus a `ci_method` column recording which method
produced them. The default `ci_method = "wald"` is fast and is what
`drmTMB::confint(fit, method = "wald")` returns by default. Wald
intervals can be too narrow when group counts are small (finite-df
situations). For more honest intervals, pass `ci_method = "profile"` —
slower but profile-likelihood-based. Satterthwaite / Kenward-Roger
corrections are not implemented; when Wald looks suspicious the
recommended alternative is `"profile"`.

## References

Nakagawa, S. (2024+). `drmTMB`: Distributional regression in TMB.
<https://itchyshin.github.io/drmTMB/>

Kristensen, K., Nielsen, A., Berg, C. W., Skaug, H., & Bell, B. M.
(2016). TMB: Automatic Differentiation and Laplace Approximation.
*Journal of Statistical Software*, 70(5), 1-21.
