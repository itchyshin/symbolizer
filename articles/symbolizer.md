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
#> 
#> ── Equations ──
#> 
#> distribution
#>   index:  W_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2)
#> mu_linear_predictor
#>   index:  \mu_i = \beta_{0} + \beta_{1} \, T_i
#> sigma_linear_predictor
#>   index:  \log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i
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
#> 
#> ── Notation bridge ──
#> 
#> conditional_distribution
#> index: `W_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2)`
#> matrix: `\mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} \sim
#> \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2))`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{80}`)
#> mu_linear_predictor
#> index: `\mu_i = \beta_{0} + \beta_{1} \, T_i`
#> matrix: `\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{80}`)
#> sigma_linear_predictor
#> index: `\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i`
#> matrix: `\log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{80}`)
#> body_mass
#> index: `W_i`
#> matrix: `\mathbf{w}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{80}`)
#> parameter
#> index: `\mu_i`
#> matrix: `\boldsymbol{\mu}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{80}`)
#> parameter
#> index: `\sigma_i`
#> matrix: `\boldsymbol{\sigma}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{80}`)
#> coefficient
#> index: `\beta_{0}, \beta_{1}`
#> matrix: `\boldsymbol{\beta}`
#> dimension: `\mathbb{R}^{p_\mu}` (= `\mathbb{R}^{2}`)
#> coefficient
#> index: `\gamma_{0}, \gamma_{1}`
#> matrix: `\boldsymbol{\gamma}`
#> dimension: `\mathbb{R}^{p_\sigma}` (= `\mathbb{R}^{2}`)
#> design_matrix
#> index: `--`
#> matrix: `\mathbf{X}`
#> dimension: `\mathbb{R}^{n \times p_\mu}` (= `\mathbb{R}^{80 \times 2}`)
#> design_matrix
#> index: `--`
#> matrix: `\mathbf{Z}`
#> dimension: `\mathbb{R}^{n \times p_\sigma}` (= `\mathbb{R}^{80 \times 2}`)
```

Read it as follows: the `dimension` column is the shape rule
(`\mathbb{R}^n`, `\mathbb{R}^{n \times p_\mu}`), and the
`dimension_concrete` column plugs in the actual sizes from this fit
(`\mathbb{R}^{80}`, `\mathbb{R}^{80 \times 2}`).

**Takeaway.** Both notations always coexist; the bridge teaches the
reader to move between them without translating by hand.

## Symbols, assumptions, formula bridge

[`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md)
lists every symbol that appears in the equations together with its role,
units, dimension, and description. Dimensions appear in both abstract
and concrete forms.

``` r

symbol_table(sym)
#> 
#> ── Symbol dictionary ("both") ──
#> 
#> body_mass [response]
#> index: `W_i`
#> matrix: `\mathbf{w}`
#> units: "g"
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{80}`)
#> response variable
#> temperature [predictor]
#> index: `T_i`
#> matrix: `(no matrix form)`
#> units: "C"
#> dimension: `column of design matrix` (= `column of \mathbf{X} (length 80)`)
#> continuous predictor
#> (parameter)
#> index: `\mu_i`
#> matrix: `\boldsymbol{\mu}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{80}`)
#> conditional mu of body_mass
#> (parameter)
#> index: `\sigma_i`
#> matrix: `\boldsymbol{\sigma}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{80}`)
#> conditional sigma of body_mass
#> (coefficient)
#> index: `\beta_{0}, \beta_{1}`
#> matrix: `\boldsymbol{\beta}`
#> dimension: `\mathbb{R}^{p_\mu}` (= `\mathbb{R}^{2}`)
#> mu submodel coefficients
#> (coefficient)
#> index: `\gamma_{0}, \gamma_{1}`
#> matrix: `\boldsymbol{\gamma}`
#> dimension: `\mathbb{R}^{p_\sigma}` (= `\mathbb{R}^{2}`)
#> sigma submodel coefficients
#> (design_matrix)
#> index: `(no index form)`
#> matrix: `\mathbf{X}`
#> dimension: `\mathbb{R}^{n \times p_\mu}` (= `\mathbb{R}^{80 \times 2}`)
#> mu submodel design matrix
#> (design_matrix)
#> index: `(no index form)`
#> matrix: `\mathbf{Z}`
#> dimension: `\mathbb{R}^{n \times p_\sigma}` (= `\mathbb{R}^{80 \times 2}`)
#> sigma submodel design matrix
```

[`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md)
distinguishes three statuses: **stated** assumptions are in the formula
(distribution, link, linear predictor); **implied** assumptions follow
from the parameterisation (positivity of $`\sigma`$, conditional
independence); **not_checked** assumptions are still the user’s
responsibility (missing-at-random).

``` r

assumption_table(sym)
#> 
#> ── Assumptions ──
#> 
#> conditional_distribution
#> expression: `W_i \mid \mu_i\, \sigma_i \sim \mathrm{Normal}(\mu_i\,
#> \sigma_i^2)`
#> meaning: body_mass varies normally around its expected value
#> status: ["stated"]
#> linear_predictor (mu)
#> expression: `\mu_i = \beta_0 + \sum_k \beta_k X_{ki}`
#> meaning: Expected body_mass is a linear combination of the mean-model
#> predictors
#> status: ["stated"]
#> linear_predictor (sigma)
#> expression: `\log(\sigma_i) = \gamma_0 + \sum_k \gamma_k Z_{ki}`
#> meaning: Log residual SD of body_mass is a linear combination of the
#> scale-model predictors
#> status: ["stated"]
#> independence
#> expression: `W_i \perp W_j \mid X \text{ for } i \ne j`
#> meaning: Observations are conditionally independent given the predictors
#> status: ["implied"]
#> positivity (sigma)
#> expression: `\sigma_i > 0`
#> meaning: Residual SD is constrained positive via the log link
#> status: ["implied"]
#> no_missing_at_random
#> expression: `—`
#> meaning: Observations are assumed not missing in a way that depends on the
#> unobserved response
#> status: ["not_checked"]
```

[`formula_bridge()`](https://itchyshin.github.io/symbolizer/reference/formula_bridge.md)
translates R syntax to mathematics. Each submodel has its R formula on
the left, a plain-English meaning, and the corresponding math in both
notations.

``` r

formula_bridge(sym)
#> 
#> ── Formula bridge ("both") ──
#> 
#> mu
#> R: `body_mass ~ temperature`
#> meaning: Expected body_mass is a linear function of the mean-model predictors
#> math: `\mu_i = \beta_{0} + \beta_{1} \, T_i`
#> matrix: `\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta}`
#> sigma
#> R: `sigma ~ temperature`
#> meaning: Log residual SD of body_mass is a linear function of the scale-model
#> predictors
#> math: `\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i`
#> matrix: `\log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma}`
```

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
#> 
#> ── Parameter interpretation ("all") ──
#> 
#> ── submodel: mu
#> (Intercept) ["intercept"] estimate = "29.6"
#> link: Expected body_mass at the reference
#> natural: Expected body_mass for the reference case
#> variance: —
#> biological: Baseline body_mass in the reference condition
#> temperature ["slope"] estimate = "0.492"
#> link: Linear change in expected body_mass per unit of temperature
#> natural: Expected body_mass changes by 0.492 per unit of temperature
#> variance: —
#> biological: A unit change in temperature shifts the expected body_mass by 0.492
#> 
#> ── submodel: sigma
#> (Intercept) ["intercept"] estimate = "0.485"
#> link: Log residual SD at the reference (SD = exp(0.485))
#> natural: Residual SD = exp(0.485) at the reference
#> variance: Residual variance = exp(2*0.485)
#> biological: Baseline level of unexplained individual variation in body_mass
#> temperature ["slope"] estimate = "0.0936"
#> link: Log residual SD changes by 0.0936 per unit of temperature
#> natural: Residual SD multiplied by exp(0.0936) per unit of temperature
#> variance: Residual variance multiplied by exp(2*0.0936) per unit
#> biological: A unit change in temperature multiplies the unexplained variability
#> of body_mass by exp(0.0936)
```

The `scale` argument filters to a single reading. The `"biological"`
scale is the one that goes in a results paragraph:

``` r

parameter_interpretation(sym, scale = "biological")
#> 
#> ── Parameter interpretation ("biological") ──
#> 
#> ── submodel: mu
#> (Intercept) ["intercept"] estimate = "29.6"
#> biological: Baseline body_mass in the reference condition
#> temperature ["slope"] estimate = "0.492"
#> biological: A unit change in temperature shifts the expected body_mass by 0.492
#> 
#> ── submodel: sigma
#> (Intercept) ["intercept"] estimate = "0.485"
#> biological: Baseline level of unexplained individual variation in body_mass
#> temperature ["slope"] estimate = "0.0936"
#> biological: A unit change in temperature multiplies the unexplained variability
#> of body_mass by exp(0.0936)
```

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
#> 
#> ── Equations ──
#> 
#> distribution
#>   index:  W_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2)
#> mu_linear_predictor
#>   index:  \mu_i = \beta_{0} + \beta_{1} \, T_i + u_{group(i)}
#> sigma_linear_predictor
#>   index:  \log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i
#> mu_random_intercept_group
#>   index:  u_{group} \sim \mathcal{N}(0,\, \sigma_{group}^2)
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
#> # A tibble: 1 × 8
#>   submodel term_label lhs_expr group_var n_levels u_symbol_index u_symbol_matrix
#>   <chr>    <chr>      <chr>    <chr>        <int> <chr>          <chr>          
#> 1 mu       (1 | grou… 1        group            6 u_{group(i)}   "\\mathbf{u}"  
#> # ℹ 1 more variable: sigma_symbol <chr>
sym_re$variance_components
#> # A tibble: 1 × 6
#>   submodel group_var parameter   symbol            n_levels description         
#>   <chr>    <chr>     <chr>       <chr>                <int> <chr>               
#> 1 mu       group     sigma_group "\\sigma_{group}"        6 between-group stand…
```

**Takeaway.** The same object carries everything a reader needs to
discuss random structure — what is grouped, how many levels, and which
variance component goes with which submodel.

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
#> # A tibble: 37 × 6
#>    class  family    component      status              since notes              
#>    <chr>  <chr>     <chr>          <chr>               <chr> <chr>              
#>  1 drmTMB gaussian  mu             Stable              0.1.0 Univariate locatio…
#>  2 drmTMB gaussian  sigma          Stable              0.1.0 Univariate scale s…
#>  3 drmTMB gaussian  random_effects First slice         0.1.0 Gaussian random in…
#>  4 drmTMB gaussian  zi             Planned or reserved NA    Zero-inflation sub…
#>  5 drmTMB gaussian  hu             Planned or reserved NA    Hurdle submodel.   
#>  6 drmTMB gaussian  rho12          Planned or reserved NA    Bivariate residual…
#>  7 drmTMB student   mu             Planned or reserved NA    NA                 
#>  8 drmTMB student   sigma          Planned or reserved NA    NA                 
#>  9 drmTMB student   nu             Planned or reserved NA    NA                 
#> 10 drmTMB lognormal mu             Planned or reserved NA    NA                 
#> # ℹ 27 more rows
```

The roadmap in `README.md` lists the planned version per family /
package. If
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
errors with a capability message, the registry will tell you which
version is scheduled to lift it.

**Takeaway.** The registry is the single source of truth for “what
works”. Read the status word before designing around an unsupported
tuple.
