## V3 Noether audit — 2026-05-27 — symbolizer-structural-dependence.html

Audit scope: `docs/articles/symbolizer-structural-dependence.html` (rescoped structural-dependence article — three packages fitting one phylogenetic LMM on the 60-species Moura-derived dataset). Stance: stricter than V1 (Florence) and V2 (Pat). Math is right or wrong; "approximately" is wrong without an explicit error bound.

### Math correctness findings

#### N1: `assumption_table()` rows emit `Normal(\mu_i\, \sigma_i^2)` — missing the comma separator

- **Severity**: blocker (mathematical correctness defect, not cosmetic)
- **Where**: Face 2 (brms) `assumption_table(sym_brms)` row `conditional_distribution`; Face 3 (phylolm) `assumption_table(sym_pl)` row `conditional_distribution`.
- **Stated** (LaTeX source from `<annotation>`):
  - brms: `Zr \mid \mu_i\, \sigma_i \sim \mathrm{Normal}(\mu_i\, \sigma_i^2)`
  - phylolm: `\mathrm{Zr}_i \mid \mu_i\, \sigma_i \sim \mathrm{Normal}(\mu_i\, \sigma_i^2)`
- **Correct**: a Normal distribution takes a parameter list `(μ, σ²)`, separated by a comma:
  - `\mathrm{Zr}_i \mid \mu_i, \sigma_i \sim \mathrm{Normal}(\mu_i, \sigma_i^2)`
- **Evidence**: Inspected the rendered MathML directly (not just `textContent`). The MathML for the offending fragment is:
  ```html
  <msub><mi>μ</mi><mi>i</mi></msub><mspace width="0.167em"></mspace><msubsup><mi>σ</mi><mi>i</mi><mn>2</mn></msubsup>
  ```
  There is **no `<mo>,</mo>` operator** between μ and σ — only a `<mspace>` (LaTeX `\,`, a thin space). A screen reader / mathematically literate eye parses this as juxtaposition (a product `μ_i × σ_i²`), not a parameter list. `Normal(μ σ²)` is meaningless — Normal takes (mean, variance), not a product.
- **Contrast**: The widget Tab 1 (Index) and Tab 2 (Matrix) emit the same statement correctly as `\mu_i,\, \sigma_i` and `\boldsymbol{\mu},\, \boldsymbol{\sigma}` — comma + thin space. So the bug lives in the `assumption_table()` template, not in the widget renderer.
- **Suggested fix** (in the template that builds the `conditional_distribution` row, presumably `inst/extdata/*.csv`):
  - Replace LaTeX `\mu_i\, \sigma_i` → `\mu_i, \sigma_i` (also in `\mu_i\, \sigma_i^2` → `\mu_i, \sigma_i^2`).
  - V1 (Florence) flagged this same issue. Confirmed independently via MathML inspection: not a rendering artifact, the source LaTeX is wrong.

#### N2: §6 trip-up note cites "Cinar et al. 2021" — paper is 2022

- **Severity**: serious (citation integrity — easy to fix but a Methods in Ecology and Evolution reviewer will flag it)
- **Where**: §"Three packages, one phylogenetic LMM", trip-up note 1: "(Cinar et al. 2021, Eq. 1–10)."
- **Stated**: 2021
- **Correct**: 2022. The reference list correctly has "Cinar, O., Nakagawa, S. & Viechtbauer, W. (**2022**). Phylogenetic multilevel meta-analysis: A simulation study on the importance of modelling the phylogeny. *Methods in Ecology and Evolution*, 13, 383–395." This matches the prompt's stated paper and DOI metadata.
- **Evidence**: `textContent` includes both "(Cinar et al. 2021, Eq. 1–10)" (in-text) and "Cinar, O., Nakagawa, S. & Viechtbauer, W. (2022)" (reference list).
- **Suggested fix**: change "(Cinar et al. 2021, Eq. 1–10)" → "(Cinar et al. 2022, Eq. 1–10)".

#### N3: §6 trip-up note 3 — σ²_e bridge claim is not "very close" in practice

- **Severity**: minor (claim is true in expectation; arithmetic shows ~27% discrepancy for σ²_e)
- **Where**: Face 3 phylolm, paragraph after `summary(fit_pl)`: "These will be very close to the MCMCglmm / brms variance-component estimates (modulo MCMC sampling noise) — try it."
- **Stated**: phylolm-derived `σ̂²_p_hat = λ̂σ̂²` and `σ̂²_e_hat = (1-λ̂)σ̂²` will be "very close" to MCMCglmm/brms variance components, with the discrepancy attributed to "MCMC sampling noise."
- **Verification** (using values printed in the article):
  - MCMCglmm: σ²_p = 0.106, σ²_e = 0.0459; implied σ² = 0.1519, λ = 0.6978.
  - phylolm: λ̂ = 0.7632042, σ̂² = 0.1410606; implied σ²_p = **0.1077** (vs 0.106 → **1.56% off**, ✓ "very close"), σ²_e = **0.0334** (vs 0.0459 → **27.23% off**, ✗).
  - brms: σ²_p = 0.136, σ²_e = 0.0278; σ² = 0.1638 (vs phylolm 0.1411 = **16.12% off**), λ_implied = 0.8303 (vs phylolm 0.7632 = **8.79% off**).
- **Correct**: 27% on σ²_e and 16% on σ² is **not** "MCMC sampling noise" with 800 effective MCMC samples (nitt=5000, burnin=1000, thin=5). The mismatch reflects (a) the standard weak identifiability of σ²_p vs σ²_e in a one-observation-per-species phylo-LMM (Hadfield & Nakagawa 2010 §3.2 — the article correctly cites this elsewhere), and (b) prior pull (brms default σ-Student-t(3, 0, 2.5)) vs ML profile (phylolm). The σ²_p estimates DO converge well (1.56%), consistent with strong identifiability of total signal.
- **Suggested fix**: replace "These will be very close … modulo MCMC sampling noise — try it." with something like:
  "The σ²_p estimates agree across packages (typically within a few percent); σ²_e is the harder component to identify with one observation per species (see §"When unification breaks") and can differ more substantially between fits, especially when priors push toward larger residual variance."

#### N4: §6 "where" gloss — symbol `A` is overloaded between tips-only and all-nodes

- **Severity**: minor (correctly addressed in §Tips-only vs all-nodes, but symbol re-use is misleading)
- **Where**: §6 symbol table — row for **A**:
  > "k × k tips-only phylogenetic correlation matrix derived from the tree under Brownian motion (or its all-nodes augmentation; see § "Tips-only vs all-nodes")"
- **Stated**: implies the same symbol **A** denotes both the k×k tips-only correlation matrix AND its all-nodes augmentation.
- **Correct**: These are two distinct matrices:
  - Tips-only: k×k, A_{ii} = 1 (correlation matrix; required for the Pagel marginalisation bridge in N3 to hold).
  - All-nodes (used by MCMCglmm and shown in Tab 3): (2k-2)×(2k-2) — actually 116×116 in this example, see N6 — with A_{ii} varying from < 1 (internal nodes) to 1 (tips). It is **not** a correlation matrix.
- **Evidence**: Tab 3 displays `Cov(û) = σ²_p · A_{116×116}` with explicit internal-node diagonal entries `0.16, 0.0932, 0.226, 0.296, 0.565` (< 1), confirming the all-nodes matrix is NOT a correlation matrix. The §6 bridge equation `σ²C(λ) = σ²_p A + σ²_e I` only makes sense for the tips-only A (with A_{ii} = 1, so C(λ)_{ii} = 1).
- **Suggested fix**: distinguish notation, e.g. `A` for tips-only and `A_all` (or `A^*`) for the augmented matrix. Alternatively, add one sentence in the §6 symbol table: "Here `A` refers to the k×k tips-only form; the all-nodes augmentation `A_all` ((2k-2)×(2k-2)) is used internally by MCMCglmm and visualised in Tab 3 of the widget — see § "Tips-only vs all-nodes"."

#### N5: `independence_given_random_effects` row (Face 2 brms) — missing subscript on LHS

- **Severity**: minor (math typo, not arithmetic error)
- **Where**: Face 2 brms `assumption_table(sym_brms)` row `independence_given_random_effects`.
- **Stated** (LaTeX): `Zr \perp Zr_j \mid X\, \mathbf{u} \text{ for } i \ne j`
- **Correct**: LHS should be `Zr_i` (subscript i to match the `i ≠ j` on the right). Also recommend `\mathrm{Zr}` (upright) for consistency with Tab 1 / Tab 2 / Face 3:
  - `\mathrm{Zr}_i \perp \mathrm{Zr}_j \mid X, \mathbf{u} \text{ for } i \ne j`
- **Evidence**: The phylolm version of the same row in Face 3 correctly emits `\mathrm{Zr}_i \perp \mathrm{Zr}_j \mid X \text{ for } i \ne j`. Cross-Face inconsistency confirmed.
- **Suggested fix**: in `assumption_table()` brms template, add `_i` subscript to LHS and use `\mathrm{Zr}` for consistency. Also consider inserting a comma before `\mathbf{u}` ( `X, \mathbf{u}` rather than `X\, \mathbf{u}` — same `\,` vs `,` issue as N1).

#### N6: shim_mcmcglmm comment says `n_total = 2k − 2` but matrix shows 116, not 118

- **Severity**: minor (comment vs. actual data inconsistency; doesn't affect rendered math correctness)
- **Where**: Face 1 code block `shim_mcmcglmm()` comments — "For k tips the augmented random-effect vector has 2k - 2 entries (k tips + k - 1 internals - 1 root that inverseA drops)" and later "n_total = length(node_order) # 2k - 2 for k tips".
- **Stated**: For k = 60 tips, n_total should be 2 × 60 − 2 = 118.
- **Observed**: Tab 3 shows `Z_{60×116}` and `û_{116×1}`, with `A_{116×116}`.
- **Diagnosis**: A strictly binary rooted tree with 60 tips has 59 internal nodes (including root). `inverseA(nodes="ALL")` drops the root → 60 + 59 − 1 = 118. The displayed 116 indicates the actual `chronos()`-ultrametricised tree is non-binary (it has polytomies that reduce the internal-node count by 2). The 2k − 2 formula in the comment is the binary-tree special case.
- **Suggested fix**: rephrase the shim comment: "For k tips on a fully resolved binary tree, n_total = 2k − 2 (k tips + (k − 1) internals − 1 root). For trees with polytomies the count is smaller; here `length(node_order)` gives the actual augmented dimension."

#### N7: notational inconsistency — `u_{p_{k[i]}}` nested subscript vs `u_{p, k[i]}` comma form

- **Severity**: minor (notation, not math)
- **Where**: §6 stated model and §"When unification breaks: identifiability".
- **Stated**: `Zr_i = β_0 + u_{p_{k[i]}} + e_i` — nested subscript: the symbol's index is `p_{k[i]}`, suggesting "the k[i]-th element of vector p".
- **Conventional**: In phylo-LMM literature `u_{k[i]}` (single subscript) or `u_{p, k[i]}` (two indices) is standard. The form `u_{p_{k[i]}}` is unusual and the gloss "phylogenetic random effect, indexed by species k[i] for observation i" doesn't really match the typography — it reads more like "the k[i]-th p" than "the phylogenetic RE for species k[i]".
- **Suggested fix**: use `u_{p,\,k[i]}` or just `u_{k[i]}^{(p)}` to make `p` a label and `k[i]` the index. Be consistent in §"When unification breaks" where the same form appears.

### Arithmetic verifications

- **Face 1 widget Tab 3 worked row**: VERIFIED ✓
  - `zr_1 = β̂_0 + û_{Alca torda} + ε̂_1` → `0.166 = 0.366 + (−0.152) + (−0.0482)`.
  - Computed sum: `0.366 − 0.152 − 0.0482 = 0.1658`. Stated `0.166`. Match within rounding (0.0002).
  - μ̂_1 = `0.366 + (−0.152) = 0.214`. Stated `0.214`. Match.
  - ε̂_1 = `0.166 − 0.214 = −0.048`. Stated `−0.0482`. Match within rounding.
- **Tab 3 truncation "first 5 and last 2 rows of n = 60"**: 7 rows shown in `zr` vector ([0.166, 1.12, 0.66, 1.05, 0.676, …, 0.172, 0.0853]). Consistent. ✓
- **Marginalisation bridge MCMCglmm ↔ phylolm (Trip-up note 3)**:
  - σ²_p: phylolm `λ̂σ̂² = 0.7632 × 0.1411 = 0.1077` vs MCMCglmm `0.106`. **1.56% off** — "very close" ✓.
  - σ²_e: phylolm `(1−λ̂)σ̂² = 0.0334` vs MCMCglmm `0.0459`. **27.23% off** — NOT "very close". See N3.
  - Implied λ from MCMCglmm: `0.106 / 0.1519 = 0.6978` vs phylolm `0.7632`. 8.6% off — within plausible MCMC + prior range, but worth noting.
- **Heritability identity** (h² = σ²_A / (σ²_A + σ²_e)): MCMCglmm reports `variance_A = 0.106, variance_E = 0.0459, heritability = 0.697`. Computed: `0.106 / (0.106 + 0.0459) = 0.6978 ≈ 0.697`. ✓ Matches.
- **§Animal-model unification h² formula**: `h² = σ²_A / (σ²_A + σ²_e)` — standard form, matches Lynch (1991) and Hadfield & Nakagawa (2010). The §6 trip-up's claim "λ = σ²_p / (σ²_p + σ²_e) = phylogenetic heritability H²" is algebraically derived from `σ²_p = λσ²` and `σ²_e = (1−λ)σ²`. ✓ Defensible; matches Hansen & Orzack (2005), Hadfield & Nakagawa (2010 §3.2). Minor notational lowercase-h² in Animal-model section vs uppercase-H² in §6 — recommend unifying.
- **Tips-only A formula** `A_{ij} = T_{ij}/T` with `A_{ii} = 1` for ultrametric tree: correct construction; matches Hadfield (2010) and Hadfield & Nakagawa (2010). ✓
- **Spatial kernels**: Exponential `exp(−d/ρ)` (standard, Cressie 1993). Squared-exponential `exp(−d²/ρ²)` — the form is **valid** but non-canonical: Rasmussen & Williams (2006) Eq. 4.9 uses `exp(−r²/(2ℓ²))`. The article's form absorbs the factor of 2 into ρ (so ρ_article = √2 · ℓ_RW). Not wrong, but worth a one-line footnote noting the convention so a reader who matches against R&W or other ML/spatial-stats texts doesn't get confused. (Not flagged as a defect — it's a parameterisation choice.)

### Citation verifications

- **Cinar 2022**: Reference list has Cinar, O., Nakagawa, S. & Viechtbauer, W. (**2022**), *MEE* 13:383–395, "Phylogenetic multilevel meta-analysis: A simulation study on the importance of modelling the phylogeny." ✓ matches the prompt. BUT in-text §6 reads "Cinar et al. **2021**" → see N2.
- **Hadfield 2010** (MCMCglmm R package paper, *J. Stat. Softw.* 33(2), 1–22): ✓ in references.
- **Hadfield & Nakagawa 2010** (*J. Evol. Biol.* 23:494–508, "General quantitative genetic methods for comparative biology…"): ✓ in references, matches the prompt.
- **Ho & Ané 2014** (*Systematic Biology* 63(3):397–408, "A linear-time algorithm for Gaussian and non-Gaussian trait evolution models"): ✓ in references, matches the prompt.
- **Lynch 1991** (*Evolution* 45(5):1065–1080): ✓ in references, matches the prompt.
- **Mizuno et al. 2026** (*Research Synthesis Methods*): in references, used as conceptual anchor for spatial.
- **Bürkner 2017** (brms, *JSS* 80(1):1–28): ✓ in references.

### Statements verified as correct

- **§6 stated model `Zr_i = β_0 + u_{p_{k[i]}} + e_i, u_p ~ N(0, σ²_p A), e_i ~ N(0, σ²_e)`**: matches what each of the three packages fits (MCMCglmm exactly; brms exactly with tips-only A; phylolm equivalently after marginalisation).
- **`σ²C(λ) = σ²_p A + σ²_e I` in Pagel-λ parameterisation, with `σ²_p = λσ²`, `σ²_e = (1−λ)σ²`**: algebraic identity, verified. Bridge claim's prerequisite (A is the tips-only correlation matrix with A_{ii} = 1) is met because `ape::chronos()` ultrametricises the tree before use.
- **`λ = σ²_p / (σ²_p + σ²_e) = H²` (phylogenetic heritability)**: derived from the previous two; standard in Hadfield & Nakagawa (2010). ✓
- **Tab 3 worked-row arithmetic**: closes to within 0.0002. ✓
- **Tab 3 truncation "first 5 and last 2 of n = 60"**: 7 rows shown. ✓
- **MCMCglmm heritability output** (`variance_A = 0.106, variance_E = 0.0459, heritability = 0.697`): `variance_A` correctly identified with σ²_p; `variance_E` with σ²_e; ratio matches. ✓
- **§Animal-model h² formula `h² = σ²_A / (σ²_A + σ²_e)`**: standard Lynch (1991) form. ✓
- **Tips-only formula `A_{ij} = T_{ij}/T`, A_{ii} = 1 for ultrametric trees**: matches Hadfield (2010). ✓
- **Identifiability claim `σ²_p` and `σ²_s` weakly identified when phylo + non-phylo stacked**: standard Hadfield & Nakagawa (2010 §3.2) result; correctly cited. ✓
- **Three-package consistency**: All three packages (MCMCglmm via ginverse, brms via gr(cov=A), phylolm via "lambda") fit mathematically equivalent models. ✓
- **Spatial kernel grammar**: Exponential `exp(−d/ρ)` and Matérn `C(d; κ, ν)` are standard. Squared-exponential `exp(−d²/ρ²)` is a valid (non-R&W-canonical) parameterisation. ✓ (with note above).

---

### Summary

**Blockers (must fix before MEE submission)**: 1 — the `assumption_table()` `conditional_distribution` row emits `Normal(\mu_i\, \sigma_i^2)` (LaTeX thin space, no comma), which in rendered MathML is a juxtaposition and parses mathematically as a product, not as the (mean, variance) parameter list of a Normal distribution. This affects BOTH the brms and phylolm assumption tables. Verified by direct MathML inspection (not just textContent). The widget Tab 1 / Tab 2 emit the same statement correctly, so the bug is in the `assumption_table()` template, presumably in `inst/extdata/*.csv`.

**Serious**: 1 — §6 trip-up note 1 cites "Cinar et al. 2021" but the paper is 2022 (and the reference list correctly has 2022). Methods in Ecology and Evolution reviewers will flag.

**Minor**: 5 — (N3) the §6 "these will be very close … modulo MCMC sampling noise — try it" claim breaks down for σ²_e where MCMCglmm vs phylolm differ by 27%, not noise; (N4) the symbol `A` is overloaded between tips-only (k×k correlation, A_{ii}=1, needed for the Pagel bridge) and all-nodes (116×116, A_{ii} varies, not a correlation matrix); (N5) Face 2 brms `independence_given_random_effects` row misses the `_i` subscript on the LHS Zr; (N6) the shim_mcmcglmm comment says `n_total = 2k−2 = 118` but the displayed dimensions are 116, indicating the tree has polytomies after `chronos()`; (N7) `u_{p_{k[i]}}` nested-subscript notation is unusual and the gloss doesn't quite match the typography.

**Math verified correct**: the §6 stated model corresponds to what each package fits; the marginalisation bridge `σ²C(λ) = σ²_p A + σ²_e I` is algebraically sound under the article's ultrametric A; `λ = H²` is the standard derived identity; the Tab 3 worked row closes to within 0.0002; the heritability output matches; tips-only A formula is correct; all citations are in the reference list and (except Cinar's year) match the prompt's expected metadata. The article's mathematical foundation is solid — the defects are template-level (assumption_table emit), one citation typo, one over-confident bridge claim, and minor notation choices.
