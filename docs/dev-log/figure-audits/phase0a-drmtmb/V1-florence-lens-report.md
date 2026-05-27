# V1 Florence-lens audit — symbolizer-drmtmb.html — 2026-05-26 overnight

## Methodology

- `preview_list`: server `symbolizer-pkgdown`, serverId `c2648b71-cdbd-434d-b7ad-4fe48a1a9a1b`, port 8766.
- Viewport: default; article column `clientW = 776 px`.
- Page `<title>` = `Understanding a drmTMB fit with symbolizer • symbolizer`; `<h1>` matches.
- **No tabbed widgets.** `[id^='sym-']` returns 0. Vignette is a flat pkgdown article with 11 `<h2>` sections and 8 `<table>` elements. The Tab 1/2/3 walk in the protocol does not apply; I substituted section-by-section body-transform scrolls.
- **Dupe verification N/A** (no widgets). B27 inapplicable on this surface.
- Math runtime: `window.MathJax` undefined, `window.katex` undefined. 111 `<math>` elements (11 block, 100 inline; 6 contain `<mtable>`). All `<annotation>` children are `display: none` — `innerText` is clean even when `textContent` carries the LaTeX source. Early `textContent` regex sweep returned 229 hits, all false positives; re-anchored on `innerText` returned zero LaTeX leaks in prose.

## Per-section findings

### Sections 1, 2, 3, 8, 9, 10, 11
Render cleanly at the typography/layout level. Title in §1 wraps to 3 lines beside the floated hex-logo image — functional. §3's `log(σ_i)=γ_0+γ_1 T_i ⇔ σ_i=exp(γ_0)exp(γ_1 T_i)` and §2's two aligned blocks (heights 81/69 px, 776 px wide) typeset correctly with no bracket misuse, no LaTeX leak. §9 stylistic micro-defect: the connector paragraph "and for the bivariate-Gaussian fit from Section 7:" begins with lowercase `and` after a paragraph break.

### Section 4 (assumption_table) — math defect (visible to V1)
`conditional_distribution` row, `expression` cell: renders `W_i ∣ μ_i σ_i ∼ Normal(μ_i σ_i²)` — **no commas**. LaTeX in `<annotation>`: `W_i \mid \mu_i\, \sigma_i \sim \mathrm{Normal}(\mu_i\, \sigma_i^2)` (thin space only). Block-math in §2/§5 uses `\mu_i,\, \sigma_i` (with comma) for the same conditional. Template inconsistency between the assumption-table emitter and the equations-block emitter. Visually the cell reads as juxtaposition (product), not a list. MathML evidence: `<msub>μ_i</msub><mspace width="0.167em"/><msub>σ_i</msub>` with no `<mo>,</mo>`.

### Section 5 (random intercepts) — two defects
- `independence_given_random_effects` row, expression cell: `W_i ⊥ W_j ∣ X𝐮 for i ≠ j`. Same comma-drop flavor: `X\, \mathbf{u}` should be `X,\, \mathbf{u}`.
- Inline `σ_{\mathrm{site}}` in surrounding prose ("the symbol table reports it as σ_site") renders as `σ s i t e` (character-spaced subscript). MathML emits one `<mi mathvariant="normal">` per letter; with no math runtime to collapse `\mathrm{site}` into a single text run, default identifier kerning leaves visible gaps. `\mathrm{site}` appears as a subscript in multiple equations on this article so the defect is recurring.

### Section 6 (richer worked example)
Big mu equation `μ_i = β_0 + β_1 T_i + β_2 log(F_i) + β_3 [sex = male] + u_{site(i)}` renders correctly in formula_bridge table (#4); all four predictor roles visible. No new defects beyond the §3 table-overflow (table #0 carries this section's parameter_interpretation rows for mu and sigma).

### Section 7 (bivariate Gaussian) — five defects
1. **Σ_i matrix bracket failure (B24 application).** Block math `Σ_i = ( … )` wraps a 62 px-tall 2×2 `<mtable>` in `<mo stretchy="true">(` and `)`. Measured bracket height = 14 px each (top 11628, bottom 11642); table top 11604, bottom 11666. Ratio 14/62 = **0.226**. Closing parenthesis floats roughly at the centre of row 1; row 2 (`ρ_{12,i}σ_{1i}σ_{2i}`, `σ²_{2i}`) extends below it un-enclosed. Functionally information is lost because the bracket IS the symbol's expressive purpose for a covariance matrix.
2. **`R syntax` column header wraps in formula_bridge table (#6).** Widths: submodel 86 px, R syntax 71 px, meaning 267 px, math (index) 153 px, math (matrix) 199 px. 71 px is too narrow for `growth ~ x1`; the header itself wraps "R" / "syntax". The univariate sibling table (#4) gives R syntax 116 px and does not wrap — same emitter, different column allocation.
3. **rho12 parameter_interpretation table (#7) clipped.** `scrollWidth = 1025`, `clientWidth = 776`, ~249 px clipped at the right edge. `variance_scale_reading` header truncates to "varianc..."; right-edge cells show partial text "Residual c…", "the refere…", "tanh(0.67…", "sigma_2".
4. **ASCII pseudo-math leaks in rho12 prose cells (table #7).** Zero `<math>` elements in `link_scale_reading`, `natural_scale_reading`, `variance_scale_reading`, `biological_reading`. Visible leaks: `tanh^{-1}(0.674)` (literal `^{-1}` braces, not superscript), `sigma_1`, `sigma_2`, `*` (ASCII multiplication), `rho12`. The `tanh^{-1}` artifact is the most egregious because it exposes LaTeX-style index notation in plain prose. Cells in table #0 also use ASCII `exp(...)` and `0.222` — partly consistent convention, but with no `^{-1}` analogue there.
5. **Long conditioning list bracket (minor).** `(Y_{1i}, Y_{2i}) ∣ … ∼ 𝒩_2((μ_{1i}, μ_{2i}), Σ_i)`. The inner `(μ_{1i}, μ_{2i})` mean-vector wrapper has 14 px brackets around a ~31 px inner mtable — ratio 0.45, milder than the Σ_i case but still mismatched. Borderline; logged for completeness.

### Section 3 — table overflow (defect detail)
`parameter_interpretation()` table (#0) — `scrollWidth = 1038`, `clientWidth = 776`, ~262 px clipped. Confirmed visually: `varianc…` header truncated, `biological_reading` column fully off-screen, cells like "A unit change in temperature multiplies the unexplained variability of body_mass by exp(0.0940)" unreadable. `getComputedStyle(table).overflowX === 'auto'` — but the `<table>` element is not wrapped in `.table-responsive`, so no scrollbar appears; content silently clips at the parent section's right edge.

### Section 5/6 — concept table overflow (#5)
`scrollWidth = 1125`, `clientWidth = 776`, ~349 px clipped. The `shape` and `concrete` columns are unreadable; the last cell of every row shows `ℝ 200` (the rendered MathML) cut at the column's right edge.

## Catalog cross-reference (B1–B64 + RF1–RF4)

- B1, B50–B64: out of V1 lens — NOT IN SCOPE.
- B2, B27: NOT APPLICABLE (no widgets, no dupes on this surface).
- B3, B17, B28 (literal LaTeX in prose): ABSENT — all `\…` strings are inside `display:none` `<annotation>`.
- B5, B19, B20 (vector/matrix vdots truncation): ABSENT.
- B24 (brackets not stretching): **PRESENT** on Σ_i (ratio 0.226) — see B65c.
- B25 (60-col matrix overflow): NOT APPLICABLE.
- B30, B43, B45 (dimension annotation mismatch): NOT OBSERVED (bivariate form has no explicit n×p dimension annotation).
- B31–B41, B42–B49, RF1–RF4: NOT IN V1 LENS for this scope, except the recurring style siblings I logged as B65a/B65f/B65g.

## NEW defects (not in B1–B64)

**B65a_drmtmb_comma** — Comma dropped in assumption_table conditional_distribution and independence_given_random_effects rows. LaTeX uses `\mu_i\, \sigma_i` instead of `\mu_i,\, \sigma_i`, and `X\, \mathbf{u}` instead of `X,\, \mathbf{u}`. Section-7 prose "with σ_{1,i} σ_{2,i} ρ_{12,i} on the off-diagonal" repeats the pattern. **Pattern U (new): comma-dropped argument lists in template-emitted math.**

**B65b_drmtmb_rsyntax** — `R syntax` column header wraps to 2 lines in bivariate formula_bridge table #6 (71 px wide). Univariate sibling table #4 gives 116 px and doesn't wrap. **Pattern V (new): per-table column-width regression vs sibling tables from the same emitter.**

**B65c_drmtmb_sigma_brackets** — Σ_i = ( … ) brackets at 14 px around a 62 px 2×2 mtable (ratio 0.226). Manifestation of catalog B24 (environmental, no math runtime), but logged because the covariance matrix loses information when unbracketed.

**B65d_drmtmb_long_conditional** — Inner mean-vector brackets around `(μ_{1i}, μ_{2i})` in `𝒩_2(...)` measure 14 px around ~31 px tuple (ratio 0.45). Borderline; same root cause as B65c.

**B65e_drmtmb_overflow** — Three result tables clipped on right edge: #0 ~262 px, #5 ~349 px, #7 ~249 px. All have `overflow-x: auto` on the `<table>` itself but no `.table-responsive` wrapper, so no scrollbar appears and content silently clips at the section column's right edge. **Pattern W (new): result-table overflow without responsive wrapper.**

**B65f_drmtmb_prose_math_leak** — rho12 row (table #7) has zero `<math>` elements across 4 prose cells. Visible ASCII pseudo-math: `tanh^{-1}(0.674)`, `sigma_1`, `sigma_2`, `*`, `rho12`. The `tanh^{-1}` token with literal `^{-1}` braces is the worst leak. **Pattern X (new): prose template uses ASCII-math placeholders instead of typeset LaTeX.** Distinct from U (which is math missing a comma).

**B65g_drmtmb_mathrm_spacing** — Subscripted `\mathrm{site}` renders with character-spaced glyphs (`σ s i t e` instead of `σ_site`). Distinct from B24: this is glyph-kerning failure on multi-letter identifier sequences, not bracket-stretch failure. **Pattern Y (new): identifier-only `\mathrm{...}` rendered as letter-spaced run by native MathML.**

## Method failures

- Protocol assumed `sym-*` tabbed widgets on every article; this vignette has none. Future per-surface dispatch should probe widget presence first and skip the Tab walk when absent.
- `textContent` regex sweep over MathML pages with `<annotation>` children produces catastrophic-looking false positives (229 hits here, all hidden). `innerText` honors `display:none` and gave 0 hits — that's the correct lens for visible-leak detection on MathML surfaces.
- Bracket-stretch ratio is best measured against the inner `<mtable>` height, not the parent `<math>` block (which includes prefixes like `Σ_i = …`).
- `getComputedStyle(table).overflowX === 'auto'` does NOT make a `<table>` scroll without `display: block` or a wrapper div. Detect overflow by comparing the table's `scrollWidth` vs `clientWidth`, not by reading the CSS property.
