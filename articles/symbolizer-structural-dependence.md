# Structural dependence: phylogenetic, animal-model, and spatial random effects

If you have ever written `(1 | species)` for an animal model,
`gr(species, cov = A)` in `brms`, or `s(x, y, bs = "gp")` for a spatial
process, you have been writing the **same model** three times — only the
matrix that encodes the dependence changes. This article is the first in
`symbolizer`’s **concept-axis series**; it teaches the
*dependence-structure* axis of GLMM grammar through five worked examples
across six R packages.

## The shared grammar

A generalised linear mixed model writes

``` math
y_i \mid \mathbf b \;\sim\; \mathcal D(\mu_i, \phi),\qquad
g(\mu_i) \;=\; \mathbf x_i^\top \boldsymbol\beta + \mathbf z_i^\top \mathbf b,
```

with random effects

``` math
\mathbf b \;\sim\; \mathcal N(\mathbf 0,\; \sigma^2\,\mathbf M).
```

The standard textbook GLMM takes $`\mathbf M = \mathbf I`$ — the random
effects are independent draws. Structural dependence is what you get
when $`\mathbf M \ne \mathbf I`$. Three named instantiations recur:

| Context | Symbol | What $`\mathbf M`$ encodes |
|----|----|----|
| Phylogenetic | $`\mathbf A`$ | Shared evolutionary history (tree → correlation) |
| Pedigree (animal model) | $`\mathbf A`$ | Genetic relatedness (pedigree → correlation) |
| Spatial | $`\boldsymbol\Omega`$ | Geographic proximity (distance + kernel) |

In abstract / cross-package teaching contexts (this article’s prose), we
write $`\mathbf M`$ for the generic role. In a fitted model with a known
context
(e.g. [`drmTMB::phylo()`](https://itchyshin.github.io/drmTMB/reference/phylo.html)
calls), `symbolizer` chooses the domain-specific letter — $`\mathbf A`$
for phylogenetic / animal-model, $`\boldsymbol\Omega`$ for spatial. The
symbol-dictionary description for $`\boldsymbol\Omega`$ explicitly
disambiguates it from (a) Wishart precision matrices and (b) CAR / SAR
spatial weights matrices.

## Where the matrix comes from

For phylogenetic dependence under a Brownian-motion model of trait
evolution, $`\mathbf A`$ is the **phylogenetic correlation matrix**:

``` math
A_{ij} \;=\; \frac{T_{ij}}{T},
```

where $`T_{ij}`$ is the shared branch length between species $`i`$ and
$`j`$ measured from the root, and $`T`$ is the tree height. For an
ultrametric tree all tips are equidistant from the root and
$`A_{ii} = 1`$ by construction. The matrix is symmetric
positive-definite.

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
A_tips <- vcv.phylo(tree, corr = TRUE)
# Reorder A_tips rows/cols to match `sp_keep` (a random sample). Without
# this, A_tips inherits the depth-first tree-tip order, so head 5x5
# clusters closely-related species (all passerines, all ~0.85+) and
# hides the structural-dependence "mix of relatedness" the widget is
# meant to demonstrate. Florence-audit 2026-05-26.
A_tips <- A_tips[sp_keep, sp_keep]
# Representation 2 -- all-nodes A-inverse (tips + internal nodes, sparse
# precision; Hadfield & Nakagawa 2010). scale = FALSE because the
# Moura tree from Open Tree of Life is not strictly ultrametric.
A_all  <- inverseA(tree, nodes = "ALL", scale = FALSE)

cat("species k =", nrow(dat),
    "  Zr range = [", round(min(dat$Zr), 2), ",", round(max(dat$Zr), 2), "]\n")
#> species k = 60   Zr range = [ -0.14 , 1.59 ]
cat("A off-diagonal quantiles (25/50/75/99%): ",
    paste(round(quantile(A_tips[upper.tri(A_tips)], c(.25,.5,.75,.99)), 3),
          collapse = " / "), "\n")
#> A off-diagonal quantiles (25/50/75/99%):  0 / 0.03 / 0.275 / 0.86
```

The two representations encode the **same** Brownian-motion prior. The
tips-only version is the operational default for `metafor`,
`glmmTMB::propto`, and `brms::gr(cov = A)`. The all-nodes version is
what `MCMCglmm` uses internally (`ginverse = list(animal = Ainv)`) and
what
[`drmTMB::phylo()`](https://itchyshin.github.io/drmTMB/reference/phylo.html)
builds under the hood (`drmTMB` cites Hadfield & Nakagawa 2010
explicitly in its
[`?phylo`](https://itchyshin.github.io/gllvmTMB/reference/phylo.html)
help page). The all-nodes form is *richer*: it gives access to
ancestral-state BLUPs at internal nodes; the tips-only form marginalises
those out. In a balanced setup the two agree on the variance estimate
$`\hat\sigma_p^2`$ — a result we’ll return to in §“Tips vs all-nodes”.

## Six packages, one phylogenetic model

We fit the same model six different ways on the 60-species Moura-derived
dataset. The model is

``` math
\mathrm{Zr}_i \;=\; \beta_0 + u_{p_{k[i]}} + e_i,\qquad
u_p \sim \mathcal N(\mathbf 0, \sigma_p^2\,\mathbf A),\quad
e_i \sim \mathcal N(0, \sigma_e^2).
```

The phylogenetic correlation matrix $`\mathbf A`$ now carries realistic
biology — most species pairs are distantly related (median off-diagonal
$`\approx 0.03`$) while a handful are close (top 1 % above 0.85).
Compare with the degenerate `rcoal(15)` simulation used in earlier
drafts where 75 % of pairs were above 0.91.

### Face 1: `metafor::rma.mv` with `R = list(species = A)`

``` r

fit_meta <- rma.mv(
  yi      = Zr,
  V       = vi,                # variance-of-the-mean per species
  random  = list(~ 1 | species),
  R       = list(species = A_tips),
  data    = dat,
  sparse  = TRUE
)
sym_meta <- symbolize(fit_meta)
sym_meta$metadata$phylo_representation
#> [1] "tips_only"
sym_meta$metadata$detected_signals
#> [1] "phylo"
```

``` r

equations(sym_meta, notation = "index")
```

``` math
\begin{aligned}
y_i \mid \theta_i \sim \mathrm{Normal}(\theta_i,\, v_i), \quad v_i \text{ known} \\
\mu_i = \beta_{0} + u_{species(i)} \\
\mathbf{u}_{species} \sim \mathcal{N}(\mathbf{0},\, \sigma_{species}^2 \mathbf{A})
\end{aligned}
```

The R-matrix tier’s group name (`species`) matches the canonical
phylogenetic lexicon, so `symbolizer`’s `metafor` extractor sets
`metadata$phylo_representation = "tips_only"`, declares
`detected_signals = "phylo"`, and adds a row to the symbol dictionary
for $`\mathbf A`$ with role `structured_correlation_phylo`. The
assumption table now lists the phylogenetic prior assumptions (Brownian
motion, ultrametricity, branch-length scale — your responsibility):

``` r

assumption_table(sym_meta)
```

| assumption | expression | biological meaning | status |
|:---|:---|:---|:---|
| conditional_distribution | $`y_i \mid \theta_i \sim \mathrm{Normal}(\theta_i,\, v_i)`$ | Each observed effect size is normally distributed around its true effect with KNOWN sampling variance | explicit |
| known_sampling_variance | $`v_i \text{ is known (not estimated)}`$ | Sampling variances v_i come from each primary study (or from escalc()); they are inputs, not parameters | your_responsibility |
| linear_predictor | $`\theta_i = \beta_0 + \sum_k \beta_k X_{ki} + u_i`$ | True effects are a linear combination of moderators plus a study-level random effect | explicit |
| random_effects_distribution | $`u_i \sim \mathrm{Normal}(0,\, \tau^2)`$ | The between-study true effects vary around the grand mean with variance tau^2 | explicit |
| inverse_variance_weights | $`w_i = 1 / (v_i + \tau^2)`$ | Each study is weighted by the inverse of (sampling variance + heterogeneity) | explicit |
| no_publication_bias | — | The included effect sizes are not preferentially the larger / significant ones; if they are, tau^2 / beta are biased | your_responsibility |
| correct_effect_metric | — | The metric (log RR, log OR, SMD, Fisher-z r, …) is appropriate for the outcome and is calculated consistently across studies | your_responsibility |
| no_missing_at_random | — | Studies are not missing in a way that depends on their unobserved true effect | your responsibility |
| phylo_random_effect | $`\mathbf{u}_p \sim \mathcal{N}(\mathbf{0}, \sigma_p^2 \mathbf{A})`$ | Species-level random effect with covariance proportional to the phylogenetic correlation matrix A | explicit |
| phylo_A_positive_definite | $`\mathbf{A} \succ 0`$ | A is positive-definite by construction: the k x k phylogenetic correlation matrix derived from a rooted tree under Brownian motion | follows from the formula |
| phylo_tips_only_representation | $`A_{ij} = T_{ij}/T`$ | Tips-only k x k representation: A\_{ij} is the proportion of shared branch length between species i and j divided by total tree height (Hadfield 2010) | follows from the formula |
| phylo_brownian_motion | $`\mathrm{Var}(u_p) \propto \mathrm{time}`$ | Brownian motion: phylogenetic variance accumulates linearly with branch length. If OU or Pagel’s lambda is intended, refit with that correlation structure | your_responsibility |
| phylo_ultrametric_tree | — | Tree is ultrametric (all tips equidistant from the root); non-ultrametric trees still give a valid A but break the strict Brownian-motion variance interpretation | your_responsibility |
| phylo_branch_lengths_meaningful | — | Branch lengths are on a meaningful evolutionary scale (time, substitutions per site); symbolizer cannot verify this from the fitted object | your_responsibility |
| phylo_nonphylo_identifiability | — | When both a phylogenetic and a non-phylogenetic species-level tier are estimated, the variance components are weakly identified – see warning_table() (Hadfield & Nakagawa 2010 section 3.2; Mizuno et al. 2026 section 4) | your_responsibility |
| heritability_reading | $`H^2 = \sigma_p^2 / (\sigma_p^2 + \sigma_e^2)`$ | Phylogenetic heritability: proportion of among-species variance attributable to shared evolutionary history | derived |

#### Three-views widget for the metafor fit

The
[`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md)
widget renders the same model three ways: per-observation index form,
matrix form, and the matrix equation with the actual numerical entries
of $`\mathbf A`$ visible. The interactive widget is below; a paper-ready
PDF version of the same three views is one click away.

``` r

# Scaffolding until issue #9 lands extractor-side expanded population.
# https://github.com/itchyshin/symbolizer/issues/9
shim_metafor <- function(fit, A) {
  beta <- as.numeric(fit$beta)
  X    <- fit$X
  re   <- ranef(fit)
  u_named <- as.numeric(re$species$intrcpt)
  names(u_named) <- rownames(re$species)
  Z_g  <- model.matrix(~ species - 1, data = dat)
  colnames(Z_g) <- sub("^species", "", colnames(Z_g))
  u <- u_named[colnames(Z_g)]
  # metafor's fitted() returns the MARGINAL mean (intercept only); we
  # want the CONDITIONAL mean = X*beta + Z*u so the worked-row
  # arithmetic closes with the displayed BLUP contribution.
  mu_hat <- as.numeric(X %*% beta + Z_g %*% u)
  list(y = as.numeric(fit$yi), X = X, beta = beta,
       Z_g = Z_g, u = u, mu_hat = mu_hat,
       fitted = mu_hat, residuals = as.numeric(fit$yi) - mu_hat,
       M = A)
}
sym_meta$expanded <- shim_metafor(fit_meta, A_tips)
htmltools::HTML(as_html_three_views(sym_meta, id = "meta"))
```

[Skip three-views widget](#sym-meta-1779818423-end)

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

``` math
\begin{aligned}
y_i \mid \theta_i & \sim \mathrm{Normal}(\theta_i,\, v_i), \quad v_i \text{ known} \\
\mu_i & = \beta_{0} + u_{species(i)} \\
\mathbf{u}_{species} & \sim \mathcal{N}(\mathbf{0},\, \sigma_{species}^2 \mathbf{A})
\end{aligned}
```

where:

- $`y`$ — response variable  $`\mathbb{R}^{60}`$
- $`\mu_i`$ — conditional mu of yi  $`\mathbb{R}^{60}`$
- $`\sigma_i`$ — residual heterogeneity SD (tau) of yi  scalar
- $`\beta_{0}`$ — mu submodel coefficients  $`\mathbb{R}^{1}`$
- $`u_{species(i)}`$ — random intercept by species  scalar;
  $`\mathbb{R}^{60}`$ in matrix form
- $`\sigma_{species}`$ — between-species standard deviation  scalar
- $`\mathbf{A}`$ — phylogenetic correlation matrix on species, attached
  via R = list(species = A): Sigma = sigma_p^2 \* A (tips-only k x k
  representation)  $`\mathbb{R}^{60 \times 60}`$

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
\mathbf{y} \mid \boldsymbol{\theta},\, V & \sim \mathcal{N}(\boldsymbol{\theta},\, V),\quad V \text{ known} \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} + \mathbf{u} \\
\mathbf{u}_{species} & \sim \mathcal{N}(\mathbf{0},\, \sigma_{species}^2 \mathbf{A}_{60 \times 60})
\end{aligned}
```

where:

- $`\mathbf{y}`$ — response variable  $`\mathbb{R}^{60}`$
- $`\boldsymbol{\mu}`$ — conditional mu of yi  $`\mathbb{R}^{60}`$
- $`\boldsymbol{\sigma}`$ — residual heterogeneity SD (tau) of yi
   scalar
- $`\boldsymbol{\beta}`$ — mu submodel coefficients  $`\mathbb{R}^{1}`$
- $`\mathbf{X}`$ — mu submodel design matrix
   $`\mathbb{R}^{60 \times 1}`$
- $`\mathbf{u}_{species}`$ — random intercept by species  scalar;
  $`\mathbb{R}^{60}`$ in matrix form
- $`\sigma_{species}`$ — between-species standard deviation  scalar
- $`\mathbf{A}`$ — phylogenetic correlation matrix on species, attached
  via R = list(species = A): Sigma = sigma_p^2 \* A (tips-only k x k
  representation)  $`\mathbb{R}^{60 \times 60}`$

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 60.

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
below. A random-effect indicator matrix Z_g and the predicted BLUPs u
are also shown.

For observation *i* = 1 of your data:

``` math
\begin{aligned}
y_{1} &= \hat\beta_{0} + \hat{u}_{\mathrm{Alca torda}} + \hat\varepsilon_{1} &\quad(\text{response equation, one row of the model}) \\
0.166 &= 0.374 + (-0.201) + (-0.00696) &\quad(\text{with your numbers}) \\
&= \underbrace{0.173}_{\textstyle\,\hat\mu_{1}\,\text{(predicted)}\,} \;+\; \underbrace{(-0.00696)}_{\textstyle\,\hat\varepsilon_{1}\,\text{(residual)}\,}
\end{aligned}
```

Stacking the same response equation for all *n* = 60 observations:

``` math
\underbrace{\begin{bmatrix} 0.166 \\ 1.12 \\ 0.66 \\ 1.05 \\ 0.676 \\ \vdots \\ 0.172 \\ 0.0853 \end{bmatrix}}_{\textstyle\,\mathbf{y}_{\,60 \times 1}\;\text{(observed)}\,} \;=\; \underbrace{\begin{bmatrix}    1 \\    1 \\    1 \\    1 \\    1 \\ \vdots \\    1 \\    1 \end{bmatrix}}_{\textstyle\,\mathbf{X}_{\,60 \times 1}\,}\, \underbrace{\begin{bmatrix} 0.374 \end{bmatrix}}_{\textstyle\,\hat{\boldsymbol{\beta}}_{\,1 \times 1}\;\text{(estimated)}\,} \;+\; \underbrace{\begin{bmatrix}    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \\    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \\    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \\    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \\    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \\ \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots \\    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \\    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \end{bmatrix}}_{\textstyle\,\mathbf{Z}_{\,60 \times 60}\,}\, \underbrace{\begin{bmatrix} 0.418 \\ 0.105 \\ -0.121 \\ -0.342 \\ -0.191 \\ -0.0211 \\ -0.108 \\ -0.212 \\ 0.356 \\ -0.332 \\ 0.607 \\ -0.259 \\ -0.177 \\ -0.176 \\ -0.184 \\ -0.271 \\ 0.382 \\ -0.171 \\ 0.122 \\ 0.056 \\ -0.0736 \\ -0.196 \\ -0.226 \\ -0.191 \\ 0.301 \\ 0.0879 \\ -0.185 \\ -0.00762 \\ -0.049 \\ -0.228 \\ -0.31 \\ 4.36e-06 \\ 0.089 \\ -0.214 \\ 0.0593 \\ -0.121 \\ 0.73 \\ -0.201 \\ 0.106 \\ -0.113 \\ 0.045 \\ 0.171 \\ -0.342 \\ 0.0127 \\ -0.273 \\ -0.0168 \\ -0.18 \\ -0.168 \\ -0.138 \\ -0.101 \\ -0.289 \\ -0.194 \\ -0.252 \\ 1.15 \\ -0.288 \\ 0.461 \\ -0.371 \\ -0.288 \\ -0.0504 \\ -0.0761 \end{bmatrix}}_{\textstyle\,\hat{\mathbf{u}}_{\,60 \times 1}\;\text{(BLUP)}\,} \;+\; \underbrace{\begin{bmatrix} -0.00696 \\ 0.0154 \\ -0.015 \\ 0.0695 \\ 0.246 \\ \vdots \\ -0.0184 \\ -0.0176 \end{bmatrix}}_{\textstyle\,\hat{\boldsymbol{\varepsilon}}_{\,60 \times 1}\;\text{(residual)}\,}
```

**Left**: observed vector $`\mathbf{y}`$. **Middle**: the prediction
$`\mathbf{X}\hat{\boldsymbol{\beta}} + \mathbf{Z}\hat{\mathbf{u}} = \hat{\boldsymbol{\mu}}`$.
**Right**: the residual vector
$`\hat{\boldsymbol{\varepsilon}} = \mathbf{y} - \hat{\boldsymbol{\mu}}`$.
Every row of this matrix equation is one of the response-equation rows
from the worked row above.

**And the structured-covariance prior on `u`**. The random effect that
gives this model its structural-dependence character:

``` math
\mathrm{Cov}(\hat{\mathbf{u}}) \;=\; \sigma_p^2 \cdot \underbrace{\begin{bmatrix}    1 &    0 & 0.17 & 0.185 & 0.187 & \cdots &    0 & 0.176 \\    0 &    1 &    0 &    0 &    0 & \cdots & 0.485 &    0 \\ 0.17 &    0 &    1 & 0.254 & 0.561 & \cdots &    0 & 0.792 \\ 0.185 &    0 & 0.254 &    1 & 0.279 & \cdots &    0 & 0.262 \\ 0.187 &    0 & 0.561 & 0.279 &    1 & \cdots &    0 & 0.579 \\ \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots \\    0 & 0.485 &    0 &    0 &    0 & \cdots &    1 &    0 \\ 0.176 &    0 & 0.792 & 0.262 & 0.579 & \cdots &    0 &    1 \end{bmatrix}}_{\textstyle\,\mathbf{A}_{\,60 \times 60}\,}
```

The phylo random effect $`u`$ has covariance
$`\sigma_p^2 \cdot \mathbf{A}`$, where $`\mathbf{A}`$ is the 60 × 60
phylogenetic correlation matrix. Showing the head + tail rows / columns;
full matrix is 60 × 60.

[Skip three-views widget](#sym-meta-1779818423-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* -- the per-individual reading.

Species are not independent observations. Closely related species tend
to have similar trait values because of shared evolutionary history; the
phylogenetic correlation matrix \$\mathbf{A}\$ encodes those expected
similarities (cell \$A\_{ij}\$ = fraction of shared branch length
between species \$i\$ and \$j\$). The phylogenetic SD \$\sigma_p\$
measures how much across-species variation remains after fixed-effect
predictors are accounted for.

\$\$\begin{aligned} y_i \mid \theta_i & \sim \mathrm{Normal}(\theta_i,\\
v_i), \quad v_i \text{ known} \\ \mu_i & = \beta\_{0} + u\_{species(i)}
\\ \mathbf{u}\_{species} & \sim \mathcal{N}(\mathbf{0},\\
\sigma\_{species}^2 \mathbf{A}) \end{aligned}\$\$

where:

- \$y\$ — response variable  \$\mathbb{R}^{60}\$
- \$\mu_i\$ — conditional mu of yi  \$\mathbb{R}^{60}\$
- \$\sigma_i\$ — residual heterogeneity SD (tau) of yi  scalar
- \$\beta\_{0}\$ — mu submodel coefficients  \$\mathbb{R}^{1}\$
- \$u\_{species(i)}\$ — random intercept by species  scalar;
  \$\mathbb{R}^{60}\$ in matrix form
- \$\sigma\_{species}\$ — between-species standard deviation  scalar
- \$\mathbf{A}\$ — phylogenetic correlation matrix on species, attached
  via R = list(species = A): Sigma = sigma_p^2 \* A (tips-only k x k
  representation)  \$\mathbb{R}^{60 \times 60}\$

The same model in matrix form -- the structural contract every textbook
past chapter 4 switches to.

Species are not independent observations. Closely related species tend
to have similar trait values because of shared evolutionary history; the
phylogenetic correlation matrix \$\mathbf{A}\$ encodes those expected
similarities (cell \$A\_{ij}\$ = fraction of shared branch length
between species \$i\$ and \$j\$). The phylogenetic SD \$\sigma_p\$
measures how much across-species variation remains after fixed-effect
predictors are accounted for.

\$\$\begin{aligned} \mathbf{y} \mid \boldsymbol{\theta},\\ V & \sim
\mathcal{N}(\boldsymbol{\theta},\\ V),\quad V \text{ known} \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} + \mathbf{u} \\
\mathbf{u}\_{species} & \sim \mathcal{N}(\mathbf{0},\\
\sigma\_{species}^2 \mathbf{A}\_{60 \times 60}) \end{aligned}\$\$

where:

- \$\mathbf{y}\$ — response variable  \$\mathbb{R}^{60}\$
- \$\boldsymbol{\mu}\$ — conditional mu of yi  \$\mathbb{R}^{60}\$
- \$\boldsymbol{\sigma}\$ — residual heterogeneity SD (tau) of yi
   scalar
- \$\boldsymbol{\beta}\$ — mu submodel coefficients  \$\mathbb{R}^{1}\$
- \$\mathbf{X}\$ — mu submodel design matrix  \$\mathbb{R}^{60 \times
  1}\$
- \$\mathbf{u}\_{species}\$ — random intercept by species  scalar;
  \$\mathbb{R}^{60}\$ in matrix form
- \$\sigma\_{species}\$ — between-species standard deviation  scalar
- \$\mathbf{A}\$ — phylogenetic correlation matrix on species, attached
  via R = list(species = A): Sigma = sigma_p^2 \* A (tips-only k x k
  representation)  \$\mathbb{R}^{60 \times 60}\$

The same matrix equation, with your actual numbers stacked inside the
brackets -- what the computer multiplies. Showing first 5 and last 2
rows of n = 60.

Species are not independent observations. Closely related species tend
to have similar trait values because of shared evolutionary history; the
phylogenetic correlation matrix \$\mathbf{A}\$ encodes those expected
similarities (cell \$A\_{ij}\$ = fraction of shared branch length
between species \$i\$ and \$j\$). The phylogenetic SD \$\sigma_p\$
measures how much across-species variation remains after fixed-effect
predictors are accounted for.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below. A random-effect indicator matrix Z_g and the predicted BLUPs u
are also shown.

For observation *i* = 1 of your data:

\$\$ \begin{aligned} y\_{1} &= \hat\beta\_{0} + \hat{u}\_{\mathrm{Alca
torda}} + \hat\varepsilon\_{1} &\quad(\text{response equation, one row
of the model}) \\ 0.166 &= 0.374 + (-0.201) + (-0.00696)
&\quad(\text{with your numbers}) \\ &=
\underbrace{0.173}\_{\textstyle\\\hat\mu\_{1}\\\text{(predicted)}\\}
\\+\\
\underbrace{(-0.00696)}\_{\textstyle\\\hat\varepsilon\_{1}\\\text{(residual)}\\}
\end{aligned} \$\$

Stacking the same response equation for all *n* = 60 observations:

\$\$ \underbrace{\begin{bmatrix} 0.166 \\ 1.12 \\ 0.66 \\ 1.05 \\ 0.676
\\ \vdots \\ 0.172 \\ 0.0853
\end{bmatrix}}\_{\textstyle\\\mathbf{y}\_{\\60 \times
1}\\\text{(observed)}\\} \\=\\ \underbrace{\begin{bmatrix} 1 \\ 1 \\ 1
\\ 1 \\ 1 \\ \vdots \\ 1 \\ 1
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\60 \times 1}\\}\\
\underbrace{\begin{bmatrix} 0.374
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\1 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 1 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 \\ 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 1 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 \\ 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 1 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 \\ 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 1 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 \\ 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 1 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 \\ \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots \\
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 1 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 \\ 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 1 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0
\end{bmatrix}}\_{\textstyle\\\mathbf{Z}\_{\\60 \times 60}\\}\\
\underbrace{\begin{bmatrix} 0.418 \\ 0.105 \\ -0.121 \\ -0.342 \\ -0.191
\\ -0.0211 \\ -0.108 \\ -0.212 \\ 0.356 \\ -0.332 \\ 0.607 \\ -0.259 \\
-0.177 \\ -0.176 \\ -0.184 \\ -0.271 \\ 0.382 \\ -0.171 \\ 0.122 \\
0.056 \\ -0.0736 \\ -0.196 \\ -0.226 \\ -0.191 \\ 0.301 \\ 0.0879 \\
-0.185 \\ -0.00762 \\ -0.049 \\ -0.228 \\ -0.31 \\ 4.36e-06 \\ 0.089 \\
-0.214 \\ 0.0593 \\ -0.121 \\ 0.73 \\ -0.201 \\ 0.106 \\ -0.113 \\ 0.045
\\ 0.171 \\ -0.342 \\ 0.0127 \\ -0.273 \\ -0.0168 \\ -0.18 \\ -0.168 \\
-0.138 \\ -0.101 \\ -0.289 \\ -0.194 \\ -0.252 \\ 1.15 \\ -0.288 \\
0.461 \\ -0.371 \\ -0.288 \\ -0.0504 \\ -0.0761
\end{bmatrix}}\_{\textstyle\\\hat{\mathbf{u}}\_{\\60 \times
1}\\\text{(BLUP)}\\} \\+\\ \underbrace{\begin{bmatrix} -0.00696 \\
0.0154 \\ -0.015 \\ 0.0695 \\ 0.246 \\ \vdots \\ -0.0184 \\ -0.0176
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}\_{\\60
\times 1}\\\text{(residual)}\\} \$\$

**Left**: observed vector \$\mathbf{y}\$. **Middle**: the prediction
\$\mathbf{X}\hat{\boldsymbol{\beta}} + \mathbf{Z}\hat{\mathbf{u}} =
\hat{\boldsymbol{\mu}}\$. **Right**: the residual vector
\$\hat{\boldsymbol{\varepsilon}} = \mathbf{y} -
\hat{\boldsymbol{\mu}}\$. Every row of this matrix equation is one of
the response-equation rows from the worked row above.

**And the structured-covariance prior on `u`**. The random effect that
gives this model its structural-dependence character:

\$\$ \mathrm{Cov}(\hat{\mathbf{u}}) \\=\\ \sigma_p^2 \cdot
\underbrace{\begin{bmatrix} 1 & 0 & 0.17 & 0.185 & 0.187 & \cdots & 0 &
0.176 \\ 0 & 1 & 0 & 0 & 0 & \cdots & 0.485 & 0 \\ 0.17 & 0 & 1 & 0.254
& 0.561 & \cdots & 0 & 0.792 \\ 0.185 & 0 & 0.254 & 1 & 0.279 & \cdots &
0 & 0.262 \\ 0.187 & 0 & 0.561 & 0.279 & 1 & \cdots & 0 & 0.579 \\
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots \\
0 & 0.485 & 0 & 0 & 0 & \cdots & 1 & 0 \\ 0.176 & 0 & 0.792 & 0.262 &
0.579 & \cdots & 0 & 1 \end{bmatrix}}\_{\textstyle\\\mathbf{A}\_{\\60
\times 60}\\} \$\$

The phylo random effect \$u\$ has covariance \$\sigma_p^2 \cdot
\mathbf{A}\$, where \$\mathbf{A}\$ is the 60 × 60 phylogenetic
correlation matrix. Showing the head + tail rows / columns; full matrix
is 60 × 60.

``` r

# Helper -- write the PDF next to the rendered HTML so the `<a href>` link
# resolves whether the article is built by rmarkdown::render (vignettes
# dir) or pkgdown::build_article (docs/articles). knitr's
# `opts_knit$get("output.dir")` returns the Rmd source dir, NOT the HTML
# destination, so we instead emit one PDF in the chunk cwd (= source
# dir, where rmarkdown::render's link resolves) AND if a sibling
# `../docs/articles` exists (pkgdown build), copy a second copy there.
pdf_alongside_html <- function(sym, basename, title) {
  as_pdf_three_views(sym, file = basename, title = title)
  docs_articles <- "../docs/articles"
  if (dir.exists(docs_articles)) {
    file.copy(basename, file.path(docs_articles, basename), overwrite = TRUE)
  }
  cat(sprintf('<p><a href="%s" class="btn btn-primary">Download as PDF</a></p>\n', basename))
  invisible(basename)
}
pdf_alongside_html(sym_meta, "fig-meta-phylo.pdf",
                   "Phylogenetic meta-analysis (metafor) -- three views")
```

[Download as
PDF](https://itchyshin.github.io/symbolizer/articles/fig-meta-phylo.pdf)

### Face 2: `MCMCglmm` with `ginverse = list(species = Ainv)`

`MCMCglmm` uses the **all-nodes** representation natively.

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
| mu        | species  | (Intercept) | 0.0794      | 0.00630      |
| residual  | residual | Residual    | 0.133       | 0.0177       |

``` r

sym_mcmc$metadata$heritability           # h^2 derived automatically
#> # A tibble: 1 × 5
#>   group   variance_A variance_E heritability reading                            
#>   <chr>        <dbl>      <dbl>        <dbl> <chr>                              
#> 1 species    0.00630     0.0177        0.262 Heritability h^2 = sigma^2_A / (si…
```

#### Three-views widget for the MCMCglmm fit

``` r

shim_mcmcglmm <- function(fit, dat, A) {
  beta_hat <- mean(fit$Sol[, "(Intercept)"])
  sp_cols  <- grep("^species[.]", colnames(fit$Sol), value = TRUE)
  u_named  <- colMeans(fit$Sol[, sp_cols, drop = FALSE])
  names(u_named) <- sub("^species[.]", "", names(u_named))
  Z_g <- model.matrix(~ species - 1, data = dat)
  colnames(Z_g) <- sub("^species", "", colnames(Z_g))
  u <- u_named[colnames(Z_g)]
  X <- matrix(1, nrow = nrow(dat), ncol = 1,
              dimnames = list(NULL, "(Intercept)"))
  mu_hat <- as.numeric(X %*% beta_hat + Z_g %*% u)
  list(y = dat$Zr, X = X, beta = beta_hat,
       Z_g = Z_g, u = u, mu_hat = mu_hat,
       fitted = mu_hat, residuals = dat$Zr - mu_hat,
       M = A)
}
sym_mcmc$expanded <- shim_mcmcglmm(fit_mcmc, dat, A_tips)
htmltools::HTML(as_html_three_views(sym_mcmc, id = "mcmc"))
```

[Skip three-views widget](#sym-mcmc-1779818424-end)

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

``` math
\begin{aligned}
\mathrm{Zr}_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i & = \beta_{0} + u_{species(i)} \\
\mathbf{u}_{species} & \sim \mathcal{N}(\mathbf{0},\, \sigma_{species}^2 \mathbf{A})
\end{aligned}
```

where:

- $`\mathrm{Zr}_i`$ — response variable  $`\mathbb{R}^{60}`$
- $`\mu_i`$ — conditional mu of Zr  $`\mathbb{R}^{60}`$
- $`\sigma_i`$ — residual standard deviation of Zr  scalar
- $`\beta_{0}`$ — mu submodel coefficients  $`\mathbb{R}^{1}`$
- $`u_{species(i)}`$ — random intercept by species  scalar;
  $`\mathbb{R}^{60}`$ in matrix form
- $`\sigma_{species}`$ — between-species standard deviation  scalar
- $`\mathbf{A}`$ — phylogenetic / pedigree correlation matrix on species
  (Hadfield-Nakagawa all-nodes sparse-precision representation, supplied
  via ginverse)  $`\mathbb{R}^{k_{species} \times k_{species}}`$

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
\mathbf{zr} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} + \mathbf{u} \\
\mathbf{u}_{species} & \sim \mathcal{N}(\mathbf{0},\, \sigma_{species}^2 \mathbf{A}_{60 \times 60})
\end{aligned}
```

where:

- $`\mathbf{zr}`$ — response variable  $`\mathbb{R}^{60}`$
- $`\boldsymbol{\mu}`$ — conditional mu of Zr  $`\mathbb{R}^{60}`$
- $`\boldsymbol{\sigma}`$ — residual standard deviation of Zr  scalar
- $`\boldsymbol{\beta}`$ — mu submodel coefficients  $`\mathbb{R}^{1}`$
- $`\mathbf{X}`$ — mu submodel design matrix
   $`\mathbb{R}^{60 \times 1}`$
- $`\mathbf{u}_{species}`$ — random intercept by species  scalar;
  $`\mathbb{R}^{60}`$ in matrix form
- $`\sigma_{species}`$ — between-species standard deviation  scalar
- $`\mathbf{A}`$ — phylogenetic / pedigree correlation matrix on species
  (Hadfield-Nakagawa all-nodes sparse-precision representation, supplied
  via ginverse)  $`\mathbb{R}^{k_{species} \times k_{species}}`$

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 60.

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
below. A random-effect indicator matrix Z_g and the predicted BLUPs u
are also shown.

For observation *i* = 1 of your data:

``` math
\begin{aligned}
zr_{1} &= \hat\beta_{0} + \hat{u}_{\mathrm{Alca torda}} + \hat\varepsilon_{1} &\quad(\text{response equation, one row of the model}) \\
0.166 &= 0.409 + (-0.221) + (-0.0214) &\quad(\text{with your numbers}) \\
&= \underbrace{0.188}_{\textstyle\,\hat\mu_{1}\,\text{(predicted)}\,} \;+\; \underbrace{(-0.0214)}_{\textstyle\,\hat\varepsilon_{1}\,\text{(residual)}\,}
\end{aligned}
```

Stacking the same response equation for all *n* = 60 observations:

``` math
\underbrace{\begin{bmatrix} 0.166 \\ 1.12 \\ 0.66 \\ 1.05 \\ 0.676 \\ \vdots \\ 0.172 \\ 0.0853 \end{bmatrix}}_{\textstyle\,\mathbf{zr}_{\,60 \times 1}\;\text{(observed)}\,} \;=\; \underbrace{\begin{bmatrix}    1 \\    1 \\    1 \\    1 \\    1 \\ \vdots \\    1 \\    1 \end{bmatrix}}_{\textstyle\,\mathbf{X}_{\,60 \times 1}\,}\, \underbrace{\begin{bmatrix} 0.409 \end{bmatrix}}_{\textstyle\,\hat{\boldsymbol{\beta}}_{\,1 \times 1}\;\text{(estimated)}\,} \;+\; \underbrace{\begin{bmatrix}    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \\    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \\    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \\    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \\    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \\ \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots \\    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \\    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    1 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 &    0 \end{bmatrix}}_{\textstyle\,\mathbf{Z}_{\,60 \times 60}\,}\, \underbrace{\begin{bmatrix} 0.361 \\ 0.0573 \\ -0.179 \\ -0.37 \\ -0.203 \\ -0.0656 \\ -0.147 \\ -0.225 \\  0.3 \\ -0.351 \\ 0.533 \\ -0.298 \\ -0.204 \\ -0.187 \\ -0.183 \\ -0.28 \\ 0.345 \\ -0.162 \\ 0.072 \\ 0.136 \\ -0.109 \\ -0.219 \\ -0.243 \\ -0.209 \\ 0.245 \\ 0.0515 \\ -0.2 \\ -0.0587 \\ -0.0609 \\ -0.244 \\ -0.316 \\ -0.0205 \\ 0.0496 \\ -0.226 \\ 0.0221 \\ -0.154 \\ 0.584 \\ -0.221 \\ 0.0267 \\ -0.141 \\ 0.0111 \\ 0.0982 \\ -0.383 \\ 0.0334 \\ -0.292 \\ -0.0419 \\ -0.185 \\ -0.264 \\ -0.171 \\ -0.14 \\ -0.407 \\ -0.211 \\ -0.244 \\ 0.918 \\ -0.27 \\ 0.44 \\ -0.367 \\ -0.311 \\ -0.0526 \\ -0.0991 \end{bmatrix}}_{\textstyle\,\hat{\mathbf{u}}_{\,60 \times 1}\;\text{(BLUP)}\,} \;+\; \underbrace{\begin{bmatrix} -0.0214 \\ 0.127 \\ 0.00686 \\ 0.109 \\ 0.132 \\ \vdots \\ -0.0543 \\ -0.0433 \end{bmatrix}}_{\textstyle\,\hat{\boldsymbol{\varepsilon}}_{\,60 \times 1}\;\text{(residual)}\,}
```

**Left**: observed vector $`\mathbf{zr}`$. **Middle**: the prediction
$`\mathbf{X}\hat{\boldsymbol{\beta}} + \mathbf{Z}\hat{\mathbf{u}} = \hat{\boldsymbol{\mu}}`$.
**Right**: the residual vector
$`\hat{\boldsymbol{\varepsilon}} = \mathbf{zr} - \hat{\boldsymbol{\mu}}`$.
Every row of this matrix equation is one of the response-equation rows
from the worked row above.

**And the structured-covariance prior on `u`**. The random effect that
gives this model its structural-dependence character:

``` math
\mathrm{Cov}(\hat{\mathbf{u}}) \;=\; \sigma_p^2 \cdot \underbrace{\begin{bmatrix}    1 &    0 & 0.17 & 0.185 & 0.187 & \cdots &    0 & 0.176 \\    0 &    1 &    0 &    0 &    0 & \cdots & 0.485 &    0 \\ 0.17 &    0 &    1 & 0.254 & 0.561 & \cdots &    0 & 0.792 \\ 0.185 &    0 & 0.254 &    1 & 0.279 & \cdots &    0 & 0.262 \\ 0.187 &    0 & 0.561 & 0.279 &    1 & \cdots &    0 & 0.579 \\ \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots \\    0 & 0.485 &    0 &    0 &    0 & \cdots &    1 &    0 \\ 0.176 &    0 & 0.792 & 0.262 & 0.579 & \cdots &    0 &    1 \end{bmatrix}}_{\textstyle\,\mathbf{A}_{\,60 \times 60}\,}
```

The phylo random effect $`u`$ has covariance
$`\sigma_p^2 \cdot \mathbf{A}`$, where $`\mathbf{A}`$ is the 60 × 60
phylogenetic correlation matrix. Showing the head + tail rows / columns;
full matrix is 60 × 60.

[Skip three-views widget](#sym-mcmc-1779818424-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* -- the per-individual reading.

Species are not independent observations. Closely related species tend
to have similar trait values because of shared evolutionary history; the
phylogenetic correlation matrix \$\mathbf{A}\$ encodes those expected
similarities (cell \$A\_{ij}\$ = fraction of shared branch length
between species \$i\$ and \$j\$). The phylogenetic SD \$\sigma_p\$
measures how much across-species variation remains after fixed-effect
predictors are accounted for.

\$\$\begin{aligned} \mathrm{Zr}\_i \mid \mu_i,\\ \sigma_i & \sim
\mathrm{Normal}(\mu_i,\\ \sigma_i^2) \\ \mu_i & = \beta\_{0} +
u\_{species(i)} \\ \mathbf{u}\_{species} & \sim
\mathcal{N}(\mathbf{0},\\ \sigma\_{species}^2 \mathbf{A})
\end{aligned}\$\$

where:

- \$\mathrm{Zr}\_i\$ — response variable  \$\mathbb{R}^{60}\$
- \$\mu_i\$ — conditional mu of Zr  \$\mathbb{R}^{60}\$
- \$\sigma_i\$ — residual standard deviation of Zr  scalar
- \$\beta\_{0}\$ — mu submodel coefficients  \$\mathbb{R}^{1}\$
- \$u\_{species(i)}\$ — random intercept by species  scalar;
  \$\mathbb{R}^{60}\$ in matrix form
- \$\sigma\_{species}\$ — between-species standard deviation  scalar
- \$\mathbf{A}\$ — phylogenetic / pedigree correlation matrix on species
  (Hadfield-Nakagawa all-nodes sparse-precision representation, supplied
  via ginverse)  \$\mathbb{R}^{k\_{species} \times k\_{species}}\$

The same model in matrix form -- the structural contract every textbook
past chapter 4 switches to.

Species are not independent observations. Closely related species tend
to have similar trait values because of shared evolutionary history; the
phylogenetic correlation matrix \$\mathbf{A}\$ encodes those expected
similarities (cell \$A\_{ij}\$ = fraction of shared branch length
between species \$i\$ and \$j\$). The phylogenetic SD \$\sigma_p\$
measures how much across-species variation remains after fixed-effect
predictors are accounted for.

\$\$\begin{aligned} \mathbf{zr} \mid \boldsymbol{\mu},\\
\boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\\
\mathrm{diag}(\boldsymbol{\sigma}^2)) \\ \boldsymbol{\mu} & = \mathbf{X}
\boldsymbol{\beta} + \mathbf{u} \\ \mathbf{u}\_{species} & \sim
\mathcal{N}(\mathbf{0},\\ \sigma\_{species}^2 \mathbf{A}\_{60 \times
60}) \end{aligned}\$\$

where:

- \$\mathbf{zr}\$ — response variable  \$\mathbb{R}^{60}\$
- \$\boldsymbol{\mu}\$ — conditional mu of Zr  \$\mathbb{R}^{60}\$
- \$\boldsymbol{\sigma}\$ — residual standard deviation of Zr  scalar
- \$\boldsymbol{\beta}\$ — mu submodel coefficients  \$\mathbb{R}^{1}\$
- \$\mathbf{X}\$ — mu submodel design matrix  \$\mathbb{R}^{60 \times
  1}\$
- \$\mathbf{u}\_{species}\$ — random intercept by species  scalar;
  \$\mathbb{R}^{60}\$ in matrix form
- \$\sigma\_{species}\$ — between-species standard deviation  scalar
- \$\mathbf{A}\$ — phylogenetic / pedigree correlation matrix on species
  (Hadfield-Nakagawa all-nodes sparse-precision representation, supplied
  via ginverse)  \$\mathbb{R}^{k\_{species} \times k\_{species}}\$

The same matrix equation, with your actual numbers stacked inside the
brackets -- what the computer multiplies. Showing first 5 and last 2
rows of n = 60.

Species are not independent observations. Closely related species tend
to have similar trait values because of shared evolutionary history; the
phylogenetic correlation matrix \$\mathbf{A}\$ encodes those expected
similarities (cell \$A\_{ij}\$ = fraction of shared branch length
between species \$i\$ and \$j\$). The phylogenetic SD \$\sigma_p\$
measures how much across-species variation remains after fixed-effect
predictors are accounted for.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below. A random-effect indicator matrix Z_g and the predicted BLUPs u
are also shown.

For observation *i* = 1 of your data:

\$\$ \begin{aligned} zr\_{1} &= \hat\beta\_{0} + \hat{u}\_{\mathrm{Alca
torda}} + \hat\varepsilon\_{1} &\quad(\text{response equation, one row
of the model}) \\ 0.166 &= 0.409 + (-0.221) + (-0.0214)
&\quad(\text{with your numbers}) \\ &=
\underbrace{0.188}\_{\textstyle\\\hat\mu\_{1}\\\text{(predicted)}\\}
\\+\\
\underbrace{(-0.0214)}\_{\textstyle\\\hat\varepsilon\_{1}\\\text{(residual)}\\}
\end{aligned} \$\$

Stacking the same response equation for all *n* = 60 observations:

\$\$ \underbrace{\begin{bmatrix} 0.166 \\ 1.12 \\ 0.66 \\ 1.05 \\ 0.676
\\ \vdots \\ 0.172 \\ 0.0853
\end{bmatrix}}\_{\textstyle\\\mathbf{zr}\_{\\60 \times
1}\\\text{(observed)}\\} \\=\\ \underbrace{\begin{bmatrix} 1 \\ 1 \\ 1
\\ 1 \\ 1 \\ \vdots \\ 1 \\ 1
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\60 \times 1}\\}\\
\underbrace{\begin{bmatrix} 0.409
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\1 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 1 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 \\ 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 1 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 \\ 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 1 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 \\ 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 1 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 \\ 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 1 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 \\ \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots &
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots \\
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 1 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 \\ 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 1 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 &
0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 0
\end{bmatrix}}\_{\textstyle\\\mathbf{Z}\_{\\60 \times 60}\\}\\
\underbrace{\begin{bmatrix} 0.361 \\ 0.0573 \\ -0.179 \\ -0.37 \\ -0.203
\\ -0.0656 \\ -0.147 \\ -0.225 \\ 0.3 \\ -0.351 \\ 0.533 \\ -0.298 \\
-0.204 \\ -0.187 \\ -0.183 \\ -0.28 \\ 0.345 \\ -0.162 \\ 0.072 \\ 0.136
\\ -0.109 \\ -0.219 \\ -0.243 \\ -0.209 \\ 0.245 \\ 0.0515 \\ -0.2 \\
-0.0587 \\ -0.0609 \\ -0.244 \\ -0.316 \\ -0.0205 \\ 0.0496 \\ -0.226 \\
0.0221 \\ -0.154 \\ 0.584 \\ -0.221 \\ 0.0267 \\ -0.141 \\ 0.0111 \\
0.0982 \\ -0.383 \\ 0.0334 \\ -0.292 \\ -0.0419 \\ -0.185 \\ -0.264 \\
-0.171 \\ -0.14 \\ -0.407 \\ -0.211 \\ -0.244 \\ 0.918 \\ -0.27 \\ 0.44
\\ -0.367 \\ -0.311 \\ -0.0526 \\ -0.0991
\end{bmatrix}}\_{\textstyle\\\hat{\mathbf{u}}\_{\\60 \times
1}\\\text{(BLUP)}\\} \\+\\ \underbrace{\begin{bmatrix} -0.0214 \\ 0.127
\\ 0.00686 \\ 0.109 \\ 0.132 \\ \vdots \\ -0.0543 \\ -0.0433
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}\_{\\60
\times 1}\\\text{(residual)}\\} \$\$

**Left**: observed vector \$\mathbf{zr}\$. **Middle**: the prediction
\$\mathbf{X}\hat{\boldsymbol{\beta}} + \mathbf{Z}\hat{\mathbf{u}} =
\hat{\boldsymbol{\mu}}\$. **Right**: the residual vector
\$\hat{\boldsymbol{\varepsilon}} = \mathbf{zr} -
\hat{\boldsymbol{\mu}}\$. Every row of this matrix equation is one of
the response-equation rows from the worked row above.

**And the structured-covariance prior on `u`**. The random effect that
gives this model its structural-dependence character:

\$\$ \mathrm{Cov}(\hat{\mathbf{u}}) \\=\\ \sigma_p^2 \cdot
\underbrace{\begin{bmatrix} 1 & 0 & 0.17 & 0.185 & 0.187 & \cdots & 0 &
0.176 \\ 0 & 1 & 0 & 0 & 0 & \cdots & 0.485 & 0 \\ 0.17 & 0 & 1 & 0.254
& 0.561 & \cdots & 0 & 0.792 \\ 0.185 & 0 & 0.254 & 1 & 0.279 & \cdots &
0 & 0.262 \\ 0.187 & 0 & 0.561 & 0.279 & 1 & \cdots & 0 & 0.579 \\
\vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots & \vdots \\
0 & 0.485 & 0 & 0 & 0 & \cdots & 1 & 0 \\ 0.176 & 0 & 0.792 & 0.262 &
0.579 & \cdots & 0 & 1 \end{bmatrix}}\_{\textstyle\\\mathbf{A}\_{\\60
\times 60}\\} \$\$

The phylo random effect \$u\$ has covariance \$\sigma_p^2 \cdot
\mathbf{A}\$, where \$\mathbf{A}\$ is the 60 × 60 phylogenetic
correlation matrix. Showing the head + tail rows / columns; full matrix
is 60 × 60.

``` r

pdf_alongside_html(sym_mcmc, "fig-mcmc-phylo.pdf",
                   "Phylogenetic meta-analysis (MCMCglmm) -- three views")
```

[Download as
PDF](https://itchyshin.github.io/symbolizer/articles/fig-mcmc-phylo.pdf)

The same extractor branch handles **animal models** (where `A` comes
from a pedigree, not a tree) — see *§Animal-model unification* below.

### Face 3: `glmmTMB::propto`

`glmmTMB` attaches $`\mathbf A`$ via the `propto()` covariance
structure. There is one subtle catch: `propto()` parameterises
$`\boldsymbol\Sigma = \sigma_p^2\,\mathbf A`$ with
$`\sigma_p^2`$**estimated as a free scalar**, and `glmmTMB` adds an
independent residual $`\sigma_\text{res}^2\,\mathbf I`$ unless you pass
`dispformula = ~ 0`. So the full conditional covariance under a propto
fit is

``` math
\operatorname{Cov}(\mathbf y \mid \mathbf u) \;=\; \sigma_p^2\,\mathbf A + \sigma_\text{res}^2\,\mathbf I,
```

i.e. **two** free scalars on top of $`\mathbf A`$. This is the
**phylogenetic / pedigree** pattern (Hadfield & Nakagawa 2010; Williams
et al. 2025, bioRxiv) — *not* the meta-analysis pattern. The
meta-analysis pattern is $`\boldsymbol\Sigma = \mathbf V`$ exactly (no
scalar multiplier) — `glmmTMB`’s reserved `equalto()` will deliver that,
but `equalto` isn’t yet implemented as of `glmmTMB` ≤ 1.1.11.

``` r

library(glmmTMB)
dat$g <- factor(1)
A_blk <- A_tips
rownames(A_blk) <- colnames(A_blk) <- dat$species

fit_glmm <- glmmTMB(
  y ~ 1 + propto(0 + species | g, A_blk),
  data = dat
)
sym_glmm <- symbolize(fit_glmm)
sym_glmm$metadata$phylo_representation  # "tips_only"
warning_table(sym_glmm)                 # propto_two_scalars info row
```

### Face 4: `brms::gr(species, cov = A)`

`brms` exposes the same matrix via the
[`gr()`](https://itchyshin.github.io/gllvmTMB/reference/gr.html) group
factor:

``` r

library(brms)
A_blk <- A_tips
data2 <- list(A = A_blk)

fit_brms <- brm(
  y ~ 1 + (1 | gr(species, cov = A)),
  data   = dat,
  data2  = data2,
  family = gaussian(),
  chains = 2, iter = 2000, refresh = 0
)
sym_brms <- symbolize(fit_brms)
sym_brms$metadata$phylo_representation  # "tips_only"
```

### Face 5: `drmTMB::phylo()`

`drmTMB` exposes the marker directly in the formula:

``` r

library(drmTMB)
fit_drm <- drmTMB(
  y ~ phylo(1 | species, tree = tree),
  family = gaussian(),
  data   = dat
)
sym_drm <- symbolize(fit_drm)
sym_drm$metadata$phylo_representation  # "all_nodes" (HN sparse precision)
```

### Face 6: `gllvmTMB::phylo_unique()`

`gllvmTMB` adds the phylogenetic layer to a latent-variable structure
(community phylogenetics; Williams et al. 2025, *MEE*). The latent axes
themselves are phylogenetically structured:

``` r

library(gllvmTMB)
fit_gllvm <- gllvmTMB(
  y_long ~ 0 + trait + phylo_unique(0 + trait | species, tree = tree),
  family = gaussian(),
  data   = dat_long
)
sym_gllvm <- symbolize(fit_gllvm)
sym_gllvm$metadata$phylo_representation  # "package_managed"
```

The cross-package agreement story is the point: every fit above attaches
the same conceptual object — a phylogenetic correlation matrix
$`\mathbf A`$ on a random-effect block — even though the syntactic
surface looks different in each package. `symbolizer` produces the same
`metadata$detected_signals = "phylo"`, the same symbol-dictionary row
for $`\mathbf A`$, the same gated phylogenetic assumption rows, no
matter which package fitted the model.

## Animal-model unification

The phylogenetic random effect is the **same mathematical object** as
the additive-genetic random effect in a quantitative-genetics animal
model. The matrix $`\mathbf A`$ comes from a different source (a
pedigree of dam-sire-offspring rather than a phylogenetic tree), but its
meaning in the model is identical:

``` math
\mathbf u_a \;\sim\; \mathcal N(\mathbf 0, \sigma_A^2\,\mathbf A),\qquad
h^2 \;=\; \frac{\sigma_A^2}{\sigma_A^2 + \sigma_e^2}.
```

The only interpretation difference is what $`\sigma_A^2`$*means*:
phylogenetic variance among species in a phylogenetic comparative
method, additive genetic variance among individuals in a
quantitative-genetics animal model. `symbolizer`’s
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
    only). Inverting the tips-only $`k \times k`$ matrix is
    $`\mathcal O(k^3)`$; the sparse A-inverse path is much faster for
    $`k > \sim 200`$.
3.  **Partial observations**. If some species have measured traits and
    others are unobserved (but on the tree), the all-nodes form handles
    this naturally.

On a balanced setup with all species observed, both representations give
the same $`\hat\sigma_p^2`$ to machine precision — the Hadfield-Nakagawa
equivalence.

## Spatial: same grammar, different matrix

For spatial dependence, $`\mathbf M`$ is built from pairwise geographic
distances and a kernel. The standard choices are:

| Kernel | Formula | Decay |
|----|----|----|
| Exponential | $`C(d) = \exp(-d/\rho)`$ | Power |
| Squared-exponential (Gaussian) | $`C(d) = \exp(-d^2/\rho^2)`$ | Sharp |
| Matérn | $`C(d; \kappa, \nu)`$ | Tunable smoothness |

Two fits demonstrate the structurally identical grammar with
$`\boldsymbol\Omega`$ in place of $`\mathbf A`$:

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

``` math
y_i = \beta_0 + u_{p_{k[i]}} + u_{s_{k[i]}} + e_i,\qquad
u_p \sim \mathcal N(0, \sigma_p^2 \mathbf A),\quad
u_s \sim \mathcal N(0, \sigma_s^2 \mathbf I),
```

the variance components $`\sigma_p^2`$ and $`\sigma_s^2`$ are *weakly
identified*: their sum is precisely estimable but the split between them
is not (Hadfield & Nakagawa 2010 §3.2; Mizuno et al. 2026 §4). With
strong phylogenetic signal (Pagel’s λ near 1) the split is informative;
with weak signal (λ near 0) the data have almost no leverage to separate
the two. `symbolizer` emits a `phylo_nonphylo_unidentifiable` row in
[`warning_table()`](https://itchyshin.github.io/symbolizer/reference/warning_table.md)
when this configuration is detected. Profile on λ or fix one tier to
resolve.

## Forward links

- **v0.22 — Phylogenetic meta-analysis (Mizuno et al. 2026)**. This
  article fits the general phylo-GLMM with $`\sigma_e^2`$*estimated*.
  The meta-analytic case where the sampling variance $`v_i`$ is
  **known** per study is its own surface — `metafor::rma.mv(V = V, ...)`
  is the canonical interface, with `glmmTMB::equalto` (reserved) and
  `brms::se(sqrt(vi))` as bridges.
- **v0.24 — Location-scale on $`\mathbf M`$ (Nakagawa et al. 2025
  *MEE*)**. The dependence parameter itself can have a submodel:
  $`\sigma_p \sim z`$ across clades, $`\rho \sim z`$ across
  environments. Symbolizer’s drmTMB extractor is the right home for the
  phylogenetic location-scale model.
- **drmTMB deep dives**:
  [`vignette("phylogenetic-models", package = "drmTMB")`](https://itchyshin.github.io/drmTMB/articles/phylogenetic-models.html),
  [`vignette("animal-models", package = "drmTMB")`](https://itchyshin.github.io/drmTMB/articles/animal-models.html),
  [`vignette("structural-dependence", package = "drmTMB")`](https://itchyshin.github.io/drmTMB/articles/structural-dependence.html).
- **gllvmTMB deep dive**:
  `vignette("phylogenetic-gllvm", package = "gllvmTMB")`.

## References

- Hadfield, J. D. (2010). MCMC methods for multi-response generalized
  linear mixed models: the `MCMCglmm` R package. *Journal of Statistical
  Software*, 33(2), 1–22.
- Hadfield, J. D. & Nakagawa, S. (2010). General quantitative genetic
  methods for comparative biology: phylogenies, taxonomies and
  multi-trait models for continuous and categorical characters. *Journal
  of Evolutionary Biology*, 23, 494–508.
- Lynch, M. (1991). Methods for the analysis of comparative data in
  evolutionary biology. *Evolution*, 45(5), 1065–1080.
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
