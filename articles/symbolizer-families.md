# A tour of non-Gaussian families

> *This tour walks through the non-Gaussian distributional families
> available for `drmTMB`. The biology of each is different — what kind
> of response it fits, what the link does, and how to read the `mu`
> coefficient. The same `symbolize(fit)` interface now applies to ten
> package families (`drmTMB`, `gllvmTMB`, `glmmTMB`, `brms`, `lme4`,
> `MCMCglmm`, `sdmTMB`, [`stats::lm`](https://rdrr.io/r/stats/lm.html) /
> [`stats::glm`](https://rdrr.io/r/stats/glm.html), `metafor`, `mgcv`);
> see the [Roadmap
> article](https://itchyshin.github.io/symbolizer/articles/symbolizer-roadmap.md)
> for the full capability matrix.*

The non-Gaussian families covered here all use the same `symbolize(fit)`
interface. The differences are in the LaTeX, the biological reading on
each coefficient, and the assumption table. Every phrase you see below
is templated from `inst/extdata/*.csv` — no LLM at runtime.

For Gaussian and bivariate Gaussian, see
[`vignette("symbolizer-drmtmb")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-drmtmb.md).
For the matching pedagogy on factors and interactions, see
[`vignette("symbolizer-factors")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-factors.md).

``` r

library(symbolizer)
library(drmTMB)
#> 
#> Attaching package: 'drmTMB'
#> The following object is masked from 'package:base':
#> 
#>     beta
```

## Continuous responses

### Student-t — robust regression

A heavier-tailed Gaussian alternative. The `nu` parameter controls tail
heaviness: `nu` large means almost Gaussian, `nu` small means heavy
outliers tolerated. drmTMB parameterises `nu` on the `log(nu - 2)` scale
so the variance is always finite.

``` r

set.seed(1); n <- 100
dat <- data.frame(
  y = rt(n, df = 5) * 2 + 10 + 0.5 * rnorm(n),
  x = rnorm(n)
)
fit <- drmTMB(drm_formula(y ~ x, sigma ~ 1, nu ~ 1),
              family = student(), data = dat)
sym <- symbolize(fit)
render_math(sym$distribution$latex)
```

y_i \mid \mu_i,\\ \sigma_i,\\ \nu_i \sim
\mathrm{Student\text{-}t}(\mu_i,\\ \sigma_i,\\ \nu_i)

**Coefficient reading on mu:** identical to Gaussian — a slope on the
response scale.

### Lognormal — positive continuous, right-skewed

`Y > 0`, and `log(Y)` is Gaussian. Coefficients on `mu` live on the
log-response scale, so `exp(beta)` is the multiplicative effect on the
**geometric mean** of `Y`.

``` r

set.seed(1); n <- 100
dat <- data.frame(y = exp(rnorm(n, 2 + 0.3 * rnorm(n), 0.4)),
                  x = rnorm(n))
fit <- drmTMB(drm_formula(y ~ x, sigma ~ 1),
              family = lognormal(), data = dat)
sym <- symbolize(fit)
parameter_interpretation(sym, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | 95% CI | biological_reading |
|:---|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 2.02 | 1.93, 2.11 \* | Baseline geometric mean of y in the reference condition is exp(2.02) |
| mu | x | slope | -0.0136 | -0.102, 0.0751 | A unit change in x multiplies the geometric mean of y by exp(-0.0136) |
| sigma | (Intercept) | intercept | -0.764 | -0.903, -0.626 \* | Baseline level of unexplained variability on the log scale |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

**Coefficient reading on mu:** a unit change in `x` multiplies the
geometric mean by `exp(beta)`.

#### Three views of the lognormal fit

``` r

as_html_three_views(sym, id = "lognormal")
```

[Skip three-views widget](#sym-lognormal-1780184017-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

**Coefficient reading.** On the response scale, \exp(\hat\beta) is the
multiplicative effect on the geometric mean (the median) of the
response: a one-unit increase multiplies the median by \exp(\hat\beta).

\begin{aligned} y_i \mid \mu_i,\\ \sigma_i & \sim
\mathrm{Lognormal}(\mu_i,\\ \sigma_i^2) \quad\Longleftrightarrow\quad
\log(y_i) \mid \mu_i,\\ \sigma_i \sim \mathrm{Normal}(\mu_i,\\
\sigma_i^2) \\ \mu_i & = \beta\_{0} + \beta\_{1} \\ x_i \\
\log(\sigma_i) & = \gamma\_{0} \end{aligned}

where:

- y_i — response variable  \mathbb{R}^{100}
- x_i — continuous predictor  column of X (length 100)
- \mu_i — conditional mu of y  \mathbb{R}^{100}
- \sigma_i — scale on the log-response  \mathbb{R}^{100}
- \beta\_{0}, \beta\_{1} — mu submodel coefficients  \mathbb{R}^{2}
- \gamma\_{0} — sigma submodel coefficients  \mathbb{R}^{1}

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

\begin{aligned} \log(\mathbf{y}) \mid \boldsymbol{\mu},\\
\boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\\
\mathrm{diag}(\boldsymbol{\sigma}^2)) \\ \boldsymbol{\mu} & = \mathbf{X}
\boldsymbol{\beta} \\ \log(\boldsymbol{\sigma}) & = \mathbf{X}\_{\sigma}
\boldsymbol{\gamma} \end{aligned}

where:

- \mathbf{y} — response variable  \mathbb{R}^{100}
- \boldsymbol{\mu} — conditional mu of y  \mathbb{R}^{100}
- \boldsymbol{\sigma} — scale on the log-response  \mathbb{R}^{100}
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{2}
- \boldsymbol{\gamma} — sigma submodel coefficients  \mathbb{R}^{1}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{100 \times 2}
- \mathbf{X}\_{\sigma} — sigma submodel design matrix  \mathbb{R}^{100
  \times 1}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 100.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

For observation *i* = 1 of your data:

\begin{aligned} \log(y\_{1}) &= \hat\beta\_{0} +
\hat\beta\_{1}\\x\_{1} + \hat\varepsilon\_{1}^{(\log)}
&\quad(\text{response equation, log scale}) \\ \hat\mu\_{1} &= 2.02 -
0.0136 \times 0.409 \approx 2.01 &\quad(\text{log-scale mean} =
\text{linear predictor}) \\ \log(y\_{1}) &=
\underbrace{2.01}\_{\textstyle\\\hat\mu\_{1}\\\text{(log-scale mean)}\\}
\\+\\
\underbrace{(-0.448)}\_{\textstyle\\\hat\varepsilon\_{1}^{(\log)}\\\text{(log-scale
residual)}\\} &\quad(\text{observed} = \text{mean} + \text{residual})
\end{aligned}

Stacking the same response equation for all *n* = 100 observations:

\underbrace{\begin{bmatrix} 1.56 \\ 2.07 \\ 1.38 \\ 2.54 \\ 1.84 \\
\vdots \\ 1.8 \\ 1.71
\end{bmatrix}}\_{\textstyle\\\log(\mathbf{y})\_{\\100 \times
1}\\\text{(observed, log scale)}\\} \\=\\ \underbrace{\begin{bmatrix} 1
& 0.409 \\ 1 & 1.69 \\ 1 & 1.59 \\ 1 & -0.331 \\ 1 & -2.29 \\ \vdots &
\vdots \\ 1 & -0.0506 \\ 1 & -0.306
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\100 \times 2}\\}\\
\underbrace{\begin{bmatrix} 2.02 \\ -0.0136
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\2 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} -0.448 \\
0.0769 \\ -0.611 \\ 0.519 \\ -0.212 \\ \vdots \\ -0.221 \\ -0.317
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}^{(\log)}\_{\\100
\times 1}\\\text{(log-scale residual)}\\}

**Left**: log-scale observed vector \log(\mathbf{y}). **Middle**: the
log-scale linear predictor \mathbf{X}\hat{\boldsymbol{\beta}} — this is
\hat{\boldsymbol{\mu}}, the mean of \log \mathbf{y} (as Tab 1 states).
**Right**: the log-scale residual vector
\hat{\boldsymbol{\varepsilon}}^{(\log)} = \log(\mathbf{y}) -
\hat{\boldsymbol{\mu}}. Each row matches the log-scale worked row above;
back-transform via E\[\mathbf{y}\] = \exp(\hat{\mu} + \hat{\sigma}^2 /
2) to recover the response-scale mean.

And the \sigma submodel (no observed counterpart – \sigma’s job is to
describe the spread of the log-scale residual
\hat{\boldsymbol{\varepsilon}}^{(\log)}, i.e. the SD of \log
\mathbf{y}). For the same observation *i* = 1:

\begin{aligned} \log\hat\sigma\_{1} &= \hat\gamma\_{0}
&\quad(\text{sigma submodel for observation 1, log link}) \\
\log\hat\sigma\_{1} &= -0.764 &\quad(\text{with your numbers}) \\
\hat\sigma\_{1} &= \exp(-0.764) \approx 0.466 &\quad(\text{predicted
log-scale residual SD for observation 1 (SD of log y)}) \end{aligned}

Stacking the same log-link equation for all *n* = 100 observations:

\log\\\underbrace{\begin{bmatrix} 0.466 \\ 0.466 \\ 0.466 \\ 0.466 \\
0.466 \\ \vdots \\ 0.466 \\ 0.466
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\sigma}\_{\\100 \times 1}\\}
\\=\\ \underbrace{\begin{bmatrix} 1 \\ 1 \\ 1 \\ 1 \\ 1 \\ \vdots \\ 1
\\ 1 \end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\sigma,\\100 \times
1}\\}\\ \underbrace{\begin{bmatrix} -0.764
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\gamma}\_{\\1 \times 1}\\}

``` r

pdf_alongside_html(sym, "fig-lognormal.pdf",
                   "Lognormal regression -- three views")
```

[Download as
PDF](https://itchyshin.github.io/symbolizer/articles/fig-lognormal.pdf)

### Gamma — positive continuous, skewed

`Y > 0`, log link by convention (`stats::Gamma(link = "log")`).
Coefficients are multiplicative on the mean response, like lognormal —
but the variance scales as `mu^2 * sigma^2`, not `log(Y)`.

``` r

set.seed(1); n <- 100
dat <- data.frame(y = rgamma(n, shape = 2, rate = 0.5),
                  x = rnorm(n))
fit <- drmTMB(drm_formula(y ~ x, sigma ~ 1),
              family = stats::Gamma(link = "log"), data = dat)
sym <- symbolize(fit)
render_math(sym$distribution$latex)
```

y_i \mid \mu_i,\\ \sigma_i \sim \mathrm{Gamma}(\mathrm{shape} =
1/\sigma_i^2,\\ \mathrm{scale} = \mu_i \sigma_i^2)

**When to choose Gamma over lognormal?** Gamma is a member of the
exponential family (it has nice GLM properties — link, canonical form).
Lognormal is fully implied by `log(Y) ~ Normal`, which makes some
predictive plots simpler but loses the GLM toolkit.

## Proportion responses

### Beta — proportions in (0, 1)

`Y` is strictly between 0 and 1. Mean via logit link, precision via log
link (large `sigma` means a *tighter* distribution around the mean).

``` r

set.seed(1); n <- 100
dat <- data.frame(y = rbeta(n, 2, 5),
                  x = rnorm(n))
fit <- drmTMB(drm_formula(y ~ x, sigma ~ 1),
              family = beta(), data = dat)
sym <- symbolize(fit)
render_math(sym$distribution$latex)
```

y_i \mid \mu_i,\\ \sigma_i \sim \mathrm{Beta}(\mu_i \sigma_i,\\ (1 -
\mu_i) \sigma_i)

**Coefficient reading on mu:** `exp(beta)` is the *odds ratio* for the
mean proportion \mu / (1 - \mu) — a Beta response is a continuous
proportion in (0, 1), not a binary success/failure trial. As an
*illustrative* example (not the fit shown below), a coefficient of `0.3`
would mean a unit increase in `x` multiplies those odds by
`exp(0.3) ≈ 1.35`. The fitted slope for this widget is small and the fit
is U-shaped (both Beta shape parameters \< 1); read the actual fitted
coefficient in the widget below.

#### Three views of the Beta fit

``` r

as_html_three_views(sym, id = "beta")
```

[Skip three-views widget](#sym-beta-1780184018-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

**Coefficient reading.** On the response scale, \exp(\hat\beta) is the
odds ratio for the mean proportion: a one-unit increase multiplies the
odds \mu/(1-\mu) by \exp(\hat\beta) (logit link).

Heads-up – both implied shape parameters are below 1 here (\hat\alpha =
\hat\mu\hat\sigma \approx 0.098 and \hat\beta = (1-\hat\mu)\hat\sigma
\approx 0.25), so the fitted Beta is **U-shaped**: its density piles up
near 0 and 1 rather than peaking at the mean. A precision \hat\sigma \<
1 does that. Worth checking whether a U-shape matches your data.

\begin{aligned} y_i \mid \mu_i,\\ \sigma_i & \sim \mathrm{Beta}(\mu_i
\sigma_i,\\ (1 - \mu_i) \sigma_i) \\ \mathrm{logit}(\mu_i) & =
\beta\_{0} + \beta\_{1} \\ x_i \\ \log(\sigma_i) & = \gamma\_{0}
\end{aligned}

where:

- y_i — response variable  \mathbb{R}^{100}
- x_i — continuous predictor  column of X (length 100)
- \mu_i — conditional mu of y  \mathbb{R}^{100}
- \sigma_i — Beta precision (larger sigma -\> distribution tighter
  around mu)  \mathbb{R}^{100}
- \beta\_{0}, \beta\_{1} — mu submodel coefficients  \mathbb{R}^{2}
- \gamma\_{0} — sigma submodel coefficients  \mathbb{R}^{1}

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

\begin{aligned} \mathbf{y} \mid \boldsymbol{\mu},\\ \boldsymbol{\sigma}
& \sim \mathrm{Beta}(\boldsymbol{\mu} \odot \boldsymbol{\sigma},\\ (1 -
\boldsymbol{\mu}) \odot \boldsymbol{\sigma}) \\
\mathrm{logit}(\boldsymbol{\mu}) & = \mathbf{X} \boldsymbol{\beta} \\
\log(\boldsymbol{\sigma}) & = \mathbf{X}\_{\sigma} \boldsymbol{\gamma}
\end{aligned}

where:

- \mathbf{y} — response variable  \mathbb{R}^{100}
- \boldsymbol{\mu} — conditional mu of y  \mathbb{R}^{100}
- \boldsymbol{\sigma} — Beta precision (larger sigma -\> distribution
  tighter around mu)  \mathbb{R}^{100}
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{2}
- \boldsymbol{\gamma} — sigma submodel coefficients  \mathbb{R}^{1}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{100 \times 2}
- \mathbf{X}\_{\sigma} — sigma submodel design matrix  \mathbb{R}^{100
  \times 1}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 100.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

For observation *i* = 1 of your data:

\begin{aligned} \hat\eta\_{1} &= \hat\beta\_{0} +
\hat\beta\_{1}\\x\_{1}&\quad(\text{linear predictor, link scale}) \\
-0.95 &= -0.824 - 0.0874 \times 1.43&\quad(\text{with your numbers}) \\
\hat\mu\_{1} &= \mathrm{logistic}(\hat\eta\_{1}) =
\mathrm{logistic}(-0.95) \approx 0.279&\quad(\text{response scale,
predicted}) \\ y\_{1} &\sim \mathrm{Beta}(\hat\mu\_{1}\hat\sigma\_{1},\\
(1 - \hat\mu\_{1})\hat\sigma\_{1})&\quad(\text{likelihood; no additive
}\varepsilon\text{ here}) \end{aligned}

Stacking the same response equation for all *n* = 100 observations:

\underbrace{\begin{bmatrix} -0.95 \\ -0.768 \\ -0.806 \\ -0.79 \\ -0.797
\\ \vdots \\ -0.81 \\ -0.861
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\eta}}\_{\\100 \times
1}\\\text{(linear predictor, link scale)}\\} \\=\\
\underbrace{\begin{bmatrix} 1 & 1.43 \\ 1 & -0.651 \\ 1 & -0.207 \\ 1 &
-0.393 \\ 1 & -0.32 \\ \vdots & \vdots \\ 1 & -0.164 \\ 1 & 0.421
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\100 \times 2}\\}\\
\underbrace{\begin{bmatrix} -0.824 \\ -0.0874
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\2 \times
1}\\\text{(estimated)}\\}

**Left**: linear predictor \hat{\boldsymbol{\eta}} on the link scale.
**Right**: \mathbf{X}\hat{\boldsymbol{\beta}} — the same linear
predictor in matrix form. There is no additive residual on the link
scale: each \mathbf{y}\_i has its own likelihood row above,
\mathbf{y}\_i \sim \mathrm{Family}(\hat{\mu}\_i), with the
response-scale mean recovered as \hat{\boldsymbol{\mu}} =
g^{-1}(\hat{\boldsymbol{\eta}}) (the inverse-link back-transform shown
in the worked row).

And the \sigma submodel (no observed counterpart – \sigma here is the
family’s spread parameter and is not a residual SD; see Tab 1 for its
specific role in this distribution). For the same observation *i* = 1:

\begin{aligned} \log\hat\sigma\_{1} &= \hat\gamma\_{0}
&\quad(\text{sigma submodel for observation 1, log link}) \\
\log\hat\sigma\_{1} &= -1.04 &\quad(\text{with your numbers}) \\
\hat\sigma\_{1} &= \exp(-1.04) \approx 0.353 &\quad(\text{predicted
precision parameter for observation 1 (positive shape, not an SD)})
\end{aligned}

Stacking the same log-link equation for all *n* = 100 observations:

\log\\\underbrace{\begin{bmatrix} 0.353 \\ 0.353 \\ 0.353 \\ 0.353 \\
0.353 \\ \vdots \\ 0.353 \\ 0.353
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\sigma}\_{\\100 \times 1}\\}
\\=\\ \underbrace{\begin{bmatrix} 1 \\ 1 \\ 1 \\ 1 \\ 1 \\ \vdots \\ 1
\\ 1 \end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\sigma,\\100 \times
1}\\}\\ \underbrace{\begin{bmatrix} -1.04
\end{bmatrix}}\_{\textstyle\\\boldsymbol{\gamma}\_{\\1 \times 1}\\}

``` r

pdf_alongside_html(sym, "fig-beta.pdf",
                   "Beta regression -- three views")
```

[Download as
PDF](https://itchyshin.github.io/symbolizer/articles/fig-beta.pdf)

### Beta-binomial — overdispersed binomial counts

`Y` is the count of successes out of `N_i` trials. Specify via
`cbind(successes, failures)`. `sigma` controls overdispersion: large
`sigma` approaches binomial (no overdispersion), small `sigma` means
strong overdispersion.

``` r

set.seed(1); n <- 80
trials <- sample(5:20, n, replace = TRUE)
p <- plogis(0.5 + 0.5 * rnorm(n))
dat <- data.frame(
  successes = rbinom(n, trials, p),
  failures  = trials - rbinom(n, trials, p),
  x         = rnorm(n)
)
fit <- drmTMB(drm_formula(cbind(successes, failures) ~ x, sigma ~ 1),
              family = beta_binomial(), data = dat)
sym <- symbolize(fit)
render_math(sym$distribution$latex)
```

\mathrm{cbind(successes, failures)}\_i \mid N_i,\\ \mu_i,\\ \sigma_i
\sim \mathrm{BetaBinomial}(N_i,\\ \mu_i,\\ \sigma_i);
\mathbb{E}\[\mathrm{cbind(successes, failures)}\_i\] = N_i \mu_i

**Coefficient reading on mu:** same logit reading as Beta — `exp(beta)`
is the odds ratio for the success probability.

## Count responses

### Poisson — counts with no dispersion parameter

`Y in {0, 1, 2, ...}`, log link on the mean count rate. The Poisson
family forces `variance = mean`; if your data show overdispersion
(variance \> mean), prefer `nbinom2`.

``` r

set.seed(1); n <- 100
dat <- data.frame(y = rpois(n, lambda = exp(1 + 0.3 * rnorm(n))),
                  x = rnorm(n))
fit <- drmTMB(drm_formula(y ~ x),
              family = stats::poisson(), data = dat)
sym <- symbolize(fit)
render_math(sym$distribution$latex)
```

y_i \mid \mu_i \sim \mathrm{Poisson}(\mu_i)

**Coefficient reading on mu:** `exp(beta)` is the *rate ratio* — a
multiplicative effect on the expected count.

#### Three views of the Poisson fit

``` r

as_html_three_views(sym, id = "poisson")
```

[Skip three-views widget](#sym-poisson-1780184018-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

Each observation is a count; the log of the expected count may shift
with the predictors.

**Coefficient reading.** On the response scale, \exp(\hat\beta) is the
rate ratio: a one-unit increase in the predictor multiplies the expected
count by \exp(\hat\beta) (log link).

\begin{aligned} y_i \mid \mu_i & \sim \mathrm{Poisson}(\mu_i) \\
\log(\mu_i) & = \beta\_{0} + \beta\_{1} \\ x_i \end{aligned}

where:

- y_i — response variable  \mathbb{R}^{100}
- x_i — continuous predictor  column of X (length 100)
- \mu_i — conditional mu of y  \mathbb{R}^{100}
- \beta\_{0}, \beta\_{1} — mu submodel coefficients  \mathbb{R}^{2}

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Each observation is a count; the log of the expected count may shift
with the predictors.

\begin{aligned} \mathbf{y} \mid \boldsymbol{\mu} & \sim
\mathrm{Poisson}(\boldsymbol{\mu}) \\ \log(\boldsymbol{\mu}) & =
\mathbf{X} \boldsymbol{\beta} \end{aligned}

where:

- \mathbf{y} — response variable  \mathbb{R}^{100}
- \boldsymbol{\mu} — conditional mu of y  \mathbb{R}^{100}
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{2}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{100 \times 2}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 100.

Each observation is a count; the log of the expected count may shift
with the predictors.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

For observation *i* = 1 of your data:

\begin{aligned} \hat\eta\_{1} &= \hat\beta\_{0} +
\hat\beta\_{1}\\x\_{1}&\quad(\text{linear predictor, link scale}) \\
0.936 &= 0.955 - 0.0438 \times 0.45&\quad(\text{with your numbers}) \\
\hat\mu\_{1} &= \exp(\hat\eta\_{1}) = \exp(0.936) \approx
2.55&\quad(\text{response scale, predicted}) \\ y\_{1} &\sim
\mathrm{Poisson}(\hat\mu\_{1})&\quad(\text{likelihood; no additive
}\varepsilon\text{ here}) \end{aligned}

Stacking the same response equation for all *n* = 100 observations:

\underbrace{\begin{bmatrix} 0.936 \\ 0.956 \\ 0.969 \\ 0.996 \\ 1.02 \\
\vdots \\ 0.963 \\ 0.911
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\eta}}\_{\\100 \times
1}\\\text{(linear predictor, link scale)}\\} \\=\\
\underbrace{\begin{bmatrix} 1 & 0.45 \\ 1 & -0.0186 \\ 1 & -0.318 \\ 1 &
-0.929 \\ 1 & -1.49 \\ \vdots & \vdots \\ 1 & -0.166 \\ 1 & 1.02
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\100 \times 2}\\}\\
\underbrace{\begin{bmatrix} 0.955 \\ -0.0438
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\2 \times
1}\\\text{(estimated)}\\}

**Left**: linear predictor \hat{\boldsymbol{\eta}} on the link scale.
**Right**: \mathbf{X}\hat{\boldsymbol{\beta}} — the same linear
predictor in matrix form. There is no additive residual on the link
scale: each \mathbf{y}\_i has its own likelihood row above,
\mathbf{y}\_i \sim \mathrm{Family}(\hat{\mu}\_i), with the
response-scale mean recovered as \hat{\boldsymbol{\mu}} =
g^{-1}(\hat{\boldsymbol{\eta}}) (the inverse-link back-transform shown
in the worked row).

``` r

pdf_alongside_html(sym, "fig-poisson.pdf",
                   "Poisson regression -- three views")
```

[Download as
PDF](https://itchyshin.github.io/symbolizer/articles/fig-poisson.pdf)

### Negative binomial (nbinom2) — counts with overdispersion

`Y in {0, 1, 2, ...}`, log link on the mean count rate. `sigma`
parameterises overdispersion: `size = exp(sigma)`. Small `size` means
highly overdispersed (much higher variance than mean); large `size`
approaches Poisson.

``` r

set.seed(1); n <- 100
dat <- data.frame(y = rnbinom(n, size = 3, mu = exp(1 + 0.3 * rnorm(n))),
                  x = rnorm(n))
fit <- drmTMB(drm_formula(y ~ x, sigma ~ 1),
              family = nbinom2(), data = dat)
sym <- symbolize(fit)
render_math(sym$distribution$latex)
```

y_i \mid \mu_i,\\ \sigma_i \sim \mathrm{NegBin}(\mu_i,\\ \mathrm{size} =
\exp(\sigma_i)); \mathrm{Var}(y_i) = \mu_i + \mu_i^2 / \exp(\sigma_i)

**Coefficient reading on mu:** same as Poisson — `exp(beta)` is the rate
ratio.

### Zero-truncated nbinom2 — counts that are never zero

`Y in {1, 2, 3, ...}`. The truncation is built into the likelihood, not
a data filter. The modelled `mu` is the mean of the *underlying
untruncated* distribution; the observed truncated mean is larger.

``` r

set.seed(1); n <- 100
dat <- data.frame(
  y = pmax(1L, rnbinom(n, size = 2, mu = exp(1 + 0.3 * rnorm(n)))),
  x = rnorm(n)
)
fit <- drmTMB(drm_formula(y ~ x, sigma ~ 1),
              family = truncated_nbinom2(), data = dat)
sym <- symbolize(fit)
render_math(sym$distribution$latex)
```

y_i \mid \mu_i,\\ \sigma_i \sim \mathrm{NegBin}^{+}(\mu_i,\\
\mathrm{size}=\exp(\sigma_i)); y_i \in \\1, 2, 3, \ldots\\

**Coefficient reading on mu:** `exp(beta)` is the rate ratio on the
untruncated mean. The observed (truncated) mean has a different
expression that depends on `size`.

## Bivariate Gaussian — two responses jointly

For paired continuous responses with a residual correlation between
them, see
[`vignette("symbolizer-drmtmb")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-drmtmb.md)
Section 7. The bivariate Gaussian shape is structurally different — five
submodels (`mu1`, `mu2`, `sigma1`, `sigma2`, `rho12`) instead of two or
three — and has its own dedicated section in the drmTMB vignette.

## Picking a family

Six rules of thumb:

1.  **Continuous, roughly symmetric, fixed scale** → `gaussian`.
2.  **Continuous, symmetric, heavier tails (outliers tolerated)** →
    `student`.
3.  **Continuous, positive, right-skewed** → `lognormal` or `Gamma`. Use
    lognormal when interpretation is naturally on the `log(Y)` scale
    (e.g., body mass, lifespan). Use Gamma when the GLM framework
    matters (e.g., for diagnostics).
4.  **Proportion in (0, 1)** → `beta`. **Count of successes out of a
    known number of trials** → `beta_binomial`.
5.  **Counts with variance = mean** → `poisson`. **Counts with variance
    \> mean** → `nbinom2`.
6.  **Counts that are structurally non-zero** → `truncated_nbinom2`.

If none of these fit, check
[`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md)
—
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
will refuse with a clear message naming what’s not yet supported.

## Where to read next

- [`vignette("symbolizer-drmtmb")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-drmtmb.md)
  — the deep drmTMB tour (Gaussian + bivariate Gaussian + random
  effects).
- [`vignette("symbolizer-factors")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-factors.md)
  — categorical pedagogy (works the same way for any family).
- [`vignette("symbolizer-compare")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-compare.md)
  — comparing two fits with
  [`compare_symbolic()`](https://itchyshin.github.io/symbolizer/reference/compare_symbolic.md).
