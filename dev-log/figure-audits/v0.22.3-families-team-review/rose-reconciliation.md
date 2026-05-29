# Rose reconciliation — families team review (v0.22.3)

Date: 2026-05-28
Lens reports (per the loaded dispatching-parallel-agents discipline):
- `florence-visual.md` — visual rendering / typography
- `noether-math.md` — math correctness vs canonical generative model
- `pat-reader-flow.md` — biologist-reader experience + within-tab consistency
- `fisher-numerical.md` — numerical extraction + diagnostic surfacing

## Verdict

**NEEDS FIXES**. Three BLOCKERS cross-confirmed by all four lenses. The
v0.22.3 families fix correctly addressed the Tab 3 WORKED-ROW arithmetic
but left the Tab 3 STACKED-BLOCK arithmetic still emitting the
Gaussian-identity template `y = Xβ̂ + ε̂` for non-Gaussian families. The
within-tab self-contradiction (worked row says "no additive ε here",
stacked block immediately below it shows `+ ε̂`) is visible on a single
page-scroll.

## Convergent findings (all four lenses agree)

### B1. Tab 3 stacked block emits `y = Xβ̂ + ε̂` for every family

| Lens | Verdict | Evidence |
|---|---|---|
| Noether | BLOCKER ×3 | "Shared template = root cause" |
| Pat | BLOCKER ×3 (with concrete arithmetic) | Poisson row 1: `0.936 + (−1.55) = −0.6134 ≠ 1` |
| Fisher | BLOCKER ×3 (numerical reproduction) | Confirms Pat's exact numbers per family |
| Florence | BLOCKER ×3 (visual confirmation) | "Tab 3 stacked block in all three widgets displays `y = Xβ̂ + ε̂`" |

**Code location**: `R/render-three-views.R`
- Line 917: `eps_hat <- ex$y - ex$mu_hat` — family-blind residual
- Lines 907–925: stacked-block construction
- Line ~1155: caption asserting `Xβ̂ = μ̂` (false for non-identity links)

**The exact lie per family**:
| Family | LHS scale | RHS scale | Numerical mismatch at i=1 |
|---|---|---|---|
| Poisson | response (count y₁=1) | log-rate (Xβ̂=0.936) + response (ε̂=−1.55) | `0.936 + (−1.55) = −0.614 ≠ 1` |
| Beta | response (y₁=0.175 ∈ (0,1)) | logit (Xβ̂=−0.95) + response (ε̂=−0.103) | `−0.95 + (−0.103) = −1.053 ≠ 0.175` |
| Lognormal | response (y₁=4.78) | mean-of-log-y (Xβ̂=2.02) + response (ε̂=2.77) | `2.02 + 2.77 = 4.79 ≈ 4.78`, BUT same symbol ε̂ also used for `−0.448` in the worked-row two lines above. Symbol overloaded factor-of-6 |

### B2. Caption "Middle: Xβ̂ = μ̂. Right: ε̂ = y − μ̂" asserts identity link

True only for Gaussian-identity. For Poisson `Xβ̂ = log μ̂`; for Beta
`Xβ̂ = logit μ̂`; for Lognormal `Xβ̂ = E[log y]`. The caption silently
trains the wrong reflex.

**Code location**: `R/render-three-views.R` ~line 1155 (caption literal).

### B3. Lognormal symbol `ε̂` overloaded within ONE tab

Worked row (top of Tab 3) uses `ε̂_1 = log(y_1) − Xβ̂ = −0.448` on log
scale. Stacked block (below) uses the same symbol `ε̂ = y − μ̂ = 2.77`
on response scale. Factor-of-6 disagreement under one symbol. Both
appear in the same Tab 3 without scrolling.

## Single-agent findings (not cross-confirmed but credible)

### M1. Beta Tab 2 collapses `Beta(μ⊙σ, (1−μ)⊙σ)` to `Beta(μ, σ)` (Noether)

Tab 1 emits the correct mean-precision form `Beta(μ_iσ_i, (1−μ_i)σ_i)`.
Tab 2 (matrix form) collapses to `Beta(μ, σ)` — reads like the
two-parameter `Beta(α, β)` form. Internal contradiction within ONE widget.

**Code location**: likely in a family-distribution CSV row or in
`drm_build_distribution` (matrix-form path). Different file from B1.

### M2. Poisson worked row carries spurious trailing `…` (Noether)

`Poisson(μ̂_1, …)` — Poisson is one-parameter; the `…` is misleading.
MINOR. Same template generated for two-parameter Beta etc; needs
per-family parameter-count awareness.

### M3. Beta φ̂ = 0.353 implies U-shaped distribution (Fisher) — **the surprise**

For this fixture: `μ̂_1 = 0.279`, `φ̂_1 = 0.353` →
shape parameters `(a, b) = (μφ, (1−μ)φ) = (0.098, 0.254)`. Both
shapes < 1 ⇒ the fitted Beta is **U-shaped** (density piles up near 0
and 1, dip in the middle). Unusual for a typical proportion model;
warning sign that the data may be zero-one-inflated and Beta is the
wrong family. The widget surfaces neither `(a, b)` nor the shape
caveat. A reader sees the numbers and walks away without realizing
their fit is suspect.

Not a bug. But the cleanest example of "the widget could surface a
biological diagnostic and doesn't" — the user's "surprise me" directive
in concrete form.

## Bug-fix punch list (Tier 1 — correctness; before any new content)

| ID | Site | Code location | Severity | Cross-lens confirms |
|---|---|---|---|---|
| F1 | Tab 3 stacked block emits `y = Xβ̂ + ε̂` for all families | `R/render-three-views.R` ~907–925 | BLOCKER | all 4 |
| F2 | Tab 3 stacked-block caption asserts `Xβ̂ = μ̂` universally | `R/render-three-views.R` ~1155 | BLOCKER | all 4 |
| F3 | Lognormal `ε̂` symbol overloaded across worked-row + stacked | same surface (F1 + worked row interplay) | BLOCKER | Fisher + Noether + Pat |
| F4 | Beta Tab 2 collapses to `Beta(μ, σ)` | separate Tab 2 builder | BLOCKER | Noether (single-lens but unambiguous math error) |
| F5 | `Poisson(μ̂_1, …)` trailing `…` | per-family distribution template | MINOR | Noether |

## Reader-improvement punch list (Tier 2 — pedagogy; lands after Tier 1)

Tier 2 items add NEW content that helps a biologist read the widget.
Not bug fixes; pedagogical additions.

### Per-family coefficient readings (Pat + Noether)

Add a line under each Tab 3 worked row:

| Family | Reading line |
|---|---|
| Poisson | `exp(β̂_1) = exp(−0.0438) ≈ 0.957` — "each unit of x multiplies the expected count by 0.957 (a 4.3% drop per unit)" |
| Beta | `exp(β̂_1) =` odds-ratio "each unit of x multiplies the odds(y) by …" |
| Lognormal | `exp(β̂_1)` is the proportional change in the **median** y per unit of x, not the mean (Lognormal mean ≠ exp(η)) |

### Per-family diagnostic line (Fisher)

| Family | Diagnostic | Reader signal |
|---|---|---|
| Poisson | Pearson `r_1 = (y_1 − μ̂_1)/√μ̂_1` + sample `mean(r²)` | observation fit + overdispersion warning |
| Beta | Shape `(a, b) = (μ̂_1 φ̂_1, (1 − μ̂_1) φ̂_1)` | **U-shape warning when both < 1** |
| Lognormal | `E[y_1] = exp(μ̂_1 + σ̂_1²/2) = 8.34` vs `median = exp(μ̂_1) = 7.46` | bias correction; the widget currently shows neither |

### Worked-row choice (Pat)

Current worked rows always use observation 1, which may be unrepresentative.
Pat proposes alternative anchor choices: row nearest x-mean, row at +1 SD,
or rows on opposite sides of the median. Useful pedagogically — pick a
worked observation that makes the math LOOK like the model's intent.

### "What this means for your study" italic line per family (Pat)

One-sentence italicised caption per widget, anchored next to the worked
row, that translates the model's statistical claim into a biological
takeaway. E.g., for Poisson: *"The model assumes the variance of the
count equals its mean — if your residuals show clumping or excess zeros,
consider negative binomial or zero-inflated alternatives."*

## Visual polish (Tier 3 — typography / layout; Florence)

| Item | Site | Fix |
|---|---|---|
| Constant-σ vector stacks 8 identical rows | σ-stacked-block | Detect when var(values) < ε and truncate to head-2 / ⋮ / tail-1 with caption "all `n` rows identical for this fit" |
| Caption "Left / Middle / Right" too visually loud | stacked-block caption | Drop `<strong>`, use 0.85em plain prose |
| Pink-box bottom padding ~20px after last equation | sym-eq CSS | Reduce to ~6px |
| No visual link between worked row at top of Tab 3 and the stacked block below | stacked block first row | Add pink-tinted left border on row 1 of y / Xβ̂ / ε̂ matrices |
| Scale-tag side-labels would survive the math fix | stacked block | Add small `log / logit / response` 0.75em uppercase tags next to each matrix |
| Beta stacked vector mixes 3- / 4- / 6-sig-fig in one column | latex_vec / formatC call | Standardise per-block |
| Beta σ caption nested parentheses wrap awkwardly | σ-caption text | Restructure the sentence |

## Implementation plan

**Slice 1 — F1 + F2 + F3 (Tab 3 stacked block + caption family-awareness)**

Mirror the worked-row architecture from v0.22.3. Three shapes:
- `additive_gaussian` (Gaussian, Student-t): `y = Xβ̂ + ε̂` on response scale — keep as-is
- `additive_log` (Lognormal): `log(y) = Xβ̂ + ε̂_log` on log scale — both stack and worked row in same units
- `generalized` (Poisson, Beta, Binomial, Gamma, NegBinom): three lines —
  - `η̂ = Xβ̂` (linear predictor stack, no ε)
  - `μ̂ = link^{-1}(η̂)` (response-scale stack)
  - `y ~ Family(μ̂)` (likelihood declaration; show one row as e.g.
    `y_1 = 1` for Poisson, `y_1 ∈ (0,1)` for Beta)

Caption per shape — drop the universal `Xβ̂ = μ̂` claim. For the
generalized shape: "Left: observed `y`. Middle: link-scale linear
predictor `Xβ̂`. Right: response-scale prediction `μ̂ = link⁻¹(Xβ̂)`."

TDD per family: extract row 1 numbers, verify the displayed equation
closes arithmetically on the correct scale.

**Slice 2 — F4 (Beta Tab 2 parameterisation)**

Locate and fix the matrix-form distribution row in the per-family
distribution template that emits `Beta(μ, σ)`. Restore
`Beta(μ⊙σ, (1−μ)⊙σ)`. TDD: rendered Beta Tab 2 contains `\mathbf{\mu}\odot\sigma`.

**Slice 3 — F5 (Poisson trailing `…`)**

Make the family-distribution template parameter-count aware. Poisson and
Exponential are one-parameter; others may have more. Drop trailing `…`
when there's only the mean.

**Slice 4 — Tier 2 reader improvements (T1 + T2 + T3 + T4)**

Add per-family reading line, diagnostic line, "what this means" caption.
Each is its own small commit so the user can review each addition.

**Slice 5 — Tier 3 visual polish**

Css / formatting changes. Lowest priority; lands once Tier 1 + Tier 2
are visually settled.

## Rose sign-off

`Rose approved: pending implementation. Punch list above is exhaustive
for the families article. All four lenses agree on the three BLOCKERs.
Implementation order: F1+F2+F3 (Slice 1) → F4 (Slice 2) → F5 (Slice 3)
→ Tier 2 (Slice 4) → Tier 3 (Slice 5). No new content until F1+F2+F3
ship and the visual contradiction within Tab 3 is gone.`

## Known residuals (what this synthesis explicitly does NOT cover)

- Other articles on the site (drmtmb, structural-dependence, gllvm,
  factors, ladder, get-started). The Tab 3 stacked template is SHARED
  across all articles — fixing F1 here probably fixes the same class on
  the other articles. To be verified after F1 lands.
- PDF parity (`as_pdf_three_views`). PDF emitter walks the same renderer;
  same fix surface. Verify post-Slice-1.
- Other family fits the renderer would hit (cumulative_logit, gamma with
  inverse link, zero-truncated nbinom2, Tweedie, bivariate_gaussian).
  Tier 1 fix should cover most; Tweedie + cumulative_logit likely need
  their own pattern.
