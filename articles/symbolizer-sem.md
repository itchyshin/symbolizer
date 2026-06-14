# Multi-node structural equation models: piecewiseSEM and drmSEM

> *A piecewise structural equation model is a **system** of regressions
> — one fitted model per response, wired together into a hypothesized
> causal graph. This article shows how
> [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
> reads the whole system: it walks each node, symbolizes it with the
> node’s own class method, and hands back a collator whose equations,
> assumption table, and HTML widget are stacked node by node. Two
> flavours are covered: mean-only piecewise SEMs from `piecewiseSEM`,
> and distributional (location-scale — modelling spread or skew, not
> just the mean) piecewise SEMs from `drmSEM`.*

[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
reports the **structure** of a model system — its responses, predictors,
links, and distributional assumptions — not the fitted coefficients,
significance, or goodness-of-fit. The directed paths below are the
analyst’s *assumed* structure; whether the data support them is a
separate question (see Shipley’s d-separation test in `piecewiseSEM`).

## A SEM is a list of regressions

Where a single GLM has one response, a piecewise SEM has several — each
its own fitted model, each a **node** in a directed graph. A variable
that is a predictor in one node is a response in another.

We use the `keeley` data bundled with `piecewiseSEM`: 90 plots of
California shrubland surveyed after wildfire (Grace & Keeley 2006). Five
of its columns appear below — stand **age**, **fire severity**
(`firesev`), an **abiotic** favourability index (`abiotic`), plant
**cover**, and species **richness** (`rich`). A simplified slice of the
Grace & Keeley causal backbone posits four directed paths plus one
correlated-error arc:

- `firesev ~ age` — the model treats fire severity as a response to
  stand age (older stands carry more accumulated fuel),
- `cover ~ firesev` — plant cover as a response to fire severity,
- `rich ~ abiotic + firesev` — richness as a response to abiotic
  favourability and fire severity,
- `rich %~~% cover` — richness and cover are allowed a residual
  covariance (some shared unmeasured cause beyond their common
  dependence on fire), declared as a bidirected arc, **not** a
  regression. *(This arc is added here to illustrate the feature; the
  age→firesev→cover/rich paths are the simplified published backbone.)*

[`piecewiseSEM::psem()`](https://rdrr.io/pkg/piecewiseSEM/man/psem.html)
glues those fitted nodes into one object.
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
reads it as a unit.

``` r

library(piecewiseSEM)
data(keeley)

sem <- psem(
  lm(firesev ~ age,              data = keeley),
  lm(cover   ~ firesev,          data = keeley),
  lm(rich    ~ abiotic + firesev, data = keeley),
  rich %~~% cover,
  data = keeley
)
#> Warning: the 'nobars' function has moved to the reformulas package. Please update your imports, or ask an upstream package maintainer to do so.
#> This warning is displayed once per session.

sym <- symbolize(
  sem,
  symbols = c(firesev = "F_i", cover = "C_i", rich = "R_i",
              age = "A_i", abiotic = "B_i")
)
sym
#> <symbolized_psem>: 3 nodes
#>   - firesev (lm, gaussian)
#>   - cover (lm, gaussian)
#>   - rich (lm, gaussian)
#>   1 residual covariance arc: rich ~~ cover
```

[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
returns a `symbolized_psem` — a collator holding one `symbolized_model`
per node (`sym$parts`), the node names in declared order
(`sym$node_names`), and any `%~~%` arcs (`sym$cov_arcs`). Every node was
dispatched on its own class:

``` r

sym$node_names
#> [1] "firesev" "cover"   "rich"
vapply(sym$parts, function(p) p$model$class, character(1))
#> firesev   cover    rich 
#>    "lm"    "lm"    "lm"
```

## The equations, node by node

[`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md)
row-binds every node’s equation block with a leading `node` column, so
you can work with the whole system in R. The rendered widget below shows
the same node equations without exposing raw LaTeX in the article:

``` r

equations(sym)
```

[`as_latex()`](https://itchyshin.github.io/symbolizer/reference/as_latex.md)
concatenates the per-node LaTeX under `## Node:` headers, ready to
splice into a manuscript. The command is run during the vignette build,
but the raw LaTeX string is not printed in the HTML article:

``` r

cat(as_latex(sym))
```

## The assumptions — including the covariance arc

[`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md)
row-binds each node’s assumptions, again with a leading `node` column.
The `%~~%` arc surfaces here as a `Residual cov(...)` row — and **only**
here. A bidirected arc (the `%~~%` arc) is a covariance, not a
regression, so it never appears as an equation. It records only that two
residuals *covary*; it neither names the source nor implies one response
affects the other:

``` r

assumption_table(sym)
```

| assumption | expression | biological meaning | status |
|:---|:---|:---|:---|
| conditional_distribution | F_i \mid \mu_i,\\ \sigma_i \sim \mathrm{Normal}(\mu_i,\\ \sigma_i^2) | firesev varies normally around its expected value | explicit |
| linear_predictor | \mu_i = \beta_0 + \sum_k \beta_k X\_{ki} | Expected firesev is a linear combination of the mean-model predictors | explicit |
| independence | F_i \perp F_j \mid X \text{ for } i \ne j | Observations are conditionally independent given the predictors | follows from the formula |
| no_missing_at_random | — | Observations are assumed not missing in a way that depends on the unobserved response | your responsibility |
| conditional_distribution | C_i \mid \mu_i,\\ \sigma_i \sim \mathrm{Normal}(\mu_i,\\ \sigma_i^2) | cover varies normally around its expected value | explicit |
| linear_predictor | \mu_i = \beta_0 + \sum_k \beta_k X\_{ki} | Expected cover is a linear combination of the mean-model predictors | explicit |
| independence | C_i \perp C_j \mid X \text{ for } i \ne j | Observations are conditionally independent given the predictors | follows from the formula |
| no_missing_at_random | — | Observations are assumed not missing in a way that depends on the unobserved response | your responsibility |
| conditional_distribution | R_i \mid \mu_i,\\ \sigma_i \sim \mathrm{Normal}(\mu_i,\\ \sigma_i^2) | rich varies normally around its expected value | explicit |
| linear_predictor | \mu_i = \beta_0 + \sum_k \beta_k X\_{ki} | Expected rich is a linear combination of the mean-model predictors | explicit |
| independence | R_i \perp R_j \mid X \text{ for } i \ne j | Observations are conditionally independent given the predictors | follows from the formula |
| no_missing_at_random | — | Observations are assumed not missing in a way that depends on the unobserved response | your responsibility |
| Residual cov(rich, cover) | \mathrm{Cov}(\varepsilon\_{rich}, \varepsilon\_{cover}) \neq 0 | Residual covariance between rich and cover, declared explicitly (a bidirected arc, not a regression). | explicit |

## Three views of the whole SEM

[`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md)
renders the interactive three-views widget for **every node**, stacked
under node headers: the per-observation *Index* form, the *Matrix* form,
and the matrix form populated with the node’s own real data (see
[`vignette("symbolizer")`](https://itchyshin.github.io/symbolizer/articles/symbolizer.md)
for what each view shows).

``` r

as_html_three_views(sym, id = "psem")
```

## Node: firesev

[Skip three-views widget](#sym-psemfiresev-1781444295-end)

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
\sigma^2) \\ \mu_i & = \beta\_{0} + \beta\_{1} \\ A_i \end{aligned}

where:

- F_i — response variable  \mathbb{R}^{90}
- A_i — continuous predictor  column of X (length 90)
- \mu_i — conditional mu of firesev  \mathbb{R}^{90}
- \sigma — residual standard deviation of firesev  scalar
- \beta\_{0}, \beta\_{1} — mu submodel coefficients  \mathbb{R}^{2}

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

\begin{aligned} \mathbf{f} \mid \boldsymbol{\mu},\\ \boldsymbol{\sigma}
& \sim \mathcal{N}(\boldsymbol{\mu},\\
\mathrm{diag}(\boldsymbol{\sigma}^2)) \\ \boldsymbol{\mu} & = \mathbf{X}
\boldsymbol{\beta} \end{aligned}

where:

- \mathbf{f} — response variable  \mathbb{R}^{90}
- \boldsymbol{\mu} — conditional mu of firesev  \mathbb{R}^{90}
- \boldsymbol{\sigma} — residual standard deviation of firesev  scalar
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{2}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{90 \times 2}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 90.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

For observation *i* = 1 of your data:

\begin{aligned} f\_{1} &= \hat\beta\_{0} +
\hat\beta\_{1}\\\mathrm{age}\_{1} + \hat\varepsilon\_{1}
&\quad(\text{response equation, one row of the model}) \\ \hat\mu\_{1}
&= 3.04 + 0.0597 \times 40 \approx 5.43 &\quad(\text{predicted mean} =
\text{linear predictor}) \\ f\_{1} &=
\underbrace{5.43}\_{\textstyle\\\hat\mu\_{1}\\\text{(predicted)}\\}
\\+\\
\underbrace{(-1.93)}\_{\textstyle\\\hat\varepsilon\_{1}\\\text{(residual)}\\}
&\quad(\text{observed} = \text{predicted mean} + \text{residual})
\end{aligned}

Stacking the same response equation for all *n* = 90 observations:

\underbrace{\begin{bmatrix} 3.5 \\ 4.05 \\ 2.6 \\ 2.9 \\ 4.3 \\ \vdots
\\ 3.9 \\ 4.6 \end{bmatrix}}\_{\textstyle\\\mathbf{f}\_{\\90 \times
1}\\\text{(observed)}\\} \\=\\ \underbrace{\begin{bmatrix} 1 & 40 \\ 1 &
25 \\ 1 & 15 \\ 1 & 15 \\ 1 & 23 \\ \vdots & \vdots \\ 1 & 60 \\ 1 & 36
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\90 \times 2}\\}\\
\underbrace{\begin{bmatrix} 3.04 \\ 0.0597
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\2 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} -1.93 \\
-0.481 \\ -1.33 \\ -1.03 \\ -0.112 \\ \vdots \\ -2.72 \\ -0.588
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}\_{\\90
\times 1}\\\text{(residual)}\\}

**Left**: observed vector \mathbf{f}. **Middle**: the prediction
\mathbf{X}\hat{\boldsymbol{\beta}} = \hat{\boldsymbol{\mu}}. **Right**:
the residual vector \hat{\boldsymbol{\varepsilon}} = \mathbf{f} -
\hat{\boldsymbol{\mu}}. Every row of this matrix equation is one of the
response-equation rows from the worked row above.

## Node: cover

[Skip three-views widget](#sym-psemcover-1781444295-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

**Coefficient reading.** On the response scale, \hat\beta is the
additive change in the mean of the response for a one-unit increase in
the predictor (identity link – no back-transformation needed).

\begin{aligned} C_i \mid \mu_i,\\ \sigma & \sim \mathrm{Normal}(\mu_i,\\
\sigma^2) \\ \mu_i & = \beta\_{0} + \beta\_{1} \\ F_i \end{aligned}

where:

- C_i — response variable  \mathbb{R}^{90}
- F_i — continuous predictor  column of X (length 90)
- \mu_i — conditional mu of cover  \mathbb{R}^{90}
- \sigma — residual standard deviation of cover  scalar
- \beta\_{0}, \beta\_{1} — mu submodel coefficients  \mathbb{R}^{2}

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

\begin{aligned} \mathbf{c} \mid \boldsymbol{\mu},\\ \boldsymbol{\sigma}
& \sim \mathcal{N}(\boldsymbol{\mu},\\
\mathrm{diag}(\boldsymbol{\sigma}^2)) \\ \boldsymbol{\mu} & = \mathbf{X}
\boldsymbol{\beta} \end{aligned}

where:

- \mathbf{c} — response variable  \mathbb{R}^{90}
- \boldsymbol{\mu} — conditional mu of cover  \mathbb{R}^{90}
- \boldsymbol{\sigma} — residual standard deviation of cover  scalar
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{2}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{90 \times 2}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 90.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

For observation *i* = 1 of your data:

\begin{aligned} c\_{1} &= \hat\beta\_{0} +
\hat\beta\_{1}\\\mathrm{firesev}\_{1} + \hat\varepsilon\_{1}
&\quad(\text{response equation, one row of the model}) \\ \hat\mu\_{1}
&= 1.07 - 0.0839 \times 3.5 \approx 0.781 &\quad(\text{predicted mean} =
\text{linear predictor}) \\ c\_{1} &=
\underbrace{0.781}\_{\textstyle\\\hat\mu\_{1}\\\text{(predicted)}\\}
\\+\\
\underbrace{(0.258)}\_{\textstyle\\\hat\varepsilon\_{1}\\\text{(residual)}\\}
&\quad(\text{observed} = \text{predicted mean} + \text{residual})
\end{aligned}

Stacking the same response equation for all *n* = 90 observations:

\underbrace{\begin{bmatrix} 1.04 \\ 0.478 \\ 0.949 \\ 1.19 \\ 1.3 \\
\vdots \\ 0.581 \\ 0.379 \end{bmatrix}}\_{\textstyle\\\mathbf{c}\_{\\90
\times 1}\\\text{(observed)}\\} \\=\\ \underbrace{\begin{bmatrix} 1 &
3.5 \\ 1 & 4.05 \\ 1 & 2.6 \\ 1 & 2.9 \\ 1 & 4.3 \\ \vdots & \vdots \\ 1
& 3.9 \\ 1 & 4.6 \end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\90 \times
2}\\}\\ \underbrace{\begin{bmatrix} 1.07 \\ -0.0839
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\2 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} 0.258 \\
-0.257 \\ 0.0928 \\ 0.364 \\ 0.585 \\ \vdots \\ -0.166 \\ -0.31
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}\_{\\90
\times 1}\\\text{(residual)}\\}

**Left**: observed vector \mathbf{c}. **Middle**: the prediction
\mathbf{X}\hat{\boldsymbol{\beta}} = \hat{\boldsymbol{\mu}}. **Right**:
the residual vector \hat{\boldsymbol{\varepsilon}} = \mathbf{c} -
\hat{\boldsymbol{\mu}}. Every row of this matrix equation is one of the
response-equation rows from the worked row above.

## Node: rich

[Skip three-views widget](#sym-psemrich-1781444295-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

**Coefficient reading.** On the response scale, \hat\beta is the
additive change in the mean of the response for a one-unit increase in
the predictor (identity link – no back-transformation needed).

\begin{aligned} R_i \mid \mu_i,\\ \sigma & \sim \mathrm{Normal}(\mu_i,\\
\sigma^2) \\ \mu_i & = \beta\_{0} + \beta\_{1} \\ B_i + \beta\_{2} \\
F_i \end{aligned}

where:

- R_i — response variable  \mathbb{R}^{90}
- B_i — continuous predictor  column of X (length 90)
- F_i — continuous predictor  column of X (length 90)
- \mu_i — conditional mu of rich  \mathbb{R}^{90}
- \sigma — residual standard deviation of rich  scalar
- \beta\_{0}, \beta\_{1}, \beta\_{2} — mu submodel coefficients
   \mathbb{R}^{3}

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

\begin{aligned} \mathbf{r} \mid \boldsymbol{\mu},\\ \boldsymbol{\sigma}
& \sim \mathcal{N}(\boldsymbol{\mu},\\
\mathrm{diag}(\boldsymbol{\sigma}^2)) \\ \boldsymbol{\mu} & = \mathbf{X}
\boldsymbol{\beta} \end{aligned}

where:

- \mathbf{r} — response variable  \mathbb{R}^{90}
- \boldsymbol{\mu} — conditional mu of rich  \mathbb{R}^{90}
- \boldsymbol{\sigma} — residual standard deviation of rich  scalar
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{3}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{90 \times 3}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 90.

Each observation is normally distributed around a mean that may shift
with the predictors; the residual SD is constant across observations.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

For observation *i* = 1 of your data:

\begin{aligned} r\_{1} &= \hat\beta\_{0} +
\hat\beta\_{1}\\\mathrm{abiotic}\_{1} +
\hat\beta\_{2}\\\mathrm{firesev}\_{1} + \hat\varepsilon\_{1}
&\quad(\text{response equation, one row of the model}) \\ \hat\mu\_{1}
&= 16.9 + 0.887 \times 60.7 - 2.49 \times 3.5 \approx 62
&\quad(\text{predicted mean} = \text{linear predictor}) \\ r\_{1} &=
\underbrace{ 62}\_{\textstyle\\\hat\mu\_{1}\\\text{(predicted)}\\} \\+\\
\underbrace{(
-11)}\_{\textstyle\\\hat\varepsilon\_{1}\\\text{(residual)}\\}
&\quad(\text{observed} = \text{predicted mean} + \text{residual})
\end{aligned}

Stacking the same response equation for all *n* = 90 observations:

\underbrace{\begin{bmatrix} 51 \\ 31 \\ 71 \\ 64 \\ 68 \\ \vdots \\ 47
\\ 44 \end{bmatrix}}\_{\textstyle\\\mathbf{r}\_{\\90 \times
1}\\\text{(observed)}\\} \\=\\ \underbrace{\begin{bmatrix} 1 & 60.7 &
3.5 \\ 1 & 40.9 & 4.05 \\ 1 & 51 & 2.6 \\ 1 & 61.2 & 2.9 \\ 1 & 46.7 &
4.3 \\ \vdots & \vdots & \vdots \\ 1 & 39.9 & 3.9 \\ 1 & 44.3 & 4.6
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\90 \times 3}\\}\\
\underbrace{\begin{bmatrix} 16.9 \\ 0.887 \\ -2.49
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\3 \times
1}\\\text{(estimated)}\\} \\+\\ \underbrace{\begin{bmatrix} -11 \\ -12.2
\\ 15.3 \\ 0.0511 \\ 20.4 \\ \vdots \\ 4.35 \\ -0.764
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\varepsilon}}\_{\\90
\times 1}\\\text{(residual)}\\}

**Left**: observed vector \mathbf{r}. **Middle**: the prediction
\mathbf{X}\hat{\boldsymbol{\beta}} = \hat{\boldsymbol{\mu}}. **Right**:
the residual vector \hat{\boldsymbol{\varepsilon}} = \mathbf{r} -
\hat{\boldsymbol{\mu}}. Every row of this matrix equation is one of the
response-equation rows from the worked row above.

## The distributional flavour: `drmSEM`

A `piecewiseSEM` node is mean-only — one linear predictor per response.
It can model how the **mean** of cover responds to fire severity, but
not how the **spread** of cover changes. When a path needs a
**distributional** structure (a scale submodel, a zero-inflation
component, a residual correlation between two responses), the node is a
`drmTMB` location-scale fit and the SEM is built with
[`drmSEM::drm_sem()`](https://itchyshin.github.io/drmSEM/).
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
reads it through the `drmSEM`-side `symbolize.drm_sem` method, which
delegates each node to `symbolize.drmTMB`.

The code below is **not run here** (it needs the `drmSEM` and `drmTMB`
packages); it continues the same `keeley` story. Suppose we wanted to
ask whether the residual *spread* of cover widens at high fire severity
— plausible when severe burns produce divergent recovery — which the
mean-only [`lm()`](https://rdrr.io/r/stats/lm.html) node cannot express:

``` r

library(drmSEM)
library(drmTMB)

sem <- drm_sem(
  # The `cover` node gains a SCALE submodel: `sigma ~ firesev` lets the
  # variability of cover -- not just its mean -- depend on fire severity.
  cover   = drm_node(drm_formula(cover ~ firesev, sigma ~ firesev),
                     family = gaussian()),
  firesev = drm_node(drm_formula(firesev ~ age),
                     family = gaussian()),
  data = keeley
)

sym <- symbolize(sem)     # dispatches to drmSEM::symbolize.drm_sem
sym                       # <symbolized_drm_sem>: 2 nodes ...
equations(sym)            # node column + per-node mu AND sigma rows
assumption_table(sym)     # per-node assumptions, distributional
as_html_three_views(sym)  # the same stacked widget, location-scale nodes
```

Everything downstream — the equations, the assumption table, the HTML
widget — works identically on the `drm_sem`, because both collators
share one parent class. See the [drmSEM
site](https://itchyshin.github.io/drmSEM/) for runnable
distributional-SEM examples.

## Why the same methods work on both

Every renderer you just saw —
[`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md),
[`as_latex()`](https://itchyshin.github.io/symbolizer/reference/as_latex.md),
[`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md),
[`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md)
— works identically on a `drm_sem`. Here is the mechanism.
`symbolize.psem` tags its output `symbolized_psem`, which inherits from
`symbolized_model_set`; `drmSEM`’s `symbolize.drm_sem` tags its output
`symbolized_drm_sem`, which inherits from the same parent. Both store
their nodes in a **named** `parts` list. So the rendering generics
dispatch on the shared parent and read `names(x$parts)` — one
implementation, two collators. The capability registry records which
package owns each method:

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
| Per-node model | `lm` / `glm` / `lmer` / `glmer` / `glmmTMB` | `drmTMB` location-scale |
| Structure per node | mean only (one linear predictor) | distributional (`mu`, `sigma`, `nu`, `zi`, `hu`, `rho12`) |
| Method lives in | `symbolizer` (bundled) | `drmSEM` |
| Collator class | `symbolized_psem` → `symbolized_model_set` | `symbolized_drm_sem` → `symbolized_model_set` |
| `%~~%` / residual covariance | `Residual cov(...)` assumption row | per-node `rho12` distributional component |

Reach for `piecewiseSEM` when each response is adequately summarised by
its mean; reach for `drmSEM` when a path’s **variance, skew, or
zero-inflation** is itself part of the story.

## References

Grace, J. B., & Keeley, J. E. (2006). A structural equation model
analysis of postfire plant diversity in California shrublands.
*Ecological Applications*, 16(2), 503–514.
<https://doi.org/10.1890/1051-0761(2006)016%5B0503:ASEMAO%5D2.0.CO;2>

Lefcheck, J. S. (2016). piecewiseSEM: Piecewise structural equation
modelling in R for ecology, evolution, and systematics. *Methods in
Ecology and Evolution*, 7(5), 573–579.
<https://doi.org/10.1111/2041-210X.12512>

Shipley, B. (2009). Confirmatory path analysis in a generalized
multilevel context. *Ecology*, 90(2), 363–368.
<https://doi.org/10.1890/08-1034.1>
