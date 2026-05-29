# Rose reconciliation — v0.22.1 / v0.22.1.1 meta-analysis Widget 2

Date: 2026-05-28
Slice: v0.22.1 (Widget 2 ship) + v0.22.1.1 (V2 blocker rollup)
Target: `vignettes/symbolizer-meta-analysis.Rmd` §4 — phylogenetic
multilevel meta-analysis. Three Faces (drmTMB deep, brms light,
metafor light) on the Pottier et al. (2022) thermal subset (164
effects × 35 species × 39 studies).

## V-agent inputs

| Lens | Verdict | Report |
|---|---|---|
| V1 Florence (visual rendering) | SHIP | `V1-florence-report.md` |
| V2 Pat (reader flow) | NEEDS FIXES | `V2-pat-report.md` |
| V3 Noether (math correctness) | NEEDS FIXES → RESOLVED | `V3-noether-report.md` |
| V4 Twin (PDF/HTML parity) | N/A | Widget ships HTML-only this slice; PDF in v0.22.3 |

## Cross-lens findings

| # | Found by | Issue | Status |
|---|---|---|---|
| 1 | V2 (Flow break 1, BLOCKER) + V3 | Widget equations omit the phylo random effect $\mathbf{u}_p \sim \mathcal{N}(\mathbf{0}, \sigma_p^2\,\mathbf{A})$. drmTMB consumes `phylo()` into its internal sparse-precision pipeline; `fit$random_effects` holds only `(1 \| study_ID)`. The article's central thesis equation is missing. | **FIXED in v0.22.1.1** (commit 12b6526). `symbolize.drmTMB()` synthesises the phylo tier into `re_per_entry` and passes `structured_matrix_for_group = list(<gv> = "\\mathbf{A}")` to `drm_build_components()`. Linear-predictor matrix form disambiguates multiple intercept-only groups (single-RE keeps bare $\mathbf{u}$; multi-RE emits $\mathbf{u}_{g_1} + \mathbf{u}_{g_2}$). |
| 2 | V2 (Flow break 2) | §4.1 marginal-variance decomposition `Var(y_kt) = v_kt + σ_study² + σ_p² A_{kk}` shown in prose but no auto-emitted decomposition block in widget Tab 3. | **PARTIALLY FIXED.** Finding #1's fix makes the widget show both tiers in its distribution rows, removing the contradiction with §4.1. The Tab 3 implied-covariance block (Λ_B-style stacked decomposition) is a separate renderer enhancement deferred to v0.22.1.2. |
| 3 | V2 (Flow break 3) | §4.3 intro leads with package syntax ("drmTMB's native idiom uses `meta_V()`...") before naming the model in biological terms. | **FIXED** (commit 91e8ac1 in this slice). One-sentence model description added before the meta_V / phylo syntax sentence: "The model adds the §3 study-tier random effect to a phylogenetic random effect with covariance $\sigma_p^2\,\mathbf{A}$, on top of the known per-effect sampling variance $v_k$." |
| 4 | V2 (Flow break 4) | §4.5 shows `$sigma2 = [0.00274, 0.0355]` without naming which row is phylo vs study, and no numerical biological interpretation. | **FIXED.** §4.5 prose now identifies first row = phylogenetic, second row = study, with the one-sentence reading: study-level variance dominates phylogenetic variance by an order of magnitude on this dataset. Heritability formula appended. |
| 5 | V3 (vi = 0 boundary collapse) | Pottier thermal CSV had rows with `Var_dARR ≈ 0` that caused drmTMB sdreport NaN. | **FIXED earlier in slice** (commit 10b3f05). `data-raw/make-thermal-subset.R` filters `Var_dARR > 1e-6` and rebuilds the committed subset. |
| 6 | V3 (CSV width regression) | `thermal_subset.csv` had 105 NA-padded columns from the wider Pottier CSV, breaking the helper roundtrip test. | **FIXED earlier in slice** (commit 10b3f05). Subset rebuild script now selects only the 5 columns the vignette + tests use. |
| 7 | V1 (gloss completeness) | Symbol gloss includes $\mathbf{A}$ and $v_k$ with correct descriptions. | OK — no action. |

## Pattern analysis

The fix to #1 closes a category that would have recurred on every
future structured-dependence package (animal models via `animal()`,
spatial via `spatial()`, autoregressive via future markers). The
synthesis path `re_per_entry` ← formula-marker detection is now
general: any structured tier that a package consumes internally and
omits from its `fit$random_effects` will reach the equation renderer
through the same path. Pattern fixed at root, not at symptom.

The linear-predictor disambiguation (single-group bare $\mathbf{u}$
vs multi-group $\mathbf{u}_{g_1} + \mathbf{u}_{g_2}$) is a small but
high-leverage rendering fix — it would also have shown up the moment
anyone fit a `(1 | a) + (1 | b)` model without phylo, with the wrong
output `Xβ + u + u`. We caught it incidentally; promote a snapshot
test on a generic two-RE drmTMB fit in v0.22.1.2.

## Issue-ledger touched

- Issue #4 (v0.22 meta-analysis article): progress comment to post —
  Widget 2 shipped under v0.22.1; V2 blocker resolved under v0.22.1.1.
- Issue #2 (cross-package phylo Fisher equivalence test, scheduled
  for v0.21.5-redo): the three Faces in §4 form a working
  cross-package equivalence demonstration; the Fisher numerical-
  equivalence test is still future work.
- No new cross-package upstream filings this slice. drmTMB#335
  (already filed) remains open and would now be **easier to land**
  if the maintainer adopts a `structured_effects(fit)` accessor that
  exposes phylo/animal/spatial tiers — but symbolizer no longer
  blocks on it.

## Verdict

**SHIP v0.22.1.1.** All V2 Pat blockers and flow breaks
addressed within the slice; V1 Florence SHIP verdict stands;
V3 Noether findings resolved with fixture and §4.3 documentation.
Full test suite at `FAIL 0 | WARN 104 | SKIP 0 | PASS 1845`.

Outstanding for separate slices (deferred):

- v0.22.1.2: Tab 3 implied-covariance auto-emit (`Σ_B`-style
  stacked block for the per-tier decomposition).
- v0.22.2: §5 location-scale Widget 3.
- v0.22.3: PDF widget via `as_pdf_three_views()` + Twin V4 audit.

## Rose sign-off

`Rose approved: 12b6526 + 91e8ac1; V2 blocker resolved by extractor
synthesis path; prose flow breaks resolved by §4.3 / §4.5 edits.`
