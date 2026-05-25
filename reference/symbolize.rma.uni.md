# Symbolize a metafor rma.uni fit (meta-analysis / meta-regression, v0.13 first slice)

Builds a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from an `rma.uni` fit. v0.13 covers random / mixed-effects meta-analysis
with optional moderators. The fitted object's `yi` and `vi` slots are
treated as known (sampling variances are not parameters), and the
between-study heterogeneity `tau^2` appears in the `variance_components`
tibble.

## Usage

``` r
# S3 method for class 'rma.uni'
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

## Location-scale (rma.ls)

When the fit was created with `rma(..., scale = ~ z)`,
`symbolize.rma.uni()` adds a second submodel `tau2` to the returned
object. metafor parameterises the scale model as
`log(tau^2_i) = alpha_0 + alpha_1 z_{1i} + ... + alpha_q z_{qi}` – log
of the **variance**, not the SD – with coefficient family `alpha`. This
contrasts with the SD parameterisation that brms, glmmTMB, and drmTMB
use for their distributional location-scale models
(`log(sigma_i) = gamma_0 + gamma_k z_ki`). The natural-scale reading on
a metafor scale slope is therefore "tau^2_i changes multiplicatively by
exp(alpha_k) per unit of z_k" – a change in the variance, not the SD.
The two scales are related by `alpha_k ~ 2 * gamma_k` (since
`log(tau^2) = 2 * log(tau) + const`).

## References

Viechtbauer, W., & López-López, J. A. (2022). Location-scale models for
meta-analysis. *Research Synthesis Methods*, 13(6), 697-715.

Nakagawa, S., Mizuno, A., Morrison, K., Ricolfi, L., Williams, C.,
Drobniak, S. M., Lagisz, M., & Yang, Y. (2025). Location-scale
meta-analysis and meta-regression as a tool to capture large-scale
changes in biological and methodological heterogeneity: A spotlight on
heteroscedasticity. *Global Change Biology*, 31, e70204.
