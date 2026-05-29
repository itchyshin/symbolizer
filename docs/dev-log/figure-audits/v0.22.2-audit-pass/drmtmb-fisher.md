# Fisher-pass numerical audit — symbolizer-drmtmb article, `sym_re` three-views widget

Auditor: Claude Opus 4.7 (1M ctx) · 2026-05-28
Surface: `docs/articles/symbolizer-drmtmb.html` §5 "See the three views of this RE fit"
Fit: `fit_re = drmTMB(body_mass ~ temperature + (1|site), sigma ~ temperature, gaussian, n=120, 6 sites)`

## Verdict

**NEEDS FIXES** — the matrix shape (Z_g, tiers, links, β̂, û BLUP) is correct, but the
Tab-3 worked-row decomposition and the stacked-block residual vector both compute the
residual against `Xβ` only and ignore the `Zu` contribution. The numerics displayed
contradict the widget's own caption ("ε̂ = w − μ̂ where μ̂ = Xβ̂ + Zû").

## Per-value table (3-sig-fig comparison)

| Symbol            | Displayed | Actual         | Diff       | Pass |
| ----------------- | --------- | -------------- | ---------- | ---- |
| y₁                | 40.2      | 40.2016        | <5e-3      | yes  |
| T₁ (X[1,2])       | 24.7      | 24.6785        | <5e-3      | yes  |
| β̂₀               | 29        | 28.9520        | <5e-2      | yes  |
| β̂₁               | 0.458     | 0.45763        | <5e-4      | yes  |
| û_site,a          | 0.482     | 0.48162        | <5e-4      | yes  |
| û_site,b          | 1.47      | 1.47356        | <5e-3      | yes  |
| û_site,c          | -0.889    | -0.88930       | <5e-4      | yes  |
| û_site,d          | -0.823    | -0.82289       | <5e-4      | yes  |
| û_site,e          | -0.45     | -0.45005       | <5e-3      | yes  |
| û_site,f          | 0.207     | 0.20706        | <5e-4      | yes  |
| γ̂₀               | 0.578     | 0.57773        | <5e-4      | yes  |
| γ̂₁               | 0.0422    | 0.042233       | <5e-4      | yes  |
| log σ̂₁           | 1.62      | 1.61997        | <5e-3      | yes  |
| σ̂₁               | 5.05      | 5.05293        | <5e-3      | yes  |
| **μ̂₁ (predicted)** | **40.2** | **40.7273** = Xβ+Zu | **0.5** | **NO** (rounds Xβ-only = 40.246 → 40.2) |
| **ε̂₁ (residual)**  | **-0.0441** | **-0.5258** = y-(Xβ+Zu) | **0.48** | **NO** (matches y-Xβ = -0.0441) |
| ε̂ stacked head 5  | -0.0441, 3.84, 5.78, -2.59, -0.559 | -0.5258, 2.3676, 6.6735, -1.7684, -0.1092 | up to 0.55 | **NO** (matches y-Xβ exactly) |
| ε̂ stacked tail 2  | 0.36, -1.39 | 0.8101, -1.5967 | up to 0.45 | **NO** (matches y-Xβ exactly) |
| w stacked         | 40.2, 41.4, 44.2, 33.8, 38, ⋮, 34.8, 36.2 | 40.20, 41.42, 44.16, 33.84, 38.04, ⋮, 34.78, 36.19 | <5e-2 | yes |
| X col2 stacked    | 24.7, 18.9, 20.6, 16.3, 21.1, ⋮, 11.9, 18.9 | 24.68, 18.85, 20.60, 16.34, 21.08, ⋮, 11.95, 18.86 | <5e-2 | yes |

## Z_g shape check

- dim(Z_g) = **120 × 6** — matches c(n, n_distinct(site)).
- All row sums == 1: **TRUE** (table(rowSums) = {1: 120}).
- All values ∈ {0, 1}: **TRUE** (proper one-hot indicator, v0.22.2 factor-coercion fix verified).
- Column ordering `a,b,c,d,e,f` matches site factor levels.
- Row 1 → col 1 ('a') matches `dat_re$site[1] = "a"`. ✓
- Tail rows 119, 120 → cols 5, 6 ('e', 'f') match site factor. ✓

## Closure check (numeric, max abs diff)

```
max |y − (Xβ + Zu) − e$e|           = 0          ← e$e stores correct residual
max |Xβ − e$mu_hat|                 = 0          ← BUG: mu_hat lacks Zu
max |(Xβ + Zu) − e$mu_hat|          = 1.4736     ← matches max|u|, confirms Zu drop
```

The contract `Xβ + Zu = μ̂` claimed in the widget caption FAILS internally:
`e$mu_hat = Xβ` (no random-effect contribution). The displayed Tab-3 numerics
inherit this bug: μ̂_displayed and ε̂_displayed both omit Zu, which contradicts
the widget's own subscript "Xβ̂ + Zû = μ̂" caption.

## Tier-count verification

- `nrow(sym_re$random_effects)` = **1** (mu, site, (Intercept))
- `length(sym_re$expanded$u_per_tier)` = **1** (`site`)
- `length(sym_re$expanded$Z_per_tier)` = **1** (`site`)
- `tier_kind["site"]` = `"iid"`
- Widget shows **1** tier (`Z_site`, 120 × 6, û_site,6×1). **Match.** ✓

## Sigma submodel worked row

- Submodel link: **log** (correct: location-scale Gaussian).
- Displayed: `log σ̂₁ = 0.578 + 0.0422 × 24.7 = 1.62`, `σ̂₁ = exp(1.62) ≈ 5.05`.
- Actual: 0.57773 + 0.042233 × 24.6785 = 1.61997, exp = 5.05293. ✓
- Stacked σ̂ vector head/tail correct. ✓
- σ submodel does NOT involve random effects (correct — no `(1|site)` on sigma).

## Bugs found

1. **BLOCKER — `mu_hat` and `e` are computed inconsistently for RE fits.**
   `sym_re$expanded$mu_hat = Xβ` (no Zu), but `sym_re$expanded$e = y − (Xβ + Zu)`.
   These two together violate `e = y − μ̂`. The Tab-3 worked row displays
   `μ̂₁ = 40.2` (≈Xβ=40.246) and `ε̂₁ = -0.0441` (= y − Xβ, not y − (Xβ+Zu) = -0.526),
   so the widget effectively shows Xβ-only μ̂ and Xβ-only residual while still adding
   the +u term to the response equation. The caption claims `Xβ + Zu = μ̂`, which is
   then numerically falsified by the worked row.
2. **BLOCKER — stacked residual vector is wrong.** The ε̂ block in the matrix
   panel shows (-0.0441, 3.84, 5.78, -2.59, -0.559, ⋮, 0.36, -1.39) — these are
   `y − Xβ`, NOT `y − (Xβ + Zu)` which the internal `e$e` correctly stores
   (-0.526, 2.368, 6.674, -1.768, -0.109, ⋮, 0.810, -1.597). Renderer reads from
   the wrong source.
3. **Cosmetic — worked-row arithmetic.** `29 + 0.458 × 24.7 + 0.482 + (-0.0441)`
   sums to 40.75 (not 40.2). Rounded inputs reach 40.2016 only with full-precision
   coefficients. Acceptable rounding artifact but the displayed equation does not
   literally balance.

## Known Residuals (not verified)

- Did not re-render the article through pkgdown (hard-constraint: no build).
- Did not inspect rendered JS-tab behavior; relied on static HTML LaTeX annotation strings.
- Did not test other panels of three-views (Tab 1, Tab 2) — out of scope.
- Did not check assumption_table / equations / random_effects tibble printouts in §5
  prior to the widget — that is a separate widget audit.
- Did not check whether v0.22.2 NEWS documents intended `mu_hat` semantics for RE fits
  (read-only on NEWS).
- Did not verify the precise renderer source in `R/render-html-three-views.R` (or
  similar) — fix-localisation is left to the implementer.
- σ submodel does not couple to random effects in this widget; whether
  `σ ~ … + (1|g)` is correctly handled is untested here.
