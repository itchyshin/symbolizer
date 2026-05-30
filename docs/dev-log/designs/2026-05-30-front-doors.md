# Design — #3 front-doors differentiation (get-started vs ladder)

Date: 2026-05-30
Status: design approved (maintainer) → writing-plans → execute
Scope: page-consolidation #3 of the "make it nice" sequence. Differentiate the two
overlapping intros into distinct, non-overlapping jobs (maintainer chose
"differentiate, keep both" over merging).

## Why

`symbolizer.Rmd` (get-started) and `symbolizer-ladder.Rmd` both walk
`body_mass ~ temperature` on simulated data and both end at a drmTMB location-scale
fit + a three-views section. They differ only in organizing principle — get-started
by **feature** (glossary → symbolize → equations → three-views → tables →
interpretation → RE → scope), ladder by **model complexity** (lm → +factor → +RE →
location-scale). A newcomer hitting the "Get started" group sees two intro-flavored
articles, with the climb currently listed before the quickstart.

## Contract (what MUST hold)

1. **`symbolizer.Rmd` becomes a lean, install-free quickstart (~5-min read):**
   - 1-paragraph "why" + the short glossary (kept — orienting for a newcomer).
   - ONE example fit: **base-R `stats::glm(... , family = poisson)`** on small
     simulated count data (zero non-CRAN install; log link).
   - The **three headline outputs** on that one fit:
     (a) the equation (`equations()` / `as_latex()`),
     (b) the **three-views widget** (`as_html_three_views()` — full Tab 3; glm has a
         design matrix),
     (c) `parameter_interpretation()` (the rate-ratio reading — log-link payoff).
   - A tightened **"Where next"** linking ladder (the climb), families, factors,
     reference, roadmap.
   - **CUT** (content relocated, not deleted): the standalone symbol/assumption/
     formula-table section (→ drmtmb/factors articles + reference), the
     random-intercepts section (→ ladder Rung 3 + variance-components article), the
     long "what's supported/planned" section (→ roadmap, one-liner + link).
2. **`symbolizer-ladder.Rmd` stays the concepts climb**, with two small tweaks:
   - a one-line "new here? skim the quickstart first" pointer near the top;
   - its "Where to next" must not treat get-started as a peer (no circular loop).
3. **`_pkgdown.yml`** "Get started" group order: `symbolizer` (quickstart) **first**,
   then `symbolizer-ladder`.

## Verification

- Quickstart renders (`rmarkdown::render`): the glm Poisson fit → the 3 outputs;
  the widget is present and MathJax-typeset in the pkgdown build.
- Ladder still renders; no broken cross-links (`vignette("...")` targets resolve).
- Full `devtools::test()` green.
- The quickstart is visibly a short read (no leftover feature-tour bloat); the two
  articles have distinct jobs.

## Out of scope

- #4 page-by-page audit (next).
- Quarto migration (deferred).
- Any extractor/code change (vignette + `_pkgdown.yml` edits only).
