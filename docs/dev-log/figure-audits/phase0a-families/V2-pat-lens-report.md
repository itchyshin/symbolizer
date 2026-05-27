# V2 Pat-lens audit — symbolizer-families.html — 2026-05-26 overnight

Auditor: V2 (Pat = ecology/evolution PhD student who wants to write
**one Methods-section sentence** per fitted model). Builds on V1 report
(B1–B41 + Pattern P), does not re-derive.

## Methodology

`preview_list` → serverId `c2648b71-cdbd-434d-b7ad-4fe48a1a9a1b`, running;
viewport 1280×1200; V1 report read first. Widgets visited (first DOM
copy): Poisson `sym-poisson-1779823408`, Beta `sym-beta-1779823406`,
Lognormal `sym-lognormal-1779823404`. All three tabs read for each widget
plus surrounding H3 prose, "Coefficient reading on mu" lines, and
"Picking a family" rules-of-thumb. Screenshots of Tab 3 for all three.

## Per-widget reading

### Poisson widget

**One-sentence takeaway I could write:** "I fitted a Poisson regression
of `y_i` on continuous `x_i` with a log link." That's all. I cannot
state what `β_1` *means biologically* using only the widget — the rate-
ratio reading `exp(β)` lives in page prose, never inside the widget.

**Tab-story drift:** Tabs 1–2 say "log link Poisson". Tab 3's worked row
silently switches to Gaussian-additive form: `1 = 0.955 + −0.0438 × 0.45
+ (0.0643)`, `= 0.936 (μ̂_1)`. Log link disappears.

**Biologist confusion points (textContent + why):**

1. *Callout vs worked row* (Tab 3): blue callout reads "Each observation
   is a count; the log of the expected count may shift with the
   predictors." Worked row below says `μ̂_1 = 0.936`. If log link is real,
   `μ̂_1 = exp(0.936) ≈ 2.55`. Two pieces on screen are arithmetically
   incompatible.
2. *`y_i — response variable ℝ^{100}`* in gloss: counts are `ℕ^{100}`,
   not `ℝ^{100}`. Biologist who has just been told "counts" sees `ℝ`
   and worries the widget forgot the family.
3. *`β_0, β_1 — mu submodel coefficients`*: spelled in English, never
   linked to `exp(β)` rate-ratio reading.

**Methods-paste:** No. Tab 1 is paste-quality only because it shows
math, not numbers. Tab 3 would paste a wrong predicted count.

**Reader-impact of V1 findings:** B1 → biologist quotes 0.936 as count
prediction. B30 → mild support-set worry.

### Beta widget

**One-sentence takeaway:** *I cannot write one.* σ wears three names
across one widget (precision in prose, second Beta shape in Tab 1
formula, residual SD in Tab 3 label) and two opposite directions
(large = tighter vs large = wider). Tab 2's `Beta(μ, σ)` is not a
parameterization that exists. I'd need to leave the package and check
a textbook — defeats the package's purpose.

**Tab-story drift:** the worst of the three. Three parameterizations
across three tabs (V1 B32 + B36), three names for σ (new).

**Biologist confusion points:**

1. *`μ̂_1 = -0.95` as "predicted" for `y ∈ (0,1)`* (Tab 3): textContent
   reads `0.175 = -0.824 + -0.0874 × 1.43 + (1.13) = -0.95 (μ̂_1)
   (predicted) + (1.13) (residual)`. A predicted *proportion* of -0.95.
   Real prediction is `inv_logit(-0.95) ≈ 0.279`. Nothing on the page
   says this. **Publication-grade embarrassing if pasted.**
2. *Three names for σ inside one widget* — precision (prose), Beta
   second shape (Tab 1), residual SD (Tab 3 textContent: "σ̂_1 =
   exp(-1.04) ≈ 0.353 (predicted residual SD for observation 1)").
3. *Direction contradicts:* prose says "large σ → tighter", SD reading
   says "large σ → wider". Opposite biological stories.
4. *`y_i ∈ ℝ^{100}`* for a proportion — should be `(0,1)^{100}`.

**Methods-paste:** No panel is correct + complete enough to paste.

**Reader-impact of V1 findings:** B36 → wrong concept in Methods. B38 →
negative predicted probability in results. B32 → biologist doesn't know
what σ is.

### Lognormal widget

**One-sentence takeaway:** "I *think* the package fitted
`log(y_i) ~ N(μ_i, σ_i²)` with `μ_i = β_0 + β_1 x_i`." Not confident,
because Tab 3 prints `y_1 = 4.78` and `μ̂_1 = 2.01` side-by-side on the
same response-scale equation, which is a scale mix the widget never
acknowledges.

**Tab-story drift:** Tab 1 clean (Lognormal ⇔ Normal on log y). Tab 2
omits the Lognormal half (V1 B35). Tab 3 mixes response and log scales
in one arithmetic line (V1 B37).

**Biologist confusion points:**

1. *Scale-mixed worked row:* `4.78 = 2.02 + −0.0136 × 0.409 + (2.77) =
   2.01 (μ̂_1) + (2.77) (residual)`. Pat reads "predicted y is 2.01,
   residual is 2.77" — that's Gaussian on `y`, not Lognormal on
   `log(y)`. The arithmetic balances numerically (it always does) but
   means nothing biologically.
2. *μ glossed as "conditional mu of y"* — textContent shared with
   Poisson and Beta. For Lognormal, μ_i = E[log y], not E[y]. The
   distinction matters: `exp(β)` is the geometric-mean effect, not the
   arithmetic-mean effect; arithmetic mean needs `+ σ²/2`. A biologist
   computing effect sizes from the widget is silently wrong by a
   factor of `exp(σ̂²/2)`.
3. *"Predicted residual SD"* without "of log y" qualifier: σ_1 ≈ 0.466
   is correct on log scale but is NOT the residual SD of y.
4. *`y_i ∈ ℝ^{100}`* for `y > 0` — should be `(0,∞)^{100}`.

**Methods-paste:** Tab 1 only.

**Reader-impact of V1 findings:** B37 → wrong predictions / residuals.
B34 → multiplicative-effect calculation off by `exp(σ²/2)`. B35 →
matrix-tab readers miss this is Lognormal.

## Page-level reader-flow defects

**RF1 — "Coefficient reading on mu" is orphan prose, not in widget.**
The most useful biological reading on the page lives outside the widget
and is lost on export/paste. textContent (Poisson):
> "Coefficient reading on mu: exp(beta) is the rate ratio — a
> multiplicative effect on the expected count."

**RF2 — One gloss template, three different μ semantics, no warning.**
"μ_i — conditional mu of y ℝ^{100}" appears identically for Poisson
(E[y]), Beta (logit), Lognormal (E[log y]). The biologist assumes one
reading, gets three different truths.

**RF3 — "1. Index" tab label reads as navigation.** "Index" in a paper
usually means table-of-contents. Here it means *indexed notation*.
Friction first time, especially without the subtitle.

**RF4 — Surrounding prose contradicts widget within one screen.** Beta
prose: "precision via log link, large sigma → tighter". Widget label
below: "residual SD". Reader sees both at once.

## "Picking a family" prose vs widget evidence

Six rules of thumb at the end of the page are well-written and Pat can
use them. But the widgets *do not demonstrate* the rules:

- Rule 3 (lognormal for right-skewed positive Y): widget shows
  arithmetic, no geometric-mean story, no `exp(β)`.
- Rule 4 (Beta for proportions in (0,1)): widget shows `μ̂_1 = -0.95`,
  which is outside (0,1). Reader could conclude Beta is broken.
- Rule 5 (Poisson for variance = mean): widget never shows the variance-
  mean relationship; can't be used to check fit.

Fix (out of Pat's scope, flagged for Rose): each widget should carry a
one-line biological reading mirroring the page prose.

## NEW defects (Pat-lens, not in V1's B1–B41)

| ID | Description | Pattern |
|---|---|---|
| B42 | Per-panel callout/preamble contradicts worked-row arithmetic in the same panel (Poisson Tab 3: "log of expected count" + `μ̂_1 = 0.936` raw). | NEW Q: intra-panel self-consistency (sibling of V1 Pattern P which covers cross-tab) |
| B43 | Gloss "μ_i — conditional mu of y" used identically for Poisson/Beta/Lognormal despite three different semantics. | Pattern B (family-aware labels), upgrade of B34. |
| B44 | Single Beta σ wears three concept names (precision in prose, second shape in Tab 1, residual SD in Tab 3). | NEW Q + B. Root: no single parameter glossary per family. |
| B45 | Response support always `ℝ^{100}` regardless of family (Poisson should be `ℕ^{100}`, Beta `(0,1)^{100}`, Lognormal `(0,∞)^{100}`). | Pattern B, upgrade of B30. |
| B46 | "Coefficient reading on mu" is page prose, not inside the widget — lost on export/paste. | NEW R: paste-ready contract (widget self-sufficient as Methods paste). |
| B47 | Tab label "1. Index" reads as navigation, not "indexed notation". Cheap rename. | NEW S: label-vs-content match (or Pattern K). |
| B48 | Worked-row template `y_1 = β̂_0 + β̂_1 x_1 + ε̂_1` is silently *family-blind*: numerically self-consistent, biologically meaningless for non-Gaussian. **Architectural root cause of B1.** | Root of Pattern B. |
| B49 | Tab 3 lacks a "what scale is μ̂ on?" line. Should add: Poisson `μ̂_1 = exp(η̂_1) ≈ 2.55 (predicted count)`; Beta `μ̂_1 = inv_logit(η̂_1) ≈ 0.279 (predicted proportion)`; Lognormal `E[y\|x] = exp(μ̂ + σ̂²/2) ≈ 8.30 (geometric mean)`. | Pattern B + NEW R. |

## Severity rank (Rose, please use this in reconciliation)

**High** (biologist quotes wrong number in Methods):

1. B48 / B1 — additive Gaussian-template worked row.
2. B49 — no response-scale prediction in Tab 3.
3. B43 / B45 — family-blind gloss.
4. B44 — Beta σ three names.
5. B42 — callout vs worked-row contradiction.

**Medium** (mental-model wobble, probably caught before publication):

6. B46 — coefficient reading outside widget.
7. RF4 — prose-vs-widget contradiction.
8. B47 — "1. Index" ambiguous.

**Pat-lens insight:** **B48 is the architectural root**. The worked-row
template emits a Gaussian-shape equation regardless of family because
it doesn't know what family it's rendering. Fixing the template to
become link-aware and emit a response-scale prediction line resolves
B1, B42, B49 entirely, and weakens B43 / B45 by half. Rose should
treat B48 as the single highest-leverage fix.

## Method failures

V1's tab-click note (`tabs[i].click()`) reaffirmed. Body-transform + tab
click must be ordered: click first, then position. Critically: Pat-lens
requires reading H3 prose immediately above each widget together with
widget textContent — RF4 / B42 / B44 only surfaced from that pairing.
Future Pat-lens agents: don't tunnel-vision into the widget DOM.

result: V2 Pat-lens audit complete; 8 new reader-flow defects B42–B49,
4 page-level RF defects, severity-ranked. B48 (family-blind worked-row
template) is the single-highest-leverage fix. Report at
`/Users/z3437171/Dropbox/Github Local/symbolizer/docs/dev-log/figure-audits/phase0a-families/V2-pat-lens-report.md`.
