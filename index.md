# symbolizer

> **Equations are not enough.** `symbolizer` turns fitted models into
> equations, assumptions, interpretations, and teachable model stories.

## Positioning

> `symbolizer` does not just print equations for `drmTMB`; it makes a
> fitted distributional model auditable by connecting the R formula,
> symbolic model, parameter scales, assumptions, coefficient readings,
> and next diagnostic steps.

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
[`drmTMB`](https://itchyshin.github.io/drmTMB/) (Stable: Gaussian
location-scale + (1 \| group); First slice today) and
[`gllvmTMB`](https://itchyshin.github.io/gllvmTMB/) (First slice:
Gaussian latent-variable models) — with planned extensions across the
GLMM ecosystem used in ecology and evolution: `glmmTMB`, `brms`,
`MCMCglmm`, `sdmTMB`, `lme4`, and base `lm`/`glm`. The capability
registry
([`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md))
is the source of truth for what’s readable today; any fitted-model class
not listed there with a Stable or First slice status will be refused by
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md).

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

``` math
\begin{aligned}
W_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i & = \beta_{0} + \beta_{1} \, T_i \\
\log(\sigma_i) & = \gamma_{0} + \gamma_{1} \, T_i
\end{aligned}
```

``` math
\begin{aligned}
\mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} \\
\log(\boldsymbol{\sigma}) & = \mathbf{Z} \boldsymbol{\gamma}
\end{aligned}
```

Bold lowercase letters are vectors ($`\mathbf{w}`$,
$`\boldsymbol{\beta}`$); bold uppercase letters are matrices
($`\mathbf{X}`$, $`\mathbf{Z}`$).

### The symbol dictionary

Each row tells you what a symbol is, its dimension (abstract and
concrete to this fit), and what it represents:

``` r

symbol_table(sym, notation = "both")
```

| index | matrix | variable | units | role | shape | concrete | description |
|:---|:---|:---|:---|:---|:---|:---|:---|
| $`W_i`$ | $`\mathbf{w}`$ | body_mass | g | response | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ | response variable |
| $`T_i`$ | — | temperature | C | predictor | column of design matrix | column of X (length 200) | continuous predictor |
| $`\mu_i`$ | $`\boldsymbol{\mu}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ | conditional mu of body_mass |
| $`\sigma_i`$ | $`\boldsymbol{\sigma}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ | conditional sigma of body_mass |
| $`\beta_{0}, \beta_{1}`$ | $`\boldsymbol{\beta}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\mu}`$ | $`\mathbb{R}^{2}`$ | mu submodel coefficients |
| $`\gamma_{0}, \gamma_{1}`$ | $`\boldsymbol{\gamma}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\sigma}`$ | $`\mathbb{R}^{2}`$ | sigma submodel coefficients |
| — | $`\mathbf{X}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\mu}`$ | $`\mathbb{R}^{200 \times 2}`$ | mu submodel design matrix |
| — | $`\mathbf{Z}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\sigma}`$ | $`\mathbb{R}^{200 \times 2}`$ | sigma submodel design matrix |

### What is assumed

``` r

assumption_table(sym)
```

| assumption | expression | biological meaning | status |
|:---|:---|:---|:---|
| conditional_distribution | $`W_i \mid \mu_i\, \sigma_i \sim \mathrm{Normal}(\mu_i\, \sigma_i^2)`$ | body_mass varies normally around its expected value | explicit |
| linear_predictor | $`\mu_i = \beta_0 + \sum_k \beta_k X_{ki}`$ | Expected body_mass is a linear combination of the mean-model predictors | explicit |
| linear_predictor | $`\log(\sigma_i) = \gamma_0 + \sum_k \gamma_k Z_{ki}`$ | Log residual SD of body_mass is a linear combination of the scale-model predictors | explicit |
| independence | $`W_i \perp W_j \mid X \text{ for } i \ne j`$ | Observations are conditionally independent given the predictors | follows from the formula |
| positivity | $`\sigma_i > 0`$ | Residual SD is constrained positive via the log link | follows from the formula |
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
through the model — see
[`vignette("symbolizer")`](https://itchyshin.github.io/symbolizer/articles/symbolizer.md)
or the pkgdown article. The widget is generated by:

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
| Planned or reserved | Public grammar may exist, but [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md) should reject it as design-only. |
| Unsupported | Do not use as analysis syntax; fit the nearest implemented model. |

### Capability matrix (v0.1 – v0.14)

| Surface | Status |
|----|----|
| `drmTMB` Gaussian location-scale, fixed effects (μ + σ submodels) | Stable |
| `drmTMB` Gaussian random intercepts `(1 \| group)` and random slopes `(1 + x \| group)` on μ | First slice (v0.3.1) |
| `drmTMB` bivariate Gaussian (`mu1`, `mu2`, `sigma1`, `sigma2`, `rho12`) | First slice (v0.2) |
| `drmTMB` Student-t, lognormal, Gamma, beta, beta_binomial, Poisson, nbinom2, truncated_nbinom2 | First slice (v0.3) |
| `drmTMB` zero-inflation (`zi`), hurdle (`hu`), cumulative_logit | First slice (v0.4) |
| `gllvmTMB` Gaussian and binomial latent-variable families | First slice (v0.4 – v0.5) |
| `glmmTMB` Gaussian / binomial / poisson / nbinom2 conditional submodel + `dispformula` + `ziformula` + `(1 \| g)` | First slice (v0.7 – v0.11) |
| [`lme4::lmer`](https://rdrr.io/pkg/lme4/man/lmer.html) + [`lme4::glmer`](https://rdrr.io/pkg/lme4/man/glmer.html) (binomial / poisson) | First slice (v0.10 – v0.11) |
| `brmsfit` Gaussian / binomial / poisson + `bf(sigma ~ z)` distributional | First slice (v0.8 – v0.11) |
| `MCMCglmm` Gaussian + `~ g` random intercepts + animal models via `ginverse` | First slice (v0.9 – v0.12) |
| [`stats::lm`](https://rdrr.io/r/stats/lm.html), [`stats::glm`](https://rdrr.io/r/stats/glm.html) (gaussian / binomial / poisson / Gamma) | First slice (v0.10 – v0.11) |
| **`sdmTMB`** Gaussian + spatial random field (`omega`) + spatiotemporal field (`epsilon`) | First slice (v0.12) |
| **[`metafor::rma.uni`](https://wviechtb.github.io/metafor/reference/rma.uni.html)** random / mixed-effects meta-analysis + meta-regression (two-tier `y_i | theta_i ~ N(theta_i, v_i)` model with known sampling variance and between-study heterogeneity τ²) | First slice (v0.13) |
| **[`mgcv::gam`](https://rdrr.io/pkg/mgcv/man/gam.html)** / **[`mgcv::bam`](https://rdrr.io/pkg/mgcv/man/bam.html)** additive models: gaussian / poisson / binomial / Gamma + `s(x)` + `s(x, by = factor)` + `te(x, z)`; smooths summarised in `metadata$smooths` (label, basis dim, edf); `f_l(x_i)` terms appended to the LaTeX linear predictor. [`mgcv::gamm`](https://rdrr.io/pkg/mgcv/man/gamm.html) / [`gamm4::gamm4`](https://rdrr.io/pkg/gamm4/man/gamm4.html) covered via the `$gam` slot | First slice (v0.14) |
| [`as_dag()`](https://itchyshin.github.io/symbolizer/reference/as_dag.md) structural model diagram (nodes / edges / DOT string) | First slice (v0.6) |
| [`model_card()`](https://itchyshin.github.io/symbolizer/reference/model_card.md) teaching bundle (equation + assumptions + readings + extraction calls) | First slice |
| [`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md) confidence bands (Wald / profile / credible) | First slice (v0.1.1) |
| [`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md), [`group_slopes()`](https://itchyshin.github.io/symbolizer/reference/group_slopes.md) via `emmeans` (response- and link-scale) | First slice (v0.1.1, response default in v0.3.1) |
| [`compare_symbolic()`](https://itchyshin.github.io/symbolizer/reference/compare_symbolic.md) structural diff + optional AIC/BIC metrics | First slice (v0.2) |
| [`methods_text()`](https://itchyshin.github.io/symbolizer/reference/methods_text.md) draft Methods-section paragraph (template-based) | First slice (v0.2.1) |
| [`warning_table()`](https://itchyshin.github.io/symbolizer/reference/warning_table.md) per-fit prose warnings | First slice (v0.2.1) |
| Expanded `emmeans` layer: `marginal_contrasts()`, `reference_grid_story()` (existing `group_means` / `group_slopes` extended in place) | Planned (v0.15) |
| [`metafor::rma.mv`](https://wviechtb.github.io/metafor/reference/rma.mv.html) (multilevel / multivariate meta-analysis) | Planned (v0.13.x) |
| brms negative-binomial / other distributional dpars; glmmTMB hurdle | Planned (v0.16+) |
| `gllvmTMB` other non-Gaussian families, within-unit decompositions, phylo / spatial | Planned |
| Phylogenetic flagship: `phylolm`, `phyloglm`, `phyr::pglmm`, `sommer` | Considered |

See
[`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md)
for the full registry — that table is the source of truth; any class /
family / component not marked Stable or First slice there will be
refused by
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md).

## Roadmap

| Version | Theme |
|----|----|
| v0.1 (released) | drmTMB Gaussian location-scale + (1 \| group); gllvmTMB Gaussian latent variables (First slice); [`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md) / [`model_card()`](https://itchyshin.github.io/symbolizer/reference/model_card.md) / dual notation |
| v0.1.1 (released) | Confidence bands via `drmTMB::confint`; marginal estimates via `emmeans` wrappers (`group_means`, `group_slopes`); intercept-less pedagogy; factors-vignette enrichment |
| v0.2 (released) | Bivariate Gaussian `rho12` / coscale extractor; [`compare_symbolic()`](https://itchyshin.github.io/symbolizer/reference/compare_symbolic.md) structural diff (+ optional AIC/BIC) |
| v0.2.1 (released) | [`methods_text()`](https://itchyshin.github.io/symbolizer/reference/methods_text.md) draft Methods paragraphs; [`warning_table()`](https://itchyshin.github.io/symbolizer/reference/warning_table.md) per-fit prose warnings; biv_gaussian gate on `group_means` |
| v0.3 (released) | Seven non-Gaussian drmTMB families (Student-t, lognormal, Gamma, beta, beta_binomial, Poisson, nbinom2, truncated_nbinom2); families-distributions CSV refactor so future families are CSV-only |
| v0.3.1 (released) | Random slopes `(1 + x \| group)` on μ; response-scale default for `group_means` / `group_slopes`; bigger pkgdown hex |
| v0.3.2 (released) | More CSV-only families (beta_binomial, truncated_nbinom2) + non-Gaussian families tour vignette |
| v0.4 (released) | `drmTMB` zero-inflation / hurdle / cumulative_logit |
| v0.5 (released) | gllvmTMB binomial (first non-Gaussian latent-variable family) |
| v0.6 (released) | `as_dag(sym)` structural model diagram (DOT-language string) |
| v0.7 (released) | `glmmTMB` Gaussian conditional submodel + `(1 \| g)` + `dispformula = ~ z`; CI band visible at all reading scales |
| v0.8 (released) | `brms` Gaussian + random effects |
| v0.9 (released) | `MCMCglmm` Gaussian + `~ g` random intercepts |
| v0.10 (released) | [`lme4::lmer`](https://rdrr.io/pkg/lme4/man/lmer.html), [`stats::lm`](https://rdrr.io/r/stats/lm.html), [`stats::glm`](https://rdrr.io/r/stats/glm.html) (gaussian / binomial / poisson) |
| v0.11.x (released) | glmmTMB non-Gaussian families (binomial / poisson / nbinom2 + zero-inflation); [`lme4::glmer`](https://rdrr.io/pkg/lme4/man/glmer.html); glm Gamma; brms binomial / poisson / `bf(sigma ~ z)`; robustness sweep across every extractor |
| v0.12 (released) | `sdmTMB` Gaussian + spatial / spatiotemporal random fields; `MCMCglmm` animal models via `ginverse`; roadmap text refresh |
| v0.13 (released) | [`metafor::rma.uni`](https://wviechtb.github.io/metafor/reference/rma.uni.html) — research-synthesis flagship: two-tier `y_i \| theta_i ~ N(theta_i, v_i)` with known sampling variance + tau² heterogeneity + meta-regression moderators |
| v0.14 (current) | [`mgcv::gam`](https://rdrr.io/pkg/mgcv/man/gam.html) / [`mgcv::bam`](https://rdrr.io/pkg/mgcv/man/bam.html) — additive models: `s(x)`, `s(x, by =)`, `te(x, z)` smooths summarised in `metadata$smooths`; `gamm` / `gamm4` covered via `$gam` slot |
| v0.15 | Expanded `emmeans` layer: `marginal_contrasts()`, `reference_grid_story()`; `group_means` / `group_slopes` extended in place (kept-public list grows by ~2, not 4) |

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
