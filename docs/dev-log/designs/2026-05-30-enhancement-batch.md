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
