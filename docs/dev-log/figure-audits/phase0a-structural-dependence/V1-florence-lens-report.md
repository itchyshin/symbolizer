# V1 Florence-lens audit — symbolizer-structural-dependence.html — 2026-05-26 overnight

## Methodology

- serverId `c2648b71-cdbd-434d-b7ad-4fe48a1a9a1b`, port 8766, viewport 1280×1200
- h1 "Structural dependence: phylogenetic, animal-model, and spatial random effects"
- `typeof MathJax === 'undefined'` and `typeof katex === 'undefined'` — native MathML only
- Widget roots `sym-meta-1779823421` (metafor) and `sym-mcmc-1779823423` (MCMCglmm), both on Moura tips data (n = 60)
- Dupe check: all 16 unique widget IDs (root + 3 tabs + 3 panels + end) appear exactly twice; 32 elements total. **B27 confirmed.**
- Tab labels vs IDs: `-tab-eq` displays "2. Matrix", `-tab-mat` displays "3. Equations with data". **B55 confirmed.** Copy 1 of `-tab-mat` renders with a literal `\n` break ("3. Equations\nwith data") while copy 2 is single-line.
- Math element counts (copy 1): meta-idx 18, meta-eq 20, meta-mat 14; mcmc-idx 18, mcmc-eq 20, mcmc-mat 14. MathML **renders**; defect is raw LaTeX printed *next to* the rendered output.

## Per-widget findings

### Widget 1: metafor (sym-meta-1779823421)

**Tab 1 "1. Index"** (18 math). B2: raw `\begin{aligned} y_i \mid \theta_i & \sim \mathrm{Normal}(\theta_i,\, v_i), \quad v_i \text{ known} \\\\ ... \end{aligned}` printed as literal text directly after the rendered MathML — no `$$` wrapper, source escaped to visible characters. B3 partial: bare `\mathbb{R}^{60}` (no `$` wrappers, contra maintainer note) leaked 5× as literal text in gloss type column. B28: every gloss entry duplicates rendered glyph and raw source — e.g. `yy\n— response variable ℝ60\\mathbb{R}^{60}`. Same pattern for `μi\mu_i`, `σi\sigma_i`, `β0\beta_{0}`, `uspecies(i)u_{species(i)}`, `σspecies\sigma_{species}`, `𝑨\mathbf{A}`. Also ASCII fallbacks `k x k` and `tau` in gloss A description (not `k × k` / `τ`).

**Tab 2 "2. Matrix"** (20 math). Same B2/B28 shape. New raw command: `\boldsymbol{\beta}` literal text in gloss (not present in Tab 1).

**Tab 3 "3. Equations with data"** (14 math, 8 mtables). 
- **B4**: `ûAlcatorda` (Alca torda, space stripped) in single-observation equation `y1 = β̂0 + ûAlcatorda + ε̂1`.
- **B25**: panel inner width 774px, Z-matrix mtable (60 cols × 8 rows) = 1248px wide; overflows by 474px. Panel `overflow-x: visible` so Z bleeds past panel into next layout column.
- **B19**: each Z row has exactly one nonzero (one-hot integrity preserved), but only **1 of 8 visible rows** (row 4) places its `1` in the first 12 columns; the other 7 ones are past col 12, off-screen. Visually a "wall of zeros".
- **B20**: u-vector mtable is 60 rows × 1 col, 1095px tall, all 60 entries rendered as actual data values (0.418, 0.105, −0.121, …, −0.0761). **No `⋮` vdots row anywhere in u.**
- **B26/B29**: stacked block (`sym-eq` div) 1139px tall. Inside, the un-truncated u (1115px) forces math row-height to 1115px while the 8-row matrices/operators (y, X, β̂, Z, ε̂) cluster at `top ≈ 475–545` from math top. ~475px of empty pink space above the visible 8-row block (maintainer estimated ~600px; actual ~475). Root cause: u not truncated.
- **B2 again**: `\begin{bmatrix} ... \cdots ... \vdots ... \end{bmatrix}_{\,\mathbf{A}_{\,60 \times 60}\,}` literal text appears after the rendered A matrix.
- **B24** (environmental): all 12 fence operators in stacked block measure 13px tall; largest interior mtable 1095px. Brackets do not stretch.

### Widget 2: MCMCglmm (sym-mcmc-1779823423)

Mirrors widget 1 on every count.
- **Tab 1**: 18 math, `\begin`/`\mathbf`/`\mathrm` raw text, 5 leaked `\mathbb{R}^{...}`.
- **Tab 2**: 20 math, **adds** `\boldsymbol{\mu}`, `\boldsymbol{\sigma}`, `\boldsymbol{\beta}` literal text in gloss.
- **Tab 3**: 14 math, 8 mtables (max 60×60 and 60×1), `Alcatorda` species-no-space.

Defects are template-level, not fit-specific — same `as_html_three_views()` output.

## Prose findings (non-widget)

**Prose table 0 — Context / Symbol / What M encodes.** Column-3 header textContent = `"What\n𝑴\\mathbf M\nencodes"`. `\mathbf M` is literal text in the `<th>`. Table has 3 data rows (Phylogenetic / Pedigree / Spatial), consistent with article prose ("Three named instantiations recur"). The "6-package matrix" naming in the maintainer brief refers to a 3-row table.

**Prose table 1 — `assumption_table(sym_meta)` output**, under "Face 1: metafor::rma.mv". 17 rows (header + 16 data), 2449px tall. Every cell of the `expression` column shows rendered MathML AND raw LaTeX source. Examples: `yi∣θi∼Normal(θi,vi)y_i \mid \theta_i \sim \mathrm{Normal}(\theta_i, v_i)`, `vi is known (not estimated)v_i \text{ is known (not estimated)}`, `θi=β0+∑kβkXki+ui\theta_i = \beta_0 + \sum_k \beta_k X_{ki} + u_i`, `ui∼Normal(0,τ2)u_i \sim \mathrm{Normal}(0,\, \tau^2)`. New defect surface: `assumption_table()` helper output, not `three_views` widget.

**"Six packages, one phylogenetic model" section prose.** Display equation duplicated: rendered `Zri=β0+upk[i]+ei,up∼𝒩(𝟎,σp2𝑨),ei∼𝒩(0,σe2).` followed by literal `\mathrm{Zr}_i \;=\; \beta_0 + u_{p_{k[i]}} + e_i,\qquad u_p \sim \mathcal N(\mathbf 0, \sigma_p^2\,\mathbf A),\quad e_i \sim \mathcal N(0, \sigma_e^2).` Article body prose, outside any widget or helper.

**Section headings with literal `\n`.** Six "Face N:" `<h3>` headings have a literal `\n` between two `<code>` spans (e.g. `Face 1: <code>metafor::rma.mv</code> with\n<code>R = list(species = A)</code>`). HTML whitespace collapses to a space in body. TOC sidebar `<a>` carries the newline — visible wrap in sidebar.

## Catalog cross-reference

| # | Status | Notes |
|---|--------|-------|
| B2 | PRESENT | Both widgets, all tabs, plus prose tables + article body prose. Even copy 1 leaks — not 2nd-copy specific. |
| B3 | PRESENT (modified) | No `$` wrappers; bare `\mathbb{R}^{60}` leaks 5–6× per Index/Matrix tab. |
| B4 | PRESENT | `ûAlcatorda` in Tab 3 of both widgets. |
| B5 | PARTIAL | y, X, ε̂ vectors do `⋮`-truncate. u (60×1) does not. |
| B19 | PRESENT | 7 of 8 visible Z rows have their 1 past col 12 (off-screen). |
| B20 | PRESENT (u only) | u 60×1 untruncated (1095px). ε̂ 8×1 truncated correctly. |
| B24 | PRESENT (env) | Bracket 13px vs 1095px mtable. |
| B25 | PRESENT | Z 1248px vs panel 774px = +474px overflow. |
| B26 | PRESENT (modified) | ~475px above (not ~600); root cause = untruncated u. |
| B27 | PRESENT | 16/16 unique IDs duplicated. |
| B28 | PRESENT | Every gloss row, prose tables, article prose. |
| B29 | = B26 | Same root cause. |
| B55 | PRESENT | `-tab-eq` shows "2. Matrix"; `-tab-mat` shows "3. Equations with data". |
| B71 | PRESENT (env) | Not re-derived. |

## NEW defects (not in B1–B71)

**B72_struct_A — `assumption_table()` expression column duplicates rendered + raw LaTeX.** Prose table 1 (17 rows), every `expression` cell shows `<rendered MathML><raw LaTeX>` pairs. New surface for the B28 pattern: helper-function output, not widget panel.

**B72_struct_B — `\mathbf M` literal text in prose-table header.** Prose table 0 column-3 `<th>` textContent = `"What\n𝑴\\mathbf M\nencodes"`. Pattern: B28 inside a manually-authored HTML table header.

**B72_struct_C — Article-body display equation duplicates rendered + raw LaTeX.** "Six packages" section. Free-standing `$$...$$` display equation emits both MathML and raw LaTeX source. Pattern: B28 in vignette body prose, no widget or helper involved.

**B72_struct_D — Six "Face N:" headings carry literal `\n` between code spans.** `<h3>` innerHTML splits at `with\n<code>...`. Body collapses to space; TOC sidebar wraps. Source-level Rmd defect.

**B72_struct_E — First DOM copy of `-tab-mat` button label differs from second.** `querySelectorAll` returns `["▸3. Equations\nwith data", "▸3. Equations with data"]`. Two emissions of the same widget render the button label differently — both share the same id. Pattern: pkgdown pass-1 vs pass-2 divergence on the dupe.

**B72_struct_F — ε̂ is truncated with `⋮` (8 rows) but u is not (60 rows) in the same stacked block.** Row counts of mtables inside the stacked block: y 8, X 8, β̂ 1, Z 8 rows × 60 cols, **u 60**, ε̂ 8. Only u escapes truncation — inconsistent policy in the renderer. Drives B19/B25/B26 together.

**B72_struct_G — Native MathML `<mtable>` for Z does not respect parent panel `max-width`.** Panel 774px, Z mtable 1248px, panel `overflow-x: visible`. Missing `overflow-x: auto` on `sym-eq`, or missing column-truncation on Z (A correctly truncates to 8×8 with `⋯`; Z does not).

**B72_struct_H — TOC anchor `#face-1-metaforrma-mv-with-r-listspecies-a` is slug-collapsed.** Pandoc flattened `::` and the literal `\n` into a continuous slug. Valid but hard to reason about. Heading-anchor slug hygiene.

## Method failures

- B71 letter-spacing measurement not re-derived (environmental, per scope).
- Tab 1 and Tab 2 not screenshotted individually; numerical evidence (textContent, math counts, mtable dims) was sufficient.
- Z mtable inspected at head columns 0–11 only (not scrolled horizontally to verify exact column index of each `1`). Per-row nonzero count confirms one-hot; the 7 off-screen ones are confirmed present but their exact column positions in 12–59 were not enumerated.
- Widget 2 Tab 3 not screenshotted. Numerical mtable dims confirm template parity with widget 1, but pixel-level visual confirmation of widget 2 was deferred.

result: V1 Florence-lens audit complete. Confirmed B2, B3 (modified), B4, B5 (partial), B19, B20 (u only), B24, B25, B26, B27, B28, B29, B55, B71 on this surface; found 8 new defects (B72_struct_A–H) including assumption_table leak, table-header `\mathbf M` leak, article-body display-equation leak, heading `\n` continuation, dupe-copy label divergence, ε̂/u truncation inconsistency, Z mtable overflow root cause, anchor-slug hygiene. Report saved to `/Users/z3437171/Dropbox/Github Local/symbolizer/docs/dev-log/figure-audits/phase0a-structural-dependence/V1-florence-lens-report.md`.
