# Rose reconciliation — symbolizer-families.html — 2026-05-26 overnight

Commit `3dd08e2` (branch `v0.21-redo`, built docs/ from v0.21.3).
Server `localhost:8766` serverId `c2648b71-cdbd-434d-b7ad-4fe48a1a9a1b`.
Widgets `sym-poisson-1779823408`, `sym-beta-1779823406`, `sym-lognormal-1779823404`.

## V-lens audit roster

| Lens | Words | Defects raised | Method-failure notes | Regex-cosplay risk? |
|---|---|---|---|---|
| V1 Florence | ~1600 | B31–B41 + Pattern P | scroll-fix; identical-IDs across copies; no PNG sink; no MathJax/KaTeX | None — `preview_inspect` px measurements (13 vs 146), `querySelectorAll` counts, textContent quotes. |
| V2 Pat | ~1300 | B42–B49 + RF1–RF4 + Patterns Q,R,S | reaffirmed V1 `tabs[i].click()`; paired widget DOM with H3 prose | None — textContent verbatim ("log of expected count" + `μ̂_1 = 0.936`); biological-impact reasoning explicit. |
| V3 Noether | ~1500 | B50_noether_A–F | tab-ID inversion (B50_F audit-blocker); `preview_eval` truncation; Rscript inline arithmetic | None — every divergence ratio recomputed (`exp(0.93529)=2.5480`, `4.115/0.466≈8.8`). |
| V4 Twin | ~1500 | B57_twin_A–G | PDF viewer iframe failed 3×, fell back to `pdftotext -layout` + grep — disclosed | None — fallback justified; column values absent in PDF verified by negative grep on `fig-*.txt`. |

All four pass the sniff test. No "looks fine" prose; every claim cites a
DOM measurement, textContent quote, or numerical recomputation.

## Unified deduplicated bug list

### Architectural roots (fix these first; many symptoms collapse)

**ROOT-1 — Family-blind worked-row template** (V1 B1 + V2 B48 + V3 implicit).
Tab 3 emits `y_1 = β̂_0 + β̂_1 x_1 + ε̂_1` regardless of family. ε̂ is
back-substituted as `y − Xβ̂`, so arithmetic balances mechanically (V3
spot-check: Poisson 0.9996, Beta 0.181, Lognormal 4.7844). Numerics
balance, semantics wrong. **Single highest-leverage fix on the page.**

**ROOT-2 — Renderer never consults the link function** (V3 B50_noether_B +
V1 B30/B45 + V2 B45). Hard-coded caption `Xβ̂ = μ̂` (should be `η̂` for
log/logit). Same root produces `ℝ^{100}` support for counts/proportions/
positives, and the missing `μ̂ = link^{-1}(η̂)` line on every Tab 3.

**ROOT-3 — Widget DOM emitted twice** (V1 B27 + B41). Identical IDs across
both copies; HTML validity violation; tab clicks don't sync; copy-2 shows
raw `$$\begin{aligned}` and `$\mathbb{R}^{100}$`. ~Half of all "intermittent"
defects observed across the four reports trace here.

**ROOT-4 — No per-family parameter glossary** (V2 B44 + V3 B50_noether_A).
Beta σ wears three names (precision, second Beta shape, residual SD) with
opposite directions (large σ → tighter vs wider). One σ glyph, two distinct
math meanings inside one widget.

### Per-widget per-tab defects

**Poisson** — Tab 1: `ℝ^{100}` for scalars/counts (B30,B45). Tab 2:
copy-2 desync. Tab 3: ROOT-1; `μ̂_1=0.936` is η̂ mislabelled, true count
rate 2.548, factor 2.72× (V3 B50_noether_D); missing `μ̂=exp(η̂)` step;
callout/worked-row contradiction (V2 B42); wrong caption `Xβ̂=μ̂` (V3 B50_B);
B24 brackets 13 vs 144–146 px; cosmetic `+ −0.0438`.

**Beta** — Tab 1: `μ_i σ_i` juxtaposed without separator (V1 B31); σ used
for precision where contract reserves φ, then re-used for σ-submodel —
one symbol, two meanings inside one widget (V3 B50_A). Tab 2:
`Beta(μ,σ)` is not a real parameterization (V1 B32); Z vs X_σ (V1 B33).
**Tab 3 PUBLICATION CATASTROPHE**: `μ̂_1 = −0.95` as predicted proportion
for `y ∈ (0,1)` (V1 B38, V2, V3) — real `inv_logit(−0.95) ≈ 0.279`.
σ̂_1=0.353 labelled "residual SD" but is actually φ; real response-scale
SD = 0.386; large φ → tight, label implies opposite (V1 B36, V2 B44, V3).
Missing `μ̂ = logistic(η̂)` step (V3 B50_E). ROOT-1.

**Lognormal** — Tab 1: μ_i glossed as "conditional mu of y" — actually
mean of log(y); effect-size error ≈ `exp(σ̂²/2)` (V1 B34, V2). Tab 2:
omits Lognormal half of bridge; matrix-tab reader can't tell this is
Lognormal (V1 B35). Tab 3 **SCALE-MIXED**: `4.78 = 2.01 + 2.77` mixes
response y with η̂ on log scale (V1 B37, V2, V3). Contract log-resid
−0.45; displayed +2.77 (opposite sign, ~6× magnitude). Missing
back-transform `μ̂ = exp(η̂ + σ̂²/2) = 8.36` (V3 B50_C). σ̂_1=0.466
labelled "residual SD" without "of log y"; reader off by ~8.8× (V3).
Z vs X_σ reapplies.

### Cross-cutting (all three widgets)

B1/B48/ROOT-1; B2 raw `$$\begin{aligned}` in copy 2
(`querySelectorAll('math').length === 0`); B3 `$\mathbb{R}^{100}$`
literal in copy-2 gloss; B24 brackets at ~9% of parent height; B27/B41
dup IDs + tab desync; B30/B45 `ℝ^{100}` regardless of family; B43/B50_B
gloss template for μ_i with three different μ semantics; B49/B50_C/D/E
missing response-scale prediction line.

### Page-level

RF1 "Coefficient reading on mu" lives in page prose, lost on widget paste.
RF2 one gloss template, three μ semantics. RF3 "1. Index" reads as
navigation, not "indexed notation". RF4 page prose contradicts widget
within one screen.

### PDF parity (page-wide)

B57_twin_A §3 stacked-matrix block dropped, all 3. B57_twin_B §3
caption invisible (reviewer can't challenge the wrong `Xβ̂=μ̂` claim).
B57_twin_C §2 where-gloss dropped, all 3. B57_twin_D §1 where-gloss
dropped, all 3. B57_twin_E Beta+Lognormal σ stacked-matrix dropped.
B57_twin_F σ-scalar 3-step collapse. B57_twin_G underbrace vs prose.
PDF carries ~30% of HTML by element count.

## Pattern attribution table

| Bug(s) | Pattern | Release |
|---|---|---|
| B1, B48, B50_C/D/E, B37, B38 (worked-row + back-transform) | **L → B** (link-aware) | v0.21.1 |
| B30, B34, B43, B45, B50_B (family-blind labels + caption + gloss) | **B** | v0.21.1 |
| B36, B44, B50_A (Beta σ / φ / SD) | **B + T** (NEW V3: per-family symbol allocation) | v0.21.1–2 |
| B32, B33, B35 (cross-tab inconsistency) | **P** (NEW V1: intra-widget consistency) | v0.21.2 |
| B42 (callout vs worked-row in one panel) | **Q** (NEW V2: intra-panel self-consistency) | v0.21.2 |
| B46, B49, RF1, RF4 (widget self-sufficient as paste) | **R** (NEW V2: paste-ready contract) | v0.22 |
| B47, RF3 (label vs content) | **S** (NEW V2) / K | v0.21.2 |
| B50_F (tab-ID inversion) | **T-meta** (NEW V3: ID-label lint) | v0.21.1 (audit-blocker) |
| B27, B41, B2, B3, B39, B40 (dup IDs, drift, raw LaTeX in copy 2) | **M** (HTML validity) | v0.21.1 |
| B24 (bracket stretch) | _pkgdown MathJax config (issue #12) | v0.21.1 |
| B57_twin_A–G (PDF parity) | **L** (PDF builder shares template state) | v0.21.1 |

New patterns ratified this audit: **P** (V1), **Q** (V2), **R** (V2),
**S** (V2), **T** (V3), **T-meta** (V3).

## V-agent misses (partial coverage, no missed classes)

- **V1 partial on B34**: tagged Lognormal-specific; V2 RF2 + V3 generalize
  — same gloss template applied to Poisson(E[y]), Beta(logit), Lognormal
  (E[log y]). Upgrade to B43.
- **V1 partial on B30**: logged Poisson Tab 1 only; V2 B45 generalizes to
  Beta `(0,1)^{100}` and Lognormal `(0,∞)^{100}`.
- **V1 partial on B36/B38**: caught Beta σ-label + μ̂=−0.95 as numerical
  errors; V3 sharpens to symbol-allocation root (σ ≠ φ; σ glyph used
  twice).
- **V2 partial on B50_B**: caught family-blind worked row (B48) but
  missed that the stacked-block caption `Xβ̂ = μ̂` carries the same scale
  error.
- **V3 partial on family-blind gloss**: ran contract per family without
  checking whether the gloss _template_ is shared across families (V2
  RF2 caught this).
- **V4 partial on B57_twin_B framing**: logged PDF caption drop but
  implied HTML caption was correct; V3 + V4 together: HTML has a wrong
  caption, PDF drops it (so PDF is "less wrong by omission").
- **V4 partial on σ-stacked block**: caught block drop (B57_twin_E) but
  didn't connect it to V3 B50_A (σ symbol overloading in HTML inherits
  into PDF).

No V-agent missed an entire defect class. All misses are partial coverage
on already-flagged defects.

## Severity rank (consolidated)

**High — publication-blocker:**
1. ROOT-1 / B1 / B48 — Gaussian-additive Tab 3 (all 3). Highest leverage.
2. B38 — Beta `μ̂_1=−0.95` as predicted proportion. **Embarrassment if pasted.**
3. B37 / B50_C — Lognormal scale-mix + missing back-transform; ~4.16× error.
4. B50_D — Poisson missing `μ̂=exp(η̂)`; factor 2.72×.
5. B36 / B44 / B50_A — Beta σ "residual SD" with three names, opposite directions.
6. B43 / B45 / RF2 — Family-blind gloss + support sets.
7. B50_B — Stacked-block caption `Xβ̂=μ̂` wrong for non-identity link.
8. B27 / B41 / B2 / B3 — Dup-DOM validity + raw-LaTeX leak in copy 2.
9. B57_twin_A / C / E — PDF drops matrix proof, §2 gloss, σ stacked block.
10. B32 / B35 — Beta non-standard form + Lognormal Tab 2 drops bridge.

**Medium — mental-model wobble:** B42, B33, B49, B57_twin_B/D, RF1/RF4, B47, B50_F.

**Low — typographic:** B24 (MathJax config), B31, B39, B40, B46 (v0.22), B57_twin_F/G.

## Rose's sign-off

Rose approved: `3dd08e2`; phase 0a-1 families.html audit found 64 unified
defects (catalog B1–B41 confirmed/extended + B42–B49 + B50_noether_A–F +
B57_twin_A–G + RF1–RF4, with new Patterns P, Q, R, S, T, T-meta); all 4
V-lenses returned without falling into regex-cosplay (every claim cites
`preview_inspect` measurements, textContent quotes, Rscript-recomputed
ratios, or negative grep evidence on `pdftotext` output); reports saved
at `docs/dev-log/figure-audits/phase0a-families/V{1,2,3,4}-*.md`; this
surface is cleared for the v0.21-redo pattern-fix releases per the
dependency graph (Patterns L/M ahead of B/N/P/Q/R/S/T), with B48 / ROOT-1
flagged as the single highest-leverage fix to land first in v0.21.1.
