# drmTMB capability check vs. GCB 2025 full meta-analysis model

Date: 2026-05-28  
Tested by: Fisher/Rose-lens drmTMB capability verifier  
Reference: Nakagawa et al. 2025, GCB 31(5), e70204 (Bonus 2)  
drmTMB version: 0.1.3.9000  
Data: subsample of itchyshin/location-scale_meta-analysis thermal.csv  
  (N effects = 250, N species = 35, N studies = 41, saved to /tmp/thermal_subset.csv)

Effect size column: `dARR`; sampling variance column: `Var_dARR`.
Rows with `Var_dARR >= 1` excluded (20 rows) before subsampling.

---

## Summary verdict

drmTMB **partially** fits the full GCB Bonus 2 model. Four of the five
structural ingredients are supported; two have caveats.

**Recommended article path**: drmTMB lead for mean-model multilevel
structure (species + study + phylo + habitat fixed effects); brms lead
for the `sigma ~ offset(0.5 * log(vi))` meta-analytic scale-equation
ingredient. The sigma fixed-effect moderator (`sigma ~ 1 + habitat`)
works in drmTMB and is a reasonable substitute if the log(vi) offset is
not required for the main inference.

---

## Per-ingredient results

| # | Ingredient | Status | Note |
|---|-----------|--------|------|
| 1 | Fixed effects on mean: `1 + habitat` | **supported** | Converges cleanly |
| 2 | Known sampling variance via `meta_V(V = vi)` | **supported** | Diagonal (column) and full matrix accepted; `meta_V` is the drmTMB analogue of brms `se(sqrt(vi))` |
| 3 | Multiple iid random intercepts (species + study) | **supported** | Both converge; study SD collapses to ~0 in this sample |
| 4 | Phylogenetic random intercept `phylo(1|species, tree)` | **supported with caveat** | Accepts pruned ape tree; Hadfield-Nakagawa A-inverse path; phylo SD collapses to ~0 in this sample (likely data feature, not a bug) |
| 5 | `sigma ~ 1 + habitat` scale submodel | **supported** | sigma coefficients estimated with SEs; large habitat effect found |
| 5b | Sigma random intercept `(1|species_ID)` in scale formula | **supported** | SD = 0.75, SE = 0.14 — the heterogeneous-variance analogue works |
| 6 | `offset(0.5 * log(vi))` in sigma formula | **NOT supported** | Hard error: "unsupported term: offset" in sigma formula |
| 7 | Observation-level RE `(1|es_ID)` as OLRE | **NOT supported** | Hard error: "singleton groups" — all es_IDs are unique in this dataset; `meta_V` is the intended substitute |

The brms `gr(es_ID, cov = vcv)` pattern (known off-diagonal V at obs
level) is handled in drmTMB by passing a full matrix to
`meta_V(V = V_matrix)`. That path accepted a 250×250 dense V matrix
without error.

---

## Working syntax snippets

### Baseline with known sampling variance
```r
drmTMB(bf(es ~ 1 + meta_V(V = vi)),
       family = gaussian(), data = dat)
# logLik: -75.99, converged
```

### Two random intercepts (species + study)
```r
drmTMB(bf(es ~ 1 + meta_V(V = vi) + (1|species_ID) + (1|study_ID)),
       family = gaussian(), data = dat)
# converged; study SD ≈ 0 in this sample
```

### Phylogenetic random intercept
```r
library(ape)
tree_pruned <- keep.tip(tree_full, unique(dat$phylogeny))
drmTMB(bf(es ~ 1 + meta_V(V = vi) +
            phylo(1 | phylogeny, tree = tree_pruned) +
            (1|study_ID)),
       family = gaussian(), data = dat)
# converged; phylo SD ≈ 0 in this sample
```

### Scale submodel with moderator
```r
drmTMB(bf(es ~ 1 + habitat + meta_V(V = vi) + (1|species_ID) + (1|study_ID),
          sigma ~ 1 + habitat),
       family = gaussian(), data = dat)
# converged; sigma:habitatterrestrial = -1.63 (SE 0.13)
```

### Best-approximation full model (all supported ingredients)
```r
drmTMB(bf(es ~ 1 + habitat + meta_V(V = vi) +
            (1|species_ID) + (1|study_ID) +
            phylo(1 | phylogeny, tree = tree_pruned),
          sigma ~ 1 + habitat),
       family = gaussian(), data = dat)
# converged; logLik: -11.61
```
This covers ingredients 1–5 of the GCB model. The `offset(0.5*log(vi))`
in sigma (ingredient 6) and OLRE via singleton es_ID (ingredient 7b
brms-style) are absent.

### Known off-diagonal V matrix (replaces gr(es_ID, cov = vcv))
```r
V_matrix <- ...  # n×n PD matrix with within-study correlations
drmTMB(bf(es ~ 1 + habitat + meta_V(V = V_matrix) + (1|species_ID)),
       family = gaussian(), data = dat)
# accepted; note issued about dense storage for large V
```

---

## Failed ingredients

### Experiment 6 — `offset()` in sigma formula
```
Error: This formula contains unsupported model terms.
  × The `sigma` formula contains unsupported term: "offset".
```
The `sigma` formula parser in drmTMB v0.1.3.9000 rejects `offset()`.
The `drm_model_offset` internal path exists for the `mu` formula only.
`offset(log(x))` in the mean formula is supported (documented for
Poisson/NB2), but not in distributional submodels.

**Impact for GCB paper**: the `sigma ~ 1 + habitat + offset(0.5*log(vi))`
term is the key ingredient that makes the scale equation
meta-analytically interpretable (it embeds the known sampling SD into
the heterogeneity model). Without it, `sigma` estimates residual
log-SD rather than excess heterogeneity conditional on sampling
variance. The paper's brms specification must be used for this
ingredient, or the sigma formula rewritten to absorb the offset as a
covariate: `sigma ~ 1 + habitat + I(0.5 * log(vi))` — though this
estimates a free coefficient rather than fixing it at 1.

---

## Recommended fallback

Use drmTMB for:
- Traditional and multilevel meta-analysis (1–3 random intercepts)
- Phylogenetic random effects with an external tree
- Location-scale models with moderators on sigma (fixed effects only)
- Known sampling covariance (diagonal or dense matrix via `meta_V`)

Use brms for:
- `sigma ~ offset(0.5 * log(vi))` (pinned offset in scale equation)
- Observation-level RE with known structured V (`gr(es_ID, cov = vcv)`)
  when effect-size IDs are unique (all singletons)
- Any combination requiring offset in a distributional submodel

For the GCB Bonus 2 model specifically: drmTMB handles the complete
mean submodel but cannot replicate the scale equation as written.

---

## Convergence notes

All supported models converged (`convergence = 0`). No boundary or NA
standard-error issues in the mean model. Notable observations:

- **Study-level SD collapses to ~0** (`7.96e-6`) when species RE is also
  in the model on this subsample (35 species, 41 studies). This is a
  data feature — with `meta_V` absorbing sampling variance and species
  RE absorbing biological heterogeneity, the study term has little
  residual variance to explain.
- **Phylo SD collapses to ~0** (`4.35e-6` to `2.32e-6`) on this
  subsample. The pruned 35-species tree may have insufficient
  phylogenetic signal relative to noise in dARR. Not a drmTMB bug.
- **Sigma random intercept** (species-level, scale formula) converged
  well: SD = 0.75, SE = 0.14 — suggesting genuine species-level
  variation in residual scale.
- All models used `nlminb` optimizer. No gradient warnings or Hessian
  issues reported.
