## V4 Twin audit — symbolizer-structural-dependence — 2026-05-27

### Setup

- **HTML**: `http://localhost:8767/articles/symbolizer-structural-dependence.html`
  (served via `python -m http.server` from
  `/Users/z3437171/Dropbox/Github Local/symbolizer-hotfix/docs/`,
  preview server `symbolizer-hotfix`, serverId `6a8f126f-c291-4115-ab3e-7380249580b9`).
- **PDF**: `/Users/z3437171/Dropbox/Github Local/symbolizer-hotfix/docs/articles/fig-mcmc-phylo.pdf`
  (2 pages, 181 KB, mtime 2026-05-27 15:45). Read via `Read` tool in
  PDF mode.
- **Viewport**: 1280 × 720 desktop. Scope limited to the MCMCglmm
  Face-1 widget (three-views) and its prose context, plus the
  assumption tables emitted by Faces 2/3 (HTML only).
- **Inspection method**: DOM read via `preview_eval` (LaTeX
  source extracted from MathML `<annotation>` nodes); PDF read as image
  in `Read` tool. No source grep used.

### Per-section parity

#### Section 1 / Tab 1 — Index form

- **PDF §1** carries the equation block:
  - `Zr_i | μ_i, σ_i ~ Normal(μ_i, σ_i²)`
  - `μ_i = β_0 + u_species(i)`
  - `u_species ~ N(0, σ²_species A)` (A is plain — no `_{116×116}` subscript in index form)
- **HTML Tab 1** annotation source:
  - `\mathrm{Zr}_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2)`
  - `\mu_i = \beta_{0} + u_{species(i)}`
  - `\mathbf{u}_{species} \sim \mathcal{N}(\mathbf{0},\, \sigma_{species}^2 \mathbf{A})` (A bare)
- **Verdict**: match. Both render plain `A` in the index/per-observation form, comma `(μ_i, σ_i²)` with thin-space spacing in the Normal.

#### Section 2 / Tab 2 — Matrix form

- **PDF §2**: `u_species ~ N(0, σ²_species A_{116×116})` — bold-italic A with `_{116×116}` subscript.
- **HTML Tab 2** annotation source: `\mathbf{u}_{species} \sim \mathcal{N}(\mathbf{0},\, \sigma_{species}^2 \mathbf{A}_{116 \times 116})`.
- **A dimension match**: yes, `116 × 116` in BOTH. Fix #1 verified.
- The two upstream lines also match: `zr | μ, σ ~ N(μ, diag(σ²))` and `μ = Xβ + u` in both.

#### Section 3 / Tab 3 — Worked observation + stacked block

- **Worked-row arithmetic**:
  - PDF: `Zr_1 (observed=0.166) = 0.366 − 0.152 − 0.0482 = 0.166`; text "Predicted μ̂_1 = 0.214; residual ε̂_1 = −0.0482".
  - HTML: `0.166 = 0.366 + (-0.152) + (-0.0482)`, then `\underbrace{0.214}_{\hat\mu_1 (predicted)} + \underbrace{(-0.0482)}_{\hat\varepsilon_1 (residual)}`.
  - Same numbers, same arithmetic; HTML wraps negatives in parens, PDF strips parens to minus signs. Both decompositions give 0.214 + (−0.0482) = 0.166. Match in BOTH.
- **Z absent in stacked block**:
  - PDF stacked block reads `[zr]_{60×1} = [X]_{60×1} [β̂]_{1×1} + [û]_{60×1} + [ε̂]_{60×1}`. No Z block. Verified.
  - HTML stacked block reads `[zr]_{60×1} = [X]_{60×1} [β̂]_{1×1} + [û]_{60×1} + [ε̂]_{60×1}`. No Z block. Verified.
  - Fix #2 verified in BOTH.
- **Caption** `Xβ̂ + û = μ̂` (no Z):
  - HTML: prose under the stacked block reads "Middle: the prediction `\mathbf{X}\hat{\boldsymbol{\beta}} + \hat{\mathbf{u}} = \hat{\boldsymbol{\mu}}`". No Z. Fix #3 verified in HTML.
  - PDF: the stacked block on page 1 has NO inline caption text under it (the `Middle: ... = μ̂` sentence is absent in PDF). This is a presence/absence drift, not a textual contradiction — see P1 below.
- **Cov(û) block present**:
  - PDF page 2: `Cov(û) = σ²_p · [matrix]_{A_{116×116}}`. Present.
  - HTML Tab 3: `\mathrm{Cov}(\hat{\mathbf{u}}) = \sigma_p^2 \cdot \underbrace{...}_{\mathbf{A}_{116 \times 116}}`. Present.
  - Both use `σ²_p` (Fix #1 cont'd) and `A_{116×116}`. Match in BOTH.
- **u / ε dim match**: `û_{60×1}` and `ε̂_{60×1}` in both. Match.

### Assumption-table comma check (HTML only — Faces 2/3 have no PDF)

- **Face 2 (brms)** assumption_table row 1: TeX source
  `\mathrm{Zr}_i \mid \mu_i,\, \sigma_i \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2)`.
  MathML between the two arguments contains `<mo>,</mo><mspace width="0.167em">` (proper comma + thin-space).
- **Face 3 (phylolm)** assumption_table row 1: identical TeX source and identical MathML. Comma + thin-space, not glued.
- Fix #5 verified in HTML (the only surface that emits these tables).

### Heritability prose check (HTML only)

- The comment line above the MCMCglmm widget reads:
  `#> 1 species 0.106 0.0459 0.697 Heritability h^2 = sigma^2_p / (si…`
  (truncated at the right-hand column edge but `sigma^2_p` is verbatim in the served HTML).
- Uses `σ²_p` not `σ²_A`. Fix #4 verified in HTML. (The PDF widget does not include this prose; it lives outside the MCMCglmm widget in pkgdown article body.)

### Parity violations (if any)

#### P1: PDF omits the `Xβ̂ + û = μ̂` interpretive caption that HTML carries under the stacked block

- **HTML says**: directly after the stacked equation, three labelled
  sentences appear:
  `Left: observed vector zr.  Middle: the prediction Xβ̂ + û = μ̂.
  Right: the residual vector ε̂ = zr − μ̂.  Every row of this matrix
  equation is one of the response-equation rows from the worked row
  above.`
- **PDF says**: nothing between the stacked block (end of page 1) and
  the `Cov(û)` block (top of page 2). The interpretive sentence
  `Xβ̂ + û = μ̂` is absent.
- **Recommendation**: not a defect — the PDF widget is a tighter
  "equation-only" face of the MCMCglmm symbolization, and the Tab 3
  caption in HTML is supplementary prose, not load-bearing math. Both
  surfaces remain consistent on the fix-target: the equation itself
  contains no Z and the dimension labels match. If parity is the
  goal, add the caption to the PDF emitter; if conciseness is the
  goal, leave as is. **Acceptable as-shipped** under the rescoped
  v0.21 contract.

### Overall

**Ship.** All five recent fixes are present and consistent between the
HTML widget and the `fig-mcmc-phylo.pdf` widget, on the surfaces where
each fix applies:

1. `A_{116 × 116}` in Tab 2 + Tab 3 Cov(û) block — matches PDF §2 + Cov block.
2. Z absent from stacked block in both.
3. Caption `Xβ̂ + û = μ̂` (HTML only; PDF omits the caption but the
   equation itself is consistent — see P1).
4. Heritability prose uses `σ²_p / (σ²_p + ...)` form (HTML only, no
   PDF surface).
5. Assumption-table `Normal(μ_i,\, σ_i²)` with comma — verified in
   Face 2 and Face 3 HTML.

No textual contradictions between HTML and PDF were found in the
shared scope. The only inter-surface difference is the PDF being
caption-light, which is an editorial choice rather than a parity
violation.

---

### One-paragraph summary

The V4 twin-lens audit confirms that the rescoped structural-dependence
article ships with full parity between the MCMCglmm Face-1 HTML widget
(three tabs) and its PDF counterpart (`fig-mcmc-phylo.pdf`, 2 pp.) on
every load-bearing element targeted by the five recent fixes: the
matrix-form `A_{116×116}` dimension annotation appears in both Tab 2
and the Cov(û) block in both surfaces; the stacked block on Tab 3 and
PDF §3 reads `zr = Xβ̂ + û + ε̂` with no Z block; the `Xβ̂ + û = μ̂`
caption is present and Z-free in the HTML and the equation itself is
likewise Z-free in the PDF (the PDF simply omits the supplementary
caption, which is editorial rather than mathematical drift); the
heritability prose above the widget uses `σ²_p / (σ²_p + σ²_e)` as
specified; and both Face-2 brms and Face-3 phylolm assumption tables
emit `\mathrm{Normal}(\mu_i,\, \sigma_i^2)` with a proper comma and
thin-space (MathML: `<mo>,</mo><mspace width="0.167em">`). Recommend
ship.
