# Package index

## Package

- [`symbolizer`](https://itchyshin.github.io/symbolizer/reference/symbolizer-package.md)
  [`symbolizer-package`](https://itchyshin.github.io/symbolizer/reference/symbolizer-package.md)
  : symbolizer: Structured Symbolic Specifications, Interpretations, and
  Teachable Stories for Modern Statistical Models

## Build the structured symbolic object

The product. Renderers consume it; users override symbols, units,
context here.

- [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  : Symbolize a fitted statistical model
- [`symbolize(`*`<drmTMB>`*`)`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  : Symbolize a drmTMB fit (Gaussian location-scale, v0.1)
- [`validate_symbolized_model()`](https://itchyshin.github.io/symbolizer/reference/validate_symbolized_model.md)
  : Validate a symbolized_model object
- [`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md)
  : Symbolizer capability registry

## Read both notations

Educator-facing bridge between index and matrix forms.

- [`notation_bridge()`](https://itchyshin.github.io/symbolizer/reference/notation_bridge.md)
  : Index ↔ matrix notation bridge

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

- [`new_symbolized_model()`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
  : Construct a symbolized_model object
