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
#>   S_i                                         factor (female, male)
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
#> 
#> ── Equations ──
#> 
#> distribution
#>   index:  W_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2)
#>   matrix: \mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2))
#> mu_linear_predictor
#>   index:  \mu_i = \beta_{0} + \beta_{1} \, T_i + \beta_{2} \, \mathrm{log}(F_i) + \beta_{3} \, [sex = \mathrm{male}] + u_{site(i)}
#>   matrix: \boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta} + \mathbf{u}
#> sigma_linear_predictor
#>   index:  \log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i + \gamma_{2} \, [sex = \mathrm{male}]
#>   matrix: \log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma}
#> mu_random_intercept_site
#>   index:  u_{site} \sim \mathcal{N}(0,\, \sigma_{site}^2)
#>   matrix: \mathbf{u}_{site} \sim \mathcal{N}(\mathbf{0},\, \sigma_{site}^2 \mathbf{I}_{8})
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
#> 
#> ── Equations ──
#> 
#> sigma_linear_predictor
#>   index:  \log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i + \gamma_{2} \, [sex = \mathrm{male}]
#>   matrix: \log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma}
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
#> 
#> ── Symbol dictionary ("both") ──
#> 
#> body_mass [response]
#> index: `W_i`
#> matrix: `\mathbf{w}`
#> units: "g"
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{200}`)
#> response variable
#> temperature [predictor]
#> index: `T_i`
#> matrix: `(no matrix form)`
#> units: "C"
#> dimension: `column of design matrix` (= `column of \mathbf{X} (length 200)`)
#> continuous predictor
#> food [transformation]
#> index: `F_i`
#> matrix: `(no matrix form)`
#> units: "g/day"
#> dimension: `column of design matrix` (= `column of \mathbf{X} (length 200)`)
#> predictor (log-transformed)
#> sex [factor]
#> index: `S_i`
#> matrix: `(no matrix form)`
#> dimension: `column of design matrix` (= `column of \mathbf{X} (length 200)`)
#> factor (female, male)
#> (parameter)
#> index: `\mu_i`
#> matrix: `\boldsymbol{\mu}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{200}`)
#> conditional mu of body_mass
#> (parameter)
#> index: `\sigma_i`
#> matrix: `\boldsymbol{\sigma}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{200}`)
#> conditional sigma of body_mass
#> (coefficient)
#> index: `\beta_{0}, \beta_{1}, \beta_{2}, \beta_{3}`
#> matrix: `\boldsymbol{\beta}`
#> dimension: `\mathbb{R}^{p_\mu}` (= `\mathbb{R}^{4}`)
#> mu submodel coefficients
#> (coefficient)
#> index: `\gamma_{0}, \gamma_{1}, \gamma_{2}`
#> matrix: `\boldsymbol{\gamma}`
#> dimension: `\mathbb{R}^{p_\sigma}` (= `\mathbb{R}^{3}`)
#> sigma submodel coefficients
#> (design_matrix)
#> index: `(no index form)`
#> matrix: `\mathbf{X}`
#> dimension: `\mathbb{R}^{n \times p_\mu}` (= `\mathbb{R}^{200 \times 4}`)
#> mu submodel design matrix
#> (design_matrix)
#> index: `(no index form)`
#> matrix: `\mathbf{Z}`
#> dimension: `\mathbb{R}^{n \times p_\sigma}` (= `\mathbb{R}^{200 \times 3}`)
#> sigma submodel design matrix
#> site [random_intercept]
#> index: `u_{site(i)}`
#> matrix: `\mathbf{u}_{site}`
#> dimension: `scalar; \mathbb{R}^{G_{site}} in matrix form` (= `scalar;
#> \mathbb{R}^{8} in matrix form`)
#> random intercept by site
#> (variance_component)
#> index: `\sigma_{site}`
#> matrix: `\sigma_{site}`
#> dimension: `scalar` (= `scalar`)
#> between-site standard deviation
```

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

One known limitation: the `independence` row reads “Observations are
conditionally independent given the predictors”. When a random intercept
is present, the cleaner statement is “conditionally independent given
the predictors **and** the random effects”. The v0.1 assumption template
uses the unconditional wording in both cases; treat it as a known item
to fix rather than a claim about your fit.

**Takeaway.** Stated, implied, not_checked is the audit lens: the model
guarantees the first two; the third is your responsibility.

## 6. Reading each coefficient

[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
reads each fixed-effect estimate on every scale that makes sense for its
submodel: a link-scale reading, a natural-scale reading, a
variance-scale reading (sigma only), and a biological reading.

``` r

parameter_interpretation(sym)
#> 
#> ── Parameter interpretation ("all") ──
#> 
#> ── submodel: mu
#> (Intercept) ["intercept"] estimate = "5.55"
#> link: Expected body_mass at the reference
#> natural: Expected body_mass for the reference case
#> variance: —
#> biological: Baseline body_mass in the reference condition
#> temperature ["slope"] estimate = "0.531"
#> link: Linear change in expected body_mass per unit of temperature
#> natural: Expected body_mass changes by 0.531 per unit of temperature
#> variance: —
#> biological: A unit change in temperature shifts the expected body_mass by 0.531
#> sex ["factor_contrast"] estimate = "2.52"
#> link: Difference in expected body_mass for male versus the reference
#> natural: Expected body_mass for male differs from the reference by 2.52
#> variance: —
#> biological: Average body_mass differs between male and the reference
#> 
#> ── submodel: sigma
#> (Intercept) ["intercept"] estimate = "0.221"
#> link: Log residual SD at the reference (SD = exp(0.221))
#> natural: Residual SD = exp(0.221) at the reference
#> variance: Residual variance = exp(2*0.221)
#> biological: Baseline level of unexplained individual variation in body_mass
#> temperature ["slope"] estimate = "0.0546"
#> link: Log residual SD changes by 0.0546 per unit of temperature
#> natural: Residual SD multiplied by exp(0.0546) per unit of temperature
#> variance: Residual variance multiplied by exp(2*0.0546) per unit
#> biological: A unit change in temperature multiplies the unexplained variability
#> of body_mass by exp(0.0546)
#> sex ["factor_contrast"] estimate = "0.0332"
#> link: Log residual SD differs by 0.0332 for male versus the reference
#> natural: Residual SD for male = exp(0.0332) times the reference SD
#> variance: Residual variance for male = exp(2*0.0332) times the reference
#> biological: Individual-level variation differs between male and the reference
#> by a factor of exp(0.0332)
```

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

One rough edge worth flagging: the `log(food)` predictor does not appear
in this table. v0.1 only ships interpretation templates for the
`intercept`, `slope`, and `factor_contrast` roles. A
[`log()`](https://rdrr.io/r/base/Log.html)-transformed predictor takes
the `transformation` role and currently has no template, so its row is
silently dropped. The coefficient is still in `sym$fixed_effects` and
rendered in the equations; it just does not yet get an English reading.

**Takeaway.** Templates exist for the simple roles in v0.1.
Transformations and interactions are on the roadmap.

## 7. R syntax to math, both directions

[`formula_bridge()`](https://itchyshin.github.io/symbolizer/reference/formula_bridge.md)
is the educator-facing translation table from R formula syntax to
mathematics. Two rows, both notations.

``` r

formula_bridge(sym)
#> 
#> ── Formula bridge ("both") ──
#> 
#> mu
#> R: `body_mass ~ temperature + log(food) + sex + (1 | site)`
#> meaning: Expected body_mass is a linear function of the mean-model predictors
#> math: `\mu_i = \beta_{0} + \beta_{1} \, T_i + \beta_{2} \, \mathrm{log}(F_i) +
#> \beta_{3} \, [sex = \mathrm{male}] + u_{site(i)}`
#> matrix: `\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta} + \mathbf{u}`
#> sigma
#> R: `sigma ~ temperature + sex`
#> meaning: Log residual SD of body_mass is a linear function of the scale-model
#> predictors
#> math: `\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i + \gamma_{2} \, [sex =
#> \mathrm{male}]`
#> matrix: `\log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma}`
```

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
#> 
#> ── Notation bridge ──
#> 
#> conditional_distribution
#> index: `W_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2)`
#> matrix: `\mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} \sim
#> \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2))`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{200}`)
#> mu_linear_predictor
#> index: `\mu_i = \beta_{0} + \beta_{1} \, T_i + \beta_{2} \, \mathrm{log}(F_i) +
#> \beta_{3} \, [sex = \mathrm{male}] + u_{site(i)}`
#> matrix: `\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta} + \mathbf{u}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{200}`)
#> sigma_linear_predictor
#> index: `\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i + \gamma_{2} \, [sex =
#> \mathrm{male}]`
#> matrix: `\log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{200}`)
#> body_mass
#> index: `W_i`
#> matrix: `\mathbf{w}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{200}`)
#> parameter
#> index: `\mu_i`
#> matrix: `\boldsymbol{\mu}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{200}`)
#> parameter
#> index: `\sigma_i`
#> matrix: `\boldsymbol{\sigma}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{200}`)
#> coefficient
#> index: `\beta_{0}, \beta_{1}, \beta_{2}, \beta_{3}`
#> matrix: `\boldsymbol{\beta}`
#> dimension: `\mathbb{R}^{p_\mu}` (= `\mathbb{R}^{4}`)
#> coefficient
#> index: `\gamma_{0}, \gamma_{1}, \gamma_{2}`
#> matrix: `\boldsymbol{\gamma}`
#> dimension: `\mathbb{R}^{p_\sigma}` (= `\mathbb{R}^{3}`)
#> design_matrix
#> index: `--`
#> matrix: `\mathbf{X}`
#> dimension: `\mathbb{R}^{n \times p_\mu}` (= `\mathbb{R}^{200 \times 4}`)
#> design_matrix
#> index: `--`
#> matrix: `\mathbf{Z}`
#> dimension: `\mathbb{R}^{n \times p_\sigma}` (= `\mathbb{R}^{200 \times 3}`)
#> site
#> index: `u_{site(i)}`
#> matrix: `\mathbf{u}_{site}`
#> dimension: `scalar; \mathbb{R}^{G_{site}} in matrix form` (= `scalar;
#> \mathbb{R}^{8} in matrix form`)
#> variance_component
#> index: `\sigma_{site}`
#> matrix: `\sigma_{site}`
#> dimension: `scalar` (= `scalar`)
```

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
