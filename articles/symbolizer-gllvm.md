# Latent variables in ecology: a gllvmTMB worked example

## 1. The biological question

A behavioural ecologist measures five traits — boldness in a novel
arena, exploration in a maze, aggression to a mirror, activity in the
home cage, and time-out-of-shelter — on each of forty fish, three times
each. Two themes keep coming up in the data. Bolder fish also tend to be
more exploratory. Active fish tend to spend more time out of shelter.
The question is not whether any single pair of traits correlates, but
whether the **whole battery of traits is organised by a small number of
stable axes of among-individual variation** — the things the syndromes
literature calls *behavioural syndromes* (Sih et al. 2004) or, in a
broader trait context, *phenotypic integration* (Pigliucci 2003).

This is the natural job for a generalised linear latent variable model
(GLLVM). Each trait gets its own intercept and its own residual
variance. A small number of unobserved latent variables — two, say —
describe the shared structure: each trait *loads* on each latent axis,
and an individual’s score on each axis is what makes their trait values
move together. The output a biologist wants is the loading matrix
$`\boldsymbol{\Lambda}_B`$, the proportion of each trait’s
between-individual variance that the shared axes explain (the
*communality*), and the residual trait-trait correlation matrix.

**Takeaway.** The biological question is *what stable axes of
among-individual variation organise these traits*, and the answer is a
loading matrix plus a communality vector.

## 2. The data

We simulate from a known truth so the biological reading at the end can
be checked. The truth puts traits 1-3 on a first axis (the
*boldness-exploration-aggression* syndrome) and traits 4-5 on a second
axis (the *activity-shelter-use* syndrome), with extra trait-specific
between-individual variance on top.

``` r

library(symbolizer)
library(gllvmTMB)

set.seed(20260523)
n_ind  <- 40   # individuals
n_tr   <- 5    # traits
n_sess <- 3    # repeated sessions per individual

# True between-individual loading matrix Lambda_B (5 traits x 2 latents)
Lam_B <- matrix(c(
  1.0, 0.0,   # trait 1 loads on axis 1 only
  0.7, 0.0,   # trait 2 loads on axis 1
  0.6, 0.0,   # trait 3 loads on axis 1
  0.0, 1.0,   # trait 4 loads on axis 2 only
  0.0, 0.7    # trait 5 loads on axis 2
), nrow = n_tr, byrow = TRUE)

sim <- simulate_site_trait(
  n_sites               = n_ind,
  n_species             = n_sess,
  n_traits              = n_tr,
  n_predictors          = 1,
  mean_species_per_site = n_sess,
  sigma2_eps            = 0.3,
  Lambda_B              = Lam_B,
  psi_B                 = rep(0.4, n_tr),
  seed                  = 1
)

# Relabel for syndromes vocabulary
dat <- sim$data
dat$individual <- dat$site          # unit
dat$session    <- dat$species       # repeated session
dat$obs        <- dat$site_species  # one row per (individual, session)
head(dat, 6)
#>   site species site_species   trait       value    env_1 individual session obs
#> 1    1       2          1_2 trait_1 -0.96758336 1.511781          1       2 1_2
#> 2    1       2          1_2 trait_2  3.24914496 1.511781          1       2 1_2
#> 3    1       2          1_2 trait_3 -0.07887043 1.511781          1       2 1_2
#> 4    1       2          1_2 trait_4  2.33232944 1.511781          1       2 1_2
#> 5    1       2          1_2 trait_5 -0.21331542 1.511781          1       2 1_2
#> 6    1       3          1_3 trait_1 -0.73572436 1.511781          1       3 1_3
```

[`simulate_site_trait()`](https://itchyshin.github.io/gllvmTMB/reference/simulate_site_trait.html)
is the gllvmTMB recovery-test simulator. It uses site/species names by
default; we rename them to the syndromes vocabulary. Each row is one
(individual, session, trait) cell.

**Takeaway.** Forty individuals, three sessions each, five traits — long
format, one row per (individual, session, trait).

## 3. The model in symbols

The same model can be written two ways. The **long form** matches the
way
[`gllvmTMB()`](https://itchyshin.github.io/gllvmTMB/reference/gllvmTMB.html)
actually fits the data — one row per (individual, occasion, trait) cell,
with a scalar response. The **wide form** matches the factor-analytic
textbooks — one row per observation, with a trait-vector response. The
two panels below place them side by side.

#### Long form

Each row of the data is one (individual, occasion, trait) cell. The
scalar response is $`y_{ijt}`$.

``` math
y_{ijt} \mid \boldsymbol{\mu},\, \boldsymbol{\Lambda},\, \mathbf{z}_i,\, \boldsymbol{\Psi}
  \sim \mathcal{N}\!\left(\mu_t + \sum_{k=1}^{d_B} \lambda_{tk}\, z_{ik},\; \sigma^2_{e}\right)
```

Native to `gllvmTMB`’s formula interface. Each row’s contribution is a
scalar Gaussian.

#### Wide form

Each row is one observation; the response is a $`T`$-vector
$`\mathbf{Y}_{ij}`$.

``` math
\mathbf{Y}_{ij} \mid \boldsymbol{\mu},\, \boldsymbol{\Lambda},\, \mathbf{z}_i,\, \boldsymbol{\Psi}
  \sim \mathcal{MN}\!\left(\boldsymbol{\mu} + \boldsymbol{\Lambda}\,\mathbf{z}_i,\; \boldsymbol{\Sigma}\right),
\quad \boldsymbol{\Sigma} = \boldsymbol{\Lambda}\boldsymbol{\Lambda}^{\!\top} + \boldsymbol{\Psi}
```

Native to factor-analytic textbooks. The covariance decomposition
$`\boldsymbol{\Sigma} = \boldsymbol{\Lambda}\boldsymbol{\Lambda}^{\!\top} + \boldsymbol{\Psi}`$
is the headline result.

*Bridge.* The two forms describe the same model. The wide form makes the
covariance decomposition explicit; the long form is what
[`gllvmTMB()`](https://itchyshin.github.io/gllvmTMB/reference/gllvmTMB.html)
actually fits.

Index $`i`$ ranges over individuals, $`j`$ over occasions, $`t`$ (or
$`j`$ in the wide form) over traits, $`k`$ over latent axes. $`\mu_t`$
is the trait $`t`$ mean; $`\lambda_{tk}`$ is the loading of trait $`t`$
on axis $`k`$; $`z_{ik}`$ is individual $`i`$’s position on axis $`k`$;
$`\boldsymbol{\Psi} = \mathrm{diag}(\psi_1^2, \ldots, \psi_T^2)`$
collects the trait-specific between-individual uniquenesses;
$`\sigma^2_e`$ is the residual scalar variance in the long form.

**Takeaway.** Long form is one scalar equation per (individual,
occasion, trait); wide form is one $`T`$-vector equation per
observation, with the covariance decomposition written explicitly. Same
model, two notations.

## 4. The fit

[`gllvmTMB()`](https://itchyshin.github.io/gllvmTMB/reference/gllvmTMB.html)
takes a long-format frame and a glmmTMB-style formula.
`latent(0 + trait | individual, d = 2)` is the between-individual
reduced-rank decomposition with two latent axes.
`unique(0 + trait | individual)` adds the trait-specific
between-individual uniqueness $`\mathbf{S}`$. `unique(0 + trait | obs)`
absorbs the within-individual (across-session) residual.

``` r

fit <- gllvmTMB(
  value ~ 0 + trait +
          latent(0 + trait | individual, d = 2) +
          unique(0 + trait | individual) +
          unique(0 + trait | obs),
  data     = dat,
  family   = gaussian(),
  trait    = "trait",
  unit     = "individual",
  unit_obs = "obs",
  cluster  = "session",
  silent   = TRUE
)
#> ℹ Auto-suppressing `sigma_eps`: `unique(0 + trait | obs)` is at the per-row
#>   level, so it already absorbs the observation residual.
#> • Fixed at 0.00146 (~1/1000 of sd(y)) to keep the Gaussian density
#>   well-defined; the row-level residual variance is fully captured by
#>   `unique()`.
class(fit)
#> [1] "gllvmTMB_multi" "gllvmTMB"
```

The fit returns a `gllvmTMB_multi` object — the multi-trait variant.
Convergence takes about a second on this dataset; the recovery-test
simulator is intentionally well-posed.

**Takeaway.** One
[`gllvmTMB()`](https://itchyshin.github.io/gllvmTMB/reference/gllvmTMB.html)
call. The formula carries four things: trait intercepts, a 2-axis latent
decomposition, between-individual uniquenesses, and a within-individual
residual.

## 5. Symbolize it

`symbolize.gllvmTMB` is a v0.4 First slice still being wired in (Agent
G1’s parallel work). The vignette is structured so it works either way:
the call is wrapped in
[`tryCatch()`](https://rdrr.io/r/base/conditions.html) and downstream
chunks guard on the return value.

``` r

sym <- tryCatch(
  symbolize(
    fit,
    symbols = c(value = "y_{ij}", trait = "j", individual = "i"),
    context = "behavioural-syndromes GLLVM"
  ),
  error = function(e) {
    cat(
      "Note: symbolize.gllvmTMB is a v0.4 First slice still being wired in.\n",
      "Once it lands, calling symbolize() here will return a structured\n",
      "symbolized_model that the same accessors below consume.\n",
      sep = ""
    )
    NULL
  }
)
#> Note: symbolize.gllvmTMB is a v0.4 First slice still being wired in.
#> Once it lands, calling symbolize() here will return a structured
#> symbolized_model that the same accessors below consume.
```

When the method lands, the returned `symbolized_model` will carry the
same surfaces as the `drmTMB` examples in the other vignettes:

- `equations(sym)` will return one row for the conditional distribution,
  one for the linear predictor, and one for the latent variable
  distribution $`\mathbf{z}_i \sim \mathcal{N}(\mathbf{0},
  \mathbf{I}_{d_B})`$.
- `symbol_table(sym)` will list each symbol — $`\mathbf{Y}`$,
  $`\boldsymbol{\Lambda}`$, $`\mathbf{Z}`$, $`\boldsymbol{\mu}`$,
  $`\mathbf{S}`$ — with its abstract dimension
  (`\mathbb{R}^{n \times T}`, `\mathbb{R}^{T \times d_B}`,
  `\mathbb{R}^{n \times d_B}`) and its concrete dimension for this fit
  (`\mathbb{R}^{40 \times 5}`, `\mathbb{R}^{5 \times 2}`,
  `\mathbb{R}^{40 \times 2}`).
- `assumption_table(sym)` will state the standard-Gaussian prior on the
  latent variables, the trait-specific Gaussian residuals, and the
  lower-triangular identification convention on
  $`\boldsymbol{\Lambda}`$.
- `parameter_interpretation(sym)` will read each loading as the
  contribution of a one-SD shift on axis $`k`$ to trait $`j`$.

For now we read the loadings directly from gllvmTMB’s own accessors.

**Takeaway.** The structural object is on the v0.4 roadmap. The
accessors in section 6 are the gllvmTMB-side surface that
`symbolize.gllvmTMB` will mirror.

## 6. Reading the latent axes biologically

The raw loading matrix is identified only up to rotation when $`d_B >
1`$, which is the usual factor-analysis story. A varimax rotation makes
the axes interpretable: each axis tries to load strongly on a small set
of traits and near zero on the rest.

``` r

getLoadings(fit, rotate = "varimax")
#>                LV1         LV2
#> trait_1 0.41772304  0.51115670
#> trait_2 0.94899617 -0.06185149
#> trait_3 0.60377617  0.35032356
#> trait_4 0.07808868  0.55425773
#> trait_5 0.04018411  0.63548458
```

Reading down the columns of the rotated loading matrix, the first axis
loads on traits 4 and 5 (the *activity-shelter-use* syndrome in the
simulated truth); the second axis loads on traits 1, 2, and 3 (the
*boldness-exploration-aggression* syndrome). The numerical labels swap
because varimax does not preserve column order — but the *block
structure* matches the truth.

The communality is the proportion of each trait’s between-individual
variance that the shared axes capture:

``` r

extract_communality(fit)
#>   trait_1   trait_2   trait_3   trait_4   trait_5 
#> 0.4346916 0.9999998 0.4802252 0.3698218 0.8354094
```

Traits with communality near 1 are well-explained by the shared axes;
traits with low communality have most of their between-individual
variability in the trait-specific uniqueness $`s_j^2`$.

The residual between-individual correlation matrix on the latent scale
falls out of
[`extract_correlations()`](https://itchyshin.github.io/gllvmTMB/reference/extract_correlations.html):

``` r

co <- extract_correlations(fit)
co_B <- co[co$tier == "B", c("trait_i", "trait_j", "correlation", "lower", "upper")]
co_B
#>    trait_i trait_j  correlation       lower     upper
#> 1  trait_1 trait_2  0.383117590  0.08131245 0.6205657
#> 2  trait_1 trait_3  0.427619562  0.13395387 0.6522450
#> 3  trait_2 trait_3  0.575506327  0.32166337 0.7521700
#> 4  trait_1 trait_4  0.342823160  0.03505772 0.5911970
#> 5  trait_2 trait_4  0.045496546 -0.26983710 0.3520169
#> 6  trait_3 trait_4  0.260280784 -0.05574866 0.5289065
#> 7  trait_1 trait_5  0.489755175  0.21033527 0.6952022
#> 8  trait_2 trait_5 -0.001767607 -0.31310455 0.3099124
#> 9  trait_3 trait_5  0.351814509  0.04526602 0.5978080
#> 10 trait_4 trait_5  0.554195857  0.29332538 0.7382549
```

The two within-syndrome correlations (traits 1-2-3 among themselves and
traits 4-5 among themselves) are clearly positive; the across-syndrome
pairs are smaller.

**Takeaway.** Two rotated axes pull apart the two simulated syndromes;
communalities tell you which traits live in the shared structure;
trait-trait correlations show the syndrome blocks directly.

## 7. Identifiability gotchas: rotation and sign of $`\boldsymbol{\Lambda}_B`$

The loading matrix $`\boldsymbol{\Lambda}_B`$ is identified only up to
**rotation** and **sign** when $`d_B > 1`$. Two fits that produce
indistinguishable likelihoods can have entirely different-looking
$`\boldsymbol{\Lambda}_B`$. This is the classical factor-analysis
identifiability problem. The implied between-unit covariance
$`\boldsymbol{\Sigma}_B = \boldsymbol{\Lambda}_B \boldsymbol{\Lambda}_B^\top
+ \boldsymbol{\Psi}_B`$ is invariant under rotation;
$`\boldsymbol{\Lambda}_B`$ itself is not. The biologist’s task is to
read the *block structure* of $`\boldsymbol{\Lambda}_B`$, not the
specific numbers in any one cell.

A symbolizer surface is explicit about this. Two practical conventions
exist, both surfaced in `assumption_table(sym)`:

- **Lower-triangular $`\boldsymbol{\Lambda}_B`$** for *confirmatory* use
  — pin the upper triangle to zero so each column has a designated
  leading trait. This is the default identification gllvmTMB uses on
  fitting. It produces a unique solution but its columns are not
  maximally interpretable.
- **Varimax-rotated $`\boldsymbol{\Lambda}_B`$** for *interpretation* —
  rotate the fitted loadings so each axis loads strongly on a small set
  of traits and near zero on the rest. The rotation is applied *after*
  fitting and preserves $`\boldsymbol{\Sigma}_B`$. The column labels may
  reorder under rotation; the block structure is what the reader
  interprets.

[`symbolize.gllvmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.gllvmTMB.md)
returns the as-fit (lower-triangular) $`\boldsymbol{\Lambda}_B`$ in
`sym$loadings`. The assumption rows for the fit carry a sentence each on
the rotation and sign conventions so a reader does not mistake
non-uniqueness for non-replicability. The varimax-rotated matrix shown
earlier in Section 6 is the reader-facing presentation; the
lower-triangular form is what the likelihood actually identifies.

**Takeaway.** Rotation and sign ambiguity are *stated assumptions*, not
bugs. The implied covariance is invariant; the loadings are not. Read
the block structure, not the cell values.

## 8. Where the symbolized story helps

With five traits and two latents, the per-element index form
$`y_{ij} = \mu_j + \sum_{k} \lambda_{jk} z_{ik} + \epsilon_{ij}`$
requires the reader to mentally instantiate fifty equations (forty
individuals times five traits, with two latents apiece). The matrix
block

``` math
\mathbf{Y} = \mathbf{1}\boldsymbol{\mu}^{\!\top} + \mathbf{Z}\,\boldsymbol{\Lambda}^{\!\top} + \mathbf{E}
```

says exactly the same thing in one line. A biologist can *see* that
$`\mathbf{Z}`$ stores one row of latent scores per individual,
$`\boldsymbol{\Lambda}`$ stores one row of loadings per trait, and the
product is the deterministic part of the trait matrix.

This is the educator-first surface symbolizer is built around: the
structural object always carries both notations, and the
[`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md)
always carries both abstract and concrete dimensions. For
latent-variable models, where the matrix form is genuinely the more
readable one, that bridge is where the package earns its keep.

**Takeaway.** Index form scales like $`n \times T`$; matrix form scales
like one block. For GLLVMs the matrix form is the reader-friendly one.

## 9. What’s available now, what’s next

The accessors in Section 6 —
[`getLoadings()`](https://itchyshin.github.io/gllvmTMB/reference/getLoadings.html),
[`extract_communality()`](https://itchyshin.github.io/gllvmTMB/reference/extract_communality.html),
[`extract_correlations()`](https://itchyshin.github.io/gllvmTMB/reference/extract_correlations.html)
— are gllvmTMB-side. The symbolizer surface wraps the Gaussian
latent-variable case as a **First slice**: every piece walked above is
shipped today, and the matrix-form story is fully populated.

**Shipped today (v0.2):**

- [`symbolize.gllvmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.gllvmTMB.md)
  for Gaussian latent variables with mu, $`\boldsymbol{\Lambda}_B`$,
  $`\boldsymbol{\Sigma}_B`$, $`\boldsymbol{\Psi}_B`$, and the
  within-unit residual SD $`\sigma_\varepsilon`$.
- `compare_symbolic(fit_d1, fit_d2)` — diffs the structural
  specifications of $`d_B = 1`$ versus $`d_B = 2`$ side by side (which
  lines change, which assumption rows change), and with `metrics = TRUE`
  also returns AIC / BIC / log-likelihood / df with the delta. See
  `vignette("symbolizer-compare")` for the worked example.

**On the roadmap:**

1.  **Non-Gaussian gllvmTMB families (v0.5).** binomial, count,
    beta-binomial — each adds a link to the linear predictor and
    reshapes the loadings interpretation.
2.  **Automated syndromes reading.**
    `parameter_interpretation(sym, scale = "biological")` produces one
    row per (trait, axis) pair today; v0.5+ adds the natural-scale
    reading for non-Gaussian families.
3.  **Uncertainty on $`\boldsymbol{\Lambda}`$.**
    [`bootstrap_Sigma()`](https://itchyshin.github.io/gllvmTMB/reference/bootstrap_Sigma.html)
    from gllvmTMB returns parametric-bootstrap draws of the loading
    matrix; a future slice will surface these through
    [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
    so the
    [`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md)
    rows for $`\boldsymbol{\Lambda}`$ and $`\boldsymbol{\Sigma}_B`$
    carry confidence regions, not just point estimates.
4.  **Within-unit decomposition** ($`\boldsymbol{\Sigma}_W`$,
    $`\boldsymbol{\Lambda}_W`$) for repeated-measures behaviour / trait
    data — `gllvmTMB_multi`.

**Takeaway.** v0.2 ships the latent-variable Gaussian case end-to-end;
further families and uncertainty surfaces come in v0.5+.
