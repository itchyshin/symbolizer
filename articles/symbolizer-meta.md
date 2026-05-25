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
#> 1 -0.2839669 0.05214863     1   1 1
#> 2 -0.6689495 0.10619273     2   2 1
#> 3  0.1386369 0.04267655     3   3 1
#> 4  0.6629762 0.12001508     4   4 1
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

cat(as_latex(sym_meta), "\n")
#> \begin{aligned}
#> y_i \mid \theta_i & \sim \mathrm{Normal}(\theta_i,\, v_i), \quad v_i \text{ known} \\
#> \mu_i & = \beta_{0} + u_{study(i)} + u_{obs(i)} \\
#> u_{study} & \sim \mathcal{N}(0,\, \sigma_{study}^2) \\
#> u_{obs} & \sim \mathcal{N}(0,\, \sigma_{obs}^2)
#> \end{aligned}
```

``` r

sym_meta$variance_components
#> # A tibble: 3 × 6
#>   parameter group    term          sd_estimate var_estimate kind             
#>   <chr>     <chr>    <chr>               <dbl>        <dbl> <chr>            
#> 1 mu        study    sigma^2_study      0.302       0.0910  heterogeneity    
#> 2 mu        obs      sigma^2_obs        0.0943      0.00890 heterogeneity    
#> 3 mu        sampling mean(v_i)          0.316       0.0999  sampling_variance
```

The model the package teaches: `meta_normal` family, two random-effect
tiers (study + observation), sampling variances `v_i` known.

## Face 2 — glmmTMB via `propto()` (the GLMM bridge)

The same model can be fit through `glmmTMB` by attaching the known `V`
matrix via `propto()`. Structurally identical; syntactically different.

``` r

fit_glmm <- glmmTMB(
  y ~ 1 + (1 | study) + propto(0 + obs | g, V),
  data = dat, REML = TRUE
)
sym_glmm <- symbolize(fit_glmm)
```

`symbolizer` detects the `propto()` block and adds an info-level warning
row:

``` r

warning_table(sym_glmm)
```

| severity | message | context |
|:---|:---|:---|
| info | This fit uses propto() (or equalto() in newer glmmTMB) to attach a known correlation / covariance matrix on a random-effect block. Structurally, that’s the meta-analytic / phylogenetic / pedigree-controlled pattern: sigma_residual is fixed (sampling-variance-known), and the (1 \| study) variance reads as the between-study heterogeneity tau^2. Compare with metafor::rma.mv(yi, V, random = list(~ 1 \| study, ~ 1 \| id), R = list(…)) or drmTMB’s location-scale form (Williams 2023; Viechtbauer & Lopez-Lopez 2022; Nakagawa et al. 2025). |  |

This is the bridge: `propto(0 + obs | g, V)` **fixes** the residual
covariance to the known `V`, which is exactly what `rma.mv(..., V = V)`
does in `metafor`. The `(1 | study)` term carries the between-study
heterogeneity $`\tau^2`$.

When this pattern is present:

| Conceptual quantity | metafor | glmmTMB |
|----|----|----|
| Known sampling-variance matrix | `V` argument | `propto(0 + obs | g, V)` block |
| Between-study heterogeneity $`\tau^2`$ | `sigma2[["study"]]` | `VarCorr(fit)$cond$study` |
| Moderator coefficients $`\beta_k`$ | `fit$beta` | `fixef(fit)$cond` |

``` r

cat(as_latex(sym_glmm), "\n")
#> \begin{aligned}
#> y \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
#> \mu_i & = \beta_{0} + u_{study(i)} \\
#> u_{study} & \sim \mathcal{N}(0,\, \sigma_{study}^2)
#> \end{aligned}
```

## Face 3 — drmTMB location-scale (the distributional surface)

`drmTMB` has location-scale Gaussian as its core form. With known
sampling variances entered as $`\sigma_i^2 = v_i`$ (via an offset on the
log-scale formula), `drmTMB` fits the meta-analytic model as a
distributional Gaussian. Symbolic output uses $`\log(\sigma_i)`$ on the
**SD scale** (the drmTMB convention), with $`\gamma_k`$ coefficients.

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
- **`glmmTMB` with `propto()`** brings meta-analysis into the GLMM
  ecosystem — letting you reuse the same modelling pipeline (model
  checking, prediction, marginal effects) you use for GLMMs in general.
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
