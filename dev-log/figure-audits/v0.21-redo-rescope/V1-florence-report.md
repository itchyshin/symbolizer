## V1 Florence audit — 2026-05-27 — symbolizer-structural-dependence.html

### Setup
- Server: ec3a7713-8caf-4818-968e-5c1ce769e287
- URL: http://localhost:8767/articles/symbolizer-structural-dependence.html
- Viewport: 1400×900
- DOM dedup check: **PASS** (40 elements with `id`, all unique. 8 `sym-*` IDs, all unique.)
- Console errors / warnings: **None**.
- Math engine: MathML (no KaTeX wrapper detected; pkgdown native).

### Defects found

#### D1: Leaked scaffolding code block — `pdf_alongside_html` helper is rendered to readers
- **Severity**: serious
- **Where**: Face 1 (after the three-views widget), inside `#face-1-deep-dive-mcmcglmm-with-ginverse-listspecies-ainv`. Source: `vignettes/symbolizer-structural-dependence.Rmd` lines 242–261, chunk label `mcmcglmm-pdf`.
- **What**: A code chunk that defines `pdf_alongside_html <- function(sym, basename, title) { ... }` and then calls it is rendered fully to the article. This is build-time scaffolding (it copies a PDF next to the HTML so the *Download as PDF* button works regardless of whether the article was built by `rmarkdown::render` or `pkgdown::build_article`). It is helpful glue, but it is **not editorial content** — a reader skimming the MCMCglmm Face has to scroll past ~25 lines of file-IO plumbing before reaching the next idea. The chunk is missing `echo = FALSE` (it does have `results = "asis"`, but that only affects the helper's `cat()` output, not the source listing).
- **Evidence**: `document.querySelectorAll('div.sourceCode').textContent` matches `pdf_alongside_html` at scrollY=8220px (between the widget and the brms Face). The visible code block height is ~600px in the rendered article. Same pattern appears for Face 2 and Face 3 — there are three of these scaffolding chunks total.
- **Suggested fix**: add `echo = FALSE` to the three `*-pdf` chunks (`mcmcglmm-pdf`, the brms equivalent if it exists, and `phylolm-pdf`), keeping `results = "asis"` so the *Download as PDF* link still emits.

#### D2: `§` followed by curly quotes has no space — five occurrences
- **Severity**: minor
- **Where**: multiple paragraphs
  1. "—a result we'll return to in §"Tips vs all-nodes"." (idx 6982, end of "Where the matrix comes from")
  2. "...all-nodes augmentation; see §"Tips-only vs all-nodes")" (idx 7766, inside the §6 gloss table, `A` row)
  3. "The §"Face 3" Face below makes the bridge explicit." (idx 9015, third trip-up note)
  4. "phylogenetic heritability H² from §"Animal-model unification"" (idx 19579, Face 3 prose)
  5. "see §Animal-model unification below" (idx 15053, after Face 1 PDF download)
- **What**: `§` (U+00A7) is rendered directly adjacent to `"` (U+201C, left curly quote) or to the next letter, with no separator. The convention `§"Tips-only vs all-nodes"` reads as if the section symbol applies to the quote glyph itself. Numerals after `§` (`§3.2`, `§4`) are standard; section *titles* after `§` are not. Note: the source `.Rmd` literally writes `§"..."` so the raw rendering is faithful — the question is whether to keep this typography.
- **Evidence**:
  ```
  document.body.innerText  matches  /§["]/g  → 4 hits (char codes 167 + 8220)
  also one §A (char codes 167 + 65)
  ```
- **Suggested fix**: prefer `§ "Tips-only vs all-nodes"` (thin space), or rewrite as "see *Tips-only vs all-nodes* below" using italics for the section title. Decide once and apply to all five.

#### D3: Response-symbol inconsistency across widget tabs — `Zr_i` vs `zr`
- **Severity**: minor
- **Where**: Face 1 widget (`#sym-mcmc-1779893993`), three tabs
  - Tab 1 (panel-idx): pink-box equation uses `\mathrm{Zr}_i` (uppercase italic, scalar with subscript i)
  - Tab 2 (panel-eq, labelled "2. Matrix"): pink-box equation uses `\boldsymbol{zr}` and `zr` (lowercase bold vector)
  - Tab 3 (panel-mat, labelled "3. Equations with data"): worked row uses `zr_1` (lowercase bold with numeric subscript) and stacked matrix uses `zr_{60×1} (observed)` (lowercase bold vector)
- **What**: The "where:" gloss list mirrors the inconsistency:
  - Tab 1's gloss list entry says **`Zr_i — response variable ℝ^60`**
  - Tab 2 and Tab 3's gloss list entries say **`zr — response variable ℝ^60`**
  Same gloss list, same `R^60` annotation — yet two different glyphs for the same object. Readers asked to "follow the per-row reading" in Tab 1 then "switch to matrix form" in Tab 2 will (rightly) ask whether `Zr_i` and `zr_i` are the same quantity. They are. Pick one convention.
- **Evidence**: `document.querySelector('#sym-mcmc-1779893993-panel-idx math[display="block"] annotation').textContent` → starts with `\mathrm{Zr}_i \mid \mu_i ...`; same selector for `panel-eq` → starts with `\boldsymbol{zr} \mid ...`.
- **Suggested fix**: choose either (a) `\mathrm{Zr}` everywhere (capital Z; vector is `\mathrm{Zr}` with no subscript, scalar is `\mathrm{Zr}_i`), or (b) `zr` lowercase everywhere. Match Tab 1's pink-box and gloss list with Tabs 2/3 accordingly.

#### D4: brms `assumption_table` overflows the article container — status column clipped
- **Severity**: minor
- **Where**: Face 2 (brms), the `assumption_table(sym_brms)` chunk output (table index 4 in DOM, scrollY ≈ 9600). Same issue on Face 3's `assumption_table(sym_pl)` (table index 6, scrollY ≈ 13832).
- **What**: The four-column table has `<th>` widths `assumption=305px, expression=214px, biological meaning=138px, status=166px`, summing to 823px. The article main column is **776px wide**. The table sets `overflow-x: auto` so the status column ends up partially behind a horizontal scrollbar — the strings `"follows from the formula"` and `"your responsibility"` are truncated at the visual right edge ("follows from t…", "your responsib…"). A reader who does not notice the scrollbar misses the entire status of three rows.
- **Evidence**:
  ```js
  // Face 2 assumption_table:
  tableScrollWidth = 824, clientWidth = 776 → 48px overflow
  hasScrollbar = true, overflowX = "auto"
  ```
- **Suggested fix**: either (a) widen the article max-width slightly, or (b) shorten the `biological meaning` column copy so the four-column table fits within 776px, or (c) make `assumption_table()` emit `expression` and `biological meaning` as wrap-friendly with `white-space: normal` and tighter `padding`. (b) is the lowest-risk change.

#### D5: `assumption_table` status string is inconsistently spelled — `your responsibility` vs `your_responsibility`
- **Severity**: minor
- **Where**: Both `assumption_table` outputs (Face 2 brms and Face 3 phylolm). Affects rows 9 (`phylo_brownian_motion`) and 10 (`phylo_ultrametric_tree`), which read `"your_responsibility"` (with underscore). Row 5 (`no_missing_at_random`) reads `"your responsibility"` (with space).
- **What**: Same semantic status, two distinct spellings within the same table. This is a **data-layer bug** in `assumption_table()` (the renderer is faithful — the difference comes from the upstream lookup table). Affects both brms and phylolm tables identically (same template, same defect).
- **Evidence**: `document.querySelectorAll('table')[4].querySelectorAll('tbody tr td:last-child')` returns mixed strings:
  - rows 0–4: `"explicit"`, `"explicit"`, `"explicit"`, `"explicit"`, `"follows from the formula"`
  - row 5: `"your responsibility"`
  - rows 6–8: `"explicit"`, `"follows from the formula"`, `"follows from the formula"`
  - rows 9–10: `"your_responsibility"` ← **with underscore**
- **Suggested fix**: in `inst/extdata/assumption_template_*.csv` (or wherever the brms / phylolm status strings are stored), normalise to a single spelling. Recommend `"your responsibility"` (spaces) since that matches `"follows from the formula"` and `"explicit"`. Then snapshot-test that all status strings come from a fixed vocabulary.

#### D6: `Normal(μ_i σ_i²)` reads as if `μ` and `σ²` are juxtaposed, not parameters
- **Severity**: minor
- **Where**: `assumption_table` `conditional_distribution` row for both brms and phylolm Faces. The expression is `Zr \mid \mu_i\, \sigma_i \sim \mathrm{Normal}(\mu_i\, \sigma_i^2)`.
- **What**: The LaTeX uses `\,` (thin space) between `\mu_i` and `\sigma_i` instead of a comma. Rendered, this looks like `Normal(μ_i σ_i²)` — without a separator between the two parameters. The standard convention for `Normal(mean, variance)` is `Normal(μ, σ²)` with a comma. The same issue appears on the LHS conditioning: `Zr | μ_i σ_i` should be `Zr | μ_i, σ_i`.
- **Evidence**: `tables[4].querySelectorAll('tbody tr')[0].querySelectorAll('td')[1].textContent` →
  ```
  Zri∣μiσi∼Normal(μiσi2)
  ```
  The annotation `\mathrm{Zr} \mid \mu_i\, \sigma_i \sim \mathrm{Normal}(\mu_i\, \sigma_i^2)` confirms the missing comma.
- **Suggested fix**: in the assumption template, replace `\mu_i\, \sigma_i` with `\mu_i,\, \sigma_i` (add the comma, keep the thin space). Two instances per row, applies to both brms and phylolm `conditional_distribution` rows.

#### D7: Tab marker `▸` is glued to "1." with no space
- **Severity**: cosmetic
- **Where**: All three widget tabs. `.sym-tab-marker` spans contain the character "▸" (right-pointing pointer, U+25B8). The following text node starts immediately with "1. Index" / "2. Matrix" / "3. Equations with data" with no separator.
- **What**: Tabs read visually as "▸1. Index" rather than "▸ 1. Index". The marker glyph is 6.86px wide and the gap to "1." is negligible. Also, `▸` is conventionally a disclosure-arrow icon (accordion/details), not a tab indicator — readers may mistake the widget for a collapsible block.
- **Evidence**: `tab.childNodes` → `[#text "\n", SPAN.sym-tab-marker "▸", #text "1. Index\n"]`. No whitespace between the SPAN and the next text node.
- **Suggested fix**: in the widget CSS, give `.sym-tab-marker { margin-right: 0.35em }` (or `padding-right`). Alternative: drop the marker entirely on inactive tabs and only show it on the active tab via a `::before` (cleaner tab metaphor).

#### D8: Internal tab IDs are semantically swapped relative to labels
- **Severity**: cosmetic (developer-facing only; not visible to readers)
- **Where**: `#sym-mcmc-1779893993-tab-eq` is labelled **"2. Matrix"** and shows the matrix-form panel. `#sym-mcmc-1779893993-tab-mat` is labelled **"3. Equations with data"** and shows the equations-with-data panel. The IDs and labels disagree: `eq` (presumably "equations") holds matrix content; `mat` (presumably "matrix") holds equations.
- **What**: Anyone debugging the widget will reach for the wrong element. Labels are correct; only the IDs are misleading.
- **Evidence**:
  ```js
  document.querySelector('#sym-mcmc-1779893993-tab-eq').textContent  → "▸2. Matrix"
  document.querySelector('#sym-mcmc-1779893993-panel-eq').textContent.slice(0,80) → "The same model in matrix form..."
  document.querySelector('#sym-mcmc-1779893993-tab-mat').textContent → "▸3. Equations\nwith data"
  document.querySelector('#sym-mcmc-1779893993-panel-mat').textContent.slice(0,80) → "The same matrix equation, with your actual numbers stacked inside the brackets..."
  ```
- **Suggested fix**: in `R/render-three-views.R` (or whichever file generates the widget HTML), rename the `eq` suffix to `mat` and vice versa to match content. Internal-only; no user-visible change.

#### D9: brms convergence warnings appear in the rendered article
- **Severity**: minor (methodological more than visual)
- **Where**: Face 2 (brms), inside the first code block. The `#>`-prefixed output shows:
  - "There were 41 divergent transitions after warmup"
  - "Bulk Effective Samples Size (ESS) is too low"
  - "Tail Effective Samples Size (ESS) is too low"
  - "There were 1 chains where the estimated Bayesian Fraction of Missing Information..."
  - "Examine the pairs() plot to diagnose sampling problems"
- **What**: A reader is being shown a brms fit that **did not converge** as a representative example. The phylogenetic signal estimate in the variance_components table (`sd=0.348, var=0.121`) may not be trustworthy. Also visually noisy — 16+ lines of `#>` warning prefixes precede the `symbolize()` call.
- **Evidence**: the code block beginning `fit_brms <- brm(...)` produces `R> #> Warning: There were 41 divergent transitions after warmup` and a sequence of further warnings. The block has `overflowX: auto` so long warning lines are clipped at the right edge.
- **Suggested fix**: either (a) increase `iter` / `warmup` / `adapt_delta` in the brms call so the fit converges and warnings go away, or (b) suppress warnings on the chunk (`warning = FALSE`) and mention in prose that this is a teaching minimum and a production fit would need more iterations.

#### D10: B4 "Alcatorda" species-name whitespace bug — confirmed present (tracking only, per brief)
- **Severity**: cosmetic (tracking only per brief)
- **Where**: Face 1 widget, Tab 3 (Equations with data), the worked-row pink box. The single-row response equation reads `Zr_1 = β̂_0 + û_Alcatorda + ε̂_1`.
- **What**: The species name has lost its internal space — should be "Alca torda" (Razorbill). This is a downstream symptom of subscript-rendering (likely `\hat{u}_{Alca torda}` collapses the space because `_{}` braces are tight).
- **Evidence**: visible in screenshot, confirmed via `panel-mat innerText` matching `Alcatorda`.
- **Suggested fix**: in the worked-row rendering, replace species-name spaces with `\,` or `~` (math-mode thin space / non-breaking space) before interpolating into the subscript. Tracking only — not blocking this slice.

#### D11: §6 gloss table — math text content concatenates rendered + annotation (probably acceptable, noted for completeness)
- **Severity**: cosmetic (potential a11y / copy-paste issue)
- **Where**: Throughout the article, but most visible in tables. Any `<td>` containing a `<math>` element returns textContent like `"σp2\\sigma_p^2"` (the rendered MathML's text concatenated with the `<annotation encoding="application/x-tex">` text).
- **What**: When a user copies a table cell, they get both the rendered Unicode and the raw LaTeX. Screen readers may read both. Visually-fine — only a concern for copy-paste / a11y.
- **Evidence**: `document.querySelectorAll('table')[1].querySelector('tbody tr td').textContent` → `"Zri\\mathrm{Zr}_i"` (renders fine, but textContent is doubled).
- **Suggested fix**: not a regression — this is pkgdown's standard MathML output. If desired, set `aria-hidden="true"` on `<annotation>` elements or use CSS `user-select: none` on them. Not blocking.

#### D12: "Power" decay descriptor for Exponential kernel is likely a label error
- **Severity**: cosmetic (content, not Florence-lens — flagging because the maintainer should see it)
- **Where**: Spatial section, three-row Kernel/Formula/Decay table. Source: `vignettes/symbolizer-structural-dependence.Rmd:372`.
- **What**: The Decay column says:
  - Exponential | `C(d) = exp(-d/ρ)` | **Power**
  - Squared-exponential | `C(d) = exp(-d²/ρ²)` | **Sharp**
  - Matérn | `C(d; κ, ν)` | Tunable smoothness
  The exponential kernel decays *exponentially*, not as a power law. The conventional descriptor would be "Gradual" or "Slow tail". Squared-exponential ("Sharp") makes sense — its tail dies faster. "Power" is misleading and may confuse readers familiar with the power-law kernel (a separate, distinct kernel).
- **Evidence**: `tables[7].querySelectorAll('tbody tr')[0].querySelectorAll('td')[2].textContent` → `"Power"`.
- **Suggested fix**: change "Power" to "Gradual" (or "Light-tailed exponential decay" if more space is desired).

### Defects checked and ABSENT

- **B1 Tab DOM duplication (Pattern M)**: NOT present. `document.querySelectorAll('[id^="sym-"]').length === [...new Set(...)].length` → both 8. No `sym-*` ID appears twice.
- **B2 Whole-document DOM ID duplicates**: NOT present. 40 IDs, 40 unique.
- **B3 Console errors / warnings**: NONE. `preview_console_logs({level: "error"})` returns "No console logs."
- **B5 Hex logo overlapping title**: NOT present. h1 wraps to 6 lines, widest line right-edge x=367; logo left edge x=428. ~60px gap.
- **B6 TOC sidebar missing**: NOT present. TOC populated with 9 h2 entries, sticky positioning (`position: sticky; top: 56px`) confirmed via getComputedStyle.
- **B7 Source link missing**: NOT present. "Source: vignettes/symbolizer-structural-dependence.Rmd" link rendered just below the title.
- **B8 Math typesetting failures (literal `$...$`, `\mathbb`, `\begin{aligned}` in prose)**: NOT present. Regex sweep of `document.body.innerText` for unrendered LaTeX delimiters and macros returned only R-code patterns like `dat$Zr` (false positive — the `$` is R's subset operator inside a code block).
- **B9 Widget tab labels showing literal `\n`**: NOT present visibly. Tab 3 label DOM has `"3. Equations\nwith data"` (textContent contains a literal newline), but CSS collapses to a single space — visually reads as "3. Equations with data".
- **B10 Tab-3 head/tail row truncation missing**: NOT present (Pattern O working). Tab 3 worked-row block shows "Showing first 5 and last 2 rows of n = 60" and the rendered stacked matrix has 5 rows + ⋮ + 2 rows (5/2 split). Column truncation also working: matrix rows show `0 0 0 0 0 ⋯ 0 0` pattern (5 head + tail columns).
- **B11 Bursts of literal LaTeX in prose**: NOT present. All `\mathbb{R}^{...}`, `\mathbf{...}`, `\begin{aligned}` etc. rendered to MathML.
- **B12 §6 status column rendering**: PRESENT and correct. `<strong>estimated</strong>` for estimated rows; plain text for "observed" and "constructed from tree". Bold styling visible in screenshot.
- **B13 brms convergence warnings styled as page errors**: NOT present. Warnings appear as `#>` prefixed text inside the same code block as the `brm()` call, styled as R output, not as page errors.
- **B14 Horizontal overflow of Tab 3 widget**: NOT present. Tab 3 panel scrollWidth (774) ≤ clientWidth (774). No horizontal overflow.
- **B15 Container fit for pink boxes**: PASSES — pink boxes sized to content with appropriate inner padding; no excessive whitespace observed.

### Anything else worth noting

- **Preview scroll behaviour**: The preview server's scroll behaviour is unusual — `window.scrollTo()` accumulates state across `body.style.transform` resets, so the body-transform trick (`document.body.style.transform = 'translateY(-Npx)'`) is the only reliable way to navigate. After a few transforms the scrollY drifts; a fresh URL navigation (`?t=` cache-buster) is required. This made multi-section auditing slow but didn't compromise findings.

- **MathML rendering**: the page uses MathML (with `<annotation encoding="application/x-tex">` annotations) — not KaTeX, not MathJax. Renders cleanly in current Chromium-based preview.

- **Page weight**: total document height 19,563px. Tab 1 + Tab 3 widget transitions add ~400px difference (Tab 3 is wider/taller because of stacked-matrix block).

- **TOC depth**: only h2 entries appear in the right-hand TOC, but the link list (`<nav#toc>` `<a>` elements) includes the h3 Face 1/2/3 entries. They are present in DOM but hidden by pkgdown CSS at this depth — by design.

- **Pattern O column truncation**: the recent commit `fe688eb Pattern O: head/tail column truncation for matrices` is operational. Math ellipsis characters used: ⋯ (14×), ⋮ (19×), ⋱ (1×). Proper Unicode, not ASCII `...`.

- **Defect spawned-task candidates** (for the maintainer's discretion):
  - D1 (scaffolding code block): worth a 5-minute fix to add `echo = FALSE`. High visual impact, trivial work.
  - D4 (assumption_table overflow): may already be a known wider issue if other Faces in v0.22 use the same table — worth a single fix in the renderer rather than per-table.
  - D5 (your_responsibility underscore): fix at the data layer; a single-file edit in `inst/extdata/` is likely enough.
