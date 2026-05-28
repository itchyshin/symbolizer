# symbolizer-gllvm article — Nakagawa-style syndromes + integrated plasticity rewrite

**Date:** 2026-05-28
**Status:** draft, awaiting maintainer review
**Slice:** v0.21.6-redo (gllvmTMB widget rollout, supersedes the v0.21.5-redo "between-only vs with-uniqueness" pair)
**Pedagogical reference:** Nakagawa et al. (in prep), *Quantifying between- and within-individual correlations and the degree of trait integration*, GitHub TBD.

## 1. Why this rewrite

The previous slice (v0.21.5-redo) shipped two widgets that built up across a misleading axis: "between-only without Ψ_B" → "between-only with Ψ_B". The maintainer's correction: **the without-Ψ_B form is a toy, not a model behavioural ecologists fit**. The real build-up — and the one the Nakagawa et al. reference paper teaches — is across *tiers*:

- **Tier 1 — between-individual (behavioural syndromes):** `Σ_B = Λ_B Λ_B^T + Ψ_B`. Reduced-rank shared loadings plus per-trait between-individual uniquenesses.
- **Tier 2 — within-individual (integrated plasticity):** `Σ_W = Λ_W Λ_W^T + Ψ_W`. Same shape, inside-individual across occasions.

The article should mirror that progression and surface the same equations the paper uses.

## 2. Cross-package pedagogical principles (research summary)

From a survey of lavaan, psych, brms, gllvm, gllvmTMB, rstanarm:

| Borrowed principle | What it means for symbolizer's article |
|---|---|
| **Single anchor equation reused everywhere** (gllvmTMB) | `Σ = Λ Λ^T + Ψ` appears in §6, §7, §8; every later section refers back to it |
| **One dataset, watch the numbers migrate** (rstanarm baseball) | Same simulated 40 fish × 3 sessions × 5 traits dataset used in §3 univariate, §5 multivariate, §6 Widget 1, §7 Widget 2; the same y values reappear under different model specifications |
| **Named concept before symbol** (rstanarm) | "Behavioural syndrome" before Σ_B; "integrated plasticity" before Σ_W; "communality" before c²; "uniqueness" before ψ |
| **Defaults made explicit** (lavaan) | New §5.3 *"What gllvmTMB silently does"*: lower-triangular Λ identification; z standardised to N(0, I); auto-suppression of σ_ε when `unique(... \| obs)` is at the row level. |
| **Operator-by-operator micro-templates** (lavaan) | Brief sidebar in §6: `latent(0 + trait \| ID, d = d_B)` → Λ_B; `unique(0 + trait \| ID)` → Ψ_B; one bullet each |
| **Vignette-by-topic factoring** (brms) | This article is the GLLVM article; cross-link to phylogenetic + structural-dependence articles for related concepts |

## 3. Article structure

| §  | Topic | Pedagogical role | New / changed? |
|---|---|---|---|
| §1 | Biological question (syndromes + integrated plasticity) | Named-concept anchor | Updated: name *both* tiers up front |
| §2 | The data (40 × 3 × 5) | One-dataset anchor | Unchanged |
| §3 | Univariate motivation: `y_{ij} = μ + u_i + e_{ij}`, `R = σ²_u / (σ²_u + σ²_e)` | Anchor multilevel intuition; lme4 chunk | **NEW** |
| §4 | Why factor-analytic: `T(T+1)/2` parameter-counting argument (T=5 ⇒ 15 covariance params per tier; d=2 ⇒ 9); curse-of-dimensionality | Motivates Λ Λ^T + Ψ structure | **NEW** |
| §5 | The model in symbols (long form / wide form side-by-side) | Already present | Light edits to use Ψ-naming throughout |
| §6 | **Widget 1 — Syndromes**: `Σ_B = Λ_B Λ_B^T + Ψ_B` | Tier 1, fully wired to a real gllvmTMB fit | **REWRITTEN** (replaces previous Widget 1 + Widget 2 pair) |
| §7 | **Widget 2 — + Integrated plasticity**: adds `Σ_W = Λ_W Λ_W^T + Ψ_W` | Tier 2, fully wired to a real two-tier gllvmTMB fit | **REWRITTEN** |
| §8 | Reading biologically: communality c²_t + uniqueness ψ_t per tier; repeatability `R_t = (Σ_B)_tt / [(Σ_B)_tt + (Σ_W)_tt]`; phenotypic-correlation decomposition `r_{P,tm} = r_{B,tm} √(R_t R_m) + r_{W,tm} √((1−R_t)(1−R_m))` | Biological-reading payoff | **REWRITTEN** to use Nakagawa-paper indices |
| §9 | Identifiability gotchas: rotation, sign, lower-triangular Λ ; "Σ is invariant, Λ is not" | Already present | Light edits to use Ψ-naming |
| §10 | The glmmTMB equivalence | Side-by-side syntax table: gllvmTMB `latent()`/`unique()` ↔ glmmTMB `rr()`/`diag()`. Same math, different package. Cites the Nakagawa paper | **NEW** |
| §11 | What's available now / what's next | Updated capability matrix | Light edits |

## 4. Widget anatomy

Both widgets share the three-tab structure (Index / Matrix / Equations with data) and use **Ψ** for the diagonal uniqueness throughout.

### 4.1 Tab 1 — Index form (per-observation)

**Widget 1** (between-only):

```
y_{ijt} | μ_t, Λ_B, z_{B,i}, σ_ε ~ N(μ_t + (Λ_B z_{B,i})_t, σ²_ε)
η_{ij,t} = μ_t + Σ_{k=1..d_B} λ_{B,tk} z_{B,ik}
z_{B,ik} ~ N(0, 1)
Σ_{B,tt'} = Σ_{k=1..d_B} λ_{B,tk} λ_{B,t'k} + ψ_{B,t} δ_{tt'}
```

**Widget 2** (two-tier):

```
y_{ijt} | μ_t, Λ_B, z_{B,i}, Λ_W, z_{W,ij}, ψ_{W,t} ~
   N(μ_t + (Λ_B z_{B,i})_t + (Λ_W z_{W,ij})_t,  ψ_{W,t}^2 + (Λ_W Λ_W^T)_{tt})
η_{ij,t} = μ_t + Σ_{k=1..d_B} λ_{B,tk} z_{B,ik} + Σ_{ℓ=1..d_W} λ_{W,tℓ} z_{W,ijℓ}
z_{B,ik} ~ N(0, 1);   z_{W,ijℓ} ~ N(0, 1)
Σ_{B,tt'} = Σ_k λ_{B,tk} λ_{B,t'k} + ψ_{B,t} δ_{tt'}
Σ_{W,tt'} = Σ_ℓ λ_{W,tℓ} λ_{W,t'ℓ} + ψ_{W,t} δ_{tt'}
```

Note σ_ε is *not* present in Widget 2's conditional variance — gllvmTMB auto-suppresses it when `unique(0 + trait | obs)` is present (see §5.3). The within-individual per-trait residual lives in `ψ_{W,t}` and the cross-trait within-individual covariance in `Λ_W Λ_W^T`.

### 4.2 Tab 2 — Matrix form

**Widget 1**:

```
Y | μ, Λ_B, Z_B, σ_ε ~ MN_{n×T}(1_n μ^T + Z_B Λ_B^T, σ²_ε I_n, I_T)
η = 1_n μ^T + Z_B Λ_B^T
z_{B,i} ~ N_{d_B}(0, I_{d_B})
Σ_B = Λ_B Λ_B^T + Ψ_B
```

**Widget 2** adds:

```
Y | μ, Λ_B, Z_B, Λ_W, Z_W ~ MN_{n×T}(1_n μ^T + Z_B Λ_B^T + Z_W Λ_W^T, I_n, Σ_W)
η = 1_n μ^T + Z_B Λ_B^T + Z_W Λ_W^T  (where Z_W is observation-level, n × d_W)
Σ_W = Λ_W Λ_W^T + Ψ_W
```

The shared Gaussian dispersion σ_ε² drops out of the matrix form in Widget 2 — the row-level variance is now structured: each row's conditional covariance across traits is `Σ_W = Λ_W Λ_W^T + Ψ_W`, not `σ²_ε I_T`.

### 4.3 Tab 3 — Equations with data

For **both widgets**, three blocks (top to bottom):

1. **Per-observation worked row** — `y_{ij1} = β̂_0 trait1_1 + ... + (Λ_B z_{B,1})_{t(1)} + [(Λ_W z_{W,1})_{t(1)}] + ε̂_1`. (The `(Λ_W ...)` term is bracketed: present in Widget 2, absent in Widget 1.) Numerical row with `(with your numbers)` line and `μ̂` + `ε̂` underbrace labels, exactly as today.

2. **Stacked matrix equation** — `Y_{n×1} = X_{n×T} β̂_{T×1} + û_{n×1} + ε̂_{n×1}`. (Z dropped because identity-on-observations; this is already what the renderer does for gllvm fits today.) **NEW**: in Widget 2, the per-obs random effect `û` is decomposed into `û = û_B + û_W` — two columns side-by-side, summing to the same thing.

3. **NEW — Implied covariance block.** For Widget 1: a 5×5 numerical `Σ_B` matrix shown next to its decomposition `Λ_B Λ_B^T + Ψ_B`. For Widget 2: same for both `Σ_B` (top) and `Σ_W` (bottom), plus a **trait-specific repeatability row** computed from the matrices:

```
R = [R_1, R_2, R_3, R_4, R_5] = [0.62, 0.45, 0.58, 0.31, 0.40]
```

with caption: "Each R_t is the share of trait t's total variance that lives at the *between-individual* tier."

## 5. R syntax

**Package framing.** `gllvmTMB` (McGillycuddy et al. 2025) is purpose-built for generalised linear *latent-variable* models — its formula DSL (`latent()`, `unique()`), its accessors (`getLoadings()`, `extract_communality()`, `extract_correlations()`), and its wide/long dual interface are all designed around the reduced-rank latent-variable use case. `glmmTMB` (Brooks et al. 2017) is a general-purpose GLMM package; the `rr()` and `diag()` keywords it added in McGillycuddy et al. 2025 can fit the same math, but the package is not designed around GLLVMs — fitting them requires extra ceremony (`dispformula = ~0`, manual reconstruction of Σ from the variance components, no native communality / repeatability accessors). The article therefore leads with gllvmTMB throughout; the glmmTMB sidebar in §10 is a bridge for readers coming from the Nakagawa paper, not a peer alternative.

### 5.1 gllvmTMB (main path, used in the article body)

**Widget 1 fit:**

```r
fit_B <- gllvmTMB(
  value ~ 0 + trait +
          latent(0 + trait | individual, d = 2) +
          unique(0 + trait | individual),
  data = dat, family = gaussian(),
  trait = "trait", unit = "individual"
)
```

**Widget 2 fit:**

```r
fit_BW <- gllvmTMB(
  value ~ 0 + trait +
          latent(0 + trait | individual, d = 2) +
          unique(0 + trait | individual) +
          latent(0 + trait | obs, d = 1) +    # Λ_W: within-individual reduced rank
          unique(0 + trait | obs),             # Ψ_W: within-individual uniqueness
  data = dat, family = gaussian(),
  trait = "trait", unit = "individual",
  unit_obs = "obs", cluster = "session"
)
```

### 5.3 What gllvmTMB silently does (lavaan-style "defaults made explicit")

When you add `unique(0 + trait | obs)` at the row level — i.e., in the Widget 2 fit — gllvmTMB prints:

> ℹ Auto-suppressing `sigma_eps`: `unique(0 + trait | obs)` is at the per-row level, so it already absorbs the observation residual.
> • Fixed at 0.00111 (~1/1000 of sd(y)) to keep the Gaussian density well-defined; the row-level residual variance is fully captured by `unique()`.

So:

- **Widget 1** (only between-tier `latent()` + `unique()` at the unit level): σ_ε is a **free scalar** capturing the row-level (within-individual, across-session) residual variance, shared across traits.
- **Widget 2** (adds within-tier `latent()` + `unique()` at the obs level): σ_ε is **auto-suppressed** to ~10⁻³. The per-trait within-individual residual variance lives in `ψ_{W,t}` (the diagonal of `Ψ_W`); the cross-trait within-individual covariance lives in `Λ_W Λ_W^T`. **Together they form `Σ_W`, which fully replaces σ²_ε I_T as the row-level conditional covariance.**

This is the gllvmTMB analogue of glmmTMB's `dispformula = ~0` (which the Nakagawa paper uses). Both mechanisms exist for the same reason — to prevent double-counting of the row-level residual variance when the within-tier `unique()` term is present.

Other silent defaults this article will footnote where relevant:

- **Lower-triangular Λ identification**: gllvmTMB pins the upper triangle of Λ_B (and Λ_W) to zero so the likelihood has a unique solution. The lower-triangular Λ is *not* the interpretable form — Section 9 (Identifiability) treats varimax rotation explicitly.
- **z scores standardised**: `z_{B,i} ~ N(0, I_{d_B})` and `z_{W,ij} ~ N(0, I_{d_W})` — the latent-score scale is fixed; the loading-matrix scale carries the variance.
- **`0 + trait`**: suppresses the global intercept and forces a distinct mean per trait. Without this, the loadings and the global intercept are confounded.

**Open verification item (must check before implementation):** does gllvmTMB actually accept `latent(0 + trait | obs, d = d_W)` as the within-individual reduced-rank decomposition? If not, fall back to the glmmTMB syntax for Widget 2 with a "this section uses glmmTMB; the equivalence is in §10" callout. Tracked as **Slice prerequisite P1** (see §7).

### 5.2 glmmTMB bridge (§10 sidebar)

Readers who came in through the Nakagawa paper will recognise the glmmTMB syntax. The same math can be fit there with extra ceremony, but the package isn't built around the GLLVM use case:

```r
fit_BW_glmmTMB <- glmmTMB(
  value ~ 0 + trait +
          rr(0 + trait | individual, d = 2) +
          diag(0 + trait | individual) +
          rr(0 + trait | obs, d = 1) +
          diag(0 + trait | obs),
  data = dat, family = gaussian(),
  dispformula = ~0
)
```

§10 carries a small two-column table:

| gllvmTMB | glmmTMB | Math |
|---|---|---|
| `latent(0 + trait \| g, d = k)` | `rr(0 + trait \| g, d = k)` | Λ_g of rank k |
| `unique(0 + trait \| g)` | `diag(0 + trait \| g)` | Ψ_g diagonal |
| Auto-suppression of σ_ε on `unique(... \| obs)` | `dispformula = ~0` | both pin / suppress σ_ε so it doesn't double-count the within-tier `Ψ_W` |

## 6. Symbolizer-side implementation

### 6.1 Extractor (`R/symbolize-gllvmtmb.R`)

`glm_build_expanded()` already populates `Lambda_B`, `Sigma_B`, `Psi_B` (from this slice's prior work). Adds for Widget 2:

- `Lambda_W` (matrix `T × d_W`) — extracted from `fit$report$Lambda_W` when the within-tier `latent()` term is present
- `Z_W` (matrix `n × d_W`) — observation-level latent scores
- `Sigma_W` (matrix `T × T`) — `Lambda_W Lambda_W^T + diag(Psi_W)`
- `Psi_W` (vector length T) — from `fit$report$sd_W` (parallel to existing `Psi_B`)

Two helpers:

- `glm_has_within_unit(fit)` — returns `TRUE` if covstructs include `kind == "rr"` and `group != unit_col`
- `glm_compute_repeatability(Sigma_B, Sigma_W)` — returns the length-T vector `diag(Sigma_B) / (diag(Sigma_B) + diag(Sigma_W))`

The widget-shape slots populated this slice are unchanged: `X`, `beta`, `u = η − X β`, `Z_g = I_n`, `mu_hat`, `fitted`, `residuals`. The new Σ_B / Σ_W / Repeatability are *additional* slots for the new Tab 3 implied-covariance block.

### 6.2 Renderer (`R/render-three-views.R`)

New emitter `latex_implied_cov_block(name, Sigma, Lambda, Psi, fmt)`:

- emits a `\begin{aligned}` block: `Sigma_name = Lambda_name Lambda_name^T + Psi_name`
- followed by a numerical equality with the three matrices stacked: `Sigma_B (5×5) = Lambda_B (5×2) * Lambda_B^T (2×5) + diag(Psi_B) (5×5)`
- truncation uses the existing `latex_mat()` head/tail mechanism

Tab 3 changes (`three_views_eq_block_data`): after the existing stacked-matrix block, conditionally append:

- if `expanded$Sigma_B` non-NULL: implied-covariance block for B-tier
- if `expanded$Sigma_W` non-NULL: implied-covariance block for W-tier + repeatability row

### 6.3 CSV templates (`inst/extdata/*.csv`)

- `assumption-templates.csv`: add `Sigma_W` rows for the within-tier (parallel to existing `Sigma_B` rows); audit existing `Sigma_B` rows for Ψ-naming consistency
- `family-parameterizations.csv`: `gllvm_gaussian` and `gllvm_binomial` rows updated to mention both `Σ_B` and `Σ_W` decompositions
- `capabilities.csv`: add `gllvmTMB, gaussian, Sigma_W` and `gllvmTMB, gaussian, Psi_W` rows at "First slice" status

### 6.4 Tests (TDD discipline)

New test file `tests/testthat/test-symbolize-gllvmtmb-two-tier.R`:

1. `expanded$Lambda_W` populated for a fit with a within-tier `latent()` term
2. `expanded$Sigma_W` is the algebraic closure `Lambda_W Lambda_W^T + diag(Psi_W)` to 1e-6
3. `expanded$Repeatability` is per-trait `diag(Sigma_B) / (diag(Sigma_B) + diag(Sigma_W))` and matches the paper's Eq 25 formula
4. Renderer test: rendered Tab 3 of a two-tier fit contains text `R_1`, `R_2`, ... `R_T`
5. Regression: existing `Psi_B`-only fit (Widget 1) still renders cleanly, no spurious `Σ_W` block

## 7. Slice prerequisites

Before writing implementation code, two verification items:

- **P1**: confirm gllvmTMB's two-tier `latent()` + `unique()` syntax actually fits the within-individual reduced-rank and uniqueness terms; if not, the article uses glmmTMB for Widget 2 (the math is unchanged; only §6 prose + R chunk need a clarifying note).
- **P2**: simulate the same 40 × 3 × 5 dataset with both true Λ_B and true Λ_W, fit Widget 2, and confirm `extract_communality()` recovers the simulated truth in both tiers. (This is also the dataset that the article uses.)

If P1 or P2 fail, raise an issue and bring the design back here.

## 8. Out of scope for this slice (explicit non-goals)

- Cross-package extension of the two-tier model (e.g., teaching the same model in brms or MCMCglmm) — that's a separate slice.
- Communality / repeatability / phenotypic-correlation **figures** (heatmaps, biplots, path diagrams). Numerical Σ matrices live in Tab 3; visual diagrams are a v0.22+ slice.
- Reaction-norm / random-slope extension (the paper's Appendix B.1). Out of scope for this slice; can be a follow-up vignette.
- Sex-specific syndromes (the paper's Appendix B.2). Out of scope.
- Rank selection grid search + AIC scan utility. Out of scope (the article's two-tier fit uses fixed d_B = 2, d_W = 1).

## 9. Done = ?

- Both widgets render cleanly under multi-V audit (V1 Florence + V2 Pat + V3 Noether + V4 Twin) on the live preview.
- `make release-check` exits 0 (assuming P1 + P2 above passed).
- Tests in `tests/testthat/test-symbolize-gllvmtmb-two-tier.R` all pass.
- Maintainer reviews the rendered article in browser and explicitly says "Ship it".
- After-task record in `docs/dev-log/after-task/v0.21.6-redo.md` with the `## Issue ledger touched` block.

## 10. References

- Nakagawa, S., Mathot, K., Dinnage, R., Ortega, S., Pugar Filjak, M., Sosiak, C., Mizuno, A., Raymond, S., Poo Hernandez, S., Gross, I., Lagisz, M., Santos, E. S. A., Lundgren, E. (in prep). Quantifying between- and within-individual correlations and the degree of trait integration. Manuscript at `/Users/z3437171/Desktop/GLLVMs_for_studying_behavioural_syndromes.pdf`.
- McGillycuddy et al. 2025 — gllvmTMB package.
- Brooks et al. 2017 — glmmTMB package.
- Sih et al. 2004 — behavioural syndromes; Dingemanse & Dochtermann 2013 — variance-covariance partitioning; Pigliucci 2003 — phenotypic integration.
- Symbolizer issue tracker: #9 (three-views widget umbrella), #16 (Pattern P intra-widget consistency).
