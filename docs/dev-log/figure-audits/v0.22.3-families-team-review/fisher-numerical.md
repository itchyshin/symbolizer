# Fisher — symbolizer-families.html (v0.22.3)

Fits from vignette chunks (`set.seed(1); n=100`), not test helper
(`seed=20260524L; n=80L`). HTML dims (`R^100`) match. Tolerance 5e-4 for
3-sf cells, 1e-9 for integers. Tabs 1, 2 carry no fitted numbers — all
extraction is on Tab 3.

## Lognormal (Tab 3)

| Symbol | Displayed | Computed | Pass |
|---|---:|---:|:--:|
| β̂_0, β̂_1, γ̂_0 | 2.02, −0.0136, −0.764 | 2.01795, −0.01356, −0.76434 | OK |
| x_1, log y_1 | 0.409, 1.56 | 0.40940, 1.56392 | OK |
| μ̂_1 (log scale), ε̂_1^(log) | 2.01, −0.448 | 2.01239, −0.44848 | OK |
| σ̂_1 = exp γ̂_0 | 0.466 | 0.46564 | OK |
| y, X col2, σ, γ stacks (head+tail) | | all cells match to <5e-4 | OK |
| ε̂ stack head (2.77, 5.95, 2, 10.7, 4.23), tail (4.02, 3.48) | | y − (β̂_0+β̂_1 x) = (2.7651, 5.9452, 1.9982, 10.6800, 4.2289; 4.0153, 3.4823) | OK as raw `y − Xβ̂` |

**Closure.** Worked row: 2.02 + (−0.0136)·0.409 + (−0.448) = 1.566 ≈ log y_1 = 1.564. Closes on log scale. Stacked block displays `y = Xβ̂ + ε̂` with y on the raw scale. i=1: 2.018 + 2.765 = 4.783 ≈ y_1 4.778 — closes only because ε̂ here is raw `y − Xβ̂`. But the worked row above defines `ε̂_1^(log) = −0.448`. Same symbol at two scales (−0.448 vs 2.77; factor ~6). **BLOCKER: ε̂ scale switch without label.**

## Beta (Tab 3)

| Symbol | Displayed | Computed | Pass |
|---|---:|---:|:--:|
| β̂_0, β̂_1, γ̂_0 | −0.824, −0.0874, −1.04 | −0.82450, −0.08743, −1.04224 | OK |
| x_1, y_1 | 1.43, 0.175 | 1.43228, 0.17547 | OK |
| η̂_1 = β̂_0+β̂_1 x_1, μ̂_1 = plogis(η̂_1) | −0.95, 0.279 | −0.94972, 0.27894 | OK |
| σ̂_1 = exp γ̂_0 | 0.353 | 0.35266 | OK |
| Worked-row RHS −0.824 + (−0.0874)·1.43 | −0.95 | −0.94898 | OK |
| y, X col2, σ, γ stacks (head+tail) | | all cells match to <5e-4 | OK |
| ε̂ stack head (−0.103, 0.00726, −0.163, 0.0448, −0.163), tail (−0.134, −0.0957) | | y − plogis(Xβ̂) = (−0.10347, 0.00726, −0.16307, 0.04483, −0.16312; −0.13379, −0.09568) | OK as `y − μ̂_resp` |

**Closure.** `y = Xβ̂ + ε̂` at i=1: −0.94972 + (−0.10347) = **−1.053 ≠ 0.175**. What closes: `y = plogis(Xβ̂) + ε̂` → 0.279 + (−0.103) = 0.176. `Xβ̂` is logit-scale; `ε̂`, `y` response-scale. Caption "Middle: `Xβ̂ = μ̂`" equates scales. **BLOCKER.**

## Poisson (Tab 3)

| Symbol | Displayed | Computed | Pass |
|---|---:|---:|:--:|
| β̂_0, β̂_1 | 0.955, −0.0438 | 0.95546, −0.04383 | OK |
| x_1, y_1 | 0.45, 1 | 0.45019, 1 | OK |
| η̂_1, μ̂_1 = exp(η̂_1) | 0.936, 2.55 | 0.93573, 2.54907 | OK |
| Worked-row RHS 0.955 + (−0.0438)·0.45 | 0.936 | 0.93529 | OK |
| y stack (1,1,2,3,1,…,0,5), X col2 stacks (head+tail) | | all cells match | OK |
| ε̂ stack head (−1.55, −1.6, −0.636, 0.292, −1.78), tail (−2.62, 2.51) | | y − exp(Xβ̂) = (−1.5491, −1.6020, −0.6364, 0.2920, −1.7750; −2.6189, 2.5139) | OK as `y − μ_resp` |

**Closure (maintainer's case confirmed).** `y = Xβ̂ + ε̂` at i=1: 0.93573 + (−1.54907) = **−0.6134 ≠ 1**. What closes: `y = exp(Xβ̂) + ε̂` → 2.549 + (−1.549) = 1.000. `Xβ̂` log scale, `ε̂`/`y` response scale. **BLOCKER.**

## Cross-widget mislabels

1. `y = Xβ̂ + ε̂` is numerically false for Beta and Poisson (off by the link) and self-contradictory for Lognormal (worked-row ε̂ at log scale; stacked ε̂ at raw scale).
2. Caption `Xβ̂ = μ̂` (Beta, Poisson) equates link-scale and response-scale vectors — false.
3. Displayed ε̂ is raw `y_resp − μ̂_resp`. Not Pearson / deviance / quantile; no variance scaling; no fit-diagnostic value for Beta or Poisson. Widget never names it.
4. No random effects; `Zû` correctly absent.

## Numerical diagnostics the widget could surface

All computable from values the widget already prints; suggested as a `Fit check` row under Tab 3.

| Family | Diagnostic | Value | Verdict |
|---|---|---:|---|
| Poisson | Pearson r_1 = (y−μ̂)/√μ̂ | −0.970 | OK |
| Poisson | Dispersion mean((y−μ̂)²/μ̂) | 1.30 | mild overdisp → consider nbinom2 |
| Poisson | μ̂ range | [2.33, 2.95] | sensible |
| Beta | Shape (a=μφ, b=(1−μ)φ) at i=1 | (0.098, 0.254) | **both < 1 → U-shaped Beta**; flag |
| Beta | Pearson r_1, var μ̂(1−μ̂)/(φ̂+1) | −0.268 | small |
| Beta | μ̂ range | [0.261, 0.349] | inside (0,1) |
| Lognormal | E[y_1] = exp(μ̂_1+σ̂²/2) | 8.34 vs y_1=4.78 | log-scale μ̂ is **not** the prediction of y |
| Lognormal | (log y_1−μ̂_1)/σ̂ | −0.963 | within ±2 |
| All | Closure line `Xβ̂ ≈ link(μ̂)` at i=1 | per above | would expose the link mismatch |

## Known residuals (not checked)

Cross-browser MathML rendering (Florence). Tab focus / ARIA / contrast / screen-reader text beyond the audited numbers. PDF figures (out of scope). Whether ε̂ for lognormal should be log or raw by package policy (Noether). pkgdown rebuild (forbidden). Estimate stability under reseed.
