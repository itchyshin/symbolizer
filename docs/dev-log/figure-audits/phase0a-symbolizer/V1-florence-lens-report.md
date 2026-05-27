# V1 (Florence-lens) report — `symbolizer.html`

**Article**: Get started with symbolizer (canonical first-contact vignette)
**URL**: `http://localhost:8766/articles/symbolizer.html`
**Viewport**: 1280×1200, server `symbolizer-pkgdown`
**Lens**: visual rendering, math typesetting, symbol consistency, layout, raw-LaTeX leaks
**Date**: 2026-05-26
**Defect ID convention**: `B89_symbolizer_<letter>`

---

## 1. Headline finding

**The marquee three-views widget is structurally broken on the get-started page.** First-time users cannot interact with the package's headline feature on the only page they will see first.

## 2. Page inventory

- Title: `Get started with symbolizer • symbolizer`
- `h1`: "Get started with symbolizer"
- 9 `h2` sections (matches sidebar "On this page")
- 1 three-views widget (`sym-sym-1779654875`), 3 panels (`eq` / `idx` / `mat`)
- 92 anchor links, 8 tables, 98 `<math>` elements, 0 MathJax/KaTeX scripts (MathML used — Pandoc native)
- Navbar version: **0.3.2**

---

## 3. New defects (`B89_symbolizer_*`)

### B89_symbolizer_A — **BLOCKER**: tab list rendered as raw HTML code block, widget unusable
**Severity**: Blocker for get-started flow.
**Location**: `Three views of your model` section, `#sym-sym-1779654875`.
**Evidence (DOM)**:
- `.sym-tablist` has ZERO `<button>` children.
- Its only child is `<pre><code>` containing the three button tags as **escaped text**.
- `preview_inspect` on `.sym-tablist pre`: 748×63px, `font-family: SFMono-Regular, Menlo, Monaco, ...` — visibly a code block.
- Pre textContent verbatim:
  ```
  <button type="button" class="sym-tab sym-active" role="tab" id="sym-sym-1779654875-tab-eq" aria-controls="sym-sym-1779654875-panel-eq" aria-selected="true" tabindex="0" data-tab="eq">...
  ```
- Panel inventory: `panel-eq` visible (height 165px, 1 `<math>`); `panel-idx` invisible (height 0); `panel-mat` invisible AND empty (0 `<math>`, 0 `<table>`).

**Why this matters**:
1. The reader sees raw `<button ...>` markup in a grey code block instead of three clickable tabs.
2. The horizontal overflow truncates each line at `aria-cont...` — the buttons appear "broken" even as text.
3. The Equation panel renders alone (with no apparent label tying it to the rest).
4. The very next paragraph reads: *"Tab 1 (Equation) is the structural contract... Tab 2 (Index) drops to per-observation form... Tab 3 (Matrix with data) actually stacks the numeric arrays."* The reader has no way to access Tab 2 or Tab 3.
5. `panel-mat` is empty even in DOM: even if a CSS/JS fix exposed it, a second defect would surface (no matrix content).

**Likely root cause** (lens-bounded — not investigated): the chunk producing `as_html_three_views(sym, head = 5, tail = 2)` is being treated by knitr/pandoc as text-output (`results = "markup"` or default) rather than `results = "asis"`. The tablist HTML is being placed inside a code block instead of being injected raw. This is a Phase 0a wiring regression. The widget itself is intact (the panels exist with content) — only the tablist wrapper is being escaped.

---

### B89_symbolizer_B — **MAJOR**: `parameter_interpretation()` table clips right edge without horizontal scroll
**Severity**: Major (data loss in visible rendering).
**Location**: `Parameter interpretation` section, table index 6 (the `scale = "all"` table).
**Evidence (preview_inspect / preview_eval)**:
- `table.scrollWidth = 1038px`, `table.clientWidth = 776px`. **262px clipped off the right.**
- Parent container `overflow-x: visible` — no scrollbar offered.
- Headers expected: `submodel, term_label, coefficient_role, estimate, link_scale_reading, natural_scale_reading, variance_scale_reading, biological_reading` (8 columns).
- Screenshot shows the right two columns clipped to fragments: "varianc…", "Residua…", "exp(2*0…". The full sentence "Residual variance multiplied by exp(2*0.0936) per unit" and the entire `biological_reading` column are partially or fully off-screen.

**Why this matters**: this is the section that demonstrates the package's interpretation-on-multiple-scales feature; the user cannot read the biology-grade output. The `scale = "biological"` table below (table 7) is narrower and renders fine — so the visible loss is asymmetric, and a newcomer might miss that `scale = "all"` carries four reading columns.

**Fix direction** (not in lens): wrap the gt/kable in a `.table-responsive` div or set `overflow-x: auto` on the wrapper.

---

### B89_symbolizer_C — **MINOR**: version drift between navbar (0.3.2), git tags (v0.20.2), and prose mentions
**Severity**: Minor (consumer-facing trust).
**Location**: navbar (`.version`), prose body, NEWS.md (off-page).
**Evidence**: textContent grep returns versions `0.3.2`, `0.1.0`, `0.3.1`, `0.2.2`, `2.1.3` (pkgdown). The navbar `.version` reads `0.3.2`. The repository's latest tagged release is `v0.20.2` (per project git log). The prose cites `0.1.0`, `0.3.1`, `0.2.2` as the milestone ladder; these are not consistent with the v0.20.x release lineage referenced in the parent project state.

**Why this matters**: A newcomer landing on `symbolizer.html` sees a `0.3.2` badge and a roadmap citing `0.1.0`-`0.3.1` milestones, while NEWS/git history references `v0.19`-`v0.20`. Likely the local DESCRIPTION carries `0.3.2` from an earlier branch state; out-of-lens whether this is intentional pre-release staging or a stale build. Flag only.

---

## 4. False alarms checked (and dismissed)

- **`\mathbb`, `\sigma`, `\begin{aligned}` strings inside `<annotation encoding="application/x-tex">`**: These are MathML semantic annotations and are **not rendered visually**. textContent picks them up but the user never sees them. Not a leak. (38 `\mathbb` instances, all in `<annotation>`.)
- **`#> \text{(index notation)}` etc. inside `<span class="co">`**: standard knitr comment output of a pedagogical `cat(as_latex(...))` chunk. The chunk is **intentional** — it shows what raw `as_latex()` returns. Not a leak.
- **`"$$" ... "$$"` in `cb5`**: source code being shown verbatim, not executed (`eval=FALSE` or `results='hide'` likely). Not a leak.
- **Tables overflowing parent**: only table 6 actually overflows; the other 7 tables are within bounds.

## 5. Get-started friction (lens-adjacent observations)

- The **elevator pitch is present and clean** (first section, "Why structured symbolic models"): contrasts with `equatiomatic`, names `symbolized_model` as the product.
- **Symbols are introduced in plain English first** in the glossary ("submodel: ... mean (mu), residual SD (sigma)"). Glyph forms appear later in code (`"W_i"`, `"T_i"`) and in MathML. No "first appearance of unexplained $\beta$" issue.
- **Code chunks execute** cleanly: a benign `Attaching package: 'drmTMB'` masking notice is shown but no errors, warnings, or stack traces leak into prose.
- **Function-name back-references work**: `as_latex()`, `symbolize()`, `equations()`, `as_html_three_views()`, `symbol_table()`, `assumption_table()`, `parameter_interpretation()`, `notation_bridge()` all link to `/reference/<fn>.html` and return HTTP 200 (spot-checked `as_latex.html`, `as_html_three_views.html`).
- **No `symbolizer-ladder` link** on this page — although `articles/symbolizer-ladder.html` 404s, the get-started article does not reference it. No broken xref here. (The broken xref the brief warned of must live on a different page.)
- **Hex logo** renders correctly top-right of intro block.

## 6. Math typesetting check

- 98 `<math display="block">` elements via Pandoc's MathML pipeline.
- Spot-checked: equation block in `panel-eq` renders `𝒘 | 𝝁, 𝝈 ~ 𝒩(𝝁, diag(𝝈²))` cleanly with bold-italic boldsymbol, `=` aligned in mtable, no bracket-stretch failure.
- Random-intercepts equation block renders `+u_{group(i)}` subscript and `~N(0, σ²_{group} I_6)` matrix form correctly in side-by-side `(index notation) ... (matrix notation)` layout.
- No oversized matrix brackets, no MathML namespace errors, no fallback to text.

## 7. Summary table

| ID | Severity | Section | One-line |
|----|----------|---------|----------|
| B89_symbolizer_A | Blocker | Three views of your model | tablist rendered as escaped HTML code block; widget tabs not interactive; panel-mat empty |
| B89_symbolizer_B | Major | Parameter interpretation | scale=all table clips 262px off right edge, no horizontal scroll |
| B89_symbolizer_C | Minor | Navbar / prose | version drift 0.3.2 vs v0.20.2 git lineage |

## 8. Recommendation to Rose / orchestrator

**Block release** of this article in its current state on the grounds of A alone. The get-started page is the single highest-leverage surface in the site, and the widget that demonstrates the entire selling point ("three views, one fit") is non-functional. The fix appears to be a chunk-option / `results='asis'` regression rather than a code defect in `as_html_three_views()` itself — verifiable by inspecting the `.Rmd` source.

B is independent and addressable with a `.table-responsive` wrapper.

C is informational only.

---

**Lens discipline**: All evidence is from `preview_inspect`, `preview_eval` DOM measurements, or `preview_screenshot` capture. No grep, no HTML source-file reads. The widget brokenness was discovered by DOM-walk after `widgetCount` returned a single widget with zero `<button>` descendants in its `.sym-tablist`.
