
<!-- README.md is generated from README.Rmd. Please edit that file -->

# symbolizer

> **Equations are not enough.** `symbolizer` turns fitted models into
> equations, assumptions, interpretations, and teachable model stories.

## Positioning

`symbolizer` is the complement to
[`equatiomatic`](https://datalorax.github.io/equatiomatic/), not a
replacement. Reach for `equatiomatic` when you want a clean LaTeX
equation for one model. Reach for `symbolizer` when you need to
understand the model — its assumptions, what each coefficient means on a
natural scale, both notations side by side, and how your data actually
flows through the matrices.

| What you want | `equatiomatic` | `symbolizer` |
|----|----|----|
| The equation | `extract_eq(fit)` | `equations(symbolize(fit))` |
| Substituted coefficients | `extract_eq(fit, use_coefs = TRUE)` | `as_latex(sym)` |
| Multi-submodel models (μ + σ + RE) | partial | first-class |
| Stated and implied assumptions | — | `assumption_table(sym)` |
| Per-coefficient reading | — | `parameter_interpretation(sym)` |
| Index and matrix notation side by side | — | `equations(sym, notation = "both")`, `notation_bridge(sym)` |
| Three views with real data | — | `expand(sym)`, `as_html_three_views(sym)` |

Built first for the two TMB sister packages —
[`drmTMB`](https://itchyshin.github.io/drmTMB/) and
[`gllvmTMB`](https://itchyshin.github.io/gllvmTMB/) — and extended
across the GLMM ecosystem used in ecology and evolution: `glmmTMB`,
`brms`, `MCMCglmm`, `sdmTMB`, `lme4`, and base `lm`/`glm`.

## Install

`symbolizer` is pre-CRAN. Install the development build from GitHub with
`pak`:

``` r
install.packages("pak")
pak::pak("itchyshin/symbolizer")
```

## Tiny example

Fit a Gaussian location-scale model with `drmTMB`, then symbolize it
once:

``` r
library(symbolizer)
library(drmTMB)

set.seed(1)
n <- 200
temperature <- runif(n, 10, 25)
dat <- data.frame(
  body_mass   = rnorm(n, 30 + 0.4 * temperature, exp(0.5 + 0.1 * temperature)),
  temperature = temperature
)

fit <- drmTMB(
  drm_formula(body_mass ~ temperature, sigma ~ temperature),
  family = gaussian(),
  data   = dat
)

sym <- symbolize(
  fit,
  symbols = c(body_mass = "W_i", temperature = "T_i"),
  units   = c(body_mass = "g",   temperature = "C"),
  context = "avian body-size location-scale model"
)
```

### The equation, both notations

`as_latex(sym, notation = "both")` produces a single LaTeX block with
the index form above and the matrix form below. On GitHub and pkgdown,
it renders as:

$$
\begin{aligned}
W_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i & = \beta_{0} + \beta_{1} \, T_i \\
\log(\sigma_i) & = \gamma_{0} + \gamma_{1} \, T_i
\end{aligned}
$$

$$
\begin{aligned}
\mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} \\
\log(\boldsymbol{\sigma}) & = \mathbf{Z} \boldsymbol{\gamma}
\end{aligned}
$$

Bold lowercase letters are vectors ($\mathbf{w}$, $\boldsymbol{\beta}$);
bold uppercase letters are matrices ($\mathbf{X}$, $\mathbf{Z}$).

### The symbol dictionary

Each row tells you what a symbol is, its dimension (abstract and
concrete to this fit), and what it represents:

``` r
symbol_table(sym, notation = "both")
```

| index | matrix | variable | units | role | shape | concrete | description |
|:---|:---|:---|:---|:---|:---|:---|:---|
| $W_i$ | $\mathbf{w}$ | body_mass | g | response | $\mathbb{R}^n$ | $\mathbb{R}^{200}$ | response variable |
| $T_i$ | — | temperature | C | predictor | column of design matrix | column of X (length 200) | continuous predictor |
| $\mu_i$ | $\boldsymbol{\mu}$ | NA | NA | parameter | $\mathbb{R}^n$ | $\mathbb{R}^{200}$ | conditional mu of body_mass |
| $\sigma_i$ | $\boldsymbol{\sigma}$ | NA | NA | parameter | $\mathbb{R}^n$ | $\mathbb{R}^{200}$ | conditional sigma of body_mass |
| $\beta_{0}, \beta_{1}$ | $\boldsymbol{\beta}$ | NA | NA | coefficient | $\mathbb{R}^{p_\mu}$ | $\mathbb{R}^{2}$ | mu submodel coefficients |
| $\gamma_{0}, \gamma_{1}$ | $\boldsymbol{\gamma}$ | NA | NA | coefficient | $\mathbb{R}^{p_\sigma}$ | $\mathbb{R}^{2}$ | sigma submodel coefficients |
| — | $\mathbf{X}$ | NA | NA | design_matrix | $\mathbb{R}^{n \times p_\mu}$ | $\mathbb{R}^{200 \times 2}$ | mu submodel design matrix |
| — | $\mathbf{Z}$ | NA | NA | design_matrix | $\mathbb{R}^{n \times p_\sigma}$ | $\mathbb{R}^{200 \times 2}$ | sigma submodel design matrix |

### What is assumed

``` r
assumption_table(sym)
```

| assumption | expression | biological meaning | status |
|:---|:---|:---|:---|
| conditional_distribution | $W_i \mid \mu_i\, \sigma_i \sim \mathrm{Normal}(\mu_i\, \sigma_i^2)$ | body_mass varies normally around its expected value | stated |
| linear_predictor | $\mu_i = \beta_0 + \sum_k \beta_k X_{ki}$ | Expected body_mass is a linear combination of the mean-model predictors | stated |
| linear_predictor | $\log(\sigma_i) = \gamma_0 + \sum_k \gamma_k Z_{ki}$ | Log residual SD of body_mass is a linear combination of the scale-model predictors | stated |
| independence | $W_i \perp W_j \mid X \text{ for } i \ne j$ | Observations are conditionally independent given the predictors | implied |
| positivity | $\sigma_i > 0$ | Residual SD is constrained positive via the log link | implied |
| no_missing_at_random | — | Observations are assumed not missing in a way that depends on the unobserved response | not_checked |

### What each coefficient means

The biological reading on each coefficient, with the estimate from the
fit:

``` r
parameter_interpretation(sym, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | biological_reading |
|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 30.4 | Baseline body_mass in the reference condition |
| mu | temperature | slope | 0.371 | A unit change in temperature shifts the expected body_mass by 0.371 |
| sigma | (Intercept) | intercept | 0.799 | Baseline level of unexplained individual variation in body_mass |
| sigma | temperature | slope | 0.0825 | A unit change in temperature multiplies the unexplained variability of body_mass by exp(0.0825) |

### Three views of the same fit

For an interactive *Equation / Index / Matrix-with-data* widget — the
educator-facing surface that shows your actual numeric arrays flowing
through the model — see `vignette("symbolizer")` or the pkgdown article.
The widget is generated by:

``` r
as_html_three_views(sym)
```

## Status

Pre-release. Read status words consistently:

| Status word | Meaning for a user |
|----|----|
| Stable | Routine path with tests, diagnostics, and a reader-facing example. |
| First slice | Fitted and tested, but intentionally narrow. |
| Opt-in control | Available for hardening, not a general modelling guarantee. |
| Planned or reserved | Public grammar may exist, but `symbolize()` should reject it as design-only. |
| Unsupported | Do not use as analysis syntax; fit the nearest implemented model. |

### v0.1 capability matrix

| Surface | Status |
|----|----|
| `drmTMB` Gaussian location-scale, fixed effects (μ + σ submodels) | Stable |
| `drmTMB` Gaussian random intercepts `(1 \| group)` | First slice |
| `drmTMB` non-Gaussian families, ZI, hurdle, bivariate | Planned |
| `gllvmTMB`, `glmmTMB`, `brms`, `MCMCglmm`, `sdmTMB`, `lme4`, `lm`/`glm` | Unsupported in v0.1 (see roadmap) |
| `compare_symbolic()`, `model_card()`, `methods_text()`, model diagrams | Planned (v0.2 to v0.5) |

See `symbolizer_capabilities()` for the full registry.

## Roadmap

| Version | Theme |
|----|----|
| v0.1 | drmTMB symbolic specification with educational extras |
| v0.2 | Structural model comparison (`compare_symbolic`) |
| v0.3 | Teaching and writing layer (`model_card`, `methods_text`, warnings, family sheets) |
| v0.4 | `gllvmTMB` and `gllvmTMB_multi` |
| v0.5 | Diagrams and notebooks |
| v0.6 | `glmmTMB` |
| v0.7 | `brms` |
| v0.8 | `MCMCglmm` |
| v0.9 | `sdmTMB` |
| v0.10 | `lme4`, `lm`, `glm` |

## License

GPL-3. Companion to [`drmTMB`](https://itchyshin.github.io/drmTMB/) and
[`gllvmTMB`](https://itchyshin.github.io/gllvmTMB/).
