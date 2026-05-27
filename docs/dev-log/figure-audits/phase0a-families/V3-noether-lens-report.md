# V3 Noether-lens audit — symbolizer-families.html — 2026-05-26 overnight

Auditor: V3 (Noether-lens) — math correctness vs per-family canonical contract.
Outcome: every Tab 3 worked row violates its family contract. V1 B1/B36–B38
and V2 B48 confirmed numerically. **6 new math defects** beyond V1+V2.

## Methodology

- `preview_list` → serverId `c2648b71-cdbd-434d-b7ad-4fe48a1a9a1b`, port 8766, running.
- Viewport 1280×1200. Widgets: `sym-poisson-1779823408`, `sym-beta-1779823406`,
  `sym-lognormal-1779823404` (first DOM copy).
- Contract source: `~/.claude/plans/where-are-you-now-glowing-cocoa.md` § Noether's authoritative table.
- V1 + V2 reports read in full first.
- Tab-ID inversion observed: `*-tab-eq` renders "2. Matrix"; `*-tab-mat` renders
  "3. Equations with data" (new defect **B50_noether_F**).
- Arithmetic verified via Rscript.

## Per-widget verification

### Poisson (`sym-poisson-1779823408`)

**Extracted Tab 3:** `β̂_0 = 0.955`, `β̂_1 = −0.0438`, `x_1 = 0.45`, displayed
`μ̂_1 = 0.936`, `y_1 = 1`, `ε̂_1 = 0.0643`. Stacked-block caption: `Xβ̂ = μ̂`.

**Contract (log link):** `η̂_1 = 0.955 + (−0.0438)(0.45) = 0.93529`;
`μ̂_1 = exp(η̂_1) = 2.5480` (count rate); Pearson resid `= (1 − 2.548)/√2.548 = −0.970`.

**Divergence:** the displayed `μ̂_1 = 0.936` is **η̂_1 mislabelled**. True
response-scale count rate `2.55`, factor **2.72×** larger. Stacked-block
caption `Xβ̂ = μ̂` is wrong: for log link, `Xβ̂ = η̂`.

**Downstream impact:** biologist reads `0.936` as "predicted count" — off
by factor `e ≈ 2.72`; error grows as `e^η − η` for larger η̂.

**σ-submodel:** N/A.
**`+ ε̂_1` line:** PRESENT. Contract: NO. (V1 B1 confirmed.)
**Tab 1 distribution:** `Poisson(μ_i); log(μ_i) = β_0 + β_1 x_i` — contract-OK.
**Violations:** B1, B48 (root), `μ̂` mislabel, caption `Xβ̂ = μ̂` wrong, missing
`μ̂_1 = exp(η̂_1)` step (**B50_noether_D**).

### Beta (`sym-beta-1779823406`)

**Extracted Tab 3:** `β̂_0 = −0.824`, `β̂_1 = −0.0874`, `x_1 = 1.43`, `y_1 = 0.175`,
displayed `μ̂_1 = −0.95`, `ε̂_1 = 1.13`. σ-submodel: `γ̂_0 = −1.04`,
`σ̂_1 ≈ 0.353`, labelled "predicted residual SD".

**Contract (logit link):** `η̂_1 = −0.824 + (−0.0874)(1.43) = −0.94898`;
`μ̂_1 = logistic(η̂_1) = 0.27909` (prob ∈ (0,1)); `φ̂_1 = exp(−1.04) = 0.35346`
(**precision**, not SD). Implied Beta shapes `(0.0986, 0.2548)` → U-shape;
actual SD `= √(μ(1−μ)/(1+φ)) = 0.3856`.

**Divergence:** `μ̂_1 = −0.95` shown as predicted proportion of `y ∈ (0,1)` — **negative
probability, off the support**. Real predicted proportion `0.279`. The number
displayed is η̂ on logit scale, mislabelled as μ̂.

**σ direction check:** contract says `φ = 0.353 < 1` → Beta is U-shaped
(anti-tight); large φ → tight. Label "residual SD" prompts reader to think
"±0.353 spread around μ̂" — exactly the wrong mental picture; real
response-scale SD is `0.386 > 0.353`.

**Downstream impact:** any reader reporting `μ̂_1` in a Methods/Results
section quotes a negative probability. Quoting `σ̂_1 = 0.353` as a Beta SD
double-fails: wrong concept (precision, not SD), wrong number (0.386), wrong
shape inference (U not unimodal).

**`+ ε̂_1` line:** PRESENT. Contract: NO.
**Tab 1 distribution:** `Beta(μ_i σ_i, (1−μ_i) σ_i)` — uses σ where contract
uses φ (**B50_noether_A**: σ then re-used for the σ-submodel → one symbol,
two meanings).
**Tab 2 distribution:** `Beta(μ, σ)` — this parameterization does not exist
(V1 B32 confirmed; mathematically a reader cannot recover μ̂ from `(μ, σ)`).
**Violations:** B1, B38, B36, B32, B48, B50_noether_A, plus missing
`μ̂_1 = logistic(η̂_1)` step (**B50_noether_E**).

### Lognormal (`sym-lognormal-1779823404`)

**Extracted Tab 3:** `β̂_0 = 2.02`, `β̂_1 = −0.0136`, `x_1 = 0.409`, `y_1 = 4.78`,
displayed `μ̂_1 = 2.01`, `ε̂_1 = 2.77`. σ-submodel: `γ̂_0 = −0.764`,
`σ̂_1 ≈ 0.466`, labelled "predicted residual SD".

**Contract (log link, Normal on log y):** `η̂_1 = 2.02 + (−0.0136)(0.409) = 2.01444`
(log scale); log-scale residual `= log(4.78) − 2.01444 = 1.5644 − 2.01444 = −0.4500`;
response-scale predicted mean `= exp(η̂ + σ̂²/2) = exp(2.0144 + 0.1086) = 8.3563`;
response-scale SD `= √((e^{σ²} − 1) e^{2η + σ²}) = 4.115`.

**Divergence:** `4.78 = 2.01 + 2.77` mixes scales (`y` on response, `μ̂`
labelled but actually η̂ on log scale). Contract log-resid is `−0.45` —
**opposite sign and ~6× smaller magnitude** than displayed `+2.77`.
Response-scale residual `y − exp(η̂) = −2.72` — same magnitude as displayed
but opposite sign.

**σ direction check:** contract: `σ̂_1 = 0.466` is the **SD on log scale**.
Label "predicted residual SD" missing the "of log y" qualifier; reader who
plugs `0.466` in as response-scale SD is off by a factor of `4.115/0.466 ≈ 8.8`.

**Downstream impact:** biologist back-transforming via `μ̂_1 = exp(2.01) =
7.46` (without the `+σ²/2` correction) underestimates arithmetic mean by
`exp(σ²/2) ≈ 1.115`. True E[y|x] is `8.36`. Reading `μ̂_1 = 2.01` as a
response-scale prediction is wrong by a factor of `8.36 / 2.01 ≈ 4.16`.

**`+ ε̂_1` line:** PRESENT on response scale. Contract: log-scale residual,
explicitly labelled. (V1 B37 confirmed.)
**Tab 1 distribution:** `Lognormal(μ_i, σ²) ⇔ Normal(μ, σ²) on log y` — bridge OK.
**Tab 2 distribution:** `log(y) ~ N(μ, diag(σ²))` — drops Lognormal half (V1 B35).
**Violations:** B1, B37, B34, B35, B48, plus missing back-transform line
`μ̂_1 = exp(η̂_1 + σ̂²/2)` (**B50_noether_C**).

## Stacked-block arithmetic spot-check

| Family | LHS (y) | Computed `Xβ̂ + ε̂` | Status |
|---|---|---|---|
| Poisson row 1 | 1 | 0.955 + 0.45·(−0.0438) + 0.0643 = **0.9996** | balances within rounding |
| Beta row 1 | 0.175 | −0.824 + 1.43·(−0.0874) + 1.13 = **0.1810** | balances (rounding) |
| Lognormal row 1 | 4.78 | 2.02 + 0.409·(−0.0136) + 2.77 = **4.7844** | balances |
| Lognormal row 2 | 7.94 | 2.02 + 1.69·(−0.0136) + 5.95 = **7.9470** | balances |
| Lognormal row 4 | 12.7 | 2.02 + (−0.331)·(−0.0136) + 10.7 = **12.7245** | balances |

The arithmetic always balances because `ε̂ = y − Xβ̂` is computed and
back-substituted. **Smoking gun for V2 B48:** the renderer never asks the
link function what scale `Xβ̂` is on. It is mechanically a Gaussian-identity
template applied universally.

## NEW math errors (not in V1 B1/B36–B38 or V2 B48/B49)

| ID | Description | Contract clause | Pattern |
|---|---|---|---|
| **B50_noether_A** | Beta Tab 1 uses `σ_i` for the precision (contract row 4 reserves `φ`). σ is then re-used for the σ-submodel — one symbol, two distinct math meanings inside one widget. | Hard rule 3 (Beta σ-submodel = "precision φ") | NEW Pattern T: per-family symbol allocation (sibling of G). |
| **B50_noether_B** | Stacked-block caption `Xβ̂ = μ̂` reused verbatim across all three widgets. Correct only for identity link. For Poisson/Beta/Lognormal it is `Xβ̂ = η̂`. | "Predicted label always identifies which scale the number is on" | Pattern B (family-aware caption). |
| **B50_noether_C** | Lognormal Tab 3 never emits the response-scale back-transform `μ̂_1 = exp(η̂_1 + σ̂²/2) = 8.36`. Contract: "back-transform shown separately as response-scale predicted mean". | Lognormal row: "η̂_1 AND μ̂_1 shown side-by-side; never one alone" | Pattern B + mandatory line. |
| **B50_noether_D** | Poisson Tab 3 never emits `μ̂_1 = exp(η̂_1) = 2.548`. Contract requires three distinct lines (η̂; μ̂; y~Poisson). Widget emits one and mislabels. | Poisson row: "`η̂_1 = ...; μ̂_1 = exp(η̂_1); y_1 ~ Poisson(μ̂_1)`" | Pattern B. |
| **B50_noether_E** | Beta Tab 3 never emits `μ̂_1 = logistic(η̂_1) = 0.279`. Widget shows only η̂ (mislabelled as μ̂). | Beta row: "Show both η̂ AND μ̂ side-by-side" | Pattern B. |
| **B50_noether_F** | Tab-button IDs swapped: `*-tab-eq` opens "2. Matrix" panel; `*-tab-mat` opens "3. Equations with data". Math correctness still computable but ID-based scripts (V1, snapshot tests) hit wrong panel. | Audit-blocker, not a math error per se | NEW Pattern T-meta: ID-to-label consistency lint. |

**Cross-check vs V1/V2:** A is genuinely new (V1 B32 catches cross-tab
mismatch, not the Tab-1-internal σ/φ clash). B is new — V1 caught the
worked-row `μ̂_1` mis-naming but not the companion stacked-block caption.
C/D/E sharpen V2 B49 from "missing response-scale line" to
"missing-by-formula" per the contract table.

## Severity rank

1. **Beta `μ̂_1 = −0.95` shown as predicted proportion (V1 B38)** — off the
   support; publication catastrophe.
2. **Lognormal scale-mixed worked row (V1 B37)** — factor 4.16 on any
   response-scale prediction; residual sign reversed.
3. **Poisson missing `μ̂ = exp(η̂)` step (B50_noether_D)** — factor 2.72 on
   every count; scales as `e^η`.
4. **Beta σ called "residual SD" (V1 B36 + B50_noether_A)** — direction of
   shape reversed; σ symbol overloaded.
5. **`+ ε̂` line architectural (V1 B1, V2 B48)** — root cause; fix it and
   1–4 collapse.
6. **Stacked-block caption `Xβ̂ = μ̂` (B50_noether_B)** — propagates the
   scale confusion; cheap fix, high visibility.
7. **Lognormal Tab 2 bridge missing (V1 B35)** — positivity constraint lost.
8. **σ symbol clash inside Beta (B50_noether_A)** — overloading.

## Method failures

- Tab-ID inversion (B50_noether_F) cost ~3 min; future Noether agents:
  confirm active tab from `textContent`, not button ID.
- Stacked-block `Xβ̂ = μ̂` caption is easy to miss in the textContent dump —
  use regex on the cleaned text.
- `preview_eval` text dump truncates around 3–4 k chars; bump `slice()` for
  Lognormal (full σ-submodel section ran past default cap).
- Rscript inline arithmetic non-negotiable for β̂_1 at `−0.04`-scale.

result: V3 Noether-lens audit complete; all three widgets fail their family contracts numerically (Beta `μ̂ = −0.95`, Lognormal scale-mix factor 4.16, Poisson missing `exp(η̂)` step); 6 NEW math defects B50_noether_A–F beyond V1/V2; report at `/Users/z3437171/Dropbox/Github Local/symbolizer/docs/dev-log/figure-audits/phase0a-families/V3-noether-lens-report.md`.
