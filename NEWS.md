# symbolizer 0.0.0.9000

## v0.1.1 (in progress) — confidence bands and marginal estimates

* `symbolize.drmTMB()` gains a `ci_method = "wald"` argument and populates
  five new columns on `fixed_effects` and `interpretation`: `std_error`,
  `confint_low`, `confint_high`, `excludes_zero`, `ci_method`. Existing
  callers see additive columns only. Confidence bands come from
  `stats::confint(fit, parm, method, level)` dispatched on `confint.drmTMB`;
  passing `ci_method = "profile"` is honest (asymmetric) but slow.
  Satterthwaite / Kenward-Roger corrections wait on drmTMB.
* `print(parameter_interpretation(sym))` shows the band as `(lo, hi)` with
  a trailing `*` marker on rows whose 95% interval excludes zero;
  `knit_print()` adds a `95% CI` column to the rendered table and a footer
  naming the CI method. Renderers consume `metadata$ci_method`.

## v0.1 surface (Stable)

* Initial development. v0.1 targets `drmTMB` Gaussian location-scale models
  with structured symbolic specification, LaTeX rendering, symbol dictionary,
  component table, formula bridge, assumption table, parameter interpretation,
  and a notation bridge teaching surface.

## v0.1 surface (Stable)

* `symbolize.drmTMB()` builds a structured `symbolized_model` from a fitted
  `drmTMB` Gaussian location-scale model with fixed effects in both the mu
  and sigma submodels. Reads `fit$formula$entries`, `fit$family`,
  `fit$coefficients`, and `drmTMB::fixef()` per dpar.
* `extract_terms()` is the term-grammar / model-matrix bridge: every renderer
  consumes this layer and never re-parses formulas.
* Capability registry (`symbolizer_capabilities()`) gates `symbolize()` with
  the five-level status vocabulary borrowed from drmTMB.

## Dual notation (index ↔ matrix)

* Every component carries both index-form and matrix-form LaTeX, with
  lowercase bold for vectors (`\mathbf{w}`, `\boldsymbol{\beta}`) and
  uppercase bold for matrices (`\mathbf{X}`, `\mathbf{Z}`).
* Symbol dictionary carries two dimension columns: abstract (`\mathbb{R}^n`)
  and concrete (e.g. `\mathbb{R}^{80}`).
* `notation_bridge()` returns an educator-facing translation table that
  pairs each model piece across both notations with its dimension.

## Renderers

* `equations(sym, notation)` returns the per-row LaTeX in either or both forms.
* `as_latex(sym, notation, env)` returns a single string ready to splice into
  a LaTeX document; stacks both forms when `notation = "both"`.
* `symbol_table(sym, notation)`, `assumption_table(sym)`, `formula_bridge(sym, notation)`.
* `parameter_interpretation(sym, scale)` exposes per-coefficient readings on
  link / natural / variance / biological scales.

## Random intercepts (First slice)

* `(1 | group)` on the mu submodel is supported. The mu linear predictor
  gains a `+ u_{group(i)}` term (index) / `+ \mathbf{u}` (matrix), a new
  random-effect distribution row appears in `components`, and the new
  `random_effects` and `variance_components` tibbles register the term.
* Random slopes and random effects on the sigma submodel raise a clear
  capability error pointing at the registry.
