# Rose reconciliation — v0.21.6-redo gllvm article

**Date**: 2026-05-28
**Branch**: hotfix-pattern-O-matrix-truncation
**Article**: docs/articles/symbolizer-gllvm.html
**Slice**: v0.21.6-redo
**Reconciler**: Rose (the maintainer's discipline reviewer)

## V-agent inputs

| Agent | Lens | Verdict at first pass | Report |
|---|---|---|---|
| V1 | Florence (visual rendering) | **SHIP** (one minor) | `V1-florence-report.md` |
| V2 | Pat (reader flow + pedagogy) | **NEEDS FIXES** | `V2-pat-report.md` |
| V3 | Noether (math correctness) | **NEEDS FIXES** | `V3-noether-report.md` |
| V4 | Twin (PDF/HTML parity) | **SKIPPED** | No two-tier PDF yet (out of scope; tracked for v0.21.7-redo) |

## Findings × dispositions

### V1 (Florence)

| Bug | Severity | Disposition |
|---|---|---|
| **B-V1-1**: §7 σ_ε auto-suppression blockquote was missing the second-bullet text. | Minor | **Fixed in `a399904`.** Article §7 now carries both bullets verbatim from gllvmTMB's actual fit message. |

### V2 (Pat) and V3 (Noether) — shared blocker

| Bug | Severity | Disposition |
|---|---|---|
| **B-V2-1 / B-V3-1**: Widget 2's Tab 1 (Index) and Tab 2 (Matrix) were byte-identical to Widget 1's — no Λ_W, no Z_W, no Σ_W. The two-tier story was invisible until Tab 3. | **BLOCKER** | **Fixed in `a399904`.** Root cause: `sym$components$equation` and `sym$components$equation_matrix` (which feed Tab 1 and Tab 2 respectively) hardcoded the between-only equations in `glm_build_components()`. Extended both `glm_build_distribution()` and `glm_build_components()` to accept `has_within` + `d_W`; when true, the Λ_W and Σ_W terms render. Two new component rows (`latent_score_distribution_W`, `implied_within_unit_covariance`) emit in Tab 1's per-axis list. |

### V2 (Pat) — supporting concerns

| Bug | Severity | Disposition |
|---|---|---|
| **B-V2-2**: All six `sym-biology` slots carry the same generic lme4 sentence ("Each observation is normally distributed around a group-specific mean…"). No per-tier sentence (syndromes vs plasticity). | Important | **Deferred.** The biology caption is family-canonical and shared across all gllvm widgets in the current CSV. Per-tier biology captions would require a new template column. Slated for v0.21.7-redo (Pattern P intra-widget consistency). |
| **B-V2-3**: Ψ_B has near-zero entries (3.2e-08, 3.9e-16) in both widgets with no explanatory callout — a biologist may read these as a broken fit. | Important | **Partially mitigated.** §9 Identifiability paragraph in the rewrite mentions rotation, sign, AND σ_ε auto-suppression as expected behaviour. A standalone callout for Ψ near-zero is a separate fix — adding to v0.21.7-redo task list. |
| **F-V2-1**: §5 front-loads two-tier equations before Widget 1 introduces between-only. | Minor flow break | **Accepted as-is.** §5 is the model statement; presenting the full model before the simpler-fit widget mirrors textbook factor-analytic exposition. Reasonable people would disagree on order. |
| **F-V2-2**: Reader toggling between Widget 1 and Widget 2 Tabs 1/2 saw no change pre-fix. | **BLOCKER (now resolved)** | Resolved by the same fix as B-V2-1/B-V3-1. |
| **F-V2-3**: §8 doesn't map communality values back to §1's named traits (boldness, exploration, …). | Minor | **Deferred.** Easy one-sentence addition; slated for v0.21.7-redo. |

### V3 (Noether) — other math checks

| Check | Verdict |
|---|---|
| §3 univariate R formula | PASS |
| §4 parameter counting (14, 29, 58) | PASS |
| §5 long-form conditional variance | PASS |
| §5 wide-form mean / Σ_W | PASS |
| §6 Widget 1 Σ_B closure (element-wise to 1e-2) | PASS |
| §7 Widget 2 Σ_W closure (element-wise to 1e-3) | PASS |
| §7 R_t per-trait values | PASS |
| §8.1 communality formula c² + ψ* = 1 | PASS |
| §8.2 phenotypic-correlation decomposition | PASS |
| σ_ε auto-suppression to ~10⁻³ | PASS |

All ten math checks pass independent of the blocker fix.

## Verdict

**Rose approved**: `a399904` ships.

- All blocker-class bugs (B-V2-1 / B-V3-1) addressed.
- All math checks pass.
- All Pattern checks (M, AA, N, A) pass.
- Visual rendering ships cleanly per V1.
- 177 gllvm tests pass.
- DESCRIPTION + NEWS bumped.

Evidence: `docs/dev-log/figure-audits/v0.21.6-redo-gllvm/V1-florence-report.md`, `V2-pat-report.md`, `V3-noether-report.md`, this reconciliation report.

## Deferred follow-ups for v0.21.7-redo

1. Per-tier biology caption (Pat B-V2-2).
2. Ψ near-zero identifiability callout (Pat B-V2-3).
3. §8 sentence connecting trait labels (t1...t5) back to biological names (Pat F-V2-3).
4. PDF two-tier widget (Twin-lens V4 parity check; new `as_pdf_three_views` extension).
5. V4 Twin-lens audit once PDF lands.

## Cultural metric (the hard one)

`Rose approved: a399904; visual check found 1 blocker (B-V2-1 / B-V3-1, shared between Pat + Noether) + 1 minor (B-V1-1) + 3 deferred follow-ups. Blocker fixed in same commit. Evidence: docs/dev-log/figure-audits/v0.21.6-redo-gllvm/*.md`
