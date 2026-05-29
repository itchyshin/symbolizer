# Three flavors of meta-analysis: a cross-package tour

## 1. Three flavors of meta-analysis

Meta-analysis pools $`K`$ study-level effect sizes $`y_k`$, each with a
**known** sampling variance $`v_k`$, into a single summary. The same
idea can be tightened in three different directions; this article walks
all three side-by-side across three packages, so a reader can land on
whichever combination matches their toolkit.

**Flavor 1 — Traditional random-effects pooling.** Studies vary beyond
what sampling alone explains. The headline parameter is $`\tau^2`$, the
**between-study heterogeneity variance**:

``` math
y_k \mid \theta_k \sim \mathcal{N}(\theta_k, v_k),
\qquad
\theta_k \sim \mathcal{N}(\mu, \tau^2),
\qquad k = 1, \ldots, K.
```

A single $`\tau^2`$ describes how much “true” effect sizes scatter
across studies after sampling noise is accounted for. This is the
textbook random-effects model (Borenstein et al. 2009; Viechtbauer
2010).

**Flavor 2 — Phylogenetic meta-analysis.** When studies are on related
species, the between-study tier becomes structured by phylogeny. The
total between-species variance splits into a **phylogenetic** piece
(constrained by relatedness) and a **non-phylogenetic** piece:

``` math
\theta_k = \mu + u_{p,k} + u_{s,k},
\quad u_p \sim \mathcal{N}(\mathbf{0}, \sigma_p^2 \mathbf{A}),
\quad u_s \sim \mathcal{N}(\mathbf{0}, \sigma_s^2 \mathbf{I}).
```

$`\mathbf{A}`$ is the phylogenetic correlation matrix (Cinar et
al. 2022; Mizuno et al. 2026).

**Flavor 3 — Location-scale meta-analysis.** When moderators predict not
just the *mean* effect but also the *heterogeneity*, the scale parameter
itself becomes a regression:

``` math
y_k \sim \mathcal{N}(\mu_k, v_k + \tau_k^2),
\quad
\mu_k = \beta_0 + \beta_1 x_k,
\quad
\log \tau_k = \gamma_0 + \gamma_1 x_k.
```

The biological question shifts: *which moderators predict how variable
study effects are?* — separate from the mean.

**Three packages, one math.** The same model can be fit in `metafor`,
`glmmTMB`, `drmTMB`, `brms`, or `MCMCglmm`. Each section below picks one
**deep Face** (the package whose interface most cleanly expresses that
flavor) and two **light Faces** (showing the cross-package equivalence
so a reader’s existing fluency carries over).

**Takeaway.** Three flavors, one statistical motivation: separate the
sampling variance $`v_k`$ (known per study) from the heterogeneity
$`\tau^2`$ (estimated). Phylogenetic and location-scale flavors
*structure* that heterogeneity further.

## 2. The data: BCG vaccine efficacy trials

We use `dat.bcg` from `metafor` (Colditz et al. 1994): thirteen
randomised trials of the BCG vaccine against tuberculosis, with
treatment / control case counts per trial. The summary effect is the
**log risk ratio**:

``` math
y_k = \log\!\left(\frac{a_k / (a_k + b_k)}{c_k / (c_k + d_k)}\right),
\qquad
v_k = \frac{1}{a_k} - \frac{1}{a_k + b_k} + \frac{1}{c_k} - \frac{1}{c_k + d_k}.
```

``` r

library(metafor)
#> Loading required package: Matrix
#> Loading required package: metadat
#> Loading required package: numDeriv
#> 
#> Loading the 'metafor' package (version 5.0-1). For an
#> introduction to the package please type: help(metafor)
library(symbolizer)
#> 
#> Attaching package: 'symbolizer'
#> The following object is masked from 'package:Matrix':
#> 
#>     expand

data(dat.bcg, package = "metafor")
#> Warning in data(dat.bcg, package = "metafor"): data set 'dat.bcg' not found
dat <- escalc(measure = "RR",
              ai = tpos, bi = tneg,
              ci = cpos, di = cneg,
              data = dat.bcg)
head(dat[, c("author", "year", "yi", "vi")], 6)
#> 
#>                 author year      yi     vi 
#> 1              Aronson 1948 -0.8893 0.3256 
#> 2     Ferguson & Simes 1949 -1.5854 0.1946 
#> 3      Rosenthal et al 1960 -1.3481 0.4154 
#> 4    Hart & Sutherland 1977 -1.4416 0.0200 
#> 5 Frimodt-Moller et al 1973 -0.2175 0.0512 
#> 6      Stein & Aronson 1953 -0.7861 0.0069
```

Thirteen trials; effect sizes range from strong protection ($`y_k < 0`$)
to no effect ($`y_k \approx 0`$). The sampling variances $`v_k`$ are
**known** (computed from the trial counts) and differ across trials —
large trials have small $`v_k`$, small trials have large $`v_k`$. *Any*
meta-analysis must respect that.

**Takeaway.** Same effect-size metric ($`y_k`$ = log RR), same known
sampling variance metric ($`v_k`$). One dataset reused across the three
flavors below.

## 3. Traditional pooling

The simplest flavor. Each trial gives $`y_k`$ with known $`v_k`$; we
pool to estimate a single mean $`\mu`$ and the between-study
heterogeneity $`\tau^2`$.

### 3.1 The model in symbols

``` math
y_k \mid \theta_k \sim \mathcal{N}(\theta_k, v_k),
\qquad
\theta_k \sim \mathcal{N}(\mu, \tau^2),
\qquad k = 1, \ldots, 13.
```

The marginal form (integrating out $`\theta_k`$) is the more commonly
fit one:

``` math
y_k \sim \mathcal{N}(\mu, v_k + \tau^2),
\qquad
\mathrm{Cov}(y_k, y_{k'}) = 0 \text{ for } k \ne k'.
```

**Two parameters of interest**: $`\mu`$ (the average log RR) and
$`\tau^2`$ (how much trials disagree beyond sampling noise).

### 3.2 Face 1 — `metafor::rma()` (deep dive)

`metafor` was built for meta-analysis;
[`rma()`](https://wviechtb.github.io/metafor/reference/rma.uni.html) is
the canonical random-effects fit.

``` r

fit_metafor <- rma(yi, vi, data = dat)
fit_metafor
#> 
#> Random-Effects Model (k = 13; tau^2 estimator: REML)
#> 
#> tau^2 (estimated amount of total heterogeneity): 0.3132 (SE = 0.1664)
#> tau (square root of estimated tau^2 value):      0.5597
#> I^2 (total heterogeneity / total variability):   92.22%
#> H^2 (total variability / sampling variability):  12.86
#> 
#> Test for Heterogeneity:
#> Q(df = 12) = 152.2330, p-val < .0001
#> 
#> Model Results:
#> 
#> estimate      se     zval    pval    ci.lb    ci.ub      
#>  -0.7145  0.1798  -3.9744  <.0001  -1.0669  -0.3622  *** 
#> 
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

`tau^2 = 0.31` says the true effects scatter across trials with standard
deviation $`\hat\tau \approx 0.56`$ on the log RR scale — substantial
heterogeneity. $`I^2 = 92\%`$ confirms: of total variation, 92% is
heterogeneity not sampling noise.

``` r

sym_metafor <- symbolize(fit_metafor)
equations(sym_metafor)
```

``` math
\begin{aligned}
y_i \mid \theta_i \sim \mathrm{Normal}(\theta_i,\, v_i), \quad v_i \text{ known} \\
\mu_i = \beta_{0} + u_{study(i)} \\
u_{study} \sim \mathcal{N}(0,\, \sigma_{study}^2)
\end{aligned}
```

``` r

assumption_table(sym_metafor)
```

| assumption | expression | biological meaning | status |
|:---|:---|:---|:---|
| conditional_distribution | $`y_i \mid \theta_i \sim \mathrm{Normal}(\theta_i,\, v_i)`$ | Each observed effect size is normally distributed around its true effect with KNOWN sampling variance | explicit |
| known_sampling_variance | $`v_i \text{ is known (not estimated)}`$ | Sampling variances v_i come from each primary study (or from escalc()); they are inputs, not parameters | your responsibility |
| linear_predictor | $`\theta_i = \beta_0 + \sum_k \beta_k X_{ki} + u_i`$ | True effects are a linear combination of moderators plus a study-level random effect | explicit |
| random_effects_distribution | $`u_i \sim \mathrm{Normal}(0,\, \tau^2)`$ | The between-study true effects vary around the grand mean with variance tau^2 | explicit |
| inverse_variance_weights | $`w_i = 1 / (v_i + \tau^2)`$ | Each study is weighted by the inverse of (sampling variance + heterogeneity) | explicit |
| no_publication_bias | — | The included effect sizes are not preferentially the larger / significant ones; if they are, tau^2 / beta are biased | your responsibility |
| correct_effect_metric | — | The metric (log RR, log OR, SMD, Fisher-z r, …) is appropriate for the outcome and is calculated consistently across studies | your responsibility |
| no_missing_at_random | — | Studies are not missing in a way that depends on their unobserved true effect | your responsibility |

**Coefficient reading on μ.** $`\hat\mu = -0.71`$ on the log RR scale is
$`\exp(-0.71) \approx 0.49`$ on the response scale — vaccinated children
have about half the TB rate of unvaccinated children, averaged across
trials, with substantial trial-to-trial variation.

### 3.3 Face 2 — `glmmTMB` (light)

`glmmTMB` fits the same math via a random-intercept model with a
per-observation weight that pins the residual variance to $`v_k`$:

``` r

if (requireNamespace("glmmTMB", quietly = TRUE)) {
  dat$study <- factor(seq_len(nrow(dat)))
  fit_glmmTMB <- glmmTMB::glmmTMB(
    yi ~ 1 + (1 | study),
    weights = 1 / vi,
    dispformula = ~ 0,        # pin residual SD to 1; weights carry v_k
    data = dat
  )
  cat("glmmTMB tau^2:",
      round(as.numeric(glmmTMB::VarCorr(fit_glmmTMB)$cond$study), 3),
      "(vs metafor:", round(fit_metafor$tau2, 3), ")\n")
} else {
  cat("glmmTMB not installed; skipping Face 2.\n")
}
#> glmmTMB tau^2: 0.444 (vs metafor: 0.313 )
```

The bridge: `dispformula = ~0` fixes the Gaussian dispersion at 1, and
`weights = 1/vi` makes each observation’s effective residual variance
equal to $`v_k`$ rather than 1 — which reproduces the meta-analytic
likelihood. The estimated random-intercept variance is $`\hat\tau^2`$.

### 3.4 Face 3 — `drmTMB` (light)

`drmTMB` is symbolizer’s distributional-regression workhorse. For
traditional meta-analysis without moderators it reduces to a weighted
Gaussian fit:

``` r

if (requireNamespace("drmTMB", quietly = TRUE)) {
  fit_drm <- drmTMB::drmTMB(
    drmTMB::drm_formula(yi ~ 1),
    family  = stats::gaussian(),
    weights = 1 / vi,
    data    = dat
  )
  cat("drmTMB residual sigma^2:",
      round(fit_drm$report$sigma_eps^2, 3),
      "\n")
} else {
  cat("drmTMB not installed; skipping Face 3.\n")
}
#> drmTMB residual sigma^2:
```

drmTMB without `sigma ~ x` or a random intercept does **not** separate
sampling from heterogeneity — the residual variance absorbs both. The
useful drmTMB Face is in §5 (location-scale), where the
`sigma ~ moderator + offset(0.5 * log(vi))` syntax models heterogeneity
explicitly as a function of moderators while still respecting the known
sampling variances $`v_k`$.

### 3.5 Cross-package summary

| Package | Call | Captures $`\tau^2`$ as |
|----|----|----|
| `metafor` | `rma(yi, vi, data = dat)` | `fit$tau2` directly. |
| `glmmTMB` | `glmmTMB(yi ~ 1 + (1\|study), weights = 1/vi, dispformula = ~0)` | `VarCorr(fit)$cond$study[1]`. |
| `drmTMB` | `drmTMB(drm_formula(yi ~ 1), weights = 1/vi)` | Residual $`\sigma_\varepsilon^2`$ (no separate $`\tau^2`$ without a random intercept). |
| `brms` | `brm(yi \| se(sqrt(vi)) ~ 1 + (1\|study))` | Random-intercept SD posterior. |
| `MCMCglmm` | `MCMCglmm(yi ~ 1, random = ~ study, mev = vi)` | `VCV[,"study"]` posterior. |

The math is one model; the syntax differs by package. The bridge columns
in `formula_bridge(sym_metafor)` summarise the rest.

**Takeaway.** Traditional pooling separates known sampling variance
$`v_k`$ from estimated heterogeneity $`\tau^2`$. metafor’s
[`rma()`](https://wviechtb.github.io/metafor/reference/rma.uni.html) is
the cleanest interface; glmmTMB and drmTMB reproduce the math via
`weights = 1/vi`; brms and MCMCglmm use their own meta-analytic bridges
(`se(sqrt(vi))`, `mev = vi`).

## 4. Phylogenetic multilevel meta-analysis

**Dataset switch.** The 13-trial BCG dataset of §3 was great for showing
traditional pooling, but it has only one study per row — so no
species-level or phylogenetic structure to model. For §4 and §5 we move
to a richer dataset: a 35-species, 164-effect subset of the Pottier et
al. (2022) thermal acclimation meta-dataset, with `dARR` as the effect
size and `habitat` (aquatic vs terrestrial) as the moderator. The subset
is shipped with the package so the vignette is fully reproducible.

When studies are on related species, the between-study tier splits into
a phylogenetic piece (constrained by the phylogeny via $`\mathbf{A}`$)
and a non-phylogenetic study tier.

### 4.1 The model in symbols

For each effect $`kt`$ in study $`k`$ on species $`s(k)`$:

``` math
y_{kt} = \beta_0 + \beta_1\, x_{kt} + u_{p,\,s(k)} + u_{\text{study},\,k} + \epsilon_{kt}
```

with

``` math
u_{p,\,s} \sim \mathcal{N}(\mathbf{0},\, \sigma_p^2\, \mathbf{A}),
\quad
u_{\text{study},\,k} \sim \mathcal{N}(0,\, \sigma_{\text{study}}^2),
\quad
\epsilon_{kt} \sim \mathcal{N}(0,\, v_{kt}).
```

The known sampling variance $`v_{kt}`$ is fixed per effect (computed
from the original study’s sample size). The marginal variance of one
effect is

``` math
\mathrm{Var}(y_{kt}) = v_{kt} + \sigma_{\text{study}}^2 + \sigma_p^2\, \mathbf{A}_{s(k),\,s(k)}.
```

This is the Nakagawa-paper-style “phylogenetic multilevel meta-analysis”
form, with the location-scale extension deferred to §5.

### 4.2 Data

A 35-species, 164-effect subset of the Pottier et al. (2022) thermal
acclimation dataset (effect-size = `dARR`; moderator = `habitat`,
aquatic vs terrestrial). Subsample is shipped with the package so the
vignette is fully reproducible without network access.

``` r

library(symbolizer)
library(ape)
dat <- read.csv(system.file("extdata", "thermal_subset.csv",
                            package = "symbolizer"),
                stringsAsFactors = FALSE)
tree <- ape::read.tree(system.file("extdata", "thermal_subset_tree.tre",
                                   package = "symbolizer"))
cat(sprintf("%d effects across %d species across %d studies; habitats: %s\n",
            nrow(dat),
            length(unique(dat$phylogeny)),
            length(unique(dat$study_ID)),
            paste(sort(unique(dat$habitat)), collapse = ", ")))
#> 164 effects across 35 species across 39 studies; habitats: aquatic, terrestrial
```

### 4.3 Face 1 — `drmTMB` (deep dive)

The model adds the §3 study-tier random effect to a phylogenetic random
effect with covariance $`\sigma_p^2\,\mathbf{A}`$, on top of the known
per-effect sampling variance $`v_k`$. In drmTMB’s idiom that is one
formula with two markers:
[`meta_V()`](https://itchyshin.github.io/drmTMB/reference/meta_V.html)
*inside* the formula (replacing brms’s response-side `se(sqrt(vi))`) and
[`phylo()`](https://itchyshin.github.io/drmTMB/reference/phylo.html)
*inside* the formula too (replacing brms’s `gr(., cov = A)`). One
gotcha: drmTMB’s formula parser does NOT accept namespace-qualified
names inside the formula, so we bind the helpers to local names first.

``` r

library(drmTMB)

# drmTMB requires unqualified names INSIDE the formula -- bind locally.
bf      <- drmTMB::drm_formula
meta_V  <- drmTMB::meta_V
phylo   <- drmTMB::phylo

fit_drm_phylo <- drmTMB::drmTMB(
  bf(
    dARR ~ 1 + habitat +
            meta_V(V = Var_dARR) +
            phylo(1 | phylogeny, tree = tree) +
            (1 | study_ID),
    sigma ~ 1),
  family = stats::gaussian(),
  data   = dat
)
sym_drm_phylo <- symbolize(
  fit_drm_phylo,
  context = "phylogenetic multilevel meta-analysis"
)
```

#### Three views — phylogenetic multilevel

[Skip three-views widget](#sym-phylomultilevel-1780075472-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

Species are not independent observations. Closely related species tend
to have similar trait values because of shared evolutionary history; the
phylogenetic correlation matrix $`\mathbf{A}`$ encodes those expected
similarities (cell $`A_{ij}`$ = fraction of shared branch length between
species $`i`$ and $`j`$). The phylogenetic SD $`\sigma_p`$ measures how
much across-species variation remains after fixed-effect predictors are
accounted for.

**Coefficient reading.** On the response scale, $`\hat\beta`$ is the
additive change in the mean of the response for a one-unit increase in
the predictor (identity link – no back-transformation needed).

``` math
\begin{aligned}
\mathrm{dARR}_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i & = \beta_{0} + \beta_{1} \, [habitat = \mathrm{terrestrial}] + u_{study_ID(i)} + u_{phylogeny(i)} \\
\log(\sigma_i) & = \gamma_{0} \\
u_{study_ID} & \sim \mathcal{N}(0,\, \sigma_{study_ID}^2) \\
\mathbf{u}_{phylogeny} & \sim \mathcal{N}(\mathbf{0},\, \sigma_{phylogeny}^2 \mathbf{A})
\end{aligned}
```

where:

- $`\mathrm{dARR}_i`$ — response variable  $`\mathbb{R}^{164}`$
- $`habitat_i`$ — factor (aquatic \[reference\], terrestrial)  column of
  X (length 164)
- $`\mu_i`$ — conditional mu of dARR  $`\mathbb{R}^{164}`$
- $`\sigma_i`$ — residual standard deviation  $`\mathbb{R}^{164}`$
- $`\beta_{0}, \beta_{1}`$ — mu submodel coefficients
   $`\mathbb{R}^{2}`$
- $`\gamma_{0}`$ — sigma submodel coefficients  $`\mathbb{R}^{1}`$
- $`u_{study_ID(i)}`$ — random intercept by study_ID  scalar;
  $`\mathbb{R}^{39}`$ in matrix form
- $`\sigma_{study_ID}`$ — between-study_ID standard deviation  scalar
- $`u_{phylogeny(i)}`$ — random intercept by phylogeny  scalar;
  $`\mathbb{R}^{35}`$ in matrix form
- $`\sigma_{phylogeny}`$ — between-phylogeny standard deviation  scalar
- $`\mathbf{A}`$ — phylogenetic / pedigree correlation matrix from
  drmTMB::phylo() or drmTMB::animal(); Hadfield-Nakagawa A-inverse
  sparse-precision representation (all-nodes: latent vector spans tips
  and internal nodes)  $`\mathbb{R}^{k \times k}`$

**Where does the variation live?** Where the variation lives – each row
is one source of variance, shown as a share of the total.

    <div class="sym-vc-row" style="display:flex;align-items:center;margin:0.25rem 0;font-size:0.8rem">
      <span style="flex:0 0 38%;color:#374151;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">study_ID</span>
      <span style="flex:1;background:#f3f4f6;border-radius:3px;overflow:hidden"><span style="display:block;width:0.0%;background:#2c7fb8;color:#fff;padding:0.1rem 0.35rem;white-space:nowrap;box-sizing:border-box">0.0%</span></span>
    </div>
    <div class="sym-vc-row" style="display:flex;align-items:center;margin:0.25rem 0;font-size:0.8rem">
      <span style="flex:0 0 38%;color:#374151;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">phylogeny</span>
      <span style="flex:1;background:#f3f4f6;border-radius:3px;overflow:hidden"><span style="display:block;width:0.0%;background:#7fcdbb;color:#fff;padding:0.1rem 0.35rem;white-space:nowrap;box-sizing:border-box">0.0%</span></span>
    </div>
    <div class="sym-vc-row" style="display:flex;align-items:center;margin:0.25rem 0;font-size:0.8rem">
      <span style="flex:0 0 38%;color:#374151;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">Residual (within-group)</span>
      <span style="flex:1;background:#f3f4f6;border-radius:3px;overflow:hidden"><span style="display:block;width:100.0%;background:#d9d9d9;color:#fff;padding:0.1rem 0.35rem;white-space:nowrap;box-sizing:border-box">100.0%</span></span>
    </div>

**ICC:** ICC not available on this scale yet. (more than one
random-effect term, so a single-number ICC is not defined – read the
full variance partition instead.)

Point estimates only; uncertainty not shown.

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Species are not independent observations. Closely related species tend
to have similar trait values because of shared evolutionary history; the
phylogenetic correlation matrix $`\mathbf{A}`$ encodes those expected
similarities (cell $`A_{ij}`$ = fraction of shared branch length between
species $`i`$ and $`j`$). The phylogenetic SD $`\sigma_p`$ measures how
much across-species variation remains after fixed-effect predictors are
accounted for.

``` math
\begin{aligned}
\mathbf{darr} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} + \mathbf{u}_{study_ID} + \mathbf{u}_{phylogeny} \\
\log(\boldsymbol{\sigma}) & = \mathbf{Z} \boldsymbol{\gamma} \\
\mathbf{u}_{study_ID} & \sim \mathcal{N}(\mathbf{0},\, \sigma_{study_ID}^2 \mathbf{I}_{39}) \\
\mathbf{u}_{phylogeny} & \sim \mathcal{N}(\mathbf{0},\, \sigma_{phylogeny}^2 \mathbf{A}_{35 \times 35})
\end{aligned}
```

where:

- $`\mathbf{darr}`$ — response variable  $`\mathbb{R}^{164}`$
- $`\boldsymbol{\mu}`$ — conditional mu of dARR  $`\mathbb{R}^{164}`$
- $`\boldsymbol{\sigma}`$ — residual standard deviation
   $`\mathbb{R}^{164}`$
- $`\boldsymbol{\beta}`$ — mu submodel coefficients  $`\mathbb{R}^{2}`$
- $`\boldsymbol{\gamma}`$ — sigma submodel coefficients
   $`\mathbb{R}^{1}`$
- $`\mathbf{X}`$ — mu submodel design matrix
   $`\mathbb{R}^{164 \times 2}`$
- $`\mathbf{Z}`$ — sigma submodel design matrix
   $`\mathbb{R}^{164 \times 1}`$
- $`\mathbf{u}_{study_ID}`$ — random intercept by study_ID  scalar;
  $`\mathbb{R}^{39}`$ in matrix form
- $`\sigma_{study_ID}`$ — between-study_ID standard deviation  scalar
- $`\mathbf{u}_{phylogeny}`$ — random intercept by phylogeny  scalar;
  $`\mathbb{R}^{35}`$ in matrix form
- $`\sigma_{phylogeny}`$ — between-phylogeny standard deviation  scalar
- $`\mathbf{A}`$ — phylogenetic / pedigree correlation matrix from
  drmTMB::phylo() or drmTMB::animal(); Hadfield-Nakagawa A-inverse
  sparse-precision representation (all-nodes: latent vector spans tips
  and internal nodes)  $`\mathbb{R}^{k \times k}`$

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 164.

Species are not independent observations. Closely related species tend
to have similar trait values because of shared evolutionary history; the
phylogenetic correlation matrix $`\mathbf{A}`$ encodes those expected
similarities (cell $`A_{ij}`$ = fraction of shared branch length between
species $`i`$ and $`j`$). The phylogenetic SD $`\sigma_p`$ measures how
much across-species variation remains after fixed-effect predictors are
accounted for.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below. The predicted random-effect contribution to each observation is
also shown.

For observation *i* = 1 of your data:

``` math
\begin{aligned}
darr_{1} &= \hat\beta_{0} + \hat\beta_{1}\,\mathrm{habitatterrestrial}_{1} + \hat{u}_{\mathrm{study\_ID},\,\mathrm{3}} + \hat{u}_{\mathrm{phylogeny},\,\mathrm{Myzus\_persicae}} + \hat\varepsilon_{1} &\quad(\text{response equation, one row of the model}) \\
\hat\mu_{1} &= 0.254 - 0.208 \times    1 + (9.74e-11) + (4.92e-15) \approx 0.0452 &\quad(\text{predicted mean} = \text{linear predictor}) \\
darr_{1} &= \underbrace{0.0452}_{\textstyle\,\hat\mu_{1}\,\text{(predicted)}\,} \;+\; \underbrace{(-0.0332)}_{\textstyle\,\hat\varepsilon_{1}\,\text{(residual)}\,} &\quad(\text{observed} = \text{predicted mean} + \text{residual})
\end{aligned}
```

Stacking the same response equation for all *n* = 164 observations:

``` math
\underbrace{\begin{bmatrix} 0.012 \\ 0.048 \\ 0.0623 \\ 0.108 \\ 0.189 \\ \vdots \\ 0.632 \\ 0.59 \end{bmatrix}}_{\textstyle\,\mathbf{darr}_{\,164 \times 1}\;\text{(observed)}\,} \;=\; \underbrace{\begin{bmatrix}    1 &    1 \\    1 &    1 \\    1 &    1 \\    1 &    1 \\    1 &    1 \\ \vdots & \vdots \\    1 &    0 \\    1 &    0 \end{bmatrix}}_{\textstyle\,\mathbf{X}_{\,164 \times 2}\,}\, \underbrace{\begin{bmatrix} 0.254 \\ -0.208 \end{bmatrix}}_{\textstyle\,\hat{\boldsymbol{\beta}}_{\,2 \times 1}\;\text{(estimated)}\,} \;+\; \underbrace{\begin{bmatrix}    1 &    0 &    0 &    0 &    0 & \cdots &    0 &    0 \\    1 &    0 &    0 &    0 &    0 & \cdots &    0 &    0 \\    1 &    0 &    0 &    0 &    0 & \cdots &    0 &    0 \\    1 &    0 &    0 &    0 &    0 & \cdots &    0 &    0 \\    1 &    0 &    0 &    0 &    0 & \cdots &    0 &    0 \\ \vdots & \vdots & \vdots & \vdots & \vdots & \ddots & \vdots & \vdots \\    0 &    0 &    0 &    0 &    0 & \cdots &    0 &    1 \\    0 &    0 &    0 &    0 &    0 & \cdots &    0 &    1 \end{bmatrix}}_{\textstyle\,\mathbf{Z}_{\text{study\_ID},\,\,164 \times 39}\,}\, \underbrace{\begin{bmatrix} 9.74e-11 \\ -2.79e-10 \\ -4.38e-11 \\ -8.03e-11 \\ 4.45e-11 \\ \vdots \\ 8.02e-11 \\ 1.85e-10 \end{bmatrix}}_{\textstyle\,\hat{\mathbf{u}}_{\text{study\_ID},\,39 \times 1}\;\text{(BLUP)}\,} \;+\; \underbrace{\begin{bmatrix}    0 &    0 &    0 &    1 &    0 & \cdots &    0 &    0 \\    0 &    0 &    0 &    1 &    0 & \cdots &    0 &    0 \\    0 &    0 &    0 &    1 &    0 & \cdots &    0 &    0 \\    0 &    0 &    0 &    1 &    0 & \cdots &    0 &    0 \\    0 &    0 &    0 &    1 &    0 & \cdots &    0 &    0 \\ \vdots & \vdots & \vdots & \vdots & \vdots & \ddots & \vdots & \vdots \\    0 &    0 &    0 &    0 &    1 & \cdots &    0 &    0 \\    0 &    0 &    0 &    0 &    1 & \cdots &    0 &    0 \end{bmatrix}}_{\textstyle\,\mathbf{Z}_{\text{phylogeny},\,\,164 \times 35}\,}\, \underbrace{\begin{bmatrix} -2.28e-15 \\ -3.97e-15 \\ -3.2e-15 \\ 4.92e-15 \\ 8.16e-15 \\ \vdots \\ -8.76e-15 \\ -3.85e-15 \end{bmatrix}}_{\textstyle\,\hat{\mathbf{u}}_{\text{phylogeny},\,35 \times 1}\;\text{(BLUP)}\,} \;+\; \underbrace{\begin{bmatrix} -0.0332 \\ 0.00281 \\ 0.0171 \\ 0.0628 \\ 0.143 \\ \vdots \\ 0.378 \\ 0.336 \end{bmatrix}}_{\textstyle\,\hat{\boldsymbol{\varepsilon}}_{\,164 \times 1}\;\text{(residual)}\,}
```

**Left**: observed vector $`\mathbf{darr}`$. **Middle**: the prediction
$`\mathbf{X}\hat{\boldsymbol{\beta}} + \mathbf{Z}\hat{\mathbf{u}} = \hat{\boldsymbol{\mu}}`$.
**Right**: the residual vector
$`\hat{\boldsymbol{\varepsilon}} = \mathbf{darr} - \hat{\boldsymbol{\mu}}`$.
Every row of this matrix equation is one of the response-equation rows
from the worked row above.

**Partial pooling.** The random-effect estimates shown here (the BLUPs)
are partially pooled: each group’s estimate is shrunk toward zero by an
amount that grows when the group has little data and shrinks when the
between-group variance is large. Groups with the least data are pulled
hardest toward the overall mean.

And the $`\sigma`$ submodel (no observed counterpart – $`\sigma`$’s job
is to describe the spread of $`\hat{\boldsymbol{\varepsilon}}`$). For
the same observation *i* = 1:

``` math
\begin{aligned}
\log\hat\sigma_{1} &= \hat\gamma_{0} &\quad(\text{sigma submodel for observation 1, log link}) \\
\log\hat\sigma_{1} &= -1.06 &\quad(\text{with your numbers}) \\
\hat\sigma_{1} &= \exp(-1.06) \approx 0.346 &\quad(\text{predicted residual SD for observation 1})
\end{aligned}
```

Stacking the same log-link equation for all *n* = 164 observations:

``` math
\log\!\underbrace{\begin{bmatrix} 0.346 \\ 0.346 \\ 0.346 \\ 0.346 \\ 0.346 \\ \vdots \\ 0.346 \\ 0.346 \end{bmatrix}}_{\textstyle\,\boldsymbol{\sigma}_{\,164 \times 1}\,} \;=\; \underbrace{\begin{bmatrix}    1 \\    1 \\    1 \\    1 \\    1 \\ \vdots \\    1 \\    1 \end{bmatrix}}_{\textstyle\,\mathbf{X}_{\sigma,\,164 \times 1}\,}\, \underbrace{\begin{bmatrix} -1.06 \end{bmatrix}}_{\textstyle\,\boldsymbol{\gamma}_{\,1 \times 1}\,}
```

Marginal covariance of the response decomposes into the (known) sampling
tier plus one term per random-effect group. Structured tiers carry their
correlation matrix; unstructured tiers use the identity via
$`\mathbf{Z}_g\mathbf{Z}_g^{\!\top}`$:

``` math
\underbrace{\mathrm{Cov}(\mathbf{y})}_{\textstyle\,n \times n,\; n = 164\,} \;=\; \underbrace{\sigma_{study_ID}^2\, \mathbf{Z}_{study_ID}\mathbf{Z}_{study_ID}^{\!\top}}_{\textstyle\,\text{study_ID tier}\,} \;+\; \underbrace{\sigma_{phylogeny}^2\, \mathbf{A}}_{\textstyle\,\text{phylogeny tier}\,} \;+\; \underbrace{\mathrm{diag}(\mathbf{v})}_{\textstyle\,\text{known sampling}\,}
```

The widget’s **Tab 3** decomposes the marginal variance into the known
sampling tier $`v_{kt}`$ and the two estimated tiers
($`\sigma_{\text{study}}^2`$, $`\sigma_p^2\,\mathbf{A}_{kk}`$). Tabs 1
and 2 carry the matching index- and matrix-form equations, including the
phylogenetic line $`\mathbf{u}_p \sim \mathcal{N}(\mathbf{0},\,
\sigma_p^2\,\mathbf{A})`$ — drmTMB consumes
[`phylo()`](https://itchyshin.github.io/drmTMB/reference/phylo.html)
into its internal sparse-precision pipeline rather than
`fit$random_effects`, and
[`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
synthesises the structured tier so the widget renders the full two-tier
model (v0.22.1.1).

### 4.4 Face 2 — `brms` (light, with `se(sqrt(vi))` + `gr(., cov = A)`)

The same math in brms’s idiom. Note that
[`se()`](https://wviechtb.github.io/metafor/reference/se.html) is parsed
by brms internally — you write it *unqualified* inside
[`bf()`](https://paulbuerkner.com/brms/reference/brmsformula.html), not
as
[`brms::se()`](https://paulbuerkner.com/brms/reference/addition-terms.html).

``` r

library(brms)
A_phylo <- ape::vcv.phylo(tree, corr = TRUE)
fit_brms_phylo <- brm(
  bf(dARR | se(sqrt(Var_dARR)) ~ 1 + habitat
       + (1 | study_ID)
       + (1 | gr(phylogeny, cov = mat))),
  data   = dat,
  data2  = list(mat = A_phylo),
  family = gaussian(),
  chains = 2, iter = 1000, warmup = 500,
  file = "cache/brms-phylo-multilevel"   # cache to disk
)
```

The cross-package bridge (cf. §7): brms `se(sqrt(vi))` ↔︎ drmTMB
`meta_V(V = vi)`; brms `gr(g, cov = A)` ↔︎ drmTMB
`phylo(1 | g, tree = ...)`.

### 4.5 Face 3 — `metafor::rma.mv` (light)

`metafor` was built for meta-analysis;
[`rma.mv()`](https://wviechtb.github.io/metafor/reference/rma.mv.html)
accepts `V = vi` for the known sampling variances and
`R = list(... = A)` for the phylogenetic correlation:

``` r

library(metafor)
A_phylo <- ape::vcv.phylo(tree, corr = TRUE)
fit_metafor_phylo <- rma.mv(
  yi     = dARR,
  V      = Var_dARR,
  mods   = ~ 1 + habitat,
  random = list(~ 1 | phylogeny, ~ 1 | study_ID),
  R      = list(phylogeny = A_phylo),
  data   = dat
)
fit_metafor_phylo$sigma2
#> [1] 0.002742389 0.035531489
```

The two `$sigma2` rows correspond, in the listed order, to the
phylogenetic tier $`\sigma_p^2`$ (first row) and the study tier
$`\sigma_{\text{study}}^2`$ (second row). On the Pottier thermal subset,
the study-level variance dominates the phylogenetic variance by an order
of magnitude — most heterogeneity in dARR sits between studies rather
than along the phylogeny. (Heritability reading:
$`H^2 = \sigma_p^2 / (\sigma_p^2 + \sigma_{\text{study}}^2)`$.)

**Takeaway.** Three packages, one math. drmTMB leads with the cleanest
meta-analytic idiom (`meta_V` + `phylo` inside the formula); brms and
metafor offer equivalent fits via package-specific syntax. The next step
(§5) adds the location-scale extension — modelling $`\tau^2`$ itself as
a function of the moderator.

## 5. Location-scale meta-analysis

*(Scaffold; full coverage lands in v0.22.2.)*

When moderators predict heterogeneity, fit the variance side:

``` math
y_k \sim \mathcal{N}(\mu(x_k), v_k + \tau^2(x_k)),
\quad
\log \tau(x_k) = \gamma_0 + \gamma_1 x_k.
```

The deep Face is
`drmTMB::drmTMB(drm_formula(yi ~ x, sigma ~ x + offset(0.5*log(vi))), family = gaussian())`.
The `offset(0.5*log(vi))` term makes the σ-submodel additive on the
known sampling variances —
`glmmTMB::glmmTMB(..., dispformula = ~ x, weights = 1/vi)` is an
equivalent Face.

## 6. Reading biologically

*(Will land in v0.22.3, after all three flavors’ deep widgets ship.)*

Three readings the article will tie together:

- **Heterogeneity τ² vs sampling v_k**: τ² is “real” disagreement among
  studies; v_k is just imprecision.
- **Phylogenetic structure σ_p²A**: when most heterogeneity sits on the
  phylogeny, related species’ effects co-vary even after $`v_k`$ is
  accounted for. Read as: “the trait has a phylogenetic signal in its
  effect size.”
- **Moderator-driven τ²(x)**: scale-regression coefficients γ are read
  on the log-SD scale, exponentiated to multiplicative scale.

## 7. References

- Borenstein, M., Hedges, L. V., Higgins, J. P. T., & Rothstein, H. R.
  (2009). *Introduction to Meta-Analysis*. Wiley.
- Cinar, O., Nakagawa, S., & Viechtbauer, W. (2022). Phylogenetic
  multilevel meta-analysis: a simulation study on the importance of
  modelling the phylogeny. *Methods in Ecology and Evolution* 13(2):
  383-395.
- Colditz, G. A., et al. (1994). Efficacy of BCG vaccine in the
  prevention of tuberculosis: meta-analysis of the published literature.
  *JAMA* 271: 698-702.
- Mizuno, A., et al. (2026). Unified phylogenetic + spatial multilevel
  meta-analysis. *Research Synthesis Methods*, in press.
- Nakagawa, S., & Santos, E. S. A. (2012). Methodological issues and
  advances in biological meta-analysis. *Evolutionary Ecology* 26:
  1253-1274.
- Viechtbauer, W. (2010). Conducting meta-analyses in R with the metafor
  package. *Journal of Statistical Software* 36(3): 1-48.
