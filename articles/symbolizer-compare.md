# Comparing two symbolized models

> *Two models on the table, one set of data — what do they say
> differently?* `compare_symbolic(sym_a, sym_b)` answers the structural
> half of that question (which submodels, which terms, which
> assumptions). With `metrics = TRUE` it adds AIC, BIC, log-likelihood,
> and df with a delta — the numbers that ground model selection.

This vignette walks three worked examples that cover the cases most
biologists actually meet:

1.  A full-versus-reduced fixed-effects comparison (same data, same
    family, different terms).
2.  A with-versus-without-random-effects comparison (same data, same
    family, different assumption status).
3.  A univariate-versus-bivariate comparison (different family — showing
    how `metrics` *refuses* to compute deltas).

It also says where the function stops being the right answer.

## 1. What `compare_symbolic` is for

`compare_symbolic` is **structural**. It tells you what’s different
about the *specification* of two fits — which submodels exist, which
predictors are in each one, which assumptions changed status. The
default return is four slots:

- `meta` — class / family / response / n_obs on each side.
- `diff_submodels` — presence per submodel: `left_only`, `right_only`,
  or `both`.
- `diff_terms` — presence per `(submodel, term_label)` pair.
- `diff_assumptions` — `left_status`, `right_status`, and a
  `same_status` logical.

When you pass `metrics = TRUE` a fifth slot appears:

- `diff_metrics` — AIC, BIC, log-likelihood, and df on each side plus a
  `delta` column (`right - left`). Refuses to compute deltas when the
  two fits are obviously incomparable (different family, response, or
  `n_obs`) and instead carries a `comparable = FALSE` attribute plus a
  `note` explaining why.

For fit-time identifiability and convergence diagnostics — singular
Hessian, parameter-at-boundary, near-zero variance components —
`compare_symbolic` is not the tool. Run
[`drmTMB::check_drm()`](https://itchyshin.github.io/drmTMB/reference/check_drm.html)
(or the gllvmTMB analogue) on each fit *before* interpreting the
structural diff. The compare surface assumes both fits actually
converged.

## 2. Worked example 1: full versus reduced fixed effects

A common workflow is to fit a richer model and a simpler nested model on
the same data and ask whether the richer model is worth the extra
parameters.

``` r

library(symbolizer)
library(drmTMB)
#> 
#> Attaching package: 'drmTMB'
#> The following object is masked from 'package:base':
#> 
#>     beta

set.seed(20260524)
n <- 200
dat <- data.frame(
  temperature = runif(n, 8, 30),
  food        = rlnorm(n, 1.5, 0.6)
)
dat$body_mass <- with(dat,
  rnorm(n, 5 + 0.5 * temperature + 2 * log(food), 2)
)

fit_full <- drmTMB(
  drm_formula(body_mass ~ temperature + log(food),
              sigma     ~ temperature),
  family = gaussian(), data = dat
)
fit_reduced <- drmTMB(
  drm_formula(body_mass ~ temperature, sigma ~ 1),
  family = gaussian(), data = dat
)

sym_full    <- symbolize(fit_full)
sym_reduced <- symbolize(fit_reduced)
```

The structural diff with metrics:

``` r

cmp1 <- compare_symbolic(sym_full, sym_reduced, metrics = TRUE)
cmp1
```

**Model summaries**

|          | left      | right     |
|:---------|:----------|:----------|
| class    | drmTMB    | drmTMB    |
| family   | gaussian  | gaussian  |
| response | body_mass | body_mass |
| n_obs    | 200       | 200       |

**Submodels**

| submodel | presence |
|:---------|:---------|
| mu       | both     |
| sigma    | both     |

**Terms**

| submodel | term_label  | presence  |
|:---------|:------------|:----------|
| mu       | (Intercept) | both      |
| mu       | temperature | both      |
| mu       | log(food)   | left_only |
| sigma    | (Intercept) | both      |
| sigma    | temperature | left_only |

**Assumptions**

| assumption               | left_status | right_status | same_status |
|:-------------------------|:------------|:-------------|:------------|
| conditional_distribution | stated      | stated       | TRUE        |
| linear_predictor         | stated      | stated       | TRUE        |
| independence             | implied     | implied      | TRUE        |
| positivity               | implied     | implied      | TRUE        |
| no_missing_at_random     | not_checked | not_checked  | TRUE        |

**Metrics**

| metric | left   | right  | delta  |
|:-------|:-------|:-------|:-------|
| AIC    | 846.4  | 892.9  | 46.54  |
| BIC    | 862.9  | 902.8  | 39.94  |
| logLik | -418.2 | -443.5 | -25.27 |
| df     | 5.000  | 3.000  | -2.000 |

*delta = right - left*

The Terms section lists the predictors lost when going from full to
reduced: `log(food)` disappears from the mu submodel and `temperature`
disappears from the sigma submodel. The Metrics section quantifies the
cost: the full model uses more df but pays that back in log-likelihood;
AIC and BIC pick the model that balances the two.

`delta = right - left`. A negative AIC delta means the *right* fit
(here, the reduced model) has lower AIC than the *left* (here, the full
model). Read the sign before you read the magnitude.

**Takeaway.** Same data, same family — pass `metrics = TRUE` and read
the delta column to do model selection on top of the structural diff.

## 3. Worked example 2: with versus without random intercepts

A second common workflow: a study with grouped data (sites, individuals,
populations). Fit both with and without `(1 | group)` and inspect what
changes — including which independence assumption is in force.

``` r

set.seed(7L)
n2 <- 150
dat2 <- data.frame(
  body_mass   = rnorm(n2, 30, 2),
  temperature = runif(n2, 10, 25),
  site        = factor(rep(letters[1:6], length.out = n2))
)

fit_noRE <- drmTMB(
  drm_formula(body_mass ~ temperature, sigma ~ 1),
  family = gaussian(), data = dat2
)
fit_RE <- drmTMB(
  drm_formula(body_mass ~ temperature + (1 | site), sigma ~ 1),
  family = gaussian(), data = dat2
)

sym_noRE <- symbolize(fit_noRE)
sym_RE   <- symbolize(fit_RE)

cmp2 <- compare_symbolic(sym_noRE, sym_RE, metrics = TRUE)
cmp2
```

**Model summaries**

|          | left      | right     |
|:---------|:----------|:----------|
| class    | drmTMB    | drmTMB    |
| family   | gaussian  | gaussian  |
| response | body_mass | body_mass |
| n_obs    | 150       | 150       |

**Submodels**

| submodel | presence |
|:---------|:---------|
| mu       | both     |
| sigma    | both     |

**Terms**

| submodel | term_label  | presence |
|:---------|:------------|:---------|
| mu       | (Intercept) | both     |
| mu       | temperature | both     |
| sigma    | (Intercept) | both     |

**Assumptions**

| assumption                        | left_status | right_status | same_status |
|:----------------------------------|:------------|:-------------|:------------|
| conditional_distribution          | stated      | stated       | TRUE        |
| linear_predictor                  | stated      | stated       | TRUE        |
| independence                      | implied     | NA           | FALSE       |
| positivity                        | implied     | implied      | TRUE        |
| no_missing_at_random              | not_checked | not_checked  | TRUE        |
| independence_given_random_effects | NA          | stated       | FALSE       |

**Metrics**

| metric | left   | right  | delta          |
|:-------|:-------|:-------|:---------------|
| AIC    | 612.0  | 614.0  | 2.000          |
| BIC    | 621.0  | 626.0  | 5.011          |
| logLik | -303.0 | -303.0 | -0.00000004182 |
| df     | 3.000  | 4.000  | 1.000          |

*delta = right - left*

Two things to notice:

1.  **The Assumptions section flips.** The left fit has an
    `independence` row (status `implied`). The right fit drops that row
    and adds an `independence_given_random_effects` row (status
    `stated`). `compare_symbolic` marks the change with `*` in the print
    output and surfaces both rows.

2.  **The Metrics section quantifies the random-intercept cost.** Adding
    `(1 | site)` uses one extra df (the variance of the site intercept).
    Whether it’s worth it depends on the AIC delta and the biology of
    the study design.

**Takeaway.** A structural diff makes the *assumption swap* visible —
going from independence to conditional independence given the random
effects — and `metrics = TRUE` quantifies the trade-off.

## 4. Worked example 3: univariate versus bivariate Gaussian

Sometimes the two fits aren’t on the same scale at all. A univariate
Gaussian fit predicts one response; a bivariate Gaussian fit predicts
two responses jointly. The structural diff still works — and `metrics`
will *refuse* to compute deltas, with a clear note.

``` r

set.seed(20260524)
n3 <- 80
e1 <- rnorm(n3); e2 <- 0.6 * e1 + sqrt(1 - 0.6^2) * rnorm(n3)
dat3 <- data.frame(
  growth = 30 + 1.5 * rnorm(n3) + e1,
  repro  = 10 + 0.8 * rnorm(n3) + e2,
  x1 = rnorm(n3), x2 = rnorm(n3)
)

fit_uv <- drmTMB(
  drm_formula(growth ~ x1, sigma ~ 1),
  family = gaussian(), data = dat3
)
fit_bv <- drmTMB(
  drm_formula(mu1 = growth ~ x1, mu2 = repro ~ x2,
              sigma1 = ~ 1, sigma2 = ~ 1, rho12 = ~ 1),
  family = biv_gaussian(), data = dat3
)

sym_uv <- symbolize(fit_uv)
sym_bv <- symbolize(fit_bv)

cmp3 <- compare_symbolic(sym_uv, sym_bv, metrics = TRUE)
cmp3
```

**Model summaries**

|          | left     | right         |
|:---------|:---------|:--------------|
| class    | drmTMB   | drmTMB        |
| family   | gaussian | biv_gaussian  |
| response | growth   | growth, repro |
| n_obs    | 80       | 80            |

**Submodels**

| submodel | presence   |
|:---------|:-----------|
| mu       | left_only  |
| sigma    | left_only  |
| mu1      | right_only |
| mu2      | right_only |
| sigma1   | right_only |
| sigma2   | right_only |
| rho12    | right_only |

**Terms**

| submodel | term_label  | presence   |
|:---------|:------------|:-----------|
| mu       | (Intercept) | left_only  |
| mu       | x1          | left_only  |
| sigma    | (Intercept) | left_only  |
| mu1      | (Intercept) | right_only |
| mu1      | x1          | right_only |
| mu2      | (Intercept) | right_only |
| mu2      | x2          | right_only |
| sigma1   | (Intercept) | right_only |
| sigma2   | (Intercept) | right_only |
| rho12    | (Intercept) | right_only |

**Assumptions**

| assumption                       | left_status | right_status | same_status |
|:---------------------------------|:------------|:-------------|:------------|
| conditional_distribution         | stated      | stated       | TRUE        |
| linear_predictor                 | stated      | NA           | FALSE       |
| independence                     | implied     | NA           | FALSE       |
| positivity                       | implied     | NA           | FALSE       |
| no_missing_at_random             | not_checked | not_checked  | TRUE        |
| linear_predictor_mu1             | NA          | stated       | FALSE       |
| linear_predictor_mu2             | NA          | stated       | FALSE       |
| linear_predictor_sigma1          | NA          | stated       | FALSE       |
| linear_predictor_sigma2          | NA          | stated       | FALSE       |
| linear_predictor_rho12           | NA          | stated       | FALSE       |
| residual_correlation_range       | NA          | implied      | FALSE       |
| residual_decomposition           | NA          | stated       | FALSE       |
| independence_across_observations | NA          | implied      | FALSE       |

**Metrics**

| metric | left   | right  | delta |
|:-------|:-------|:-------|:------|
| AIC    | 333.5  | 565.3  | NA    |
| BIC    | 340.7  | 582.0  | NA    |
| logLik | -163.8 | -275.7 | NA    |
| df     | 3.000  | 7.000  | NA    |

*Deltas not computed: incomparable: family differs (left = gaussian,
right = biv_gaussian)*

The Submodels block shows the structural extension cleanly: univariate’s
`mu, sigma` are `left_only`; bivariate’s
`mu1, mu2, sigma1, sigma2, rho12` are `right_only`. None of them are in
`both` because the submodel *names* differ.

The Metrics block shows the raw AIC, BIC, logLik, df on each side for
transparency — but the `delta` column is all NA and the print output
flags *“deltas not computed: incomparable: family differs (left =
gaussian, right = biv_gaussian)”*. That’s deliberate. The two
likelihoods aren’t on the same scale: the univariate fit is a sum of `n`
univariate Gaussian densities, the bivariate fit is a sum of `n`
bivariate joint densities. Comparing the AIC values directly would be
misleading.

**Takeaway.** `compare_symbolic` works structurally regardless of
whether the two fits are comparable on the likelihood scale.
`metrics = TRUE` is honest: it refuses to compute deltas when the fits
aren’t comparable, and tells you why.

## 5. When NOT to use `compare_symbolic`

`compare_symbolic` is structural-symbolic. It answers *“what’s different
about how these models are specified?”* It does **not** answer:

- **“Does my model converge?”** — that’s a fit-time question. Use
  `drmTMB::check_drm(fit)` or the gllvmTMB analogue *before* you call
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md).
  If a fit didn’t converge, the structural diff is misleading.
- **“Are my parameters identifiable?”** — see
  [`check_drm()`](https://itchyshin.github.io/drmTMB/reference/check_drm.html)
  for Hessian-rank diagnostics on drmTMB; for gllvmTMB latent-variable
  models,
  [`vignette("symbolizer-gllvm")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-gllvm.md)
  Section 7 covers the rotation-and-sign identifiability of
  $`\boldsymbol{\Lambda}_B`$.
- **“Which coefficients changed by how much?”** — that’s a
  coefficient-level numeric question. Use
  `parameter_interpretation(sym_a)` and
  `parameter_interpretation(sym_b)` and compare the `estimate` and
  `(confint_low, confint_high)` columns directly. A future slice may add
  `diff_coefficients()` as an opt-in extension of `compare_symbolic`.
- **“Should I drop predictor X?”** — that’s an inference question about
  the structural diff’s *consequences*. `metrics = TRUE` gives you the
  AIC / BIC delta; that’s evidence, not a verdict. The biology still has
  to be your call.

**Takeaway.** The compare surface is structural — it tells you what your
two models *say differently*. Identifiability, convergence, and
inference are different lenses that live in different functions.

## 6. Where to read next

- [`vignette("symbolizer")`](https://itchyshin.github.io/symbolizer/articles/symbolizer.md)
  — the package-wide Get Started tour.
- [`vignette("symbolizer-drmtmb")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-drmtmb.md)
  — the drmTMB-first deep tour (location-scale, random intercepts,
  bivariate Gaussian, the richer four-role worked example).
- [`vignette("symbolizer-factors")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-factors.md)
  — the categorical pedagogy guide (dummies, contrasts, interactions,
  six common pitfalls).
- [`vignette("symbolizer-gllvm")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-gllvm.md)
  — the parallel story for latent-variable models in `gllvmTMB`.
