# Multi-node structural equation models: piecewiseSEM and drmSEM

> *A piecewise structural equation model is a **system** of regressions
> — one fitted model per response, wired together into a causal graph.
> This article shows how
> [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
> reads the whole system: it walks each node, symbolizes it with the
> node’s own class method, and hands back a collator whose equations,
> assumption table, and HTML widget are stacked node by node. Two
> flavours are covered: mean-only piecewise SEMs from `piecewiseSEM`,
> and distributional (location-scale) piecewise SEMs from `drmSEM`.*

## A SEM is a list of regressions

Where a single GLM has one response, a piecewise SEM has several — each
its own fitted model, each a **node** in a directed graph. A path that
appears as a predictor in one node is a response in another. The model
of avian fecundity below is three statements:

- `body_size ~ temperature` — body size tracks temperature,
- `fecundity ~ body_size + rainfall` — fecundity tracks body size and
  rainfall,
- `rainfall %~~% temperature` — the two climate drivers are correlated
  (a residual covariance arc, **not** a regression).

[`piecewiseSEM::psem()`](https://rdrr.io/pkg/piecewiseSEM/man/psem.html)
glues those fitted nodes into one object.
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
reads it as a unit.

``` r

library(piecewiseSEM)

n <- 120
d <- data.frame(temperature = rnorm(n), rainfall = rnorm(n))
d$body_size <- 0.5 * d$temperature + rnorm(n)
d$fecundity <- 0.4 * d$body_size + 0.3 * d$rainfall + rnorm(n)

m_size <- lm(body_size ~ temperature, data = d)
m_fec  <- lm(fecundity ~ body_size + rainfall, data = d)

sem <- psem(m_size, m_fec, rainfall %~~% temperature, data = d)
#> Warning: the 'nobars' function has moved to the reformulas package. Please update your imports, or ask an upstream package maintainer to do so.
#> This warning is displayed once per session.

sym <- symbolize(
  sem,
  symbols = c(body_size = "S_i", fecundity = "F_i",
              temperature = "T_i", rainfall = "R_i")
)
sym
#> <symbolized_psem>: 2 nodes
#>   - body_size (lm, gaussian)
#>   - fecundity (lm, gaussian)
#>   1 residual covariance arc: rainfall ~~ temperature
```

[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
returns a `symbolized_psem` — a collator holding one `symbolized_model`
per node (`sym$parts`), the node names in declared order
(`sym$node_names`), and any `%~~%` arcs (`sym$cov_arcs`). Every node was
dispatched on its own class:

``` r

sym$node_names
#> [1] "body_size" "fecundity"
vapply(sym$parts, function(p) p$model$class, character(1))
#> body_size fecundity 
#>      "lm"      "lm"
```

## The equations, node by node

[`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md)
row-binds every node’s equation block with a leading `node` column, so
you can see the whole system at once:

``` r

equations(sym)
```

\begin{aligned} S_i \mid \mu_i,\\ \sigma \sim \mathrm{Normal}(\mu_i,\\
\sigma^2) \\ \mu_i = \beta\_{0} + \beta\_{1} \\ T_i \\ F_i \mid \mu_i,\\
\sigma \sim \mathrm{Normal}(\mu_i,\\ \sigma^2) \\ \mu_i = \beta\_{0} +
\beta\_{1} \\ S_i + \beta\_{2} \\ R_i \end{aligned}

[`as_latex()`](https://itchyshin.github.io/symbolizer/reference/as_latex.md)
concatenates the per-node LaTeX under `## Node:` headers, ready to
splice into a manuscript:

``` r

cat(as_latex(sym))
#> ## Node: body_size
#> \begin{aligned}
#> S_i \mid \mu_i,\, \sigma & \sim \mathrm{Normal}(\mu_i,\, \sigma^2) \\
#> \mu_i & = \beta_{0} + \beta_{1} \, T_i
#> \end{aligned}
#> 
#> ## Node: fecundity
#> \begin{aligned}
#> F_i \mid \mu_i,\, \sigma & \sim \mathrm{Normal}(\mu_i,\, \sigma^2) \\
#> \mu_i & = \beta_{0} + \beta_{1} \, S_i + \beta_{2} \, R_i
#> \end{aligned}
```

## The assumptions — including the covariance arc

[`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md)
row-binds each node’s assumptions, again with a leading `node` column.
The `%~~%` arc surfaces here as a `Residual cov(...)` row — and **only**
here. A bidirected arc is a covariance, not a regression, so it never
appears as an equation:

``` r

assumption_table(sym)
```

| assumption | expression | biological meaning | status |
|:---|:---|:---|:---|
| conditional_distribution | S_i \mid \mu_i,\\ \sigma_i \sim \mathrm{Normal}(\mu_i,\\ \sigma_i^2) | body_size varies normally around its expected value | explicit |
| linear_predictor | \mu_i = \beta_0 + \sum_k \beta_k X\_{ki} | Expected body_size is a linear combination of the mean-model predictors | explicit |
| independence | S_i \perp S_j \mid X \text{ for } i \ne j | Observations are conditionally independent given the predictors | follows from the formula |
| no_missing_at_random | — | Observations are assumed not missing in a way that depends on the unobserved response | your responsibility |
| conditional_distribution | F_i \mid \mu_i,\\ \sigma_i \sim \mathrm{Normal}(\mu_i,\\ \sigma_i^2) | fecundity varies normally around its expected value | explicit |
| linear_predictor | \mu_i = \beta_0 + \sum_k \beta_k X\_{ki} | Expected fecundity is a linear combination of the mean-model predictors | explicit |
| independence | F_i \perp F_j \mid X \text{ for } i \ne j | Observations are conditionally independent given the predictors | follows from the formula |
| no_missing_at_random | — | Observations are assumed not missing in a way that depends on the unobserved response | your responsibility |
| Residual cov(rainfall, temperature) | \mathrm{Cov}(\varepsilon\_{rainfall}, \varepsilon\_{temperature}) \neq 0 | Residual covariance between rainfall and temperature, declared explicitly (a bidirected arc, not a regression). | explicit |

## Three views of the whole SEM

[`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md)
renders the interactive *Index / Matrix / Matrix-with-data* widget for
**every node**, stacked under node headers. Each node carries its own
real data through the third tab:

``` r

as_html_three_views(sym, id = "psem")
```

## Node: body_size

[Skip three-views widget](#sym-psembodysize-1781037296-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

**Coefficient reading.** On the response scale, \hat\beta is the
additive change in the mean of the response for a one-unit increase in
the predictor (identity link – no back-transformation needed).

\begin{aligned} S_i \mid \mu_i,\\ \sigma & \sim \mathrm{Normal}(\mu_i,\\
\sigma^2) \\ \mu_i & = \beta\_{0} + \beta\_{1} \\ T_i \end{aligned}

where:

- S_i — response variable  \mathbb{R}^{120}
- T_i — continuous predictor  column of X (length 120)
- \mu_i — conditional mu of body_size  \mathbb{R}^{120}
- \sigma — residual standard deviation of body_size  scalar
- \beta\_{0}, \beta\_{1} — mu submodel coefficients  \mathbb{R}^{2}

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

\begin{aligned} \mathbf{s} \mid \boldsymbol{\mu},\\ \boldsymbol{\sigma}
& \sim \mathcal{N}(\boldsymbol{\mu},\\
\mathrm{diag}(\boldsymbol{\sigma}^2)) \\ \boldsymbol{\mu} & = \mathbf{X}
\boldsymbol{\beta} \end{aligned}

where:

- \mathbf{s} — response variable  \mathbb{R}^{120}
- \boldsymbol{\mu} — conditional mu of body_size  \mathbb{R}^{120}
- \boldsymbol{\sigma} — residual standard deviation of body_size  scalar
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{2}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{120 \times 2}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 120.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

For observation *i* = 1 of your data:

\begin{aligned} s\_{1} &= \hat\beta\_{0} +
\hat\beta\_{1}\\\mathrm{temperature}\_{1} + \hat\varepsilon\_{1}
&\quad(\text{response equation, one row of the model}) \\ \hat\mu\_{1}
&= 0.08 + 0.635 \times -0.626 \approx -0.318 &\quad(\text{predicted
mean} = \text{linear predictor}) \\ s\_{1} &=
\underbrace{-0.318}\_{\textstyle\\\hat\mu\_{1}\\\text{(predicted)}\\}
\\+\\
\underbrace{(0.712)}\_{\textstyle\\\hat\varepsilon\_{1}\\\text{(residual)}\\}
&\quad(\text{observed} = \text{predicted mean} + \text{residual})
\end{aligned}

Stacking the same response equation for all *n* = 120 observations:

\underbrace{\begin{bmatrix} 0.394 \\ 1.13 \\ -0.194 \\ -0.0811 \\ 1.33
\\ \vdots \\ -1.67 \\ -0.284
\end{bmatrix}}\_{\textstyle\\\mathbf{s}\_{\\120 \times
1}\\\text{(observed)}\\} \\=\\ \underbrace{\begin{bmatrix} 1 & -0.626 \\
1 & 0.184 \\ 1 & -0.836 \\ 1 & 1.6 \\ 1 & 0.33 \\ \vdots & \vdots \\ 1 &
0.494 \\ 1 & -0.177 \end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\120
\times 2}\\}\\ \underbrace{\begin{bmatrix} 0.08 \\ 0.635
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\2 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} 0.712 \\
0.929 \\ 0.256 \\ -1.17 \\ 1.04 \\ \vdots \\ -2.07 \\ -0.251
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}\_{\\120
\times 1}\\\text{(residual)}\\}

**Left**: observed vector \mathbf{s}. **Middle**: the prediction
\mathbf{X}\hat{\boldsymbol{\beta}} = \hat{\boldsymbol{\mu}}. **Right**:
the residual vector \hat{\boldsymbol{\varepsilon}} = \mathbf{s} -
\hat{\boldsymbol{\mu}}. Every row of this matrix equation is one of the
response-equation rows from the worked row above.

## Node: fecundity

[Skip three-views widget](#sym-psemfecundity-1781037296-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

**Coefficient reading.** On the response scale, \hat\beta is the
additive change in the mean of the response for a one-unit increase in
the predictor (identity link – no back-transformation needed).

\begin{aligned} F_i \mid \mu_i,\\ \sigma & \sim \mathrm{Normal}(\mu_i,\\
\sigma^2) \\ \mu_i & = \beta\_{0} + \beta\_{1} \\ S_i + \beta\_{2} \\
R_i \end{aligned}

where:

- F_i — response variable  \mathbb{R}^{120}
- S_i — continuous predictor  column of X (length 120)
- R_i — continuous predictor  column of X (length 120)
- \mu_i — conditional mu of fecundity  \mathbb{R}^{120}
- \sigma — residual standard deviation of fecundity  scalar
- \beta\_{0}, \beta\_{1}, \beta\_{2} — mu submodel coefficients
   \mathbb{R}^{3}

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

\begin{aligned} \mathbf{f} \mid \boldsymbol{\mu},\\ \boldsymbol{\sigma}
& \sim \mathcal{N}(\boldsymbol{\mu},\\
\mathrm{diag}(\boldsymbol{\sigma}^2)) \\ \boldsymbol{\mu} & = \mathbf{X}
\boldsymbol{\beta} \end{aligned}

where:

- \mathbf{f} — response variable  \mathbb{R}^{120}
- \boldsymbol{\mu} — conditional mu of fecundity  \mathbb{R}^{120}
- \boldsymbol{\sigma} — residual standard deviation of fecundity  scalar
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{3}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{120 \times 3}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 120.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

For observation *i* = 1 of your data:

\begin{aligned} f\_{1} &= \hat\beta\_{0} +
\hat\beta\_{1}\\\mathrm{body\\size}\_{1} +
\hat\beta\_{2}\\\mathrm{rainfall}\_{1} + \hat\varepsilon\_{1}
&\quad(\text{response equation, one row of the model}) \\ \hat\mu\_{1}
&= -0.0486 + 0.379 \times 0.394 + 0.379 \times -0.506 \approx -0.091
&\quad(\text{predicted mean} = \text{linear predictor}) \\ f\_{1} &=
\underbrace{-0.091}\_{\textstyle\\\hat\mu\_{1}\\\text{(predicted)}\\}
\\+\\
\underbrace{(-2.5)}\_{\textstyle\\\hat\varepsilon\_{1}\\\text{(residual)}\\}
&\quad(\text{observed} = \text{predicted mean} + \text{residual})
\end{aligned}

Stacking the same response equation for all *n* = 120 observations:

\underbrace{\begin{bmatrix} -2.59 \\ 2.17 \\ -0.778 \\ -0.516 \\ 0.332
\\ \vdots \\ 0.854 \\ -0.143
\end{bmatrix}}\_{\textstyle\\\mathbf{f}\_{\\120 \times
1}\\\text{(observed)}\\} \\=\\ \underbrace{\begin{bmatrix} 1 & 0.394 &
-0.506 \\ 1 & 1.13 & 1.34 \\ 1 & -0.194 & -0.215 \\ 1 & -0.0811 & -0.18
\\ 1 & 1.33 & -0.1 \\ \vdots & \vdots & \vdots \\ 1 & -1.67 & 1.1 \\ 1 &
-0.284 & -0.00534 \end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\120 \times
3}\\}\\ \underbrace{\begin{bmatrix} -0.0486 \\ 0.379 \\ 0.379
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\3 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} -2.5 \\ 1.28
\\ -0.574 \\ -0.369 \\ -0.0847 \\ \vdots \\ 1.12 \\ 0.0151
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}\_{\\120
\times 1}\\\text{(residual)}\\}

**Left**: observed vector \mathbf{f}. **Middle**: the prediction
\mathbf{X}\hat{\boldsymbol{\beta}} = \hat{\boldsymbol{\mu}}. **Right**:
the residual vector \hat{\boldsymbol{\varepsilon}} = \mathbf{f} -
\hat{\boldsymbol{\mu}}. Every row of this matrix equation is one of the
response-equation rows from the worked row above.

## The distributional flavour: `drmSEM`

A `piecewiseSEM` node is mean-only — one linear predictor per response.
When a path needs a **distributional** structure (a scale submodel, a
zero-inflation component, a residual correlation between two responses),
the node is a `drmTMB` location-scale fit and the SEM is built with
[`drmSEM::drm_sem()`](https://itchyshin.github.io/drmSEM/).
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
reads it through the `drmSEM`-side `symbolize.drm_sem` method, which
delegates each node to `symbolize.drmTMB`:

``` r

library(drmSEM)
library(drmTMB)

sem <- drm_sem(
  size = drm_node(drm_formula(size ~ temp, sigma ~ temp),
                  family = gaussian()),
  fec  = drm_node(drm_formula(fec ~ size + temp),
                  family = gaussian()),
  data = dat
)

sym <- symbolize(sem)   # dispatches to drmSEM::symbolize.drm_sem
equations(sym)          # node column + per-node mu AND sigma rows
assumption_table(sym)   # per-node assumptions, distributional
as_html_three_views(sym)  # same stacked widget, location-scale nodes
```

The `sigma ~ temp` submodel on the `size` node is what `piecewiseSEM`
cannot express: it models the **spread** of body size as a function of
temperature, not just the mean. Everything downstream — the equations,
the assumption table, the HTML widget — works identically, because both
collators share one parent class.

## Why the same methods work on both

`symbolize.psem` tags its output `symbolized_model_set`; `drmSEM`’s
`symbolize.drm_sem` tags its output the same way. Both store their nodes
in a **named** `parts` list. So the rendering generics dispatch on the
shared parent and read `names(x$parts)` — one implementation, two
collators. The capability registry records which package owns each
method:

``` r

caps <- symbolizer_capabilities()
caps[caps$class %in% c("piecewiseSEM", "drm_sem"),
     c("class", "status", "since", "lives_in", "notes")]
#> # A tibble: 2 × 5
#>   class        status since  lives_in   notes                                   
#>   <chr>        <chr>  <chr>  <chr>      <chr>                                   
#> 1 piecewiseSEM Stable 0.22.4 symbolizer Walks psem list-of-fits; each fitted no…
#> 2 drm_sem      Stable 0.22.4 drmSEM     Method lives in drmSEM::symbolize.drm_s…
```

|  | `piecewiseSEM` (`psem`) | `drmSEM` (`drm_sem`) |
|----|----|----|
| Per-node model | `lm` / `glm` / `lmer` / `glmer` / `glmmTMB` / `lme` | `drmTMB` location-scale |
| Structure per node | mean only (one linear predictor) | distributional (`mu`, `sigma`, `nu`, `zi`, `hu`, `rho12`) |
| Method lives in | `symbolizer` (bundled) | `drmSEM` |
| Collator class | `symbolized_psem` → `symbolized_model_set` | `symbolized_drm_sem` → `symbolized_model_set` |
| `%~~%` / residual covariance | `Residual cov(...)` assumption row | per-node `rho12` distributional component |

Reach for `piecewiseSEM` when each response is adequately summarised by
its mean; reach for `drmSEM` when a path’s **variance, skew, or
zero-inflation** is itself part of the story.
