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
  library(ape)
  library(MCMCglmm)
})

# A toy ultrametric tree with k = 15 species.
tree <- rcoal(15, tip.label = paste0("sp", 1:15))

# Representation 1 -- tips-only k x k correlation matrix
A_tips <- vcv.phylo(tree, corr = TRUE)
dim(A_tips)
#> [1] 15 15

# Representation 2 -- all-nodes A-inverse (tips + internal nodes,
# sparse precision; Hadfield-Nakagawa 2010).
A_all  <- inverseA(tree, nodes = "ALL")
dim(A_all$Ainv)
#> [1] 28 28
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

We simulate a small phylogenetic trait dataset, then fit the same model
six different ways. The model is

``` math
y_i \;=\; \beta_0 + u_{p_{k[i]}} + e_i,\qquad
u_p \sim \mathcal N(\mathbf 0, \sigma_p^2\,\mathbf A),\quad
e_i \sim \mathcal N(0, \sigma_e^2).
```

``` r

k <- nlevels(factor(tree$tip.label))
sigma_p <- 0.7; sigma_e <- 0.3
u_p <- as.numeric(MASS::mvrnorm(1, mu = rep(0, k), Sigma = sigma_p^2 * A_tips))
dat <- data.frame(
  species = factor(tree$tip.label, levels = tree$tip.label),
  y       = u_p + rnorm(k, 0, sigma_e)
)
# Sampling variance "v_i" for the meta-analysis-style fits.
dat$vi <- runif(k, 0.05, 0.15)
```

### Face 1: `metafor::rma.mv` with `R = list(species = A)`

``` r

suppressPackageStartupMessages(library(metafor))

fit_meta <- rma.mv(
  yi      = y,
  V       = vi,                # known sampling variances
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
u_{species} \sim \mathcal{N}(0,\, \sigma_{species}^2)
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

### Face 2: `MCMCglmm` with `ginverse = list(species = Ainv)`

`MCMCglmm` uses the **all-nodes** representation natively.

``` r

fit_mcmc <- MCMCglmm(
  y ~ 1,
  random   = ~ species,
  ginverse = list(species = A_all$Ainv),
  data     = dat,
  family   = "gaussian",
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
| mu        | species  | (Intercept) | 0.344       | 0.118        |
| residual  | residual | Residual    | 0.340       | 0.116        |

``` r

sym_mcmc$metadata$heritability           # h^2 derived automatically
#> # A tibble: 1 × 5
#>   group   variance_A variance_E heritability reading                            
#>   <chr>        <dbl>      <dbl>        <dbl> <chr>                              
#> 1 species      0.118      0.116        0.505 Heritability h^2 = sigma^2_A / (si…
```

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
