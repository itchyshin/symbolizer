# NOETHER — Math correctness audit, v0.22.3 families widgets

Target: widgets `sym-lognormal-*`, `sym-beta-*`, `sym-poisson-*`
in `docs/articles/symbolizer-families.html`. Tab 1 = Index,
Tab 2 = Matrix, Tab 3 = Equations with data. Arithmetic reproduced
numerically. Defects are **structural** (equation shape / scale).

---

## 1. Poisson

`y_i|μ_i ~ Poisson(μ_i)`, `η_i = β_0+β_1 x_i`, `μ_i = exp(η_i)`.
**No additive ε.**

| Block | Rendered | Correct | Sev |
|---|---|---|---|
| Tab 1 dist | `y_i ~ Poisson(μ_i)`; `log(μ_i)=β_0+β_1 x_i` | same | OK |
| Tab 2 matrix | `y ~ Poisson(μ)`; `log(μ)=Xβ` | same | OK |
| Tab 3 row | `η̂_1=β̂_0+β̂_1 x_1`; `μ̂_1=exp(η̂_1)`; `y_1~Poisson(μ̂_1, …)` | `…` spurious — Poisson is one-parameter | MINOR |
| Tab 3 stacked | `y=Xβ̂+ε̂`, `Xβ̂=μ̂`, `ε̂=y−μ̂` | **WRONG.** Valid: `η=Xβ`, `μ=exp η`, `y~Poisson(μ)` separate. `Xβ̂=log μ̂`, not μ̂. Residuals shown have no structural role. | BLOCKER |

## 2. Beta

`y_i ~ Beta(μ_i φ_i, (1−μ_i) φ_i)`, `logit(μ_i)=β_0+β_1 x_i`,
`log(φ_i)=γ_0`. drmTMB names φ as `σ` (precision, not SD). **No
additive ε.**

| Block | Rendered | Correct | Sev |
|---|---|---|---|
| Tab 1 dist | `Beta(μ_i σ_i,(1−μ_i)σ_i)`; `logit(μ_i)=β_0+β_1 x_i`; `log(σ_i)=γ_0` | correct | OK |
| Tab 2 matrix | `Beta(μ,σ)`; `logit(μ)=Xβ` | **WRONG.** Reads like μ=α, σ=β. Should be `Beta(μ⊙σ,(1−μ)⊙σ)`. Tabs 1/2 inconsistent. | BLOCKER |
| Tab 3 row | `η̂_1=β̂_0+β̂_1 x_1`; `μ̂_1=logistic(η̂_1)≈0.279`; `y_1~Beta(μ̂_1,…)` | shape OK; cleaner: `Beta(μ̂_1 σ̂_1,(1−μ̂_1)σ̂_1)` | MINOR |
| Tab 3 stacked | `y=Xβ̂+ε̂`, `Xβ̂=μ̂`, `ε̂=y−μ̂` | **WRONG.** No additive ε. `Xβ̂` is logit scale, not μ̂. | BLOCKER |
| Tab 3 σ worked | `σ̂_1=exp(−1.04)≈0.353` "precision, not SD" | correct | OK |
| Tab 3 σ stacked | `log[σ]=X_σ γ` | correct | OK |

## 3. Lognormal (drmTMB identity link on μ ≡ E[log y])

`log(y_i)~N(μ_i,σ_i²)`, `μ_i=β_0+β_1 x_i` (**on log-y scale**),
`log(σ_i)=γ_0`. Only valid additive form: `log(y_i)=β_0+β_1 x_i+ε_log`.

| Block | Rendered | Correct | Sev |
|---|---|---|---|
| Tab 1 dist | `Lognormal(μ_i,σ_i²) ⇔ log(y_i)~N(μ_i,σ_i²)` | correct | OK |
| Tab 2 matrix | `log(y)~N(μ,diag(σ²))`; `μ=Xβ` | correct | OK |
| Tab 3 row | `log(y_1)=β̂_0+β̂_1 x_1+ε̂^{(log)}_1`; underbrace "log-scale mean / residual" | correct additive form | OK |
| Tab 3 stacked | `y=Xβ̂+ε̂` with **response-scale** y (4.78, 7.94, 12.7) and residuals (2.77, 5.95, 10.7); `Xβ̂=μ̂` | **WRONG.** Worked row uses log scale; stack uses raw y. Valid: `log(y)=Xβ+ε_log`. | BLOCKER |
| Tab 3 σ worked / stacked | "SD of log y" | correct | OK |

---

## Bug classes

1. **`y=Xβ̂+ε̂` stacked template emitted for all 3 families.** Valid
   only for Gaussian-identity. Shared template = root cause. BLOCKER×3.
2. **Caption `Xβ̂=μ̂` everywhere.** Poisson: `log μ̂`. Beta: `logit μ̂`.
   Lognormal: `E[log y]`. Silently asserts identity link. BLOCKER×3.
3. **`ε̂=y−μ̂` printed inside the structural equation** for Poisson
   and Beta — response-scale empirical residuals masquerading as model
   terms. BLOCKER×2.
4. Trailing `…` in `Family(μ̂_1, …)` — MINOR for Poisson.
5. Beta Tab-2 `Beta(μ,σ)` ≠ Tab-1 parameterisation. BLOCKER (Beta).

Highest-leverage fix: family-aware Tab-3 stacked template.
Response-scale for Gaussian-identity; log-scale for Lognormal;
`η=Xβ` link-scale plus separate likelihood line for Poisson, Beta,
other GLM families.

---

## Math content that would serve the reader better

**Poisson** (Tab 3 currently right but thin):
- Pearson residual: `r_i = (y_i − μ̂_i) / √μ̂_i`. Show `r_1` worked
  out and annotate "≈0 means this observation lands on the rate the
  model predicts."
- Overdispersion check: emit `mean(r²) ≈ 1` (currently for the fitted
  data, ≈ ?) and warn that Poisson **forces** `Var = μ`; if `mean(r²)
  >> 1` the family is wrong and `nbinom2` is needed.
- Coefficient reading: `exp(β̂_1) =` "rate ratio per unit of x".
  Currently the index tab shows `log μ = β_0 + β_1 x` but not
  `exp(β̂_1)` as a number, which is what biologists want.

**Beta** (mostly correct, missing biological pivot):
- Variance: `Var(y_i | μ_i, φ_i) = μ_i(1−μ_i)/(1+φ_i)`. Currently the
  reader has no way to see why a "precision" σ (φ) controls spread.
  At `μ̂_1=0.279`, `φ̂_1=0.353`, `Var ≈ 0.149` — bigger than under
  binomial-like dispersion. Worth showing.
- Odds-ratio reading: `exp(β̂_1) =` "each unit of x multiplies the
  odds of y by this factor". Currently only the logit equation is
  shown; the back-translated odds ratio is the biologist's lens.
- The "precision, not an SD" annotation is good; add a line showing
  that **larger σ ⇒ tighter spread** (counterintuitive) with one
  worked example.

**Lognormal** (where bias correction is routinely forgotten):
- Mean vs median: render both. `median(y) = exp(μ̂_1) = exp(2.01) ≈
  7.46`. `E[y] = exp(μ̂_1 + σ̂_1²/2) = exp(2.01 + 0.466²/2) ≈ 8.36`.
  The widget currently shows neither on the response scale; biologists
  who report "predicted weight" from this fit and use `exp(μ)` are
  systematically low by ~12% here.
- Coefficient reading: `exp(β̂_1)` is the proportional change in
  **median** y per unit of x, not the mean. The vignette body says
  this once for the index page; the widget should anchor it next to
  `β̂_1 = −0.0136 ⇒ ×0.986 per unit x on the median`.
- Variance on response scale: `Var(y) = exp(2μ+σ²)·(exp(σ²)−1)`.
  Mention that response-scale residuals (the wrongly-emitted ε̂ in
  Tab 3) are inherently right-skewed even when the fit is perfect —
  another reason to plot residuals on log scale.

A common addition all three need: an explicit **"link function /
response scale" disambiguator line** on Tab 3, since the
widget's job is to teach scale-passing, and the current `Xβ̂=μ̂`
caption actively trains the wrong reflex.
