# Structural dependence: phylogenetic, animal-model, and spatial random effects

> *Phylogenetic, animal-model, and spatial random effects are the same
> model written three ways — only the matrix that encodes the dependence
> changes. This article is for biologists fitting any of those
> structures; by the end you’ll be able to see the shared grammar
> [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
> reads across `MCMCglmm`, `brms`, and `phylolm`, and how the dependence
> matrix is the one piece that differs.*

If you have ever written `(1 | species)` for an animal model,
`gr(species, cov = A)` in `brms`, or `s(x, y, bs = "gp")` for a spatial
process, you have been writing the **same model** three times — only the
matrix that encodes the dependence changes. This article is the first in
`symbolizer`’s **concept-axis series**; it teaches the
*dependence-structure* axis of GLMM grammar through one **deep-dive**
Face and two **light** Faces across three R packages: `MCMCglmm`,
`brms`, and `phylolm`. The scope is the **phylogenetic LMM** with
\sigma_e^2 estimated; the *meta-analytic* form (with v_i known sampling
variances) is covered in the companion article,
[`vignette("symbolizer-meta-analysis")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-meta-analysis.md).

## The shared grammar

A generalised linear mixed model writes

y_i \mid \mathbf b \\\sim\\ \mathcal D(\mu_i, \phi),\qquad g(\mu_i)
\\=\\ \mathbf x_i^\top \boldsymbol\beta + \mathbf z_i^\top \mathbf b,

with random effects

\mathbf b \\\sim\\ \mathcal N(\mathbf 0,\\ \sigma^2\\\mathbf M).

The standard textbook GLMM takes \mathbf M = \mathbf I — the random
effects are independent draws. Structural dependence is what you get
when \mathbf M \ne \mathbf I. Three named instantiations recur:

| Context | Symbol | What \mathbf M encodes |
|----|----|----|
| Phylogenetic | \mathbf A | Shared evolutionary history (tree → correlation) |
| Pedigree (animal model) | \mathbf A | Genetic relatedness (pedigree → correlation) |
| Spatial | \boldsymbol\Omega | Geographic proximity (distance + kernel) |

In abstract / cross-package teaching contexts (this article’s prose), we
write \mathbf M for the generic role. In a fitted model with a known
context
(e.g. [`drmTMB::phylo()`](https://itchyshin.github.io/drmTMB/reference/phylo.html)
calls), `symbolizer` chooses the domain-specific letter — \mathbf A for
phylogenetic / animal-model, \boldsymbol\Omega for spatial. The
symbol-dictionary description for \boldsymbol\Omega explicitly
disambiguates it from (a) Wishart precision matrices and (b) CAR / SAR
spatial weights matrices.

## Where the matrix comes from

For phylogenetic dependence under a Brownian-motion model of trait
evolution, \mathbf A is the **phylogenetic correlation matrix**:

A\_{ij} \\=\\ \frac{T\_{ij}}{T},

where T\_{ij} is the shared branch length between species i and j
measured from the root, and T is the tree height. For an ultrametric
tree all tips are equidistant from the root and A\_{ii} = 1 by
construction. The matrix is symmetric positive-definite.

Two operational representations exist:

``` r

suppressPackageStartupMessages({
  library(metadat); library(ape); library(metafor); library(MCMCglmm)
})

# Real comparative-biology data: Mizuno et al. (2026, Research Synthesis
# Methods; tutorial at https://ayumi-495.github.io/phylo_spatial_tutorial/)
# use Moura et al. (2021)'s assortative-mating dataset for the phylogenetic
# example. dat.moura2021 carries 1,828 Pearson correlations (size-size
# assortative mating) across 341 species, plus a phylogeny. We follow the
# Mizuno workflow: compute Fisher-z effect sizes via metafor::escalc,
# subsample 60 species (each with at least 2 effect sizes for stable
# aggregation), and aggregate to one mean Fisher-z per species so the
# example is a clean phylogenetic random-intercept model on a Gaussian
# trait. The full multilevel-meta-analytic structure (effect-size +
# study + species_phylo + species_nonphylo random effects) is the
# v0.22 article's topic.
data(dat.moura2021, package = "metadat")
moura_es <- escalc(measure = "ZCOR", ri = ri, ni = ni,
                   data = dat.moura2021$dat)

# Tree tip labels carry Open Tree of Life format ("Genus_species_ottNNN");
# strip the suffix and convert underscores to spaces to match dat$species
# ("Genus species"). Drop node labels (duplicated in the source tree;
# MCMCglmm::inverseA rejects them otherwise).
tree_raw <- dat.moura2021$tree
tree_raw$tip.label <- gsub("_", " ", sub("_ott[0-9]+$", "", tree_raw$tip.label))
tree_raw$node.label <- NULL

n_per_sp <- table(moura_es$species)
sp_pool  <- intersect(tree_raw$tip.label,
                      names(n_per_sp[n_per_sp >= 2L]))
set.seed(1)
sp_keep  <- sample(sp_pool, 60L)

# Aggregate to one mean Zr per species + variance-of-the-mean for V.
agg <- aggregate(cbind(yi, vi) ~ species,
                 data = moura_es[moura_es$species %in% sp_keep, ],
                 FUN  = function(v) c(mean = mean(v), n = length(v)))
dat <- data.frame(
  species = factor(as.character(agg$species), levels = sp_keep),
  Zr      = agg$yi[, "mean"],
  vi      = (agg$vi[, "mean"] * agg$yi[, "n"]) / agg$yi[, "n"]^2,
  n_eff   = agg$yi[, "n"]
)

tree   <- keep.tip(tree_raw, sp_keep)
# Ultrametricise the tree once, here, so every downstream phylogenetic
# fit is on the SAME ultrametric tree. Brownian-motion on tips-only A
# requires equal root-to-tip distances by construction (A_ii = 1 only
# when tips are equidistant from the root); metafor / MCMCglmm / brms /
# glmmTMB accept a non-ultrametric tree silently but the BM prior is
# then misspecified. drmTMB ENFORCES ultrametricity (it errors otherwise),
# which surfaces the assumption that the other packages let pass. The
# Moura tree comes from Open Tree of Life with mixed-source branch
# lengths, so we smooth it with ape::chronos() (penalised-likelihood
# molecular-clock estimate; lambda = 1 = smoothest plausible clock).
tree   <- ape::chronos(tree, lambda = 1, quiet = TRUE)
class(tree) <- "phylo"
A_tips <- vcv.phylo(tree, corr = TRUE)
# Reorder A_tips rows/cols to match `sp_keep` (a random sample). Without
# this, A_tips inherits the depth-first tree-tip order, so head 5x5
# clusters closely-related species (all passerines, all ~0.85+) and
# hides the structural-dependence "mix of relatedness" the widget is
# meant to demonstrate. Florence-audit 2026-05-26.
A_tips <- A_tips[sp_keep, sp_keep]
# Representation 2 -- all-nodes A-inverse (tips + internal nodes, sparse
# precision; Hadfield & Nakagawa 2010). With the tree now ultrametric,
# scale = TRUE works cleanly (normalises total tree depth to 1, the
# canonical BM-prior parameterisation).
A_all  <- inverseA(tree, nodes = "ALL", scale = TRUE)

cat("species k =", nrow(dat),
    "  Zr range = [", round(min(dat$Zr), 2), ",", round(max(dat$Zr), 2), "]\n")
#> species k = 60   Zr range = [ -0.14 , 1.59 ]
cat("A off-diagonal quantiles (25/50/75/99%): ",
    paste(round(quantile(A_tips[upper.tri(A_tips)], c(.25,.5,.75,.99)), 3),
          collapse = " / "), "\n")
#> A off-diagonal quantiles (25/50/75/99%):  0 / 0.095 / 0.228 / 0.866
```

The two representations encode the **same** Brownian-motion prior. The
tips-only version is the operational default for `metafor`,
`glmmTMB::propto`, and `brms::gr(cov = A)`. The all-nodes version is
what `MCMCglmm` uses internally (`ginverse = list(animal = Ainv)`) and
what
[`drmTMB::phylo()`](https://itchyshin.github.io/drmTMB/reference/phylo.html)
builds under the hood (`drmTMB` cites Hadfield & Nakagawa 2010
explicitly in its [`?phylo`](https://rdrr.io/pkg/ape/man/read.tree.html)
help page). The all-nodes form is *richer*: it gives access to
ancestral-state BLUPs at internal nodes; the tips-only form marginalises
those out. In a balanced setup the two agree on the variance estimate
\hat\sigma_p^2 — a result we’ll return to in § “Tips-only vs all-nodes”.

## Three packages, one phylogenetic LMM

We fit the same model three different ways on the 60-species
Moura-derived dataset. The model is

\mathrm{Zr}\_i \\=\\ \beta_0 + u\_{p\_{k\[i\]}} + e_i,\qquad u_p \sim
\mathcal N(\mathbf 0,\\ \sigma_p^2\\\mathbf A),\quad e_i \sim \mathcal
N(0,\\ \sigma_e^2),

where:

| Symbol | Meaning | Status |
|----|----|----|
| i | observation index, i = 1, \dots, n — in this dataset there is one observation per species, so i runs over species | index |
| k | species index — total number of species in the phylogeny, k = 60 here | index |
| k\[i\] | the species that observation i belongs to (here k\[i\] = i because one observation per species) | index |
| \mathrm{Zr}\_i | Fisher-z transformed correlation for species i — here treated as an ordinary continuous trait | observed |
| \beta_0 | global mean of \mathrm{Zr} across species | **estimated** |
| u\_{p\_{k\[i\]}} | phylogenetic random effect, indexed by species k\[i\] for observation i | **estimated** (latent) |
| \sigma_p^2 | phylogenetic variance — the scale of \mathbf u_p | **estimated** |
| \mathbf A | k \times k tips-only phylogenetic correlation matrix derived from the tree under Brownian motion (or its all-nodes augmentation; see § “Tips-only vs all-nodes”) | constructed from tree |
| e_i | residual on the response scale | **estimated** |
| \sigma_e^2 | residual variance — what each package would call \sigma^2\_{\text{units}}, \sigma^2\_{\text{res}}, or the marginal \sigma^2 (1 - \lambda) depending on the parameterisation | **estimated** |

Three notes that often trip up first readers:

1.  **\sigma_e^2 is estimated, not the per-effect sampling variance
    v_i.** In meta-analysis we’d also feed in v_i (a *known* sampling
    variance per study) via `metafor::rma.mv(V = vi, ...)`. That’s the
    model class in the companion
    [`vignette("symbolizer-meta-analysis")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-meta-analysis.md)
    — same \sigma_p^2 \mathbf A phylogenetic term, but with \mathbf V =
    \operatorname{diag}(v_i) added on top of \sigma_e^2 \mathbf I (Cinar
    et al. 2022, Eq. 1–10).
2.  The Moura data was *built* as a meta-analytic dataset (one Fisher-z
    per species, aggregated from many effect-size estimates). We use
    only \mathrm{Zr} here; the v_i column is set aside. That’s a
    pedagogical choice — a clean phylo-LMM is easier to read than a
    meta-analytic phylo-LMM, and it keeps this article focused on the
    structural-dependence axis.
3.  `phylolm` fits a **marginalised** version of this same model: it
    absorbs u_p into the residual to give \mathrm{Zr} \sim \mathcal
    N(\beta_0 \mathbf 1, \sigma^2 \mathbf C(\alpha)) where \sigma^2
    \mathbf C(\alpha) = \sigma_p^2 \mathbf A + \sigma_e^2 \mathbf I in
    the Pagel-\lambda parametrisation. The § “Face 3” Face below makes
    the bridge explicit.

The phylogenetic correlation matrix \mathbf A carries realistic biology
— most species pairs are distantly related (median off-diagonal \approx
0.09) while a handful are close (top 1 % above 0.85). Compare with the
degenerate `rcoal(15)` simulation used in earlier drafts where 75 % of
pairs were above 0.91.

### Face 1 (deep dive): `MCMCglmm` with `ginverse = list(species = Ainv)`

`MCMCglmm` uses the **all-nodes** representation natively (Hadfield 2010
§8.2.1). Internally the random-effect vector spans both tip species AND
internal phylogenetic nodes, so when the widget below shows the
\mathbf{A} matrix you will see a 116 \times 116 block, not the nominal k
\times k = 60 \times 60 tips-only form — the same prior, just an
augmented coordinate system. (For a k-tip tree the augmentation is at
most 2k-2 rows; in this dataset two polytomies after ultrametricisation
drop the count from 118 to 116.) The Moura dataset has one observation
per species, so the random-effect incidence matrix \mathbf{Z} is the
identity on the observed species and the widget elides it from Tab 3’s
stacked block — each row shows the predicted per-observation random
effect \hat u\_{\text{species}(i)} directly. (\mathbf{Z} is reintroduced
in articles where multiple observations share a species or study.)

A note on **scalar vs vector notation** before the widget: the **Index**
tab writes one row of the model for a single observation i, so the
scalar form \mathrm{Zr}\_i (italic capital, with subscript) is used. The
**Matrix** and **Equations with data** tabs collect all n observations
into the column vector \mathbf{zr} = (\mathrm{Zr}\_1, \dots,
\mathrm{Zr}\_n)^\top (bold lowercase, no subscript). Same quantity, two
notations — the index form is for reading one row, the vector form is
for the matrix algebra.

``` r

fit_mcmc <- MCMCglmm(
  Zr ~ 1,
  random   = ~ species,
  ginverse = list(species = A_all$Ainv),
  data     = dat,
  family   = "gaussian",
  pr       = TRUE,        # store the per-species BLUPs for the widget
  nitt = 5000, burnin = 1000, thin = 5, verbose = FALSE
)
sym_mcmc <- symbolize(fit_mcmc, data = dat)
```

``` r

sym_mcmc$metadata$phylo_representation   # "all_nodes"
#> [1] "all_nodes"
sym_mcmc$metadata$detected_signals       # "phylo"
#> [1] "phylo"
sym_mcmc$variance_components             # phylo + residual
```

| parameter | group    | term        | sd_estimate | var_estimate |
|:----------|:---------|:------------|:------------|:-------------|
| mu        | species  | (Intercept) | 0.325       | 0.105        |
| residual  | residual | Residual    | 0.215       | 0.0460       |

``` r

sym_mcmc$metadata$heritability           # h^2 derived automatically
#> # A tibble: 1 × 5
#>   group   variance_A variance_E heritability reading                            
#>   <chr>        <dbl>      <dbl>        <dbl> <chr>                              
#> 1 species      0.105     0.0460        0.696 Heritability h^2 = sigma^2_p / (si…
```

#### Three-views widget for the MCMCglmm fit

[Skip three-views widget](#sym-mcmc-1781371055-end)

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

**Coefficient reading.** On the response scale, \hat\beta is the
additive change in the mean of the response for a one-unit increase in
the predictor (identity link – no back-transformation needed).

\begin{aligned} \mathrm{Zr}\_i \mid \mu_i,\\ \sigma & \sim
\mathrm{Normal}(\mu_i,\\ \sigma^2) \\ \mu_i & = \beta\_{0} +
u\_{species(i)} \\ \mathbf{u}\_{species} & \sim
\mathcal{N}(\mathbf{0},\\ \sigma\_{species}^2 \mathbf{A}) \end{aligned}

where:

- \mathrm{Zr}\_i — response variable  \mathbb{R}^{60}
- \mu_i — conditional mu of Zr  \mathbb{R}^{60}
- \sigma — residual standard deviation of Zr  scalar
- \beta\_{0} — mu submodel coefficients  \mathbb{R}^{1}
- u\_{species(i)} — random intercept by species  scalar;
  \mathbb{R}^{116} in matrix form
- \sigma\_{species} — between-species standard deviation  scalar
- \mathbf{A} — phylogenetic / pedigree correlation matrix on species
  (Hadfield-Nakagawa all-nodes sparse-precision representation, supplied
  via ginverse)  \mathbb{R}^{k\_{species} \times k\_{species}}

**Where does the variation live?** Where the variation lives – each row
is one variance component (shown as a share of the total when a single
total variance is defined).

species 69.6%

Residual (within-group) 30.4%

**ICC (data scale):** 0.696. Data-scale ICC: the share of total variance
that lies between groups – a genuine proportion of variance.

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

\begin{aligned} \mathbf{zr} \mid \boldsymbol{\mu},\\ \boldsymbol{\sigma}
& \sim \mathcal{N}(\boldsymbol{\mu},\\
\mathrm{diag}(\boldsymbol{\sigma}^2)) \\ \boldsymbol{\mu} & = \mathbf{X}
\boldsymbol{\beta} + \mathbf{u} \\ \mathbf{u}\_{species} & \sim
\mathcal{N}(\mathbf{0},\\ \sigma\_{species}^2 \mathbf{A}\_{116 \times
116}) \end{aligned}

where:

- \mathbf{zr} — response variable  \mathbb{R}^{60}
- \boldsymbol{\mu} — conditional mu of Zr  \mathbb{R}^{60}
- \boldsymbol{\sigma} — residual standard deviation of Zr  scalar
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{1}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{60 \times 1}
- \mathbf{u}\_{species} — random intercept by species  scalar;
  \mathbb{R}^{116} in matrix form
- \sigma\_{species} — between-species standard deviation  scalar
- \mathbf{A} — phylogenetic / pedigree correlation matrix on species
  (Hadfield-Nakagawa all-nodes sparse-precision representation, supplied
  via ginverse)  \mathbb{R}^{k\_{species} \times k\_{species}}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 60.

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
below. The predicted random-effect contribution to each observation is
also shown.

For observation *i* = 1 of your data:

\begin{aligned} zr\_{1} &= \hat\beta\_{0} + \hat{u}\_{1} +
\hat\varepsilon\_{1} &\quad(\text{response equation, one row of the
model}) \\ \hat\mu\_{1} &= 0.366 + (-0.151) \approx 0.215
&\quad(\text{predicted mean} = \text{linear predictor}) \\ zr\_{1} &=
\underbrace{0.215}\_{\textstyle\\\hat\mu\_{1}\\\text{(predicted)}\\}
\\+\\
\underbrace{(-0.0485)}\_{\textstyle\\\hat\varepsilon\_{1}\\\text{(residual)}\\}
&\quad(\text{observed} = \text{predicted mean} + \text{residual})
\end{aligned}

Stacking the same response equation for all *n* = 60 observations:

\underbrace{\begin{bmatrix} 0.166 \\ 1.12 \\ 0.66 \\ 1.05 \\ 0.676 \\
\vdots \\ 0.172 \\ 0.0853
\end{bmatrix}}\_{\textstyle\\\mathbf{zr}\_{\\60 \times
1}\\\text{(observed)}\\} \\=\\ \underbrace{\begin{bmatrix} 1 \\ 1 \\ 1
\\ 1 \\ 1 \\ \vdots \\ 1 \\ 1
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\60 \times 1}\\}\\
\underbrace{\begin{bmatrix} 0.366
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\1 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} -0.0485 \\
0.351 \\ 0.057 \\ 0.289 \\ 0.285 \\ \vdots \\ -0.178 \\ -0.0958
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}\_{\\60
\times 1}\\\text{(residual)}\\}

**Left**: observed vector \mathbf{zr}. **Middle**: the prediction
\mathbf{X}\hat{\boldsymbol{\beta}} + \hat{\mathbf{u}} =
\hat{\boldsymbol{\mu}}. **Right**: the residual vector
\hat{\boldsymbol{\varepsilon}} = \mathbf{zr} - \hat{\boldsymbol{\mu}}.
Every row of this matrix equation is one of the response-equation rows
from the worked row above.

**Partial pooling.** The random-effect estimates shown here (the BLUPs)
are partially pooled: each group’s estimate is shrunk toward zero by an
amount that grows when the group has little data and shrinks when the
between-group variance is large. Groups with the least data are pulled
hardest toward the overall mean.

**And the structured-covariance prior on `u`**. The random effect that
gives this model its structural-dependence character:

\mathrm{Cov}(\hat{\mathbf{u}}) \\=\\ \sigma_p^2 \cdot
\underbrace{\begin{bmatrix} 0.161 & 0 & 0.161 & 0.161 & 0.161 & \cdots &
0 & 0 \\ 0 & 0.0946 & 0 & 0 & 0 & \cdots & 0.0946 & 0.0946 \\ 0.161 & 0
& 0.228 & 0.228 & 0.228 & \cdots & 0 & 0 \\ 0.161 & 0 & 0.228 & 0.298 &
0.298 & \cdots & 0 & 0 \\ 0.161 & 0 & 0.228 & 0.298 & 0.565 & \cdots & 0
& 0 \\ \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots \\ 0 & 0.0946 & 0 & 0 & 0 & \cdots & 1 & 0.867 \\ 0 & 0.0946 & 0
& 0 & 0 & \cdots & 0.867 & 1
\end{bmatrix}}\_{\textstyle\\\mathbf{A}\_{\\116 \times 116}\\}

The phylo random effect u has covariance \sigma_p^2 \cdot \mathbf{A},
where \mathbf{A} is the 116 × 116 augmented phylogenetic **covariance**
matrix (tips and internal nodes, the Hadfield–Nakagawa all-nodes
representation). Its diagonal is *not* all 1: the leading rows shown
here are internal nodes, whose self-covariance is \< 1 under all-nodes
scaling; only the tip rows have unit diagonal. Showing the head + tail
rows / columns; full matrix is 116 × 116.

[Download as
PDF](https://itchyshin.github.io/symbolizer/articles/fig-mcmc-phylo.pdf)

The same extractor branch handles **animal models** (where `A` comes
from a pedigree, not a tree) — see *§Animal-model unification* below.

### Face 2 (light): `brms::gr(species, cov = A)`

`brms` (Bürkner 2017) exposes the same structured-effect model via the
[`gr()`](https://paulbuerkner.com/brms/reference/gr.html) group factor
inside an lme4-style RE bar. The fit takes ~30 s of Stan
compile-and-sample (cached after the first build).

``` r

library(brms)
data2_list <- list(A = A_tips)
fit_brms <- brm(
  Zr ~ 1 + (1 | gr(species, cov = A)),
  data       = dat,
  data2      = data2_list,
  family     = gaussian(),
  chains     = 2, iter = 2000, warmup = 1000, refresh = 0, silent = 2,
  control    = list(adapt_delta = 0.95),     # tighten leapfrog to avoid divergent transitions
  file       = "fig-brms-phylo-cache",        # brms auto-caches as .rds
  file_refit = "on_change"
)
sym_brms <- symbolize(fit_brms)
```

``` r

sym_brms$metadata$phylo_representation   # "tips_only"
#> [1] "tips_only"
sym_brms$metadata$detected_signals       # "phylo"
#> [1] "phylo"
sym_brms$variance_components             # species + residual
```

| parameter | group    | term        | sd_estimate | var_estimate |
|:----------|:---------|:------------|:------------|:-------------|
| mu        | species  | (Intercept) | 0.364       | 0.132        |
| residual  | residual | Residual    | 0.170       | 0.0289       |

`symbolizer` reports `phylo_representation = "tips_only"` because `brms`
works directly with the k \times k tips-only \mathbf A — no
internal-node augmentation. Compare with the MCMCglmm Face above where
`phylo_representation = "all_nodes"`; the variance estimate
\hat\sigma_p^2 is the same in expectation — the roughly 28 % Monte-Carlo
gap between the two fits here (and the matching gap in \hat H^2)
reflects short chains and differing default priors, not a difference in
the underlying model.

``` r

assumption_table(sym_brms)
```

| assumption | expression | biological meaning | status |
|:---|:---|:---|:---|
| conditional_distribution | \mathrm{Zr}\_i \mid \mu_i,\\ \sigma_i \sim \mathrm{Normal}(\mu_i,\\ \sigma_i^2) | Zr varies normally around its expected value | explicit |
| linear_predictor | \mu_i = \beta_0 + \sum_k \beta_k X\_{ki} | Expected Zr is a linear combination of the mean-model predictors | explicit |
| independence_given_random_effects | \mathrm{Zr}\_i \perp \mathrm{Zr}\_j \mid X\\ \mathbf{u} \text{ for } i \ne j | Observations are conditionally independent given the predictors and the random effects | explicit |
| no_missing_at_random | — | Observations are assumed not missing in a way that depends on the unobserved response | your responsibility |
| phylo_random_effect | \mathbf{u}\_p \sim \mathcal{N}(\mathbf{0}, \sigma_p^2 \mathbf{A}) | Species-level random effect with covariance proportional to the phylogenetic correlation matrix A | explicit |
| phylo_A_positive_definite | \mathbf{A} \succ 0 | A is positive-definite k \times k phylogenetic correlation matrix derived from a rooted tree under Brownian motion | follows from the formula |
| phylo_tips_only_representation | A\_{ij} = T\_{ij}/T | Tips-only k \times k representation: A\_{ij} is shared branch length between species i and j divided by total tree height (Hadfield 2010) | follows from the formula |
| phylo_brownian_motion | \mathrm{Var}(u_p) \propto \mathrm{time} | Brownian motion prior: phylogenetic variance accumulates linearly with branch length | your responsibility |
| phylo_ultrametric_tree | — | Tree is ultrametric – non-ultrametric trees still produce a valid A but break the strict Brownian-motion variance interpretation | your responsibility |

### Face 3 (light): `phylolm::phylolm()` — the marginal PGLS form

`phylolm` (Ho & Ané 2014) fits the same conceptual model in a
*marginalised* form: instead of writing y = \beta_0 + u_p + e with two
separate variance components, `phylolm` absorbs u_p into the residual to
give

\mathrm{Zr}\_i \\=\\ \beta_0 + e'\_i,\quad \mathbf e' \sim \mathcal
N(\mathbf 0,\\ \sigma^2\\\mathbf C(\alpha))

where \mathbf C(\alpha) is a tree-derived correlation matrix. For
Pagel’s \lambda model the connection to the RE form is precise:

\mathbf C(\lambda) = \lambda\\\mathbf A + (1 - \lambda)\\\mathbf I,
\qquad \sigma_p^2 = \lambda\\\sigma^2, \qquad \sigma_e^2 = (1 -
\lambda)\\\sigma^2.

So \lambda = \sigma_p^2 / (\sigma_p^2 + \sigma_e^2) — the **phylogenetic
heritability** H^2 from § “Animal-model unification” — and the two
parameterisations agree on every prediction. `phylolm`’s advantage is
speed: a closed-form ML fit in a fraction of a second instead of Stan’s
compile + sample.

``` r

library(phylolm)
dat_pl <- dat
rownames(dat_pl) <- dat_pl$species
fit_pl <- phylolm(Zr ~ 1, data = dat_pl, phy = tree, model = "lambda")
sym_pl <- symbolize(fit_pl, data = dat_pl)
```

``` r

sym_pl$metadata$phylo_representation   # "pgls_marginal"
#> [1] "pgls_marginal"
sym_pl$metadata$phylo_model            # "lambda"
#> [1] "lambda"
sym_pl$metadata$phylo_param            # estimated lambda
#> [1] 0.7631645
sym_pl$metadata$detected_signals       # "phylo_marginal"
#> [1] "phylo_marginal"
sym_pl$variance_components             # single sigma^2 row
```

| parameter | group | term                   | sd_estimate | var_estimate |
|:----------|:------|:-----------------------|:------------|:-------------|
| residual  | phylo | sigma^2 (phylogenetic) | 0.376       | 0.141        |

``` r

summary(fit_pl)
#> 
#> Call:
#> phylolm(formula = Zr ~ 1, data = dat_pl, phy = tree, model = "lambda")
#> 
#>    AIC logLik 
#>  27.13 -10.57 
#> 
#> Raw residuals:
#>      Min       1Q   Median       3Q      Max 
#> -0.51914 -0.23479 -0.12683  0.05359  1.20643 
#> 
#> Mean tip height: 1
#> Parameter estimate(s) using ML:
#> lambda : 0.7631645
#> sigma2: 0.141141 
#> 
#> Coefficients:
#>             Estimate  StdErr t.value  p.value   
#> (Intercept)  0.38077 0.13955  2.7285 0.008369 **
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
#> 
#> R-squared:     0 Adjusted R-squared:     0 
#> 
#> Note: p-values and R-squared are conditional on lambda=0.7631645.
```

The bridge with the RE form: take the estimated \hat\sigma^2 and
\hat\lambda from the summary above, then \hat\sigma_p^2 =
\hat\lambda\\\hat\sigma^2 and \hat\sigma_e^2 =
(1-\hat\lambda)\\\hat\sigma^2. With this dataset, those reconciled
values agree with the MCMCglmm estimates on the phylogenetic variance to
within a couple of percent, but the residual variance \sigma_e^2 can
differ by 20–30 % across the three packages — the variance *split* is
weakly identified when there is one observation per species (see § “When
unification breaks: identifiability” below). The total \hat\sigma_p^2 +
\hat\sigma_e^2 and the heritability \hat H^2 = \hat\lambda are more
stable than either component on its own.

``` r

assumption_table(sym_pl)
```

| assumption | expression | biological meaning | status |
|:---|:---|:---|:---|
| conditional_distribution | \mathrm{Zr}\_i \mid \mu_i,\\ \sigma_i \sim \mathrm{Normal}(\mu_i,\\ \sigma_i^2) | Zr varies normally around its expected value | explicit |
| linear_predictor | \mu_i = \beta_0 + \sum_k \beta_k X\_{ki} | Expected Zr is a linear combination of the mean-model predictors | explicit |
| no_missing_at_random | — | Observations are assumed not missing in a way that depends on the unobserved response | your responsibility |
| pgls_marginal_distribution | \mathbf{y} \mid \boldsymbol{\beta},\\ \sigma_p^2 \sim \mathcal{N}(\mathbf{X} \boldsymbol{\beta},\\ \sigma_p^2 \mathbf{A}) | Zr follows a multivariate normal with mean \mathbf{X}\boldsymbol{\beta} and a DENSE phylogenetic residual covariance (PGLS marginal form). Under Brownian motion that covariance is \sigma_p^2\mathbf{A}; under Pagel’s \lambda it is \sigma_p^2\[\lambda\mathbf{A} + (1-\lambda)\mathbf{I}\] – \lambda scales the phylogenetic off-diagonals while leaving the diagonal at \sigma_p^2. Either way the residuals are not independent across species. | explicit |
| phylo_residual_covariance | \mathbf{e} \sim \mathcal{N}(\mathbf{0},\\ \sigma_p^2 \mathbf{A}),\quad \mathbf{y} = \mathbf{X} \boldsymbol{\beta} + \mathbf{e} | The phylogenetic signal lives entirely in the residual covariance: phylolm marginalises the species effect into \mathbf{e}, so \mathrm{Cov}(\mathbf{e}) = \sigma_p^2\mathbf{A} (under BM) or \sigma_p^2\[\lambda\mathbf{A} + (1-\lambda)\mathbf{I}\] (under Pagel’s \lambda) rather than a separate u_p random-effect tier. | explicit |
| phylo_marginal_A_positive_definite | \mathbf{A} \succ 0 | \mathbf{A} is the positive-definite k \times k phylogenetic correlation matrix derived from the rooted tree. Under BM the residual covariance is \sigma_p^2\mathbf{A}; under Pagel’s \lambda it is \sigma_p^2\[\lambda\mathbf{A} + (1-\lambda)\mathbf{I}\]. | follows from the formula |
| phylo_marginal_brownian_motion | \mathrm{Cov}(e_i\\ e_j) = \sigma_p^2 A\_{ij} \propto \text{shared branch length} | Brownian motion: residual covariance between two species is proportional to their shared evolutionary history (branch length). If OU / EB / kappa / delta is intended, refit with that correlation structure – the marginalization-bridge prose is calibrated to BM and Pagel’s lambda | your responsibility |
| phylo_marginal_ultrametric_tree | — | Tree is ultrametric (all tips equidistant from the root); non-ultrametric trees still give a valid A but break the strict Brownian-motion variance interpretation | your responsibility |

The cross-package agreement story is the point: every fit above attaches
the same conceptual object — a phylogenetic correlation matrix \mathbf A
— even though the syntactic surface differs (RE bar in `MCMCglmm` and
`brms`, marginalised residual covariance in `phylolm`). The RE-form fits
(`MCMCglmm`, `brms`) report `metadata$detected_signals = "phylo"`;
`phylolm` reports `"phylo_marginal"`, the marginal-form variant of the
same phylogenetic signal (it absorbs u_p into the residual, so there is
no separate u_p tier to label). Either way `symbolizer` attaches the
same symbol-dictionary row for \mathbf A and gates the matching
phylogenetic assumption rows, no matter which parameterisation fitted
the model.

## Animal-model unification

The phylogenetic random effect is the **same mathematical object** as
the additive-genetic random effect in a quantitative-genetics animal
model. The matrix \mathbf A comes from a different source (a pedigree of
dam-sire-offspring rather than a phylogenetic tree), but its meaning in
the model is identical:

\mathbf u_p \\\sim\\ \mathcal N(\mathbf 0, \sigma_p^2\\\mathbf A),\qquad
h^2 \\=\\ \frac{\sigma_p^2}{\sigma_p^2 + \sigma_e^2}.

(The quantitative-genetics literature often writes the same quantities
as \mathbf u_a, \sigma_A^2, and \sigma_E^2 — the “A” / “E” letters stand
for *additive* and *environmental*. This article uses p / e throughout
for consistency; the conversion is purely cosmetic.) The interpretation
of \sigma_p^2 differs by domain: it’s *phylogenetic* variance among
species in a phylogenetic comparative method, *additive genetic*
variance among individuals in a quantitative-genetics animal model.
`symbolizer`’s
[`symbolize.MCMCglmm()`](https://itchyshin.github.io/symbolizer/reference/symbolize.MCMCglmm.md)
handles both via the same `ginverse` detection branch, and `drmTMB`
ships separate `phylo(term, tree)` and `animal(term, pedigree)` markers
that share an internal implementation. For deep-dive treatments of
either case, see drmTMB’s own
[`structural-dependence.Rmd`](https://itchyshin.github.io/drmTMB/articles/structural-dependence.html),
[`phylogenetic-models.Rmd`](https://itchyshin.github.io/drmTMB/articles/phylogenetic-models.html),
and
[`animal-models.Rmd`](https://itchyshin.github.io/drmTMB/articles/animal-models.html)
— `symbolizer` cross-links rather than duplicates them.

## Tips-only vs all-nodes

Why does the all-nodes representation matter when the tips-only
correlation matrix has all the data information? Three reasons:

1.  **Ancestral states**. The all-nodes form lets you query a posterior
    for the trait value at any internal node — useful for inferring
    ancestral character states.
2.  **Numerical efficiency on large trees**. The all-nodes A-inverse is
    *sparse* (each internal node connects to its parent and children
    only). Inverting the tips-only k \times k matrix is \mathcal O(k^3);
    the sparse A-inverse path is much faster for k \> \sim 200.
3.  **Partial observations**. If some species have measured traits and
    others are unobserved (but on the tree), the all-nodes form handles
    this naturally.

On a balanced setup with all species observed, both representations give
the same \hat\sigma_p^2 to machine precision — the Hadfield-Nakagawa
equivalence.

## Spatial: same grammar, different matrix

For spatial dependence, \mathbf M is built from pairwise geographic
distances and a kernel. The standard choices are:

| Kernel                         | Formula                  | Decay              |
|--------------------------------|--------------------------|--------------------|
| Exponential                    | C(d) = \exp(-d/\rho)     | Power              |
| Squared-exponential (Gaussian) | C(d) = \exp(-d^2/\rho^2) | Sharp              |
| Matérn                         | C(d; \kappa, \nu)        | Tunable smoothness |

Two fits *illustrate* the structurally identical grammar with
\boldsymbol\Omega in place of \mathbf A — these are **pseudocode** (the
spatial demo data + mesh would be set up in a separate spatial article,
not here):

``` r

library(sdmTMB)
fit_sp <- sdmTMB(
  y ~ 1,
  data = dat_spatial,
  mesh = mesh,
  spatial = "on",
  family = gaussian()
)
sym_sp <- symbolize(fit_sp)
sym_sp$metadata$spatial_representation  # "package_managed"

library(mgcv)
fit_gp <- gam(y ~ s(x, y, bs = "gp"), data = dat_spatial)
sym_gp <- symbolize(fit_gp)
```

`symbolizer`’s metafor extractor also handles
`rma.mv(struct = "SPEXP", dist = list(location = D))` — Mizuno et
al. (2026, *Research Synthesis Methods*) is the conceptual anchor for
the unified phylogenetic + spatial meta-analytic story.

## When unification breaks: identifiability

The unification works mathematically, but practical inference depends on
the data. When you stack a phylogenetic tier and a non-phylogenetic
species-level tier on the same grouping column,

y_i = \beta_0 + u\_{p\_{k\[i\]}} + u\_{s\_{k\[i\]}} + e_i,\qquad u_p
\sim \mathcal N(0, \sigma_p^2 \mathbf A),\quad u_s \sim \mathcal N(0,
\sigma_s^2 \mathbf I),

the variance components \sigma_p^2 and \sigma_s^2 are *weakly
identified*: their sum is precisely estimable but the split between them
is not (Hadfield & Nakagawa 2010 §3.2; Mizuno et al. 2026 §4). With
strong phylogenetic signal (Pagel’s λ near 1) the split is informative;
with weak signal (λ near 0) the data have almost no leverage to separate
the two. `symbolizer` emits a `phylo_nonphylo_unidentifiable` row in
[`warning_table()`](https://itchyshin.github.io/symbolizer/reference/warning_table.md)
when this configuration is detected. Profile on λ or fix one tier to
resolve.

## Forward links

- **Phylogenetic meta-analysis (Mizuno et al. 2026)** — already covered
  in the companion
  [`vignette("symbolizer-meta-analysis")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-meta-analysis.md)
  (§4). This article fits the general phylo-GLMM with \sigma_e^2
  *estimated*; the meta-analytic case, where the per-study sampling
  variance v_i is **known**, uses `metafor::rma.mv(V = V, ...)` as the
  canonical interface, with `glmmTMB::equalto` (reserved) and
  `brms::se(sqrt(vi))` as bridges.
- **v0.24 — Location-scale on \mathbf M (Nakagawa et al. 2025 *MEE*)**.
  The dependence parameter itself can have a submodel: \sigma_p \sim z
  across clades, \rho \sim z across environments. Symbolizer’s drmTMB
  extractor is the right home for the phylogenetic location-scale model.
- **drmTMB deep dives**:
  [`vignette("phylogenetic-models", package = "drmTMB")`](https://itchyshin.github.io/drmTMB/articles/phylogenetic-models.html),
  [`vignette("animal-models", package = "drmTMB")`](https://itchyshin.github.io/drmTMB/articles/animal-models.html),
  [`vignette("structural-dependence", package = "drmTMB")`](https://itchyshin.github.io/drmTMB/articles/structural-dependence.html).
- **gllvmTMB deep dive**:
  `vignette("phylogenetic-gllvm", package = "gllvmTMB")`.

## References

- Bürkner, P.-C. (2017). brms: An R Package for Bayesian multilevel
  models using Stan. *Journal of Statistical Software*, 80(1), 1–28.
- Cinar, O., Nakagawa, S. & Viechtbauer, W. (2022). Phylogenetic
  multilevel meta-analysis: A simulation study on the importance of
  modelling the phylogeny. *Methods in Ecology and Evolution*, 13,
  383–395.
- Hadfield, J. D. (2010). MCMC methods for multi-response generalized
  linear mixed models: the `MCMCglmm` R package. *Journal of Statistical
  Software*, 33(2), 1–22.
- Hadfield, J. D. & Nakagawa, S. (2010). General quantitative genetic
  methods for comparative biology: phylogenies, taxonomies and
  multi-trait models for continuous and categorical characters. *Journal
  of Evolutionary Biology*, 23, 494–508.
- Ho, L. S. T. & Ané, C. (2014). A linear-time algorithm for Gaussian
  and non-Gaussian trait evolution models. *Systematic Biology*, 63(3),
  397–408.
- Lynch, M. (1991). Methods for the analysis of comparative data in
  evolutionary biology. *Evolution*, 45(5), 1065–1080.
- Moura, M. R., Costa, H. C., Peixoto, M. A., Fonseca, E. M.,
  Werneck, F. P. & Garda, A. A. (2021). Data from: Detecting the
  geography of size-assortative mating in the Neotropics. *Ecography*,
  44(11), 1583–1594.
- Mizuno, A., Williams, C., Lagisz, M., Senior, A. M. & Nakagawa, S.
  (2026). A unified framework for phylogenetic and spatial
  meta-analysis: concepts, implementation, and practical guidance.
  *Research Synthesis Methods*.
- Nakagawa, S., Mizuno, A., Williams, C., Lagisz, M., Yang, Y. &
  Drobniak, S. M. (2025). Quantifying macro-evolutionary patterns of
  trait mean and variance with phylogenetic location-scale models.
  *Methods in Ecology and Evolution*, 16, 2585–2602.
- Williams, C., McGillycuddy, M., Drobniak, S. M., Bolker, B. M.,
  Warton, D. I. & Nakagawa, S. (2025). Fast phylogenetic generalised
  linear mixed-effects modelling using the `glmmTMB` R package.
  *bioRxiv* 2025.12.20.695312.
