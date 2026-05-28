# Rose-style consistency scan — 2026-05-27 — symbolizer-structural-dependence article + extractors

Triggered by the maintainer's observation that the MCMCglmm widget mixes
A_{60×60} (Tab 2) with A_{116×116} (Tab 3). Rose's principle: "if I find
one inconsistency, you'll have ten." Scan was run BEFORE any code edits.

## How the scan worked

For the article (`vignettes/symbolizer-structural-dependence.Rmd` and the
rendered HTML) + the three extractors (`R/symbolize-mcmcglmm.R`,
`R/symbolize-brms.R`, `R/symbolize-phylolm.R`) + the CSV templates
(`inst/extdata/*.csv`):

- Inspected the symbolized model from a real MCMCglmm fit (animal-model
  fixture) — full symbol_dictionary, full metadata.
- Inspected brms phylo and phylolm symbolized models likewise.
- Grepped CSV templates for symbol drift (σ_p vs σ_species vs σ_animal;
  u_p vs u_species vs u_animal).
- Checked the actual widget HTML (Tab 1 / Tab 2 / Tab 3) rendering.
- Checked the §6 gloss table + the §"Animal-model unification" cross-link.

## Inconsistencies found, grouped by class

### Class 1 — Dimension inconsistencies within ONE widget

| ID | Where | What it says | Should be |
|---|---|---|---|
| **T1.1** | §6 gloss, A row | "k × k tips-only" | Both forms, with explicit "see §Tips-only vs all-nodes" |
| **T1.2** | symbol_dictionary A row (MCMCglmm) | `dimension = R^{k × k}`, `dimension_concrete = R^{k_{animal} × k_{animal}}` (no numeric) | Should be 60×60 OR 116×116, not abstract |
| **T1.3** | Widget Tab 2 | A_{60×60} | Match Tab 3 = 116×116 (per maintainer 2026-05-27) |
| **T1.4** | Widget Tab 3 | A_{116×116} ← reference | reference |
| **T1.5** | Symbol_dictionary u row | `dim = scalar; R^{G_{animal}}`, `dim_concrete = R^{30}` (= number of unique species in this fixture) | Should match widget 116 for all-nodes |
| **T1.6** | Widget Tab 2 | `u` (no explicit dim) | Implicit 60-dim from A_{60×60} |
| **T1.7** | Widget Tab 3 | u_{116×1} ← reference | reference |
| **T1.8** | Widget Tab 3 | Z_{60×116} (rows = obs, cols = all-nodes) | reference; mixing 60 and 116 is structurally correct here |

**Conclusion (Class 1)**: 4 different dimension expressions for A across one widget + the article. Tab 2 → 116×116 (maintainer's choice).

### Class 2 — Symbol-name drift (same concept, different name across surfaces)

| ID | Where | Symbol used | Concept |
|---|---|---|---|
| **T2.1** | §6 gloss + model statement | `σ_p`, `u_{p, k[i]}` | phylogenetic variance / RE |
| **T2.2** | Widget Tab 1 (per-obs) | `σ_species`, `u_species(i)` | same concept |
| **T2.3** | Widget Tab 2 (matrix) | `σ²_species`, `u` (bold, no subscript) | same concept |
| **T2.4** | Widget Tab 3 (worked) | `σ_p` in `Cov(û) = σ_p² · A`, but u tagged just `û` | same concept |
| **T2.5** | MCMCglmm vc tibble row | group name = "animal" (or "species" when ginverse name is species) | same concept |
| **T2.6** | brms vc tibble row | group name = "species" (from gr() group) | same concept |
| **T2.7** | phylolm vc tibble row | group name = "phylo" (hardcoded in my new extractor) | same concept |
| **T2.8** | §"Animal-model unification" | `σ²_A`, `u_a` (A for "additive", a for "animal") | same concept |
| **T2.9** | CSV template phylo_random_effect rows | `\sigma_p^2`, `\mathbf{u}_p` | same concept |

**Conclusion (Class 2)**: 6+ different names for "phylogenetic variance" across surfaces a reader sees in one article. Cleanest fix is **one canonical name** (recommend `σ_p` everywhere, with `\sigma_p` in CSV templates) — the widget should NOT substitute ginverse group name into the σ symbol.

### Class 3 — Response-symbol drift across tabs (V1-D3 expanded)

| ID | Where | Symbol | Notes |
|---|---|---|---|
| **T3.1** | Widget Tab 1 | `\mathrm{Zr}_i` (uppercase, with _i, italic-roman) | matches §6 |
| **T3.2** | Widget Tab 2 | `\boldsymbol{zr}` (bold lowercase, no subscript) | vector form |
| **T3.3** | Widget Tab 3 stacked block | `zr_{60×1}` (bold lowercase with dim) | vector form, with dim |
| **T3.4** | §6 gloss | `\mathrm{Zr}_i` | reference (matches Tab 1) |
| **T3.5** | brms `independence_given_random_effects` row | Was `y \perp y_j` (no `_i`); now `\mathrm{Zr}_i \perp \mathrm{Zr}_j` after fix | already fixed today |
| **T3.6** | brms response symbol overall | Was raw `y`; now `\mathrm{Zr}_i` with _i + escaping after fix | already fixed today |

**Conclusion (Class 3)**: Tab 1 uses scalar form (Zr_i); Tab 2/Tab 3 use vector form (zr). This may be DEFENSIBLE (per-observation scalar vs n-vector), but the convention should be explicit. Cleanest: keep both, but label clearly ("scalar `Zr_i`" vs "vector `zr`").

### Class 4 — Heritability / λ naming

| ID | Where | Symbol | Concept |
|---|---|---|---|
| **T4.1** | MCMCglmm `heritability` reading row | `H^2 = \sigma_A^2 / (\sigma_A^2 + \sigma_E^2)` (uses A/E — animal-model convention) | same concept |
| **T4.2** | phylolm `metadata$phylo_param` | the `optpar` value (λ for Pagel) | same concept |
| **T4.3** | §6 trip-up note 3 | `λ = σ²_p/(σ²_p + σ²_e) — the phylogenetic heritability H²` (uses p/e) | bridges (T4.1) and (T4.2) |
| **T4.4** | §"Animal-model unification" | `σ²_A / (σ²_A + σ²_e)` (uses A/e mixed) | same concept |

**Conclusion (Class 4)**: σ_A vs σ_p vs σ_E vs σ_e — 4 different letter conventions in one article. Pick one and stick to it. Recommend σ_p / σ_e (the §6 statement's convention) for THIS article and add a one-line note in §"Animal-model unification" that σ_A is the quantitative-genetics alias.

### Class 5 — Status / vocabulary (fixed in this session)

- ✓ `your_responsibility` → renders as "your responsibility" via friendly_status map (fixed today)
- ✓ `derived` → renders as "derived" via friendly_status map (fixed today)

### Class 6 — Citations / references

- ✓ Cinar 2022 — fixed
- ✗ **Moura et al. 2021** cited inline (data prep comment) but NOT in References — V2-F13 open
- ✓ Ho & Ané 2014, Hadfield 2010, Bürkner 2017 — present
- ✗ **Hadfield 2010 §8.2.1** cited in Face 1 prose (today's addition) — needs a literal reference entry

### Class 7 — Numerical cross-package consistency (V3)

- ✓ σ_p² MCMCglmm vs phylolm-derived: ~2% gap — fine
- ⚠️ σ_e² MCMCglmm vs phylolm-derived: ~27% gap — now honestly noted in prose
- ⚠️ λ ↔ H² (should be equal): phylolm λ = 0.763, MCMCglmm H² = 0.697 — ~8% gap; ALSO honestly noted

### Class 8 — Prose / text cross-section drift

- T8.1: §6 says A is "k × k tips-only OR all-nodes augmentation" — partially fixed (Face 1 intro now warns 116×116) but Tab 2 still shows 60×60 — covered by Class 1
- T8.2: §"Animal-model unification" uses `σ_A`; §6 uses `σ_p` — covered by Class 4
- T8.3: spatial section uses `Ω` (greek omega) — consistent within the section but never cross-linked to the phylogenetic A

### Class 9 — Headings / TOC

- ✗ V2-F11: TOC sidebar omits Face 1/2/3 h3 entries

### Class 10 — Code chunk visibility / pseudocode

- ✓ pdf_alongside_html helper now `echo = FALSE` (V1-D1 fixed)
- ⚠️ V2-F10: ~40-line shim_mcmcglmm function still visible to readers before the widget. Should be `echo = FALSE`.
- ✓ Spatial chunk explicitly flagged as pseudocode

### Class 11 — Widget CSS / layout

- ⚠️ V1-D4/V2-F4: assumption_table overflows article column by 48px (status column clipped)
- ⚠️ V1-D7: ▸ tab marker glued to "1." with no space
- ⚠️ V1-D8: tab IDs `-tab-eq`/`-tab-mat` semantically swapped relative to labels (internal-only)

### Class 12 — Tab-label / textContent quirks

- ⚠️ #132: Tab 3 textContent contains literal `\n` between "Equations" and "with data" (collapses in display)

## Proposed fix strategy

Given the maintainer's "address all" instruction and the "Tab 2 also shows 116×116" decision, the proposed sequence:

1. **Class 1 + Class 2 together** — fix the widget renderer so dimensions track expanded$M (Tab 2 = whatever Tab 3 shows) AND the widget σ/u letters track the §6 canonical name (`σ_p`, `u_p`) instead of substituting the ginverse group name. This requires touching:
   - `R/render-three-views.R` (the dimension annotation source)
   - The symbol_dictionary builder so dim_concrete carries the right number
   - The widget templates so they use canonical letters (or the §6 gloss uses the per-fit names — pick one)
2. **Class 3** — make Tab 1 vs Tab 2/Tab 3 response-symbol convention explicit (or unify)
3. **Class 4** — pick σ_p convention for §6 + §Animal-model + heritability_reading row; add quantitative-genetics alias note once
4. **Class 6** — add Moura 2021 + (if needed) Hadfield 2010 explicit refs
5. **Class 10** — `echo = FALSE` on shim chunk
6. **Class 11** — assumption_table responsive wrapper; ▸ marker spacing; tab-ID rename (internal)
7. **Class 9** — TOC depth fix
8. **Class 12** — investigate Tab 3 textContent `\n` (defer or fix)

## Recommendation

This is more inconsistency than I expected. Three options:

- **Option I**: I tackle all 12 classes in one big pass over the next ~2 hours, then rebuild + V4 + maintainer review.
- **Option II**: I tackle classes 1 + 2 + 4 (dimension + symbol naming — the user-visible core) and stop there; cosmetics in a follow-up slice.
- **Option III**: I write a `docs/specs/structural-dependence.md` golden-output spec FIRST that pins every dimension + symbol + name once, then fix the renderer to match. This is the v0.21-redo plan's Phase 0d work — strictly correct, but slower.
