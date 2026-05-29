# V3 Noether-lens audit — symbolizer-meta-analysis §4 (v0.22.1)
Date: 2026-05-28
Slice: v0.22.1
Target: http://localhost:8767/articles/symbolizer-meta-analysis.html

## Verdict
NEEDS FIXES

Two bugs found (one blocker, one near-boundary convergence flag). The §4.1 prose
math is correct. The widget equation is not — the phylogenetic random effect
`u_phylo` is silently dropped by the extractor.

---

## Math checks (1–5)

### 1. §4.1 hierarchical form: PASS

Rendered equation (annotation 51, 52 from live page):

```
y_{kt} = β_0 + β_1 x_{kt} + u_{p,s(k)} + u_{study,k} + ε_{kt}
u_{p,s} ~ N(0, σ_p² A),  u_{study,k} ~ N(0, σ_study²),  ε_{kt} ~ N(0, v_{kt})
```

- Index `s(k)` (species of study k): correct and consistent with the subscript
  convention used throughout.
- `u_p ~ N(0, σ_p² A)`: `A` is the phylogenetic correlation matrix (T × T,
  one row/column per species tip). Correct.
- `u_study ~ N(0, σ_study²)`: scalar variance — correct, independent per study.
- `ε ~ N(0, v_{kt})`: v_{kt} is the KNOWN per-effect sampling variance. Correct.

### 2. §4.1 marginal form: PASS

Rendered equation (annotation 54):

```
Var(y_{kt}) = v_{kt} + σ_study² + σ_p² A_{s(k),s(k)}
```

Element-wise: the `(s(k), s(k))` diagonal entry of `σ_p² A` is the marginal
phylogenetic variance for species s(k). Correct — off-diagonal terms integrate
out under the marginal of a single observation. Matches the design doc §4
canonical formula.

### 3. §4.3 drmTMB fit converges + reasonable variance components: FAIL

Fit runs without optimizer error (convergence = 0, gradient max = 2.89e-08,
logLik = −77.67) but both random-effect standard deviations collapse to boundary:

```
sd_phylo   (σ_p)      = 3.4e-08   [log = −17.20]
sd_mu_re   (σ_study)  = 7.8e-06   [log = −11.76]
```

Both are effectively zero — the fit is degenerate. The NaN warning
`In sqrt(diag(cov)) : NaNs produced` during `sdr` construction confirms the
Hessian is singular at this point. There are no negative values or Inf, so
the optimizer converged to a boundary of the parameter space, not a genuine
interior maximum. The `vi` range is `[0, 9.17]` — a vi = 0 entry is suspicious
and may be a data artefact causing numerical issues. The fit should not be
presented as-is; the variance components are not "reasonable" in the sense
required by the article.

### 4. §4.4 brms ↔ drmTMB conceptual equivalence: PASS (conceptually)

brms `se(sqrt(vi))` and drmTMB `meta_V(V = vi)` both fix the per-observation
residual variance to the known `v_k`, removing it from the likelihood's
estimated scale. Both then add hierarchical random intercepts on top. The
marginal distributions are identical under the same parameterisation. The
design doc §11 confirms this equivalence explicitly. Numerical comparison is
deferred (brms fit is cached/not run live), but there is no structural
difference in the math.

### 5. §4.5 metafor V + R = list(phylogeny = A): PASS

The `rma.mv` call uses:
- `V = Var_dARR` — per-effect known sampling variance (replaces `vi`).
- `random = list(~ 1 | phylogeny, ~ 1 | study_ID)` — two random-intercept tiers.
- `R = list(phylogeny = A_phylo)` — tells metafor that the `phylogeny`
  grouping's covariance is structured by `A`. The two `$sigma2` entries
  correspond to σ_p² and σ_study² respectively.

This is mathematically the same model as §4.1. The `R` argument scales the
random-effect variance matrix for the `phylogeny` level by `A`, exactly
encoding `u_p ~ N(0, σ_p² A)`. Correct.

---

## drmTMB API conformance

- `meta_V` inside formula: **Y** (vignette line 335, helper line 39)
- `phylo` inside formula: **Y** (vignette line 336, helper line 40)
- `sigma ~ 1` second entry present: **Y** (vignette line 338, helper line 43)
- Unqualified names inside formula: **Y** — `bf`, `meta_V`, `phylo` are all
  bound to local names before use (vignette lines 328–330, helper lines 33–35)

---

## Bugs found

**Bug 1 (BLOCKER) — Extractor drops phylo() random effect from symbolized output.**

`symbolize(fit_drm_phylo)$random_effects` contains only 1 row (`study_ID`);
the `phylo(1 | phylogeny, tree = tree)` term is absent. Consequently the
widget's Tab 1 indexed equation (annotation 60) reads:

```
μ_i = β_0 + β_1[habitat=terrestrial] + u_{study_ID(i)}
```

and Tab 2 matrix equation (annotation 82) also omits the phylogenetic term.
The Tab 3 worked-example equation (annotation 107) similarly shows only
`u_{study_ID}`. The prose note in Tab 3 mentions `σ_p² A_{kk}` as a
static string, but the symbolizer-generated equation is wrong.
File responsible: `R/symbolize-drmtmb.R` — the extractor must recognise
`phylo(...)` as a random-effect term and add it to `random_effects` with
`type = "phylogenetic"`.

**Bug 2 (WARNING) — Both variance components at boundary (σ_p ≈ σ_study ≈ 0).**

The drmTMB fit converges to a degenerate boundary solution. The most likely
cause is one or more `vi = 0` values in `thermal_subset.csv`
(range confirmed: `[0, 9.17]`). A zero sampling variance is mathematically
inadmissible in the `meta_V` likelihood. Pre-filter or add a small jitter
(`vi = pmax(vi, 1e-6)`) before fitting, or flag it as a data-quality check.
This is a warning, not a hard blocker for the math audit, but the article
must not display σ_p = 0 as a result.
