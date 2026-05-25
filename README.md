
<!-- README.md is generated from README.Rmd. Please edit that file -->

# symbolizer <img src="man/figures/logo.png" align="right" height="139" alt="symbolizer hex logo: an R to script-L arrow above a small scatter plot pointing at y ~ beta x + epsilon" />

<!-- badges: start -->

[![R-CMD-check](https://github.com/itchyshin/symbolizer/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/itchyshin/symbolizer/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/itchyshin/symbolizer/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/itchyshin/symbolizer/actions/workflows/pkgdown.yaml)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

> **Equations are not enough.** `symbolizer` turns fitted models into
> equations, assumptions, interpretations, and teachable model stories.

## Positioning

> `symbolizer` makes a fitted model **auditable**. It connects the R
> formula, the symbolic model in both notations, every parameter’s
> scale, the assumptions that are stated vs. implied vs. unchecked, what
> each coefficient means biologically, and the next diagnostic steps —
> across the GLMM, meta-analysis, additive-model, and
> Bayesian-multilevel packages an ecologist or evolutionary biologist
> actually uses.

`symbolizer` is the complement to
[`equatiomatic`](https://datalorax.github.io/equatiomatic/), not a
replacement. Reach for `equatiomatic` when you want a clean LaTeX
equation for one `lm()` or `lmer()` model. Reach for `symbolizer` when
you need to understand the model — across multi-submodel distributional
fits, mixed models, latent-variable, spatial, meta-analytic, or additive
structures — its assumptions, what each coefficient means on a natural
scale, both notations side by side, and how your data actually flows
through the matrices.

| What you want | `equatiomatic` | `symbolizer` |
|----|----|----|
| The equation | `extract_eq(fit)` | `equations(symbolize(fit))` |
| Substituted coefficients | `extract_eq(fit, use_coefs = TRUE)` | `as_latex(sym)` |
| Multi-submodel models (μ + σ + RE) | partial | first-class |
| Stated and implied assumptions | — | `assumption_table(sym)` |
| Per-coefficient reading | — | `parameter_interpretation(sym)` |
| Index and matrix notation side by side | — | `equations(sym, notation = "both")`, `notation_bridge(sym)` |
| Three views with real data | — | `expand(sym)`, `as_html_three_views(sym)` |

**Currently reads ten package families** (14 fitted-class methods, 30+
family-class combinations): the two TMB sister packages
[`drmTMB`](https://itchyshin.github.io/drmTMB/) and
[`gllvmTMB`](https://itchyshin.github.io/gllvmTMB/), the broader GLMM
ecosystem `glmmTMB`, `brms`, `lme4` (`lmer` + `glmer`), `MCMCglmm`
(including animal models), `sdmTMB` (spatial + spatiotemporal random
fields), `stats::lm` / `stats::glm`, the meta-analytic framework
`metafor` (`rma.uni` + `rma.mv` with multilevel / structured /
location-scale variants), and additive models via `mgcv::gam` /
`mgcv::bam` (with `gamm` / `gamm4` covered through the `$gam` slot). See
the [Roadmap article](articles/symbolizer-roadmap.html) for the full
capability matrix; `symbolizer_capabilities()` is the in-package source
of truth, and any class / family / component not marked Stable or First
slice there will be refused by `symbolize()`.

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
| conditional_distribution | $W_i \mid \mu_i\, \sigma_i \sim \mathrm{Normal}(\mu_i\, \sigma_i^2)$ | body_mass varies normally around its expected value | explicit |
| linear_predictor | $\mu_i = \beta_0 + \sum_k \beta_k X_{ki}$ | Expected body_mass is a linear combination of the mean-model predictors | explicit |
| linear_predictor | $\log(\sigma_i) = \gamma_0 + \sum_k \gamma_k Z_{ki}$ | Log residual SD of body_mass is a linear combination of the scale-model predictors | explicit |
| independence | $W_i \perp W_j \mid X \text{ for } i \ne j$ | Observations are conditionally independent given the predictors | follows from the formula |
| positivity | $\sigma_i > 0$ | Residual SD is constrained positive via the log link | follows from the formula |
| no_missing_at_random | — | Observations are assumed not missing in a way that depends on the unobserved response | your responsibility |

### What each coefficient means

The biological reading on each coefficient, with the estimate from the
fit:

``` r
parameter_interpretation(sym, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | 95% CI | biological_reading |
|:---|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 30.4 | 25.3, 35.6 \* | Baseline body_mass in the reference condition |
| mu | temperature | slope | 0.371 | 0.0427, 0.699 \* | A unit change in temperature shifts the expected body_mass by 0.371 |
| sigma | (Intercept) | intercept | 0.799 | 0.361, 1.24 \* | Baseline level of unexplained individual variation in body_mass |
| sigma | temperature | slope | 0.0825 | 0.0584, 0.106 \* | A unit change in temperature multiplies the unexplained variability of body_mass by exp(0.0825) |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

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

### At a glance

`symbolize()` reads **10 package families / 14 fitted-class methods /
~30 family-class combinations** today: `drmTMB`, `gllvmTMB`, `glmmTMB`,
`brms`, `lme4` (`lmer` + `glmer`), `MCMCglmm` (including animal models
via `ginverse`), `sdmTMB` (spatial + spatiotemporal fields), `stats::lm`
/ `stats::glm`, `metafor` (`rma.uni` + `rma.mv` with multilevel /
structured / phylogenetic random effects), and `mgcv::gam` / `mgcv::bam`
(additive smooths; `gamm` / `gamm4` via `$gam`).

For the full **capability matrix, release history, status vocabulary,
and what’s planned next**, see [the Roadmap
article](articles/symbolizer-roadmap.html). The capability registry
(`symbolizer_capabilities()`) is the source of truth — any class /
family / component not marked Stable or First slice there will be
refused by `symbolize()`.

## How symbolizer fits with related packages

`symbolizer` fills the *structural and educational* slot of the R
modelling stack: what the model is, what it assumes, what each
coefficient means before you read its number. Other packages fill the
*summarisation*, *standardisation*, *prediction*, and *auto-narration*
slots. None of these is competing — most ecology and evolution papers
use two or three of them together.

| Package | Job to be done | Output |
|----|----|----|
| **symbolizer** | Structured symbolic model: equation, symbols, assumptions, interpretation, compare two fits | `symbolized_model` object; equations, tables, HTML widget, `symbolic_comparison` |
| `equatiomatic` | Render a fitted model as a LaTeX equation | LaTeX string |
| `gtsummary` | Publication-ready regression table | `gt` / `flextable` / `kable` table |
| `modelsummary` | Regression and model-comparison tables, many formats | Word / LaTeX / Markdown table |
| `parameters` (easystats) | Tidy tibble of parameter estimates across many classes | Tidy tibble |
| `marginaleffects` | Predictions, contrasts, slopes, marginal effects | Tibble + plots |
| `report` (easystats) | Auto-generated prose paragraph describing a fit | Prose paragraph |

A typical stack for a Gaussian location-scale fit:

1.  **`symbolizer`** for the equation in the Methods section — both
    notations spliced via `as_latex(sym, notation = "both")` — plus the
    assumption table and per-coefficient biological reading.
2.  **`gtsummary`** or **`modelsummary`** for the coefficient table in
    the Results.
3.  **`marginaleffects`** for the prediction figure and any
    marginal-effect contrasts.

If you also want a quick draft paragraph for the Results, drop in
**`report`** before you edit. If your downstream code wants tibbles of
estimates regardless of model class, **`parameters`** harmonises that
layer.

The point: **pick by the job, not by the package**. For most papers, the
right answer is two or three of them used together. The `symbolizer`
slot is the one labelled *“what the model is and what it assumes”* — and
that’s the slot the others don’t fill.

## License

GPL-3. Companion to [`drmTMB`](https://itchyshin.github.io/drmTMB/) and
[`gllvmTMB`](https://itchyshin.github.io/gllvmTMB/).
