# V3 Noether-lens audit — symbolizer-gllvm.html (v0.21.6-redo)

Audit date: 2026-05-28
Auditor: V3 Noether-lens (math correctness)
Target: http://localhost:8767/articles/symbolizer-gllvm.html
Slice: v0.21.6-redo

## Summary verdict

NEEDS FIXES

Two equations in Widget 2 Tabs 1 and 2 are copied verbatim from Widget 1, rendering the wrong conditional variance and omitting the within-tier term. All other math checks pass.

## Math check by focus area (1–10)

**1. §3 univariate R formula: PASS**

Article (idx 9): `R = sigma^2_u / (sigma^2_u + sigma^2_e)`. lme4 output shows sigma^2_u = 1.0103895, sigma^2_e = 0.3356346; computed R = 1.0103895 / (1.0103895 + 0.3356346) = 0.751. Article reports 0.751. Matches Nakagawa & Schielzeth 2010 Eq 4.

**2. §4 parameter counting: PASS**

Formula `T(d+1) - d(d-1)/2` (idx 25):
- T=5, d=2: 5×3 − 2×1/2 = 15 − 1 = **14**. Full: T(T+1)/2 = 15. Article shows `15→14`. Correct.
- T=10, d=2: 10×3 − 1 = **29**. Full: 55. Article shows `55→29`. Correct.
- Two tiers: 29×2 = **58**. Full: 110. Article shows `110→58`. Correct.

**3. §5 long-form conditional variance (Widget 2): PASS (in §5)**

Section 5 (idx 42) correctly writes the conditional variance as `psi_{W,t}^2 + (Lambda_W Lambda_W^T)_{tt}`, not `sigma_eps^2`. This is correct per spec §4.1.

However — see B-V3-1 below — Widget 2 Tab 1 does NOT use this equation.

**4. §5 wide-form mean and Sigma_W: PASS (in §5)**

Section 5 (idx 45/172): mean = `mu + Lambda_B z_{B,i}` (per-obs form); full matrix mean = `1_n mu^T + Z_B Lambda_B^T + Z_W Lambda_W^T` (idx 172). Conditional covariance = `Sigma_W` (not `sigma_eps^2 I_T`); decomposition `Sigma_W = Lambda_W Lambda_W^T + Psi_W` explicit (idx 46). Correct.

However — see B-V3-1 — Widget 2 Tab 2 does NOT use this equation.

**5. §6 Widget 1 implied-cov closure: PASS**

Numerical closure `Sigma_B = Lambda_B Lambda_B^T + Psi_B^2` checked element-wise. Lambda_B (5×2) = [[0.817,0],[0.268,−0.295],[0.852,0.507],[0.154,−0.0449],[0.754,0.398]]; Psi_B^2 diag = [0.358, 3.2e-8, 0.249, 0.142, 3.9e-16]. Max discrepancy vs article's stated Sigma_B: **0.0045** (within 2 d.p. rounding of displayed values). No element exceeds 0.01 tolerance.

**6. §7 Widget 2 Sigma_W closure: PASS**

Lambda_W (5×1) = [0.564, 0.328, 0.429, 0.296, 0.403]; Psi_W^2 diag = [0.0172, 0.0366, 0.0571, 0.0326, 0.0365]. Computed `Lambda_W Lambda_W^T + diag(Psi_W^2)` vs article Sigma_W. Max discrepancy: **0.0007**. PASS.

Also checked Widget 2 Sigma_B closure with its own Lambda_B (different from Widget 1): max discrepancy **0.0009**. PASS.

**7. §7 Tab 3 per-trait repeatability: PASS**

Using Widget 2 Sigma_B and Sigma_W diagonals, computed R_t = (Sigma_B)_tt / [(Sigma_B)_tt + (Sigma_W)_tt]:

| Trait | (Sigma_B)_tt | (Sigma_W)_tt | Computed R_t | Article R_t | Diff |
|-------|-------------|-------------|-------------|------------|------|
| t1    | 0.992       | 0.335       | 0.7476      | 0.747      | 0.0006 |
| t2    | 0.179       | 0.144       | 0.5542      | 0.555      | 0.0008 |
| t3    | 1.23        | 0.241       | 0.8362      | 0.836      | 0.0002 |
| t4    | 0.196       | 0.120       | 0.6203      | 0.620      | 0.0003 |
| t5    | 0.726       | 0.199       | 0.7849      | 0.785      | 0.0001 |

All within rounding. PASS.

**8. §8.1 communality formula: PASS**

Article (idx 184): `c^2_{g,t} = sum_k lambda_{g,tk}^2 / (Sigma_g)_{tt}`, `psi*_{g,t} = (Psi_g)_{tt} / (Sigma_g)_{tt}`, `c^2 + psi* = 1`. Algebraic closure verified: numerator + denominator = `(sum_k lambda^2 + Psi_tt) / Sigma_tt = Sigma_tt / Sigma_tt = 1`. Numerical check on Widget 1 trait 1: c^2 = 0.6675/1.0255 = 0.6509, psi* = 0.358/1.0255 = 0.3491, sum = 1.0000. PASS.

**9. §8.2 phenotypic-correlation decomposition: PASS**

Article (idx 196): `r_{P,tm} = r_{B,tm} sqrt(R_t R_m) + r_{W,tm} sqrt((1-R_t)(1-R_m))`. Square roots present. Between term uses R_t (not 1-R_t). Within term uses (1-R_t). Signs and weights correct per Dingemanse & Dochtermann 2013. PASS.

**10. sigma_eps auto-suppression: PASS (claim consistent with data)**

Article (§9) states gllvmTMB auto-suppresses `sigma_eps^2` to ~10^{-3} when `unique(0 + trait | obs)` is present. Widget 2 Tab 3 residuals are ~1e-6 in absolute value (e.g. -1.62e-06 vs Widget 1's 0.188 for the same observation). The ratio is ~8.6e-6, consistent with sigma_eps being suppressed to a near-zero floor. The claim "~10^{-3}" refers to sigma_eps^2 (variance), implying sigma_eps (SD) ~ 0.032; residuals of ~1e-6 are even smaller, suggesting the actual suppression floor may be below 10^{-3} for the variance. The article's claim is directionally correct and not misleading. PASS.

## Bugs found

**B-V3-1** (BLOCKER): Widget 2 Tab 1 and Tab 2 equations are identical to Widget 1 and wrong for the two-tier model.

- **Tab 1 (Index form)** — Widget 2 (LaTeX annotation idx 125) is byte-for-byte identical to Widget 1 (idx 77). Both show `y_{ij} | mu, Lambda_B, z_{B,i}, sigma_eps ~ Normal(mu + Lambda_B z_{B,i}, sigma_eps^2)`. Missing: `(Lambda_W z_{W,ij})_t` term in the mean; the conditional variance should be `psi_{W,t}^2 + (Lambda_W Lambda_W^T)_{tt}`, not `sigma_eps^2`. The "What changes between Widget 1 and Widget 2" callout (§7) correctly describes what *should* be there; the rendered equations contradict it.

- **Tab 2 (Matrix form)** — Widget 2 (idx 142) is byte-for-byte identical to Widget 1 (idx 94). Both show `y_{ij} | ... ~ MN(1_n mu^T + Z_B Lambda_B^T, sigma_eps^2 I_n, I_T)`. Missing: `Z_W Lambda_W^T` in the mean; the row-level covariance argument should be `Sigma_W = Lambda_W Lambda_W^T + Psi_W`, not `sigma_eps^2 I_T`. Section 5 (idx 45, 172) gives the correct two-tier wide form; the renderer is not using it for Widget 2.

The implied-covariance block in Tab 3 is correct (Sigma_W and R_t values close correctly). The defect is in the per-tab rendered equations only.

**No other math defects found.**
