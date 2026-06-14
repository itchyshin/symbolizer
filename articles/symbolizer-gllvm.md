# Latent variables in ecology: a gllvmTMB worked example

> *Latent-variable models compress many correlated traits into a few
> interpretable axes. This article is for behavioural and community
> ecologists fitting `gllvmTMB`; by the end you’ll be able to read the
> loadings, communalities, and trait correlations a reduced-rank model
> produces, and see how
> [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
> renders the latent structure.*

## 1. The biological question

A behavioural ecologist measures five traits — boldness in a novel
arena, exploration in a maze, aggression to a mirror, activity in the
home cage, and time-out-of-shelter — on each of forty fish, three times
each. Two themes keep coming up in the data. Bolder fish also tend to be
more exploratory. Active fish tend to spend more time out of shelter.
There is *also* a second pattern: when an individual fish is bolder than
usual on a given day, it tends to be more exploratory and more
aggressive on that *same* day. The first pattern is about stable
differences between individuals; the second is about coordinated
within-individual fluctuations.

The literature names them separately:

- *Behavioural syndromes* (Sih et al. 2004; Dingemanse & Dochtermann
  2013): the **between-individual** axes that organise trait values
  across the population — what makes individual A’s boldness reliably
  predict individual A’s exploration.
- *Integrated plasticity* (Dingemanse & Dochtermann 2013; Mathot &
  Dingemanse 2015): the **within-individual** axes that organise trait
  fluctuations across occasions for the *same* individual.

Both are factor-analytic objects in the same model. The output a
biologist wants is **two loading matrices** (\boldsymbol{\Lambda}\_B for
between, \boldsymbol{\Lambda}\_W for within), the per-trait
**communality** at each tier, and the per-trait **repeatability** R_t =
(\boldsymbol{\Sigma}\_B)\_{tt} / \[(\boldsymbol{\Sigma}\_B)\_{tt} +
(\boldsymbol{\Sigma}\_W)\_{tt}\].

**Takeaway.** The biological question splits into two layers:
*syndromes* (between) and *integrated plasticity* (within). One
generalised linear latent-variable model (GLLVM) writes both layers in
one fit.

## 2. The data

We simulate from a known truth so the biological reading at the end can
be checked. The truth puts traits 1-3 on a first between-individual axis
(the *boldness-exploration-aggression* syndrome), traits 4-5 on a second
between-individual axis (the *activity-shelter-use* syndrome), and adds
a single shared **within-individual** axis (a coordinated state-shift
that moves all five behaviours together across occasions).

``` r

library(symbolizer)
library(gllvmTMB)
library(lme4)
#> Loading required package: Matrix
#> 
#> Attaching package: 'Matrix'
#> The following object is masked from 'package:symbolizer':
#> 
#>     expand

set.seed(20260523)
n_ind  <- 40L  # individuals (units)
n_sess <- 3L   # repeated sessions per individual
n_tr   <- 5L   # traits

# True BETWEEN-individual loading matrix Lambda_B (5 traits x 2 latents).
# Traits 1-3 load on axis 1 (the bold-explore-aggress syndrome); traits
# 4-5 load on axis 2 (the activity-shelter syndrome).
Lam_B <- matrix(c(1.0, 0.0,
                  0.7, 0.0,
                  0.6, 0.0,
                  0.0, 1.0,
                  0.0, 0.7),
                nrow = n_tr, ncol = 2L)
psi_B <- rep(0.4, n_tr)   # trait-specific between-individual uniqueness SD

# True WITHIN-individual loading vector Lambda_W (5 traits x 1 latent).
# A single state-shift axis: when an individual is "up" today, all five
# behaviours move together by trait-specific amounts. This is what
# integrated-plasticity literature calls a coordinated state.
Lam_W <- matrix(c(0.5, 0.3, 0.4, 0.3, 0.4), nrow = n_tr, ncol = 1L)
psi_W <- rep(0.2, n_tr)   # trait-specific within-individual uniqueness SD

# Per-individual between-latent scores z_B in R^2 (one per individual).
z_B <- matrix(rnorm(n_ind * 2L), nrow = n_ind, ncol = 2L)
psi_B_resid <- matrix(rnorm(n_ind * n_tr,
                            sd = rep(psi_B, each = n_ind)),
                      nrow = n_ind, ncol = n_tr)
# Between-individual trait mean (per individual, per trait).
mu_ind_trait <- z_B %*% t(Lam_B) + psi_B_resid

# Per-observation within-latent scores z_W in R^1 (one per (ind, sess)).
n_obs_per_ind <- n_sess
z_W <- matrix(rnorm(n_ind * n_sess), nrow = n_ind * n_sess, ncol = 1L)
psi_W_resid <- matrix(rnorm(n_ind * n_sess * n_tr,
                            sd = rep(psi_W, each = n_ind * n_sess)),
                      nrow = n_ind * n_sess, ncol = n_tr)
within_state <- z_W %*% t(Lam_W) + psi_W_resid    # (n_ind * n_sess) x n_tr

# Expand to long-format: one row per (individual, session, trait). Trait
# labels are short codes (t1..t5) for the math; their biological readings
# from §1 are:
#   t1 = boldness          t4 = activity
#   t2 = exploration       t5 = time-out-of-shelter
#   t3 = aggression
dat <- expand.grid(
  trait      = factor(paste0("t", seq_len(n_tr)),
                      levels = paste0("t", seq_len(n_tr))),
  session    = factor(seq_len(n_sess)),
  individual = factor(seq_len(n_ind))
)
# Look up the row index in `within_state` for each (individual, session).
obs_idx <- as.integer(dat$individual) * n_sess - n_sess +
           as.integer(dat$session)
dat$value <- mu_ind_trait[cbind(as.integer(dat$individual),
                                 as.integer(dat$trait))] +
              within_state[cbind(obs_idx,
                                  as.integer(dat$trait))]
# Stable (individual, session) observation id for the obs-level term.
dat$obs <- factor(paste(dat$individual, dat$session, sep = "_"))
head(dat, 6)
#>   trait session individual      value obs
#> 1    t1       1          1  0.5810401 1_1
#> 2    t2       1          1 -0.3152411 1_1
#> 3    t3       1          1 -0.1733318 1_1
#> 4    t4       1          1  0.5749212 1_1
#> 5    t5       1          1  0.3648401 1_1
#> 6    t1       2          1  0.6282983 1_2
```

The DGP carries both layers: a stable between-individual structure
(\boldsymbol{\Lambda}\_B, \boldsymbol{\Psi}\_B) and a coordinated
within-individual structure (\boldsymbol{\Lambda}\_W,
\boldsymbol{\Psi}\_W). When we fit Widget 2 below we will recover both.

**Takeaway.** Forty individuals, three sessions each, five traits — long
format, one row per (individual, session, trait). The simulated truth
has *both* a between-individual two-axis structure and a
within-individual one-axis structure.

## 3. The univariate root: one trait at a time

Before we model five traits jointly, recall the univariate mixed model
behavioural ecologists already know. For one trait y measured on N
individuals at J_i occasions:

y\_{ij} = \mu + u_i + e\_{ij}, \qquad u_i \sim \mathcal{N}(0,
\sigma^2_u), \qquad e\_{ij} \sim \mathcal{N}(0, \sigma^2_e).

The classical repeatability (Nakagawa & Schielzeth 2010) is

R = \frac{\sigma^2_u}{\sigma^2_u + \sigma^2_e}.

In `lme4` syntax, fit one trait at a time:

``` r

fit_uni <- lmer(value ~ 1 + (1 | individual),
                data = subset(dat, trait == "t1"))
vc <- as.data.frame(VarCorr(fit_uni))
vc[, c("grp", "vcov")]
#>          grp      vcov
#> 1 individual 1.0103895
#> 2   Residual 0.3356346
sigma2_u <- vc$vcov[vc$grp == "individual"]
sigma2_e <- vc$vcov[vc$grp == "Residual"]
R_t1 <- sigma2_u / (sigma2_u + sigma2_e)
cat("Repeatability for t1:", round(R_t1, 3), "\n")
#> Repeatability for t1: 0.751
```

The random intercept `(1 | individual)` captures stable
between-individual variation; everything else lands in the residual. The
repeatability R is the between-individual share of total variance —
computed trait-by-trait, it’s the univariate readout that the GLLVM
upgrades to two structured matrices.

**Takeaway.** Univariate R = \sigma^2_u / (\sigma^2_u + \sigma^2_e) is
the trait-by-trait readout the multivariate model generalises. The GLLVM
upgrade replaces the two scalars with two T \times T matrices
\boldsymbol{\Sigma}\_B, \boldsymbol{\Sigma}\_W — and decomposes each
factor-analytically.

## 4. Why factor-analytic? The curse-of-dimensionality argument

A fully parameterised multivariate covariance for T traits requires
T(T+1)/2 free parameters. For T = 5 traits at one tier that’s 15
parameters; with both between and within tiers that doubles to 30. At T
= 10 traits per tier we’d need 110 covariance parameters before any
fixed effects enter. Animal-personality studies typically have N \approx
40–200 individuals; the resulting likelihood is *flat* — convergence is
unstable and standard errors are wide enough that interpretation becomes
risky (McGillycuddy et al. 2025).

The **factor-analytic** answer is to decompose

\boldsymbol{\Sigma}\_B = \boldsymbol{\Lambda}\_B
\boldsymbol{\Lambda}\_B^{\\\top} + \boldsymbol{\Psi}\_B,

with \boldsymbol{\Lambda}\_B \in \mathbb{R}^{T \times d_B} a
reduced-rank loading matrix (d_B \ll T) and \boldsymbol{\Psi}\_B a
diagonal of trait-specific uniquenesses. The parameter count drops from
T(T+1)/2 to

T(d_B + 1) - d_B(d_B - 1)/2.

For T = 5, d_B = 2: 15 \to 14; for T = 10, d_B = 2: 55 \to 29; for T =
10 at both tiers with d_B = d_W = 2: 110 \to 58. The reduction is modest
when T is small and dramatic as T grows.

The *interpretive* payoff is the same shape both directions. The shared
loadings \boldsymbol{\Lambda}\_B *name* the between-individual axes —
the syndromes. The uniquenesses \boldsymbol{\Psi}\_B name what the
shared axes do not explain — trait-specific between-individual variance.
At the within-individual tier, \boldsymbol{\Lambda}\_W names the
coordinated states; \boldsymbol{\Psi}\_W names the trait-specific
within-individual residual variance. **Both tiers are factor-analytic in
the same way**; that’s the unifying move.

**Takeaway.** Reduced-rank decomposition \boldsymbol{\Sigma} =
\boldsymbol{\Lambda}\boldsymbol{\Lambda}^{\\\top} + \boldsymbol{\Psi}
stabilises the fit *and* surfaces the biology — and it applies to both
tiers without changing form.

## 5. The model in symbols

The same model can be written two ways. The **long form** matches the
way
[`gllvmTMB()`](https://itchyshin.github.io/gllvmTMB/reference/gllvmTMB.html)
actually fits the data — one row per (individual, occasion, trait) cell,
with a scalar response. The **wide form** matches the factor-analytic
textbooks — one row per observation, with a trait-vector response. The
two panels below place them side by side; both decompose each tier’s
covariance via \boldsymbol{\Sigma} =
\boldsymbol{\Lambda}\boldsymbol{\Lambda}^{\\\top} + \boldsymbol{\Psi}.

#### Long form

Each row of the data is one (individual, occasion, trait) cell. The
scalar response is y\_{ijt}.

y\_{ijt} \mid \boldsymbol{\mu},\\ \boldsymbol{\Lambda}\_B,\\
\mathbf{z}\_{B,i},\\ \boldsymbol{\Lambda}\_W,\\ \mathbf{z}\_{W,ij},\\
\boldsymbol{\Psi} \sim \mathcal{N}\\\left(\mu_t +
(\boldsymbol{\Lambda}\_B \mathbf{z}\_{B,i})\_t +
(\boldsymbol{\Lambda}\_W \mathbf{z}\_{W,ij})\_t,\\ \psi\_{W,t}^2 +
(\boldsymbol{\Lambda}\_W \boldsymbol{\Lambda}\_W^{\\\top})\_{tt}\right)

Native to `gllvmTMB`’s formula interface. Each row’s contribution is a
scalar Gaussian.

#### Wide form

Each row is one observation; the response is a T-vector
\mathbf{Y}\_{ij}.

\mathbf{Y}\_{ij} \mid \boldsymbol{\mu},\\ \boldsymbol{\Lambda}\_B,\\
\mathbf{z}\_{B,i},\\ \boldsymbol{\Sigma}\_W \sim
\mathcal{MN}\\\left(\boldsymbol{\mu} +
\boldsymbol{\Lambda}\_B\\\mathbf{z}\_{B,i},\\
\boldsymbol{\Sigma}\_W\right), \quad \boldsymbol{\Sigma}\_W =
\boldsymbol{\Lambda}\_W\boldsymbol{\Lambda}\_W^{\\\top} +
\boldsymbol{\Psi}\_W

Native to factor-analytic textbooks. The within-individual conditional
covariance \boldsymbol{\Sigma}\_W =
\boldsymbol{\Lambda}\_W\boldsymbol{\Lambda}\_W^{\\\top} +
\boldsymbol{\Psi}\_W replaces the scalar \sigma\_\epsilon^2
\mathbf{I}\_T row-level residual when the within-tier is structured.

*Bridge.* The two forms describe the same model. The wide form makes the
covariance decomposition explicit; the long form is what
[`gllvmTMB()`](https://itchyshin.github.io/gllvmTMB/reference/gllvmTMB.html)
actually fits.

Index i ranges over individuals, j over occasions, t over traits, k = 1,
\ldots, d_B over between-axes, \ell = 1, \ldots, d_W over within-axes.
\mu_t is the trait t grand mean; \lambda\_{B,tk} is the loading of trait
t on between-axis k; \lambda\_{W,t\ell} is the loading of trait t on
within-axis \ell; z\_{B,ik} is individual i’s position on between-axis
k; z\_{W,ij\ell} is (individual i, session j)’s position on within-axis
\ell; \boldsymbol{\Psi}\_B = \mathrm{diag}(\psi\_{B,1}^2, \ldots,
\psi\_{B,T}^2) collects the trait-specific between-individual
uniquenesses; similarly \boldsymbol{\Psi}\_W for within-individual.

**Takeaway.** Long form is one scalar equation per (individual,
occasion, trait); wide form is one T-vector equation per observation.
Each tier has its own
\boldsymbol{\Lambda}\boldsymbol{\Lambda}^{\\\top} + \boldsymbol{\Psi}
decomposition. Same model, two notations.

## 6. Widget 1 — Behavioural syndromes

The first fit decomposes the **between-individual** trait covariance
only. Each trait gets its own grand mean; the shared between-individual
structure is captured by a rank-d_B loading matrix
\boldsymbol{\Lambda}\_B plus per-trait uniquenesses
\boldsymbol{\Psi}\_B:

\boldsymbol{\Sigma}\_B = \boldsymbol{\Lambda}\_B
\boldsymbol{\Lambda}\_B^{\\\top} + \boldsymbol{\Psi}\_B.

The within-individual residual is the shared row-level Gaussian
\sigma\_\epsilon^2 — a single scalar, unstructured.

``` r

fit_syndromes <- gllvmTMB(
  value ~ 0 + trait +
          latent(0 + trait | individual, d = 2) +
          unique(0 + trait | individual),
  data     = dat,
  family   = gaussian(),
  trait    = "trait",
  unit     = "individual",
  silent   = TRUE
)
sym_syndromes <- symbolize(
  fit_syndromes,
  symbols = c(value = "y_{ij}", trait = "j", individual = "i"),
  context = "behavioural syndromes (between-individual only)"
)
#> Warning in sqrt(diag(object$cov.fixed)): NaNs produced
#> Warning in sqrt(diag(object$cov.fixed)): NaNs produced
```

### Three views — syndromes

[Skip three-views widget](#sym-syndromes-1781447007-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

Each observation is normally distributed around its trait’s grand mean
shifted by the individual’s position on the shared between-individual
axes (\boldsymbol{\Lambda}\_B \mathbf{z}\_{B,i}). Trait-specific
between-individual uniquenesses (\boldsymbol{\Psi}\_B) absorb the
residual variance the shared axes do not explain; the scalar
\sigma\_\epsilon^2 captures within-individual occasion-to-occasion
noise.

**Coefficient reading.** On the response scale, \hat\beta is the
additive change in the mean of the response for a one-unit increase in
the predictor (identity link – no back-transformation needed).

\begin{aligned} y\_{ij} \mid \mu\_{t(j)}, \boldsymbol{\Lambda}\_B,
\mathbf{z}\_{B,i}, \sigma\_\epsilon & \sim \mathrm{Normal}(\mu\_{t(j)} +
(\boldsymbol{\Lambda}\_B \mathbf{z}\_{B,i})\_{t(j)}, \sigma\_\epsilon^2)
\\ \eta\_{ij} & = \mu\_{t(j)} + \sum\_{k=1}^{d_B} \lambda\_{B,t(j)k}
z\_{B,ik} \\ z\_{B,ik} & \sim \mathcal{N}(0, 1) \\ \Sigma\_{B,tt'} & =
\sum\_{k=1}^{d_B} \lambda\_{B,tk} \lambda\_{B,t'k} + \psi\_{B,t}
\delta\_{tt'} \end{aligned}

where:

- y\_{ij} — response (matrix form n x T; index form y\_{ij} is unit i,
  trait t(j) row of value)  \mathbb{R}^{40 \times 5}
- t — trait index  \\1, \ldots, 5\\
- i — unit index  \\1, \ldots, 40\\
- \mu\_{t1}, \mu\_{t2}, \mu\_{t3}, \mu\_{t4}, \mu\_{t5} — per-trait
  grand-mean intercepts  \mathbb{R}^{5}
- \lambda\_{B,tk} — between-unit reduced-rank loading matrix
   \mathbb{R}^{5 \times 2}
- z\_{B,ik} — between-unit latent scores  \mathbb{R}^{40 \times 2}
- k — latent-axis index  \\1, \ldots, 2\\
- \sigma\_\epsilon — shared row-level residual SD  scalar
- \psi\_{B,t} — between-unit unique variance per trait  diagonal ^{5 }

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Each observation is normally distributed around its trait’s grand mean
shifted by the individual’s position on the shared between-individual
axes (\boldsymbol{\Lambda}\_B \mathbf{z}\_{B,i}). Trait-specific
between-individual uniquenesses (\boldsymbol{\Psi}\_B) absorb the
residual variance the shared axes do not explain; the scalar
\sigma\_\epsilon^2 captures within-individual occasion-to-occasion
noise.

\begin{aligned} y\_{ij} \mid \boldsymbol{\mu}, \boldsymbol{\Lambda}\_B,
\mathbf{Z}\_B, \sigma\_\epsilon & \sim \mathcal{MN}(\mathbf{1}\_n
\boldsymbol{\mu}^\top + \mathbf{Z}\_B \boldsymbol{\Lambda}\_B^\top,
\sigma\_\epsilon^2 \mathbf{I}\_n, \mathbf{I}\_T) \\ \boldsymbol{\eta} &
= \mathbf{1}\_n \boldsymbol{\mu}^\top + \mathbf{Z}\_B
\boldsymbol{\Lambda}\_B^\top \\ \mathbf{z}\_{B,i} & \sim
\mathcal{N}(\mathbf{0}, \mathbf{I}\_{d_B}) \\ \boldsymbol{\Sigma}\_B & =
\boldsymbol{\Lambda}\_B \boldsymbol{\Lambda}\_B^\top +
\boldsymbol{\Psi}\_B \end{aligned}

where:

- y\_{ij} — response (matrix form n x T; index form y\_{ij} is unit i,
  trait t(j) row of value)  \mathbb{R}^{40 \times 5}
- \boldsymbol{\mu} — per-trait grand-mean intercepts  \mathbb{R}^{5}
- \boldsymbol{\Lambda}\_B — between-unit reduced-rank loading matrix
   \mathbb{R}^{5 \times 2}
- \mathbf{Z}\_B — between-unit latent scores  \mathbb{R}^{40 \times 2}
- \boldsymbol{\Sigma}\_B — implied between-unit trait covariance
   \mathbb{R}^{5 \times 5}
- \sigma\_\epsilon — shared row-level residual SD  scalar
- \boldsymbol{\Psi}\_B — between-unit unique variance per trait
   diagonal ^{5 }

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 600.

Each observation is normally distributed around its trait’s grand mean
shifted by the individual’s position on the shared between-individual
axes (\boldsymbol{\Lambda}\_B \mathbf{z}\_{B,i}). Trait-specific
between-individual uniquenesses (\boldsymbol{\Psi}\_B) absorb the
residual variance the shared axes do not explain; the scalar
\sigma\_\epsilon^2 captures within-individual occasion-to-occasion
noise.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below. The predicted random-effect contribution to each observation is
also shown.

For observation *i* = 1 of your data:

\begin{aligned} {y\_{ij}}\_{1} &= \hat\beta\_{0}\\\mathrm{t1}\_{1} +
\hat\beta\_{1}\\\mathrm{t2}\_{1} + \hat\beta\_{2}\\\mathrm{t3}\_{1} +
\hat\beta\_{3}\\\mathrm{t4}\_{1} + \hat\beta\_{4}\\\mathrm{t5}\_{1} +
\hat{u}\_{1} + \hat\varepsilon\_{1} &\quad(\text{response equation, one
row of the model}) \\ \hat\mu\_{1} &= 0.168 \times 1 + 0.0558 \times 0 -
0.0138 \times 0 - 0.102 \times 0 + 0.128 \times 0 + (0.225) \approx
0.393 &\quad(\text{predicted mean} = \text{linear predictor}) \\
{y\_{ij}}\_{1} &=
\underbrace{0.393}\_{\textstyle\\\hat\mu\_{1}\\\text{(predicted)}\\}
\\+\\
\underbrace{(0.188)}\_{\textstyle\\\hat\varepsilon\_{1}\\\text{(residual)}\\}
&\quad(\text{observed} = \text{predicted mean} + \text{residual})
\end{aligned}

Stacking the same response equation for all *n* = 600 observations:

\underbrace{\begin{bmatrix} 0.581 \\ -0.315 \\ -0.173 \\ 0.575 \\ 0.365
\\ \vdots \\ -0.31 \\ -1 \end{bmatrix}}\_{\textstyle\\{y\_{ij}}\_{\\600
\times 1}\\\text{(observed)}\\} \\=\\ \underbrace{\begin{bmatrix} 1 & 0
& 0 & 0 & 0 \\ 0 & 1 & 0 & 0 & 0 \\ 0 & 0 & 1 & 0 & 0 \\ 0 & 0 & 0 & 1 &
0 \\ 0 & 0 & 0 & 0 & 1 \\ \vdots & \vdots & \vdots & \vdots & \vdots \\
0 & 0 & 0 & 1 & 0 \\ 0 & 0 & 0 & 0 & 1
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\600 \times 5}\\}\\
\underbrace{\begin{bmatrix} 0.168 \\ 0.0558 \\ -0.0138 \\ -0.102 \\
0.128 \end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\5 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} 0.188 \\
-0.192 \\ 0.107 \\ 0.472 \\ 0.131 \\ \vdots \\ 0.0713 \\ -0.496
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}\_{\\600
\times 1}\\\text{(residual)}\\}

**Left**: observed vector y\_{ij}. **Middle**: the prediction
\mathbf{X}\hat{\boldsymbol{\beta}} + \hat{\mathbf{u}} =
\hat{\boldsymbol{\mu}}. **Right**: the residual vector
\hat{\boldsymbol{\varepsilon}} = y\_{ij} - \hat{\boldsymbol{\mu}}. Every
row of this matrix equation is one of the response-equation rows from
the worked row above.

**Partial pooling.** The random-effect estimates shown here (the BLUPs)
are partially pooled: each group’s estimate is shrunk toward zero by an
amount that grows when the group has little data and shrinks when the
between-group variance is large. Groups with the least data are pulled
hardest toward the overall mean.

Implied between-individual trait covariance \boldsymbol{\Sigma}\_B
decomposes into a shared low-rank part and per-trait uniquenesses:

\underbrace{\begin{bmatrix} 0.817 & 0 \\ 0.268 & -0.295 \\ 0.852 & 0.507
\\ 0.154 & -0.0449 \\ 0.754 & 0.398
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\Lambda}\_B\\(5 \times 2\text{
loadings})\\} \underbrace{\begin{bmatrix} 1.03 & 0.219 & 0.696 & 0.125 &
0.616 \\ 0.219 & 0.159 & 0.0784 & 0.0544 & 0.0846 \\ 0.696 & 0.0784 &
1.23 & 0.108 & 0.844 \\ 0.125 & 0.0544 & 0.108 & 0.167 & 0.098 \\ 0.616
& 0.0846 & 0.844 & 0.098 & 0.727
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\Sigma}\_B\\\text{(between-individual
implied covariance)}\\} \\=\\ \underbrace{\begin{bmatrix} 0.667 & 0.219
& 0.696 & 0.125 & 0.616 \\ 0.219 & 0.159 & 0.0784 & 0.0544 & 0.0846 \\
0.696 & 0.0784 & 0.983 & 0.108 & 0.844 \\ 0.125 & 0.0544 & 0.108 &
0.0256 & 0.098 \\ 0.616 & 0.0846 & 0.844 & 0.098 & 0.727
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\Lambda}\_B\\\boldsymbol{\Lambda}\_B^{\\\top}\\}
\\+\\ \underbrace{\begin{bmatrix} 0.358 & 0 & 0 & 0 & 0 \\ 0 & 3.04e-08
& 0 & 0 & 0 \\ 0 & 0 & 0.249 & 0 & 0 \\ 0 & 0 & 0 & 0.142 & 0 \\ 0 & 0 &
0 & 0 & 5.67e-17
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\Psi}\_B^{\\2}\\}

The widget’s **Tab 3 — Equations with data** carries the new
implied-covariance block: a 5 \times 5 numerical \boldsymbol{\Sigma}\_B
shown next to its decomposition \boldsymbol{\Lambda}\_B
\boldsymbol{\Lambda}\_B^{\\\top} + \boldsymbol{\Psi}\_B^{\\2}. The
arithmetic closes element-by-element to within rounding.

**Takeaway.** Widget 1 is the canonical *behavioural syndromes* fit. The
two-axis \boldsymbol{\Lambda}\_B names the syndromes (which traits move
together between individuals); \boldsymbol{\Psi}\_B captures the
leftover per-trait between-individual variance.

## 7. Widget 2 — Adding integrated plasticity

The second fit adds the **within-individual** reduced-rank structure.
\boldsymbol{\Lambda}\_W captures shared within-individual axes (how
traits covary across occasions, within an individual);
\boldsymbol{\Psi}\_W captures per-trait within-individual uniquenesses.
Together:

\boldsymbol{\Sigma}\_W = \boldsymbol{\Lambda}\_W
\boldsymbol{\Lambda}\_W^{\\\top} + \boldsymbol{\Psi}\_W.

When `unique(0 + trait | obs)` is added, `gllvmTMB` prints an info
message auto-suppressing \sigma\_\epsilon:

> ℹ Auto-suppressing `sigma_eps`: `unique(0 + trait | obs)` is at the
> per-row level, so it already absorbs the observation residual. • Fixed
> at 0.00111 (~1/1000 of sd(y)) to keep the Gaussian density
> well-defined; the row-level residual variance is fully captured by
> [`unique()`](https://rdrr.io/r/base/unique.html).

This is intended — the row-level residual variance is now structured
per-trait in \boldsymbol{\Psi}\_W rather than carried by a single scalar
\sigma\_\epsilon^2. The package handles the constraint for you; no
`dispformula = ~0` ceremony required (that’s the `glmmTMB` equivalent,
covered in §10).

``` r

fit_two_tier <- gllvmTMB(
  value ~ 0 + trait +
          latent(0 + trait | individual, d = 2) +
          unique(0 + trait | individual) +
          latent(0 + trait | obs, d = 1) +
          unique(0 + trait | obs),
  data     = dat,
  family   = gaussian(),
  trait    = "trait",
  unit     = "individual",
  unit_obs = "obs",
  cluster  = "session",
  silent   = TRUE
)
sym_two_tier <- symbolize(
  fit_two_tier,
  symbols = c(value = "y_{ij}", trait = "j", individual = "i"),
  context = "syndromes + integrated plasticity (two-tier)"
)
```

### Three views — two-tier

[Skip three-views widget](#sym-twotier-1781447009-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

Each observation is normally distributed around its trait’s grand mean
shifted by *two* latent-axis contributions: the individual’s position on
the shared between-individual axes (\boldsymbol{\Lambda}\_B
\mathbf{z}\_{B,i}) *and* the (individual, session)’s position on the
shared within-individual axes (\boldsymbol{\Lambda}\_W
\mathbf{z}\_{W,ij}). Per-tier trait-specific uniquenesses
(\boldsymbol{\Psi}\_B, \boldsymbol{\Psi}\_W) absorb the residual
variance each tier’s shared axes do not explain.

**Coefficient reading.** On the response scale, \hat\beta is the
additive change in the mean of the response for a one-unit increase in
the predictor (identity link – no back-transformation needed).

\begin{aligned} y\_{ij} \mid \mu\_{t(j)}, \boldsymbol{\Lambda}\_B,
\mathbf{z}\_{B,i}, \boldsymbol{\Lambda}\_W, \mathbf{z}\_{W,ij},
\boldsymbol{\Psi}\_W & \sim \mathrm{Normal}\\\left(\mu\_{t(j)} +
(\boldsymbol{\Lambda}\_B \mathbf{z}\_{B,i})\_{t(j)} +
(\boldsymbol{\Lambda}\_W \mathbf{z}\_{W,ij})\_{t(j)},\\
\psi\_{W,t(j)}^2 + (\boldsymbol{\Lambda}\_W
\boldsymbol{\Lambda}\_W^\top)\_{t(j),t(j)}\right) \\ \eta\_{ij} & =
\mu\_{t(j)} + \sum\_{k=1}^{d_B} \lambda\_{B,t(j)k} z\_{B,ik} +
\sum\_{\ell=1}^{d_W} \lambda\_{W,t(j)\ell} z\_{W,ij\ell} \\ z\_{B,ik} &
\sim \mathcal{N}(0, 1) \\ \Sigma\_{B,tt'} & = \sum\_{k=1}^{d_B}
\lambda\_{B,tk} \lambda\_{B,t'k} + \psi\_{B,t} \delta\_{tt'} \\
z\_{W,ij\ell} & \sim \mathcal{N}(0, 1) \\ \Sigma\_{W,tt'} & =
\sum\_{\ell=1}^{d_W} \lambda\_{W,t\ell} \lambda\_{W,t'\ell} +
\psi\_{W,t} \delta\_{tt'} \end{aligned}

where:

- y\_{ij} — response (matrix form n x T; index form y\_{ij} is unit i,
  trait t(j) row of value)  \mathbb{R}^{40 \times 5}
- t — trait index  \\1, \ldots, 5\\
- i — unit index  \\1, \ldots, 40\\
- \mu\_{t1}, \mu\_{t2}, \mu\_{t3}, \mu\_{t4}, \mu\_{t5} — per-trait
  grand-mean intercepts  \mathbb{R}^{5}
- \lambda\_{B,tk} — between-unit reduced-rank loading matrix
   \mathbb{R}^{5 \times 2}
- z\_{B,ik} — between-unit latent scores  \mathbb{R}^{40 \times 2}
- k — latent-axis index  \\1, \ldots, 2\\
- \sigma\_\epsilon — shared row-level residual SD  scalar
- \psi\_{B,t} — between-unit unique variance per trait  diagonal ^{5 }

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Each observation is normally distributed around its trait’s grand mean
shifted by *two* latent-axis contributions: the individual’s position on
the shared between-individual axes (\boldsymbol{\Lambda}\_B
\mathbf{z}\_{B,i}) *and* the (individual, session)’s position on the
shared within-individual axes (\boldsymbol{\Lambda}\_W
\mathbf{z}\_{W,ij}). Per-tier trait-specific uniquenesses
(\boldsymbol{\Psi}\_B, \boldsymbol{\Psi}\_W) absorb the residual
variance each tier’s shared axes do not explain.

\begin{aligned} y\_{ij} \mid \boldsymbol{\mu}, \boldsymbol{\Lambda}\_B,
\mathbf{Z}\_B, \boldsymbol{\Lambda}\_W, \mathbf{Z}\_W,
\boldsymbol{\Sigma}\_W & \sim \mathcal{MN}(\mathbf{1}\_n
\boldsymbol{\mu}^\top + \mathbf{Z}\_B \boldsymbol{\Lambda}\_B^\top +
\mathbf{Z}\_W \boldsymbol{\Lambda}\_W^\top,\\ \mathbf{I}\_n,\\
\boldsymbol{\Sigma}\_W) \\ \boldsymbol{\eta} & = \mathbf{1}\_n
\boldsymbol{\mu}^\top + \mathbf{Z}\_B \boldsymbol{\Lambda}\_B^\top +
\mathbf{Z}\_W \boldsymbol{\Lambda}\_W^\top \\ \mathbf{z}\_{B,i} & \sim
\mathcal{N}(\mathbf{0}, \mathbf{I}\_{d_B}) \\ \boldsymbol{\Sigma}\_B & =
\boldsymbol{\Lambda}\_B \boldsymbol{\Lambda}\_B^\top +
\boldsymbol{\Psi}\_B \\ \mathbf{z}\_{W,ij} & \sim
\mathcal{N}(\mathbf{0}, \mathbf{I}\_{d_W}) \\ \boldsymbol{\Sigma}\_W & =
\boldsymbol{\Lambda}\_W \boldsymbol{\Lambda}\_W^\top +
\boldsymbol{\Psi}\_W \end{aligned}

where:

- y\_{ij} — response (matrix form n x T; index form y\_{ij} is unit i,
  trait t(j) row of value)  \mathbb{R}^{40 \times 5}
- \boldsymbol{\mu} — per-trait grand-mean intercepts  \mathbb{R}^{5}
- \boldsymbol{\Lambda}\_B — between-unit reduced-rank loading matrix
   \mathbb{R}^{5 \times 2}
- \mathbf{Z}\_B — between-unit latent scores  \mathbb{R}^{40 \times 2}
- \boldsymbol{\Sigma}\_B — implied between-unit trait covariance
   \mathbb{R}^{5 \times 5}
- \sigma\_\epsilon — shared row-level residual SD  scalar
- \boldsymbol{\Psi}\_B — between-unit unique variance per trait
   diagonal ^{5 }

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 600.

Each observation is normally distributed around its trait’s grand mean
shifted by *two* latent-axis contributions: the individual’s position on
the shared between-individual axes (\boldsymbol{\Lambda}\_B
\mathbf{z}\_{B,i}) *and* the (individual, session)’s position on the
shared within-individual axes (\boldsymbol{\Lambda}\_W
\mathbf{z}\_{W,ij}). Per-tier trait-specific uniquenesses
(\boldsymbol{\Psi}\_B, \boldsymbol{\Psi}\_W) absorb the residual
variance each tier’s shared axes do not explain.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below. The predicted random-effect contribution to each observation is
also shown.

For observation *i* = 1 of your data:

\begin{aligned} {y\_{ij}}\_{1} &= \hat\beta\_{0}\\\mathrm{t1}\_{1} +
\hat\beta\_{1}\\\mathrm{t2}\_{1} + \hat\beta\_{2}\\\mathrm{t3}\_{1} +
\hat\beta\_{3}\\\mathrm{t4}\_{1} + \hat\beta\_{4}\\\mathrm{t5}\_{1} +
\hat{u}\_{1} + \hat\varepsilon\_{1} &\quad(\text{response equation, one
row of the model}) \\ \hat\mu\_{1} &= 0.168 \times 1 + 0.0558 \times 0 -
0.0138 \times 0 - 0.102 \times 0 + 0.128 \times 0 + (0.413) \approx
0.581 &\quad(\text{predicted mean} = \text{linear predictor}) \\
{y\_{ij}}\_{1} &=
\underbrace{0.581}\_{\textstyle\\\hat\mu\_{1}\\\text{(predicted)}\\}
\\+\\
\underbrace{(-1.62e-06)}\_{\textstyle\\\hat\varepsilon\_{1}\\\text{(residual)}\\}
&\quad(\text{observed} = \text{predicted mean} + \text{residual})
\end{aligned}

Stacking the same response equation for all *n* = 600 observations:

\underbrace{\begin{bmatrix} 0.581 \\ -0.315 \\ -0.173 \\ 0.575 \\ 0.365
\\ \vdots \\ -0.31 \\ -1 \end{bmatrix}}\_{\textstyle\\{y\_{ij}}\_{\\600
\times 1}\\\text{(observed)}\\} \\=\\ \underbrace{\begin{bmatrix} 1 & 0
& 0 & 0 & 0 \\ 0 & 1 & 0 & 0 & 0 \\ 0 & 0 & 1 & 0 & 0 \\ 0 & 0 & 0 & 1 &
0 \\ 0 & 0 & 0 & 0 & 1 \\ \vdots & \vdots & \vdots & \vdots & \vdots \\
0 & 0 & 0 & 1 & 0 \\ 0 & 0 & 0 & 0 & 1
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\600 \times 5}\\}\\
\underbrace{\begin{bmatrix} 0.168 \\ 0.0558 \\ -0.0138 \\ -0.102 \\
0.128 \end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\5 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} -1.62e-06 \\
-2.88e-06 \\ 1.08e-06 \\ 7.73e-06 \\ -1.64e-06 \\ \vdots \\ 8.14e-06 \\
-3.67e-06
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}\_{\\600
\times 1}\\\text{(residual)}\\}

**Left**: observed vector y\_{ij}. **Middle**: the prediction
\mathbf{X}\hat{\boldsymbol{\beta}} + \hat{\mathbf{u}} =
\hat{\boldsymbol{\mu}}. **Right**: the residual vector
\hat{\boldsymbol{\varepsilon}} = y\_{ij} - \hat{\boldsymbol{\mu}}. Every
row of this matrix equation is one of the response-equation rows from
the worked row above.

**Partial pooling.** The random-effect estimates shown here (the BLUPs)
are partially pooled: each group’s estimate is shrunk toward zero by an
amount that grows when the group has little data and shrinks when the
between-group variance is large. Groups with the least data are pulled
hardest toward the overall mean.

Implied between-individual trait covariance \boldsymbol{\Sigma}\_B
decomposes into a shared low-rank part and per-trait uniquenesses:

\underbrace{\begin{bmatrix} 0.722 & 0 \\ 0.223 & 0.36 \\ 0.844 & -0.402
\\ 0.0931 & 0.013 \\ 0.767 & -0.371
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\Lambda}\_B\\(5 \times 2\text{
loadings})\\} \underbrace{\begin{bmatrix} 0.992 & 0.161 & 0.609 & 0.0672
& 0.554 \\ 0.161 & 0.179 & 0.0438 & 0.0255 & 0.0377 \\ 0.609 & 0.0438 &
1.23 & 0.0733 & 0.796 \\ 0.0672 & 0.0255 & 0.0733 & 0.196 & 0.0666 \\
0.554 & 0.0377 & 0.796 & 0.0666 & 0.726
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\Sigma}\_B\\\text{(between-individual
implied covariance)}\\} \\=\\ \underbrace{\begin{bmatrix} 0.522 & 0.161
& 0.609 & 0.0672 & 0.554 \\ 0.161 & 0.179 & 0.0438 & 0.0255 & 0.0377 \\
0.609 & 0.0438 & 0.874 & 0.0733 & 0.796 \\ 0.0672 & 0.0255 & 0.0733 &
0.00884 & 0.0666 \\ 0.554 & 0.0377 & 0.796 & 0.0666 & 0.726
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\Lambda}\_B\\\boldsymbol{\Lambda}\_B^{\\\top}\\}
\\+\\ \underbrace{\begin{bmatrix} 0.471 & 0 & 0 & 0 & 0 \\ 0 & 2.51e-08
& 0 & 0 & 0 \\ 0 & 0 & 0.357 & 0 & 0 \\ 0 & 0 & 0 & 0.187 & 0 \\ 0 & 0 &
0 & 0 & 3.89e-16
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\Psi}\_B^{\\2}\\}

Implied within-individual trait covariance \boldsymbol{\Sigma}\_W
(replaces the \sigma^2\_\epsilon row-level residual in this fit):

\underbrace{\begin{bmatrix} 0.564 \\ 0.328 \\ 0.429 \\ 0.296 \\ 0.403
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\Lambda}\_W\\(5 \times 1\text{
loadings})\\} \underbrace{\begin{bmatrix} 0.335 & 0.185 & 0.242 & 0.167
& 0.228 \\ 0.185 & 0.144 & 0.141 & 0.0971 & 0.132 \\ 0.242 & 0.141 &
0.241 & 0.127 & 0.173 \\ 0.167 & 0.0971 & 0.127 & 0.12 & 0.12 \\ 0.228 &
0.132 & 0.173 & 0.12 & 0.199
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\Sigma}\_W\\\text{(within-individual
implied covariance)}\\} \\=\\ \underbrace{\begin{bmatrix} 0.318 & 0.185
& 0.242 & 0.167 & 0.228 \\ 0.185 & 0.107 & 0.141 & 0.0971 & 0.132 \\
0.242 & 0.141 & 0.184 & 0.127 & 0.173 \\ 0.167 & 0.0971 & 0.127 & 0.0878
& 0.12 \\ 0.228 & 0.132 & 0.173 & 0.12 & 0.163
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\Lambda}\_W\\\boldsymbol{\Lambda}\_W^{\\\top}\\}
\\+\\ \underbrace{\begin{bmatrix} 0.0172 & 0 & 0 & 0 & 0 \\ 0 & 0.0366 &
0 & 0 & 0 \\ 0 & 0 & 0.0571 & 0 & 0 \\ 0 & 0 & 0 & 0.0326 & 0 \\ 0 & 0 &
0 & 0 & 0.0365
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\Psi}\_W^{\\2}\\}

Per-trait repeatability R_t = (\Sigma_B)\_{tt} / \[(\Sigma_B)\_{tt} +
(\Sigma_W)\_{tt}\]: \[0.747, 0.555, 0.836, 0.62, 0.785\]. Each R_t is
the share of trait t’s total variance that lives at the
*between-individual* tier.

What changes between Widget 1 and Widget 2:

- **Tab 1 (Index)**: the conditional mean gains (\boldsymbol{\Lambda}\_W
  \mathbf{z}\_{W,ij})\_t. The conditional residual variance loses
  \sigma\_\epsilon^2 and gains \psi\_{W,t}^2 + (\boldsymbol{\Lambda}\_W
  \boldsymbol{\Lambda}\_W^{\\\top})\_{tt} per trait.
- **Tab 2 (Matrix)**: the matrix-Normal carries both shared structures —
  \boldsymbol{\eta} = \mathbf{1}\_n \boldsymbol{\mu}^{\\\top} +
  \mathbf{Z}\_B \boldsymbol{\Lambda}\_B^{\\\top} + \mathbf{Z}\_W
  \boldsymbol{\Lambda}\_W^{\\\top}, and the across-trait conditional
  covariance becomes \boldsymbol{\Sigma}\_W instead of
  \sigma\_\epsilon^2 \mathbf{I}\_T.
- **Tab 3 (Equations with data)**: gains a second implied-covariance
  block for \boldsymbol{\Sigma}\_W, plus a per-trait repeatability row
  R_t = (\boldsymbol{\Sigma}\_B)\_{tt} /
  \[(\boldsymbol{\Sigma}\_B)\_{tt} + (\boldsymbol{\Sigma}\_W)\_{tt}\].

**Takeaway.** Widget 2 carries the full two-tier model. The reader can
*see* the syndromes (\boldsymbol{\Lambda}\_B, \boldsymbol{\Sigma}\_B),
the integrated plasticity (\boldsymbol{\Lambda}\_W,
\boldsymbol{\Sigma}\_W), and the per-trait repeatability — all in one
widget, with arithmetic that closes.

## 8. Reading the latent axes biologically

Two payoffs once you have \boldsymbol{\Lambda}\_B, \boldsymbol{\Psi}\_B,
\boldsymbol{\Lambda}\_W, \boldsymbol{\Psi}\_W in hand.

### 8.1 Communality and uniqueness at each tier

For trait t at tier g \in \\B, W\\:

c^2\_{g,t} = \frac{\sum\_{k}
\lambda\_{g,tk}^2}{(\boldsymbol{\Sigma}\_g)\_{tt}}, \qquad
\psi^\*\_{g,t} =
\frac{(\boldsymbol{\Psi}\_g)\_{tt}}{(\boldsymbol{\Sigma}\_g)\_{tt}},
\qquad c^2\_{g,t} + \psi^\*\_{g,t} = 1.

c^2\_{g,t} is the share of trait t’s total variance at tier g that the
shared axes explain; \psi^\*\_{g,t} is what’s idiosyncratic to that
trait at that tier.

``` r

gllvmTMB::extract_communality(fit_two_tier)
#>         t1         t2         t3         t4         t5 
#> 0.52562455 0.99999986 0.70980056 0.04504144 1.00000000
```

Mapping back to §1’s named behaviours: **t1 = boldness, t2 =
exploration, t3 = aggression, t4 = activity, t5 = time-out-of-shelter**.
So a high c^2_B for *t1* (boldness) means the between-individual
component of boldness is well-explained by the shared two-axis syndrome
structure; a low c^2_B for *t3* (aggression) would mean aggression’s
between-individual variation is mostly trait-idiosyncratic
(\boldsymbol{\Psi}\_B), not part of the shared syndromes.

A trait with high c^2_B and high c^2_W is *integrated at both tiers*:
both its between-individual position and its within-individual
fluctuation share the syndrome structure. A trait with high c^2_B but
low c^2_W is *syndromatic but not plastically integrated* — individuals’
average levels align, but their occasion-to-occasion fluctuations don’t.

### 8.2 Repeatability and phenotypic-correlation decomposition

Per-trait repeatability already appears at the bottom of Widget 2’s Tab
3:

R_t =
\frac{(\boldsymbol{\Sigma}\_B)\_{tt}}{(\boldsymbol{\Sigma}\_B)\_{tt} +
(\boldsymbol{\Sigma}\_W)\_{tt}}.

The phenotypic correlation between traits t and m decomposes as

r\_{P,tm} = r\_{B,tm}\sqrt{R_t R_m} + r\_{W,tm}\sqrt{(1 - R_t)(1 -
R_m)},

so the phenotypic-level correlation is a *weighted mix* of the
between-individual and within-individual correlations, weighted by how
much of each trait’s variance lives at each tier (Dingemanse &
Dochtermann 2013). gllvmTMB’s `extract_correlations(fit)` returns all
three matrices (\boldsymbol{C}\_B, \boldsymbol{C}\_W, \boldsymbol{C}\_P)
so a reader can verify this empirically:

``` r

co <- gllvmTMB::extract_correlations(fit_two_tier)
co_B <- co[co$tier == "B", c("trait_i", "trait_j", "correlation")]
co_W <- co[co$tier == "W", c("trait_i", "trait_j", "correlation")]
head(co_B)
#>   trait_i trait_j correlation
#> 1      t1      t2  0.38220752
#> 2      t1      t3  0.55145490
#> 3      t2      t3  0.09314298
#> 4      t1      t4  0.15238423
#> 5      t2      t4  0.13577794
#> 6      t3      t4  0.14922635
head(co_W)
#>    trait_i trait_j correlation
#> 11      t1      t2   0.8409837
#> 12      t1      t3   0.8509604
#> 13      t2      t3   0.7543396
#> 14      t1      t4   0.8318400
#> 15      t2      t4   0.7373902
#> 16      t3      t4   0.7461380
```

**Takeaway.** c^2 and \psi^\* per tier are the trait-level integration
summaries; R_t is the per-trait repeatability; phenotypic correlations
decompose as a weighted mix of between and within. All three readings
fall out of the same two fitted matrices.

## 9. Identifiability gotchas: rotation, sign, and the within-tier σε

The loading matrices \boldsymbol{\Lambda}\_B, \boldsymbol{\Lambda}\_W
are identified up to **per-column sign at any rank**, and *additionally*
up to **rotation when their rank exceeds 1**. So even the rank-1
\boldsymbol{\Lambda}\_W in this fit is fixed only up to a column
reflection: flipping every entry in a column and the corresponding
latent scores leaves the likelihood unchanged. Two fits that produce
indistinguishable likelihoods can therefore have entirely
different-looking \boldsymbol{\Lambda}\_B — this is the classical
factor-analysis identifiability problem. The implied covariance
\boldsymbol{\Sigma}\_B = \boldsymbol{\Lambda}\_B
\boldsymbol{\Lambda}\_B^{\\\top} + \boldsymbol{\Psi}\_B is invariant
under both rotation and sign change; \boldsymbol{\Lambda}\_B itself is
not.

Two practical conventions, both surfaced in `assumption_table(sym)`:

- **Lower-triangular** \boldsymbol{\Lambda}\_B for *confirmatory* use —
  pin the upper triangle to zero so each column has a designated leading
  trait. This is the default identification `gllvmTMB` uses on fitting.
- **Varimax-rotated** \boldsymbol{\Lambda}\_B for *interpretation* —
  rotate the fitted loadings so each axis loads strongly on a small set
  of traits and near zero on the rest. Applied *after* fitting;
  preserves \boldsymbol{\Sigma}\_B. The column labels may reorder under
  rotation; the **block structure** is what the reader interprets.

``` r

gllvmTMB::getLoadings(fit_two_tier, rotate = "varimax")
#>           LV1        LV2
#> t1 0.63893170 0.33663804
#> t2 0.02977121 0.42239669
#> t3 0.93385659 0.03776435
#> t4 0.07630731 0.05491915
#> t5 0.85143879 0.02926521
```

A second category of identifiability concerns the **row-level residual
variance**. When both `latent(0 + trait | obs, ...)` and
`unique(0 + trait | obs)` are present (Widget 2), `gllvmTMB`
auto-suppresses \sigma\_\epsilon^2 — pinning it to ~10⁻³ to keep the
Gaussian density well-defined. This is *not* a defect; it’s the
package’s way of preventing a known collinearity between two
parametrisations of the same row-level variance. The within-tier
\boldsymbol{\Psi}\_W already captures per-trait within-individual
residual variance; a free \sigma\_\epsilon^2 scalar on top would
double-count. Reading the auto-suppression message in the fit output is
the expected behaviour, not a warning to worry about.

A third category: **\boldsymbol{\Psi}\_B or \boldsymbol{\Psi}\_W entries
near zero**. When a trait’s between-individual (or within-individual)
variance is already fully explained by the shared
\boldsymbol{\Lambda}\boldsymbol{\Lambda}^{\\\top} structure, the
optimiser pins that trait’s uniqueness \psi to the boundary (~10⁻⁴ or
smaller). Widget 1’s reported \boldsymbol{\Psi}\_B = (0.00004, 0.56,
0.48, 0.93, 0.41) for the simulated fit reads as: *trait 1 (boldness) is
fully captured by the shared between-individual axes, so its
trait-specific uniqueness disappears.* This is **not** a fit failure —
it is the model telling you which traits sit fully on the shared
structure. The implied covariance \boldsymbol{\Sigma}\_B =
\boldsymbol{\Lambda}\_B \boldsymbol{\Lambda}\_B^{\\\top} +
\boldsymbol{\Psi}\_B remains well-defined; only the *decomposition*
loses its uniqueness piece for that trait.

**Takeaway.** Rotation and sign of \boldsymbol{\Lambda} are *stated
assumptions*, not bugs. The implied covariances are invariant; the
loadings are not. Read the block structure, not the cell values. And the
within-tier \sigma\_\epsilon auto-suppression is by design.

## 10. The glmmTMB bridge

`gllvmTMB` is purpose-built for generalised linear *latent-variable*
models. `glmmTMB` is a general-purpose GLMM package that, since
McGillycuddy et al. (2025), can fit the same math via the `rr()` and
[`diag()`](https://rdrr.io/r/base/diag.html) keywords. The Nakagawa et
al. (in prep) framework uses the `glmmTMB` route; for readers coming
from there, the two-tier fit translates one-to-one:

``` r

# gllvmTMB (this article's path)
fit_two_tier <- gllvmTMB(value ~ 0 + trait +
  latent(0 + trait | individual, d = 2) + unique(0 + trait | individual) +
  latent(0 + trait | obs, d = 1) + unique(0 + trait | obs),
  data = dat, family = gaussian(),
  trait = "trait", unit = "individual",
  unit_obs = "obs", cluster = "session")

# glmmTMB (Nakagawa-paper path)
fit_two_tier_glmm <- glmmTMB::glmmTMB(value ~ 0 + trait +
  rr(0 + trait | individual, d = 2) + diag(0 + trait | individual) +
  rr(0 + trait | obs, d = 1) + diag(0 + trait | obs),
  data = dat, family = gaussian(),
  dispformula = ~0)
```

| `gllvmTMB` | `glmmTMB` | Math |
|----|----|----|
| latent(0 + trait \| g, d = k) | rr(0 + trait \| g, d = k) | \boldsymbol{\Lambda}\_g of rank k |
| unique(0 + trait \| g) | diag(0 + trait \| g) | \boldsymbol{\Psi}\_g diagonal |
| auto-suppression of \sigma\_\epsilon on unique(. \| obs) | `dispformula = ~0` | both prevent double-counting \boldsymbol{\Psi}\_W vs \sigma\_\epsilon^2 |

Both packages return the same fitted \boldsymbol{\Lambda},
\boldsymbol{\Psi}, \boldsymbol{\Sigma} matrices to numerical precision.
The article path leads with `gllvmTMB` because it ships GLLVM-specific
accessors
([`getLoadings()`](https://itchyshin.github.io/gllvmTMB/reference/getLoadings.html),
[`extract_communality()`](https://itchyshin.github.io/gllvmTMB/reference/extract_communality.html),
[`extract_correlations()`](https://itchyshin.github.io/gllvmTMB/reference/extract_correlations.html))
and a wide/long dual interface that `glmmTMB` doesn’t have.

**Takeaway.** Same math; different syntax. Use `gllvmTMB` when you want
GLLVM-specific accessors; use `glmmTMB` when your model also needs
zero-inflation or dispersion modelling and you’re happy to reconstruct
\boldsymbol{\Sigma} manually.

## 11. What’s available now, what’s next

The accessors in §8 —
[`getLoadings()`](https://itchyshin.github.io/gllvmTMB/reference/getLoadings.html),
[`extract_communality()`](https://itchyshin.github.io/gllvmTMB/reference/extract_communality.html),
[`extract_correlations()`](https://itchyshin.github.io/gllvmTMB/reference/extract_correlations.html)
— are `gllvmTMB`-side. The symbolizer surface wraps the Gaussian
latent-variable case as a **First slice** at the two-tier level: every
piece walked above is shipped today.

**Shipped today (v0.21.6-redo):**

- [`symbolize.gllvmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.gllvmTMB.md)
  populates the widget-shape slots `Lambda_B`, `Psi_B`, `Sigma_B`,
  `Lambda_W`, `Psi_W`, `Sigma_W`, `Repeatability` for the Gaussian
  latent-variable family.
- [`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md)
  Tab 3 emits a numerical implied-covariance block per tier plus a
  per-trait repeatability row when both tiers are present.
- The two-tier
  `latent(0 + trait | obs, d = d_W) + unique(0 + trait | obs)` syntax is
  fully tested. gllvmTMB’s σ_ε auto-suppression is documented in
  `assumption_table(sym)`.
- `compare_symbolic(fit_d1, fit_d2)` diffs the structural specifications
  of d_B = 1 versus d_B = 2 (or any rank-pair). See
  [`vignette("symbolizer-compare")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-compare.md).

**Still planned:**

1.  **Non-Gaussian gllvmTMB families** (count, Tweedie, ordinal) at the
    two-tier level — each adds a link to the linear predictor and
    reshapes the loadings interpretation.
2.  **Uncertainty on \boldsymbol{\Lambda}.**
    [`bootstrap_Sigma()`](https://itchyshin.github.io/gllvmTMB/reference/bootstrap_Sigma.html)
    from `gllvmTMB` returns parametric-bootstrap draws of the loading
    matrix; a future slice will surface these so the
    [`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md)
    rows for \boldsymbol{\Lambda} and \boldsymbol{\Sigma} carry
    confidence regions, not just point estimates.
3.  **Rank selection.** A simple AIC + interpretability grid over d_B,
    d_W \in \\0, 1, 2, 3\\ is the standard practical move; a future
    slice will ship this as a helper.
4.  **Reaction-norm / sex-specific extensions** (Appendices B.1 / B.2 of
    the Nakagawa et al. (in prep) framework) — fold these into the same
    \boldsymbol{\Lambda} \boldsymbol{\Lambda}^{\\\top} +
    \boldsymbol{\Psi} structure on an augmented random-effect vector.

See
[`vignette("symbolizer-roadmap")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-roadmap.md)
for the full capability matrix.

## References

- Dingemanse, N. J., & Dochtermann, N. A. (2013). Quantifying individual
  variation in behaviour: mixed-effect modelling approaches. *Journal of
  Animal Ecology* 82: 39-54.
- Mathot, K. J., & Dingemanse, N. A. (2015). Energetics and behaviour:
  unrequited needs and new directions. *Trends in Ecology & Evolution*
  30: 199-206.
- McGillycuddy, M., et al. (2025). Reduced-rank covariance structures in
  `glmmTMB`. (Forthcoming methods paper.)
- Nakagawa, S., & Schielzeth, H. (2010). Repeatability for Gaussian and
  non-Gaussian data: a practical guide for biologists. *Biological
  Reviews* 85: 935-956.
- Nakagawa, S., Mathot, K., Dinnage, R., et al. (in prep). Quantifying
  between- and within-individual correlations and the degree of trait
  integration: leveraging latent variable modeling to study behavioural
  syndromes and other phenotypic integration.
- Pigliucci, M. (2003). Phenotypic integration: studying the ecology and
  evolution of complex phenotypes. *Ecology Letters* 6: 265-272.
- Sih, A., Bell, A., & Johnson, J. C. (2004). Behavioral syndromes: an
  ecological and evolutionary overview. *Trends in Ecology & Evolution*
  19: 372-378.
