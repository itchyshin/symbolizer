# Changelog

## symbolizer 0.0.0.9000

- Initial development. v0.1 targets `drmTMB` Gaussian location-scale
  models with structured symbolic specification, LaTeX rendering, symbol
  dictionary, component table, formula bridge, assumption table,
  parameter interpretation, and a notation bridge teaching surface.

### v0.1 surface (Stable)

- [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  builds a structured `symbolized_model` from a fitted `drmTMB` Gaussian
  location-scale model with fixed effects in both the mu and sigma
  submodels. Reads `fit$formula$entries`, `fit$family`,
  `fit$coefficients`, and
  [`drmTMB::fixef()`](https://itchyshin.github.io/drmTMB/reference/fixef.html)
  per dpar.
- [`extract_terms()`](https://itchyshin.github.io/symbolizer/reference/extract_terms.md)
  is the term-grammar / model-matrix bridge: every renderer consumes
  this layer and never re-parses formulas.
- Capability registry
  ([`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md))
  gates
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  with the five-level status vocabulary borrowed from drmTMB.

### Dual notation (index ↔︎ matrix)

- Every component carries both index-form and matrix-form LaTeX, with
  lowercase bold for vectors (`\mathbf{w}`, `\boldsymbol{\beta}`) and
  uppercase bold for matrices (`\mathbf{X}`, `\mathbf{Z}`).
- Symbol dictionary carries two dimension columns: abstract
  (`\mathbb{R}^n`) and concrete (e.g. `\mathbb{R}^{80}`).
- [`notation_bridge()`](https://itchyshin.github.io/symbolizer/reference/notation_bridge.md)
  returns an educator-facing translation table that pairs each model
  piece across both notations with its dimension.

### Renderers

- `equations(sym, notation)` returns the per-row LaTeX in either or both
  forms.
- `as_latex(sym, notation, env)` returns a single string ready to splice
  into a LaTeX document; stacks both forms when `notation = "both"`.
- `symbol_table(sym, notation)`, `assumption_table(sym)`,
  `formula_bridge(sym, notation)`.
- `parameter_interpretation(sym, scale)` exposes per-coefficient
  readings on link / natural / variance / biological scales.

### Random intercepts (First slice)

- `(1 | group)` on the mu submodel is supported. The mu linear predictor
  gains a `+ u_{group(i)}` term (index) / `+ \mathbf{u}` (matrix), a new
  random-effect distribution row appears in `components`, and the new
  `random_effects` and `variance_components` tibbles register the term.
- Random slopes and random effects on the sigma submodel raise a clear
  capability error pointing at the registry.
