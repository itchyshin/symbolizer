## Cross-article visual sweep — 2026-05-27

Auditor: Claude (sub-agent), read-only, no source edits.
Preview server: `http://localhost:8767/` (serving `symbolizer-hotfix/docs/`).
Viewport: 1400x900 for top screenshots; 1400x9000-10000 for full-page when needed.

Methodology per article:
- Navigate with cache-bust `?t=<rand>`.
- Run JS counts on `innerText` (what users see) and DOM querySelectorAll.
- Click each `button.sym-tab` and capture the visible panel text (excluding hidden `<annotation>` MathML siblings) to confirm no raw LaTeX leak.
- Scan headings and right-sidebar `a.nav-link` for math source bleeding into TOC.
- Take real screenshots (full-page when needed).

A note on what is NOT a defect: every `<math>` element has a hidden `<annotation encoding="application/x-tex">` child. That node is `display:none` and not visible to readers — it exists for screen-reader/copy-paste fidelity. Counts based on `textContent` will include it; counts based on `innerText` will not. This report only flags leaks that are actually rendered to readers.

---

### 1. symbolizer-families.html
- raw LaTeX leaks (innerText): 0
- tablists: 3 (expected 3)
- buttons: 9 (expected 9)
- DOM `id` collisions: none
- mathml elements: 103
- Widgets: `sym-lognormal-1779920170`, `sym-beta-1779920172`, `sym-poisson-1779920174`
- Tab-1 (Index) rendering: PASS for all 3 widgets — MathML rendered, no raw `\begin{aligned}` visible, 8-12 `<math>` per panel.
- Tab-2 (Matrix) rendering: PASS for all 3 widgets — MathML rendered, 9-15 `<math>` per panel.
- Tab-3 (Equations with data) rendering: PASS for all 3 widgets — MathML rendered, 5-10 `<math>` per panel.
- Visual screenshot (full-page): all three widgets visible with proper tab list and rendered math.
- Verdict: PASS. The maintainer's fix (removing `htmltools::HTML()` wrap) landed correctly.

### 2. symbolizer-drmtmb.html
- raw LaTeX leaks (innerText): 0
- tablists: 1 (expected 1)
- buttons: 3 (expected 3)
- DOM `id` collisions: none
- mathml elements: 160
- Widget: `sym-sym-1779918289`
- Tab-1 rendering: PASS — 15 `<math>` elements, panel height 606px, content begins "What happens for each observation i ...".
- Tab-2 rendering: PASS — 18 `<math>`, height 624px.
- Tab-3 rendering: PASS — 10 `<math>`, height 1091px.
- Verdict: PASS.

### 3. symbolizer-factors.html
- raw LaTeX leaks (innerText): 0
- tablists: 1 (expected 1)
- buttons: 3 (expected 3)
- DOM `id` collisions: none
- mathml elements: 231
- Widget: `sym-sym-1779918294`
- Tab-1 rendering: PASS — 13 `<math>`, height 523px.
- Tab-2 rendering: PASS — 15 `<math>`, height 510px.
- Tab-3 rendering: PASS — 10 `<math>`, height 1066px.
- Top-of-page screenshot: hex logo, headings, TOC all clean.
- Verdict: PASS.

### 4. symbolizer-ladder.html
- raw LaTeX leaks (innerText): 0
- tablists: 1 (expected 1)
- buttons: 3 (expected 3)
- DOM `id` collisions: none
- mathml elements: 93
- Widget: `sym-sym-1779918314`
- Tab-1 rendering: PASS — 16 `<math>`, height 637px.
- Tab-2 rendering: PASS — 18 `<math>`, height 624px.
- Tab-3 rendering: PASS — 10 `<math>`, height 1114px.
- Top-of-page screenshot: clean.
- Verdict: PASS.

### 5. symbolizer.html (Get started)
- raw LaTeX leaks (innerText): `\begin{aligned}` = 2, `\mathbf{` = 3, `\boldsymbol{` = 8, `$$` = 4
  - **These are NOT defects** — they appear inside `<span class="co">` (code-comment output) and `<span class="st">` (string literals) inside R code chunks. The article calls `cat(as_latex(sym, notation = "both"))` and displays the printed LaTeX with `#>` prefix as intentional pedagogy. Verified by tracing each match into an enclosing `<div class="sourceCode">`.
- tablists: 1 (expected 1)
- buttons: 3 (expected 3)
- pre_with_sym_html (B89 marker): **false** — the widget DOM is real, NOT escaped as text.
- DOM `id` collisions: none
- mathml elements: 135
- Widget: `sym-sym-1779918344`
- Tab-1 rendering: PASS — 12 `<math>`, height 515px.
- Tab-2 rendering: PASS — 15 `<math>`, height 533px.
- Tab-3 rendering: PASS — 10 `<math>`, height 1090px.
- Top-of-page screenshot: title, hex, TOC ("Why structured...", "A short glossary", ...) all clean.
- Verdict: PASS — B89 NOT present.

### 6. symbolizer-gllvm.html
- raw LaTeX leaks (innerText): `\boldsymbol{` = 1
- tablists: 0 (expected 0 — no widget yet)
- DOM `id` collisions: none
- mathml elements: 66
- **DEFECT FOUND** (real, user-visible):
  - Location: right-sidebar `a.nav-link[href="#identifiability-gotchas-rotation-and-sign-of-boldsymbollambda_b"]`
  - Visible text: `7. Identifiability gotchas: rotation and sign of 𝚲B\boldsymbol{\Lambda}_B`
  - Visible at viewport position approx. top=361px, width=306px, height=89px (TOC sidebar at 1400x900).
  - Root cause: the H2 heading body uses inline math `$\boldsymbol{\Lambda}_B$`. The H2 renders correctly (MathML with hidden `<annotation>`), but pkgdown's TOC generator extracts the heading via `textContent` (or analogous DOM walk), which includes the annotation source. The TOC `<a class="nav-link">` then contains the raw LaTeX as a plain text node with no `<math>` wrapper, so it IS visible to users.
  - Visual screenshot confirmed: top-right "On this page" list shows `Λ_B\boldsymbol{\Lambda}_B` as literal text.
- Verdict: FAIL — TOC raw-LaTeX leak.

### 7. symbolizer-structural-dependence.html
- raw LaTeX leaks (innerText): 0 across all patterns (`\begin{aligned}`, `\mathbf`, `\boldsymbol`, `\mathcal`, `\mathrm`, `$$`)
- tablists: 1 (expected 1)
- buttons: 3 (expected 3)
- DOM `id` collisions: none
- mathml elements: 191
- Widget: `sym-mcmc-1779918330`
- Tab-1 rendering: PASS — 18 `<math>`, height 619px.
- Tab-2 rendering: PASS — 20 `<math>`, height 641px.
- Tab-3 rendering: PASS — 14 `<math>`, height 1041px.
- Headings and TOC: no math leaks (18 nav-links scanned, 0 offending; no headings with raw `\boldsymbol`/`\mathbf`/`\mathcal`/`\mathrm`).
- Top-of-page screenshot: title, hex, body math (`y_i | b ~ D(μ_i, φ), g(μ_i) = x_i^T β + z_i^T b`) all render properly.
- Verdict: PASS — no regression on the heavily audited deep-dive.

### 8. index.html (home)
- raw LaTeX leaks (innerText): 0
- tablists: 1 (a widget IS present, embedded from README)
- buttons: 3
- DOM `id` collisions: none
- mathml elements: 75
- Widget: `sym-sym-1779794964`
- Tab-1 rendering: PASS — 12 `<math>`, height 531px.
- Tab-2 rendering: PASS — 15 `<math>`, height 549px.
- Tab-3 rendering: PASS — 10 `<math>`, height 1154px.
- Navbar: correct (`Get started`, `Articles`, `Roadmap`, `Reference`, `Changelog`, GitHub icon).
- Screenshot: hexagon logo, sidebar (Links, License, Community, Citation, Developers, Dev status with R-CMD-check, pkgdown passing, lifecycle experimental badges) all render correctly.
- Verdict: PASS.

---

### Bonus articles also scanned (not in original spec, but available on the site)

#### symbolizer-compare.html
- All raw-LaTeX patterns: 0; no widget; no TOC/heading leaks.
- Verdict: PASS.

#### symbolizer-meta.html
- All raw-LaTeX patterns: 0; no widget; no TOC/heading leaks.
- Verdict: PASS.

#### symbolizer-roadmap.html
- All raw-LaTeX patterns: 0; no widget; no TOC/heading leaks.
- Verdict: PASS.

---

### Summary

- Articles passing all checks: **10**
  - symbolizer-families, symbolizer-drmtmb, symbolizer-factors, symbolizer-ladder, symbolizer (get-started), symbolizer-structural-dependence, index, plus bonus: symbolizer-compare, symbolizer-meta, symbolizer-roadmap.
- Articles failing: **1**
  - symbolizer-gllvm.html — TOC raw-LaTeX leak in section 7.

### Specific actionable defects (for the maintainer to triage)

- **symbolizer-gllvm.html, H2 in section 7** (`#identifiability-gotchas-rotation-and-sign-of-boldsymbollambda_b`):
  - **What**: the right-sidebar "On this page" TOC entry shows `7. Identifiability gotchas: rotation and sign of Λ_B\boldsymbol{\Lambda}_B` — the raw LaTeX `\boldsymbol{\Lambda}_B` is visible after the rendered math.
  - **Why**: the H2 source in `vignettes/symbolizer-gllvm.Rmd` uses inline math (`$\boldsymbol{\Lambda}_B$`) in the heading. The H2 itself renders correctly (MathML in body, annotation hidden), but pkgdown's TOC sidebar generator copies the heading's full text (including the `<annotation>`) into a plain `<a class="nav-link">`, where the annotation is no longer hidden because there's no surrounding `<math>` element.
  - **Suggested fix (in order of preference)**:
    1. **Drop math from this heading** — rewrite as plain text: `## 7. Identifiability gotchas: rotation and sign of Lambda_B` (or `... loadings matrix Λ_B` using a Unicode bold capital lambda). Headings are TOC-bound and pkgdown reliably mishandles math in them. This is the simplest, most portable fix.
    2. If math in the heading is non-negotiable, override the TOC entry via a custom anchor or with pkgdown's `toc` config — but the upstream pkgdown bug means any heading with inline math will leak. Best to avoid.
  - **Severity**: cosmetic but user-visible at the top of the article. Easy 1-line fix in the `.Rmd`.

- (No other defects found.)

### Notes on the audit process

- One ID-naming quirk noted but not a defect: the panel IDs use `-panel-idx` / `-panel-eq` / `-panel-mat` while the visible tab labels are "1. Index" / "2. Matrix" / "3. Equations with data". The IDs are internally consistent (eq = matrix view of the equations; mat = matrix with data values). This is intentional shorthand, not a bug.
- The Claude Preview MCP tool's `preview_screenshot` reliably captures the top-of-page but fails (returns blank or error) when the viewport is scrolled past initial paint on this pkgdown site. Worked around by using oversize viewports (1400x10000) for full-page captures. JS-based content inspection was used in lieu of mid-page screenshots; visual confirmation was obtained either at top or via full-page captures.
