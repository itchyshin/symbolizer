# Three faces of meta-analysis: metafor, glmmTMB, drmTMB

## The shared model

A meta-analysis is, structurally, a two-tier Normal model:

``` math
\begin{aligned}
y_i \mid \theta_i &\sim \mathcal{N}(\theta_i,\, v_i), \quad v_i \text{ known} \\
\theta_i &= \beta_0 + \sum_k \beta_k\, x_{ki} + u_i \\
u_i &\sim \mathcal{N}(0,\, \tau^2)
\end{aligned}
```

The observed effect size $`y_i`$ from study $`i`$ is a noisy estimate of
a true effect $`\theta_i`$, with **known** sampling variance $`v_i`$ (an
input, not a parameter). The true effects vary around a meta-analytic
mean with between-study heterogeneity variance $`\tau^2`$. Moderators
$`x_{ki}`$ explain part of the location; a separate scale model can
explain part of $`\tau^2`$ as well (the **location-scale** extension;
see Viechtbauer & López-López, 2022; Nakagawa et al., 2025).

What changes from package to package isn’t the model — it’s the syntax
used to construct it. `symbolizer` reads all three.

## Setup — a tiny simulated meta-analytic dataset

``` r

library(symbolizer)
library(metafor)
#> Loading required package: Matrix
#> 
#> Attaching package: 'Matrix'
#> The following object is masked from 'package:symbolizer':
#> 
#>     expand
#> Loading required package: metadat
#> Loading required package: numDeriv
#> 
#> Loading the 'metafor' package (version 5.0-1). For an
#> introduction to the package please type: help(metafor)
library(glmmTMB)

set.seed(1)
k_studies <- 10
k_per <- 3
study <- rep(seq_len(k_studies), times = k_per)
k <- length(study)
id <- seq_len(k)
# Sampling variances (known per effect size)
vi <- rbeta(k, 2, 20)
# Block-diagonal V with within-study correlation rho = 0.5
V <- matrix(0, k, k)
for (s in unique(study)) {
  idx <- which(study == s)
  for (i in idx) for (j in idx) {
    V[i, j] <- if (i == j) vi[i] else 0.5 * sqrt(vi[i] * vi[j])
  }
}
rownames(V) <- colnames(V) <- as.character(id)
# Simulate y_i around a true between-study mean
true_y <- 0 + rnorm(k_studies, 0, 0.5)[study]
y <- true_y + as.numeric(MASS::mvrnorm(1, rep(0, k), V))
dat <- data.frame(y = y, vi = vi, study = factor(study),
                  obs = factor(id), g = factor(1))
head(dat, 4)
#>            y         vi study obs g
#> 1 -0.1037070 0.05214863     1   1 1
#> 2  0.2746595 0.10619273     2   2 1
#> 3  0.1386369 0.04267655     3   3 1
#> 4  0.4370492 0.12001508     4   4 1
```

## Face 1 — metafor (the canonical interface)

``` r

fit_meta <- rma.mv(yi = y, V = V,
                   random = list(~ 1 | study, ~ 1 | obs),
                   data = dat)
sym_meta <- symbolize(fit_meta)
```

The symbolic surface:

``` r

equations(sym_meta, notation = "index")
```

``` math
\begin{aligned}
y_i \mid \theta_i \sim \mathrm{Normal}(\theta_i,\, v_i), \quad v_i \text{ known} \\
\mu_i = \beta_{0} + u_{study(i)} + u_{obs(i)} \\
u_{study} \sim \mathcal{N}(0,\, \sigma_{study}^2) \\
u_{obs} \sim \mathcal{N}(0,\, \sigma_{obs}^2)
\end{aligned}
```

``` r

sym_meta$variance_components
```

| parameter | group    | term          | sd_estimate | var_estimate |
|:----------|:---------|:--------------|:------------|:-------------|
| mu        | study    | sigma^2_study | 0.349       | 0.122        |
| mu        | obs      | sigma^2_obs   | 0.0596      | 0.00355      |
| mu        | sampling | mean(v_i)     | 0.316       | 0.0999       |

The model the package teaches: `meta_normal` family, two random-effect
tiers (study + observation), sampling variances `v_i` known.

## Face 2 — glmmTMB via `propto()` (phylogenetic / structured-covariance, NOT meta-analysis)

> **v0.20 correction.** v0.16 of this article claimed
> `propto(0 + obs | g, V)` was “structurally identical” to
> `metafor::rma.mv(..., V = V)`. **That was wrong.** Empirical
> verification (k = 30, seed 1, see Fisher’s v0.20.0 audit in
> `NEWS.md`): metafor estimates β̂₀ = 0.357438 and τ̂² = 0.068911; the
> glmmTMB-propto fit on the same data estimates β̂₀ = 0.357024 and τ̂² =
> 0.071700, **with an additional free scalar σ̂²_propto = 0.942742** that
> propto inserts between Σ and V. The models differ in parameter count,
> standard errors, and log-likelihood. See §“What `propto` actually
> does” below for the corrected story.

### What `propto` actually does

`glmmTMB::propto(X, V)` parameterises

``` math
\boldsymbol{\Sigma}_{\text{propto}} \;=\; \sigma_{\text{propto}}^{2}\, V
```

with **σ²_propto estimated** as a free scalar. Combined with glmmTMB’s
default residual term (unless `dispformula = ~ 0` is passed), the full
conditional covariance is

``` math
\operatorname{Cov}(\mathbf{y}\mid \mathbf{u})
\;=\; \sigma_{\text{propto}}^{2}\,V \;+\; \sigma_{\text{res}}^{2}\,\mathbf{I},
```

i.e. **two** free scalars sitting on top of `V`, not zero. This is the
**phylogenetic / pedigree / known-correlation** pattern: you know the
*shape* of the covariance (the matrix `V`, or a phylogenetic correlation
matrix `C`), and the model estimates how big it is.

The corresponding metafor construction is

``` r

metafor::rma.mv(yi, V = 0 * diag(k),
                random = list(~ 1 | study, ~ 1 | obs),
                R = list(obs = V))
```

— i.e. `propto` mirrors metafor’s `R = list(...)` argument, **not** its
`V = V` argument. Fisher’s audit fitted both on the same
AR(1)-correlation data and they agree to five decimals.

### Why the package detects `propto` anyway

The `glmmTMB` extractor still detects covariance code 11 (the propto
block) and surfaces an info-level row in
[`warning_table()`](https://itchyshin.github.io/symbolizer/reference/warning_table.md).
The info-row text in v0.20+ names propto as a **structured-covariance /
phylogenetic** pattern, not meta-analysis:

``` r

fit_glmm <- glmmTMB(
  y ~ 1 + (1 | study) + propto(0 + obs | g, V),
  data = dat, REML = TRUE
)
#> Warning in finalizeTMB(TMBStruc, obj, fit, h, data.tmb.old): Model convergence
#> problem; non-positive-definite Hessian matrix. See vignette('troubleshooting')
#> Warning in finalizeTMB(TMBStruc, obj, fit, h, data.tmb.old): Model convergence
#> problem; false convergence (8). See vignette('troubleshooting'),
#> help('diagnose')
sym_glmm <- symbolize(fit_glmm)
#> Warning in sqrt(diag(vv)): NaNs produced
#> Warning in sqrt(diag(object$cov.fixed)): NaNs produced
#> Warning in sqrt(diag(object$cov.fixed)): NaNs produced
```

``` r

warning_table(sym_glmm)
```

| severity | message | context |
|:---|:---|:---|
| info | This fit uses propto() to attach a covariance proportional to a known matrix V on a random-effect block: Sigma = sigma^2 \* V, with sigma^2 estimated. That is the phylogenetic / pedigree / structured-covariance pattern, equivalent to metafor::rma.mv(V = 0, random = ~ 1 \| g, R = list(g = V)). It is NOT the meta-analytic fixed-V pattern: metafor::rma.mv(V = V, …) fixes Sigma = V exactly, with no scalar multiplier. glmmTMB also estimates an independent residual sigma_res unless dispformula = ~ 0 is passed – so the full conditional covariance under a propto fit is sigma^2_propto \* V + sigma^2_res \* I, two free scalars. The exact meta-analytic GLMM bridge requires glmmTMB’s planned equalto() block (Sigma = V, no multiplier), which is reserved but not yet implemented in glmmTMB \<= 1.1.11. References: Hadfield & Nakagawa 2010 (phylogenetic mixed models); Viechtbauer & López-López 2022 (location-scale meta-analysis); Nakagawa et al. 2025 (multilevel + phylo location-scale). |  |

``` r

equations(sym_glmm, notation = "index")
```

``` math
\begin{aligned}
y \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i = \beta_{0} + u_{study(i)} \\
u_{study} \sim \mathcal{N}(0,\, \sigma_{study}^2)
\end{aligned}
```

### What you’d need for an actual meta-analytic glmmTMB fit

The structural twin of `rma.mv(..., V = V)` would be

``` r

glmmTMB(y ~ 1 + (1 | study) + equalto(0 + obs | g, V),
        data = dat, dispformula = ~ 0)
```

where `equalto(X, V)` parameterises Σ = V exactly (no scalar
multiplier), and `dispformula = ~ 0` suppresses the residual term.
**`equalto` is reserved but not yet implemented in `glmmTMB` ≤ 1.1.11**
(`.valid_covstruct` shows codes 0–13; no equalto entry). Until glmmTMB
ships it, the GLMM-side meta-analytic bridge is incomplete; the honest
two routes today are metafor (Face 1) and drmTMB (Face 3 below).

## Face 3 — drmTMB location-scale (the distributional surface)

`drmTMB` has location-scale Gaussian as its core form. With known
sampling variances entered as $`\sigma_i^2 = v_i`$ (via an offset on the
log-scale formula), `drmTMB` fits a meta-analytic-flavoured model as a
distributional Gaussian. Symbolic output uses $`\log(\sigma_i)`$ on the
**SD scale** (the drmTMB convention), with $`\gamma_k`$ coefficients.

> **Caveat (v0.20).** Writing `sigma ~ 1 + offset(0.5 * log(vi))` does
> not pin $`\sigma_i^{2} = v_i`$ unless the intercept $`\gamma_0`$ is
> *also* constrained to 0 (e.g. via `map`). Without that constraint,
> drmTMB estimates $`\sigma_i = \exp(\hat{\gamma}_0) \sqrt{v_i}`$ —
> **proportional** to the sampling SE, not equal to it. The construction
> is genuinely useful (the proportionality constant captures over- or
> under-dispersion beyond the known sampling variance), but it is *not*
> the exact metafor fixed-V identity.

(Sketch only — a full drmTMB construction with known sigma offsets is
shown in
[`vignette("symbolizer-drmtmb")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-drmtmb.md)
and the drmTMB docs.)

## The variance / SD parameterization gap

Each package writes the scale model differently:

| Package | Quantity modelled | Link | Coefficient |
|----|----|----|----|
| `metafor::rma(scale = ~ z)` | $`\tau^2`$ (variance) | $`\log(\tau^2_i) = \alpha_0 + \alpha_1 z_i`$ | $`\alpha`$ |
| `brms::bf(sigma ~ z)` | $`\sigma`$ (SD) | $`\log(\sigma_i) = \gamma_0 + \gamma_1 z_i`$ | $`\gamma`$ |
| `glmmTMB(dispformula = ~ z)` | $`\sigma`$ (SD) | $`\log(\sigma_i) = \gamma_0 + \gamma_1 z_i`$ | $`\gamma`$ |
| `drmTMB(sigma ~ z)` | $`\sigma`$ (SD) | $`\log(\sigma_i) = \gamma_0 + \gamma_1 z_i`$ | $`\gamma`$ |

The two parameterizations are mathematically equivalent. Because
$`\log(\tau^2) = 2 \log(\tau) + \mathrm{const}`$, the slope on the
variance scale is twice the slope on the SD scale:

``` math
\alpha_k \;\approx\; 2 \cdot \gamma_k
```

(For the intercept the relationship is offset by $`\log 2`$ once.) So a
`metafor` location-scale slope of $`\alpha = 0.4`$ is the same
biological signal as a `brms` / `glmmTMB` / `drmTMB` location-scale
slope of $`\gamma \approx 0.2`$ — variance doubles ≈ SD increases by
$`\sqrt{2}`$.

`symbolizer` renders each faithfully in its own parameterization: look
for the coefficient symbol ($`\alpha`$ vs $`\gamma`$) and the
$`\tau^2`$-vs-$`\sigma`$ distinction in the LaTeX block to know which
convention is in play.

## When to use which

- **`metafor`** is the canonical interface for traditional
  meta-analysis. Rich diagnostics, well-documented effect-size
  computation
  ([`escalc()`](https://wviechtb.github.io/metafor/reference/escalc.html)),
  and a long literature on small-sample corrections.
- **`glmmTMB` with `propto()`** is **not** a meta-analytic surface in
  the strict sense (propto estimates a scalar multiplier on the known
  covariance; meta-analysis fixes the covariance to V exactly). It *is*
  the right glmmTMB surface for **phylogenetic / pedigree /
  structured-covariance** models, where you know the *shape* of the
  covariance but want to estimate its size. The meta-analytic identity Σ
  = V (without a scalar multiplier) waits on glmmTMB shipping its
  planned `equalto()` block.
- **`drmTMB`** lets you fit location-scale meta-analysis with moderators
  on heterogeneity directly, with the same syntax as any other
  location-scale model. This is the surface Nakagawa et al.
  2025. explore in depth for ecology and evolution.

`symbolizer` lets all three speak the same teachable language.

## References

- Viechtbauer, W., & López-López, J. A. (2022). Location-scale models
  for meta-analysis. *Research Synthesis Methods*, **13**(6), 697–715.
- Nakagawa, S., Mizuno, A., Morrison, K., Ricolfi, L., Williams, C.,
  Drobniak, S. M., Lagisz, M., & Yang, Y. (2025). Location-scale
  meta-analysis and meta-regression as a tool to capture large-scale
  changes in biological and methodological heterogeneity: A spotlight on
  heteroscedasticity. *Global Change Biology*, **31**, e70204.
- Williams, C. R. (2023). *Fitting meta-analysis with the glmmTMB R
  package: a worked tutorial.*
  <https://coraliewilliams.github.io/equalto_sim_study/webpage.html>
