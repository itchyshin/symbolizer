# Phase 0a multi-agent visual check — master summary

Date: 2026-05-26 overnight
Branch: `v0.21-redo` at commit 884684f (build state: v0.21.3 pkgdown output, gitignore-fixed)
Auditor team: V1 Florence-lens, V2 Pat-lens, V3 Noether-lens, V4 Twin-lens, Rose reconciliation

## Scope of this report

Phase 0a audited the deployed v0.21.3 pkgdown site to enumerate every user-visible defect before the rebuild begins. This summary rolls up the per-surface V-agent reports into one durable artifact you can grep at 5am.

## Surfaces audited

| # | Surface | V1 | V2 | V3 | V4 | Rose | New defects | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | symbolizer-structural-dependence.html | maintainer ✓ + ✓ overnight | — | — | — | — | B72–B79 (+ B2–B30 from maintainer) | Deepest manual + V1 — has 2 widgets; canonical phylo article |
| 2 | symbolizer-families.html | ✓ | ✓ | ✓ | ✓ | ✓ approved | B31–B41 (V1), B42–B49+RF1–RF4 (V2), B50–B56 (V3), B57–B64 (V4) | Full 4-lens sweep with Rose sign-off; 3 widgets, 3 PDFs |
| 3 | symbolizer-drmtmb.html | ✓ | — | — | — | — | B65–B71 | Flat vignette, no widgets; different bug class |
| 4 | symbolizer-factors.html | ✓ | — | — | — | — | B80–B82 | No widgets; factor-symbol specific bugs |
| 5 | symbolizer-gllvm.html | ✓ | — | — | — | — | B83–B88 | Most defect-dense — v0.21.4 residue, ghost-widget, raw LaTeX everywhere |
| 6 | symbolizer.html (get-started) | ✓ | — | — | — | — | B89–B91 | P0 BLOCKER: widget rendered as escaped HTML on first-contact page |
| 7 | symbolizer-roadmap.html | ✓ | — | — | — | — | B92–B96 | Rendering clean but ~6 versions stale; 4 claim/code drift findings |
| 8 | index.html | ✓ | — | — | — | — | B97–B101 | pkgdown build incomplete — ladder + meta vignettes never built |

**Not yet audited (lower priority for v0.21.1 foundation gate)**: compare.html, large.html, vs-others.html, gllvm-design.html, README rendered output.

## Catalog dimensions

- **101 defects cataloged** (B1–B101) plus **4 reader-flow defects** (RF1–RF4). Started at 23 (maintainer manual on structural-dependence); each lens added on average ~9 defects.
- **34 pattern families** (A–HH). Patterns L–HH all came from this audit; A–K predate it.
- **8 surfaces audited** of an original 12-surface Phase 0a list.

## Catalog growth timeline

| Phase | Defects | Patterns | Audit step |
|---|---|---|---|
| Pre-audit (maintainer manual structural-dependence) | B1–B23 | A–K | 2026-05-26 manual |
| Plan revision 4 (+ maintainer screenshot at families) | B24–B30 | L–O | Mid-day |
| V1 families | +B31–B41 | + P | First sub-agent dispatch |
| V2 families | +B42–B49, RF1–RF4 | + Q, R, S | Pat reader-flow |
| V3 families | +B50–B56 | + T | Noether math correctness |
| V4 families | +B57–B64 | (refines J) | Twin PDF/HTML parity |
| V1 drmtmb | +B65–B71 | + U, V, W, X, Y | Different surface class |
| V1 struct-dep (post-maintainer) | +B72–B79 | + Z, AA | assumption_table dupe + heading slug |
| V1 factors | +B80–B82 | + BB, CC | Inline-R + transform deparse |
| V1 gllvm | +B83–B88 | + DD, EE | Ghost widget + n/d contradictions |
| V1 symbolizer (get-started) | +B89–B91 | + FF | P0 BLOCKER (escaped widget) |
| V1 roadmap | +B92–B96 | — (folds under A + F) | Claim/code drift |
| V1 index | +B97–B101 | + GG, HH | pkgdown build incompleteness |

## Architectural roots (highest leverage; fix collapses dependents)

Rose's reconciliation on families.html named 4 roots; this audit confirms 3 more apply package-wide:

1. **B48 / Pattern B — family-blind worked-row template.** Every Tab 3 emits `y_1 = β̂_0 + β̂_1 x_1 + ε̂_1` regardless of family/link. Fixes B1, B36, B37, B38, B42, B49, B50–B54, B56.
2. **B27 / Pattern M — widget DOM duplicated with reused IDs.** Triggers B2, B39, B40, B41, B76, B84, B85, B86.
3. **No MathJax loaded / Pattern L.** Triggers B24, B67, B68, B71 (every bracket-stretch + `\mathrm{}` letter-spacing across every article).
4. **Pattern N — gloss prose with unrendered LaTeX source.** Triggers B3, B17, B28, B30, B43, B45, B65 (across multiple articles).
5. **Pattern Z — rendered + raw LaTeX duplicate emission.** Triggers B72, B73, B74, B85 (especially gllvm Tab 3).
6. **Pattern F — claim/code drift across releases.** Triggers B91, B93, B94, B95, B96 (roadmap stale).
7. **Pattern GG — pkgdown build doesn't realize `_pkgdown.yml`.** Triggers B97, B98, B99 (and downstream B9, B101).

## Per-surface P0 (publication-blocker) defects

| Surface | P0 defect | Reader impact |
|---|---|---|
| symbolizer.html (get-started) | **B89** — three-views widget renders as escaped `<pre><code>` instead of interactive tabs | First-time-user impression killer; widget is the package's headline feature |
| symbolizer-gllvm.html | **B27 SEVERE manifestation** — ghost widget; click copy 2 to flip copy 1 | ~2000 px of dead content; broken interactivity |
| symbolizer-families.html Beta widget | **B38** — Tab 3 shows `μ̂_1 = −0.95` as predicted of `y ∈ (0,1)` | Off the support; reader pastes wrong probability into Methods |
| symbolizer-families.html Lognormal widget | **B37** — Tab 3 scale-mixes `log(μ̂)` with `y`: `4.78 − 2.01 = 2.77` is incoherent | Off by factor 4.16× on response-scale prediction |
| symbolizer-families.html every widget | **B1** — Gaussian-additive template universal | Every non-Gaussian fit shows wrong arithmetic |
| symbolizer-structural-dependence.html every widget | **B19** + **B77** | Wall of zeros (Z one-hot truncation hides 1s) + u-vector renders all 60 rows |
| index.html | **B97** — ladder + meta vignettes never built | "Get started" navbar link points to wrong vignette |

## Pattern ↔ release-gate dependency graph (updated)

```
v0.20.3 (foundation: discipline scaffold + docs/specs/ + tools/)
  ├─ Pattern GG / HH (pkgdown build completeness + CSS overlap)
  └─ Issue-ledger discipline (#11)
        │
        ▼
v0.21.0(redo) — drmTMB phylo() real parser (Pattern C seed)
        │
        ▼
v0.21.1(redo) — FOUNDATION GATE
  ├─ Pattern L (MathJax in _pkgdown.yml) — closes B24, B67, B68, B71
  ├─ Pattern M + FF (widget DOM dedup + chunk options) — closes B27, B39, B40, B41, B76, B84–B86, B89
  ├─ Pattern B (link-aware worked row) — closes B1, B36–B38, B42, B48–B54, B56
  ├─ Pattern A (math/text helpers + `_` escape) — closes B3, B17, B81, B92
  ├─ Pattern D (vector/matrix truncation contract) — closes B5, B19, B20, B77
  ├─ Pattern K (number formatting) — closes B21
  ├─ Pattern H (identifiability footnote) — closes B15
  ├─ Pattern I (uncertainty disclaimer) — closes B16
  ├─ Pattern S (tab labels) — closes B47
  ├─ Pattern W (table-responsive wrap) — closes B69, B90
  └─ Pattern Z (rendered+raw LaTeX dedup) — closes B72, B73, B74, B85
        │
        ▼
v0.21.2(redo) — CONSISTENCY GATE
  ├─ Pattern N (gloss prose math_fragments split) — closes B28, B43, B45
  ├─ Pattern G (notation_bridge single source) — closes B14, B33
  ├─ Pattern P (intra-widget consistency) — closes B32, B33, B35
  ├─ Pattern Q (intra-panel self-consistency) — closes B42, B44
  ├─ Pattern R (paste-ready contract) — closes B46, RF1
  ├─ Pattern T (per-family symbol allocation) — closes B50, B55
  ├─ Pattern U (comma-drop lint) — closes B65
  └─ Pattern X (ASCII-math placeholders) — closes B70
        │
        ├─► v0.21.3(redo) — structural-dependence single widget
        │     ├─ Pattern O (column-truncation + abbreviation balance) — closes B25, B26, B29, B31, B78
        │     ├─ Pattern AA (Rmd heading slug) — closes B75, B79
        │     ├─ Pattern BB (un-evaluated inline-R) — closes B80
        │     ├─ Pattern DD (article-level n/d contradictions) — closes B87, B88, B12
        │     └─ Pattern EE (prose vs code) — closes B88
        │
        ├─► v0.21.4(redo) — metafor widget
        ├─► v0.21.5(redo) — MCMCglmm widget (closes #9)
        ├─► v0.21.6(redo) — brms + glmmTMB widgets
        │
        ├─► v0.21.7(redo) — families article + Pattern V (column-width regression) + Pattern CC (transform deparse) — closes B66, B82
        │
        └─► v0.21.8(redo) — PDF + Copy-LaTeX
              └─ Pattern J full enforcement — closes B13, B22, B23, B57–B64
```

## Methodology validation (the "regex-cosplay" sniff)

All V-agents in Phase 0a passed the regex-cosplay sniff test (their reports are evidence-backed, not source-grep-derived). Rose's sign-off on families.html explicitly checked this:

- V1 evidence: `preview_inspect` numerical measurements (bracket vs table heights, container widths, table scrollWidth vs clientWidth) — 100% of B24/B67/B68/B69/B71/B78/B90 claims cite specific px values.
- V2 evidence: `textContent` quotes paired with biologist-impact reasoning — every claim cites a specific rendered string.
- V3 evidence: explicit numerical computation against the per-family contract — every claim shows the displayed number, the contract value, and the divergence ratio.
- V4 evidence: HTML quote + PDF quote per parity claim. PDF viewer MCP iframe failed; V4 transparently fell back to `pdftotext -layout` and noted that as a method failure.

**Method failures recorded for the next audit run** (across reports):
1. `preview_screenshot` requires `scrollY === 0` for body-transform trick to work.
2. No PNG save endpoint on `preview_screenshot`; screenshots live only in agent context unless transcribed.
3. Both DOM copies need clicking via `querySelectorAll(...)[i]`, not `click()` on `#id` which only hits copy 1.
4. PDF viewer MCP iframe sometimes fails to mount in background sessions; `pdftotext` is a reliable fallback for content-presence checks.
5. Tab-button IDs may be inverted relative to labels (B55) — verify by reading `textContent` of clicked tab, not by trusting ID slug.

These belong in `docs/specs/visual-check.md` once Phase 0d lands.

## What this enables for Phase 1 (v0.20.3 discipline-scaffold release)

Phase 1 ships when:
- Every pattern A–HH has a `docs/specs/<name>.md` file at status `first-slice` or higher.
- Every `tools/check-*.R` script invoked by `make release-check` exists and exits 0 on the v0.20.2 baseline (clean / no-op).
- `_pkgdown.yml` switches to `template.math-rendering: mathjax` — but the test that asserts this lands in Phase 0d as part of `docs/specs/math-rendering.md`.

## What this defers to later phases

- **V2/V3/V4 lens audits on the remaining 7 surfaces** — for now, single-V1 coverage is enough to discover patterns. Per-surface depth audits happen during each pattern-fix release as the regression gate.
- **README rendered output, model_card output, as_dag output, simulate_recipe output** — non-widget surfaces. Hold for Phase 1 release-checklist QA.
- **compare.html, large.html, vs-others.html, gllvm-design.html** — additional surfaces. Hold for completeness pass before v0.21.1(redo) gate.
- **PDF parity on every PDF** — V4 only audited the 3 families PDFs. fig-meta-phylo.pdf, fig-mcmc-phylo.pdf, fig-gllvm.pdf pending Twin-lens audits during their respective release prep.

## Rose's overnight sign-off

For surfaces with full V1+V2+V3+V4 (families.html): Rose previously signed off at commit 3dd08e2.

For single-V1 surfaces (drmtmb, struct-dep, factors, gllvm, symbolizer, roadmap, index): each V1 report cites preview-tool evidence (no regex cosplay) per the sniff test above. **I (Rose) endorse the V1 single-lens audits as sufficient for the catalog at this stage**; depth-audits on these surfaces will happen during each pattern-fix release. Sign-off line:

```
Rose approved: 884684f; Phase 0a V1 sweep (single-lens) of 7 additional surfaces (drmtmb, struct-dep, factors, gllvm, symbolizer, roadmap, index) completed; all evidence-backed; catalog at B1–B101 + RF1–RF4; patterns A–HH (34); architectural roots ranked; release-gate dependency graph updated; surfaces are cleared for the v0.21-redo pattern-fix release plan per the dependency graph above.
```

End of Phase 0a master summary. Next phase: Phase 0b (audit v0.20.2 baseline state), Phase 0c (paired Noether+Rose source-code audit), Phase 0d (write docs/specs/).
