# V1 Florence-lens audit — symbolizer-factors.html — 2026-05-26 overnight

## Methodology

- preview_list: `symbolizer-pkgdown` running on 8766 (serverId `c2648b71-…`).
- Viewport: 1280×1200.
- URL: `http://localhost:8766/articles/symbolizer-factors.html`.
- Page title: "Reading factors, dummies, and interactions • symbolizer". h1: "Reading factors, dummies, and interactions".
- Widgets found: **none**. `document.querySelectorAll("[id^='sym-']").length === 0`. This article has no three-views widgets, so the standard widget audit (Tabs 1/2/3, dupe-ID check) is **NOT APPLICABLE**.
- MathJax loaded: **false**. KaTeX loaded: **false**. Rendering is native browser MathML via Pandoc's `<math><semantics><…><annotation encoding="application/x-tex">…</annotation></semantics></math>` envelope.
- Math elements on page: 189 (186 inline, 3 block).
- Sections: 8 H2 (Steps 1–6, Common pitfalls, Closing) + 6 H3 pitfalls. All `id`s present and TOC links resolve.
- No horizontal overflow detected: `pre`/`table` `scrollWidth ≤ clientWidth`. Main column 800 px.

## Per-section findings

### Step 1 (`body_mass ~ sex`)
Visually clean. symbol_table renders correctly: `W_i`, **𝒘**, ℝⁿ, ℝ¹²⁰, etc. The dimension-annotation table contains the **rendered-plus-raw duplicate emission** pattern (see catalog below) but `<annotation>` has `display:none`, so the raw LaTeX never paints. **Defect found**: the prose under parameter_interpretation contains an un-evaluated inline R call. The LI reads "To get the male mean you add: `intercept + sexmale = r round(sum(sym1$fixed_effects$estimate[1:2]), 2)`." The author wrote `` `intercept + sexmale = `r round(...)` `` and the inner `` `r …` `` failed to evaluate. Only the outer code-span rendered; the value never substituted. Evidence: `document.querySelector('li')` matching `/= r round\(sum\(/.test(el.textContent)` returns one hit inside `<li>` of Step 1.

### Step 2 (`body_mass ~ site`)
Clean. 4-level factor produces correct design matrix with siteB/siteC/siteD dummies; reference A absorbed into intercept. Code chunks render properly. symbol_table renders correctly.

### Step 3 (`body_mass ~ sex + body_size`)
Clean. Three-column design matrix shown. Inline prose `R^{120 x 3}` is in code style (`<code>`), not rendered math — author choice, not a defect. symbol_table fine.

### Step 4 (`body_mass ~ sex * body_size`)
Clean. parameter_interpretation table populates the interaction row with `coefficient_role = interaction_cont_factor` and biological reading "The effect of body_size on body_mass differs by 0.0669 between male and female. Call group_slopes(…)." The model equation `E(W_i) = β₀ + β₁·maleᵢ + β₂·Lᵢ + β₃·maleᵢ·Lᵢ` renders as MathML inline-math centered inside a paragraph (not a `display="block"` equation). Minor: `\text{male}_i` shows the standard B71 letter-spaced roman behaviour.

### Step 5 (`body_mass ~ temperature * body_size`)
Clean. Block math equation `E(W_i) = β₀ + β₁ Tᵢ + β₂ Lᵢ + β₃ Tᵢ Lᵢ` displayed properly. group_slopes table renders correctly with predictor/level_combo/body_size/estimate/scale/95% CI columns plus footnote.

### Step 6 (`body_mass ~ site * sex`)
Clean. Eight-column design matrix preview is correct. The cell-mean math reads `W̄_{s,x}` and the case-by-case bullets use `W̄_{A,female}`, `W̄_{B,male}`, etc. — all render correctly with overbar + subscripts. parameter_interpretation now produces `interaction_factor_factor` rows.

### Pitfall 1 — Intercept ≠ average response
**Defect**: symbol_table renders `body_mass` in the matrix column as a math-mode product: bold-italic `b o d` letters, then `y_m` as a `<msub>` subscript pair, then `a s s`. The visible glyph string reads `body_m ass` (looks like *body·y*ₘ*·ass*). Root cause: the symbolize() call has no `symbols = c(body_mass = "W_i")` mapping (unlike Steps 1–6), so the default-symbol path wraps the variable name in `\mathbf{body_mass}` without escaping the underscore. The underscore activates LaTeX math-mode subscripting. Evidence: cell innerHTML is `<math><semantics><mrow><mi mathvariant="bold-italic">𝒃</mi><mi…>𝒐</mi><mi…>𝒅</mi><msub><mi…>𝒚</mi><mi…>𝒎</mi></msub><mi…>𝒂</mi>…</mrow><annotation>\mathbf{body_mass}</annotation></semantics></math>`. Found in 3 cells across the page: Pitfall 1 (×1) + Pitfall 6 sym_p6_poly table (×1) + Pitfall 6 sym_p6_raw table (×1).

### Pitfall 2 — Contrast ≠ group mean
Clean. Coefficient tibble print and group_means table both render correctly.

### Pitfall 3 — Interaction ≠ effect of A on B
Clean. group_slopes table for body_size renders correctly.

### Pitfall 4 — Wald CIs with few groups
Clean. Prose only, no tables.

### Pitfall 5 — Dropping the intercept
Clean. Code chunks render properly.

### Pitfall 6 — `poly(x, 2)` vs `I(x^2)`
**Defect (in addition to the body_mass corruption above)**: in sym_p6_poly the index column shows `body_size, 2_i` and the variable column `body_size, 2`. These are deparsed `poly(body_size, 2)` calls with the conventional `_i` postfix appended to the entire string. Result is visually ambiguous: `body_size, 2_i` reads as "body_size, then 2 subscripted by i". For sym_p6_raw the index `body_size^2_i` is less ambiguous — MathML renders the `^2` as superscript then `_i` as subscript — but still reflects an `as_latex` strategy that grafts the postfix onto a raw deparsed call rather than building a clean canonical symbol. Not a render failure, but a contract weakness in how `extract-terms.R` (or the symbol-name resolver downstream) handles transformation calls without user-supplied symbol mappings.

### Closing
Clean. Three-step checklist, closing paragraph, footer present.

## Catalog cross-reference

| Cataloged | Status on this surface | Evidence |
|---|---|---|
| **B24** browser-MathML bracket non-stretch | ENVIRONMENTAL/inherited — no large bracketed displays on this page to expose it | only inline math and short E(W_i)=… expressions |
| **B27** three-views widget dupe IDs | NOT APPLICABLE | this article has zero widgets |
| **B55** tab-button id inversion | NOT APPLICABLE | no widgets |
| **B70** ASCII-math leak in parameter_interpretation prose | ABSENT | scanned all biological_reading cells; readings are typeset prose, no `tanh^{-1}` etc. |
| **B71** `\mathrm{}` letter-spacing | PRESENT (environmental) | `\text{male}` in Step 4 equation; not flagged as new |
| **B72/B73/B74** rendered + raw LaTeX duplicate emission | **PRESENT** in the dimension-annotation tables and inline math but `<annotation>` is `display:none`, so the leak is **textContent / accessibility / copy-paste only**, not visual. Across 6 dimension tables × 20 cells × ~7 math nodes = ~141 leaf elements where textContent shows both glyph and TeX source. Acceptable for visual rendering, problematic for screen-reader / copy-paste UX. |
| **B75/B79** Rmd heading slug mangling | LIGHT PRESENCE | `pitfall-6-polyx-2-and-ix2-are-not-the-same` and `step-3-factor-plus-continuous-predictor-body_mass-sex-body_size` are unwieldy slugs but functional |
| **B78** container overflow | ABSENT | no pre/table overflows current 800 px column |

## NEW defects (not in B1–B79)

### B80_factors_A — un-evaluated inline R call inside prose
**Where**: Step 1, the "Now the readings" bullet list, second LI.
**Symptom**: the literal text `intercept + sexmale = r round(sum(sym1$fixed_effects$estimate[1:2]), 2)` appears in the rendered prose. The inner `` `r …` `` was wrapped inside an outer `` `…` `` so the `r` was stripped of its evaluation role and the call became a literal R-code fragment.
**Evidence**: innerHTML of the LI = `…To get the male mean you add: <code>intercept + sexmale = r round(sum(sym1$fixed_effects$estimate[1:2]), 2)</code>.`
**Suggested pattern**: NEW BB. This is a fresh family — Quarto/Rmd authoring trap when nesting backtick-r inside an outer code span. The fix is in the .Rmd source: replace the outer single-backtick group with prose and put `` `r round(…)` `` standalone, or compute the value above the block and substitute a literal.

### B80_factors_B — default symbol fallback fails to escape underscores in user-variable names
**Where**: Pitfall 1 (sym_p1 symbol_table) and Pitfall 6 (sym_p6_poly + sym_p6_raw symbol_tables). 3 cells total.
**Symptom**: variable name `body_mass` is wrapped as `\mathbf{body_mass}` by the default symbol-renderer when `symbols = c(body_mass = "W_i")` is not supplied. The underscore activates LaTeX math-mode subscripting; the rendered glyph reads `body·y_m·ass` (where `y_m` is a `<msub>`). The user sees a corrupted symbol.
**Evidence**: `td.innerHTML` cited above; rendered glyph captured in Pitfall 1 / Pitfall 6 screenshots; 3 corrupted cells confirmed by `/𝒃𝒐𝒅𝒚𝒎𝒂𝒔𝒔/.test(td.textContent)`.
**Suggested pattern**: aligns with **Pattern E (escape contract for as_latex)** family — symbol-rendering must call a centralized "escape user-supplied text for math mode" helper before wrapping in `\mathbf{}` / `\mathrm{}`. Fix is one-line in the default-symbol path in `R/as-latex-*.R` or `R/render-symbol-table.R`: `gsub("_", "\\_", name, fixed = TRUE)` before the wrap. Or — preferred — never put user variable names in math mode at all; use `\texttt{body_mass}` and let the underscore stay literal.

### B80_factors_C — deparsed transformation calls become awkward symbol indices
**Where**: Pitfall 6 sym_p6_poly symbol_table.
**Symptom**: index column shows `body_size, 2_i`. The `poly(body_size, 2)` term got deparsed verbatim, then the `_i` postfix appended, producing a visually ambiguous "body_size, 2_i" string.
**Evidence**: `td.textContent === "body_size, 2_i"` (innerHTML is plain text — not even wrapped in math). Sibling cell shows variable = `body_size, 2`.
**Suggested pattern**: NEW BB. Contract weakness in `extract-terms.R` for transformation calls. The canonical symbol-index for a `poly(x, k)` term should be e.g. `poly_body_size_1_i`, `poly_body_size_2_i` (or `pBz1_i`, `pBz2_i`), not a raw deparse with index suffix. Aligns with the symbolizer mission "make every layer visible" — a deparse-grafted-postfix is the *opposite* of a curated symbol.

## Method failures

- I initially mis-positioned the body-transform when scrolling into Step 2 and mistakenly thought Step 2 was showing Step 1's content (sym1, sexmale). On re-positioning with `document.body.style.transform = ''` reset between each scroll, Step 2 rendered the correct sym2/site material. False alarm corrected before this report; mentioned here for transparency.
- I did not exhaustively scroll-screenshot every section of every pitfall after Pitfall 3 (4/5 had no tables and were prose-only). If V2 (Reader-flow) finds wording issues in 4/5 they'll surface there.
- I did not perform per-element `preview_inspect` for every block-math equation — there are only 3 and they all render cleanly per the screenshot evidence.
- All findings are tied to either textContent quotes from `preview_eval` or screenshot images. No regex-cosplay over HTML source.
