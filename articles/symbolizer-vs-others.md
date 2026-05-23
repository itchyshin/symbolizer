# How symbolizer compares to equatiomatic, gtsummary, and friends

## 1. What this vignette is for

`symbolizer` is one tool in a much larger R modelling-toolkit landscape.
Other packages have spent years polishing equation rendering, regression
tables, parameter extraction, marginal-effect post-processing, and
auto-narration. None of them replaces another; each occupies a different
slot. The point of this article is to map those slots so you can pick
the right tool for the job — or, more often, the right two or three
tools to combine.

We assume you have already read
[`vignette("symbolizer")`](https://itchyshin.github.io/symbolizer/articles/symbolizer.md)
and seen what a `symbolized_model` object carries: the equation in both
notations, the symbol dictionary with dimensions, the assumption table
with status labels, the formula-to-math bridge, and the per-coefficient
interpretation. That bundle is the structural and educational slot. The
packages compared here fill other slots.

To keep the vignette concrete, we re-use the canonical Gaussian
location-scale fit from the Get Started vignette: body mass on
temperature, with the residual SD also depending on temperature.

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

sym <- symbolize(
  fit,
  symbols = c(body_mass = "W_i", temperature = "T_i"),
  units   = c(body_mass = "g",   temperature = "C"),
  context = "avian body-size location-scale model"
)
```

**Takeaway.** This vignette is a map of the landscape; the other
vignettes show you how `symbolizer` works.

## 2. `equatiomatic`: the scribe

`equatiomatic::extract_eq()` was the package that taught the R world
that fitted models could render themselves as LaTeX equations. Its job
to be done is narrow and well-executed: given a single fit, return a
clean LaTeX block ready to paste into a paper. It handles `lm`, `glm`,
`lmer` (mixed models), GAM smooth terms, and multinomial models, with
options for substituted coefficients (`use_coefs = TRUE`) and Greek
versus letter styling.

`symbolizer` started where `equatiomatic` reaches its current limits:
multi-submodel distributional models like `drmTMB`’s location-scale
family, where the residual SD has its own linear predictor and link. For
those fits, `equatiomatic` renders only the mean structure; `symbolizer`
renders mu, sigma, the random-effect distributions, and the variance
components as a single coherent block. `symbolizer` also carries the
two-notation bridge, the assumption table, the symbol dictionary with
dimensions, and the per-coefficient biological reading — surfaces that
`equatiomatic` does not target.

Practically: reach for `equatiomatic` when you want a one-line LaTeX
equation for a textbook `lm` or `glm`. Reach for `symbolizer` when the
fit has structure that needs explaining — multiple submodels, scale
covariates, random effects you want to discuss, or a teaching audience.

``` r

cat("$$", as_latex(sym, notation = "index"), "$$", sep = "\n")
```

``` math
\begin{aligned}
W_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
\mu_i & = \beta_{0} + \beta_{1} \, T_i \\
\log(\sigma_i) & = \gamma_{0} + \gamma_{1} \, T_i
\end{aligned}
```

**Takeaway.** `equatiomatic` is the scribe for the equation;
`symbolizer` is the bundle for everything around it.

## 3. `gtsummary` and `modelsummary`: the table-makers

`gtsummary::tbl_regression()` and `modelsummary::modelsummary()` solve a
different problem: publication-ready regression tables. Their job to be
done is the coefficient table that lives in the Results section —
estimates, standard errors, confidence intervals, p-values, model-fit
statistics — with a long tail of polish for footnotes, p-value
formatting, reference levels, exponentiated odds ratios, and grouping
multiple models side by side. Between them they cover essentially every
common model class and every common output format (gt, flextable, kable,
HTML, Word, LaTeX, Markdown).

The difference is what they summarise. `gtsummary` and `modelsummary`
summarise the *fit*: the numeric output of the optimisation, formatted
for a journal. `symbolizer` describes the *structure*: what the model
is, what it assumes, how its formula maps to math, what each coefficient
means on a biological scale before you read its number. There is no
overlap. A typical paper uses both: the coefficient table from
`gtsummary` or `modelsummary` in the Results, the equation and
biological reading from `symbolizer` in the Methods.

For comparison, here is what `symbolizer` puts where a coefficient table
would normally go:

``` r

parameter_interpretation(sym, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | biological_reading |
|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 29.6 | Baseline body_mass in the reference condition |
| mu | temperature | slope | 0.492 | A unit change in temperature shifts the expected body_mass by 0.492 |
| sigma | (Intercept) | intercept | 0.485 | Baseline level of unexplained individual variation in body_mass |
| sigma | temperature | slope | 0.0936 | A unit change in temperature multiplies the unexplained variability of body_mass by exp(0.0936) |

The columns are *meanings*, not *numbers*. The estimate is one column;
the rest is interpretation.

**Takeaway.** Use a table-maker for the numeric coefficient table; use
`symbolizer` for the equation, the assumptions, and the reading.

## 4. `parameters` (easystats): the harmonizer

`parameters::model_parameters()`, part of the easystats family,
standardises parameter extraction across a remarkably wide range of
model classes. Feed it almost any fit — `lm`, `glm`, `lme4`, `glmmTMB`,
`brms`, `rstanarm`, `survival`, `GAM`, `nlme`,
[`MASS::polr`](https://rdrr.io/pkg/MASS/man/polr.html), and many more —
and you get back a tidy tibble of estimates, standard errors, confidence
intervals, and test statistics, with consistent column names regardless
of the source object.

That is a different problem from `symbolizer`. `parameters` is the
*harmonizer*: it absorbs the eccentricities of dozens of S3 method
implementations and gives you one tibble shape to program against.
`symbolizer` is the *storyteller*: it returns the structured object that
the equation, the symbol dictionary, the assumption table, the notation
bridge, and the per-coefficient biological reading all flow from. Where
`parameters` is numeric, `symbolizer` is symbolic and prose; where
`parameters` is wide in class coverage, `symbolizer` is deep in what it
does per class.

A useful mental model: `parameters` is what you call when you want a
machine-readable tibble of estimates. `symbolizer` is what you call when
you want to write the Methods section.

**Takeaway.** `parameters` standardises the numbers; `symbolizer`
structures the meaning.

## 5. `marginaleffects`: the contrasts engine

`marginaleffects` solves the post-fit question: given this model, what
does it predict at arbitrary covariate values, what are the contrasts
between groups, what are the average marginal effects, what are the
slopes at the mean, what does a counterfactual look like? Its job is
deeply general post-fit analysis — predictions, contrasts, slopes,
hypothesis tests on linear and nonlinear combinations — and it works
across a very large set of model classes.

`symbolizer` answers a different question. `marginaleffects` answers
*“what would this model predict at X = x?”*. `symbolizer` answers *“what
does the structure of this model say?”*. The two are complementary. You
typically symbolize the fit to explain what is being estimated, then
call `marginaleffects` to compute the specific quantities of interest —
average predictions, predicted slopes, contrasts between sex groups,
marginal effects at the mean — that you plot and report.

In a paper: `symbolizer` in the Methods, `marginaleffects` for the
prediction figures and the contrast tests in the Results.

**Takeaway.** `marginaleffects` is the engine for *what does it
predict*; `symbolizer` is the engine for *what does the model say*.

## 6. `report`: the auto-narrator

`report::report()` (also from easystats) auto-generates a paragraph of
prose describing a fit: the model class, the predictors, the
coefficients with effect sizes, an interpretation in plain English. It
is opinionated about the narrative structure — what to mention, what
order to mention it in, which thresholds to use for “small”, “moderate”,
“large” effects.

`symbolizer` does not generate a paragraph. It hands you the building
blocks: each coefficient’s biological reading in
[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md),
each assumption in
[`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md),
each equation in
[`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md).
The author composes the paragraph using those blocks rather than
accepting a generated one. The `biological_reading` column of
[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
is the closest analog — a sentence-shaped reading of each coefficient —
but it is a row in a tibble, not a finished paragraph.

Practically: `report` if you want a draft paragraph fast and are happy
to edit it. `symbolizer` if you want to assemble the prose yourself from
auditable pieces, with the equation and the assumptions visible on the
same page.

**Takeaway.** `report` writes the paragraph; `symbolizer` gives you the
rows, and you write the paragraph.

## 7. A summary matrix

| Package | Job to be done | Input | Output | When to use it | When NOT to use it |
|:---|:---|:---|:---|:---|:---|
| symbolizer | Structured symbolic model: equation, symbols, assumptions, interpretation | Fitted model (drmTMB now; broader in roadmap) | symbolized_model object; equations, tables, HTML widget | Methods section: equation, assumptions, per-coefficient reading | Coefficient tables, prediction grids, or auto-prose |
| equatiomatic | Render a fitted model as a LaTeX equation | Fitted model (lm, glm, lmer, gam, multinomial) | LaTeX string | One clean LaTeX equation for a simple fit | Multi-submodel distributional fits, teaching, assumption audit |
| gtsummary | Publication-ready regression table | Fitted model | gt / flextable / kable table | Results section: the coefficient table | Equation rendering or biological interpretation |
| modelsummary | Regression tables and model-comparison tables, many formats | Fitted model(s) | gt / flextable / kable / Word / LaTeX / Markdown table | Results section: one or many coefficient tables | Equation rendering or biological interpretation |
| parameters | Tidy tibble of parameter estimates across many classes | Fitted model (very wide class coverage) | Tidy tibble of estimates and uncertainty | Programmatic access to estimates with consistent columns | Equation rendering, assumption audit, prose |
| marginaleffects | Predictions, contrasts, slopes, marginal effects | Fitted model (very wide class coverage) | Tibble of predictions / contrasts / slopes, plus plots | Predictions and contrasts to plot or test | Equation rendering, assumption audit, prose |
| report | Auto-generated prose paragraph describing a fit | Fitted model | Prose paragraph | Quick first-draft prose to edit | Auditable templated readings or equation rendering |

**Takeaway.** One row per package; pick by the job column.

## 8. Picking a stack

A typical ecology or evolution paper uses two or three of these tools
together. A common stack for a Gaussian location-scale fit like the one
above:

1.  **`symbolizer`** for the equation in the Methods section — both
    notations spliced via `as_latex(sym, notation = "both")` — plus the
    assumption table from `assumption_table(sym)` and the
    per-coefficient biological reading from
    `parameter_interpretation(sym, scale = "biological")`.
2.  **`gtsummary`** (or **`modelsummary`**) for the coefficient table in
    the Results: estimates, confidence intervals, model-fit statistics,
    formatted to journal style.
3.  **`marginaleffects`** for the prediction figure: predicted body mass
    across temperature for each sex, with confidence bands, plus the
    marginal-effect contrast between sexes at the mean temperature.

If you also want a quick draft paragraph for the Results, drop in
**`report`** before you edit. If your downstream code wants tibbles of
estimates regardless of model class, **`parameters`** harmonises that
layer.

``` r

parameter_interpretation(sym, scale = "biological")
```

| submodel | term_label | coefficient_role | estimate | biological_reading |
|:---|:---|:---|:---|:---|
| mu | (Intercept) | intercept | 29.6 | Baseline body_mass in the reference condition |
| mu | temperature | slope | 0.492 | A unit change in temperature shifts the expected body_mass by 0.492 |
| sigma | (Intercept) | intercept | 0.485 | Baseline level of unexplained individual variation in body_mass |
| sigma | temperature | slope | 0.0936 | A unit change in temperature multiplies the unexplained variability of body_mass by exp(0.0936) |

The point is that none of these is competing with the others. Each fills
a different slot in the writing pipeline.

**Takeaway.** Stack two or three; do not pick one.

## 9. Takeaway

`symbolizer` fills the *structural and educational* slot: what the model
is, what it assumes, what each coefficient means before you read its
number. The other packages fill the *summarisation*, *standardisation*,
*prediction*, and *auto-narration* slots. Pick by the job, not by the
package — and for most papers, the right answer is two or three of them
used together.
