# V1 Florence-lens audit — symbolizer-families.html — 2026-05-26

Target: `http://localhost:8766/articles/symbolizer-families.html`
Branch: `v0.21-redo` (built docs/ from v0.21.3 deploy state)
Auditor: V1 (Florence-lens) sub-agent
Outcome: 6 catalog bugs confirmed (B1, B2, B3, B24, B27, B30 partial-B28); 4 catalog bugs ruled out (B17, B25, B26, B29); **11 new defects identified.**

## Methodology evidence

- `preview_list` returned serverId `c2648b71-cdbd-434d-b7ad-4fe48a1a9a1b` on `localhost:8766`, status `running`.
- Viewport: 1280×1200 (set via `preview_resize`).
- Widgets found: `sym-poisson-1779823408`, `sym-beta-1779823406`, `sym-lognormal-1779823404`.
- Dupe verified via `document.querySelectorAll('#sym-poisson-1779823408').length === 2` (same for beta and lognormal); both copies have independent `aria-selected` state.
- 103 native `<math>` elements present. `window.MathJax === undefined`, `katex === undefined`. All math via browser-native MathML — no stretchy operator support in this environment.
- 18 tab elements total (3 per widget × 2 copies = 18).

## Per-widget findings

### Widget 1: Poisson (`sym-poisson-1779823408`)

**Tab 1 (Index)**
- Copy 1 renders MathML correctly: `y_i | μ_i ~Poisson(μ_i)` and `log(μ_i) = β_0 + β_1 x_i`.
- Copy 2 shows literal source `$$\begin{aligned} y_i \mid \mu_i & \sim \mathrm{Poisson}(\mu_i) \\ \log(\mu_i) & = \beta_{0} + \beta_{1} \, x_i \end{aligned}$$` (B2).
- Subtitle text drift between copies: copy 1 `"i – the per-individual reading"` (en-dash) vs copy 2 `"i -- the per-individual reading"` (double hyphen).
- B30: per-observation Tab 1 prints `R^100` for scalars `y_i`, `μ_i` — should be scalar `R`.

**Tab 2 (Matrix)**
- Copy 1 renders `y | μ ~Poisson(μ)`, `log(μ) = Xβ`. Gloss adds `X — mu submodel design matrix R^{100×2}`.
- Copy 2 stuck on Tab 1 markup — clicking copy 1's tab does NOT sync copy 2.

**Tab 3 (Equations with data)**
- **B1 (severe)**: worked row `y_1 = β̂_0 + β̂_1 x_1 + ε̂_1`, `1 = 0.955 + −0.0438 × 0.45 + (0.0643)`, `= 0.936 (predicted μ̂_1) + (0.0643) (residual ε̂_1)`. Poisson has no additive ε; this is the Gaussian-additive template applied to a count model.
- **B24**: `<mo stretchy="true">[` height 13 px vs parent `<mrow>` 144–146 px (≈9% ratio). Same for `(`/`)` around inner matrices (14 vs 94 px).
- B25 NOT triggered (matrices fit at 100×2).
- B26 / B29 NOT triggered (pink container 118–190 px, first child at 12 px from top).
- Cosmetic: `+ −0.0438` appears literally (plus negative).

**Gloss "where:"**
- Copy 1: prose says "mu submodel coefficients", "mu submodel design matrix" — spells out "mu" in English rather than rendering as math (mild B28).
- Copy 2: raw `$\mathbb{R}^{100}$` etc.

### Widget 2: Beta (`sym-beta-1779823406`)

**Tab 1 (Index)**
- Renders `y_i | μ_i, σ_i ~ Beta(μ_i σ_i, (1 − μ_i)σ_i)` (mean-precision parameterization), `logit(μ_i) = β_0 + β_1 x_i`, `log(σ_i) = γ_0`.
- **NEW Bxx_A**: `Beta(μ_i σ_i, …)` has `μ_i σ_i` juxtaposed with no `·` or `×` separator — could be misread as a single symbol `μσ`.

**Tab 2 (Matrix)**
- Renders `y | μ, σ ~ Beta(μ, σ)`, `logit(μ) = Xβ`, `log(σ) = Zγ`.
- **NEW Bxx_B (parameterization inconsistency Tab 1 vs Tab 2)**: Tab 1 explicitly writes `Beta(μσ, (1−μ)σ)`; Tab 2 collapses to `Beta(μ, σ)`, which is not a standard parameterization. A reader who only reads Tab 2 has no idea this is mean-precision.

**Tab 3 (Equations with data)**
- **B1 (severe)**: `y_1 = β̂_0 + β̂_1 x_1 + ε̂_1`, `0.175 = -0.824 + -0.0874 × 1.43 + (1.13)`, `= -0.95 (predicted μ̂_1) + (1.13) (residual)`. **`μ̂_1 = -0.95` shown as predicted of `y ∈ (0,1)`** — but a Beta mean cannot be negative. `μ̂` is on the *logit* scale; the actual predicted mean is `inv_logit(-0.95) ≈ 0.279`.
- **NEW Bxx_F**: σ submodel labeled "predicted residual SD for observation 1". For Beta's mean-precision form, σ is a precision-like parameter, **not** a residual SD.
- **NEW Bxx_C (design-matrix naming inconsistency Tab 2 vs Tab 3)**: Tab 2 defines `Z — sigma submodel design matrix`. Tab 3's σ stacked block labels the same matrix `X_{σ, 100×1}`. Same matrix, two names across tabs.
- **NEW Bxx_H**: `μ̂_1 = -0.95` as "predicted" for `y ∈ (0,1)` is a logit-link aware worked-row missing — should show both `η̂ = -0.95` and `μ̂ = inv_logit(η̂) ≈ 0.279`.
- B24 confirmed.

### Widget 3: Lognormal (`sym-lognormal-1779823404`)

**Tab 1 (Index)**
- Renders `y_i | μ_i, σ_i ~ Lognormal(μ_i, σ_i²) ⇔ log(y_i) | μ_i, σ_i ~ Normal(μ_i, σ_i²)`, `μ_i = β_0 + β_1 x_i`, `log(σ_i) = γ_0`.
- **NEW Bxx_D**: Gloss does not warn that `μ_i` is the mean of `log(y)`, not `y` itself. Reader will misread `μ_i` as `E[y_i|x_i]`.

**Tab 2 (Matrix)**
- Renders `log(y) | μ, σ ~ N(μ, diag(σ²))`, `μ = Xβ`, `log(σ) = Zγ`.
- **NEW Bxx_E**: Tab 2 OMITS the Lognormal-side of the bridge shown in Tab 1; reader who jumps to Tab 2 won't realize this is a Lognormal model.

**Tab 3 (Equations with data)**
- **B1 + NEW Bxx_G (severe, scale-mixed)**: worked row `y_1 = β̂_0 + β̂_1 x_1 + ε̂_1`, `4.78 = 2.02 + -0.0136 × 0.409 + (2.77)`, `= 2.01 (μ̂) + (2.77) (residual)`. But `μ̂ = 2.01` is the mean of `log y`, while `y_1 = 4.78` is on the response scale. `y − μ̂ = 2.77` is **scale-mixed** (response − log). Either `log(4.78) − 2.01 = -0.45` (log-scale residual) or `μ̂` should be `exp(2.01 + σ̂²/2) ≈ 8.3` (response-scale prediction) — the displayed numbers are internally inconsistent.
- σ submodel labeled "predicted residual SD" — here σ IS the SD of `log y`, so closer to right than Beta, but still missing "on the log scale" qualifier.
- Bxx_C reapplies (Z vs X_σ).
- B24 confirmed.

## Catalog cross-reference (B1–B30)

| Bug | Status | Evidence |
|---|---|---|
| B1 Gaussian-additive worked-row template | **PRESENT** on Poisson/Beta/Lognormal Tab 3 | textContent matches `y_1 = β̂_0 + β̂_1 x_1 + ε̂_1`; Beta shows `μ̂_1 = -0.95` for `y ∈ (0,1)`; Lognormal shows scale-mixed `y - μ̂ = 2.77` |
| B2 raw `$$\begin{aligned}` in 2nd DOM copy | **PRESENT** all three widgets | `panel.querySelectorAll('math').length === 0` for every copy 2 |
| B3 `$\mathbb{R}^{100}$` literal in gloss | **PRESENT** in copy 2 only | copy 2 gloss rows show literal source |
| B17 `_` escaping in user names | **NOT APPLICABLE** — page uses simulated covariates |
| B24 brackets not stretching | **PRESENT** all 3 Tab 3 matrix blocks | bracket 13 px vs parent 144–146 px |
| B25 wide matrices overflow | **NOT PRESENT** here — 100×2 fits in 776 px widget |
| B26 empty top whitespace | **NOT PRESENT** — first child at 12 px |
| B27 widget DOM emitted twice | **PRESENT** all three | duplicate IDs verified |
| B28 unrendered LaTeX-source in CSV | **PARTIAL** — copy 1 says "mu/sigma submodel coefficients" (English spellings of Greek letters); aggressive sigma_p^2/tau/yi/k×k patterns NOT visible here |
| B29 ~600 px whitespace | **NOT PRESENT** — containers 118–191 px |
| B30 dimension format inconsistent | **PRESENT** in Tab 1 — scalars labelled with vector dimension `R^100` |

## NEW defects (not in B1–B30)

11 new findings, suggested catalog numbering B31–B41:

| Bxx_ | Description | Suggested catalog # | Suggested pattern family |
|---|---|---|---|
| A | Beta `μ_i σ_i` juxtaposed without `·`/`×` separator | B31 | Pattern N (template prose) or A (math/text context) |
| B | Tab 1 `Beta(μσ,…)` vs Tab 2 `Beta(μ,σ)` parameterization mismatch | B32 | **NEW Pattern P: intra-widget consistency** |
| C | Z (Tab 2 gloss) vs X_σ (Tab 3 stacked block) — same matrix, two names | B33 | Pattern G (symbol consistency) |
| D | Lognormal μ_i glossed as "conditional mu of y" — wrong; it's mean of log(y) | B34 | Pattern N + B (family-aware gloss) |
| E | Lognormal Tab 2 omits the Lognormal-side of the bridge shown in Tab 1 | B35 | NEW Pattern P |
| F | "Predicted residual SD" label applied to Beta σ (which is a precision, not SD) | B36 | Pattern B (family-aware labels) |
| G | Lognormal Tab 3 worked row scale-mixes log(μ̂) with response y | B37 | Pattern B |
| H | Beta Tab 3 shows `μ̂_1 = -0.95` as predicted of `y ∈ (0,1)` — should show η̂ and μ̂=inv_logit | B38 | Pattern B (link-aware worked row) |
| I | Tab label "3. Equations with data" wraps to 2 lines in copy 1, 1 line in copy 2 | B39 | Pattern M (B27 manifestation) |
| J | Subtitle en-dash drift: copy 1 `–`, copy 2 `--` | B40 | Pattern M |
| K | HTML validity: duplicate IDs across copies (hard standards violation) | B41 | Pattern M (upgrade to validity violation, not just visual bug) |

## NEW pattern proposed

**Pattern P — intra-widget consistency (Tab 1 ↔ Tab 2 ↔ Tab 3 tell the same story)**

Bugs B32 (Beta parameterization), B35 (Lognormal bridge), and parts of B33 (Z vs X_σ) all share a root cause: each tab is built from its own CSV row, with no cross-tab consistency check. A reader who scans only one tab can come away with a parameterization the other tabs contradict.

Structural fix: introduce a per-family "consistency contract" in `docs/specs/per-family-templates.md` — every family declares its canonical parameterization once, and Tab 1 / Tab 2 / Tab 3 templates must reference the SAME parameterization. Snapshot test: rendered text of Tab 1, Tab 2, Tab 3 distribution lines must mention the same parameter list (allowing for index → matrix substitution like `i → ·`).

Lands in v0.21.1(redo) alongside Patterns B, K.

## Method failures (lessons for the next V-agent)

- **Screenshot tool requires `scrollY === 0`** when the body-transform trick is applied. Programmatic `window.scrollTo(0, N)` does not move the captured viewport; only `document.body.style.transform = 'translateY(-Npx)'` works, AND only if `scrollY === 0` first. After clicking tabs (which may auto-scroll), needed `window.scrollTo(0,0); requestAnimationFrame(() => applyTransform())` to reliably capture. Lost ~3 screenshots before learning this.
- **No PNG save endpoint.** `preview_screenshot` returns an inline image. Per the brief I created the figure-audits directory but could not persist bytes there from inside the agent. All findings cite preview_inspect measurements and DOM-query results that the auditor can rerun.
- **Both DOM copies have identical IDs.** `preview_click` with `#sym-poisson-...-tab-mat` only clicks the first match; to sync copy 2's tab state, must use `Array.from(document.querySelectorAll(...))[i].click()` via `preview_eval`. Even then, panel-state synchronization is independent.
- **mathjax/katex are not loaded.** All math renders via browser-native MathML. This is environmental and is the root cause of B24 — the fix is to add `template.math-rendering: mathjax` to `_pkgdown.yml` (issue #12).
