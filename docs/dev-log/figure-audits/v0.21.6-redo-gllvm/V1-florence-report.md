# V1 Florence-lens audit — symbolizer-gllvm.html (v0.21.6-redo)

Audit date: 2026-05-28
Auditor: V1 Florence-lens (visual rendering only)
Target: http://localhost:8767/articles/symbolizer-gllvm.html
Slice: v0.21.6-redo
Reference spec: docs/dev-log/designs/2026-05-28-gllvm-syndromes-integrated-plasticity.md

## Summary verdict

SHIP

No blockers. All math renders (MathML, native browser). All widgets functional.
One minor observation (see B-V1-1) about blockquote completeness relative to spec §5.3.

## Findings

### Section-by-section

- §1 — pass. Prose clean; inline MathML renders (MathMLMath nodes confirmed in a11y tree); Λ_B and Λ_W notation present.
- §2 — pass. Code block present; prose clean; no math issues.
- §3 — pass. 9 math elements (2 display: h=24, h=43). Both display blocks render correctly: `y_{ij} = μ + u_i + e_{ij}` and `R = σ²_u/(σ²_u + σ²_e)`.
- §4 — pass. 26 math elements, all inline, all rendering (h≥11). Parameter-counting argument `T(T+1)/2` present.
- §5 — pass. Side-by-side flexbox layout confirmed (`display:flex; flex-wrap:wrap`). Long-form and wide-form panels render in a 776px-wide container. All display math in §5 renders (4 display blocks, positive heights).
- §6 — pass. Intro prose present; widget container `sym-syndromes-1779936656` with 3 tab buttons found.
- §7 — pass. Intro prose present; σ_ε auto-suppression blockquote present at correct DOM position (after §7 h2, before widget). Widget 2 container `sym-twotier-1779936656` found.
- §8 — pass. All 3 display math blocks render: communality (h=45), repeatability R_t (h=40), phenotypic-correlation decomposition r_{P,tm} (h=20).
- §9 — pass. 12 math elements, all rendering (h≥11). Λ identifiability content present.
- §10 — pass. 8 math elements all rendering. glmmTMB bridge content present.
- §11 — pass. 7 math elements all rendering.

### Widget-by-widget × tab

- Widget 1 (`sym-syndromes-1779936656`), Tab 1 (Index) — pass. Display on load; 1 display block (h=119) + 9 inline math. `\mathbb{R}^{40×5}` renders as proper MathML inline (h=14). Σ_B decomposition present.
- Widget 1, Tab 2 (Matrix) — pass. Hidden on load (display:none); after click shows display:block. Display math h=105 confirmed post-click. Index form equations clean.
- Widget 1, Tab 3 (Equations with data) — pass. After click: 3 display blocks: aligned-equation (h=99), loadings bmatrix (h=170), Σ_B bmatrix (h=113). No overflow (max width 776px < viewport 1280px).
- Widget 2, Tab 1 (Index) — pass. 17 math elements. σ_ε is present in the Widget 2 index equations (expected: the index form still carries σ_ε for completeness; auto-suppression prose is in the §7 preamble, not inside the widget panel).
- Widget 2, Tab 2 (Matrix) — pass. Not directly inspected post-click (Widget 2 Tab 3 was last activated), but DOM structure and hidden math elements confirmed identical shape to Widget 1 Tab 2 (Σ_W annotation present).
- Widget 2, Tab 3 (Equations with data) — pass. 4 display blocks post-click: aligned-equation (h=99), loadings bmatrix (h=170), Σ_B bmatrix (h=113), Σ_W bmatrix (h=113). Per-trait repeatability row R_t = [0.747, 0.555, 0.836, 0.62, 0.785] renders as inline MathML (h=13) — 5 values confirmed.

### Pattern checks

- Pattern A (escape leaks): PASS. No `\mathbb`, `\begin{`, `\bmatrix` as visible text. MathML `<annotation>` elements carrying raw LaTeX are all `display:none`.
- Pattern M (duplicate IDs): PASS. `querySelectorAll("[id]")` dedup check returns empty array `[]`.
- Pattern AA (literal \\n): PASS. Tab labels contain only real whitespace newlines (JSON: `"\n▸1. Index\n"`), not the two-character `\n` sequence. `hasLiteralBackslashN: false` confirmed.
- Pattern N (raw $$ text leaks): PASS. Body innerText contains no `$$\begin` sequences. 22 display math blocks and 206 inline math blocks confirmed as proper MathML elements with positive bounding boxes.

### Bugs found (numbered)

B-V1-1: The σ_ε auto-suppression blockquote (§7) renders as a **single paragraph** containing only the first sentence of the spec §5.3 message ("ℹ Auto-suppressing sigma_eps: unique(0 + trait | obs) is at the per-row level, so it already absorbs the observation residual."). The spec §5.3 specifies a two-part blockquote: the second bullet ("Fixed at 0.00111 (~1/1000 of sd(y)) to keep the Gaussian density well-defined; the row-level residual variance is fully captured by unique().") is absent from the rendered page. Non-blocking — the present text is accurate — but the spec calls for both sentences. Selector: `blockquote > p` (sole `<p>` in the document's only blockquote, DOM position at y≈6518px).

## Evidence

- `querySelectorAll("[id]")` dedup eval → `[]` (Pattern M pass)
- `querySelectorAll(".sym-tab").map(t => JSON.stringify(t.textContent))` → `['"\\n▸1. Index\\n"', ...]` (Pattern AA pass — real whitespace, not escape sequence)
- `document.body.innerText` checked for `$$\begin`, `\mathbb`, `\begin{` — none found (Patterns N, A pass)
- `querySelectorAll('math[display="block"]')` → 22 elements, 18 with positive height (4 in hidden widget panels = 0 height until tab-click, expected)
- Tab click eval: `sym-syndromes-1779936656-tab-eq.click()` → panel-eq `display:block`, math h=105; `tab-mat.click()` → panel-mat `display:block`, Σ_B bmatrix h=113
- Widget 2 Tab 3 click: Σ_B h=113, Σ_W h=113, R_t inline h=13, annotation `[0.747, 0.555, 0.836, 0.62, 0.785]` confirmed
- Active tab style: `color: rgb(138, 31, 34)` (brand red) on `rgb(255,255,255)` — adequate contrast. Inactive tabs: `rgb(107, 114, 128)` on transparent (readable against white body)
- Math rendering engine: native browser MathML (Pandoc output). No MathJax/KaTeX script tags in `<head>`. All `<annotation encoding="application/x-tex">` elements have `display:none`.
- Blockquote full text confirmed via `document.querySelector('blockquote').textContent` — one paragraph only, missing spec §5.3 second bullet.
