# symbolizer — vision

A short, opinionated document. Sets direction the version-by-version
roadmap can’t. Updated when the direction changes, not when a slice
ships.

## Mission

> *symbolizer turns a fitted statistical model into a structured,
> teachable object that a biologist can audit — connecting R formula,
> symbolic equations, parameter scales, assumptions, coefficient
> readings, confidence bands, marginal estimates, and the next
> diagnostic steps.*

The product is not a LaTeX string. The product is a **structured
`symbolized_model`** that any renderer can read.

## Who it’s for

In order of priority:

1.  **Working biologists fitting models.** They know what their data
    *means* but can be unsure what their model *is doing* — what each
    coefficient says about which scale, which assumptions are stated vs
    implied, where to look next.
2.  **Educators teaching statistics from a biology-first perspective.**
    They want examples that match how scientists actually fit and
    interpret models, with the same vocabulary their students will see
    in the wider literature.
3.  **Statisticians collaborating with biologists.** They want one place
    to point a co-author at when explaining what a fitted model is
    actually saying.

Notably **NOT** the primary audience: - Theoretical statisticians (they
have textbooks). - Method developers (they have their own
derivations). - Generic data scientists outside ecology / evolution /
health sciences.

## Core principles

These are non-negotiable and override speed of shipping.

1.  **The structured object is the product.** `symbolize(fit)` returns a
    `symbolized_model`. Every renderer reads that object. No renderer
    re-parses formulas. The single source of truth is the extractor.

2.  **Educator-first prose.** Every prose surface explains what the
    number means in biological terms, not what the coefficient is
    called. Each section ends with a one-line takeaway. Plain language
    beats formal notation when the two compete.

3.  **Dual notation, side by side.** Index form (`y_i = β_0 + β_1 x_i`)
    and matrix form (`y = Xβ`) coexist; users can read either. Lowercase
    bold for vectors, uppercase bold for matrices.

4.  **Honest capability gate.**
    [`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md)
    is the single source of truth for what
    [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
    can read today. Status words: Stable, First slice, Opt-in control,
    Planned or reserved, Unsupported. Prose never claims more than the
    registry allows.

5.  **Functionality before articles.** If a vignette would describe a
    surface that doesn’t exist correctly today, fix the surface first.

6.  **Pitfalls are first-class teaching.** The hardest part of teaching
    a biologist a regression model is not the equation; it’s the
    categorical variables, the dummy encoding, the interaction
    interpretation. Every pedagogy article addresses these head-on.

7.  **Stable terminology.** `mu`, `sigma`, `rho12`, `nu`, `sd(group)`,
    `coscale` — the drmTMB / gllvmTMB vocabulary. Never drift to `tau`,
    generic `variance`, or `rho` without subscript.

8.  **Light-touch uncertainty, no p-value culture.** Confidence bands
    show `(low, high)`; a `*` marker flags rows whose 95% interval
    excludes zero. The marker is a hint, not a verdict.

9.  **Delegate where mature tools exist.** Marginal means come from
    `emmeans` via thin wrappers. We don’t reimplement well-tested
    inference machinery; we provide the structural symbolic surface that
    emmeans and similar don’t.

10. **Wrappers over internals.** Public surface should be small and
    composable. Helpers that users don’t type should be
    `@keywords internal`.

## What success looks like

Concretely, in this order:

- A biologist with a fitted `drmTMB` Gaussian location-scale model can
  call `symbolize(fit)` and `explain(fit)` and learn what the model says
  in five minutes.
- The same biologist with `(1 | group)` random intercepts gets honest
  assumption rewording automatically.
- A statistics teacher uses the categorical / dummies / interactions
  vignette in a class without modification.
- A reviewer reading a paper sees `model_card(fit)` in supplementary
  materials and immediately knows what was fit, what was assumed, and
  what to inspect.
- The capability registry stays honest as the package grows; never a
  claim in prose that the registry doesn’t back.

## What symbolizer is NOT

Equally important.

- **Not a replacement for `equatiomatic`.** equatiomatic is the equation
  scribe; symbolizer is the model tutor. Both belong on the same desk.
- **Not a regression-table generator.** Use `gtsummary` or
  `modelsummary` for publication tables.
- **Not a marginal-effects engine.** We wrap `emmeans` for the common
  cases (group means, per-group slopes); for arbitrary contrasts use
  `marginaleffects` or `emmeans` directly.
- **Not a model-fitting library.** It reads fits; it doesn’t produce
  them.
- **Not a generic LaTeX template.** Every output is sourced from the
  symbolized_model and a CSV template — auditable, not generated.
- **Not a peer-review oracle.** It will not tell you whether your model
  is right. It tells you what your model *says*; the rightness is your
  job.

## Long-term direction (beyond the version roadmap)

The package targets the GLMM ecosystem used in ecology and evolution.
Roadmap (live) is in README.md. The vision beneath the roadmap is:

- **Cover the distributional model in full.** Gaussian
  location-scale-correlation (drmTMB), latent-variable models
  (gllvmTMB), non-Gaussian families (glmmTMB, brms), structured random
  effects (phylo, spatial, animal). Each gets the same structural
  symbolic story.
- **Make model comparison structural.** `compare_symbolic(a, b)` shows
  the structural difference between two fits — not just a number, but a
  story about what they say differently.
- **Bring auto-narration responsibly.** A `methods_text(sym)` surface
  that produces a methods-section paragraph in the same
  honest-status-and-citation style. Always opt-in, never the default.

## How we work

The team perspectives (from drmTMB’s convention, adopted as ours):
**Ada** (orchestration), **Boole** (API), **Gauss** (numerics),
**Noether** (math-code consistency), **Darwin** (biological reading),
**Fisher** (inference), **Pat** (reader / tutorial), **Jason**
(related-package landscape), **Curie** (tests), **Emmy** (S3
architecture), **Grace** (pkgdown / CI), **Rose** (audit, repeated
mistakes, after-task feedback).

Each slice goes through these lenses, not all at once but with the ones
whose stakes are highest. After-task notes record what each role saw and
would flag.

## Stopping conditions

When something tempts us off-mission, return here. If the proposed work
doesn’t serve a biologist auditing a model, doesn’t fit one of the core
principles, or weakens the capability gate, push back.

The vision is a service, not a constraint. It exists to make the hard
product calls easier when the immediate path is unclear.
