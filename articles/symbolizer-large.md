# A worked example: structured body-size model

The “Get started” vignette walks the surface on a deliberately small fit
(`n = 80`, one continuous predictor, one random intercept). This article
exercises more of the renderer machinery on a model an ecologist would
actually run: a Gaussian location-scale fit with a continuous predictor,
a log-transformed predictor, a two-level factor contrast, and a random
intercept on the mean submodel.

The goal is not to teach you `drmTMB`; it is to show what each
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
surface returns when the inputs are richer.

## 1. Setup and fit

We simulate a body-size dataset with `temperature` (continuous), `food`
(continuous, lognormal so `log(food)` is the natural scale), `sex`
(two-level factor), and `site` (eight-level grouping). The fitted model
has the mean depending on all four predictors and the residual standard
deviation depending on `temperature` and `sex`.

``` r

library(symbolizer)
library(drmTMB)
#> 
#> Attaching package: 'drmTMB'
#> The following object is masked from 'package:base':
#> 
#>     beta

set.seed(20260523)
n           <- 200
temperature <- runif(n, 8, 30)
food        <- rlnorm(n, meanlog = 1.5, sdlog = 0.6)
sex         <- factor(sample(c("female", "male"), n, replace = TRUE))
site        <- factor(sample(letters[1:8], n, replace = TRUE))

site_re <- rnorm(8, sd = 1.5)
mu      <- 5 + 0.5 * temperature + 2 * log(food) +
             3 * (sex == "male") + site_re[site]
sigma   <- exp(0.3 + 0.05 * temperature + 0.1 * (sex == "male"))

dat <- data.frame(
  body_mass   = rnorm(n, mu, sigma),
  temperature = temperature,
  food        = food,
  sex         = sex,
  site        = site
)

fit <- drmTMB(
  drm_formula(
    body_mass ~ temperature + log(food) + sex + (1 | site),
    sigma ~ temperature + sex
  ),
  family = gaussian(),
  data   = dat
)
```

[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
is the single entry point. We pass biologically meaningful symbols
(`W_i` for body mass, `T_i` for temperature, `F_i` for food, `S_i` for
sex) and units; the rendered equations carry these instead of the raw R
names.

``` r

sym <- symbolize(
  fit,
  symbols = c(body_mass = "W_i", temperature = "T_i",
              food      = "F_i", sex         = "S_i"),
  units   = c(body_mass = "g",   temperature = "C",
              food      = "g/day"),
  context = "structured body-size location-scale model"
)
sym
#> <symbolized_model> -- call `summary()` for a plain-English walkthrough, or
#> `explain()` in one step from your fit.
#> 
#> ── <symbolized_model> ──────────────────────────────────────────────────────────
#> Class: <drmTMB> (drmTMB)
#> Family: "gaussian"
#> Response: "body_mass" (n = 200)
#> Context: structured body-size location-scale model
#> 
#> ── Submodels ──
#> 
#> `mu`: `body_mass ~ temperature + log(food) + sex + (1 | site)` (link:
#> "identity")
#> `sigma`: `sigma ~ temperature + sex` (link: "log")
#> 
#> ── Equations ──
#> 
#>   W_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2)
#>   \mu_i = \beta_{0} + \beta_{1} \, T_i + \beta_{2} \, \mathrm{log}(F_i) + \beta_{3} \, [sex = \mathrm{male}] + u_{site(i)}
#>   \log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i + \gamma_{2} \, [sex = \mathrm{male}]
#>   u_{site} \sim \mathcal{N}(0,\, \sigma_{site}^2)
#> 
#> ── Symbols ──
#> 
#>   W_i                                         response variable
#>   T_i                                         continuous predictor
#>   F_i                                         predictor (log-transformed)
#>   S_i                                         factor (female [reference], male)
#>   \mu_i                                       conditional mu of body_mass
#>   \sigma_i                                    conditional sigma of body_mass
#>   \beta_{0}, \beta_{1}, \beta_{2}, \beta_{3}  mu submodel coefficients
#>   \gamma_{0}, \gamma_{1}, \gamma_{2}          sigma submodel coefficients
#>   --                                          mu submodel design matrix
#>   --                                          sigma submodel design matrix
#>   u_{site(i)}                                 random intercept by site
#>   \sigma_{site}                               between-site standard deviation
#> 
#> ── Random effects ──
#> 
#> `(1 | site)` on submodel "mu" (8 levels)
```

**Takeaway.** One call to
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
produces the structured object; every later section is a renderer
pulling rows from it.

## 2. The mean structure

[`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md)
returns one row per renderable block (the conditional distribution, each
linear predictor, and any random-effect distribution). Both notations
always live in their own columns; `notation = "both"` controls only how
the result prints.

``` r

equations(sym, notation = "both")
```

**Index form:**

``` math
\begin{aligned}
W_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i = \beta_{0} + \beta_{1} \, T_i + \beta_{2} \, \mathrm{log}(F_i) + \beta_{3} \, [sex = \mathrm{male}] + u_{site(i)} \\
\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i + \gamma_{2} \, [sex = \mathrm{male}] \\
u_{site} \sim \mathcal{N}(0,\, \sigma_{site}^2)
\end{aligned}
```

**Matrix form:**

``` math
\begin{aligned}
\mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta} + \mathbf{u} \\
\log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma} \\
\mathbf{u}_{site} \sim \mathcal{N}(\mathbf{0},\, \sigma_{site}^2 \mathbf{I}_{8})
\end{aligned}
```

Reading the mu row line by line:

- `\log(F_i)` shows up as the transformed predictor. The bridge
  recognises `log(food)` as a transformation role and renders the
  transformation in math, not as a plain symbol.
- The sex contrast renders as `\beta_{3} \, [sex = \mathrm{male}]`. The
  bracket notation is the contrast convention: the coefficient applies
  whenever `sex = male`, and the female baseline is folded into the
  intercept.
- The random-intercept term `u_{site(i)}` is appended to the mu
  predictor, flagged by its subscript that it depends on which `site`
  observation `i` belongs to.

Spliced into a math-aware renderer (the pkgdown site emits MathML
through pandoc; Quarto and most LaTeX renderers use KaTeX or MathJax),
the two-notation block looks like this:

``` r

cat("$$", as_latex(sym, notation = "both"), "$$", sep = "\n")
```

``` math
\text{(index notation)}
\begin{aligned}
W_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i & = \beta_{0} + \beta_{1} \, T_i + \beta_{2} \, \mathrm{log}(F_i) + \beta_{3} \, [sex = \mathrm{male}] + u_{site(i)} \\
\log(\sigma_i) & = \gamma_{0} + \gamma_{1} \, T_i + \gamma_{2} \, [sex = \mathrm{male}] \\
u_{site} & \sim \mathcal{N}(0,\, \sigma_{site}^2)
\end{aligned}
\text{(matrix notation)}
\begin{aligned}
\mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
\boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} + \mathbf{u} \\
\log(\boldsymbol{\sigma}) & = \mathbf{Z} \boldsymbol{\gamma} \\
\mathbf{u}_{site} & \sim \mathcal{N}(\mathbf{0},\, \sigma_{site}^2 \mathbf{I}_{8})
\end{aligned}
```

**Takeaway.** The mu line carries four predictors with different roles
(intercept, slope, transformation, factor contrast) plus a random
intercept, all rendered from the same
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
call.

## 3. The scale structure

The sigma submodel does its own work. Pulling just the `sigma`
linear-predictor row:

``` r

eq <- equations(sym, notation = "both")
eq[eq$submodel == "sigma" & eq$kind == "linear_predictor", ]
```

**Index form:**

``` math
\begin{aligned}
\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i + \gamma_{2} \, [sex = \mathrm{male}]
\end{aligned}
```

**Matrix form:**

``` math
\begin{aligned}
\log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma}
\end{aligned}
```

Two features deserve attention.

First, the sigma submodel has its own predictors: residual variability
changes with `temperature` and with `sex`. This is the location-scale
part — the model lets the spread depend on covariates, not just the
mean.

Second, the link on sigma is `log`, which `drmTMB` locks in. The
biological reading is multiplicative: a unit change in `temperature`
multiplies the residual standard deviation by `\exp(\gamma_{1})`, and
the male contrast multiplies it by `\exp(\gamma_{2})` relative to
females.

**Takeaway.** The residual SD is not constant; it varies on the
log-scale with the same kind of linear-predictor grammar as the mean.

## 4. What the symbols mean

[`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md)
lists every symbol used in the equations, together with its abstract
dimension (the shape rule) and its concrete dimension (the actual sizes
from this fit). With `n = 200` observations, four mu coefficients
(intercept + `temperature` + `log(food)` + sex contrast), and three
sigma coefficients (intercept + `temperature` + sex contrast), the
concrete columns now show real numbers, not just placeholders.

``` r

symbol_table(sym)
```

| index | matrix | variable | units | role | shape | concrete | description |
|:---|:---|:---|:---|:---|:---|:---|:---|
| $`W_i`$ | $`\mathbf{w}`$ | body_mass | g | response | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ | response variable |
| $`T_i`$ | — | temperature | C | predictor | column of design matrix | column of X (length 200) | continuous predictor |
| $`F_i`$ | — | food | g/day | transformation | column of design matrix | column of X (length 200) | predictor (log-transformed) |
| $`S_i`$ | — | sex | NA | factor | column of design matrix | column of X (length 200) | factor (female \[reference\], male) |
| $`\mu_i`$ | $`\boldsymbol{\mu}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ | conditional mu of body_mass |
| $`\sigma_i`$ | $`\boldsymbol{\sigma}`$ | NA | NA | parameter | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ | conditional sigma of body_mass |
| $`\beta_{0}, \beta_{1}, \beta_{2}, \beta_{3}`$ | $`\boldsymbol{\beta}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\mu}`$ | $`\mathbb{R}^{4}`$ | mu submodel coefficients |
| $`\gamma_{0}, \gamma_{1}, \gamma_{2}`$ | $`\boldsymbol{\gamma}`$ | NA | NA | coefficient | $`\mathbb{R}^{p_\sigma}`$ | $`\mathbb{R}^{3}`$ | sigma submodel coefficients |
| — | $`\mathbf{X}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\mu}`$ | $`\mathbb{R}^{200 \times 4}`$ | mu submodel design matrix |
| — | $`\mathbf{Z}`$ | NA | NA | design_matrix | $`\mathbb{R}^{n \times p_\sigma}`$ | $`\mathbb{R}^{200 \times 3}`$ | sigma submodel design matrix |
| $`u_{site(i)}`$ | $`\mathbf{u}_{site}`$ | site | NA | random_intercept | $`scalar; \mathbb{R}^{G_{site}} in matrix form`$ | $`scalar; \mathbb{R}^{8} in matrix form`$ | random intercept by site |
| $`\sigma_{site}`$ | $`\sigma_{site}`$ | NA | NA | variance_component | scalar | scalar | between-site standard deviation |

Notice the design matrix rows: `\mathbf{X}` is
`\mathbb{R}^{n \times p_\mu}` abstractly, `\mathbb{R}^{200 \times 4}`
concretely; `\mathbf{Z}` is the sigma submodel’s design matrix at
`\mathbb{R}^{200 \times 3}`. The random-intercept row carries
`\mathbb{R}^{8}` because `site` has eight levels.

**Takeaway.** The symbol table is the page a reader uses to look up what
each glyph in the equations actually means and how big it is.

## 5. What is assumed

[`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md)
separates **stated** assumptions (those baked into the formula:
distribution, link, linear predictor), **implied** assumptions (those
that follow from the parameterisation: positivity of `\sigma_i`,
conditional independence), and **not_checked** assumptions (those still
on the user’s plate: missing-at-random).

``` r

assumption_table(sym)
```

| assumption | expression | biological meaning | status |
|:---|:---|:---|:---|
| conditional_distribution | $`W_i \mid \mu_i\, \sigma_i \sim \mathrm{Normal}(\mu_i\, \sigma_i^2)`$ | body_mass varies normally around its expected value | explicit |
| linear_predictor | $`\mu_i = \beta_0 + \sum_k \beta_k X_{ki}`$ | Expected body_mass is a linear combination of the mean-model predictors | explicit |
| linear_predictor | $`\log(\sigma_i) = \gamma_0 + \sum_k \gamma_k Z_{ki}`$ | Log residual SD of body_mass is a linear combination of the scale-model predictors | explicit |
| independence_given_random_effects | $`W_i \perp W_j \mid X\, \mathbf{u} \text{ for } i \ne j`$ | Observations are conditionally independent given the predictors and the random effects | explicit |
| positivity | $`\sigma_i > 0`$ | Residual SD is constrained positive via the log link | follows from the formula |
| no_missing_at_random | — | Observations are assumed not missing in a way that depends on the unobserved response | your responsibility |

Because this fit carries a random intercept, the table swaps in the
RE-conditional independence row automatically: observations are
conditionally independent **given the predictors and the random
effects**. We can verify it directly from `sym$assumptions`:

``` r

sym$assumptions$assumption
#> [1] "conditional_distribution"          "linear_predictor"                 
#> [3] "linear_predictor"                  "independence_given_random_effects"
#> [5] "positivity"                        "no_missing_at_random"
```

The plain `independence` row is absent;
`independence_given_random_effects` appears in its place. A
fixed-effects-only fit would show the reverse.

**Takeaway.** Stated, implied, not_checked is the audit lens: the model
guarantees the first two; the third is your responsibility.

## 6. Reading each coefficient

[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
reads each fixed-effect estimate on every scale that makes sense for its
submodel: a link-scale reading, a natural-scale reading, a
variance-scale reading (sigma only), and a biological reading.

``` r

parameter_interpretation(sym)
```

| submodel | term_label | coefficient_role | estimate | link_scale_reading | natural_scale_reading | variance_scale_reading | biological_reading |
|:---|:---|:---|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 5.55 | Expected body_mass at the reference | Expected body_mass for the reference case | — | Baseline body_mass in the reference condition |
| mu | temperature | slope | 0.531 | Linear change in expected body_mass per unit of temperature | Expected body_mass changes by 0.531 per unit of temperature | — | A unit change in temperature shifts the expected body_mass by 0.531 |
| mu | log(food) | transformation | 1.75 | Linear change in expected body_mass per unit of log(food) | Expected body_mass changes by 1.75 per unit of log(food) | — | A unit change in log(food) shifts the expected body_mass by 1.75 |
| mu | sex | factor_contrast | 2.52 | Difference in expected body_mass between sex = male and the reference (female) | Expected body_mass for sex = male differs from sex = female by 2.52 | — | Average body_mass differs between male and female by 2.52 |
| sigma | (Intercept) | intercept | 0.221 | Log residual SD at the reference (SD = exp(0.221)) | Residual SD = exp(0.221) at the reference | Residual variance = exp(2\*0.221) | Baseline level of unexplained individual variation in body_mass |
| sigma | temperature | slope | 0.0546 | Log residual SD changes by 0.0546 per unit of temperature | Residual SD multiplied by exp(0.0546) per unit of temperature | Residual variance multiplied by exp(2\*0.0546) per unit | A unit change in temperature multiplies the unexplained variability of body_mass by exp(0.0546) |
| sigma | sex | factor_contrast | 0.0332 | Log residual SD differs by 0.0332 between sex = male and sex = female | Residual SD for male is exp(0.0332) times the SD for female | Residual variance for male is exp(2\*0.0332) times the variance for female | Unexplained variation in body_mass differs between male and female by a factor of exp(0.0332) |

For this fit, the most informative comparison is the `temperature` slope
on each submodel.

On mu, `\beta_{1}` is additive on the response: a unit change in
`temperature` shifts the expected body mass by the coefficient value,
because the mu link is identity.

On sigma, `\gamma_{1}` is additive on the log scale, which means a unit
change in `temperature` *multiplies* the residual SD by
`\exp(\gamma_{1})`. The biological reading expresses this directly: a
unit change in temperature multiplies the unexplained variability of
`body_mass` by `\exp(\gamma_{1})`. Two coefficients on the same
predictor, two genuinely different scales.

The `log(food)` row deserves a closer look: a transformed predictor
takes the `transformation` role and gets its own templated readings on
the link, natural, and biological scales. The natural-scale reading
reports the slope per unit of `log(food)`, not per raw unit of `food` —
the mathematics in
[`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md)
and the English in this table now agree about which scale the
coefficient lives on.

``` r

sym$interpretation[sym$interpretation$term_label == "log(food)", , drop = FALSE]
#> # A tibble: 1 × 8
#>   submodel term_label coefficient_role estimate link_scale_reading              
#>   <chr>    <chr>      <chr>               <dbl> <chr>                           
#> 1 mu       log(food)  transformation       1.75 Linear change in expected body_…
#> # ℹ 3 more variables: natural_scale_reading <chr>,
#> #   variance_scale_reading <chr>, biological_reading <chr>
```

**Takeaway.** v0.1 ships interpretation templates for `intercept`,
`slope`, `factor_contrast`, and `transformation` roles on both mu and
sigma. Interactions remain on the roadmap.

## 7. R syntax to math, both directions

[`formula_bridge()`](https://itchyshin.github.io/symbolizer/reference/formula_bridge.md)
is the educator-facing translation table from R formula syntax to
mathematics. Two rows, both notations.

``` r

formula_bridge(sym)
```

| submodel | R syntax | meaning | math (index) | math (matrix) |
|:---|:---|:---|:---|:---|
| mu | `body_mass ~ temperature + log(food) + sex + (1 &#124; site)` | Expected body_mass is a linear function of the mean-model predictors | $`\mu_i = \beta_{0} + \beta_{1} \, T_i + \beta_{2} \, \mathrm{log}(F_i) + \beta_{3} \, [sex = \mathrm{male}] + u_{site(i)}`$ | $`\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta} + \mathbf{u}`$ |
| sigma | `sigma ~ temperature + sex` | Log residual SD of body_mass is a linear function of the scale-model predictors | $`\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i + \gamma_{2} \, [sex = \mathrm{male}]`$ | $`\log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma}`$ |

For the mu submodel, the R syntax
`body_mass ~ temperature + log(food) + sex + (1 | site)` maps to the
indexed equation in the `mathematics` column and to
`\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta} + \mathbf{u}` in the
`mathematics_matrix` column. The random-intercept piece appears as
`+ \mathbf{u}` in the matrix form and as `+ u_{site(i)}` in the indexed
form. A reader can compare the two columns and learn the translation
without doing it by hand.

**Takeaway.** R syntax on the left, math on the right, both notations
side by side.

## 8. The notation bridge for educators

[`notation_bridge()`](https://itchyshin.github.io/symbolizer/reference/notation_bridge.md)
is the deeper teaching surface: every symbol *and* every equation pairs
its index form with its matrix form and tags both shapes.

``` r

notation_bridge(sym)
```

| concept | index | matrix | shape | concrete |
|:---|:---|:---|:---|:---|
| conditional_distribution | $`W_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2)`$ | $`\mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2))`$ | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ |
| mu_linear_predictor | $`\mu_i = \beta_{0} + \beta_{1} \, T_i + \beta_{2} \, \mathrm{log}(F_i) + \beta_{3} \, [sex = \mathrm{male}] + u_{site(i)}`$ | $`\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta} + \mathbf{u}`$ | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ |
| sigma_linear_predictor | $`\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i + \gamma_{2} \, [sex = \mathrm{male}]`$ | $`\log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma}`$ | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ |
| body_mass | $`W_i`$ | $`\mathbf{w}`$ | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ |
| parameter | $`\mu_i`$ | $`\boldsymbol{\mu}`$ | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ |
| parameter | $`\sigma_i`$ | $`\boldsymbol{\sigma}`$ | $`\mathbb{R}^n`$ | $`\mathbb{R}^{200}`$ |
| coefficient | $`\beta_{0}, \beta_{1}, \beta_{2}, \beta_{3}`$ | $`\boldsymbol{\beta}`$ | $`\mathbb{R}^{p_\mu}`$ | $`\mathbb{R}^{4}`$ |
| coefficient | $`\gamma_{0}, \gamma_{1}, \gamma_{2}`$ | $`\boldsymbol{\gamma}`$ | $`\mathbb{R}^{p_\sigma}`$ | $`\mathbb{R}^{3}`$ |
| design_matrix | — | $`\mathbf{X}`$ | $`\mathbb{R}^{n \times p_\mu}`$ | $`\mathbb{R}^{200 \times 4}`$ |
| design_matrix | — | $`\mathbf{Z}`$ | $`\mathbb{R}^{n \times p_\sigma}`$ | $`\mathbb{R}^{200 \times 3}`$ |
| site | $`u_{site(i)}`$ | $`\mathbf{u}_{site}`$ | $`scalar; \mathbb{R}^{G_{site}} in matrix form`$ | $`scalar; \mathbb{R}^{8} in matrix form`$ |
| variance_component | $`\sigma_{site}`$ | $`\sigma_{site}`$ | scalar | scalar |

The `dimension` column carries the shape rule (`\mathbb{R}^n`,
`\mathbb{R}^{n \times p_\mu}`). The `dimension_concrete` column plugs in
the actual numbers from this fit (`\mathbb{R}^{200}`,
`\mathbb{R}^{200 \times 4}`). A reader learning matrix notation can
stare at this table and see, in one place, that the `\boldsymbol{\mu}`
vector has 200 entries, the `\boldsymbol{\beta}` vector has four, and
`\mathbf{X}` is the 200 by 4 matrix that connects them.

**Takeaway.** Abstract shape rules on one side, concrete numbers from
this fit on the other. That is the bridge.

## 9. Roadmap and capabilities

[`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md)
is the single source of truth for what
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
knows how to render. Each row carries one of five status words:
**Stable**, **First slice**, **Opt-in control**, **Planned or
reserved**, or **Unsupported or blocked**.

``` r

symbolizer_capabilities()
#> # A tibble: 54 × 6
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
#> # ℹ 44 more rows
```

For the model fit in this vignette, the relevant rows are:

- `drmTMB / gaussian / mu` — **Stable**
- `drmTMB / gaussian / sigma` — **Stable**
- `drmTMB / gaussian / random_effects` — **First slice** (intercept-only
  `(1 | group)`; other RE structures still error)

Everything else in the table is **Planned or reserved**. If
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
errors with a capability message, the registry tells you which version
is scheduled to lift the restriction.

**Takeaway.** Read the status word before designing around a tuple. The
registry, not the prose, decides what
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
accepts.
