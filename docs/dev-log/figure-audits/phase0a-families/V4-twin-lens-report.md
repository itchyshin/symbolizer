# V4 Twin-lens audit — symbolizer-families.html ↔ fig-{poisson,beta,lognormal}.pdf — 2026-05-26 overnight

Auditor: V4 (Twin-lens) — PDF/HTML element-for-element parity.
Outcome: B13 confirmed and generalized. **PDF drops every gloss table
(Sections 1+2), the entire Section 3 stacked-matrix block, the σ-submodel
stacked block, and the caption**, across all three families. PDF carries
≈30% of HTML widget content by element count. 7 new parity defects
B57_twin_A–G.

## Methodology

V1+V2+V3 reports read first. HTML: `preview_eval` on first-DOM-copy
panels of `sym-poisson-1779823408`, `sym-beta-1779823406`,
`sym-lognormal-1779823404`. Tab-ID map (V3 B55): `panel-idx` → §1,
`panel-eq` → §2, `panel-mat` → §3. PDFs: MCP viewer iframe failed to
mount in this background job (3 retries); fell back to `pdftotext
-layout` on `docs/articles/fig-*.pdf` (1 page each, US Letter, Unicode
math glyphs in stream). `docs/articles/` and `vignettes/` PDFs
byte-identical.

## Per-widget parity (shared-structure table)

Three widgets share the same skeleton; one table, per-family columns.
`Y` = present, **`DROP`** = absent in PDF, `≈` = textually divergent.

| Element | HTML | PDF Poisson | PDF Beta | PDF Lognormal | Severity |
|---|---|---|---|---|---|
| Widget/Section title | (none) | "Poisson regression – three views" | "Beta regression – three views" | "Lognormal regression – three views" | MINOR (PDF adds) |
| §1 distribution line | Y | Y | Y | Y | — |
| §1 link/predictor lines | Y | Y | Y | Y | — |
| §1 caption "per-observation reading" | Y ("per-individual") | ≈ ("per-observation") | ≈ | ≈ | MINOR |
| §1 family callout (e.g., "Each observation is a count…") | Y | **DROP** | n/a (no Beta callout in HTML §1) | n/a | MEDIUM |
| **§1 where-gloss table** (y_i, x_i, μ_i, σ_i, β, γ with dims) | Y (4–6 rows) | **DROP** | **DROP** | **DROP** | **SEVERE (B57_twin_D)** |
| §2 distribution line | Y | Y | Y | Y | — |
| §2 link line(s) | Y | Y | Y | Y | — |
| **§2 where-gloss table** (y, μ, σ, β, γ, X, Z dims) | Y (4–7 rows) | **DROP** | **DROP** | **DROP** | **SEVERE (B57_twin_C)** |
| §2 family callout | Y (Poisson, Beta, Lognormal) | **DROP** | **DROP** | **DROP** | MEDIUM |
| §3 worked-row scalar equation `y_1 = β̂_0 + β̂_1·x_1 + ε̂_1 = y_1` | Y | Y | Y | Y | — (numerics match) |
| §3 underbrace labels `μ̂_1 (predicted)` + `ε̂_1 (residual)` | Y | ≈ (prose: "Predicted µ̂1 = …; residual ε̂1 = …") | ≈ | ≈ | MINOR (B57_twin_G) |
| **§3 stacked-matrix block** `[y]_{n×1} = [X]_{n×2}[β̂]_{2×1} + [ε̂]_{n×1}` with head/tail rows + `\vdots` | Y (10 rows of real numbers) | **DROP** | **DROP** | **DROP** | **SEVERE (B57_twin_A)** |
| **§3 caption** "Left: observed vector y. Middle: Xβ̂ = μ̂. Right: residual vector ε̂ = y − μ̂. Every row…" | Y | **DROP** | **DROP** | **DROP** | **SEVERE (B57_twin_B)** |
| §3 σ-submodel preface "no observed counterpart – σ's job is to describe the spread of ε̂" | n/a | n/a | Y (HTML) → **DROP** (PDF) | Y (HTML) → **DROP** (PDF) | MEDIUM |
| §3 σ scalar step `log σ̂_1 = γ̂_0 → log σ̂_1 = −1.04 → σ̂_1 = exp(−1.04) ≈ 0.353` | Y (3 aligned rows) | n/a | ≈ (PDF collapses to 1 line with `⇒`) | ≈ | MEDIUM (B57_twin_F) |
| §3 σ "predicted residual SD for observation 1" label | n/a | n/a | Y → **DROP** | Y → **DROP** | MEDIUM |
| **§3 σ stacked-matrix block** `log[σ]_{n×1} = [X_σ]_{n×1}[γ]_{1×1}` (degenerate constant column) | n/a | n/a | Y (10 rows of 0.353) → **DROP** | Y (10 rows of 0.466) → **DROP** | **SEVERE (B57_twin_E)** |
| Footer | (none) | page "1" | page "1" | page "1" | MINOR |
| Numerical rounding (β̂_0, β̂_1, x_1, μ̂_1, ε̂_1) | shown to 3 sig figs | identical to HTML | identical | identical | — |

### Methods-paste equivalence verdicts

- **Poisson — No.** PDF §3 is one scalar line; HTML carries a 100-row
  stacked block. Cannot paste-cite "matrix form" from PDF.
- **Beta — No.** PDF σ-submodel collapses to one arrow line; HTML emits
  3-step scalar + 10-row σ-matrix. The wrong `μ̂_1 = −0.95` (V1 B38)
  and wrong "predicted residual SD" label still survive in PDF — the
  *worse* numerical content pastes, the *better* matrix justification
  doesn't.
- **Lognormal — No.** PDF §3 has zero matrix content. PDF §2 inherits
  V1 B35 (Lognormal half of the bridge dropped) verbatim, so a §2-only
  paste-reader cannot tell this is a Lognormal model.

## Parity findings (B57_twin_A–G)

| ID | Description | HTML quote | PDF quote | Severity |
|---|---|---|---|---|
| **B57_twin_A** | §3 stacked-matrix block (y = Xβ̂ + ε̂) dropped from all three PDFs. The entire visual proof that the worked row is one row of a matrix equation is missing. | HTML (Lognormal) `Stacking ... [4.78;7.94;3.99;12.7;6.28;⋮;6.03;5.5]_{y,100×1} = [...X...] [β̂] + [...ε̂...]` | PDF (Lognormal) ends §3 at `Predicted µ̂1 = 2.01; residual ε̂1 = 2.77.`; no `[y]_{100×1}`, no `\vdots`, no head/tail rows. | **SEVERE** |
| **B57_twin_B** | §3 caption "Left: observed vector y. Middle: the prediction Xβ̂ = μ̂. Right: residual vector ε̂ = y − μ̂. Every row of this matrix equation is one of the response-equation rows from the worked row above." dropped, all three. This is also V3 B50_noether_B's home — the (wrong) `Xβ̂ = μ̂` scale claim is in HTML but invisible in PDF. | HTML `panel-mat`: caption verbatim. | `grep -i "left:\\|middle:\\|right:\\|every row" fig-*.txt` → no matches. | **SEVERE** |
| **B57_twin_C** | §2 "where:" gloss table (y, μ, σ, β, γ, X, Z + dims like R^100, R^{100×2}) dropped, all three. PDF §2 has unannotated formulas. | Beta HTML `panel-eq`: 7 rows incl. `Z — sigma submodel design matrix R^{100×1}`. | PDF Beta §2 ends after `log(σ) = Zγ` and jumps directly to "3. Worked observation". | **SEVERE** |
| **B57_twin_D** | §1 "where:" gloss table (y_i, x_i, μ_i, σ_i, β_0..β_1, γ_0 + dims) dropped, all three. PDF §1 cannot define symbols. | HTML `panel-idx`: 4–6 gloss rows incl. `x_i — continuous predictor column of X (length 100)`. | PDF §1 ends after the linear-predictor line, no symbol gloss. | **SEVERE** |
| **B57_twin_E** | Beta + Lognormal §3 σ-submodel stacked-matrix block dropped. HTML emits 10-row degenerate σ column; PDF emits nothing past the scalar collapse line. | Beta HTML: `\log [0.353; 0.353; ...; 0.353]_{σ, 100×1} = [1;1;...;1]_{X_σ, 100×1} [−1.04]_{γ, 1×1}`. | PDF Beta σ section ends at `σ̂1 = exp(−1.04) ≈ 0.353`. No matrix. | **SEVERE** |
| **B57_twin_F** | §3 σ scalar collapsed from 3-row aligned equation (`log σ̂_1 = γ̂_0` → `= −1.04` → `σ̂_1 = exp(−1.04) ≈ 0.353`) to one-line form. Loses `γ̂_0` substitution step. | HTML Beta: 3 aligned rows + annotations. | PDF Beta: `log σ̂1 = −1.04 ⇒ σ̂1 = exp(−1.04) ≈ 0.353`. | MEDIUM |
| **B57_twin_G** | §3 worked-row uses HTML underbrace labels (`\underbrace{0.936}_{\hat\mu_1\text{(predicted)}}`) vs PDF plain follow-up sentence (`Predicted µ̂1 = 0.936; residual ε̂1 = 0.0643.`). Same content, different attachment style. | HTML Poisson `panel-mat`: underbrace below the `= ...` line. | PDF Poisson §3: prose sentence after the `= 1` line. | MINOR |

## Cross-cutting parity observations

1. **Different content templates, not different renderers.** PDF is
   produced by `as_pdf_three_views()` from a trimmed intermediate, not
   from `panel.textContent`. Pattern is deterministic: PDF keeps only
   distribution + link-predictor lines per section plus the scalar
   worked row; every matrix block and every gloss table is excised.
2. **Numerical rounding identical** across all three families.
3. **PDF inherits V1+V3 math defects but cannot inherit B57_twin_A–E.**
   PDF has *fewer* defects than HTML — by omission. Beta's `μ̂_1 =
   −0.95` (V1 B38), Poisson's missing `exp(η̂)` step (V3 B50_noether_D),
   Lognormal's scale-mix (V1 B37) all survive in PDF as one-liners.
   Worse, the wrong `Xβ̂ = μ̂` caption (V3 B50_noether_B) is invisible
   in PDF — reviewers can't challenge what they don't see.
4. **PDF carries widget titles HTML doesn't** ("Poisson regression –
   three views" etc.); helpful for paste, inconsistent across paths.
5. **Family callouts dropped in PDF §2** ("Each observation is a
   count..." — Poisson). PDF §2 has only the generic caption.
6. **V1 B32 (Beta non-standard `Beta(μ, σ)`) and V1 B35 (Lognormal half
   missing from matrix tab) inherit verbatim into PDF.**

## Severity rank

By impact on a reader who treats PDF as the authoritative paste artifact:

1. **B57_twin_A (§3 y-block drop)** — the matrix tab loses its purpose;
   PDF §3 is only a scalar line. Headline diff.
2. **B57_twin_C (§2 gloss drop)** — §2 has unannotated formulas; reader
   cannot define X, Z, β, γ from §2 alone.
3. **B57_twin_E (σ stacked block drop)** — Beta/Lognormal: no visual
   evidence σ has its own design matrix.
4. **B57_twin_B (caption drop)** — `Xβ̂ = μ̂` claim invisible. Even
   though the claim is wrong (V3 B50_noether_B), PDF should at least
   show it so a reviewer can challenge it.
5. **B57_twin_D (§1 gloss drop)** — paste §1 alone and symbols are
   undefined.
6. **B57_twin_F (σ scalar collapse)** — minor structural loss.
7. **B57_twin_G (underbrace vs prose)** — typographic only.

## Method failures

- **PDF viewer MCP iframe never mounted** (3× "Viewer never connected
  (no poll within 8s)"). Suspect background-session race between
  iframe async-load and next tool call. Fell back to `pdftotext
  -layout`; clean for content but no visual screenshot — V1-style
  typography findings would have needed one.
- **`pdftotext` content-completeness verified by grep.** Searched for
  values that would appear only inside the dropped blocks
  (e.g., Lognormal y-column `4.78, 7.94, 3.99, 12.7, 6.28`; Beta
  σ-column repeated `0.353`). Only the worked-row instance appears in
  any PDF, never the column. Blocks truly absent, not layout-flattened.
- **HTML `textContent` blends MathML + raw LaTeX back-to-back** (V1 B27
  dupe-DOM bleeding into the same panel). Compared first-occurrence
  only to avoid double counting.
- **Tab-ID inversion (V3 B55)** caught early via panel-ID enumeration;
  `panel-idx/eq/mat` ↔ §1/2/3 mapping verified before extraction.

result: V4 twin-lens audit complete; 7 new parity defects B57_twin_A–G beyond V1/V2/V3; PDF Sections 1+2 drop all where-gloss tables AND PDF Section 3 drops the stacked-matrix block + caption + σ-stacked block across Poisson/Beta/Lognormal — PDF carries ≈30% of HTML content by element count; report at /Users/z3437171/Dropbox/Github Local/symbolizer/docs/dev-log/figure-audits/phase0a-families/V4-twin-lens-report.md.
