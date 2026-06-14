# One-call explainer for a fitted model

`explain()` is the recommended entry point for **understanding** a fit.
It runs
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
internally and returns a `symbolized_explanation` that bundles the
original
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
together with the reader-facing pieces already rendered:

- `equations` – the
  [`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md)
  tibble (both notations)

- `symbols` – the
  [`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md)
  result

- `assumptions` – the
  [`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md)
  result

- `formula_bridge` – the
  [`formula_bridge()`](https://itchyshin.github.io/symbolizer/reference/formula_bridge.md)
  result (also available as the deprecated alias `bridge`)

- `interpretation` – the
  [`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
  result

- `factor_coding` – a one-line dummy-coding overview per factor

- `variance_components` – where the variation lives (NULL when the model
  has no random effects)

- `notation_bridge` – the
  [`notation_bridge()`](https://itchyshin.github.io/symbolizer/reference/notation_bridge.md)
  result

Use `explain()` to *understand* a model; use
[`model_card()`](https://itchyshin.github.io/symbolizer/reference/model_card.md)
when you also want to *act* on it – it adds extraction calls,
recommended plots, and marginal means / slopes / contrasts on top of the
same pieces.

Print the result at the console for a walkthrough led by a plain-English
paragraph, or knit it inside a Quarto / R Markdown document for a
heading-and-kable section per piece.

Use [`summary()`](https://rdrr.io/r/base/summary.html) on an
already-symbolize'd object to get the same walkthrough without
re-running
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md).

## Usage

``` r
explain(fit, symbols = NULL, units = NULL, context = NULL, ...)
```

## Arguments

- fit:

  A fitted statistical model object.

- symbols:

  Optional named character vector mapping variable names to
  user-supplied LaTeX symbols, e.g.
  `c(body_mass = "W_i", temperature = "T_i")`.

- units:

  Optional named character vector mapping variable names to units, e.g.
  `c(body_mass = "g", temperature = "C")`.

- context:

  Optional short character description of the model, e.g.
  `"avian body-size location-scale model"`.

- ...:

  Reserved for method-specific extra arguments.

## Value

A `symbolized_explanation` object with elements `model` (the underlying
`symbolized_model`), `equations`, `symbols`, `assumptions`,
`formula_bridge` (and its deprecated alias `bridge`), `interpretation`,
`factor_coding`, `variance_components` (NULL when the model has no
random effects), `notation_bridge`.

## See also

[`model_card()`](https://itchyshin.github.io/symbolizer/reference/model_card.md)
for the act-on-it bundle.

## Examples

``` r
# `explain()` takes the fitted model directly -- it runs `symbolize()` for you.
explain(lm(mpg ~ wt, data = mtcars))
#> 
#> ── == explaining your <lm> model == ────────────────────────────────────────────
#> This is a gaussian model of `mpg` (n = 32) with 1 submodel: mu explains the
#> mean (using an identity link). Coefficients are fit by maximum likelihood via
#> stats.
#> 
#> ── Equations (both notations) ──
#> 
#> ── Equations ──
#> 
#> distribution
#>   index:  \mathrm{mpg}_i \mid \mu_i,\, \sigma \sim \mathrm{Normal}(\mu_i,\, \sigma^2)
#>   matrix: \mathbf{mpg} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} \sim \mathcal{N}(\boldsymbol{\mu},\, \sigma^2 \mathbf{I}_n)
#> mu_linear_predictor
#>   index:  \mu_i = \beta_{0} + \beta_{1} \, \mathrm{wt}_i
#>   matrix: \boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta}
#> 
#> ── The symbols ──
#> 
#> ── Symbol dictionary ("both") ──
#> 
#> mpg [response]
#> index: `\mathrm{mpg}_i`
#> matrix: `\mathbf{mpg}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{32}`)
#> response variable
#> wt [predictor]
#> index: `\mathrm{wt}_i`
#> matrix: `(no matrix form)`
#> dimension: `column of design matrix` (= `column of X (length 32)`)
#> continuous predictor
#> (parameter)
#> index: `\mu_i`
#> matrix: `\boldsymbol{\mu}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{32}`)
#> conditional mu of mpg
#> (residual_sd)
#> index: `\sigma`
#> matrix: `\boldsymbol{\sigma}`
#> dimension: `scalar (constant across observations)` (= `scalar`)
#> residual standard deviation of mpg
#> (coefficient)
#> index: `\beta_{0}, \beta_{1}`
#> matrix: `\boldsymbol{\beta}`
#> dimension: `\mathbb{R}^{p_\mu}` (= `\mathbb{R}^{2}`)
#> mu submodel coefficients
#> (design_matrix)
#> index: `(no index form)`
#> matrix: `\mathbf{X}`
#> dimension: `\mathbb{R}^{n \times p_\mu}` (= `\mathbb{R}^{32 \times 2}`)
#> mu submodel design matrix
#> 
#> ── What's assumed ──
#> 
#> ── Assumptions ──
#> 
#> conditional_distribution
#> expression: `\mathrm{mpg}_i \mid \mu_i,\, \sigma_i \sim
#> \mathrm{Normal}(\mu_i,\, \sigma_i^2)`
#> meaning: mpg varies normally around its expected value
#> status: ["explicit"]
#> linear_predictor (mu)
#> expression: `\mu_i = \beta_0 + \sum_k \beta_k X_{ki}`
#> meaning: Expected mpg is a linear combination of the mean-model predictors
#> status: ["explicit"]
#> independence
#> expression: `\mathrm{mpg}_i \perp \mathrm{mpg}_j \mid X \text{ for } i \ne j`
#> meaning: Observations are conditionally independent given the predictors
#> status: ["follows from the formula"]
#> no_missing_at_random
#> expression: `—`
#> meaning: Observations are assumed not missing in a way that depends on the
#> unobserved response
#> status: ["your responsibility"]
#> 
#> ── R syntax to mathematics ──
#> 
#> ── Formula bridge ("both") ──
#> 
#> mu
#> R: `mpg ~ wt`
#> meaning: Expected mpg is a linear function of the mean-model predictors
#> math: `\mu_i = \beta_{0} + \beta_{1} \, \mathrm{wt}_i`
#> matrix: `\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta}`
#> 
#> ── What each coefficient means ──
#> 
#> ── Parameter interpretation ("all") ──
#> 
#> ── submodel: mu 
#> (Intercept) ["intercept"] estimate = "37.3" (33.5, 41.1) *
#> link: Expected mpg at the reference
#> natural: Expected mpg for the reference case
#> variance: —
#> biological: Baseline mpg in the reference condition
#> wt ["slope"] estimate = "-5.34" (-6.49, -4.20) *
#> link: Linear change in expected mpg per unit of wt
#> natural: Expected mpg changes by -5.34 per unit of wt
#> variance: —
#> biological: A unit change in wt shifts the expected mpg by -5.34
#> 
#> ── How the variation splits ──
#> 
#> # A tibble: 1 × 5
#>   parameter group    term     sd_estimate var_estimate
#>   <chr>     <chr>    <chr>          <dbl>        <dbl>
#> 1 residual  residual Residual        3.05         9.28
#> ── Index vs matrix notation ──
#> 
#> ── Notation bridge ──
#> 
#> conditional_distribution
#> index: `\mathrm{mpg}_i \mid \mu_i,\, \sigma \sim \mathrm{Normal}(\mu_i,\,
#> \sigma^2)`
#> matrix: `\mathbf{mpg} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} \sim
#> \mathcal{N}(\boldsymbol{\mu},\, \sigma^2 \mathbf{I}_n)`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{32}`)
#> mu_linear_predictor
#> index: `\mu_i = \beta_{0} + \beta_{1} \, \mathrm{wt}_i`
#> matrix: `\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{32}`)
#> mpg
#> index: `\mathrm{mpg}_i`
#> matrix: `\mathbf{mpg}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{32}`)
#> parameter
#> index: `\mu_i`
#> matrix: `\boldsymbol{\mu}`
#> dimension: `\mathbb{R}^n` (= `\mathbb{R}^{32}`)
#> residual_sd
#> index: `\sigma`
#> matrix: `\boldsymbol{\sigma}`
#> dimension: `scalar (constant across observations)` (= `scalar`)
#> coefficient
#> index: `\beta_{0}, \beta_{1}`
#> matrix: `\boldsymbol{\beta}`
#> dimension: `\mathbb{R}^{p_\mu}` (= `\mathbb{R}^{2}`)
#> design_matrix
#> index: `--`
#> matrix: `\mathbf{X}`
#> dimension: `\mathbb{R}^{n \times p_\mu}` (= `\mathbb{R}^{32 \times 2}`)
```
