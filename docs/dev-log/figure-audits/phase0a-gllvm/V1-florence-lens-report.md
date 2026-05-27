# V1 Florence-lens audit — symbolizer-gllvm.html — 2026-05-26 overnight

## Methodology

- `preview_list` confirmed `symbolizer-pkgdown` on `localhost:8766`.
  Viewport set to 1280x1200 via `preview_resize`.
- Navigated to `http://localhost:8766/articles/symbolizer-gllvm.html`.
- h1 = `Latent variables in ecology: a gllvmTMB worked example`.
- `[id^=sym-]` query returned 16 elements / 8 unique ids — every widget
  id is emitted **twice**.
- `window.MathJax` and `window.katex` both falsy. Page uses pandoc-style
  native MathML: 134 `<annotation>` elements, all with computed
  `display: none`. So the `\boldsymbol{\Lambda}_B`-style raw fallback
  that appears in `textContent` is visually hidden for inline math
  (B79 occurs only in slug/TOC text, not in the body).
- `<math>` element count: widget-1 = 48, widget-2 = 0 (duplicate is
  unrendered).

## Per-widget / per-section findings

**Widget — `sym-gllvm-1779825333` (Three views of the GLLVM fit)**

Two complete copies of the same widget HTML live as siblings inside
`div.section.level3#three-views-of-the-gllvm-fit`. They are 16 px apart
visually, ~2000 px in document flow.

Tab labels (both copies): `▸1. Index`, `2. Matrix`,
`3. Equations with data` — three tabs total.

Internal ID inversion (B55):

| Tab label             | tab `id` suffix | `aria-controls` |
|-----------------------|-----------------|-----------------|
| 1. Index              | `tab-idx`       | `panel-idx`     |
| 2. Matrix             | `tab-eq`        | `panel-eq`      |
| 3. Equations with data| `tab-mat`       | `panel-mat`     |

The `-eq` suffix belongs on the "Equations with data" tab; the `-mat`
suffix on the "Matrix" tab. Labels and contents match, so the
inversion is **code-internal only** and not user-visible — but flag
for cleanup before any tooling parses these slugs.

Per-tab math element counts (widget 1 only — widget 2 has zero rendered
math everywhere):

- panel-idx: 17 `<math>`, 0 raw `$$` — clean.
- panel-eq (Matrix): 13 `<math>`, 0 raw `$$` — clean.
- panel-mat (Equations with data): 18 `<math>`, **12 raw `$$`** — the
  six numerical matrix displays (Λ_B, S_B, Σ_B, Λ_W, S_W, Σ_W) are all
  literal LaTeX in the rendered page, e.g.
  `$$ \boldsymbol{\Lambda}_{B} \;=\; \begin{bmatrix} 0.371 \\ 0.525
  \\ 0.729 \\ 0.6 \\ 0.145 \end{bmatrix}\qquad
  \text{(5 \times 1 loadings)} $$`. Visually identifiable inside a
  pale-red bordered box. This is the headline visual defect of the
  article.

**Section 7 heading**: `7. Identifiability gotchas: rotation and sign
of 𝚲_B\boldsymbol{\Lambda}_B`. The raw LaTeX is visible in the **TOC**
("On this page" rail) and the slug
`identifiability-gotchas-rotation-and-sign-of-boldsymbollambda_b`. The
heading itself displays only the rendered glyph because pkgdown CSS
hides the `<annotation>` element. Slug + TOC carry the leak.

**Sections 1, 2, 4, 6, 8, 9**: math typography renders correctly via
native MathML (subscripts, italics, sigma, bold ALL display as
expected). No raw LaTeX visible in prose body.

## GLLVM-specific bug confirmation

- **B7 tier mismatch — ABSENT**. Single-tier widget (one model, both
  B / W tiers shown side-by-side in panel-mat). Tabs 1, 2, 3 all
  describe the same fit. `tier1` / `tier2` markers don't appear.
- **B8 `\times` inside `\text{}` — PRESENT and visible**.
  `\text{(5 \times 1 loadings)}` and
  `\text{(5 \times 5 diagonal of trait-specific variances)}` appear as
  literal text in the panel-mat numerical-matrix captions. Visible
  because panel-mat math displays don't render at all (see panel-mat
  finding above). 31 raw `\times` occurrences in body textContent.
- **B12 terminology drift — PRESENT and broad**. Four overlapping
  terms for the same level of analysis:
  - Data sim: `n_ind`, `n_sess`.
  - Section 1 prose: "fish", "individuals", "sessions".
  - Formula args: `unit = "individual"`, `unit_obs = "session_id"`.
  - API accessors: `level = "unit"`, `level = "unit_obs"`.
  - Math/gloss: B / W tier names, "between-unit", "within-unit".
  
  Plus a **dimension-experimental-design contradiction**:
  - Section 1 says "forty fish, three times each" → 40 × 3 = 120 obs.
  - Section 2 sets `n_ind = 60`, `n_sess = 4` → 240 obs.
  - panel-idx gloss declares `y ∈ ℝ^{60×5}` → 60 rows in matrix form.
  - panel-mat narrative says "Showing first 5 and last 2 rows of
    **n = 1000**".
  
  Four different population sizes (40, 60, 1000) in one article.

- **Rank-1 vs rank-2 narrative contradiction (B12-class)** — Section 4
  prose: "`latent(0 + trait | individual, d = 2)` is the
  between-individual reduced-rank decomposition with **two latent
  axes**" — immediately followed by the actual code chunk
  `latent(0 + trait | individual, d = 1)`. Prose claims d=2, fit uses
  d=1. The Section 2 truth puts traits 1-3 on one axis and 4-5 on a
  second axis (rank-2 truth), so a d=1 fit collapses the simulation.
  Section 6 then asserts `d_B = 1` and discusses sign-only
  identifiability; Section 7 discusses rotation at d>1. Article
  cannot decide what rank it is fitting.

## Catalog cross-reference

- **B1** (family / link blindness): NOT APPLICABLE — Gaussian family is
  named in prose and code; no link-confusion in panels.
- **B5 / B19 / B20 / B77** (vector / matrix truncation contract): NOT
  APPLICABLE in the strict sense — all matrices shown are 5×1 or 5×5
  with all entries present. No "... rows omitted" markers. The
  panel-mat caption "first 5 and last 2 rows of n = 1000" is a
  caption-vs-content mismatch (B82-class), not vector truncation.
- **B7** (GLLVM tier mismatch): ABSENT (see above).
- **B8** (`\times` in `\text{}`): **PRESENT**.
- **B12** (terminology flip-flop, rank flip-flop): **PRESENT** (broad).
- **B24** (no MathJax / brackets don't stretch): **PRESENT**
  environmental. Tab-3 matrices don't render at all — raw `$$...$$`.
- **B25 / B78** (container overflow): mild — panel-mat raw `$$` boxes
  wrap their literal LaTeX inside `.math.display` (`overflow-x:
  visible`). No scrollbar at 1280 px.
- **B27** (DOM duplication): **PRESENT and SEVERE**. Widget HTML
  emitted twice. Widget 2 has zero `<math>` rendering AND its tab
  clicks bind by `getElementById`, which resolves to widget 1 — so
  clicking widget-2 tabs activates widget-1 tabs. Non-interactive
  ghost UI plus 2000+ px of duplicate vertical content.
- **B28** (gloss prose unrendered LaTeX): gloss in good widget renders
  fine, except `\boldsymbol{\Psi}_{B}` row ends in **`diagonal ^{5 }`**
  — orphan superscript with no base, see new defect below.
- **B48 / B56**: NOT APPLICABLE.
- **B55** (tab id inversion): **PRESENT internally** — IDs swapped
  (eq↔mat) but labels and contents match.
- **B71** (`\mathrm{}` letter-spacing): ABSENT observable damage —
  `\mathrm{Normal}(...)` renders as expected via MathML.
- **B72 / B73 / B74** (rendered + raw duplicate emission): **PRESENT
  and very visible**: widget 2 entirely raw LaTeX; widget 1 panel-mat
  matrices raw LaTeX (12 `$$` blocks); section 8's `\mathbf{Y}=...`
  renders fine, isolating the bug to widget-emitted dollar-delimited
  math.
- **B75 / B79** (heading slug raw-LaTeX leak): **PRESENT** — section
  7 slug `…boldsymbollambda_b`, TOC link shows raw LaTeX.
- **B80** (inline-R leak): ABSENT — no un-evaluated `r expr` patterns.
- **B81** (visible `\_` escape): ABSENT — no literal `\_` in body.
- **B82** (transform deparse `scale()` / `log()` / `I()`): NOT
  APPLICABLE — no transforms in this model.

## NEW defects (not in B1–B82)

### B83_gllvm_A — orphan `^{5 }` in Ψ gloss row

Both panel-idx and panel-eq, last gloss row, displays:
```
ψ_{B,t}  — between-unit unique variance per trait  diagonal  ^{5 }
```
Visible visually (see widget-1 screenshot near `^{5 }`). The intended
shape annotation `\mathbb{R}^{5}` lost its base `\mathbb{R}` somewhere
in the rendering pipeline; only the raw-text superscript fragment
remained. Pattern: **broken-superscript-no-base** — extends B81
underscore-escape family to a new sibling. Likely root cause:
`format_shape()` or analogous helper emits `\mathbb{R}^{5}` for the
"diagonal" shape but the gloss-row column then splits text vs math
incorrectly, leaving `^{5 }` outside the math span. Suggest **Pattern
DD: broken-shape-annotation**.

### B83_gllvm_B — duplicate-widget binding ghost

The duplicate widget injected by the renderer shares all element IDs
with the original. The widget's tab-switch JS (likely
`document.getElementById('…-tab-eq').addEventListener('click', …)` or
similar) binds only the first match, so the visible second widget's
tab buttons are non-functional and clicking them appears to do nothing
locally while silently flipping the first widget's tabs 2000 px above.
This is **B27 plus a JS-binding failure**. Suggest extension of
Pattern A (DOM-dupe family) into a new sub-pattern: **Pattern
DD-bind-by-id-only**.

### B83_gllvm_C — duplicate-widget pandoc bypass

Widget 1 has 48 `<math>` elements; widget 2 has zero. Same source,
two emission sites — only widget 1 was post-processed by pandoc/mathml.
Duplicate is injected after the pandoc pass. Explains why widget 2
displays raw `$$\begin{aligned}...$$`. Pattern:
**B27-shadow-emission**.

### B83_gllvm_D — em-dash pandoc bypass on duplicate

Widget 1: " – " (en dash). Widget 2: " -- " (double hyphen). Pandoc
smart-punct ran on widget 1 only. Cosmetic but corroborates B83_gllvm_C.

### B83_gllvm_E — n-value contradiction (40 / 60 / 1000)

Sub-finding of B12: panel-mat caption "first 5 and last 2 rows of
n = 1000" vs 5×1 / 5×5 matrices vs gloss `y ∈ ℝ^{60×5}`. Three
population sizes in one widget.

### B83_gllvm_F — d_B prose vs code mismatch

Section 4 prose says `d = 2`; code chunk uses `d = 1`. Structural
description vs structural code mismatch. Suggest **Pattern EE:
prose-code-disagreement**.

## Method failures

None — all evidence is from `preview_eval`, `preview_inspect`, or
`preview_screenshot`. No grep / cat / Read on built HTML source was
used. One ToolSearch round-trip to load the preview tool schemas.
