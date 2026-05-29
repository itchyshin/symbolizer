# V1 Florence-lens audit — symbolizer-meta-analysis §4 (v0.22.1)
Date: 2026-05-28
Slice: v0.22.1
Target: http://localhost:8767/articles/symbolizer-meta-analysis.html

## Verdict
SHIP

## §4 subsection check
- 4.1 model in symbols (math blocks): **pass** — 5 math-bearing paragraphs, 7 `<math>` / MathJax elements rendered; no raw `$$`, no raw `\begin{`, no visible LaTeX escape leaks.
- 4.2 data: **pass** — `h3#data` found; first child paragraph begins "A 35-species, 164-effect subset of the Pottier et al. (2022) thermal acclimation dataset...".
- 4.3 drmTMB + widget: **pass** — `h3#face-1-drmtmb-deep-dive` found; widget ID `sym-phylomultilevel-1779974278` present; R code blocks render as `.downlit.sourceCode.r`; three tab buttons and three panels all present.
- 4.4 brms light: **pass** — `h3#face-2-brms-light-with-sesqrtvi-gr--cov-a` found; one highlighted `.downlit.sourceCode.r` block confirmed.
- 4.5 metafor light: **pass** — `h3#face-3-metaforrma-mv-light` found; one highlighted `.downlit.sourceCode.r` block confirmed.

## Widget §4.3 tab check
Widget ID: `sym-phylomultilevel-1779974278`
- Tab 1 (Index) `#tab-idx` → `#panel-idx`: **pass** — panel visible (`display: block`) on load; 22 `<math>`/MathJax elements rendered inside.
- Tab 2 (Matrix) `#tab-eq` → `#panel-eq`: **pass** — click toggles panel-eq to `display: block`, panel-idx to `display: none`; 25 math elements inside.
- Tab 3 (Equations with data) `#tab-mat` → `#panel-mat`: **pass** — click toggles panel-mat to `display: block`, others `display: none`; 15 math elements inside; no raw `$$`.

## Pattern checks
- Pattern M (dupe IDs): **pass** — zero duplicate IDs across page.
- Pattern AA (literal `\n` in tab button text): **pass** — button `innerHTML` contains no `\n` literal; the whitespace newline in `h3#face-2-brms-light-with-sesqrtvi-gr--cov-a` heading is a real newline (line wrap), not a string escape.
- Pattern N (raw `$$` leak): **pass** — tree-walker scan of all `Text` nodes found zero `$$` outside `<math>` / MathJax containers.
- Pattern A (escape leak `\_`): **pass** — one `Text` node in `<annotation>` (inside `<math>` in `#panel-mat`) contains `\_`; computed `display: none` on the annotation element; this is standard MathJax accessibility markup, not a visible text leak.

## §1-§3 regression check
- §1 (`h2#three-flavors-of-meta-analysis`): **pass** — present, has content, math renders (e.g. `τ²` in §1 intro).
- §2 (`h2#the-data-bcg-vaccine-efficacy-trials`): **pass** — present, has content.
- §3 (`h2#traditional-pooling`): **pass** — present, has content; §3.1 (`h3#the-model-in-symbols`) has 5 math elements; §3.2 (`h3#face-1-metaforrma-deep-dive`) has content and highlighted code blocks.

## Bugs found (numbered)
No defects found.
