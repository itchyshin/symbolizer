# Enhancement batch E1 / E3 / E4 — 2026-05-30

Post-audit feature backlog (the audit *defects* are already fixed in commits
`0cb1462`..`3a19dda`). Maintainer chose: do E1 + E3 + E4 now; **defer E2**
(drmTMB-phylo tip-BLUP extraction from the sparse-precision pipeline — a
separate deep slice; B2's `mu_hat - X*beta` fallback already closes the
arithmetic with an aggregate `u-hat`).

## E1 — gllvm implied-covariance: full chain `Λ → ΛΛᵀ + Ψ = Σ`

`R/render-three-views.R`, the gllvm implied-covariance block (today emits the
raw 5×2 loading `Λ`). Maintainer chose the **full chain**. For each tier
present (between `B`; within `W` when two-tier) render:

    Σ_B = Λ_B Λ_Bᵀ + Ψ_B

showing: `Λ_B` (loadings, T×d), the outer product `Λ_BΛ_Bᵀ` (T×T, rank-d
"shared syndrome" part), the diagonal `Ψ_B` (trait-specific uniquenesses),
and the sum `Σ_B` (T×T implied between-trait covariance). `ΛΛᵀ + Ψ` is
computed in R from the loadings + uniquenesses already carried in `expand()`.
Matrices render as KaTeX `\bmatrix`; T=5 fits, existing head/tail truncation
handles larger T. One pass over tiers so `Σ_W` gets identical treatment.

## E3 — P7 factor-contrast reading under an interaction

**Verify first.** Build a `y ~ x * sex` fit; read the `factor_contrast` row
of `parameter_interpretation()`. If it reads "average … differs by β" when β
is really the contrast at *interacting-var = 0* (not the marginal average),
fix: add an interaction-aware `factor_contrast` template row to
`inst/extdata/interpretation-templates.csv`; the interp builder selects it
when `extract_terms` flags the factor as participating in an interaction.
Wording: "difference when [other var] = 0; see `group_means` / `group_slopes`
for the marginal." If already correct → verified no-op.

## E4 — symbol-table polish + phantom-σ tails

(a) `symbol_table`: matrix symbols wrapped in `\mathbf{}`; `poly(x, 2)`
deparses to a clean token (not `body_size, 2_i`); `[var = level]` factor
labels escape underscores. (b) Probe mcmcglmm + sdmTMB **homoscedastic** fits
for the phantom location-scale σ rows (guard already applied to
lm/glm/lmer/glmmTMB); apply `constant_scale` if present — but **confirm
sdmTMB `phi` is not a legitimate σ row** before touching it.

## Discipline (all three)

TDD where there is a testable assertion (E3 reading, E4 symbol_table); then
implement → `devtools::test()` → reinstall → rebuild affected articles
(gllvm, factors) → KaTeX sweep → commit each as its own wave. Branch
`capability-remediation` stays unpushed (maintainer review gate).

## Outcome — 2026-05-30

- **E1 — DONE** (`7190140`). gllvm implied-covariance renders the full chain;
  the term under the `ΛΛᵀ` label is the T×T outer product (not the raw T×d
  loading), loadings shown separately. Test `test-implied-cov-outer-product.R`.
- **E3 — DONE** (`69cf000`). Interaction-aware `factor_contrast` reading; new
  `factor_contrast_interaction` template selected when the factor participates
  in an interaction (falls back to the plain reading otherwise). Test
  `test-factor-contrast-interaction.R`; factors article renders the corrected
  reading in 5 places.
- **E4(a) poly-deparse (B82) — DONE** (`9519320`). `classify_term()` takes a
  function-call transform's first top-level argument as the variable, so
  `poly(x, 2)` → variable `x` (no `x, 2` leak) and a supplied symbol is now
  honoured. Test `test-transform-first-arg.R`. Bonus finding: this also fixed
  a silent symbol-lookup miss for poly terms.
- **E4(b) phantom-σ — DEFERRED (blocked).** sdmTMB is **not installed** in this
  environment, so its `phi`-vs-σ question cannot be confirmed here (and the
  rule was "confirm sdmTMB phi is not a legit σ row *before* touching it" — so
  no change is the correct, honest action). MCMCglmm — **verified no-op**:
  `symbolize-mcmcglmm.R` already passes `constant_scale = TRUE` (lines 147,
  190), so a homoscedastic fit writes `\sigma`, not a phantom `\sigma_i`
  submodel. The lm/glm (`symbolize-base.R`), lmer/glmer (`symbolize-lme4.R`)
  and glmmTMB (`!has_sigma_sub`) guards are all confirmed present in source.
- **E4(a) `[var = level]` underscore-escaping — DONE.** Probe confirmed (not
  just hypothesised) that `as_latex()` / `equations()` rendered
  `[body_size = \mathrm{small}]` with a raw underscore for a snake_case factor
  (B81 family) — `build_latex()`'s factor_contrast branch interpolated
  `variable` and `contrast_level` raw. Both are now run through
  `escape_underscores_for_latex()`. `symbol_table` never surfaced this (it
  shows the escaped `symbol` column, not `latex_term`), but `as_latex` /
  `equations` did. Test `test-factor-contrast-escape.R` (relevel pins the snake
  level as the contrast, so the assertion is deterministic). No snapshot churn:
  every existing factor-contrast snapshot uses underscore-free factors/levels.
- **E4(a) `\mathbf{}` matrix-symbol wrap — NOT DONE** (honest scope): not
  verified as broken; no rendered surface found exercising it. Deferred.
- **Bonus — stale render snapshots refreshed** (`981186e`). The full suite
  surfaced 3 pre-existing snapshot failures (`render-latex`, `render-tables`):
  the σ-submodel design-matrix symbol became `\mathbf{X}_{\sigma}` in
  `79936ff` (audit wave 2) but those snapshots were never regenerated, so they
  had been red since then. Refreshed to the live notation; suite now green bar
  the known `Matrix::expand` gllvmtmb load-order flake.
