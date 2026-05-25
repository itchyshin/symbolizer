# Symbolize an lme4 lmer() fit (Gaussian, v0.10 first slice)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from an `lmerMod` object. v0.10 covers the Gaussian conditional submodel
with optional `(1 | g)` random intercepts. Generalised mixed models
(glmer / glmerMod) are routed through `symbolize.glmerMod`.

## Usage

``` r
# S3 method for class 'lmerMod'
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

## Confidence intervals

CIs come from `lme4::confint(fit, parm = "beta_", method = ci_method)`.
Default `ci_method = "Wald"`. Profile-likelihood CIs (`"profile"`) are
slower but more honest for fits with small group counts. `ci_method` is
stored on metadata as lowercase `"wald"` / `"profile"`.

## References

Bates, D., Maechler, M., Bolker, B., & Walker, S. (2015). Fitting Linear
Mixed-Effects Models Using lme4. *Journal of Statistical Software*,
67(1), 1-48.
