---
name: variance-components-speak-biology
applies_to: variance_components surfacing + variance_partition()/icc() accessors + the three-views Index-tab variance panel
status: first-slice
last_review: 2026-05-29
pilot: docs/dev-log/pilots/variance-components-pilot.html (.png/.pdf) — maintainer-reviewed & approved
---

## Why this exists

A mixed model's payoff for a biologist is *where the variation lives* and *how
repeatable a trait is*. symbolizer computes the variance components and then
drops them: the pure-drmTMB variance builder carries only symbols (no numeric
estimates), and `explain()` / `model_card()` omit `variance_components`
entirely; there is no ICC / repeatability / partition / shrinkage prose
anywhere. This surface closes that gap, Gaussian-first, with a hard honesty
contract.

Approved by the maintainer via the v2 pilot. Decisions on record:
- Quantity is labelled **ICC** (repeatability as a secondary gloss).
- **Binomial / Bernoulli is first-class**, not deferred (proportion data is
  often binary): latent-scale ICC with the known residual constant.
- Visual: ship **both** renderers, **auto-select** by component count.

## Contract (what MUST hold)

1. **Numbers, not just symbols.** Every mixed-model extractor's
   `variance_components` tibble carries numeric `sd_estimate` + `var_estimate`.
   (lme4 + glmmTMB already do; drmTMB MUST be fixed to populate them.)
2. **Surfaced at the entry points.** `explain()` and `model_card()` include a
   "How the variation splits" section rendering `variance_components` (reusing
   the existing knit_print), whenever the fit has random effects.
3. **`variance_partition(x)`** — S3 generic + `.symbolized_model` method,
   mirroring `group_means()` / `group_slopes()` (family gate, classed
   honest-print tibble, `metadata$fit` retrieval). Returns one row per variance
   component with `variance`, `sd`, `pct` (proportion of total).
4. **`icc(x)`** — returns the ICC with an explicit `scale` attribute:
   - Gaussian-identity, single random intercept → **data-scale** ICC
     `σ²_g / (σ²_g + σ²_ε)` (a true proportion of variance).
   - Binomial logit → **latent-scale** ICC `σ²_g / (σ²_g + π²/3)`;
     binomial probit → `σ²_g / (σ²_g + 1)`. Labelled "latent scale"; MUST carry
     the caption "not a proportion of variance in the observed outcome."
   - Any other family, or >1 random-effect term → `NA` with a reason; the
     caller shows the table and a one-line "ICC not available on this scale yet."
5. **Widget panel** (three-views Index tab, beneath the random-effects glossary):
   a "where does the variation live?" bar + one sentence + the ICC line.
   Auto-select the bar: single stacked bar for exactly 2 components
   (between/within); per-component bars for 3+. Plain CSS `<div>`s — no JS,
   survives PDF export.
6. **Prose-only shrinkage caption** beside the worked-row BLUP (keyed on
   `has_re`); no numbers (numeric shrinkage deferred).
7. **Prose from CSV.** All sentences live in `inst/extdata/variance-readings.csv`
   (keyed by reading type + family-scale); none string-spliced in R.
8. **Point estimates only.** Every reading carries the point-estimate caveat and
   reuses the existing `few_re_levels` / `few_groups_wald` warnings.

## Counter-examples (do NOT)

- Data-scale ICC / partition % for Poisson or any GLMM without a known latent
  residual constant — mathematically empty; refuse it and show the table only.
- A latent-scale ICC printed without the "not observed-outcome variance" caption.
- Numeric shrinkage %, overdispersion verdicts, or a goodness-of-fit panel
  (VISION: symbolizer is not a fit oracle).
- ICC for a model with >1 random-effect term in this first slice (variance
  partitioning is still meaningful and shown; the single-number ICC is not).

## Slices (each RED→GREEN→REFACTOR, full suite green, committed)

- **S1 — keystone plumbing.** drmTMB variance builder populates
  `sd_estimate`/`var_estimate`; `explain()` + `model_card()` surface
  `variance_components`. Tests: drmTMB `sym$variance_components` has finite
  numbers; explain/model_card output includes the variance table for an RE fit.
- **S2 — accessors.** `variance_partition()` + `icc()`. Tests: Gaussian ICC
  correct & partition sums to 1; binomial latent ICC = σ²/(σ²+π²/3) (logit) and
  σ²/(σ²+1) (probit); Poisson → table + `NA` ICC + reason; honest-print.
- **S3 — widget panel.** Auto A/B bar + sentence + ICC line on the Index tab,
  prose from `variance-readings.csv`. Tests: Gaussian widget HTML has the bar +
  sentence + "ICC"; binomial shows a latent-scale-labelled ICC; Poisson shows
  the table + "not on this scale yet" and NO bar; 3-component fit uses per-
  component bars.
- **S4 — shrinkage caption.** Prose-only caption on the worked-row BLUP. Test:
  rendered worked row carries the partial-pooling caption when `has_re`.
- **S5 — GLMM repeatability demo (accessor-centric).** Give the bar + ICC a
  visible home on the live site, in the rptR / repeatability tradition the
  maintainer named (lme4 + glmmTMB GLMMs, *not* the drmTMB location-scale
  sections). Two units:
  1. **`knit_print` methods** for `symbolizer_variance_partition` and
     `symbolizer_icc` (`R/knit-print.R`, mirroring `group_means`/`group_slopes`).
     They emit `knitr::asis_output` HTML by **reusing the S3 helpers**
     (`vc_bar_stacked()` / `vc_bar_per_component()` / `vc_component_list()` for
     the partition; `vc_icc_line()` for the ICC) plus a compact numbers table
     built as inline HTML (so the whole emission is one `asis` HTML block
     alongside the bar — not a kable, which would not combine with raw HTML).
     This frees the bar from the drmTMB-only three-views widget: it now travels
     wherever the accessor is shown. No extractor changes; the lme4/glmmTMB
     Tab-3 widget gap is explicitly out of scope (not queued).
  2. **New vignette** `vignettes/symbolizer-variance-components.Rmd` ("Where the
     variation lives: ICC and repeatability"). Reuses the approved pilot
     examples (no new dependency; `rnorm`/`rbinom`): boldness measured
     repeatedly per individual and survival per nest. §1 Gaussian repeatability
     via `lmer` → `variance_partition()` (bar + table) + `icc()` (data-scale =
     repeatability). §2 binomial via `glmer` → `icc()` latent-scale + the "not
     observed-outcome variance" caption (the rptR `link`-scale approach). §3
     **same reading, different engine** via `glmmTMB` → `icc()` matches lme4
     (engine-agnostic). §4 brief honesty note (Poisson / >1 RE → `NA` + reason;
     point estimates only). Frames **ICC = repeatability**, nods to rptR
     (Nakagawa & Schielzeth). Registered in `_pkgdown.yml` ("Deep dives" group;
     placement adjustable).

  Tests (`test-variance-knit-print.R`): `knit_print(variance_partition(lmer))`
  is `asis` HTML with the bar markers + a numbers table; `knit_print(icc(glmer
  binomial))` contains "ICC" + "latent" + "observed outcome"; Poisson → "not
  available". Verification: vignette built locally + a visual check that the
  Gaussian repeatability bar renders live (the showcase the location-scale
  widgets could not provide).

## Verification

- `tools/` lints unchanged; new `tests/testthat/test-variance-*` files own each slice.
- Visual: rebuild one Gaussian + one binomial widget; confirm the panel renders
  and the binomial latent caption is present (preview / pilot-style check).
- Audited by the Pat (reader) + Noether (honesty) lenses on the rendered widget.

## Scope boundary: HTML-first; PDF parity deferred

S3 (the Index-tab panel) and S4 (the shrinkage caption) ship in the **HTML
widget only**. The PDF emitter currently drops the entire stacked-matrix BLUP
block and its captions (catalog B57–B64), so there is no block beside which to
place the panel or caption. Adding either to a PDF that omits the block would
itself be an inconsistency. PDF/HTML parity for the whole variance surface is
therefore one deferred follow-up, tied to the Pattern J rebuild (the single
`three_views_payload` formatter, v0.21.8 in the redo plan) that restores the
PDF stacked block. Until then the HTML widget is the source of truth for the
variance surface; the accessors (`variance_partition()` / `icc()`) are
package-public and scale-honest regardless of render target.
