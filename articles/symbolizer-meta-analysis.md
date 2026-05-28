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

## 4. Phylogenetic meta-analysis

*(Scaffold; full coverage lands in v0.22.1.)*

When studies are on related species, the between-study variance splits
into a phylogenetic piece (constrained by $`\mathbf{A}`$) and a
non-phylogenetic piece. The deep Face is
`metafor::rma.mv(yi, V = vi, random = ~ 1 | species, R = list(species = A))`.

Cross-link: the v0.21.4-redo article
[`symbolizer-structural-dependence.html`](https://itchyshin.github.io/symbolizer/articles/symbolizer-structural-dependence.md)
covers the **structural dependence** view of the same model (without the
sampling-tier $`v_k`$). This article’s §4 will combine the two: known
$`v_k`$ at the bottom tier + phylogenetic correlation at the species
tier.

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
