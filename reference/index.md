# Package index

## Package

- [`symbolizer`](https://itchyshin.github.io/symbolizer/reference/symbolizer-package.md)
  [`symbolizer-package`](https://itchyshin.github.io/symbolizer/reference/symbolizer-package.md)
  : symbolizer: Structured Symbolic Specifications, Interpretations, and
  Teachable Stories for Modern Statistical Models

## First-time entry

One call that does it all, plus the plain-English summary of a
symbolized_model.

- [`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md)
  : One-call explainer for a fitted model
- [`summary(`*`<symbolized_model>`*`)`](https://itchyshin.github.io/symbolizer/reference/summary.symbolized_model.md)
  : Plain-English summary of a symbolized model

## Teaching bundle (one-call)

model_card collects equation, assumptions, readings, extraction calls,
recommended plots in one S3 object.

- [`model_card()`](https://itchyshin.github.io/symbolizer/reference/model_card.md)
  : One-call teaching bundle for a symbolized model

## Build the structured symbolic object

The product. Renderers consume it; users override symbols, units,
context here.

- [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  : Symbolize a fitted statistical model
- [`symbolize(`*`<drmTMB>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  : Symbolize a drmTMB fit (Gaussian and bivariate Gaussian, v0.1)
- [`symbolize(`*`<gllvmTMB>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.gllvmTMB.md)
  : Symbolize a gllvmTMB fit (Gaussian latent-variable, v0.1)
- [`symbolize(`*`<glmmTMB>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.glmmTMB.md)
  : Symbolize a glmmTMB fit (Gaussian, v0.7 first slice)
- [`symbolize(`*`<brmsfit>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.brmsfit.md)
  : Symbolize a brms fit (Gaussian, v0.8 first slice)
- [`symbolize(`*`<MCMCglmm>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.MCMCglmm.md)
  : Symbolize an MCMCglmm fit (Gaussian, v0.9 first slice)
- [`symbolize(`*`<lm>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.lm.md)
  : Symbolize a base R lm() fit (Gaussian, v0.10 first slice)
- [`symbolize(`*`<glm>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.glm.md)
  : Symbolize a base R glm() fit (Gaussian / binomial / poisson, v0.10
  first slice)
- [`symbolize(`*`<lmerMod>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.lmerMod.md)
  : Symbolize an lme4 lmer() fit (Gaussian, v0.10 first slice)
- [`symbolize(`*`<glmerMod>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.glmerMod.md)
  : Symbolize an lme4 glmer() fit (binomial / poisson, v0.11 first
  slice)
- [`symbolize(`*`<sdmTMB>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.sdmTMB.md)
  : Symbolize an sdmTMB fit (Gaussian, v0.12 first slice)
- [`symbolize(`*`<rma.uni>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.rma.uni.md)
  : Symbolize a metafor rma.uni fit (meta-analysis / meta-regression,
  v0.13 first slice)
- [`symbolize(`*`<rma.mv>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.rma.mv.md)
  : Symbolize a metafor rma.mv fit (multilevel / multivariate
  meta-analysis, v0.13.1)
- [`symbolize(`*`<gam>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.gam.md)
  : Symbolize an mgcv gam / bam fit (additive grammar, v0.14 first
  slice)
- [`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md)
  : Symbolizer capability registry

## Read both notations

Educator-facing bridge between index and matrix forms.

- [`notation_bridge()`](https://itchyshin.github.io/symbolizer/reference/notation_bridge.md)
  : Index vs matrix notation bridge

## See the data flow

Numeric arrays behind the symbols, and the three-views HTML widget.

- [`expand()`](https://itchyshin.github.io/symbolizer/reference/expand.md)
  : Expand a symbolized_model to its underlying numeric arrays
- [`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md)
  : Three-views HTML rendering of a symbolized_model

## Render the equations

LaTeX surface. Lines come from the symbolized_model; renderers only
choose the layout.

- [`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md)
  : Equation rows from a symbolized_model
- [`as_latex()`](https://itchyshin.github.io/symbolizer/reference/as_latex.md)
  : Render a symbolized_model as LaTeX

## Render the tables

Symbols (with dimensions), assumptions (stated / implied / not checked),
R-syntax-to-math bridge.

- [`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md)
  : Symbol dictionary as a reader-friendly table
- [`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md)
  : Assumption table for a symbolized model
- [`formula_bridge()`](https://itchyshin.github.io/symbolizer/reference/formula_bridge.md)
  : Formula bridge table for a symbolized model

## Interpret the coefficients

Per-parameter readings on link, natural, variance, and biological
scales.

- [`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
  : Per-parameter interpretations for a symbolized model

## Marginal estimates

Per-group means and per-group slopes via emmeans, alongside the contrast
rows.

- [`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
  : Per-group marginal means for a symbolized model
- [`group_slopes()`](https://itchyshin.github.io/symbolizer/reference/group_slopes.md)
  : Per-group slopes for a continuous predictor

## Compare two models

Structural diff between two symbolized_model objects: which submodels,
which terms, which assumption statuses differ.

- [`compare_symbolic()`](https://itchyshin.github.io/symbolizer/reference/compare_symbolic.md)
  : Structural comparison of two symbolized models

## Draft a Methods paragraph

Turn a symbolized_model into a draft Methods-section paragraph (opt-in,
template-based, never LLM).

- [`methods_text()`](https://itchyshin.github.io/symbolizer/reference/methods_text.md)
  : Methods-section paragraph from a symbolized model

## Per-fit warnings

Conditions symbolize() flagged when building the object (e.g., Wald CI
with few RE groups). Templated from inst/extdata/warning-templates.csv.

- [`warning_table()`](https://itchyshin.github.io/symbolizer/reference/warning_table.md)
  : Per-fit prose warnings for a symbolized model

## Model diagram

Render the structural model as a DAG (nodes for response, parameters,
predictors, groups, random effects). Returns a list with the DOT
representation ready for GraphvizOnline or DiagrammeR.

- [`as_dag()`](https://itchyshin.github.io/symbolizer/reference/as_dag.md)
  : Model diagram for a symbolized model

## Internal: term-grammar bridge

The R formula \<-\> model matrix \<-\> biological symbol layer that
every renderer reads.

- [`extract_terms()`](https://itchyshin.github.io/symbolizer/reference/extract_terms.md)
  : Build the term-grammar / model-matrix bridge for one submodel
- [`get_parameterization()`](https://itchyshin.github.io/symbolizer/reference/get_parameterization.md)
  : Get the family parameterization contract

## Internal: capability registry

- [`capability_check()`](https://itchyshin.github.io/symbolizer/reference/capability_check.md)
  : Check whether a (class, family, component) tuple is supported

## Internal: template loader

- [`load_template()`](https://itchyshin.github.io/symbolizer/reference/load_template.md)
  : Load a template CSV from inst/extdata
- [`clear_template_cache()`](https://itchyshin.github.io/symbolizer/reference/clear_template_cache.md)
  : Clear the template cache

## Internal: formula helpers

- [`formula_lhs()`](https://itchyshin.github.io/symbolizer/reference/formula_lhs.md)
  : Get the left-hand side of a formula

- [`formula_rhs()`](https://itchyshin.github.io/symbolizer/reference/formula_rhs.md)
  : Get the right-hand side of a formula

- [`formula_vars()`](https://itchyshin.github.io/symbolizer/reference/formula_vars.md)
  : All variable names appearing in a formula RHS

- [`wrap_aligned()`](https://itchyshin.github.io/symbolizer/reference/wrap_aligned.md)
  :

  Wrap a vector of equation lines in `aligned` environment

- [`align_at()`](https://itchyshin.github.io/symbolizer/reference/align_at.md)
  :

  Insert an alignment marker before `=` or `\\sim`

- [`wrap_env()`](https://itchyshin.github.io/symbolizer/reference/wrap_env.md)
  : Wrap aligned LaTeX equation lines in a chosen environment

## Internal: object construction

S3 constructor and validator. Useful only for advanced users
hand-building symbolized_model objects.

- [`new_symbolized_model()`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
  : Construct a symbolized_model object
- [`validate_symbolized_model()`](https://itchyshin.github.io/symbolizer/reference/validate_symbolized_model.md)
  : Validate a symbolized_model object
