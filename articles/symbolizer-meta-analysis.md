# Three flavors of meta-analysis: a cross-package tour

> *Meta-analysis pools study-level effects that each carry a known
> sampling variance. This article is for anyone running `metafor`,
> `brms`, or `MCMCglmm` meta-analyses; by the end you’ll be able to read
> how
> [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
> renders the three common flavors — random-effects, phylogenetic, and
> location-scale — side by side across the packages.*

## 1. Three flavors of meta-analysis

Meta-analysis pools K study-level effect sizes y_k, each with a
**known** sampling variance v_k, into a single summary. The same idea
can be tightened in three different directions; this article walks all
three side-by-side across three packages, so a reader can land on
whichever combination matches their toolkit.

**Flavor 1 — Traditional random-effects pooling.** Studies vary beyond
what sampling alone explains. The headline parameter is \tau^2, the
**between-study heterogeneity variance**:

y_k \mid \theta_k \sim \mathcal{N}(\theta_k, v_k), \qquad \theta_k \sim
\mathcal{N}(\mu, \tau^2), \qquad k = 1, \ldots, K.

A single \tau^2 describes how much “true” effect sizes scatter across
studies after sampling noise is accounted for. This is the textbook
random-effects model (Borenstein et al. 2009; Viechtbauer 2010).

**Flavor 2 — Phylogenetic meta-analysis.** When studies are on related
species, the between-study tier becomes structured by phylogeny. The
total between-species variance splits into a **phylogenetic** piece
(constrained by relatedness) and a **non-phylogenetic** piece:

\theta_k = \mu + u\_{p,k} + u\_{s,k}, \quad u_p \sim
\mathcal{N}(\mathbf{0}, \sigma_p^2 \mathbf{A}), \quad u_s \sim
\mathcal{N}(\mathbf{0}, \sigma_s^2 \mathbf{I}).

\mathbf{A} is the phylogenetic correlation matrix (Cinar et al. 2022;
Mizuno et al. 2026).

**Flavor 3 — Location-scale meta-analysis.** When moderators predict not
just the *mean* effect but also the *heterogeneity*, the scale parameter
itself becomes a regression:

y_k \sim \mathcal{N}(\mu_k, v_k + \tau_k^2), \quad \mu_k = \beta_0 +
\beta_1 x_k, \quad \log \tau_k = \gamma_0 + \gamma_1 x_k.

The biological question shifts: *which moderators predict how variable
study effects are?* — separate from the mean.

**Three packages, one math.** The same model can be fit in `metafor`,
`glmmTMB`, `drmTMB`, `brms`, or `MCMCglmm`. Each section below picks one
**deep Face** (the package whose interface most cleanly expresses that
flavor) and two **light Faces** (showing the cross-package equivalence
so a reader’s existing fluency carries over).

**Takeaway.** Three flavors, one statistical motivation: separate the
sampling variance v_k (known per study) from the heterogeneity \tau^2
(estimated). Phylogenetic and location-scale flavors *structure* that
heterogeneity further.

## 2. The data: BCG vaccine efficacy trials

We use `dat.bcg` from `metafor` (Colditz et al. 1994): thirteen
randomised trials of the BCG vaccine against tuberculosis, with
treatment / control case counts per trial. The summary effect is the
**log risk ratio**:

y_k = \log\\\left(\frac{a_k / (a_k + b_k)}{c_k / (c_k + d_k)}\right),
\qquad v_k = \frac{1}{a_k} - \frac{1}{a_k + b_k} + \frac{1}{c_k} -
\frac{1}{c_k + d_k}.

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

Thirteen trials; effect sizes range from strong protection (y_k \< 0) to
no effect (y_k \approx 0). The sampling variances v_k are **known**
(computed from the trial counts) and differ across trials — large trials
have small v_k, small trials have large v_k. *Any* meta-analysis must
respect that.

**Takeaway.** Same effect-size metric (y_k = log RR), same known
sampling variance metric (v_k). One dataset reused across the three
flavors below.

## 3. Traditional pooling

The simplest flavor. Each trial gives y_k with known v_k; we pool to
estimate a single mean \mu and the between-study heterogeneity \tau^2.

### 3.1 The model in symbols

y_k \mid \theta_k \sim \mathcal{N}(\theta_k, v_k), \qquad \theta_k \sim
\mathcal{N}(\mu, \tau^2), \qquad k = 1, \ldots, 13.

The marginal form (integrating out \theta_k) is the more commonly fit
one:

y_k \sim \mathcal{N}(\mu, v_k + \tau^2), \qquad \mathrm{Cov}(y_k,
y\_{k'}) = 0 \text{ for } k \ne k'.

**Two parameters of interest**: \mu (the average log RR) and \tau^2 (how
much trials disagree beyond sampling noise).

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
deviation \hat\tau \approx 0.56 on the log RR scale — substantial
heterogeneity. I^2 = 92\\ confirms: of total variation, 92% is
heterogeneity not sampling noise.

``` r

sym_metafor <- symbolize(fit_metafor)
equations(sym_metafor)
```

\begin{aligned} y_i \mid \theta_i \sim \mathrm{Normal}(\theta_i,\\ v_i),
\quad v_i \text{ known} \\ \mu_i = \beta\_{0} + u\_{study(i)} \\
u\_{study} \sim \mathcal{N}(0,\\ \sigma\_{study}^2) \end{aligned}

``` r

assumption_table(sym_metafor)
```

| assumption | expression | biological meaning | status |
|:---|:---|:---|:---|
| conditional_distribution | y_i \mid \theta_i \sim \mathrm{Normal}(\theta_i,\\ v_i) | Each observed effect size is normally distributed around its true effect with KNOWN sampling variance | explicit |
| known_sampling_variance | v_i \text{ is known (not estimated)} | Sampling variances v_i come from each primary study (or from escalc()); they are inputs, not parameters | your responsibility |
| linear_predictor | \theta_i = \beta_0 + \sum_k \beta_k X\_{ki} + u_i | True effects are a linear combination of moderators plus a study-level random effect | explicit |
| random_effects_distribution | u_i \sim \mathrm{Normal}(0,\\ \tau^2) | The between-study true effects vary around the grand mean with variance \tau^2 | explicit |
| inverse_variance_weights | w_i = 1 / (v_i + \tau^2) | Each study is weighted by the inverse of (sampling variance + heterogeneity) | explicit |
| no_publication_bias | — | The included effect sizes are not preferentially the larger / significant ones; if they are, \tau^2 and the fixed-effect coefficients are biased | your responsibility |
| correct_effect_metric | — | The metric (log RR, log OR, SMD, Fisher-z r, …) is appropriate for the outcome and is calculated consistently across studies | your responsibility |
| no_missing_at_random | — | Studies are not missing in a way that depends on their unobserved true effect | your responsibility |

**Coefficient reading on μ.** \hat\mu = -0.71 on the log RR scale is
\exp(-0.71) \approx 0.49 on the response scale — vaccinated children
have about half the TB rate of unvaccinated children, averaged across
trials, with substantial trial-to-trial variation.

### 3.3 Face 2 — `glmmTMB` (light)

`glmmTMB` fits the same math via a random-intercept model with a
per-observation weight that pins the residual variance to v_k:

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

The bridge: `dispformula = ~0` fixes the Gaussian dispersion and
`weights = 1/vi` make each observation’s residual variance track v_k, so
the random-intercept variance plays the role of \hat\tau^2. The two land
close but not identical — glmmTMB’s hierarchical fit gives \hat\tau^2
\approx 0.44 against metafor’s marginal REML estimate of 0.31 (the
values printed above). With one effect per trial the random-intercept
and residual tiers are separated only by the weights, so the
hierarchical (glmmTMB) and marginal (metafor) parameterizations need not
converge on the same \hat\tau^2; metafor’s
[`rma()`](https://wviechtb.github.io/metafor/reference/rma.uni.html)
remains the canonical interface for traditional pooling.

*Note:* `glmmTMB::propto(…, V)` is **not** a meta-analytic surface — it
estimates a *free scalar* multiplying a known covariance (the
phylogenetic / structured-covariance pattern; see
[`vignette("symbolizer-structural-dependence")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-structural-dependence.md)).
The meta-analytic bridge here is `weights = 1/v_k` with
`dispformula = ~ 0`, as above.

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
      round(sigma(fit_drm)[1]^2, 3),
      "\n")
} else {
  cat("drmTMB not installed; skipping Face 3.\n")
}
#> drmTMB residual sigma^2: 0.25
```

drmTMB without `sigma ~ x` or a random intercept does **not** separate
sampling from heterogeneity — the residual variance absorbs both. The
useful drmTMB Face is in §5 (location-scale), where the
`sigma ~ moderator + offset(0.5 * log(vi))` syntax models heterogeneity
explicitly as a function of moderators while still respecting the known
sampling variances v_k.

### 3.5 Cross-package summary

| Package | Call | Captures \tau^2 as |
|----|----|----|
| `metafor` | `rma(yi, vi, data = dat)` | `fit$tau2` directly. |
| `glmmTMB` | glmmTMB(yi ~ 1 + (1 \| study), weights = 1/vi, dispformula = ~0) | `VarCorr(fit)$cond$study[1]`. |
| `drmTMB` | `drmTMB(drm_formula(yi ~ 1), weights = 1/vi)` | Residual \sigma\_\varepsilon^2 (no separate \tau^2 without a random intercept). |
| `brms` | brm(yi \| se(sqrt(vi)) ~ 1 + (1 \| study)) | Random-intercept SD posterior. |
| `MCMCglmm` | `MCMCglmm(yi ~ 1, random = ~ study, mev = vi)` | `VCV[,"study"]` posterior. |

The math is one model; the syntax differs by package. The bridge columns
in `formula_bridge(sym_metafor)` summarise the rest.

**Takeaway.** Traditional pooling separates known sampling variance v_k
from estimated heterogeneity \tau^2. metafor’s
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
a phylogenetic piece (constrained by the phylogeny via \mathbf{A}) and a
non-phylogenetic study tier.

### 4.1 The model in symbols

For each effect kt in study k on species s(k):

y\_{kt} = \beta_0 + \beta_1\\ x\_{kt} + u\_{p,\\s(k)} +
u\_{\text{study},\\k} + \epsilon\_{kt}

with

u\_{p,\\s} \sim \mathcal{N}(\mathbf{0},\\ \sigma_p^2\\ \mathbf{A}),
\quad u\_{\text{study},\\k} \sim \mathcal{N}(0,\\
\sigma\_{\text{study}}^2), \quad \epsilon\_{kt} \sim \mathcal{N}(0,\\
v\_{kt}).

The known sampling variance v\_{kt} is fixed per effect (computed from
the original study’s sample size). The marginal variance of one effect
is

\mathrm{Var}(y\_{kt}) = v\_{kt} + \sigma\_{\text{study}}^2 +
\sigma_p^2\\ \mathbf{A}\_{s(k),\\s(k)}.

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

### 4.3 Face 1 — `metafor::rma.mv` (deep dive)

`metafor` was built for meta-analysis and converges cleanly on this
two-tier model: `V = Var_dARR` carries the known per-effect sampling
variances, `random = list(~ 1 | phylogeny, ~ 1 | study_ID)` declares the
two random tiers, and `R = list(phylogeny = A)` attaches the
phylogenetic correlation \mathbf{A}.

``` r

library(metafor)
library(ape)
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

The two `$sigma2` rows are, in order, the phylogenetic tier \sigma_p^2
(\approx 0.003) and the study tier \sigma\_{\text{study}}^2 (\approx
0.036). On the Pottier thermal subset the **study-level variance
dominates the phylogenetic variance by an order of magnitude** — most
heterogeneity in dARR sits between studies rather than along the
phylogeny. (Heritability reading: H^2 = \sigma_p^2 / (\sigma_p^2 +
\sigma\_{\text{study}}^2) \approx 0.07.)

``` r

sym_phylo <- symbolize(
  fit_metafor_phylo,
  context = "phylogenetic multilevel meta-analysis"
)
```

#### Three views — phylogenetic multilevel

[Skip three-views widget](#sym-phylomultilevel-1781369777-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

Species are not independent observations. Closely related species tend
to have similar trait values because of shared evolutionary history; the
phylogenetic correlation matrix \mathbf{A} encodes those expected
similarities (cell A\_{ij} = fraction of shared branch length between
species i and j). The phylogenetic SD \sigma_p measures how much
across-species variation remains after fixed-effect predictors are
accounted for.

\begin{aligned} y_i \mid \theta_i & \sim \mathrm{Normal}(\theta_i,\\
v_i), \quad v_i \text{ known} \\ \mu_i & = \beta\_{0} + \beta\_{1} \\
\[habitat = \mathrm{terrestrial}\] + u\_{phylogeny(i)} +
u\_{\mathrm{study\\ID}(i)} \\ \mathbf{u}\_{phylogeny} & \sim
\mathcal{N}(\mathbf{0},\\ \sigma\_{phylogeny}^2 \mathbf{A}) \\
u\_{\mathrm{study\\ID}} & \sim \mathcal{N}(0,\\
\sigma\_{\mathrm{study\\ID}}^2) \end{aligned}

where:

- y — response variable  \mathbb{R}^{164}
- \mathrm{habitat}\_i — factor (aquatic \[reference\], terrestrial)
   column of X (length 164)
- \mu_i — conditional mu of yi  \mathbb{R}^{164}
- \sigma — residual heterogeneity SD (tau) of yi  scalar
- \beta\_{0}, \beta\_{1} — mu submodel coefficients  \mathbb{R}^{2}
- u\_{phylogeny(i)} — random intercept by phylogeny  scalar;
  \mathbb{R}^{35} in matrix form
- \sigma\_{phylogeny} — between-phylogeny standard deviation  scalar
- u\_{\mathrm{study\\ID}(i)} — random intercept by study_ID  scalar;
  \mathbb{R}^{39} in matrix form
- \sigma\_{\mathrm{study\\ID}} — between-study_ID standard deviation
   scalar
- \mathbf{A} — phylogenetic correlation matrix on phylogeny, attached
  via R = list(phylogeny = A): Sigma = sigma_p^2 \* A (tips-only k x k
  representation)  \mathbb{R}^{35 \times 35}

**Where does the variation live?** Where the variation lives – each row
is one variance component (shown as a share of the total when a single
total variance is defined).

- phylogeny \[sigma^2_phylogeny\]: variance = 0.00274
- study_ID \[sigma^2_study_ID\]: variance = 0.0355
- sampling \[mean(v_i)\]: variance = 0.111

**ICC:** ICC not available on this scale yet. (more than one
random-effect term, so a single-number ICC is not defined – read the
full variance partition instead.)

Point estimates only; uncertainty not shown.

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Species are not independent observations. Closely related species tend
to have similar trait values because of shared evolutionary history; the
phylogenetic correlation matrix \mathbf{A} encodes those expected
similarities (cell A\_{ij} = fraction of shared branch length between
species i and j). The phylogenetic SD \sigma_p measures how much
across-species variation remains after fixed-effect predictors are
accounted for.

\begin{aligned} \mathbf{y} \mid \boldsymbol{\theta},\\ V & \sim
\mathcal{N}(\boldsymbol{\theta},\\ V),\quad V \text{ known} \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} +
\mathbf{u}\_{phylogeny} + \mathbf{u}\_{\mathrm{study\\ID}} \\
\mathbf{u}\_{phylogeny} & \sim \mathcal{N}(\mathbf{0},\\
\sigma\_{phylogeny}^2 \mathbf{A}\_{35 \times 35}) \\
\mathbf{u}\_{\mathrm{study\\ID}} & \sim \mathcal{N}(\mathbf{0},\\
\sigma\_{\mathrm{study\\ID}}^2 \mathbf{I}\_{39}) \end{aligned}

where:

- \mathbf{y} — response variable  \mathbb{R}^{164}
- \boldsymbol{\mu} — conditional mu of yi  \mathbb{R}^{164}
- \boldsymbol{\sigma} — residual heterogeneity SD (tau) of yi  scalar
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{2}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{164 \times 2}
- \mathbf{u}\_{phylogeny} — random intercept by phylogeny  scalar;
  \mathbb{R}^{35} in matrix form
- \sigma\_{phylogeny} — between-phylogeny standard deviation  scalar
- \mathbf{u}\_{\mathrm{study\\ID}} — random intercept by study_ID
   scalar; \mathbb{R}^{39} in matrix form
- \sigma\_{\mathrm{study\\ID}} — between-study_ID standard deviation
   scalar
- \mathbf{A} — phylogenetic correlation matrix on phylogeny, attached
  via R = list(phylogeny = A): Sigma = sigma_p^2 \* A (tips-only k x k
  representation)  \mathbb{R}^{35 \times 35}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 164.

Species are not independent observations. Closely related species tend
to have similar trait values because of shared evolutionary history; the
phylogenetic correlation matrix \mathbf{A} encodes those expected
similarities (cell A\_{ij} = fraction of shared branch length between
species i and j). The phylogenetic SD \sigma_p measures how much
across-species variation remains after fixed-effect predictors are
accounted for.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

*This view shows the actual numbers flowing through the fit — the
response, the design matrix, the coefficients, and the fitted values.
For this model the per-observation design matrix was not captured when
it was symbolized, so only the response is available here. The **Index**
and **Matrix** tabs above show the full structure of the fit.*

Marginal covariance of the response is the sum of one term per
random-effect group:

\underbrace{\mathrm{Cov}(\mathbf{y})}\_{\textstyle\\n \times n,\\ n =
164\\} \\=\\ \underbrace{\sigma\_{phylogeny}^2\\
\mathbf{Z}\_{phylogeny}\mathbf{Z}\_{phylogeny}^{\\\top}}\_{\textstyle\\\text{phylogeny
tier}\\} \\+\\ \underbrace{\sigma\_{\mathrm{study\\ID}}^2\\
\mathbf{Z}\_{study\\ID}\mathbf{Z}\_{study\\ID}^{\\\top}}\_{\textstyle\\\text{study\\ID
tier}\\}

Tab 1 carries the index-form equation and the variance-component panel
showing the two estimated tiers (\sigma\_{\text{study}}^2 and
\sigma_p^2\\\mathbf{A}) alongside the known sampling tier v\_{kt}; Tab 2
carries the matrix form. (The “with your numbers” tab falls back to a
note for `rma.mv` —
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
does not yet expand metafor’s design matrix into per-row arrays — so the
structure lives on Tabs 1–2.)

**Reading the widget’s notation.** `symbolizer` names each random tier
by its *data column*, so the widget writes \sigma\_{\text{phylogeny}}
for the phylogenetic SD that §4.1 called \sigma_p, and
\sigma\_{\text{study\\ID}} for \sigma\_{\text{study}}, and it indexes
every quantity by the effect-size row i rather than by the (k, s(k))
effect-within-species pairing used in §4.1. The two notations describe
the same two tiers.

### 4.4 Face 2 — `brms` (light, with `se(sqrt(vi))` + `gr(., cov = A)`)

The same math in brms’s idiom. Note that
[`se()`](https://wviechtb.github.io/metafor/reference/se.html) is parsed
by brms internally — you write it *unqualified* inside
[`bf()`](https://itchyshin.github.io/drmTMB/reference/drm_formula.html),
not as
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

### 4.5 Face 3 — `drmTMB` (the idiom, caveated)

drmTMB expresses the same two-tier model as a single formula with two
markers:
[`meta_V()`](https://itchyshin.github.io/drmTMB/reference/meta_V.html)
for the known sampling variances (replacing brms’s response-side
`se(sqrt(vi))`) and
[`phylo()`](https://itchyshin.github.io/drmTMB/reference/phylo.html) for
the phylogenetic tier (replacing brms’s `gr(., cov = A)`). One gotcha:
drmTMB’s parser does not accept namespace-qualified names inside the
formula, so bind the helpers to local names first.

``` r

library(drmTMB)
# drmTMB requires unqualified names INSIDE the formula -- bind locally.
bf <- drmTMB::drm_formula; meta_V <- drmTMB::meta_V; phylo <- drmTMB::phylo

fit_drm_phylo <- drmTMB::drmTMB(
  bf(dARR ~ 1 + habitat +
          meta_V(V = Var_dARR) +
          phylo(1 | phylogeny, tree = tree) +
          (1 | study_ID)),
  family = stats::gaussian(),
  data   = dat
)
```

**Caveat:** at the time of writing this
`meta_V() + phylo() + (1 | study)` combination does **not** converge for
drmTMB — it returns `pdHess = FALSE` and collapses the two estimated
tiers toward zero (the same numerical fragility documented in §5.4,
reported upstream as
[itchyshin/drmTMB#417](https://github.com/itchyshin/drmTMB/issues/417)).
We therefore lead with
[`metafor::rma.mv`](https://wviechtb.github.io/metafor/reference/rma.mv.html)
(§4.3) for the converged decomposition; the drmTMB idiom is shown here
for syntax reference.

**Takeaway.** Three packages, one math. metafor gives the converged
two-tier decomposition (study variance dominates the phylogenetic
variance here); brms gives the equivalent Bayesian fit; drmTMB offers
the most compact idiom (`meta_V` + `phylo` in one formula) but does not
yet converge on this model (#417). The next step (§5) adds the
location-scale extension — modelling \tau^2 itself as a function of the
moderator.

## 5. Location-scale meta-analysis

The first two flavors modelled the *mean* effect and (in §4) split the
between-study tier by phylogeny. The location-scale flavor asks a
different question: **does a moderator predict the *heterogeneity*
itself?** — are aquatic species’ thermal-acclimation effects more
variable than terrestrial ones, separately from any difference in their
average?

### 5.1 The model in symbols

Both the mean and the heterogeneity SD become regressions:

y_k \sim \mathcal{N}\\\big(\mu(x_k),\\ v_k + \tau^2(x_k)\big), \qquad
\mu(x_k) = \beta_0 + \beta_1 x_k, \qquad \log \tau(x_k) = \gamma_0 +
\gamma_1 x_k.

v_k is still the known per-effect sampling variance; \tau(x_k) is the
*estimated* heterogeneity SD, now a function of the moderator x_k
(habitat). A non-zero \gamma_1 means the spread of true effects differs
between habitats.

### 5.2 Face 1 — `glmmTMB` (deep dive)

glmmTMB expresses location-scale meta-analysis cleanly: the mean is the
usual formula, the **dispersion formula** `dispformula = ~ habitat` is
the log-SD scale model, and `weights = 1/v_k` pins the known sampling
variances (as in §3.3).

``` r

library(glmmTMB)
dat$habitat <- factor(dat$habitat)
fit_ls <- glmmTMB(
  dARR ~ 1 + habitat,
  dispformula = ~ 1 + habitat,   # log tau(x) = gamma_0 + gamma_1 * habitat
  weights     = 1 / Var_dARR,    # pin the known sampling variances v_k
  data        = dat
)
sym_ls <- symbolize(fit_ls, context = "location-scale meta-analysis")
```

#### Three views — location-scale

[Skip three-views widget](#sym-locscalemeta-1781369777-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

Each observation is normally distributed around a mean that may shift
with the predictors, and a residual SD that may also shift with its own
predictors – so both the centre and the spread of the response are
modeled.

**Coefficient reading.** On the response scale, \hat\beta is the
additive change in the mean of the response for a one-unit increase in
the predictor (identity link – no back-transformation needed).

\begin{aligned} \mathrm{dARR}\_i \mid \mu_i,\\ \sigma_i & \sim
\mathrm{Normal}(\mu_i,\\ \sigma_i^2) \\ \mu_i & = \beta\_{0} +
\beta\_{1} \\ \[habitat = \mathrm{terrestrial}\] \\ \log(\sigma_i) & =
\gamma\_{0} + \gamma\_{1} \\ \[habitat = \mathrm{terrestrial}\]
\end{aligned}

where:

- \mathrm{dARR}\_i — response variable  \mathbb{R}^{164}
- \mathrm{habitat}\_i — factor (aquatic \[reference\], terrestrial)
   column of X (length 164)
- \mu_i — conditional mu of dARR  \mathbb{R}^{164}
- \sigma_i — residual standard deviation  \mathbb{R}^{164}
- \beta\_{0}, \beta\_{1} — mu submodel coefficients  \mathbb{R}^{2}
- \gamma\_{0}, \gamma\_{1} — sigma submodel coefficients  \mathbb{R}^{2}

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Each observation is normally distributed around a mean that may shift
with the predictors, and a residual SD that may also shift with its own
predictors – so both the centre and the spread of the response are
modeled.

\begin{aligned} \mathbf{darr} \mid \boldsymbol{\mu},\\
\boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\\
\mathrm{diag}(\boldsymbol{\sigma}^2)) \\ \boldsymbol{\mu} & = \mathbf{X}
\boldsymbol{\beta} \\ \log(\boldsymbol{\sigma}) & = \mathbf{X}\_{\sigma}
\boldsymbol{\gamma} \end{aligned}

where:

- \mathbf{darr} — response variable  \mathbb{R}^{164}
- \boldsymbol{\mu} — conditional mu of dARR  \mathbb{R}^{164}
- \boldsymbol{\sigma} — residual standard deviation  \mathbb{R}^{164}
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{2}
- \boldsymbol{\gamma} — sigma submodel coefficients  \mathbb{R}^{2}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{164 \times 2}
- \mathbf{X}\_{\sigma} — sigma submodel design matrix  \mathbb{R}^{164
  \times 2}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 164.

Each observation is normally distributed around a mean that may shift
with the predictors, and a residual SD that may also shift with its own
predictors – so both the centre and the spread of the response are
modeled.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

For observation *i* = 1 of your data:

\begin{aligned} darr\_{1} &= \hat\beta\_{0} +
\hat\beta\_{1}\\\mathrm{habitatterrestrial}\_{1} + \hat\varepsilon\_{1}
&\quad(\text{response equation, one row of the model}) \\ \hat\mu\_{1}
&= 0.183 - 0.128 \times 1 \approx 0.0549 &\quad(\text{predicted mean} =
\text{linear predictor}) \\ darr\_{1} &=
\underbrace{0.0549}\_{\textstyle\\\hat\mu\_{1}\\\text{(predicted)}\\}
\\+\\
\underbrace{(-0.0429)}\_{\textstyle\\\hat\varepsilon\_{1}\\\text{(residual)}\\}
&\quad(\text{observed} = \text{predicted mean} + \text{residual})
\end{aligned}

Stacking the same response equation for all *n* = 164 observations:

\underbrace{\begin{bmatrix} 0.012 \\ 0.048 \\ 0.0623 \\ 0.108 \\ 0.189
\\ \vdots \\ 0.632 \\ 0.59
\end{bmatrix}}\_{\textstyle\\\mathbf{darr}\_{\\164 \times
1}\\\text{(observed)}\\} \\=\\ \underbrace{\begin{bmatrix} 1 & 1 \\ 1 &
1 \\ 1 & 1 \\ 1 & 1 \\ 1 & 1 \\ \vdots & \vdots \\ 1 & 0 \\ 1 & 0
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\164 \times 2}\\}\\
\underbrace{\begin{bmatrix} 0.183 \\ -0.128
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\2 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} -0.0429 \\
-0.00691 \\ 0.00743 \\ 0.0531 \\ 0.134 \\ \vdots \\ 0.449 \\ 0.407
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}\_{\\164
\times 1}\\\text{(residual)}\\}

**Left**: observed vector \mathbf{darr}. **Middle**: the prediction
\mathbf{X}\hat{\boldsymbol{\beta}} = \hat{\boldsymbol{\mu}}. **Right**:
the residual vector \hat{\boldsymbol{\varepsilon}} = \mathbf{darr} -
\hat{\boldsymbol{\mu}}. Every row of this matrix equation is one of the
response-equation rows from the worked row above.

The widget carries two submodels: the **mean** (\mu, identity link) and
the **heterogeneity SD** (\sigma \equiv \tau, log link). The scale
coefficient \hat\gamma\_{\text{terrestrial}} \approx -0.84 reads on the
log-SD scale: terrestrial effects are about \exp(-0.84) \approx 0.43
times as heterogeneous as aquatic ones — the thermal-acclimation
response is roughly half as variable on land as in water, beyond any
difference in the mean.

### 5.3 The variance-vs-SD parameterization gap

Packages disagree about *what* they put the moderator on — the variance
\tau^2 or the SD \tau — and the coefficient symbol changes with it:

| Package | Quantity modelled | Link | Coefficient |
|----|----|----|----|
| `metafor::rma(scale = ~ z)` | \tau^2 (variance) | \log(\tau^2_k) = \alpha_0 + \alpha_1 z_k | \alpha |
| `glmmTMB(dispformula = ~ z)` | \tau (SD) | \log(\tau_k) = \gamma_0 + \gamma_1 z_k | \gamma |
| `drmTMB(sigma ~ z)` | \sigma \equiv \tau (SD) | \log(\sigma_k) = \gamma_0 + \gamma_1 z_k | \gamma |

The two conventions are mathematically equivalent. Because \log(\tau^2)
= 2\log(\tau) + \text{const}, the slope on the variance scale is
**twice** the slope on the SD scale:

\alpha_k \\\approx\\ 2\\\gamma_k.

So a `metafor` location-scale slope of \alpha = 0.4 is the same
biological signal as a `glmmTMB` / `drmTMB` slope of \gamma \approx 0.2:
variance doubles ≈ SD increases by \sqrt{2}. `symbolizer` renders each
faithfully — look for the coefficient symbol (\alpha vs \gamma) and the
\tau^2-vs-\tau distinction in the LaTeX to know which convention is in
play.

### 5.4 Face 2 — `drmTMB` (light, with a caveat)

drmTMB’s location-scale idiom is
[`meta_V()`](https://itchyshin.github.io/drmTMB/reference/meta_V.html)
for the known sampling variances plus a `sigma ~ habitat` scale
submodel:

``` r

library(drmTMB)
bf <- drmTMB::drm_formula; meta_V <- drmTMB::meta_V
fit_ls_drm <- drmTMB::drmTMB(
  bf(dARR ~ 1 + habitat + meta_V(V = Var_dARR), sigma ~ 1 + habitat),
  family = stats::gaussian(), data = dat
)
drmTMB::fixef(fit_ls_drm, "sigma")   # gamma on the log-SD scale
#>        (Intercept) habitatterrestrial 
#>         -0.9566351         -1.1647041
```

drmTMB’s scale submodel gives the **same qualitative reading** as
glmmTMB — a negative habitat slope, so terrestrial effects are less
heterogeneous — but at a different magnitude
(\hat\gamma\_{\text{terrestrial}} \approx -1.16 here against glmmTMB’s
-0.84): the two packages decompose the residual heterogeneity slightly
differently. **Caveat:** the `meta_V() + sigma`-submodel combination is
numerically delicate — drmTMB sometimes flags `pdHess = FALSE` for it,
so its standard errors are not always trustworthy. We lead with glmmTMB
for that reason and reported the convergence issue upstream
([itchyshin/drmTMB#417](https://github.com/itchyshin/drmTMB/issues/417)).
drmTMB also does **not** accept
[`offset()`](https://rdrr.io/r/stats/offset.html) inside the `sigma`
formula;
[`meta_V()`](https://itchyshin.github.io/drmTMB/reference/meta_V.html)
is its mechanism for the known variances.

### 5.5 Takeaway

Location-scale meta-analysis turns the heterogeneity itself into a
regression. The biological payoff: you can ask *which conditions make
effects more variable*, not just *what the average effect is*. glmmTMB
is the cleanest converging Face today; metafor (`scale = ~ z`) models
the same signal on the variance scale (\alpha \approx 2\gamma).

## 6. Reading biologically

The three flavors share one statistical spine — separate the known
sampling variance v_k from the estimated heterogeneity — but each
answers a different biological question. Tying the article’s fitted
numbers together:

- **Heterogeneity \tau^2 vs sampling v_k (§3).** \hat\tau^2 \approx 0.31
  (I^2 \approx 92\\) on the BCG trials means the *true* protective
  effect genuinely differs from trial to trial — only about 8% of the
  spread is sampling imprecision. A large \tau^2 is a finding (“the
  effect is context-dependent”), not a nuisance.
- **Phylogenetic structure \sigma_p^2\mathbf{A} (§4).** On the thermal
  data the study-level variance dominates the phylogenetic variance, so
  the heritability reading H^2 = \sigma_p^2 / (\sigma_p^2 +
  \sigma\_{\text{study}}^2) is small: most disagreement in the
  acclimation response sits *between studies*, not *along the phylogeny*
  — related species are not especially alike in their effect sizes here.
- **Moderator-driven \tau(x) (§5).** The scale slope
  \hat\gamma\_{\text{terrestrial}} \approx -0.84 exponentiates to
  \approx 0.43: terrestrial thermal-acclimation effects are about half
  as variable as aquatic ones. Read \gamma on the log-SD scale and
  exponentiate; on the variance scale the same signal is \alpha \approx
  2\gamma (§5.3).

In every case `symbolizer`’s job is the same: surface *which* variance
is known and which is estimated, *what scale* each coefficient lives on,
and *how* to read it back on the biological scale.

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
