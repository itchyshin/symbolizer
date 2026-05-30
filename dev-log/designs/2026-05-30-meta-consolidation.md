# Design — consolidate the two meta-analysis vignettes into one

Date: 2026-05-30
Status: design (awaiting maintainer sign-off → writing-plans)
Scope: page-consolidation #2 of the "make it nice" sequence (#1 CI, #2 meta merge,
#3 two front doors, #4 page-by-page audit; #5 CRAN deferred behind drmTMB/gllvmTMB→CRAN).

## Why this exists

The package ships **two** meta-analysis articles that cover the same ground:

- `symbolizer-meta.Rmd` (v0.16, 276L) — "Three faces: metafor / glmmTMB / drmTMB":
  one two-tier model, fit three ways, on a tiny **simulated** dataset. Face 2
  (glmmTMB `propto()`) is a long, honest digression concluding propto is *not*
  meta-analysis; Face 3 (drmTMB) is a **sketch only**.
- `symbolizer-meta-analysis.Rmd` (v0.22, 477L) — "Three flavors: a cross-package
  tour": traditional / phylogenetic / location-scale, on **real** data (BCG trials
  + the Pottier thermal subset), with the phylo three-views widget and an H²
  reading. §5 (location-scale) and §6 (reading biologically) are **scaffolds**
  ("lands in v0.22.2 / v0.22.3").

A reader landing on "Cross-package bridges" sees two near-duplicate meta articles.
Maintainer decision: **consolidate to one, completed article** ("really nice").

## Contract (what MUST hold)

1. **Base = `symbolizer-meta-analysis.Rmd`.** `symbolizer-meta.Rmd` is **retired**
   (`git rm`).
2. **§1–§4 kept as-is** (three-flavors intro; BCG data; traditional pooling with
   metafor-deep + glmmTMB/drmTMB-light + 5-package summary; phylogenetic multilevel
   with the drmTMB three-views widget + brms/metafor light + H² reading).
3. **§5 Location-scale is COMPLETED (no scaffold text survives):**
   - Deep Face: a **real, converging** drmTMB location-scale fit on the §4 Pottier
     thermal data — `mu ~ habitat`, `sigma ~ habitat + offset(0.5*log(vi))`.
   - **Salvaged from meta.Rmd:** the τ²-vs-σ "**α ≈ 2γ**" parameterization-gap table
     (metafor models τ² (variance); drmTMB/brms/glmmTMB model σ (SD); a metafor
     slope α ≈ 2× a drmTMB slope γ). This is the unique pedagogy worth keeping.
   - **Honest caveat (from meta.Rmd):** `offset(0.5*log(vi))` makes σ *proportional*
     to the sampling SE, not exactly equal, unless γ₀ is constrained — stated plainly.
   - Light Face: glmmTMB `dispformula = ~habitat, weights = 1/vi`.
   - **A three-views widget** for the location-scale fit (consistency with §4).
4. **§6 Reading biologically is WRITTEN (no scaffold text survives):** three readings
   grounded in the actual fitted numbers — (a) τ² (real disagreement) vs v_k
   (imprecision); (b) phylogenetic σ_p²A + the H² reading from §4; (c) moderator-driven
   τ²(x), γ read on the log-SD scale then exponentiated.
5. **propto correction** (from meta.Rmd) → a **one-line callout + cross-ref to
   `symbolizer-structural-dependence`** in the §3 glmmTMB Face. NOT the old long
   digression (propto is a structural-dependence topic, not a meta one).
6. **No "lands in v0.22.x" placeholders** anywhere in the final article.
7. **`_pkgdown.yml`**: remove `symbolizer-meta` from the "Cross-package bridges" group.
   Fix any cross-references (other vignettes / README) that pointed at `symbolizer-meta`.

## Fit-risk fallback (maintainer-directed)

The §5 drmTMB location-scale fit (`sigma ~ habitat + offset`) is the one real risk —
it may not converge cleanly on the thermal subset.

1. **Try drmTMB first** on the real Pottier thermal data.
2. **If it does not converge:** fall back to a small **simulated** location-scale
   dataset, **clearly labelled as illustrative**, AND
3. **File a convergence report for the drmTMB team** (a minimal reproducible example
   of the non-converging `sigma ~ x + offset(0.5*log(vi))` meta fit) so they can fix
   it upstream. Cross-package issue per the issue-ledger discipline.

## Verification

- The §5 fit converges (or the labelled-simulated fallback is in place + the drmTMB
  report is filed).
- The vignette **renders locally** (`pkgdown::build_articles(lazy = FALSE)` on this one
  article) with both widgets (§4 phylo, §5 location-scale) typeset under MathJax.
- `grep` the rendered + source article for "lands in v0.22" / "scaffold" / "Will land"
  → **zero** matches.
- `symbolizer-meta.Rmd` gone; `_pkgdown.yml` no longer lists it; no dangling links.
- Full `devtools::test()` still green (no test references symbolizer-meta).

## Out of scope

- Quarto migration (deferred behind consolidation + audit + CRAN-deps decision).
- The other consolidation (#3 ladder vs get-started) — separate brainstorm.
- Any extractor/code change (this is a vignette + pkgdown.yml change only, except
  possibly a fixture/data file for §5 if simulated fallback is used).
