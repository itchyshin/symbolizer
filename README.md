
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
> across the GLMM, meta-analysis, additive-model, Bayesian-multilevel,
> and classical (base-R) regression packages an ecologist or
> evolutionary biologist actually uses.

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

**Currently reads eleven package families** (14 fitted-class methods,
30+ family-class combinations): the two TMB sister packages
[`drmTMB`](https://itchyshin.github.io/drmTMB/) and
[`gllvmTMB`](https://itchyshin.github.io/gllvmTMB/), the broader GLMM
ecosystem `glmmTMB`, `brms`, `lme4` (`lmer` + `glmer`), `MCMCglmm`
(including animal models), `sdmTMB` (spatial + spatiotemporal random
fields), `stats::lm` / `stats::glm`, the meta-analytic framework
`metafor` (`rma.uni` + `rma.mv` with multilevel / structured /
location-scale variants), additive models via `mgcv::gam` / `mgcv::bam`
(with `gamm` / `gamm4` covered through the `$gam` slot), and
phylogenetic GLS via `phylolm`. See the
[Roadmap article](articles/symbolizer-roadmap.html) for the full
capability matrix; `symbolizer_capabilities()` is the in-package source
of truth, and any class / family / component not marked Stable or First
slice there will be refused by `symbolize()`.

**Works with multi-node SEMs too.** `symbolize()` reads piecewise
structural equation models in two flavours: mean-only piecewise SEMs
from [`piecewiseSEM::psem()`](https://jslefche.github.io/piecewiseSEM/)
via the bundled `symbolize.psem` method (each node delegates to
`symbolize.<class>()`), and distributional / location-scale piecewise
SEMs from [`drmSEM::drm_sem()`](https://itchyshin.github.io/drmSEM/) via
the `drmSEM`-side `symbolize.drm_sem` method (each node delegates to
`symbolize.drmTMB`). Both return a `symbolized_*` collator whose
`as_latex()`, `equations()`, and `assumption_table()` companions emit
per-node output stamped with the response variable.

## Install

`symbolizer` is pre-CRAN. Install the development build from GitHub with
`pak`:

``` r
install.packages("pak")
pak::pak("itchyshin/symbolizer")
```

## Tiny example

> **Want to start gentler?**
> [`vignette("symbolizer-ladder")`](articles/symbolizer-ladder.html)
> builds the same kind of model in four rungs — `lm()` → `lm()` with a
> factor → `lmer()` with random intercepts → `drmTMB` location-scale —
> using one shared dataset and showing what new line each rung adds to
> the symbolic equation. That’s the recommended on-ramp.

The example below jumps straight into a Gaussian location-scale fit with
`drmTMB`, then symbolizes it once:

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

`as_html_three_views(sym)` opens an interactive *Equation / Index /
Matrix-with-data* widget that runs your actual numeric arrays through
the model live. Three tabs — equation, expanded scalar form, matrix form
with data — backed by the same `symbolized_model` object.

``` r
as_html_three_views(sym)
```

<style>.sym-tabs { position: relative; border: 1px solid #e5e7eb; border-radius: 8px; overflow: hidden; margin: 1em 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
.sym-tablist { display: flex; background: #f9fafb; border-bottom: 1px solid #e5e7eb; }
.sym-tab { flex: 1; text-align: center; padding: 0.6rem 0.5rem; cursor: pointer; font-weight: 600; color: #6b7280; border: 0; border-right: 1px solid #e5e7eb; background: transparent; user-select: none; font-size: 0.92rem; font-family: inherit; }
.sym-tab:last-child { border-right: 0; }
.sym-tab:hover { background: #fbe7e7; color: #7a2a2a; }
.sym-tab.sym-active { background: #fff; color: #8a1f22; box-shadow: inset 0 -3px 0 #a0282b; }
.sym-tab:focus-visible { outline: 2px solid #a0282b; outline-offset: -2px; }
.sym-tab-marker { display: inline-block; margin-right: 0.35em; opacity: 0; transition: opacity 0.1s; }
.sym-tab.sym-active .sym-tab-marker { opacity: 1; }
.sym-panel { padding: 1rem 1.1rem 1.2rem; }
.sym-panel[hidden] { display: none; }
.sym-eq { background: #fbe7e7; border: 1px solid #a0282b; border-radius: 6px; padding: 0.7rem 1rem; margin: 0.4rem 0; text-align: center; overflow-x: auto; max-width: 100%; }
.sym-caption { color: #6b7280; font-size: 0.85rem; margin: 0.2rem 0 0.4rem; }
.sym-biology { color: #1f6feb; background: #f0f5ff; border-left: 3px solid #1f6feb; padding: 0.55rem 0.8rem; margin: 0.5rem 0 0.8rem; font-size: 0.95rem; line-height: 1.5; font-style: italic; }
.sym-gloss { margin: 0.8rem 0 0.2rem; font-size: 0.9rem; color: #374151; }
.sym-gloss > summary { cursor: pointer; font-weight: 600; color: #6b7280; padding: 0.2rem 0; }
.sym-gloss > summary:hover { color: #8a1f22; }
.sym-gloss-list { list-style: none; padding-left: 0.6rem; margin: 0.4rem 0 0.2rem; }
.sym-gloss-list li { margin: 0.4rem 0; line-height: 1.7; }
.sym-dim { color: #6b7280; font-size: 0.85rem; }
.sym-matrix { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 0.78rem; line-height: 1.35; white-space: pre; overflow-x: auto; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px; padding: 0.6rem 0.8rem; margin: 0.3rem 0; }
.sym-sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
.sym-skip { position: absolute; top: -100px; left: 0; padding: 0.4rem 0.7rem; background: #8a1f22; color: #fff; text-decoration: none; font-size: 0.85rem; z-index: 5; }
.sym-skip:focus { top: 0; }</style>

<div id="sym-sym-1779794964" class="sym-tabs">

<a class="sym-skip" href="#sym-sym-1779794964-end">Skip three-views
widget</a>

<div class="sym-tablist" role="tablist"
aria-label="Three views of the model">

<button type="button" class="sym-tab sym-active" role="tab" id="sym-sym-1779794964-tab-idx" aria-controls="sym-sym-1779794964-panel-idx" aria-selected="true" tabindex="0" data-tab="idx">

<span class="sym-tab-marker" aria-hidden="true">▸</span>1. Index
</button>

<button type="button" class="sym-tab" role="tab" id="sym-sym-1779794964-tab-eq" aria-controls="sym-sym-1779794964-panel-eq" aria-selected="false" tabindex="-1" data-tab="eq">

<span class="sym-tab-marker" aria-hidden="true">▸</span>2. Matrix
</button>

<button type="button" class="sym-tab" role="tab" id="sym-sym-1779794964-tab-mat" aria-controls="sym-sym-1779794964-panel-mat" aria-selected="false" tabindex="-1" data-tab="mat">

<span class="sym-tab-marker" aria-hidden="true">▸</span>3. Equations
with data
</button>

</div>

<div id="sym-sym-1779794964-panel-idx" class="sym-panel sym-active"
role="tabpanel" aria-labelledby="sym-sym-1779794964-tab-idx"
data-panel="idx" tabindex="0">

<p class="sym-caption">

What happens for each observation <em>i</em> – the per-individual
reading.
</p>

<p class="sym-biology">

Each observation is normally distributed around a mean that may shift
with the predictors, and a residual SD that may also shift with its own
predictors – so both the centre and the spread of the response are
modeled.
</p>

<div class="sym-eq">

$$\begin{aligned}
W_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i & = \beta_{0} + \beta_{1} \, T_i \\
\log(\sigma_i) & = \gamma_{0} + \gamma_{1} \, T_i
\end{aligned}$$

</div>

<details class="sym-gloss" open>

<summary>

where:
</summary>

<ul class="sym-gloss-list">

<li>

$W_i$ — response variable
 <span class="sym-dim">$\mathbb{R}^{200}$</span>
</li>

<li>

$T_i$ — continuous predictor  <span class="sym-dim">column of X (length
200)</span>
</li>

<li>

$\mu_i$ — conditional mu of body_mass
 <span class="sym-dim">$\mathbb{R}^{200}$</span>
</li>

<li>

$\sigma_i$ — conditional sigma of body_mass
 <span class="sym-dim">$\mathbb{R}^{200}$</span>
</li>

<li>

$\beta_{0}, \beta_{1}$ — mu submodel coefficients
 <span class="sym-dim">$\mathbb{R}^{2}$</span>
</li>

<li>

$\gamma_{0}, \gamma_{1}$ — sigma submodel coefficients
 <span class="sym-dim">$\mathbb{R}^{2}$</span>
</li>

</ul>

</details>

</div>

<div id="sym-sym-1779794964-panel-eq" class="sym-panel" role="tabpanel"
aria-labelledby="sym-sym-1779794964-tab-eq" data-panel="eq" hidden=""
tabindex="0">

<p class="sym-caption">

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.
</p>

<p class="sym-biology">

Each observation is normally distributed around a mean that may shift
with the predictors, and a residual SD that may also shift with its own
predictors – so both the centre and the spread of the response are
modeled.
</p>

<div class="sym-eq">

$$\begin{aligned}
\mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} \\
\log(\boldsymbol{\sigma}) & = \mathbf{Z} \boldsymbol{\gamma}
\end{aligned}$$

</div>

<details class="sym-gloss" open>

<summary>

where:
</summary>

<ul class="sym-gloss-list">

<li>

$\mathbf{w}$ — response variable
 <span class="sym-dim">$\mathbb{R}^{200}$</span>
</li>

<li>

$\boldsymbol{\mu}$ — conditional mu of body_mass
 <span class="sym-dim">$\mathbb{R}^{200}$</span>
</li>

<li>

$\boldsymbol{\sigma}$ — conditional sigma of body_mass
 <span class="sym-dim">$\mathbb{R}^{200}$</span>
</li>

<li>

$\boldsymbol{\beta}$ — mu submodel coefficients
 <span class="sym-dim">$\mathbb{R}^{2}$</span>
</li>

<li>

$\boldsymbol{\gamma}$ — sigma submodel coefficients
 <span class="sym-dim">$\mathbb{R}^{2}$</span>
</li>

<li>

$\mathbf{X}$ — mu submodel design matrix
 <span class="sym-dim">$\mathbb{R}^{200 \times 2}$</span>
</li>

<li>

$\mathbf{Z}$ — sigma submodel design matrix
 <span class="sym-dim">$\mathbb{R}^{200 \times 2}$</span>
</li>

</ul>

</details>

</div>

<div id="sym-sym-1779794964-panel-mat" class="sym-panel" role="tabpanel"
aria-labelledby="sym-sym-1779794964-tab-mat" data-panel="mat" hidden=""
tabindex="0">

<p class="sym-caption">

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 200.
</p>

<p class="sym-biology">

Each observation is normally distributed around a mean that may shift
with the predictors, and a residual SD that may also shift with its own
predictors – so both the centre and the spread of the response are
modeled.
</p>

<span class="sym-sr-only">Matrix-form expansion of the model. Each row
shows the response y_i and the corresponding row of the design matrix X
(showing head and tail rows of the n total observations), with the
coefficient vector beta listed below.</span>
<p class="sym-caption" style="font-size:0.95em;color:#374151">

For observation <em>i</em> = 1 of your data:
</p>

<div class="sym-eq">

$$
\begin{aligned}
W_{1} &= \hat\beta_{0} + \hat\beta_{1}\,\mathrm{temperature}_{1} + \hat\varepsilon_{1} &\quad(\text{response equation, one row of the model}) \\
31.5 &= 30.4 + 0.371 \times   14 + (-4.16) &\quad(\text{with your numbers}) \\
&= \underbrace{35.6}_{\textstyle\,\hat\mu_{1}\,\text{(predicted)}\,} \;+\; \underbrace{(-4.16)}_{\textstyle\,\hat\varepsilon_{1}\,\text{(residual)}\,}
\end{aligned}
$$

</div>

<p class="sym-caption" style="font-size:0.95em;color:#374151">

Stacking the same response equation for all <em>n</em> = 200
observations:
</p>

<div class="sym-eq">

$$
\underbrace{\begin{bmatrix} 31.5 \\ 36.6 \\ 27.8 \\ 42.2 \\ 31.2 \\ \vdots \\ 35.5 \\ 34.3 \end{bmatrix}}_{\textstyle\,\mathbf{w}_{\,200 \times 1}\;\text{(observed)}\,} \;=\; \underbrace{\begin{bmatrix}    1 &   14 \\    1 & 15.6 \\    1 & 18.6 \\    1 & 23.6 \\    1 &   13 \\ \vdots & \vdots \\    1 & 14.8 \\    1 & 21.7 \end{bmatrix}}_{\textstyle\,\mathbf{X}_{\,200 \times 2}\,}\, \underbrace{\begin{bmatrix} 30.4 \\ 0.371 \end{bmatrix}}_{\textstyle\,\hat{\boldsymbol{\beta}}_{\,2 \times 1}\;\text{(estimated)}\,} \;+\; \underbrace{\begin{bmatrix} -4.16 \\ 0.355 \\ -9.53 \\ 3.02 \\ -4.02 \\ \vdots \\ -0.364 \\ -4.23 \end{bmatrix}}_{\textstyle\,\hat{\boldsymbol{\varepsilon}}_{\,200 \times 1}\;\text{(residual)}\,}
$$

</div>

<p class="sym-caption" style="font-size:0.85em;color:#6b7280;margin-top:0.4rem">

<strong>Left</strong>: observed vector $\mathbf{w}$.
<strong>Middle</strong>: the prediction
$\mathbf{X}\hat{\boldsymbol{\beta}} = \hat{\boldsymbol{\mu}}$.
<strong>Right</strong>: the residual vector
$\hat{\boldsymbol{\varepsilon}} = \mathbf{w} - \hat{\boldsymbol{\mu}}$.
Every row of this matrix equation is one of the response-equation rows
from the worked row above.
</p>

<p class="sym-caption" style="font-size:0.95em;color:#374151;margin-top:1.2rem">

And the $\sigma$ submodel (no observed counterpart – $\sigma$’s job is
to describe the spread of $\hat{\boldsymbol{\varepsilon}}$). For the
same observation <em>i</em> = 1:
</p>

<div class="sym-eq">

$$
\begin{aligned}
\log\hat\sigma_{1} &= \hat\gamma_{0} + \hat\gamma_{1}\,\mathrm{temperature}_{1} &\quad(\text{sigma submodel for observation 1, log link}) \\
\log\hat\sigma_{1} &= 0.799 + 0.0825 \times   14 = 1.95 &\quad(\text{with your numbers}) \\
\hat\sigma_{1} &= \exp(1.95) \approx 7.04 &\quad(\text{predicted residual SD for observation 1})
\end{aligned}
$$

</div>

<p class="sym-caption" style="font-size:0.95em;color:#374151">

Stacking the same log-link equation for all <em>n</em> = 200
observations:
</p>

<div class="sym-eq">

$$
\log\!\underbrace{\begin{bmatrix} 7.04 \\ 8.03 \\ 10.3 \\ 15.6 \\ 6.51 \\ \vdots \\ 7.51 \\ 13.4 \end{bmatrix}}_{\textstyle\,\boldsymbol{\sigma}_{\,200 \times 1}\,} \;=\; \underbrace{\begin{bmatrix}    1 &   14 \\    1 & 15.6 \\    1 & 18.6 \\    1 & 23.6 \\    1 &   13 \\ \vdots & \vdots \\    1 & 14.8 \\    1 & 21.7 \end{bmatrix}}_{\textstyle\,\mathbf{X}_{\sigma,\,200 \times 2}\,}\, \underbrace{\begin{bmatrix} 0.799 \\ 0.0825 \end{bmatrix}}_{\textstyle\,\boldsymbol{\gamma}_{\,2 \times 1}\,}
$$

</div>

</div>

</div>

<span id="sym-sym-1779794964-end" tabindex="-1"></span>
<script>(function() {
  var root = document.getElementById("sym-sym-1779794964");
  if (!root) return;
  var tabs   = Array.prototype.slice.call(root.querySelectorAll("[role=\"tab\"]"));
  var panels = Array.prototype.slice.call(root.querySelectorAll("[role=\"tabpanel\"]"));
  function activate(idx) {
    tabs.forEach(function(t, i) {
      var on = (i === idx);
      t.classList.toggle("sym-active", on);
      t.setAttribute("aria-selected", on ? "true" : "false");
      t.setAttribute("tabindex", on ? "0" : "-1");
    });
    panels.forEach(function(p, i) {
      var on = (i === idx);
      p.classList.toggle("sym-active", on);
      if (on) { p.removeAttribute("hidden"); } else { p.setAttribute("hidden", ""); }
    });
    if (typeof window.MathJax !== "undefined" && window.MathJax.typesetPromise) {
      try { window.MathJax.typesetPromise([panels[idx]]); } catch (e) {}
    }
  }
  tabs.forEach(function(t, idx) {
    t.addEventListener("click", function() { activate(idx); t.focus(); });
    t.addEventListener("keydown", function(e) {
      var k = e.key;
      var n = tabs.length;
      var next = null;
      if (k === "ArrowRight") next = (idx + 1) % n;
      else if (k === "ArrowLeft") next = (idx - 1 + n) % n;
      else if (k === "Home") next = 0;
      else if (k === "End") next = n - 1;
      else if (k === "Enter" || k === " ") { activate(idx); e.preventDefault(); return; }
      if (next !== null) { activate(next); tabs[next].focus(); e.preventDefault(); }
    });
  });
})();</script>

On GitHub this section renders as static markup (GitHub doesn’t execute
the inline JavaScript); on the pkgdown homepage the tabs are
interactive. The same widget also renders in the [ladder
article](articles/symbolizer-ladder.html), in its own *Three views of
the same fit* section.

## Status

Pre-release. Read status words consistently:

| Status word | Meaning for a user |
|----|----|
| Stable | Routine path with tests, diagnostics, and a reader-facing example. |
| First slice | Fitted and tested, but intentionally narrow. |
| Opt-in control | Available for hardening, not a general modelling guarantee. |
| Planned or reserved | Public grammar may exist, but `symbolize()` should reject it as design-only. |
| Unsupported or blocked | Do not use as analysis syntax; fit the nearest implemented model. |

### At a glance

`symbolize()` reads **11 package families / 14 fitted-class methods /
30+ family-class combinations** today: `drmTMB`, `gllvmTMB`, `glmmTMB`,
`brms`, `lme4` (`lmer` + `glmer`), `MCMCglmm` (including animal models
via `ginverse`), `sdmTMB` (spatial + spatiotemporal fields), `stats::lm`
/ `stats::glm`, `metafor` (`rma.uni` + `rma.mv` with multilevel /
structured / phylogenetic random effects), `mgcv::gam` / `mgcv::bam`
(additive smooths; `gamm` / `gamm4` via `$gam`), and `phylolm`
(phylogenetic GLS).

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
