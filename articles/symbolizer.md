# Get started with symbolizer

## Why structured symbolic models

[`equatiomatic`](https://datalorax.github.io/equatiomatic/) renders a
fitted model as a LaTeX string. That is enough when the only goal is a
publishable equation. `symbolizer` returns a richer object: a
*structured symbolic model* that other renderers can read. From the same
object you can pull the equation, the symbol dictionary, the assumption
table, the formula-to-math bridge, and the per-coefficient
interpretation on link, natural, variance, and biological scales.

The package is educator-first. It exposes equations in both index
(scalar) and matrix notation side by side, and it labels every
assumption as *stated*, *implied*, or *not checked* so a reader can see
what the fit guarantees and what it does not.

**Takeaway.** The product is the `symbolized_model` object; everything
else is a renderer of that object.

## A short glossary

If you don’t read formula-grammar terminology fluently, here’s the
quickest possible map of what each word means in a biology context.

| word | meaning |
|:---|:---|
| response | the outcome you measured (e.g., body mass, abundance). |
| predictor | a variable you think influences the response. |
| factor | a categorical predictor with named levels (e.g., sex with “female” and “male”). |
| submodel | one piece of the formula. A location-scale model has two submodels: one for the mean (mu), one for the residual SD (sigma). |
| linear predictor | the sum that determines a parameter for an observation: intercept + slope x predictor + … Sometimes a link function (e.g., log) is applied to make it work on its natural scale. |
| design matrix | the table the computer multiplies coefficients by to get fitted values. Each row is one observation; each column is one term (intercept, slope, factor contrast, …). |
| coefficient | a single number the model estimates: an intercept, a slope, or a factor contrast. |
| link function | the transformation between a parameter’s natural scale (e.g., probability) and the scale the linear predictor works on (e.g., logit). For `sigma` in a location-scale model, the link is log, so the linear predictor models log(sigma). |
| random intercept | a per-group offset that lets each group have its own baseline, while assuming those offsets follow a shared distribution. |
| latent variable | an unmeasured axis the model uses to explain shared variation in multiple traits or species. (Used in gllvmTMB.) |
| loading | how strongly a single trait or species responds to a latent axis. |

### How a factor becomes 0/1 columns

When you put a factor like `sex` (with levels `female`, `male`) in a
formula, R automatically encodes the non-reference levels as **dummy
variables**: 0/1 columns the model can multiply by coefficients.

| Observation | sex    | sexmale (dummy column) |
|-------------|--------|------------------------|
| 1           | female | 0                      |
| 2           | male   | 1                      |
| 3           | female | 0                      |

For a `k`-level factor, R makes `k-1` dummy columns. The first level
(alphabetical by default) is the **reference**: it doesn’t get a column
of its own and lives inside the intercept.
[`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md)
marks the reference explicitly – look for the `[reference]` tag in the
description.

The `sexmale` coefficient is the *difference* between male and female
means at the reference values of any other predictors, not the male mean
itself.

**Takeaway.** A k-level factor produces k-1 dummy columns. The reference
level lives inside the intercept; each contrast coefficient is a
*difference* from the reference.

**Takeaway.** If a word above is unfamiliar, treat the next section as a
hands-on definition by example.

## A first `symbolize()` call

The canonical v0.1 example is a Gaussian location-scale model fit with
[`drmTMB`](https://itchyshin.github.io/drmTMB/): one submodel for the
mean (`mu`), one for the residual standard deviation (`sigma`).

``` r

library(symbolizer)
library(drmTMB)
#> 
#> Attaching package: 'drmTMB'
#> The following object is masked from 'package:base':
#> 
#>     beta

set.seed(1)
n <- 80
temperature <- runif(n, 10, 25)
dat <- data.frame(
  body_mass   = rnorm(n, 30 + 0.4 * temperature, exp(0.5 + 0.1 * temperature)),
  temperature = temperature
)

fit <- drmTMB(
  drm_formula(body_mass ~ temperature, sigma ~ temperature),
  family = gaussian(),
  data   = dat
)
```

[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
is the single entry point. Pass user-facing symbols and units so the
rendered equations carry biological meaning rather than R variable
names:

``` r

sym <- symbolize(
  fit,
  symbols = c(body_mass = "W_i", temperature = "T_i"),
  units   = c(body_mass = "g",   temperature = "C"),
  context = "avian body-size location-scale model"
)
```

**Takeaway.** One call gives you the structured object; the next
sections unpack what it carries.

## Equations in both notations

[`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md)
returns one row per renderable block (conditional distribution, each
linear predictor, and any random-effect distribution). It always carries
both notations as columns; the `notation` argument only controls how the
result prints.

``` r

equations(sym)
```

``` math
\begin{aligned}
W_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i = \beta_{0} + \beta_{1} \, T_i \\
\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i
\end{aligned}
```

[`as_latex()`](https://itchyshin.github.io/symbolizer/reference/as_latex.md)
produces the LaTeX string ready to splice into a document. With
`notation = "both"` the index and matrix forms are stacked in two
`aligned` blocks. Pasting the output into a math-aware renderer (the
pkgdown site emits MathML through pandoc; Quarto and most LaTeX
renderers use KaTeX or MathJax) shows them as proper math:

``` r

cat(as_latex(sym, notation = "both"))
#> \text{(index notation)}
#> \begin{aligned}
#> W_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
#> \mu_i & = \beta_{0} + \beta_{1} \, T_i \\
#> \log(\sigma_i) & = \gamma_{0} + \gamma_{1} \, T_i
#> \end{aligned}
#> \text{(matrix notation)}
#> \begin{aligned}
#> \mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
#> \boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} \\
#> \log(\boldsymbol{\sigma}) & = \mathbf{Z} \boldsymbol{\gamma}
#> \end{aligned}
```

``` r

cat("$$", as_latex(sym, notation = "both"), "$$", sep = "\n")
```

``` math
\text{(index notation)}
\begin{aligned}
W_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i & = \beta_{0} + \beta_{1} \, T_i \\
\log(\sigma_i) & = \gamma_{0} + \gamma_{1} \, T_i
\end{aligned}
\text{(matrix notation)}
\begin{aligned}
\mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} \\
\log(\boldsymbol{\sigma}) & = \mathbf{Z} \boldsymbol{\gamma}
\end{aligned}
```

The matrix form follows a simple convention: bold lowercase is a vector
($`\boldsymbol{\mu}`$, $`\boldsymbol{\beta}`$), bold uppercase is a
matrix ($`\mathbf{X}`$, $`\mathbf{Z}`$), and Greek vectors keep their
Greek glyph.

[`notation_bridge()`](https://itchyshin.github.io/symbolizer/reference/notation_bridge.md)
is the educator-facing table that pairs every piece of the model with
its counterpart in the other notation and tags the shape:

``` r

notation_bridge(sym)
```

| concept | index | matrix | shape | concrete |
|:---|:---|:---|:---|:---|
| conditional_distribution | $`W_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2)`$ | $`\mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2))`$ | $`\mathbb{R}^n`$ | $`\mathbb{R}^{80}`$ |
| mu_linear_predictor | $`\mu_i = \beta_{0} + \beta_{1} \, T_i`$ | $`\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta}`$ | $`\mathbb{R}^n`$ | $`\mathbb{R}^{80}`$ |
| sigma_linear_predictor | $`\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i`$ | $`\log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma}`$ | $`\mathbb{R}^n`$ | $`\mathbb{R}^{80}`$ |
| body_mass | $`W_i`$ | $`\mathbf{w}`$ | $`\mathbb{R}^n`$ | $`\mathbb{R}^{80}`$ |
| parameter | $`\mu_i`$ | $`\boldsymbol{\mu}`$ | $`\mathbb{R}^n`$ | $`\mathbb{R}^{80}`$ |
| parameter | $`\sigma_i`$ | $`\boldsymbol{\sigma}`$ | $`\mathbb{R}^n`$ | $`\mathbb{R}^{80}`$ |
| coefficient | $`\beta_{0}, \beta_{1}`$ | $`\boldsymbol{\beta}`$ | $`\mathbb{R}^{p_\mu}`$ | $`\mathbb{R}^{2}`$ |
| coefficient | $`\gamma_{0}, \gamma_{1}`$ | $`\boldsymbol{\gamma}`$ | $`\mathbb{R}^{p_\sigma}`$ | $`\mathbb{R}^{2}`$ |
| design_matrix | — | $`\mathbf{X}`$ | $`\mathbb{R}^{n \times p_\mu}`$ | $`\mathbb{R}^{80 \times 2}`$ |
| design_matrix | — | $`\mathbf{Z}`$ | $`\mathbb{R}^{n \times p_\sigma}`$ | $`\mathbb{R}^{80 \times 2}`$ |

Read it as follows: the `dimension` column is the shape rule
(`\mathbb{R}^n`, `\mathbb{R}^{n \times p_\mu}`), and the
`dimension_concrete` column plugs in the actual sizes from this fit
(`\mathbb{R}^{80}`, `\mathbb{R}^{80 \times 2}`).

**Takeaway.** Both notations always coexist; the bridge teaches the
reader to move between them without translating by hand.

## Three views of your model

The dual-notation equations cover *what shape* the model has. To see
*what numbers* actually flow through that shape, call
`as_html_three_views(sym)`: a single self-contained HTML widget with
three tabs over the same fit.

``` r

as_html_three_views(sym, head = 5, tail = 2)
```

[Skip three-views widget](#sym-sym-1779716284-end)

    <button type="button" class="sym-tab sym-active" role="tab" id="sym-sym-1779716284-tab-eq" aria-controls="sym-sym-1779716284-panel-eq" aria-selected="true" tabindex="0" data-tab="eq"><span class="sym-tab-marker" aria-hidden="true">&#9656;</span>1. Equation</button>
    <button type="button" class="sym-tab" role="tab" id="sym-sym-1779716284-tab-idx" aria-controls="sym-sym-1779716284-panel-idx" aria-selected="false" tabindex="-1" data-tab="idx"><span class="sym-tab-marker" aria-hidden="true">&#9656;</span>2. Index</button>
    <button type="button" class="sym-tab" role="tab" id="sym-sym-1779716284-tab-mat" aria-controls="sym-sym-1779716284-panel-mat" aria-selected="false" tabindex="-1" data-tab="mat"><span class="sym-tab-marker" aria-hidden="true">&#9656;</span>3. Matrix (with data)</button>

The structural contract. No indices, no numbers – the shape of the
model.

``` math
\begin{aligned}
\mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} \\
\log(\boldsymbol{\sigma}) & = \mathbf{Z} \boldsymbol{\gamma}
\end{aligned}
```

What happens for each observation *i*.

``` math
\begin{aligned}
W_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i & = \beta_{0} + \beta_{1} \, T_i \\
\log(\sigma_i) & = \gamma_{0} + \gamma_{1} \, T_i
\end{aligned}
```

The actual numbers stacked – what the computer is multiplying. Showing
first 5 and last 2 rows of n = 80.

Matrix-form expansion of the model. Each row shows the response y_i and
the corresponding row of the design matrix X (showing head and tail rows
of the n total observations), with the coefficient vector beta listed
below.

``` sym-matrix

  y                   X                          beta
  y_1 = 34.5          1.00  14.0              
  y_2 = 34.2          1.00  15.6              
  y_3 = 44.8          1.00  18.6              
  y_4 = 49.2          1.00  23.6              
  y_5 = 31.0          1.00  13.0              
  ...               ...                   
  y_79 = 45.8         1.00  21.7              
  y_80 = 36.4         1.00  24.4              

  Coefficients (beta, mu):
    beta_0 = 29.6
    beta_1 = 0.492

  X_sigma                       gamma
  1.00  14.0                    
  1.00  15.6                    
  1.00  18.6                    
  1.00  23.6                    
  1.00  13.0                    
  ...                         
  1.00  21.7                    
  1.00  24.4                    
    gamma_0 = 0.485
    gamma_1 = 0.0936

  Fitted mu_hat (first 5): 36.4  37.2  38.7  41.2  36.0
  Fitted sigma_hat (first 5): 6.01  6.98  9.26  14.8  5.50
```

Tab 1 (Equation) is the structural contract – $`\mathbf{y}`$,
$`\boldsymbol{\mu}`$, $`\boldsymbol{\beta}`$, $`\mathbf{X}`$ – with no
indices. Tab 2 (Index) drops to per-observation form: $`y_i`$,
$`\mu_i`$, $`\beta_0`$, $`\beta_1`$, $`T_i`$. Tab 3 (Matrix with data)
actually stacks the numeric arrays: the response column, the rows of the
design matrix, the coefficient vector, fitted $`\hat{\boldsymbol{\mu}}`$
and $`\hat{\boldsymbol{\sigma}}`$. The accessor that returns those
numeric arrays without the HTML wrapping is `expand(sym)`.

**Takeaway.** Three views, one fit. A biologist can flip between *the
shape of the model*, *what happens per observation*, and *the data the
computer is actually multiplying*.

## Symbols, assumptions, formula bridge

[`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md)
lists every symbol that appears in the equations together with its role,
units, dimension, and description. Dimensions appear in both abstract
and concrete forms.

``` r

symbol_table(sym)
```

| index | matrix | variable | units | role | shape | concrete | description |
|:---|:---|:---|:---|:---|:---|:---|:---|
| $`W_i`$ | $`\mathbf{w}`$ | body_mass | g | response | $`\mathbb{R}^n`$ | $`\mathbb{R}^{80}`$ | response variable |
| $`T_i`$ | — | temperature | C | predictor | column of design matrix | column of X (length 80) | continuous predictor |
| $`\mu_i`$ | $`\boldsymbol{\mu}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{80}`$ | conditional mu of body_mass |
| $`\sigma_i`$ | $`\boldsymbol{\sigma}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{80}`$ | conditional sigma of body_mass |
| $`\beta_{0}, \beta_{1}`$ | $`\boldsymbol{\beta}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\mu}`$ | $`\mathbb{R}^{2}`$ | mu submodel coefficients |
| $`\gamma_{0}, \gamma_{1}`$ | $`\boldsymbol{\gamma}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\sigma}`$ | $`\mathbb{R}^{2}`$ | sigma submodel coefficients |
| — | $`\mathbf{X}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\mu}`$ | $`\mathbb{R}^{80 \times 2}`$ | mu submodel design matrix |
| — | $`\mathbf{Z}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\sigma}`$ | $`\mathbb{R}^{80 \times 2}`$ | sigma submodel design matrix |

[`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md)
distinguishes three statuses: **stated** assumptions are in the formula
(distribution, link, linear predictor); **implied** assumptions follow
from the parameterisation (positivity of $`\sigma`$, conditional
independence); **not_checked** assumptions are still the user’s
responsibility (missing-at-random).

``` r

assumption_table(sym)
```

| assumption | expression | biological meaning | status |
|:---|:---|:---|:---|
| conditional_distribution | $`W_i \mid \mu_i\, \sigma_i \sim \mathrm{Normal}(\mu_i\, \sigma_i^2)`$ | body_mass varies normally around its expected value | explicit |
| linear_predictor | $`\mu_i = \beta_0 + \sum_k \beta_k X_{ki}`$ | Expected body_mass is a linear combination of the mean-model predictors | explicit |
| linear_predictor | $`\log(\sigma_i) = \gamma_0 + \sum_k \gamma_k Z_{ki}`$ | Log residual SD of body_mass is a linear combination of the scale-model predictors | explicit |
| independence | $`W_i \perp W_j \mid X \text{ for } i \ne j`$ | Observations are conditionally independent given the predictors | follows from the formula |
| positivity | $`\sigma_i > 0`$ | Residual SD is constrained positive via the log link | follows from the formula |
| no_missing_at_random | — | Observations are assumed not missing in a way that depends on the unobserved response | your responsibility |

**Note.** The status column shows whether the assumption is *explicit*
(written in the formula), *follows from the formula* (implied by the
link or parameterization), or *your responsibility* (something
`symbolizer` cannot check from the fit, e.g. missing-at-random).

[`formula_bridge()`](https://itchyshin.github.io/symbolizer/reference/formula_bridge.md)
translates R syntax to mathematics. Each submodel has its R formula on
the left, a plain-English meaning, and the corresponding math in both
notations.

``` r

formula_bridge(sym)
```

| submodel | R syntax | meaning | math (index) | math (matrix) |
|:---|:---|:---|:---|:---|
| mu | `body_mass ~ temperature` | Expected body_mass is a linear function of the mean-model predictors | $`\mu_i = \beta_{0} + \beta_{1} \, T_i`$ | $`\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta}`$ |
| sigma | `sigma ~ temperature` | Log residual SD of body_mass is a linear function of the scale-model predictors | $`\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i`$ | $`\log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma}`$ |

**Takeaway.** What the model says, what it assumes, and how its R syntax
maps to math live in three separate tables — so reviewers can audit each
one independently.

## Parameter interpretation

[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
reads each fixed-effect estimate on multiple scales. By default
(`scale = "all"`) it shows link, natural, variance (for $`\sigma`$
coefficients), and biological readings together:

``` r

parameter_interpretation(sym)
```

| submodel | term_label | coefficient_role | estimate | 95% CI | link_scale_reading | natural_scale_reading | variance_scale_reading | biological_reading |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 29.6 | 22.4, 36.7 \* | Expected body_mass at the reference | Expected body_mass for the reference case | — | Baseline body_mass in the reference condition |
| mu | temperature | slope | 0.492 | 0.0317, 0.952 \* | Linear change in expected body_mass per unit of temperature | Expected body_mass changes by 0.492 per unit of temperature | — | A unit change in temperature shifts the expected body_mass by 0.492 |
| sigma | (Intercept) | intercept | 0.485 | -0.169, 1.14 | Log residual SD at the reference (SD = exp(0.485)) | Residual SD = exp(0.485) at the reference | Residual variance = exp(2\*0.485) | Baseline level of unexplained individual variation in body_mass |
| sigma | temperature | slope | 0.0936 | 0.0581, 0.129 \* | Log residual SD changes by 0.0936 per unit of temperature | Residual SD multiplied by exp(0.0936) per unit of temperature | Residual variance multiplied by exp(2\*0.0936) per unit | A unit change in temperature multiplies the unexplained variability of body_mass by exp(0.0936) |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

The `scale` argument filters to a single reading. The `"biological"`
scale is the one that goes in a results paragraph:

``` r

parameter_interpretation(sym, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | 95% CI | biological_reading |
|:---|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 29.6 | 22.4, 36.7 \* | Baseline body_mass in the reference condition |
| mu | temperature | slope | 0.492 | 0.0317, 0.952 \* | A unit change in temperature shifts the expected body_mass by 0.492 |
| sigma | (Intercept) | intercept | 0.485 | -0.169, 1.14 | Baseline level of unexplained individual variation in body_mass |
| sigma | temperature | slope | 0.0936 | 0.0581, 0.129 \* | A unit change in temperature multiplies the unexplained variability of body_mass by exp(0.0936) |

*Rows marked `*` have a 95% confidence interval that excludes zero (CI
method: `wald`).*

**Takeaway.** Every coefficient has an interpretation on every scale
that makes sense for its submodel; the package writes them so you do not
have to.

## Random intercepts (first slice)

v0.1 supports Gaussian random intercepts of the form `(1 | group)` as a
*first slice*. The same
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
call works; the equation set picks up the random-intercept term and a
new distribution row, and the structured object gains a `random_effects`
and `variance_components` tibble.

``` r

set.seed(2)
n        <- 80
n_groups <- 6
group    <- factor(rep(letters[seq_len(n_groups)], length.out = n))
temperature <- runif(n, 10, 25)
re <- rnorm(n_groups, sd = 1)
dat_re <- data.frame(
  body_mass = rnorm(
    n,
    30 + 0.4 * temperature + re[as.integer(group)],
    exp(0.5 + 0.05 * temperature)
  ),
  temperature = temperature,
  group       = group
)

fit_re <- drmTMB(
  drm_formula(body_mass ~ temperature + (1 | group), sigma ~ temperature),
  family = gaussian(),
  data   = dat_re
)

sym_re <- symbolize(
  fit_re,
  symbols = c(body_mass = "W_i", temperature = "T_i"),
  units   = c(body_mass = "g",   temperature = "C")
)
```

The mu linear predictor now carries a $`+ u_{group(i)}`$ term, and a new
distributional row appears for the random intercepts:

``` r

equations(sym_re)
```

``` math
\begin{aligned}
W_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i = \beta_{0} + \beta_{1} \, T_i + u_{group(i)} \\
\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i \\
u_{group} \sim \mathcal{N}(0,\, \sigma_{group}^2)
\end{aligned}
```

``` r

cat("$$", as_latex(sym_re, notation = "both"), "$$", sep = "\n")
```

``` math
\text{(index notation)}
\begin{aligned}
W_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i & = \beta_{0} + \beta_{1} \, T_i + u_{group(i)} \\
\log(\sigma_i) & = \gamma_{0} + \gamma_{1} \, T_i \\
u_{group} & \sim \mathcal{N}(0,\, \sigma_{group}^2)
\end{aligned}
\text{(matrix notation)}
\begin{aligned}
\mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} + \mathbf{u} \\
\log(\boldsymbol{\sigma}) & = \mathbf{Z} \boldsymbol{\gamma} \\
\mathbf{u}_{group} & \sim \mathcal{N}(\mathbf{0},\, \sigma_{group}^2 \mathbf{I}_{6})
\end{aligned}
```

The grouping structure is exposed as tidy tibbles, ready to feed into
reports or other renderers:

``` r

sym_re$random_effects
#> # A tibble: 1 × 11
#>   submodel term_label  lhs_expr group_var component   n_levels component_index
#>   <chr>    <chr>       <chr>    <chr>     <chr>          <int>           <int>
#> 1 mu       (1 | group) 1        group     (Intercept)        6               0
#> # ℹ 4 more variables: u_symbol_index <chr>, u_symbol_matrix <chr>,
#> #   sigma_symbol <chr>, predictor_factor <chr>
sym_re$variance_components
#> # A tibble: 1 × 7
#>   submodel group_var component   parameter     symbol       n_levels description
#>   <chr>    <chr>     <chr>       <chr>         <chr>           <int> <chr>      
#> 1 mu       group     (Intercept) sigma_group_0 "\\sigma_{g…        6 between-gr…
```

**Takeaway.** The same object carries everything a reader needs to
discuss random structure — what is grouped, how many levels, and which
between-group SD (`sd(group)`) goes with which submodel.

## What’s supported, what’s planned

[`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md)
is the registry that gates
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md).
Each row carries one of five status words: **Stable**, **First slice**,
**Opt-in control**, **Planned or reserved**, or **Unsupported**. v0.1
marks `drmTMB` Gaussian `mu` and `sigma` as Stable, Gaussian
`random_effects` as First slice, and reserves the rest of the matrix for
later versions.

``` r

symbolizer_capabilities()
#> # A tibble: 113 × 6
#>    class  family            component      status              since notes      
#>    <chr>  <chr>             <chr>          <chr>               <chr> <chr>      
#>  1 drmTMB gaussian          mu             Stable              0.1.0 Univariate…
#>  2 drmTMB gaussian          sigma          Stable              0.1.0 Univariate…
#>  3 drmTMB gaussian          random_effects First slice         0.3.1 Random int…
#>  4 drmTMB gaussian          zi             Planned or reserved NA    Zero-infla…
#>  5 drmTMB gaussian          hu             Planned or reserved NA    Hurdle sub…
#>  6 drmTMB poisson           zi             First slice         0.4.0 Zero-infla…
#>  7 drmTMB nbinom2           zi             First slice         0.4.0 Zero-infla…
#>  8 drmTMB truncated_nbinom2 hu             First slice         0.4.0 Hurdle sub…
#>  9 drmTMB gaussian          rho12          Planned or reserved NA    Bivariate …
#> 10 drmTMB student           mu             First slice         0.2.2 Student-t …
#> # ℹ 103 more rows
```

The roadmap in `README.md` lists the planned version per family /
package. If
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
errors with a capability message, the registry will tell you which
version is scheduled to lift it.

**Takeaway.** The registry is the single source of truth for “what
works”. Read the status word before designing around an unsupported
tuple.
