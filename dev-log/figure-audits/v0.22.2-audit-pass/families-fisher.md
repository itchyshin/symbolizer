# Fisher-pass audit — symbolizer-families.html (v0.22.2)

# Verdict: BLOCKER

All three non-Gaussian Tab 3 worked rows mix linear-predictor (η̂) and
response (y) scales additively, label η̂ as μ̂, and (Lognormal/Beta) call
the dispersion "predicted residual SD". The worked-row helper treats every
family as Gaussian-identity.

## Per-widget findings

### 1. Lognormal (`id="lognormal"`)

| Symbol | Displayed | Actual | Pass |
| --- | --- | --- | --- |
| y_1 | 4.78 | 4.7775 | OK |
| β̂_0, β̂_1 | 2.02, -0.0136 | 2.01795, -0.013562 | OK |
| x_1 | 0.409 | 0.40940 | OK |
| **μ̂_1 label** | 2.01 | η̂_1 = 2.0124 | **WRONG SCALE** |
| true μ̂_1 (response) | (missing) | exp(η̂_1) = 7.481 | **MISSING** |
| ε̂_1 | 2.77 | y_1 − η̂_1 = 2.765 | scale-mixed |
| log-scale residual | (missing) | log(y_1) − η̂_1 = −0.448 | **MISSING** |
| log σ̂_1 = γ̂_0; σ̂_1 | -0.764; 0.466 | -0.76434; 0.4658 | OK |

**Scale check:** Tab 1 declares `log(Y) ~ Normal(μ, σ²)`. Tab 3 labels
η̂ = 2.01 as μ̂_1 on the same line as raw y = 4.78 and reports ε̂ = y − η.
No back-transform; no log-scale residual.

### 2. Beta (`id="beta"`)

| Symbol | Displayed | Actual | Pass |
| --- | --- | --- | --- |
| y_1 | 0.175 | 0.17547 | OK |
| β̂_0, β̂_1 | -0.824, -0.0874 | -0.82450, -0.08743 | OK |
| x_1 | 1.43 | 1.4323 | OK |
| **μ̂_1 label** | -0.95 | η̂_1 = -0.9497 | **WRONG SCALE** |
| true μ̂_1 (∈ (0,1)) | (missing) | plogis(η̂_1) = 0.2789 | **MISSING** |
| ε̂_1 | 1.13 | y_1 − η̂_1 = 1.125 | scale-mixed |
| response residual | (missing) | y_1 − plogis(η̂_1) = −0.103 | **MISSING** |
| log σ̂_1 = γ̂_0; φ̂_1 | -1.04; 0.353 | -1.0422; 0.3527 | OK |

**Scale check:** μ̂_1 = -0.95 is impossible for a Beta mean (must be in
(0,1)). Tab 1 correctly emits `y ~ Beta(μσ, (1-μ)σ)`,
`logit(μ) = β_0 + β_1 x`; Tab 3 contradicts it with an additive ε on the
linear predictor. σ̂ is the **precision φ**, not an SD; "predicted
residual SD for observation 1" is doubly wrong.

### 3. Poisson (`id="poisson"`)

| Symbol | Displayed | Actual | Pass |
| --- | --- | --- | --- |
| y_1 | 1 | 1 | OK |
| β̂_0, β̂_1 | 0.955, -0.0438 | 0.95546, -0.04383 | OK |
| x_1 | 0.45 | 0.45019 | OK |
| **μ̂_1 label** | 0.936 | η̂_1 = 0.9357 | **WRONG SCALE** |
| true μ̂_1 (rate) | (missing) | exp(η̂_1) = 2.549 | **MISSING** |
| ε̂_1 (spurious) | 0.0643 | y_1 − η̂_1 = 0.0643 | **spurious** |

**Scale check:** Poisson has no residual on the linear predictor —
likelihood is `y ~ Poisson(μ)` with `var = mean`. Tab 1 correctly emits
`y_i | μ_i ~ Poisson(μ_i)`, `log(μ_i) = β_0 + β_1 x_i`. Tab 3 emits a
spurious additive ε̂, treats η̂ as μ̂, and omits `y_1 ~ Poisson(μ̂_1)`.

## Cross-widget patterns

**A — η/μ label confusion (all three).** Tab 3 labels `X[i,] %*% β̂` as
μ̂_i regardless of link. Verified via live fit: `sym$expanded$mu_hat[1]`
holds η̂ for all three families. Bug is upstream of the renderer —
`R/symbolize-drmtmb.R` stores the linear predictor in a slot named
`mu_hat` without back-transforming under a non-identity link.

**B — Additive ε on linear predictor (all three).** Tab 3 writes
`y_i = β̂_0 + β̂_1 x_i + ε̂_i` with ε̂_i = y_i − η̂_i. Legitimate for
Gaussian-identity; for these families it sums quantities on different scales.

**C — Tab 1 vs Tab 3 contradiction (all three).** Tab 1 emits the correct
distributional skeleton (log/logit links; Poisson with no σ). Tab 3
reverts to the Gaussian template.

**D — σ misnamed (Lognormal, Beta).** Lognormal σ̂ is on log(Y) but the
printed residuals are on y, so "predicted residual SD" mislabels what is
printed. For Beta, σ is precision φ, not an SD. Poisson correctly omits σ.

## Known Residuals

I did **not**:

- Re-render the vignette; I read the artifact under `docs/articles/`.
- Inspect renderer source (`R/render-*.R`) — bug-class identification
  suffices for BLOCKER.
- Audit the other widgets (Student-t, Gamma, beta-binomial, nbinom2,
  truncated-nbinom2, cumulative-logit). They almost certainly inherit
  Patterns A–C; flag for follow-up.
- Audit Tab 2 (Matrix); spot-checks show it uses `y = X β̂ + ε̂` and
  inherits the same scale-mixing.
- Cross-check σ̂ against `summary(fit)`; γ̂_0 was extracted via
  `fixef(fit, "sigma")` only.
- Reconcile `sym$expanded$e` for Poisson (live run:
  e[1] = −1.549 = y_1 − exp(η̂_1)). The slot holds a response-scale
  residual but the HTML uses `y − mu_hat`, so the slot is unused.
