# Get started with symbolizer

`symbolizer` turns a fitted model into a *structured symbolic model* —
an object your renderers read to produce publication-ready equations,
assumption tables, and per-coefficient interpretations. This is the
five-minute tour: one model, one
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
call, and the three things you get back. It runs on **base R alone** —
nothing to install.

## Why structured symbolic models

[`equatiomatic`](https://datalorax.github.io/equatiomatic/) renders a
fitted model as a LaTeX string — enough when the only goal is a
publishable equation. `symbolizer` returns a richer object: from the
same `symbolized_model` you can pull the equation (in both index and
matrix notation), the symbol dictionary, the assumption table (each
assumption labelled *stated* / *implied* / *not checked*), the
formula-to-math bridge, and the per-coefficient interpretation on link,
natural, variance, and biological scales.

**Takeaway.** The product is the `symbolized_model` object; everything
else is a renderer of that object.

## A short glossary

If formula-grammar terminology isn’t second nature, here’s the quickest
map of what each word means in a biology context.

| word | meaning |
|:---|:---|
| response | the outcome you measured (e.g., body mass, abundance). |
| predictor | a variable you think influences the response. |
| factor | a categorical predictor with named levels (e.g., sex with “female” and “male”). |
| submodel | one piece of the formula. A location-scale model has two submodels: one for the mean (mu), one for the residual SD (sigma). |
| linear predictor | the sum that determines a parameter for an observation: intercept + slope x predictor + … Sometimes a link function (e.g., log) is applied first. |
| design matrix | the table the computer multiplies coefficients by to get fitted values. Each row is one observation; each column is one term. |
| coefficient | a single number the model estimates: an intercept, a slope, or a factor contrast. |
| link function | the transformation between a parameter’s natural scale (e.g., a count) and the scale the linear predictor works on (e.g., log-count). |

(For how a factor becomes 0/1 dummy columns, and contrasts in depth, see
[`vignette("symbolizer-factors")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-factors.md).)

## Your first fit

We use a model every R user already has: a base-R Poisson GLM of a count
against a predictor. No non-CRAN packages required.

``` r

library(symbolizer)

set.seed(1)
n <- 80
temperature <- runif(n, 10, 25)
dat <- data.frame(
  count       = rpois(n, exp(0.3 + 0.08 * temperature)),
  temperature = temperature
)

fit <- glm(count ~ temperature, family = poisson, data = dat)
```

[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
is the single entry point. Pass user-facing symbols and units so the
equations carry biological meaning rather than R variable names:

``` r

sym <- symbolize(
  fit,
  symbols = c(count = "N_i", temperature = "T_i"),
  units   = c(temperature = "C"),
  context = "abundance ~ temperature, Poisson GLM"
)
```

That’s it — `sym` is the structured object. The rest of this page shows
the three things it gives you.

## The three things symbolizer gives you

### 1. The equation, in real math

[`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md)
returns one row per renderable block;
[`as_latex()`](https://itchyshin.github.io/symbolizer/reference/as_latex.md)
produces the string you splice into a manuscript. The Poisson log link
shows up explicitly:

``` r

cat("$$", as_latex(sym, notation = "both"), "$$", sep = "\n")
```

\text{(index notation)} \begin{aligned} N_i \mid \mu_i & \sim
\mathrm{Poisson}(\mu_i) \\ \log(\mu_i) & = \beta\_{0} + \beta\_{1} \\
T_i \end{aligned} \text{(matrix notation)} \begin{aligned} \mathbf{n}
\mid \boldsymbol{\mu} & \sim \mathrm{Poisson}(\boldsymbol{\mu}) \\
\log(\boldsymbol{\mu}) & = \mathbf{X} \boldsymbol{\beta} \end{aligned}

Bold lowercase is a vector (\boldsymbol{\mu}, \boldsymbol{\beta}), bold
uppercase a matrix (\mathbf{X}); the index form drops to per-observation
symbols (\mu_i, \beta_0, \beta_1, T_i).

### 2. Three views of the fit

[`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md)
is a self-contained widget with three tabs over the same fit, in the
order they appear in the widget: the per-observation **index** form, the
matrix-form **equation**, and **equations with data** — the response
column, the design-matrix rows, the coefficient vector, and the fitted
mean \hat{\boldsymbol{\mu}}.

``` r

as_html_three_views(sym, head = 5, tail = 2)
```

[Skip three-views widget](#sym-sym-1780182281-end)

▸1. Index

▸2. Matrix

▸3. Equations with data

What happens for each observation *i* – the per-individual reading.

Each observation is a count; the log of the expected count may shift
with the predictors.

**Coefficient reading.** On the response scale, \exp(\hat\beta) is the
rate ratio: a one-unit increase in the predictor multiplies the expected
count by \exp(\hat\beta) (log link).

\begin{aligned} N_i \mid \mu_i & \sim \mathrm{Poisson}(\mu_i) \\
\log(\mu_i) & = \beta\_{0} + \beta\_{1} \\ T_i \end{aligned}

where:

- N_i — response variable  \mathbb{R}^{80}
- T_i — continuous predictor  column of X (length 80)
- \mu_i — conditional mu of count  \mathbb{R}^{80}
- \beta\_{0}, \beta\_{1} — mu submodel coefficients  \mathbb{R}^{2}

The same model in matrix form – the structural contract every textbook
past chapter 4 switches to.

Each observation is a count; the log of the expected count may shift
with the predictors.

\begin{aligned} \mathbf{n} \mid \boldsymbol{\mu} & \sim
\mathrm{Poisson}(\boldsymbol{\mu}) \\ \log(\boldsymbol{\mu}) & =
\mathbf{X} \boldsymbol{\beta} \end{aligned}

where:

- \mathbf{n} — response variable  \mathbb{R}^{80}
- \boldsymbol{\mu} — conditional mu of count  \mathbb{R}^{80}
- \boldsymbol{\beta} — mu submodel coefficients  \mathbb{R}^{2}
- \mathbf{X} — mu submodel design matrix  \mathbb{R}^{80 \times 2}

The same matrix equation, with your actual numbers stacked inside the
brackets – what the computer multiplies. Showing first 5 and last 2 rows
of n = 80.

Each observation is a count; the log of the expected count may shift
with the predictors.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

For observation *i* = 1 of your data:

\begin{aligned} \hat\eta\_{1} &= \hat\beta\_{0} +
\hat\beta\_{1}\\\mathrm{temperature}\_{1}&\quad(\text{linear predictor,
link scale}) \\ 1.37 &= 0.168 + 0.0861 \times 14&\quad(\text{with your
numbers}) \\ \hat\mu\_{1} &= \exp(\hat\eta\_{1}) = \exp(1.37) \approx
3.94&\quad(\text{response scale, predicted}) \\ n\_{1} &\sim
\mathrm{Poisson}(\hat\mu\_{1})&\quad(\text{likelihood; no additive
}\varepsilon\text{ here}) \end{aligned}

Stacking the same response equation for all *n* = 80 observations:

\underbrace{\begin{bmatrix} 1.37 \\ 1.51 \\ 1.77 \\ 2.2 \\ 1.29 \\
\vdots \\ 2.03 \\ 2.27
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\eta}}\_{\\80 \times
1}\\\text{(linear predictor, link scale)}\\} \\=\\
\underbrace{\begin{bmatrix} 1 & 14 \\ 1 & 15.6 \\ 1 & 18.6 \\ 1 & 23.6
\\ 1 & 13 \\ \vdots & \vdots \\ 1 & 21.7 \\ 1 & 24.4
\end{bmatrix}}\_{\textstyle\\\mathbf{X}\_{\\80 \times 2}\\}\\
\underbrace{\begin{bmatrix} 0.168 \\ 0.0861
\end{bmatrix}}\_{\textstyle\\\hat{\boldsymbol{\beta}}\_{\\2 \times
1}\\\text{(estimated)}\\}

**Left**: linear predictor \hat{\boldsymbol{\eta}} on the link scale.
**Right**: \mathbf{X}\hat{\boldsymbol{\beta}} — the same linear
predictor in matrix form. There is no additive residual on the link
scale: each \mathbf{n}\_i has its own likelihood row above,
\mathbf{n}\_i \sim \mathrm{Family}(\hat{\mu}\_i), with the
response-scale mean recovered as \hat{\boldsymbol{\mu}} =
g^{-1}(\hat{\boldsymbol{\eta}}) (the inverse-link back-transform shown
in the worked row).

### 3. What each coefficient means

[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
reads every estimate on the scales that make sense for the model. For a
Poisson GLM the natural-scale reading is the **rate ratio**:
\exp(\hat\beta) multiplies the expected count per unit of the predictor.

``` r

parameter_interpretation(sym)
```

| submodel | term_label | coefficient_role | estimate | 95% CI | link_scale_reading | natural_scale_reading | variance_scale_reading | biological_reading |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 0.168 | -0.296, 0.632 | Log expected count at the reference (count = exp(0.168)) | Expected count at the reference is exp(0.168) | — | Baseline count of count in the reference condition is exp(0.168) |
| mu | temperature | slope | 0.0861 | 0.0624, 0.110 \* | Log expected count changes by 0.0861 per unit of temperature | Expected count multiplied by exp(0.0861) per unit of temperature | — | A unit change in temperature multiplies the expected count of count by exp(0.0861) |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

**Takeaway.** One
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
call → the equation, the three-views widget, and a per-coefficient
reading you can paste straight into a Methods section.

## Where to go next

- **Build up from `lm` to location-scale**, one rung at a time on a
  shared dataset —
  [`vignette("symbolizer-ladder")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-ladder.md).
- **A tour of non-Gaussian families** (Gamma, beta, binomial, negative
  binomial, …) —
  [`vignette("symbolizer-families")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-families.md).
- **Factors, dummies, and interactions** in depth —
  [`vignette("symbolizer-factors")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-factors.md).
- **Random effects, ICC, and repeatability** —
  [`vignette("symbolizer-variance-components")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-variance-components.md).
- **The full function reference** —
  [`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md),
  [`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md),
  [`formula_bridge()`](https://itchyshin.github.io/symbolizer/reference/formula_bridge.md),
  [`notation_bridge()`](https://itchyshin.github.io/symbolizer/reference/notation_bridge.md),
  [`model_card()`](https://itchyshin.github.io/symbolizer/reference/model_card.md),
  [`expand()`](https://itchyshin.github.io/symbolizer/reference/expand.md),
  [`as_dag()`](https://itchyshin.github.io/symbolizer/reference/as_dag.md),
  and the rest — in the package’s *Reference* index.
- **What’s supported and what’s planned** across the ten model families
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  reads (`drmTMB`, `gllvmTMB`, `glmmTMB`, `brms`, `lme4`, `MCMCglmm`,
  `sdmTMB`, [`stats::lm`](https://rdrr.io/r/stats/lm.html)/`glm`,
  `metafor`, `mgcv`) —
  [`vignette("symbolizer-roadmap")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-roadmap.md),
  or call
  [`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md).
