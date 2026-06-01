# symbolizer (development version)

## Audit remediation -- docs, vignette build-safety, pkgdown framing

A read-only package audit surfaced several low-risk doc/build issues, fixed here:

* **`symbolize.bam` is now documented.** The exported `bam` method had no
  `\alias`, producing an R CMD check "undocumented S3 method" warning and no
  reference page for an advertised class; it now shares the `symbolize.gam`
  topic via `@rdname`.
* **`symbolizer-structural-dependence` vignette is now build-safe.** It gained
  the `eval = requireNamespace(...)` setup guard every sibling vignette already
  had, so `pkgdown::build_site()` no longer fails when a Suggests package
  (MCMCglmm / brms / phylolm / metafor / ape / metadat) is absent.
* **Family count corrected to eleven.** The quickstart and families vignettes
  and the README undercounted the supported families as "ten" and omitted
  `phylolm`; all now list eleven families including `phylolm`.
* **README status legend** now uses the canonical "Unsupported or blocked"
  status word (was "Unsupported").
* **pkgdown Articles index** now has a `desc:` framing line on every group
  (Deep dives / Cross-package bridges / Where we're going), not just "Get
  started".

## Variance-components surface -- "where does the variation live?"

A mixed model's payoff for a biologist is *where the variation lives* and
*how repeatable a trait is*. symbolizer computed the variance components and
then dropped them. This surface closes that gap, Gaussian-first, with a hard
honesty contract. Spec: `docs/specs/variance-components.md`. Built in four
TDD slices.

* **Numbers, not just symbols (S1).** Every mixed-model extractor's
  `variance_components` tibble now carries numeric `sd_estimate` /
  `var_estimate`; the drmTMB builder, which previously carried only symbols,
  was fixed to populate them from `fit$sdpars`. `explain()` and
  `model_card()` now surface a "How the variation splits" section whenever
  the fit has random effects.
* **New accessor `variance_partition()` (S2).** One row per variance source
  (`component`, `variance`, `sd`, `pct`), with a residual row and `pct`
  shares that sum to 1 when the residual variance is defined; otherwise the
  variances are shown and `pct` is `NA` with a reason.
* **New accessor `icc()` (S2).** The intraclass correlation / repeatability,
  carrying an explicit `scale` attribute. Gaussian-identity single random
  intercept gives a **data-scale** ICC (a true proportion of variance);
  binomial gives a **latent-scale** ICC (logit residual \eqn{\pi^2/3},
  probit residual 1) with a mandatory "not a proportion of variance in the
  observed outcome" caption. Any other family, a location-scale Gaussian
  whose residual SD varies, or more than one random-effect term returns `NA`
  with a human-readable reason rather than a misleading number.
* **Widget panel (S3).** The three-views Index tab now shows a "where does
  the variation live?" panel beneath the random-effects glossary: a plain-CSS
  bar (a stacked between/within bar for two components, per-component bars
  for three or more), one sentence, and the ICC line. No bar -- only the
  table and the "ICC not available on this scale yet" line -- when the ICC is
  undefined.
* **Partial-pooling caption (S4).** The Tab 3 worked-row BLUP block carries a
  prose-only caption explaining that the random-effect estimates are shrunk
  toward zero (partial pooling); no numbers.
* **GLMM repeatability demo + `knit_print` (S5).** New `knit_print` methods for
  `variance_partition()` / `icc()` render the bar + numbers table + the
  scale-labelled ICC reading as HTML in a knitted document, so the bar travels
  outside the three-views widget. New vignette
  `vignette("symbolizer-variance-components")` ("Where the variation lives: ICC
  and repeatability") walks a Gaussian `lme4::lmer`, a binomial `lme4::glmer`
  (latent-scale ICC), and a `glmmTMB` refit (same reading, different engine),
  framed as repeatability in the rptR tradition, with an explicit account of
  when the ICC is `NA` and why.

All reader-facing prose is templated from
`inst/extdata/variance-readings.csv` (no string-spliced prose in R). Point
estimates only; no confidence intervals. The panel and caption ship in the
HTML widget; PDF/HTML parity for the variance surface is deferred to the
Pattern J payload rebuild (see the spec's scope-boundary note).

# symbolizer 0.22.3

## v0.22.3 -- family-aware Tab 3 worked row for non-Gaussian families

Closes the BLOCKER on `symbolizer-families.html` surfaced by the v0.22.2
Fisher pass
(`docs/dev-log/figure-audits/v0.22.2-audit-pass/families-fisher.md`).

Before this release the Tab 3 worked-row helper hardcoded the Gaussian
template

$$y_1 = \beta_0 + \beta_1 x_1 + \hat{\varepsilon}_1$$

for every family. For non-identity-link families the displayed
$\hat{\mu}_1$ was the **linear predictor** $\hat{\eta}_1$ not the
**response-scale predicted mean**, the additive $\hat{\varepsilon}_1$
was meaningless (Poisson has no residual in its likelihood at all), and
the rendered values were either off by orders of magnitude or
mathematically impossible. The Beta widget displayed
$\hat{\mu}_1 = -0.95$ -- impossible for a Beta mean which must be in
$(0,1)$; the correct response-scale value is
$\mathrm{logistic}(-0.95) = 0.279$.

### Three slices (TDD)

**Slice 1 -- `R/symbolize-drmtmb.R`:** `drm_build_expanded()` now stores
the linear predictor in a new `$expanded$eta_hat` slot and applies the
mu-submodel link inverse to obtain `$expanded$mu_hat` on the response
scale. Helper `drm_apply_link_inverse(eta_hat, link)` covers
identity, log, logit, probit, cloglog, and inverse. For
Gaussian-identity and the drmTMB Lognormal-on-mu-of-log-Y convention,
`mu_hat == eta_hat` and the historic behaviour is preserved.

**Slice 2 -- `R/render-three-views.R`:** the Tab 3 worked-row helper
becomes family-aware and emits one of three shapes:

- **Additive Gaussian** (Gaussian, Student-t):
  $y_1 = \beta_0 + \beta_1 x_1 + \hat{\varepsilon}_1$ -- the historic
  form, kept for back-compat.
- **Additive log** (Lognormal):
  $\log(y_1) = \beta_0 + \beta_1 x_1 + \hat{\varepsilon}_1^{(\log)}$
  -- the residual is on the log scale where the Gaussian noise lives.
- **Generalized** (Poisson, Beta, Binomial, Gamma, NegBinom):
  $\hat{\eta}_1 = \beta_0 + \beta_1 x_1$, then
  $\hat{\mu}_1 = \mathrm{link}^{-1}(\hat{\eta}_1)$, then
  $y_1 \sim \mathrm{Family}(\hat{\mu}_1, \ldots)$ -- no spurious
  additive $\hat{\varepsilon}_1$.

**Slice 3 -- `R/render-three-views.R` (sigma submodel):**
`three_views_worked_row_sigma()` takes the family argument and labels
the $\hat{\sigma}_1$ submodel correctly per family:

- gaussian / student: predicted residual SD (unchanged)
- lognormal: log-scale residual SD (SD of $\log y$)
- beta: predicted **precision $\hat{\phi}_1$** (NOT an SD)
- gamma: predicted dispersion
- nbinom1 / nbinom2: predicted dispersion (size parameter $k$)

### Tests

- `tests/testthat/test-symbolize-drmtmb-link-scale.R` (9 expectations):
  Poisson $\hat{\mu}_1 = \exp(\hat{\eta}_1)$; Beta $\hat{\mu}_1 \in (0,1)$;
  Lognormal $\hat{\mu}_1 = \hat{\eta}_1$ (drmTMB identity-on-mu);
  Gaussian back-compat.
- `tests/testthat/test-three-views-worked-row-families.R` (5
  expectations): Poisson drops spurious $\varepsilon$; Poisson shows
  $\exp$ back-transform; Beta shows response-scale $\hat{\mu}_1$
  matching $\sym$expanded$mu_hat[[1]]$; Beta $\sigma$ row labelled as
  precision $\phi$; Gaussian-identity keeps the historic shape.
- `tests/testthat/test-expand.R`: slot list updated to include
  `eta_hat`.

Full suite: `FAIL 0 | SKIP 0 | PASS 1908` (+13 from new tests beyond
the 1893 in v0.22.2-mu_hat-with-Zu).

### Rendered HTML verification

Spot-checks on `docs/articles/symbolizer-families.html`:

```
Poisson \hat{\eta}_{1} line:              4 matches
Poisson \exp() back-transform:            7 matches
Poisson y ~ Poisson(...) declaration:    11 matches
Beta logistic link in worked row:         2 matches
Beta "precision \phi" label:              2 matches
Lognormal \log scale references:         19 matches
Lognormal "log-scale residual SD" label:  3 matches
Beta misleading "predicted residual SD":  0 matches  ← was the bug
```

### Out of scope (deferred to a separate slice)

- The other extractors (gllvmTMB, glmmTMB, lme4, brms, MCMCglmm,
  metafor, phylolm, mgcv, sdmTMB) have not been audited under the
  Fisher protocol yet. The two-tier and structural-dependence widgets
  may have analogous bugs; both Codex audits started during v0.22.2
  were killed by the maintainer mid-run.
- CRAN submission is paused per maintainer direction
  (2026-05-28 21:55): focus on families correctness first.

# symbolizer 0.22.2

## v0.22.2 -- multi-tier random-effects in Tab 3 (Slice A1 + A2 + worked-row polish)

Closes the second of the two bugs the maintainer's Fisher pass
surfaced on 2026-05-28: the phylogenetic random-effect tier was
silently invisible in Tab 3 of the meta-multilevel widget, because
`drm_build_expanded()` extracted only the first random-effect tier
via `re_per_entry[[which(has_re)[1L]]]`. For phylo + study fits, the
35-species phylogenetic tier (the article's central thesis) was
hidden behind a single bare `Z` aggregate that actually held only
the iid study tier.

This release replaces the single-tier extraction path with a
per-tier one. Every random-effect tier present in `re_per_entry`
is now surfaced into the `$expanded$Z_per_tier` and
`$expanded$u_per_tier` slots, with kinds tagged in
`$expanded$tier_kind` (`"iid"` or `"structured"`). The Tab 3
stacked matrix block iterates these slots so every tier shows up
in the equation; the worked-row at observation 1 likewise
expands to include each tier's BLUP. Single-tier fits keep the
historic shape (no `_g` subscripts, no per-tier subscript on
`\hat{u}`) for back-compat.

### Numerical contract

Per the Fisher protocol from `docs/specs/import-from-sisters.md`:

$$\mathbf{X}\hat{\boldsymbol{\beta}} + \sum_g \mathbf{Z}_g \hat{\mathbf{u}}_g = \hat{\boldsymbol{\mu}}$$

verified to 2.5e-14 on the Pottier thermal subset (35 species
× 39 studies × 164 effects), well under the protocol tolerance
of 1e-9. Closure holds for both the iid tier (study) and the
structured tier (phylogeny, where BLUPs are extracted from
`fit$obj$report()$u_phylo[1:n_tips]` in factor-level order).

### Renderer changes

- `as_html_three_views()` Tab 3 stacked block iterates
  `$expanded$Z_per_tier` and emits one `\mathbf{Z}_g
  \hat{\mathbf{u}}_g` block per tier with `\text{...}`-wrapped
  subscripts so multi-character group names like `study_ID`
  render legibly.
- The worked-row helper (`three_views_worked_row()`) iterates the
  same per-tier slots and emits one `\hat{u}_{g,\,\text{level}(1)}`
  term per tier. On the Pottier widget, observation 1 now shows
  `+ \hat{u}_{\text{study\_ID},\,3}
   + \hat{u}_{\text{phylogeny},\,\text{Myzus\_persicae}}`,
  carrying the BLUP for each tier so the scalar arithmetic closes.
- Pattern O smart-column-truncation now promotes informative MIDDLE
  columns into the visible head/tail when neither structural head
  nor tail contains any 1s within the visible row band. The phylo
  Z column on the Pottier fit (visible species: Myzus_persicae
  at col 18, Oreochromis_niloticus at col 20 of 35) now displays
  the 1s rather than all zeros.

### Extractor changes

- `drm_build_expanded()` now accepts a
  `structured_matrix_for_group` argument and threads it through
  to flag structured tiers (where BLUPs come from
  `fit$obj$report()$u_phylo` rather than
  `fit$random_effects$mu$terms`).
- The factor-coercion-before-`model.matrix` discipline from
  v0.22.1.3 applies per-tier; numeric grouping variables for
  ANY tier are correctly turned into one-hot incidence matrices.

### Tests

- New `tests/testthat/test-symbolize-drmtmb-per-tier-Z.R` (30
  expectations): two-tier iid fit surfaces both Z, Pottier
  meta-multilevel surfaces study + phylogeny with full Fisher
  closure at 1e-9, single-RE back-compat $Z_g/$u alias semantics.
- `tests/testthat/test-expand.R` updated to list the new slot
  names on `$expanded`.
- Full suite: `FAIL 0 | SKIP 0 | PASS 1891` (+30 from new tests
  beyond 1861).

### Audit trail

- `docs/dev-log/figure-audits/v0.22.1-meta-phylo/claude-fisher-audit.md`
  is the numerical Fisher pass that surfaced both bugs.
- `docs/specs/import-from-sisters.md` is the synthesis of three
  sister-repo scouts (drmTMB / glmmTMB / gllvmTMB) into a
  discipline-import spec. This release implements Priority 1
  (Z-matrix bug class) and part of Priority 2 (Fisher closure
  baked into a regression test).

### Known residuals

- Codex CLI Fisher-pass demo is still pending a CLI upgrade
  (`codex-cli 0.120.0` does not yet support the backend's `gpt-5.5`
  routing). The Claude-authored Fisher pass substitutes; live
  Codex demo deferred.
- The remaining Priority 3-6 imports (V-agent registry expansion,
  after-task `_TEMPLATE.md`, `tools/` enforcement scripts,
  `.codex/agents/` stubs) are deferred to v0.22.3-discipline.

# symbolizer 0.22.1.3

## v0.22.1.3 -- drmTMB Z_g extractor fix (numeric group_var)

**Bug fix.** `drm_build_expanded()$Z_g` was being constructed via
`stats::model.matrix(~ 0 + g_var, data = fit$data)` without coercing
`g_var` to factor. When `g_var` is a NUMERIC variable in `fit$data`
(very common -- `study_ID`, `site_id`, `animal_id` codes are
typically integer-coded), `model.matrix` does NOT build a one-hot
incidence matrix. It returns a single-column matrix carrying the
literal integer values. The widget Tab 3 then displayed a
`164 x 1` Z column of raw study integers `[3, 3, 3, ..., 147, 147]`
next to a `39`-vector of BLUPs, and the displayed
$\mathbf{Z}\hat{\mathbf{u}}$ arithmetic in the worked row was
meaningless (`3.29e-18` instead of the true BLUP value `9.74e-11`
for study_ID = 3).

Surfaced by the maintainer's Fisher-pass on the v0.22.1.2 rendered
widget -- the V1 Florence and V3 Noether audits had both
rubber-stamped Tab 3 without checking that Z was actually a
one-hot matrix. The bug had been latent in `drm_build_expanded()`
since v0.1 and affects every drmTMB fit where the grouping
variable is stored as numeric in `fit$data`.

**Fix.** One-line change in `R/symbolize-drmtmb.R`: convert
`g_var` to factor before `model.matrix` so the one-hot matrix is
emitted correctly. The companion `u` vector is then re-ordered by
factor levels so `Z_g %*% u` gives the correct per-observation
random-effect contribution.

**Regression coverage** added in
`tests/testthat/test-symbolize-drmtmb-Zg-numeric-group.R`:
- `Z_g` is `n x k` with row-sums all 1 and values in {0, 1} for
  numeric group_var
- `Z_g %*% u` equals the per-row BLUP indexed by the row's group
- factor input path (previously already correct) still works

Full suite: `FAIL 0 | SKIP 0 | PASS 1861` (+16 from new tests).

# symbolizer 0.22.1.2

## v0.22.1.2 -- Tab 3 marginal-covariance decomposition

Closes V2 Pat-lens flow break #2 on
`symbolizer-meta-analysis.Rmd` §4: Tab 3 of the widget now
*shows* the marginal-covariance decomposition rather than just
announcing it in prose.

### What changed

New helper `latex_marginal_cov_block(x)` in
`R/render-three-views.R` emits a LaTeX `Cov(y) = ...` block
of the form

$$\underbrace{\mathrm{Cov}(\mathbf{y})}_{n \times n} = \underbrace{\sigma_g^2\, \mathbf{A}}_{\text{phylogeny tier}} + \underbrace{\sigma_g^2\, \mathbf{Z}_g\,\mathbf{Z}_g^{\!\top}}_{\text{study tier}} + \underbrace{\mathrm{diag}(\mathbf{v})}_{\text{known sampling}}$$

with one underbrace-labeled term per random-effect tier (structured
tiers carry $\mathbf{A}$; unstructured tiers use $\mathbf{Z}_g\mathbf{Z}_g^\top$)
plus a `diag(v)` term when `meta_V()` is detected. The helper
returns `NULL` for trivial cases (single iid RE without `meta_V`)
so simple fits aren't cluttered.

Wired into `as_html_three_views.symbolized_model` Tab 3. Mutually
exclusive with the existing gllvm $\boldsymbol{\Sigma}_B$ /
$\boldsymbol{\Sigma}_W$ stacked block — gllvm fits never carry
`meta_analysis` in `detected_signals` and never expose
`metadata$structured_matrix_for_group`, so the new block fires
only on meta-analysis / multilevel widgets.

`symbolize.drmTMB()` now also exposes
`metadata$structured_matrix_for_group` (a named list mapping
each detected structured group to its LaTeX matrix symbol, e.g.
`list(phylogeny = "\\mathbf{A}")`) so the renderer can match
structured tiers to their group_vars.

### Tests

Two new tests in `test-symbolize-drmtmb-meta-multilevel.R`:
one assertion on a meta-multilevel fit (block contains the three
tier symbols + the `Cov(y)` LHS), and one assertion that
single-RE non-meta fits return `NULL`. Suite at
`FAIL 0 | SKIP 0 | PASS 1847`.

# symbolizer 0.22.1.1

## v0.22.1.1 -- phylo tier propagated into widget equations

Closes the V2 Pat-lens blocker on `symbolizer-meta-analysis.Rmd`
§4: the article's central thesis equation -- the phylogenetic
random effect $\mathbf{u}_p \sim \mathcal{N}(\mathbf{0},\,
\sigma_p^2\,\mathbf{A})$ -- now appears in the rendered widget
across all three tabs.

### What changed

`symbolize.drmTMB()` now synthesises a random-effect row for each
`phylo()` / `animal()` marker in the formula so the equation
renderer, `variance_components`, symbol dictionary, and assumption
gate all see the structured tier. Previously the tier was detected
in `metadata$phylo_representation` and `metadata$structured_matrices`
but never reached `$random_effects` (because drmTMB consumes
`phylo()` into its internal sparse-precision pipeline rather than
`fit$random_effects`).

`drm_build_components()` now receives `structured_matrix_for_group`
and emits $\mathbf{u}_g \sim \mathcal{N}(\mathbf{0},\, \sigma_g^2\,
\mathbf{A}_{k \times k})$ (matrix form) and $\mathbf{u}_g \sim
\mathcal{N}(\mathbf{0},\, \sigma_g^2\, \mathbf{A})$ (index form)
for any structured tier, instead of falling through to
$\mathbf{I}_n$.

The linear-predictor matrix form disambiguates multiple
intercept-only RE groups: single-RE fits keep the historic bare
$\mathbf{u}$, multi-RE fits emit $\mathbf{u}_{g_1} + \mathbf{u}_{g_2}$
so the multilevel structure is visible.

`sym$metadata$structured_matrices` is now populated when drmTMB
detects `phylo()` / `animal()` / `spatial()`, exposing the matrix
symbol, role tag, and dimensions for downstream consumers.

### Tests

`test-symbolize-drmtmb-meta-multilevel.R` gains two un-skipped
tests covering the variance_components phylo tier and the matrix-
form equation row $\mathbf{u}_{\text{phylogeny}} \sim
\mathcal{N}(\mathbf{0},\, \sigma_{\text{phylogeny}}^2\,
\mathbf{A}_{35 \times 35})$, plus a new test for
`metadata$structured_matrices`. Suite at FAIL 0 | SKIP 0 | PASS 1845.

### Vignette

`vignettes/symbolizer-meta-analysis.Rmd` §4.3 drops the
"Known limitation (v0.22.1)" caveat (the cause is fixed) and
documents the synthesis path.

# symbolizer 0.22.1

## v0.22.1 -- meta-analysis Widget 2 (phylogenetic multilevel)

Second slice of the v0.22 meta-analysis article (design anchored on
Nakagawa et al. 2025 *Global Change Biology* e70204 "Bonus 2"). Adds
§4 of `vignettes/symbolizer-meta-analysis.Rmd` -- phylogenetic
multilevel meta-analysis with three Faces:

- **Face 1 (deep)**: `drmTMB::drmTMB(drm_formula(es ~ x + meta_V(V = vi) + phylo(1 | species, tree = ...) + (1 | study), sigma ~ 1))` -- the GCB-aligned native idiom that replaces brms `se(sqrt(vi))` and `gr(., cov = A)`.
- **Face 2 (light)**: `brms::brm(bf(es | se(sqrt(vi)) ~ ... + (1 | gr(species, cov = mat))))` -- the GCB paper's reference syntax.
- **Face 3 (light)**: `metafor::rma.mv(yi, V = vi, random = list(~1|phylogeny, ~1|study), R = list(phylogeny = A))`.

Widget 2 (id = `sym-phylomultilevel-...`) renders the per-tier
$\boldsymbol{\Sigma}$ decomposition in Tab 3, mirroring the
v0.21.6-redo gllvm Σ-block layout. The article switches data from
the §3 BCG fixture to a 35-species / 164-effect subset of the
Pottier et al. (2022) thermal acclimation data shipped at
`inst/extdata/thermal_subset.csv`.

### Extractor additions

- `symbolize.drmTMB()` detects `meta_V()` inside the formula and
  tags `metadata$context = "meta_analysis"`. Two production-code
  fixes (`drm_strip_re_terms` + `drm_entry_rhs_formula`) ensure
  drm-formula parsing handles `meta_V()` and `phylo()` markers
  cleanly.
- `symbolize.brms()` detects `se(...)` on the response and tags
  `metadata$context = "meta_analysis"`.

### Data

- `inst/extdata/thermal_subset.csv` (164 effects, 35 species, 39
  studies; seed = `20260528L`).
- `inst/extdata/thermal_subset_tree.tre` (ultrametric phylogeny
  matching the subset).
- `data-raw/make-thermal-subset.R` (reproducible build script).

### Tests

- `tests/testthat/test-symbolize-drmtmb-meta-multilevel.R` (5
  passing + 1 documented skip).
- `tests/testthat/test-symbolize-brms-meta.R` (3 passing).
- `tests/testthat/helper-meta-fits.R` adds three fixtures:
  `fit_drmtmb_phylo_multilevel()`, `fit_brms_phylo_meta()`,
  `fit_metafor_phylo_meta()`.

### Capabilities + assumptions

- 4 new rows in `inst/extdata/capabilities.csv`: drmTMB / brms /
  metafor × meta-analytic + phylo-multilevel.
- 7 new rows in `inst/extdata/assumption-templates.csv` for
  `family = gaussian` with `requires = meta_analysis`: the
  meta-analytic likelihood ($y_k \mid \theta_k \sim
  \mathrm{Normal}(\theta_k,\, v_k)$), the known-sampling-variance
  caveat ($v_k$ is an input, not a parameter), the moderator
  + random-effect linear predictor for $\theta_k$, conditional
  independence, and three reader-responsibilities (no publication
  bias, correct effect metric, no missing-at-random). Rows fire
  only when `symbolize.drmTMB()` or `symbolize.brms()` reports
  `detected_signals` including `"meta_analysis"`.

### Out of scope (deferred)

- §5 location-scale Widget 3 (v0.22.2).
- PDF widgets via `as_pdf_three_views()` (v0.22.3).
- Updating §2/§3 to use the thermal dataset (currently still BCG;
  the §4 transition paragraph documents the switch).
- MCMCglmm `mev = vi` bridge (lands later if scope allows).

# symbolizer 0.21.6-redo

## v0.21.6-redo -- gllvm two-tier widget: syndromes + integrated plasticity

A pedagogical rewrite of `symbolizer-gllvm.html` around the
Nakagawa et al. (in prep) framework: behavioural syndromes
($\boldsymbol{\Sigma}_B = \boldsymbol{\Lambda}_B \boldsymbol{\Lambda}_B^\top + \boldsymbol{\Psi}_B$)
plus integrated plasticity
($\boldsymbol{\Sigma}_W = \boldsymbol{\Lambda}_W \boldsymbol{\Lambda}_W^\top + \boldsymbol{\Psi}_W$).
The previous v0.21.5-redo two-widget split (between-only without Psi_B
vs with Psi_B) was a toy and is removed; the new widgets build up
across **tiers** instead.

### Article structure (11 sections)

- §1 Biological question -- now names both syndromes (between-individual)
  and integrated plasticity (within-individual) up front.
- §2 Data -- 40 individuals × 3 sessions × 5 traits with simulated truth
  carrying both Lambda_B (5×2) and Lambda_W (5×1).
- §3 NEW -- univariate motivation via `lme4::lmer`; classical
  repeatability $R = \sigma^2_u / (\sigma^2_u + \sigma^2_e)$ (Nakagawa
  & Schielzeth 2010).
- §4 NEW -- factor-analytic motivation: $T(T+1)/2$ vs $T(d+1) -
  d(d-1)/2$ parameter counting.
- §5 The model in symbols -- long form / wide form, both tiers explicit.
- §6 **Widget 1** -- behavioural syndromes ($\Sigma_B$ only).
- §7 **Widget 2** -- adds integrated plasticity ($\Sigma_W$). Documents
  gllvmTMB's $\sigma_\varepsilon$ auto-suppression when
  `unique(0 + trait | obs)` is present.
- §8 Reading biologically -- $c^2$ + $\psi^*$ per tier, $R_t$
  per-trait, phenotypic-correlation decomposition
  $r_P = r_B\sqrt{R_t R_m} + r_W\sqrt{(1-R_t)(1-R_m)}$ (Dingemanse &
  Dochtermann 2013).
- §9 Identifiability -- rotation, sign, AND $\sigma_\varepsilon$
  auto-suppression as expected behaviour.
- §10 NEW -- the `glmmTMB` bridge: `latent()`/`unique()` ↔ `rr()`/`diag()`
  syntax equivalence so readers from the Nakagawa et al. paper see the
  same math.
- §11 Capability list -- updated to reflect v0.21.6-redo.

### Extractor extensions (`symbolize.gllvmTMB`)

`$expanded` now carries the two-tier widget contract:

- `Lambda_W` ($n_\text{traits} \times d_W$) -- within-individual
  reduced-rank loadings.
- `Z_W` ($n_\text{obs} \times d_W$) -- per-observation latent scores
  (expanded from gllvmTMB's `unit_obs`-level via `site_species_id`).
- `Psi_W` (length $n_\text{traits}$) -- per-trait within-individual
  uniqueness SDs.
- `Sigma_W` ($n_\text{traits} \times n_\text{traits}$) -- algebraic
  closure $\Lambda_W \Lambda_W^\top + \mathrm{diag}(\Psi_W^2)$.
- `Repeatability` (length $n_\text{traits}$) -- per-trait
  $R_t = (\Sigma_B)_{tt} / [(\Sigma_B)_{tt} + (\Sigma_W)_{tt}]$.

Sigma_B now prefers the algebraic closure $\Lambda_B \Lambda_B^\top +
\mathrm{diag}(\Psi_B^2)$ over `fit$report$Sigma_B` (which only
contains $\Lambda_B \Lambda_B^\top$ -- the Psi_B diagonal was being
dropped under the prior behaviour).

### Renderer extension (`as_html_three_views` Tab 3)

A new `latex_implied_cov_block(tier, Sigma, Lambda, Psi)` emitter
conditionally appends an implied-covariance block per tier when the
relevant slots are populated. Widget 1 (between-only) shows the
$\Sigma_B$ block; Widget 2 (two-tier) shows both $\Sigma_B$ and
$\Sigma_W$ blocks plus a per-trait $R_t$ row. Non-gllvm fits are
unaffected (the emitter returns NULL when the slots are absent).

### Tests (TDD-first)

- `tests/testthat/test-symbolize-gllvmtmb-two-tier.R` -- 36
  assertions covering the two-tier extractor contract, closure
  equalities to $10^{-6}$, repeatability formula, between-only
  graceful NULL.
- `tests/testthat/test-render-implied-cov.R` -- 11 assertions on the
  emitter's tier / NULL-safety / labels.
- `tests/testthat/test-three-views-implied-cov.R` -- 10 assertions on
  Tab 3 integration; ensures non-gllvm fits stay unaffected.

# symbolizer 0.21.4-redo

## v0.21.4-redo -- structural-dependence rescope + 3-Face article + consistency sweep

A rescope of the `symbolizer-structural-dependence` article from 6
half-working Faces to one deep-dive + two light Faces, plus a
12-class consistency sweep across the widget renderer, the §6 model
statement, the CSV templates, and the cross-package extractors.

### Three Faces, one phylogenetic LMM

- **Face 1 (deep-dive)**: `MCMCglmm` with `ginverse = list(species = Ainv)`
  -- full three-views widget.
- **Face 2 (light)**: `brms` with `gr(species, cov = A)` -- fitted Stan
  model with `symbolize()` outputs (no widget).
- **Face 3 (light)**: `phylolm::phylolm()` with Pagel's lambda -- the
  marginalised PGLS form (no widget), with an explicit bridge to
  Face 1's RE form.

Dropped from this article (moved elsewhere): metafor (meta-analytic
scope → v0.22), glmmTMB (propto two-scalar → defer), drmTMB
location-scale phylo (→ v0.24), gllvmTMB community-phylo (→ separate
arc). The §6 model statement now distinguishes the **estimated**
$\sigma_e^2$ from the **known** sampling variance $v_i$ (Cinar et
al. 2022, *Methods in Ecology and Evolution*).

### New: `symbolize.phylolm()` extractor

PGLS marginal form support. BM and Pagel's lambda evolutionary
models. New capability rows; `metadata$phylo_representation =
"pgls_marginal"`; `metadata$phylo_model` + `metadata$phylo_param`.
End-to-end on the Moura data: $\hat\lambda = 0.7632$.

### B6 fix (Ayumi report)

`drmTMB::phylo()` formulas no longer crash `symbolize()`. The
`drm_strip_markers()` formula walker replaces `phylo()` / `animal()` /
`spatial()` / `gp()` markers with `call("(", arg1)` so lme4-style RE
notation survives `stats::terms()`. Real regression-test fixture
based on Ayumi's failing example.

### drm_strip_re_terms parse-tree refactor

Previously rejected RE bars containing inner parens, so
`(1 | gr(species, cov = A))` crashed `model.frame()` with "could not
find function 'gr'". New implementation walks the parse tree;
handles arbitrary nesting. 7 unit tests pin the contract.

### Three-views widget

- **User-configurable truncation**: `as_html_three_views()` and
  `as_pdf_three_views()` now accept `head` / `tail` (rows) and
  `head_cols` / `tail_cols` (columns); defaults match prior
  behaviour. 7 tests.
- **Z elision when one obs per level**: when `n_obs == n_distinct_levels`,
  the Tab 3 stacked block drops the random-effect incidence matrix Z
  (which is then the identity on the observed levels and renders as
  a wall of zeros) and emits the per-observation random effect
  $\hat{\mathbf{u}}_{n\times 1}$ directly. Z is retained for
  multi-obs-per-level cases (repeated measures, multi-effect-size
  meta-analyses).
- **All-nodes dim propagation**: when MCMCglmm's `ginverse` carries
  the Hadfield-Nakagawa all-nodes representation, the symbol
  dictionary + matrix-form equation now report the augmented
  dimension (e.g. $\mathbf{A}_{116 \times 116}$ for a 60-tip tree),
  matching what the Tab 3 stacked block shows.

### Consistency sweep (12 classes)

Rose-style consistency scan triggered by the maintainer's dim
inconsistency catch. Findings + fixes filed at
`docs/dev-log/figure-audits/v0.21-redo-rescope/rose-consistency-scan.md`
along with V1 Florence, V2 Pat, V3 Noether audit reports. Highlights:

- **assumption_table comma**: the gaussian / student / lognormal /
  Gamma / Beta `conditional_distribution` rows previously emitted
  `\mathrm{Normal}(\mu_i\, \sigma_i^2)` (LaTeX thin space, no comma),
  which renders as the product `μ σ²` instead of the parameter list
  `(μ, σ²)`. All 5 rows now use the comma form. **Bug fix**.
- **`your_responsibility` status**: 14 CSV rows used the underscore
  spelling, which `friendly_status()` did not map. Now mapped to
  the displayed string "your responsibility".
- **Tables now scroll**: `sym_kable_responsive()` wraps wide
  `assumption_table()` / interpretation outputs in a
  `<div class="table-responsive">` so the right-edge status column
  scrolls instead of clipping.
- **`σ_p` naming canonical**: §6 model, §Animal-model unification,
  and the heritability output now all use $\sigma_p^2$ /
  $\sigma_e^2$; the quantitative-genetics A/E alias is noted once.
- **Hidden scaffolding**: the `pdf_alongside_html()` helper chunk
  + the `shim_mcmcglmm()` chunk are now `echo = FALSE`; they no
  longer leak into the article.
- **§ typography**: 5 occurrences of `§"..."` glued together;
  now `§ "..."` with proper space.
- **brms convergence warnings suppressed**: `iter` bumped from 1000
  to 2000 with `adapt_delta = 0.95`; `warning = FALSE` on the chunk.

### Multi-V audit reports (committed)

- `V1-florence-report.md` (visual)
- `V2-pat-report.md` (reader flow)
- `V3-noether-report.md` (math correctness)
- `rose-consistency-scan.md` (cross-class consistency)

### Test results

`1795 pass / 0 fail / 1 pre-existing error (Matrix::expand masking #7) /
97 pre-existing warnings (sdmTMB NaN)`. R CMD check: 0 errors / 0
warnings / 1 NOTE (`.git` in-source). `pkgdown::build_site()` clean.

### DESCRIPTION

Added `phylolm` and `Matrix` to Suggests.

# symbolizer 0.21.3

## v0.21.3 -- three-views widget rollout to symbolizer-families.Rmd

Continuation of the v0.21.2 widget-rollout arc. Three representative
family chunks in `vignettes/symbolizer-families.Rmd` now carry
interactive three-views widgets + PDF download links.

### Widget chunks added

- **Poisson** (count, log link) — `exp(beta)` is the rate ratio.
- **Beta** (proportion, logit link) — `exp(beta)` is the odds ratio.
- **Lognormal** (positive continuous, log link) — `exp(beta)` is
  the multiplicative effect on the geometric mean.

The Tab-3 matrix-with-data view falls out naturally because
`drmTMB` already populates `sym$expanded` with the right shape.
No shim is needed.

### Vignette helper

`pdf_alongside_html()` -- the chunk-scoped helper introduced in
v0.21.2 -- is reused (defined inline) in the `families` vignette.
The helper writes the PDF to the chunk cwd and copies into
`../docs/articles` when that path exists (pkgdown build), so the
`<a href>` link resolves under both `rmarkdown::render()` and
`pkgdown::build_article()`.

### GLLVM widget deferred to v0.21.4

A v1 GLLVM widget was prototyped (Σ_B as a single 5×5 block) but
dropped before release. The Nakagawa et al. behavioural-syndromes
manuscript surfaces the GLLVM as a **trio** of matrices per level
(Λ_B, S_B, Σ_B = Λ_B Λ_B^T + S_B) plus integration indices
(repeatability R_t, between-communality c²_B,t, within-communality
c²_W,t, uniqueness ψ_t). Building only Σ_B would have shipped an
incomplete and immediately-replaced view. The full
Nakagawa-faithful GLLVM panel — including both Σ_B and Σ_W where
available, plus the per-trait indices — is scoped into v0.21.4
with its own design doc at
`.memory/designs/v0.21.4-gllvm-widget.md`.

### Honest scope notes

- The widget rollout to `symbolizer-meta.Rmd` is deferred to
  v0.22 (that vignette archives during the meta-analysis flagship).

# symbolizer 0.21.2

## v0.21.2 -- structural-dependence article: realistic phylo demo + widget + PDF rollout

Targeted patch release. The v0.21 flagship article
(`symbolizer-structural-dependence.Rmd`) has shipped with zero
three-views widgets and a degenerate `rcoal(15)` simulation as its
phylogeny demo. The Mizuno-style tutorial convention (Mizuno et al.
2026 *RSM*) uses a real comparative-biology dataset for the worked
examples; the article now matches.

### Article: real Mizuno-style data

- Replaces the 15-tip coalescent simulation with a 60-species subsample
  of `metadat::dat.moura2021` (Moura et al. 2021 assortative-mating
  size-size correlations).
- Effect sizes computed from `(ri, ni)` via
  `metafor::escalc(measure = "ZCOR")` (Fisher-z transform), then
  aggregated to one mean Zr per species with
  variance-of-the-mean. Yields realistic Zr values (median 0.25, range
  [-0.14, 1.59]) instead of toy simulated values.
- `A` matrix off-diagonal quantiles are 25% = 0.00, 50% = 0.03,
  75% = 0.27, 99% = 0.86 — a real mix of close + distant phylogenetic
  relatedness, unlike the previous degenerate
  `rcoal(15)` where 75% of off-diagonal entries were above 0.91.
- `A_tips` reordered to match the random sp_keep order so the head 5x5
  in the widget visibly shows a MIX of pairwise relatedness rather
  than a clade of closely-related species.

### Widget + PDF embed below the metafor and MCMCglmm fits

- Both faces (metafor and MCMCglmm) now have a three-views interactive
  widget directly below the fit chunk, showing the same model in
  index / matrix / matrix-with-data forms. Tab 3 carries the actual
  `A_{60x60}` correlation matrix with real numerical entries.
- A "Download as PDF" affordance below each widget renders a paper-
  ready PDF via `as_pdf_three_views()` and links to it.

### Bugs fixed during the Florence pass on the widget render

- `pdf_three_views_worked_row()` no longer crashes on intercept-only
  models. The `for (k in seq.int(2L, length(terms_tex)))` loop ran with
  `length(terms_tex) == 1L`, producing `seq.int(2L, 1L) == c(2L, 1L)`
  and a subscript-out-of-bounds error. Replaced with
  `paste(terms_tex, collapse = " + ")` which is safe for any length.
- `as_pdf_three_views(file = "<relative path>")` now writes to the
  caller's working directory, not the system tempdir.
  `normalizePath(<relative>, mustWork = FALSE)` on macOS returns the
  relative string unchanged when the file doesn't exist;
  `rmarkdown::render()` then interpreted the output_file relative to
  the input Rmd in tempdir, silently writing the PDF to tempdir.
  Patched to expand relative paths against `getwd()` first.
- `pdf_three_views_worked_row()` now includes the random-effect
  contribution on the rendered equation, matching
  `three_views_worked_row()` (the HTML version). Without this, the
  worked-row arithmetic `y_1 = X*beta + eps` doesn't close for models
  with random effects — the residual silently absorbed the BLUP and
  the displayed sum was mathematically wrong.
- `symbolize.rma.mv()` now passes `structured_matrix_for_group` to
  `drm_build_components()`. Previously the rma.mv phylo detection ran
  AFTER components were built, so the distribution line was being
  rendered as `u ~ N(0, sigma^2 I_n)` instead of
  `u ~ N(0, sigma_p^2 A)`. The metafor face of the widget surfaced
  the wrong distribution; the PDF carried it too.

### Vignette helper for PDF placement

The vignette defines a local `pdf_alongside_html()` shim that writes
the PDF in the chunk cwd and, if `../docs/articles` exists (pkgdown
build path), copies a second copy there so the `<a href>` link
resolves whether the article is built via `rmarkdown::render()` or
`pkgdown::build_article()`. `knitr::opts_knit$get("output.dir")`
returns the Rmd source dir (not the HTML destination), so we cannot
target the destination from inside the chunk in a portable way.

### Honest scope notes

- The `$expanded` shim for the metafor and MCMCglmm widgets is
  scaffolding until issue #9 lands the extractor-side `expanded`
  populator. The shim is documented inline in the vignette.
- The widget rollout to `symbolizer-gllvm.Rmd` and
  `symbolizer-families.Rmd` is a follow-up release.
  `symbolizer-meta.Rmd` will archive during v0.22.

# symbolizer 0.21.1

## v0.21.1 -- three-views widget patches + Florence + Rose + Darwin discipline protocols adopted

Targeted patch release after a Florence-style audit of the three-views
HTML widget. The maintainer opened a rendered widget and surfaced six
bugs in one look; the Rose rule ("one bug means ten more in the
pattern") expanded the audit to all symbol-dictionary surfaces. This
release closes the visible bugs AND adopts process protocols from the
drmTMB / gllvmTMB sister repos so the underlying failure mode cannot
recur.

### Three-views widget fixes

- **Standalone HTML now self-renders math.** `as_html_three_views()`
  gained `standalone = FALSE` (default) and `file = NULL` arguments.
  Passing `standalone = TRUE` wraps the fragment in a full HTML
  document with a MathJax 3 CDN bootstrap, so the resulting file
  renders LaTeX when opened directly via `file://...` rather than
  needing a host pkgdown / Rmd page. Without `standalone = TRUE`,
  writing the fragment to file emits a `cli::cli_warn()` so users
  know what they got.
- **Captions switched from `\(...\)` to `$...$`.** Standalone MathJax
  recognises only `$...$` by default; the widget's captions previously
  used the pkgdown-convention `\(...\)`, which rendered as raw text
  in standalone mode. Captions also now interpolate the actual response
  symbol (e.g., `$\mathbf{log\_mass}$`) instead of hardcoding `\mathbf{w}`.
- **Worked-row scalar response derived from the response symbol.**
  Previously hardcoded as `W_{1}` regardless of the actual response
  column. Now derives from `resp_sym`: `\mathbf{y}` -> `y_{1}`;
  `\mathbf{body\_mass}` -> `\mathrm{body\_mass}_{1}`;
  `\mathrm{log\_mass}_i` -> `\mathrm{log\_mass}_{1}`.
- **Phylo-aware biology gloss.** When `metadata$phylo_representation`
  is set, the biology caption above the equation block now reads
  "Species are not independent observations. Closely related species
  tend to have similar trait values because of shared evolutionary
  history; the phylogenetic correlation matrix $\mathbf{A}$ encodes
  those expected similarities..." -- replacing the default Gaussian
  "Each observation is normally distributed..." gloss which was
  conceptually wrong for comparative phylogenetic models. Same
  for `metadata$spatial_representation`.
- **Structured matrix surfaced on tab 3.** When `expanded$M` carries
  a numerical correlation matrix, the "Equations with data" tab
  renders a new equation block showing `Cov(u) = sigma_p^2 * A` with
  the A matrix as a bmatrix of actual numbers (truncated head + tail
  for large matrices).
- **PDF export.** New `as_pdf_three_views(sym, file = "out.pdf")`
  exports the same three views as a single-page PDF with three stacked
  sections (Index form / Matrix form / Worked observation at i = 1).
  Internally renders an Rmd stub via `rmarkdown::render()` with
  `pdf_document`; requires a working LaTeX install (TinyTeX or system).
- **Gloss dimensions wrapped in `$...$`.** Inline `\mathbb{R}^{...}`
  expressions inside mixed prose ("scalar; $\mathbb{R}^{15}$ in matrix
  form") now wrap correctly.

### Phylogenetic / structural-covariance distribution line

The matrix-form distribution line for random effects now reads
`\mathbf{u}_{g} \sim \mathcal{N}(\mathbf{0}, \sigma_{g}^2\, \mathbf{A}_{k \times k})`
when the extractor detects a structured covariance matrix on the
group `g`. Previously rendered `\mathbf{I}_{k}` even for phylogenetic
fits -- the v0.20.0 audit's "A is missing from the formula" complaint
was correct.

`drm_build_components()` gained a `structured_matrix_for_group`
argument: a named list mapping group name to LaTeX matrix symbol
(e.g., `list(species = "\\mathbf{A}")`). Default `NULL` preserves
the v0.20 `\mathbf{I}_n` behaviour for non-structured fits. The
MCMCglmm extractor now passes this list whenever `animal_groups` is
non-empty. The remaining extractors (drmTMB, glmmTMB, brms, metafor,
gllvmTMB, sdmTMB, mgcv) will adopt the same pattern in a follow-up.

### Symbol-dictionary completeness

`drm_build_symbol_dictionary()` now adds a `residual_sd` row for
every Gaussian-style family (`gaussian`, `lognormal`, `student`,
`Gamma`, `beta`, `nbinom2`, `beta_binomial`, `truncated_nbinom2`,
`meta_normal`) when no sigma submodel is already present. Previously
extractors that did not promote sigma to its own submodel (lm, lmer,
MCMCglmm, brms Gaussian, glmmTMB Gaussian, metafor) silently omitted
the residual SD from the symbol gloss list even though the equation
block contained `\sigma_i`. Rose-style audit found this affected 6
of 7 extractors tested.

### MCMCglmm response-symbol resolver

`mcmcglmm_resolve_response_symbol()` now escapes underscores and
wraps multi-character column names in `\mathrm{...}`, matching the
drmTMB convention. Previously a `log_mass` column produced raw
`log_mass` LaTeX which MathJax parsed as `log` with `m`, `a`, `s`, `s`
as nested subscripts.

### Florence + Rose + Darwin protocols (from drmTMB + gllvmTMB)

`CLAUDE.md` gained a top-level "Top discipline rule" section plus an
"Adopted protocols (from drmTMB + gllvmTMB sister repos)" section
documenting: (a) Florence visual-check is mandatory before any
user-facing rendered surface ships; (b) Rose rule -- one bug means
ten more in the pattern, scan before patching; (c) Darwin rule --
demos with data must be biologically coherent (comparative analyses
use log-transformed traits clustering -2 to 2, not raw within-species
ranges); (d) default Claude mode is read-only audits, not "ship and
iterate"; (e) eight-condition Definition of Done including Florence
check + after-task report; (f) widget-visual-audit checklist for
every render.

`.github/VISION.md` adds Florence as a named team role (scientific
figure / widget / vignette visualization reviewer) and a new "Accuracy
over speed" section.

`.memory/MEMORY.md` documents the specific bug patterns from this
audit; `.memory/check-log.md` is a new running log adopted from
drmTMB; `.memory/reports/2026-05-26-discipline-protocols-adopted.md`
is the after-task report covering both v0.21.0 and v0.21.1 work.

### Tests

`rcmdcheck`: 0 errors / 0 warnings / 0 notes. Pre-existing
`Matrix::expand` masking failure under `devtools::test()` only (does
not occur under `R CMD check`); see issue #7.

### Deferred to a follow-up

- The structured-matrix-for-group plumbing currently only flows
  through MCMCglmm. drmTMB / glmmTMB / brms / metafor / gllvmTMB
  extractors still call `drm_build_components()` without it -- their
  fits will continue to show `\mathbf{I}_n` in the matrix-form
  distribution line. Trivial to extend per-extractor; not in this
  release because the MCMCglmm path is the primary demo target.
- The three-views widget still needs to be embedded in the
  structural-dependence vignette and others (issue #9). Now safe to
  do incrementally because the rendering bugs are closed.
- LaTeX-copy buttons on the widget (issue #8) remain unbuilt; the
  standalone HTML + PDF parts of #8 are now done.

# symbolizer 0.21.0

## v0.21.0 -- Structural dependence: phylogenetic, animal-model, and spatial random effects (6 packages)

First article in the v0.21-v0.24 concept-axis series. v0.21 ships the
**dependence-structure axis**: one ~3500-word vignette teaching the
shared `b ~ N(0, sigma^2 M)` grammar, with `M = A` (phylogenetic /
animal-model) and `M = Omega` (spatial), instantiated across all six
backends symbolizer touches.

### New vignette

`vignettes/symbolizer-structural-dependence.Rmd` -- the deliverable.
Six-package walkthrough on the same simulated phylogenetic dataset:
metafor (`R = list(species = A)`), MCMCglmm (`ginverse =
list(species = Ainv)`), glmmTMB (`propto(0 + species | g, A)`),
brms (`gr(species, cov = A)`), drmTMB (`phylo(1 | species, tree)`),
gllvmTMB (`phylo_unique(...)`). Plus animal-model unification, tips-
vs-all-nodes equivalence, spatial sidebar (sdmTMB + mgcv), the
phylo-vs-non-phylo identifiability warning. Anchored on Williams et
al. 2025 bioRxiv (glmmTMB propto PGLMM), Hadfield & Nakagawa 2010
(all-nodes representation), Mizuno et al. 2026 (spatial half).

### Symbol convention: context-aware M / A / Omega

Symbol_dictionary now carries a `role` value `structured_correlation_phylo`
(renders as `A`) or `structured_correlation_spatial` (renders as
`Omega`). Cross-package teaching prose uses `M` as the abstract form
with the alias note "M = A in phylo, M = Omega in spatial". Omega's
dictionary description explicitly disambiguates from Wishart
precision matrices and CAR / SAR spatial-weights matrices.

### Detection across 6 backends

Every backend now populates `metadata$phylo_representation` (one of
`tips_only` / `all_nodes` / `package_managed`) and
`metadata$detected_signals` (used by the gating mechanism, below):

| Package | Detection path | phylo_representation |
|---|---|---|
| MCMCglmm | `fit$ginverse` non-empty | `all_nodes` |
| glmmTMB | propto block (blockCode 11) | `tips_only` |
| metafor | R = list(<group> = M) with phylo-lexicon name | `tips_only` |
| brms | `fit$ranef$cov` non-empty | `tips_only` |
| drmTMB | `phylo()` / `animal()` markers in formula | `all_nodes` (HN sparse precision) |
| gllvmTMB | covstruct kinds `phylo_*` | `package_managed` |

### Requires-column gating mechanism

`inst/extdata/assumption-templates.csv` and
`inst/extdata/interpretation-templates.csv` gained a `requires`
column. Rows whose `requires` is in
`c("phylo", "spatial", "animal", "temporal", "meta_analysis")` fire
only when the extractor declares a matching signal in
`metadata$detected_signals`. Empty / NA / unknown values fire
unconditionally (back-compat for the existing rows).

Both `drm_build_assumptions()` and `drm_build_interpretation()`
gained a `detected_signals = character(0L)` argument and the filter
logic. `glm_build_*` parallels in `R/symbolize-gllvmtmb.R` likewise.

### Capability registry: 6 phylo paths promoted to First slice

- `gllvmTMB,*,phylo` (was Planned)
- `drmTMB,gaussian,phylo` (was Planned)
- `metafor,*,phylo` (was Planned)
- `brms,*,phylo` (was Planned)
- `MCMCglmm,*,phylo` (new row -- alias for the v0.12 animal-model path)
- `glmmTMB,*,phylo` (new row -- alias for the v0.16 propto path)

### Shared helper

`drm_build_symbol_dictionary()` gained a `structured_matrices = NULL`
argument; extractors pass a list of A / Omega row specs. Per the
AGENTS.md "no new exported helpers" rule, this extends an existing
internal helper rather than adding a new one.

### New CSV rows

- assumption-templates.csv: 14 new phylo rows (meta_normal + gaussian
  + gllvm_gaussian), all gated `requires = phylo`.
- interpretation-templates.csv: 7 new phylo rows (phylo_intercept,
  variance_component, heritability across meta_normal + gaussian +
  gllvm_gaussian), all gated `requires = phylo`.
- warning-templates.csv: 6 new rows (phylo_detected,
  phylo_propto_two_scalars, phylo_nonphylo_unidentifiable,
  phylo_rank_deficiency, phylo_tree_data_mismatch, spatial_detected).

### Forward links

The concept-axis series continues:
- v0.22 (Meta-analysis with known v_i, Mizuno anchor)
- v0.23 (Categorical phylogenetic models -- binary, ordered, unordered)
- v0.24 (Location-scale on M -- PLSMs, Nakagawa et al. 2025 MEE anchor)

### Non-goals (deferred)

- Per-package phylo helper fixtures + cross-package Fisher equivalence
  test (deferred to v0.21.1; the article shows the patterns inline).
- `drm_build_interpretation` enhancement to emit phylo_intercept /
  variance_component / heritability rows from the variance-components
  tibble (rows are in the CSV gated by requires = phylo but the builder
  iterates only over fixed_eff -- to fire they need an extra pass).
- Multi-trait / cross-trait phylogenetic covariance (us(trait):species).
- Pagel's lambda / Blomberg's K parameterisations (Brownian motion only).

# symbolizer 0.20.2

## v0.20.2 -- Pat cleanup + phylogenetic capability scaffold

Pure cleanup release after Pat's R-output-vs-LaTeX audit, plus the
first piece of scaffolding for a unified phylogenetic + spatial
meta-analysis vignette (D+E) targeted for the next release.

### Pat cleanup: vignette output paths now render math via knit_print

1. **Six `cat(as_latex(sym), "\n")` chunks** in
   `vignettes/symbolizer-ladder.Rmd` (rungs 1-4) and
   `vignettes/symbolizer-meta.Rmd` (Face 1 and Face 2) were dumping
   raw LaTeX strings to the page instead of rendered MathJax. Each is
   now `equations(sym, notation = "index")`, which routes through the
   existing `knit_print.symbolizer_equations` method and produces a
   properly delimited `$$...$$` math block. The one `cat(as_latex(...))`
   chunk in `vignettes/symbolizer.Rmd` is left intact -- it is a
   deliberate teaching demonstration of the raw string.

2. **Two new `knit_print` methods**:
   `knit_print.symbolizer_random_effects` and
   `knit_print.symbolizer_variance_components`. The `random_effects`
   tibble carries LaTeX-valued columns (`u_symbol_index`,
   `sigma_symbol`); the bare tibble print was leaking
   `\sigma_{site}`-style strings onto the page. The new methods wrap
   the symbol columns in `$...$` and render the table as a clean
   pipe-Markdown kable so MathJax / KaTeX picks them up. The
   underlying tbl_df / data.frame classes remain in the class chain,
   so all downstream tibble operations are unaffected.

3. **`print()` wrapper dropped** around `parameter_interpretation()`
   in `vignettes/symbolizer-families.Rmd` so the
   `knit_print.symbolizer_interpretation` method runs and the
   biological-reading column renders as math instead of as raw text.

### Phylogenetic capability scaffold (D+E article preview)

The Mizuno, Williams, Lagisz, Senior, Nakagawa tutorial unifies
phylogenetic and spatial meta-analysis: they are the same multilevel
random-effects model, differing only in what "distance" means
(evolutionary time vs geographic distance). The next release will
ship a single article that teaches both via the shared
$p \sim \mathcal N(0, \sigma^2_p \mathbf M)$ structure -- with
$\mathbf M$ being the phylogenetic correlation matrix $\mathbf A$
(phylo) or a kernel-derived spatial matrix (spatial).

As a scaffold, three new `Planned or reserved` rows have been added
to `inst/extdata/capabilities.csv`:

- `drmTMB,gaussian,phylo` -- `drmTMB::phylo(term, tree)` uses
  Hadfield & Nakagawa (2010) A-inverse sparse-precision internally,
  which is the **all-nodes** representation (latent vector spans
  tips + internal nodes).
- `metafor,*,phylo` -- `rma.mv(..., R = list(species = A))` with the
  tips-only k x k phylogenetic correlation matrix; distinct from the
  `V = V` fixed-sampling-covariance pattern that v0.20.0 nailed down.
- `brms,*,phylo` -- `gr(species, cov = A)` with the tips-only A.

Existing rows for `gllvmTMB,*,phylo`, `glmmTMB propto`, and
`MCMCglmm animal` already cover the rest of the phylo surface; the
notes have been left as-is in this release. The extractor work that
will populate `metadata$phylo_representation` (`"tips_only"` /
`"all_nodes"`) is deferred to the D+E release.

### Florence visual-check discipline (continued)

Every widget-touching release must include a visual check of the
live rendered page in a browser, not just `rcmdcheck`. v0.20.2 is
no exception.

# symbolizer 0.20.1

## v0.20.1 -- symbol gloss renders Greek letters / mathbb properly

The "where:" symbol gloss in the three-views widget was emitting
`\(\mu_i\)`-style MathJax inline-math delimiters. Pandoc processes
`<li>` content as markdown by default, and the `tex_math_single_backslash`
extension is OFF by default -- so pandoc was interpreting `\mu`,
`\sigma`, `\beta`, `\mathbb` as escape sequences and **eating them
before MathJax ever saw them**. The published gloss was reading
"`(_i) — conditional mu of body_mass`" where the `\mu` had vanished,
"`({0}, {1}) — mu submodel coefficients`" where `\beta_{0}, \beta_{1}`
collapsed (the `_{0}, _{1}` triggered italic markup, the `\beta`
was eaten), and dimension labels like "`(^{200})`" with `\mathbb{R}`
stripped.

### The fix

Three coordinated changes in `three_views_symbol_gloss()`:

1. **Math delimiters**: switched from `\(...\)` to `$...$`. Pandoc's
   `tex_math_dollars` extension is on by default, so `$\mu_i$` is
   recognised as inline math and the contents are preserved verbatim
   for MathJax to render. Pipeline verified: `\boldsymbol{\mu}`,
   `\boldsymbol{\beta}`, `\mathbb{R}^{200}`, `\mathbb{R}^{n \times p}`
   all survive R -> knitr -> pandoc -> MathJax intact.
2. **Always-wrap for symbol columns**: split the wrapper into two.
   `wrap_always()` wraps any non-empty symbol-column value (symbol
   columns are always LaTeX, even when they don't start with `\` --
   e.g. `W_i`, `T_i`). `wrap_if_latex()` keeps the old "only wrap
   strings starting with `\`" heuristic for `dimension_concrete`,
   which is sometimes math (`\mathbb{R}^{200}`) and sometimes prose
   ("column of X (length 200)"). Without this split, `W_i` and `T_i`
   were rendering as plain ASCII while `\mu_i` and `\sigma_i` rendered
   as italic math -- visually inconsistent within the same gloss.
3. **Line-height fix in `.sym-gloss-list li`**: MathJax-rendered
   subscripts are taller than ASCII text, so the default tight margin
   between list items caused adjacent rows to appear to overlap (the
   "strikethrough" effect a reader sees on the rendered page). Bumped
   to `line-height: 1.7; margin: 0.4rem 0;` so each row has room.

### Process commitment: visual checks before each release

The maintainer pointed out that this bug had been visible on the
live deployed page since v0.19.x and we kept missing it because
`rcmdcheck` says 0/0/0 and prior audits checked the *intent* of the
gloss code rather than the *rendered output*. From v0.20.1 onward:

**Every release that touches the widget must include a visual check
step**: fetch the deployed HTML (`curl` the live URL or render a
local preview), grep for known broken patterns (literal `(_i)`,
`^{200}` outside math delimiters, raw `\mathbf{` strings), and open
the rendered page in a browser before tagging. This complements
`rcmdcheck`; the two answer different questions.

The unfixed deferred items the v0.19.2 NEWS named as "Known
remaining issues" -- the scalar-symbol gloss plain-text leak and
the dimension `^{n}` literal -- were both symptoms of this same root
cause. Naming them in NEWS without fixing them was a process
failure as well as a rendering one.

# symbolizer 0.20.0

## v0.20.0 -- corrective release: propto is the phylogenetic bridge, not the meta-analysis bridge

This release corrects a substantive inferential framing error that had
been woven through the package since v0.16. The maintainer flagged it
directly; three audit agents (Fisher empirical, Rose cross-repo,
Noether math) verified it independently. **No previous audit had been
asked to verify the equivalence claim by fitting both models and
comparing estimates** -- that is the audit-process gap this release
documents.

### What the package used to claim (wrong)

v0.16 introduced detection of `glmmTMB`'s `propto(0 + obs | g, V)`
covariance block and framed it as "the GLMM bridge to metafor":
`vignette("symbolizer-meta")` Face 2 said *"`propto(0 + obs | g, V)`
**fixes** the residual covariance to the known `V`, which is exactly
what `rma.mv(..., V = V)` does in `metafor`. Structurally identical;
syntactically different."* The info-row in `warning_table()` carried
the same claim: *"sigma_residual is fixed (sampling-variance-known)"*.
Every downstream reference to propto in capability rows, the roadmap,
the ladder cross-reference, and NEWS itself inherited that framing.

### What is actually true

`propto(X, V)` parameterises **Σ = σ² · V** with **σ² estimated** as a
free scalar. Combined with glmmTMB's default residual term (which
stays on unless `dispformula = ~ 0` is passed), the full conditional
covariance is `σ²_propto · V + σ²_res · I` -- **two free scalars** on
top of `V`, not zero. That is the **phylogenetic / pedigree /
structured-covariance** pattern, mirroring metafor's `R = list(g = V)`
argument, not its `V = V` argument. The structural twin of
`rma.mv(V = V, …)` would be `equalto(X, V)`, which parameterises Σ = V
exactly (no scalar multiplier). **`equalto` is reserved but not yet
implemented in `glmmTMB` <= 1.1.11** (`.valid_covstruct` exposes codes
0-13; no `equalto` entry). The package had been treating two distinct
covariance models as identical.

### Fisher's empirical verification (k = 30, seed 1)

| quantity | metafor `rma.mv(V = V, ~ 1 | study)` | glmmTMB `(1 | study) + propto(0 + obs | g, V)` |
| --- | --: | --: |
| β̂_0 | 0.357438 | 0.357024 |
| SE(β̂_0) | 0.063038 | 0.064973 |
| τ̂² (study) | 0.068911 | 0.071700 |
| **σ̂² (propto scale)** | **n/a (fixed at 1)** | **0.942742** (estimated; constant across all i with sd ≈ 2e-16) |
| logLik | -10.6426 | -12.3428 |
| n parameters | 2 | 3 |

The decisive number is the 0.942742 propto-scale: propto multiplied
`V` by a single free scalar that converged near, but not at, 1. The
two models share neither parameter count, log-likelihood, nor standard
errors. They are not "structurally identical."

Phase 3 of Fisher's audit verified that on AR(1)-correlation
phylogenetic data, `metafor::rma.mv(V = 0, R = list(sp = C))` and
`glmmTMB(y ~ 1 + propto(0 + obs | g, C))` agree to **five decimals**.
So `propto` IS the right bridge -- just for phylogenetic / pedigree /
known-correlation models, not meta-analysis.

### Fixes in this release

* **`vignettes/symbolizer-meta.Rmd` Face 2 rewritten** as "glmmTMB via
  propto() (phylogenetic / structured-covariance, NOT meta-analysis)".
  The new section names propto's σ² estimation explicitly, points at
  metafor's `R = list(...)` argument as the true counterpart, and
  documents that the meta-analytic identity (Σ = V) is upstream-blocked
  until `glmmTMB` ships `equalto()`.
* **Face 3 (drmTMB-as-meta) caveated**: writing
  `sigma ~ 1 + offset(0.5 * log(vi))` does not pin σ_i² = v_i unless
  the intercept γ_0 is also constrained to 0. The vignette now flags
  this honestly.
* **`R/symbolize-glmmtmb.R` info-row prose rewritten**: σ² is named as
  *estimated*; the σ_res default is named; the metafor counterpart is
  named as `R = list(g = V)` (phylo), not `V = V` (meta-analysis).
* **Metadata flag renamed**: `propto_known_corr_block` is the new name;
  `meta_analysis_via_glmmTMB` stays set as a deprecation alias for
  back-compat through one minor version.
* **`inst/extdata/capabilities.csv:69`** gaussian-propto description
  trimmed: drop "meta-analysis /". Binomial/poisson rows were already
  correctly framed as phylogenetic.
* **`inst/extdata/family-distributions.csv` `meta_normal` row**: the
  matrix-form covariance now renders as `\mathcal{N}(θ, V)` with `V`
  known, not `\mathrm{diag}(v)` (which silently lost off-diagonal
  correlations when V was block-diagonal, as in the meta vignette's
  own simulated data).
* **`vignettes/symbolizer-roadmap.Rmd`** v0.16 row annotated with
  the v0.20 correction. **`vignettes/symbolizer-ladder.Rmd`**
  cross-reference no longer lists `glmmTMB::propto()` alongside metafor
  in the meta-analysis sentence.

### Audit-process lesson

The propto = meta-analysis equivalence was a *quantitative* claim. The
v0.16 audits (Pat readability, Rose stale-wording, GF2 capability
truth, several others) all reviewed the *prose* of the claim against
the *intent*. None were asked to verify the intent itself by fitting
both models and comparing estimates. From v0.20 onward, any
equivalence claim between two packages must be paired with a Fisher
brief that **fits both and reports estimate divergence**, with the
results pinned in a regression test snapshot. The propto/equalto
empirical comparison from Fisher's audit is preserved in
`tests/testthat/test-glmm-propto-not-metafor.R` for this purpose --
if a future version of symbolizer ever claims the two are equivalent
again, that test fails.

# symbolizer 0.19.2

## v0.19.2 -- multi-page widget bug sweep (Rose + Pat)

After v0.19.1 the maintainer reported visible widget breakage on the
deployed pages. A parallel Rose + Pat audit across all four
widget-bearing pages (homepage, ladder, drmtmb, factors) surfaced a
set of patterns; this release fixes them.

### Fixes

* **Homepage widget was emitted inside a `<div class="sourceCode">`
  block with stale v0.18.x tab labels and broken JS** (Rose Pattern A,
  Pat 🔴 Pattern A). `README.md` had been knit against an older
  installed `symbolizer`, so the v0.18.x `<button>` lines (4-space
  indented + un-escaped `\"` in `querySelectorAll`) were baked into
  the committed README. Re-knit `README.Rmd` against an installed
  v0.19.2 build; the homepage now carries the same de-indented buttons
  + raw-R-string JS that the vignettes have been emitting since v0.18.2.
* **Tab 3 horizontal overflow on every vignette with a wide matrix
  equation** (Rose Pattern C, Pat 🔴 Pattern B). `.sym-eq` had no
  `overflow-x` rule; for fits with a random effect, the response
  equation `w = Xβ + Zu + ε̂` is 4-5 bmatrices side by side and ran
  off the panel and the page. Added `overflow-x: auto; max-width:
  100%;` to the rule -- one CSS line; ladder + drmtmb + factors
  Tab 3 panels now scroll horizontally instead of clipping.
* **`\mathbf{body_mass}` rendered as "body_m ass"** (Rose Pattern B,
  Pat 🟡 Pattern D). MathJax was parsing the underscore in the
  variable name as a subscript operator inside `\mathbf{...}`. The
  fault was at one helper site: `drm_response_symbol_matrix()` and
  `drm_resolve_response_symbol()` in `R/symbolize-drmtmb.R` -- both
  now `gsub("_", "\\_", ...)` the variable name before LaTeX
  emission, and the scalar-form fallback wraps multi-character names
  in `\mathrm{...}` so they render upright as a single identifier.
* **Worked row dropped the random-effect term silently, so the
  arithmetic for observation i = 1 did not close** (Pat 🔴 Pattern C).
  A reader checking `30.4 + 0.371 × 14.0 + (-2.4) = 28.4` against
  the printed `μ̂_1 = 30.8` would conclude the package math was
  wrong, when in fact the missing piece was `+ û_site(1)`. The
  worked-row helper now reads `ex$Z_g[1, ] %*% ex$u` to compute the
  RE contribution for observation 1, includes `\hat{u}_{site(L1)}`
  in the symbolic line, and adds the numeric value in the with-numbers
  line. The decomposition `μ̂_1 + ε̂_1 = W_1` now reconciles.
* **Biology gloss claimed sigma shifts with predictors even on
  fits where `sigma ~ 1`** (Pat 🟡 Pattern E). Affects the factors
  vignette (sigma is intercept-only there). The gloss now detects
  `ncol(X_sigma) > 1` and only emits the "spread also modeled"
  sentence when sigma actually varies; constant-sigma fits get the
  simpler sentence.
* **Trailing dots in the bmatrix data** (Pat 🟡 Pattern G). The
  formatter used `formatC(..., format = "fg", flag = "#")` which
  always shows a decimal point, so `129` printed as `129.` and
  `111` as `111.`. Switched to `format = "g"` -- the values that
  need decimals still show them, integers don't carry dangling dots.

### Known remaining issues (deferred to v0.20)

Rose surfaced three more patterns that need a deeper refactor and a
test fixture, deferred:

* Scalar-symbol gloss data-side ships as plain text rather than
  `\(...\)`-wrapped MathJax for some rows (`body_mass_i` shows literally,
  while `\(\mu_i\)` is wrapped).
* `^{n}` literal in the `u_{site}` dim gloss leaks as raw LaTeX
  (`scalar; ^{12} in matrix form`) instead of `\(\mathbb{R}^{12}\)`.
* The user-supplied `symbols = c(body_mass = "W_i")` mapping isn't
  propagated into the gloss prose descriptions ("conditional mu of
  body_mass" still shows the raw variable name).

These ride on the symbol-table builder rather than the renderer and
need a wider edit.

# symbolizer 0.19.1

## v0.19.1 -- balance the worked-row treatment across both submodels

Small follow-up to v0.19.0:

* **Sigma submodel now gets a worked row too.** On Tab 3, observation
  i = 1 is now walked through BOTH submodels in scalar arithmetic,
  not just the mu side. The new sigma block reads
  `log(sigma_hat_1) = gamma_0 + gamma_1 T_1` in symbols, then with
  numbers, then back-transformed to the predicted residual SD in
  original units (`sigma_hat_1 = exp(...) approx 7.04 g` for the
  ladder example). One observation, both submodels, before the matrix
  bmatrices stack each one n times.
* **Tab 3 renamed**: "Matrix with data" -> **"Equations with data"**.
  The label "matrix with data" stopped being accurate in v0.19.0 once
  the tab carried both scalar response equations (the worked row) and
  the matrix-form response equations stacked from them. "Equations
  with data" captures that the tab is now multiple equations -- scalar
  + matrix, mu + sigma -- all populated with the user's numbers.

# symbolizer 0.19.0

## v0.19.0 -- three-views widget v2: pedagogically reordered, live on the homepage, embedded in more vignettes

Today's headline change is in the interactive `as_html_three_views()`
widget. A four-agent design pass (Pat / Noether / Darwin / Boole)
surfaced a series of issues with the v0.18.x widget; the most
important fixes ship now, with the more substantive moves (worked-row
anchor, biology one-liner per tab, narrative bridge captions, print
stylesheet, dark mode) staged for v0.20.

### Pedagogical reorder of the three tabs

The widget now opens on **1. Per-observation (Index)**, then steps to
**2. Matrix form**, then **3. Matrix with your data**. The order
matters: biologists read scalar regression notation fluently from
undergrad coursework but encounter matrix algebra as an abstraction.
The new order is *familiar → abstract → concrete grounding*: each tab
builds on the previous one rather than dropping the reader into bold
letters cold.

### Notation cleanup

* The sigma-submodel design matrix is now rendered as
  $\mathbf{X}_\sigma$ rather than $\mathbf{Z}$. $\mathbf{Z}$ is
  reserved for random-effect design matrices, matching the convention
  in Pinheiro & Bates and the lme4 paper. Noether's audit flagged the
  earlier `Z`-overload as the single biggest notational tell.
* Dimension annotations now use textbook subscript form
  `\mathbf{X}_{n \times p}` rather than the programming-type-annotation
  form `\mathbf{X}\,(n \times p)`.
* The spurious `+ \boldsymbol{\varepsilon}` tail on the
  matrix-with-data equation is removed. It conflicted with the
  conditional-mean form (`\boldsymbol{\mu} = \mathbf{X}\boldsymbol{\beta}`)
  used on the other two tabs.
* Dimension labels under each `\underbrace{...}_{label}` are now
  rendered at `\textstyle` instead of the LaTeX default
  `\scriptstyle`. The labels were genuinely hard to read at half size.

### Symbol-gloss rendering bug fixed

`three_views_symbol_gloss()` wrapped every `dimension_concrete` value
in MathJax `\(...\)` delimiters, but for predictor columns the field
carries prose ("column of X (length 200)"), not LaTeX. The wrap turned
the prose into garbled italic math on the default-open tab. The helper
now MathJax-wraps only strings that begin with `\` (i.e. actually look
like LaTeX); plain prose falls through verbatim.

### Live widgets in more places

The widget is now embedded as a **live, clickable** widget (not a
static screenshot) on:

* the pkgdown **homepage** (`index.html`),
* the **ladder article** (Rung 4),
* `symbolizer-drmtmb.Rmd` (Section 5: Gaussian location-scale with a
  random intercept -- showcases the `Z u` block alongside the
  `X \beta` block in the matrix-with-data tab),
* `symbolizer-factors.Rmd` (Step 3: `sex + body_size` mixed
  factor + continuous predictor -- showcases how the `sexmale` dummy
  column sits next to the continuous `body_size` column in the design
  matrix).

On GitHub these sections render as static markup; on the pkgdown
homepage and articles the tabs are interactive. The same widget also
underlies the bigger v0.20 work to come.

### Other small fixes folded in

* Homepage README: `vignette("symbolizer-ladder")` mentions trimmed
  from three to two; the second mention is now a soft cross-reference
  to the article's *Three views of the same fit* section.
* CI actions bumped to Node-24-compatible versions:
  `actions/checkout@v4` -> `@v6`,
  `JamesIves/github-pages-deploy-action@v4.5.0` -> `@v4.8.0`.

### Audit findings deferred to v0.20

Fisher's inference/interval audit and Emmy's S3/field-contract audit
surfaced a real set of substantive issues:

* `simulate_recipe()` double-draws the random effect for
  meta-analysis fits and references several undefined variables
  (`sigma_residual`, `v_i`, `tau2`, `n_studies`, `study_index`) in
  fall-back branches.
* `MCMCglmm` HPD credible intervals are labeled with the same
  generic `"credible"` tag as `brms`'s posterior quantiles; the two
  intervals are materially different.
* `lme4` / `glmmTMB` / `brms` extractors don't surface
  singular-fit / boundary / divergent-transition warnings.
* `symbolize.drmTMB` adds `ci_method = "wald"` before `...`,
  breaking the generic's signature.
* `symbolize.bam` is exported but its capability row is unreachable
  (`symbolize.bam <- symbolize.gam`, and `symbolize.gam` calls
  `capability_check("gam", ...)`).
* `metafor` CIs are unconditionally labelled Wald even when
  `test = "knha"` widens them.

These need test cases and careful staging; they will land in v0.20.

# symbolizer 0.18.3

## v0.18.3 -- Pat + Rose cross-repo audit

Dispatched two role-named review agents in parallel after the
maintainer spotted `(1&#124;site)` rendering as literal text on the
deployed ladder vignette:

* **Pat** (applied-reader / tutorial-flow) — surfaced the
  package-level pipe-encoding bug, a singular-fit landmine on Rung 3
  of the ladder, and a "30+ vs ~30 family-class combinations"
  inconsistency between the homepage's two paragraphs.
* **Rose** (cross-repo consistency / stale wording) — found that the
  roadmap article had drifted badly: claimed `marginal_contrasts()`
  and `reference_grid_story()` were upcoming features (they were
  never built), described rma.ls and `propto` as "planned" when they
  shipped in v0.15 / v0.16, and the release-history table stopped at
  v0.14.1.

### Fixes

* **Package-level pipe-encoding fix in `knit_print.symbolizer_formula_bridge()`**:
  pre-escape `|` -> `\|` in the `r_syntax` column before backticking.
  Previously, mixed-model R syntax like `(1 | group)` was rendered as
  `(1&#124;group)` in pandoc pipe-tables, then re-escaped at HTML
  output to literal `&amp;#124;`. The fix runs everywhere
  `formula_bridge()` knit-prints, so every vignette and every user's
  knitted report benefits.
* **Ladder recap table**: the `Rung` column moved from markdown
  backticks to explicit `<code>` tags. With
  `kable(format = "html", escape = FALSE)`, pandoc still parses
  markdown inside table cells; explicit HTML tags bypass that.
* **Roadmap article rewritten** (`vignettes/symbolizer-roadmap.Rmd`):
  - "What's covered today" header bumped from v0.14.1 -> v0.18.x.
  - Cross-cutting-surfaces table updated: confidence bands marked
    Stable, `as_dag()` row notes the new `$mermaid` / `$tikz` slots,
    `simulate_recipe()` and `as_html_three_views()` rows added,
    stale version anchors removed.
  - "What's planned" rewritten: rma.ls / `struct = "UN"` / glmmTMB
    `propto` removed (shipped); `marginal_contrasts()` /
    `reference_grid_story()` removed (never built and out of scope
    given the kept-public discipline). Remaining items merged into
    v0.19+ and Considered buckets.
  - Release-history table extended with v0.15 -- v0.18.3.
  - Kept-public list updated to include `simulate_recipe()`.
* **Rung 3 singular-fit landmine** (`vignettes/symbolizer-ladder.Rmd`):
  the data-gen used `rnorm(n_sites, 0, 0.6)`, which combined with
  `set.seed(1)` and the heteroscedastic residual produced a
  `boundary (singular) fit` from `lmer` — `variance_components`
  showed site SD = 0 in the very rung that's supposed to demonstrate
  variance partitioning. Bumped to `rnorm(n_sites, 0, 1.5)`; lmer
  now recovers a clearly non-zero site SD. Truth-list bullet updated.
* **Rung 4 lead-in** named the *location-scale* concept (also called
  "distributional regression" / "heteroscedastic regression") in
  plain language before introducing `log(σ_i) = γ_0 + γ_1 T_i` —
  an ecologist meeting `dpar`-style submodels for the first time
  now has a phrase to look up.
* **Stale version anchors** in four vignettes cleaned up
  (`symbolizer.Rmd:96`, `:259`; `symbolizer-drmtmb.Rmd:33`;
  `symbolizer-factors.Rmd:528`). The drmTMB one was the worst —
  it said Student-t / lognormal / Gamma / beta "remain on the
  roadmap" when all four shipped in v0.3.
* **README "30+ vs ~30"** mismatch resolved (both paragraphs now
  say "30+", consistent with the capability registry count).
* **NEWS v0.17 line** that promised `as_mermaid()` / `as_tikz()` /
  `render_model_notebook()` exports for v0.18 was corrected — only
  `simulate_recipe()` shipped as a function; diagram surfaces became
  slots on `as_dag()` to keep the public surface tight;
  `render_model_notebook()` is deferred further.
* **Citation consistency**: `Lopez-Lopez` -> `López-López` (3 sites);
  `Nakagawa (2024+)` -> `Nakagawa (forthcoming)` (2 sites).

devtools::check(): 0 errors / 0 warnings / 0 notes.

# symbolizer 0.18.2

## v0.18.2 -- three-views widget tab switching works again

The interactive `as_html_three_views()` widget rendered correctly in
v0.18.1 (after the indented-code-block fix) but the **tabs did not
switch on click**. Only the first panel ("Equation") was reachable on
the deployed pkgdown article and any knitted vignette.

Root cause: the inline JavaScript that wires up `click` and `keydown`
handlers was written as a literal R string with embedded `\"` escape
sequences inside the two `querySelectorAll` selectors:

```js
root.querySelectorAll("[role=\"tab\"]")
root.querySelectorAll("[role=\"tabpanel\"]")
```

R's string parser **does** process `\"` inside both single- and
double-quoted strings, stripping the backslash. After R parsing, the
emitted JavaScript became:

```js
root.querySelectorAll("[role="tab"]")
root.querySelectorAll("[role="tabpanel"]")
```

which is a JS syntax error. The IIFE failed silently, no event
handlers were installed, and the panel-switching logic never ran.

Fix: the JS body is now wrapped in an R raw string (`r"---(...)---"`,
available since R 4.0; the package's `Depends` is R >= 4.1.0). Raw
strings do not process escape sequences, so the `\"` survives
verbatim into the rendered `<script>` block.

A regression test
(`test-three-views.R::"emitted JS preserves the escaped CSS selector
quotes"`) asserts both that the **escaped** form
`querySelectorAll("[role=\"tab\"]")` appears, and that the **broken**
un-escaped form `querySelectorAll("[role="tab"]")` does not. This
catches any future regression to plain-quoted R strings.

No other changes. `devtools::check()` clean (0 / 0 / 0).
`testthat::test_dir()`: all assertions pass (`test-three-views.R`
now has 44 expectations).

# symbolizer 0.18.1

## v0.18.1 -- audit pass: doc + vignette consistency

A documentation-consistency sweep. Three exploration agents (vignette
audit, R/ documentation audit, top-level files audit) surfaced the
following inconsistencies, now fixed:

### Vignette staleness

* `vignettes/symbolizer-gllvm.Rmd` no longer says "`symbolize.gllvmTMB`
  is a v0.4 First slice still being wired in" with `tryCatch()` guards
  -- the extractor has been live since v0.4-v0.5. Section 5 now
  invokes `symbolize()` directly. Section 9 ("What's available now,
  what's next") rewritten to reflect current scope (Gaussian +
  binomial latent variable shipped; further families and bootstrap
  uncertainty still planned).
* `vignettes/symbolizer.Rmd` "Today (v0.15) `symbolize()` reads ten
  package families" -> "`symbolize()` currently reads ten package
  families" (drop the stale version anchor).
* `vignettes/symbolizer-drmtmb.Rmd` line 482 "v0.1 surface does not
  plot live" rewritten as "`symbolizer` does not draw the plots
  itself" (the v0.1 reference is irrelevant by now).
* `vignettes/symbolizer-drmtmb.Rmd` section 10 "v0.1 ships ... v0.2
  added ..." rewritten to describe the current drmTMB capability set.
* `vignettes/symbolizer-factors.Rmd` "v0.1 does not yet ship an
  interaction template" -- removed; interaction templates have been
  in `interpretation-templates.csv` since v0.1.1.

### R/ documentation

`@references` blocks added to every `symbolize.X` method that didn't
already have one:

* `drmTMB` (Nakagawa; Kristensen et al. 2016 TMB)
* `gllvmTMB` (Nakagawa)
* `glmmTMB` (Brooks et al. 2017)
* `brmsfit` (Bürkner 2017)
* `lmerMod` / `glmerMod` (Bates et al. 2015)
* `MCMCglmm` (Hadfield 2010)
* `sdmTMB` (Anderson et al. 2022)
* `gam` / `bam` (Wood 2017; Wood 2011)
* `lm` (Chambers 1992)
* `glm` (McCullagh & Nelder 1989)

`@section Confidence intervals:` blocks added to `symbolize.gam` /
`bam` (Wald approximations on parametric coefs; smooths summarised
separately) and `symbolize.gllvmTMB` (Wald via sd_report).
`symbolize.glm` gets an explicit "profile likelihood" CI note.

### Top-level files

* `README.Rmd` Positioning paragraph now mentions classical
  (base-R) regression explicitly, not just GLMM / meta-analysis /
  additive-model / Bayesian-multilevel.
* `NEWS.md` v0.15.0 "Still planned beyond this batch" -- two items
  that shipped in v0.16.0 (Slices C + D) are now annotated as
  shipped.

### Bug fix: three-views widget rendering in pkgdown / knitted vignettes

* `as_html_three_views()` previously emitted the three tab `<button>`
  elements with 4-space cosmetic indentation. Pandoc's markdown reader
  treats any line with 4+ leading spaces as the start of an indented
  code block, so the buttons were silently re-emitted inside
  `<pre><code>...</code></pre>` with HTML-escaped angle brackets,
  causing the raw tags and stylesheet to leak into the rendered page
  (visible on the deployed pkgdown ladder vignette and any external
  re-render). The function now keeps all nested HTML at 0-2 spaces of
  indentation and carries a header comment warning against re-introducing
  4+-space indents.
* `vignettes/symbolizer-ladder.Rmd` no longer wraps the call in
  `htmltools::tagList(as_html_three_views(sym4))`. `tagList()` treats
  the character return value as a text node and re-emits the same HTML
  escaped, on top of the rendered widget. The chunk now uses
  `invisible(as_html_three_views(sym4))` and a `results = "asis"`
  context, which lets the function's internal `cat()` write raw HTML
  once. The "(opens in the Viewer pane)" caption was also wrong --
  `cat()` writes to the console, not to RStudio's Viewer -- and has
  been replaced with an accurate description of the `cat()` + `asis`
  pattern.

No other code changes. No behaviour changes for the other extractors.
`testthat::test_file("tests/testthat/test-three-views.R")` continues to
pass all 40 assertions (the de-indent only changes cosmetic whitespace,
which the test suite did not depend on).

# symbolizer 0.18.0

## v0.18 -- Option B debt cleared: simulate_recipe() and diagram surfaces

Closes the long-standing Option B debt named in the master plan
(simulate_recipe + diagrams beyond as_dag).

* New exported function `simulate_recipe(sym, n = NULL, seed = NULL)`.
  Returns a `symbolizer_simulation_recipe` S3 object with two slots:
  - `$pseudocode` -- numbered prose steps describing the
    generative model (draw random effects, build linear predictor,
    apply inverse link, sample response).
  - `$r_code` -- runnable R code with the right RNG calls for the
    fitted family (rnorm / rbinom / rpois / rgamma / rnbinom for
    Gaussian / binomial / Poisson / Gamma / negative-binomial, and a
    two-tier draw for `meta_normal`).
  Family-aware via the symbolized_model's `submodels` and
  `random_effects` tibbles; honours link functions and detects
  optional sigma / zi submodels.
* `as_dag(sym)` is enriched with two new slots (no new exports):
  - `$mermaid` -- Mermaid-flowchart string suitable for pasting into
    Markdown / Quarto.
  - `$tikz`    -- TikZ string suitable for inclusion in a LaTeX
    document (requires `\\usepackage{tikz}` and the
    `positioning,shapes.geometric` libraries).
  The existing `$dot` (GraphViz) slot is unchanged.
* pkgdown reference page gains a "Simulation recipe" section listing
  `simulate_recipe`; the "Model diagram" section is rewritten to
  mention all three syntactic frames (DOT / Mermaid / TikZ).
* `as_dag` test updated to assert the five-slot shape.

# symbolizer 0.17.0

## v0.17 -- ladder vignette and homepage refresh

This release replaces the abrupt "jump straight into a complex
location-scale model" on-ramp with a gentle 4-rung ladder, on one
shared synthetic dataset.

* New article `vignettes/symbolizer-ladder.Rmd` ("Building up: from
  `lm` to location-scale"). One synthetic
  `body_mass ~ temperature + sex + site` dataset, four rungs:
  (1) `lm(body_mass ~ temperature)`, (2) `+ sex`, (3) `lmer` with
  `(1 | site)`, (4) `drmTMB` location-scale with
  `sigma ~ temperature`. At each rung the same `symbolize()` call
  produces a richer symbolic specification; "what just got added"
  callouts highlight the new line(s).
* The interactive `as_html_three_views()` widget renders live at the
  end of the ladder (Rung 4) so the reader sees Equation /
  Index-expansion / Matrix-with-data tabs side by side.
* New homepage screenshot of the widget at
  `man/figures/three-views-widget.png` -- the README's "Three views
  of the same fit" section now shows the widget instead of just
  describing it.
* `_pkgdown.yml`: navbar Articles dropdown reorganised. "Get started"
  is now Ladder -> Concepts (the existing `symbolizer.Rmd`);
  remaining articles moved into "Deep dives".
* README "Tiny example" gets a callout pointing readers at the
  ladder for a gentler on-ramp.

Option B debt (`simulate_recipe()` and diagram surfaces) stays
deferred to v0.18. (When it landed in v0.18, `simulate_recipe()`
became a real exported function; the diagram surfaces shipped as
`$mermaid` and `$tikz` slots on `as_dag()` rather than as separate
`as_mermaid()` / `as_tikz()` exports, to keep the public surface
tight. `render_model_notebook()` is deferred further.)

# symbolizer 0.16.0

## v0.16 -- meta-analysis bridge complete

Three slices that together close the cross-package meta-analysis
story:

### Slice B -- rma.mv `struct = "UN"` (bivariate / multivariate covariance)

`symbolize.rma.mv()` now handles fits constructed with
`~ inner | outer, struct = "UN"` -- the bivariate / multivariate
meta-analysis pattern (e.g., two outcome measures per trial). When
detected:

* Per-inner-level diagonal variances appear in `variance_components`
  with `kind = "heterogeneity_un"` (one row per inner level).
* Off-diagonal correlations (from `fit$rho`) appear as rows with
  `kind = "correlation"`.
* LaTeX renders one `u_{level(i)}` random-effect symbol per inner
  level.

New capability row `rma.mv,meta_normal,struct_UN` (First slice).

### Slice C -- glmmTMB `propto()` (and future `equalto()`) detection

`symbolize.glmmTMB()` now detects the meta-analytic /
phylogenetic / pedigree-controlled pattern used in
`glmmTMB(y ~ 1 + (1 | study) + propto(0 + obs | g, V), ...)`. When
the conditional RE blocks include a `propto()` (covariance code 11)
or future `equalto()` term:

* `sym$metadata$meta_analysis_via_glmmTMB` is set to `TRUE`.
* `warning_table()` adds an info-level row pointing at the
  equivalent metafor `rma.mv(yi, V, random = ..., R = ...)` and
  drmTMB location-scale constructions, citing Williams (2023),
  Viechtbauer & Lopez-Lopez (2022), and Nakagawa et al. (2025).
* The propto / equalto block is stripped from the rhs before
  `extract_terms()` runs (`glmm_strip_meta_calls()`), so the
  formula bridge and LaTeX render cleanly.

New capability rows: `glmmTMB,{gaussian,binomial,poisson},propto`
(First slice).

### Slice D -- "Three faces of meta-analysis" article

New vignette `vignettes/symbolizer-meta.Rmd`. Fits the same
two-tier meta-analytic model via `metafor::rma.mv`, `glmmTMB` with
`propto()`, and `drmTMB` location-scale. Shows `symbolize()` output
side by side, explains the variance ($\tau^2$, $\alpha$) vs SD
($\sigma$, $\gamma$) parameterization gap with the
$\alpha_k \approx 2 \gamma_k$ relationship, and points to when each
package is the natural choice.

The article is reachable from a new pkgdown navbar group
"Cross-package bridges".

### Deferred to later

* Full prose re-routing for glmmTMB-as-meta-analysis (currently
  flagged via warning, but `family` stays Gaussian for prose
  templating) -- v0.16.x
* Double-hierarchical location-scale via brms (Nakagawa Eq 19-22)
  -- v0.17 candidate
* Publication-bias detection layer (Nakagawa Sec 2.5) -- v0.17
  candidate
* I^2 / CV heterogeneity partitioning -- v0.17 candidate

# symbolizer 0.15.1

## v0.15.1 -- positioning text refresh: not just drmTMB

Stale framing pass: the homepage positioning paragraph still
described `symbolizer` as "for drmTMB" even though the package now
reads ten package families. This release rewrites the user-facing
prose so the multi-package scope is visible from the homepage and
Get-started vignette.

* README `Positioning` paragraph rewritten: now describes
  `symbolizer` as making "a fitted model auditable" across "the GLMM,
  meta-analysis, additive-model, and Bayesian-multilevel packages an
  ecologist or evolutionary biologist actually uses".
* README "Built first for..." paragraph: now reads "Currently reads
  ten package families" with the list spelt out, and a direct link
  to the Roadmap article.
* DESCRIPTION text: extended to name `drmTMB`, `gllvmTMB`, `glmmTMB`,
  `brms`, `lme4`, `MCMCglmm`, `sdmTMB`, `stats::lm`/`glm`, `metafor`,
  `mgcv` explicitly.
* `vignette("symbolizer")` "What's supported, what's planned": no
  longer claims "v0.1 marks ... as Stable"; reflects v0.15 reality
  and links to the Roadmap article.
* `vignette("symbolizer-families")`: no longer says "Eight
  distribution families ship today"; clarifies that this vignette
  walks the drmTMB non-Gaussian families specifically, while the
  same `symbolize(fit)` interface applies to all ten package
  families.

No code changes. Test sweep + check unchanged.

# symbolizer 0.15.0

## v0.15 -- location-scale meta-regression (rma.ls)

First slice of the cross-package meta-analysis bridge: `metafor::rma`
with `scale = ~ z` (the `rma.ls` location-scale model) is now
recognised by `symbolize.rma.uni()`. A second submodel `tau2` is added
with the variance-faithful parameterisation:

  log(tau^2_i) = alpha_0 + alpha_1 z_{1i} + ... + alpha_q z_{qi}

This is **log of the variance**, not log of the SD -- coefficients
are `alpha` (Greek alpha) and the natural-scale reading is "tau^2_i
changes multiplicatively by exp(alpha_k) per unit of z_k". The
distinction matters because brms / glmmTMB / drmTMB parameterise
the same structural model via `log(sigma)` (the SD), with `gamma`
coefficients, and the relationship is alpha_k ~ 2 * gamma_k.

* New `tau2` submodel in the symbolizer-wide registry:
  `drm_coef_family_for("tau2") = "alpha"`,
  `drm_link_for(..., "tau2") = "log"`,
  `drm_param_greek("tau2") = "\\tau^{2}"`.
* New capability row `rma.uni,meta_normal,tau2_scale` (First slice).
* New interpretation templates `meta_normal,tau2,{intercept,slope,factor_contrast}`
  that explicitly contrast variance vs SD parameterisations and cite
  Viechtbauer & Lopez-Lopez 2022 / Nakagawa et al. 2025.
* Alpha estimates pulled from `fit$alpha` with Wald CIs from
  `fit$ci.lb.alpha` / `fit$ci.ub.alpha`.
* For rma.ls, `variance_components` reports the mean tau^2_i with
  `kind = "heterogeneity_scale"`; the per-observation vector lives
  in `metadata$tau2`.
* Robustness sweep gains one row: rma.ls location-scale.

### Still planned beyond this batch

Wider meta-analysis bridge items not in v0.15.0. **Update:** the
first two shipped in v0.16.0:

* ✅ glmmTMB `equalto()` / `propto()` detection -- **shipped in
  v0.16.0** (Slice C).
* ✅ Cross-package "Three faces of meta-analysis" article --
  **shipped in v0.16.0** as `vignette("symbolizer-meta")` (Slice D).
* Double-hierarchical location-scale via brms (Nakagawa et al. 2025
  Eq 19-22): random effects on the scale part with bivariate
  (u^(l), u^(s)) distribution. Still planned.
* Publication-bias detection layer (Nakagawa et al. 2025 Section 2.5):
  small-study effect / decline effect / small-study divergence /
  Proteus effect, surfaced via `warning_table()`. Still planned.
* I^2 / CV partitioning (Eq 14-16, 26-31): derived heterogeneity
  measures attached to `metadata$heterogeneity_partition`. Still
  planned.

The brms double-hierarchical / publication-bias / I^2 items are
queued for v0.19+.

# symbolizer 0.14.2

## v0.14.2 -- Roadmap moved to its own page; README slimmed

The README homepage had grown to ~250 lines because the capability
matrix and roadmap tables sat alongside the introductory material.
That layout was hard to scan once the package crossed ten model
classes.

* New article `vignettes/symbolizer-roadmap.Rmd` ("Roadmap and
  capability matrix") -- the canonical home for the status
  vocabulary, full capability matrix, planned releases, and release
  history. It's reachable from a new top-level **Roadmap** entry in
  the pkgdown navbar.
* README slimmed: capability matrix and roadmap tables removed; in
  their place a single "At a glance" paragraph naming the 10
  covered package families and linking to the Roadmap article. README
  is now ~170 lines.
* `_pkgdown.yml`: navbar gains a "Roadmap" link
  (`articles/symbolizer-roadmap.html`); the article is also listed
  under a new "Where we're going" article group.
* NEWS continues to record past releases (no overlap with the
  Roadmap article, which is forward-looking).

No code changes; no behaviour changes. devtools::check() unchanged.

# symbolizer 0.14.1

## v0.14.1 -- metafor rma.mv (multilevel + structured meta-analysis)

`symbolize.rma.mv()` for `metafor::rma.mv` fits. Covers the two
patterns that dominate modern ecology / evolution / education
meta-analyses:

* **Multilevel meta-analysis** -- multiple random-effect tiers via
  `random = list(~ 1 | study, ~ 1 | id)` or the nested syntax
  `random = ~ 1 | district / study`. Each tier gets a row in
  `variance_components` with `kind = "heterogeneity"`, and a
  `u_{tier(i)} \sim \mathcal{N}(0, \sigma^2_{tier})` line in the
  LaTeX.

* **Structured random effects (phylogenetic / pedigree / spatial)**
  -- when `R = list(group = R_matrix)` is attached to the fit, the
  tier is tagged `kind = "structured"` and listed in
  `sym$metadata$structured_random` with the R-matrix dimension.

The fixed-effects extraction reuses the rma.uni infrastructure
(intrcpt row-name mapping + Wald CIs via `fit$ci.lb` / `fit$ci.ub`),
so meta-regression moderators work the same way for `rma.mv` as for
`rma.uni`. The two-tier sampling-distribution / linear-predictor
structure inherits from `family = meta_normal` so the assumption /
interpretation prose is shared with `rma.uni`.

Two new helper fits (`fit_metafor_rma_mv()`,
`fit_metafor_rma_mv_structured()`) and two new robustness-sweep rows.

Capability rows: `rma.mv,meta_normal,mu` and
`rma.mv,meta_normal,structured` (both First slice).
`struct = "UN"` / `"HCS"` / `"AR"` covariance structures and
selection / publication-bias variants remain Planned.

# symbolizer 0.14.0

## v0.14 -- mgcv additive grammar (gam / bam / gamm / gamm4)

* `symbolize.gam()` (and `symbolize.bam = symbolize.gam` since `bam`
  inherits from `gam`) for `mgcv::gam` / `mgcv::bam` fits. First
  slice covers gaussian / poisson / binomial / Gamma families with
  smooth specifications `s(x)`, `s(x, by = factor)`, and `te(x, z)`.
  Method-of-fit (REML / GCV.Cp) is captured as metadata.
* Smooth terms are summarised in `sym$metadata$smooths` -- one row
  per smooth with `label`, `bs_dim` (basis dimension K), `edf`
  (effective degrees of freedom), p-value, underlying `variable`(s),
  and `by_var` (for `s(x, by = group)`).
* LaTeX rendering appends a smooth term `f_l(x_i)` (or
  `f_l(x_i, z_i)` for tensor products) to the linear predictor for
  each smooth, so the additive structure
  `g(mu_i) = beta_0 + sum beta_k x_ki + sum_l f_l(z_li)` is visible.
* Smoothing parameters lambda_l appear in `variance_components` with
  `kind = "smoothing_param"`; the residual SD (for Gaussian) appears
  with `kind = "residual"`.
* `mgcv::gamm()` and `gamm4::gamm4()` return lists with a `$gam`
  slot of class `gam`. Document the pattern
  `symbolize(fit_gamm$gam)`; both are covered by the test sweep.
* Warning surface: when a smooth's `edf` approaches its basis
  dimension `K`, the extractor flags it with the same suggestion
  `mgcv::gam.check()` makes -- "consider increasing k".
* mgcv + gamm4 added to `Suggests`.
* Two new robustness-sweep rows: gam with `s(x)`, gam with
  `te(x, z)`.

# symbolizer 0.13.0

## v0.13 -- metafor (research-synthesis flagship)

This release adds the meta-analytic grammar -- a distinct two-tier
structure with sampling variance, true effects, and between-study
heterogeneity that's substantively different from the GLMMs the
package has covered until now.

### New extractor

* `symbolize.rma.uni()` for `metafor::rma.uni` fits. Covers random
  and mixed-effects meta-regression with the model:
  ```
  y_i | theta_i ~ N(theta_i, v_i)             (sampling level, v_i known)
  theta_i = beta_0 + sum beta_k x_ki + u_i    (true-effect level)
  u_i ~ N(0, tau^2)                            (heterogeneity)
  w_i = 1 / (v_i + tau^2)                      (inverse-variance weight)
  ```
* Sampling variances `v_i` are treated as KNOWN (inputs, not
  parameters). `tau^2` shows up in `variance_components` with
  `kind = "heterogeneity"`; mean sampling variance is reported with
  `kind = "sampling_variance"` for reader reference.
* New family `meta_normal` in `family-distributions.csv` /
  `family-parameterizations.csv`. 9 new rows in
  `assumption-templates.csv` covering known sampling variance, the
  linear predictor for true effects, between-study heterogeneity,
  inverse-variance weights, publication-bias responsibility, correct
  effect-metric responsibility, and conditional independence. 3 new
  interpretation rows for intercept / slope / factor-contrast on the
  meta-analytic scale.
* metafor's `intrcpt` row name (vs. R's usual `(Intercept)`) is
  handled in the hit-name mapper.
* `rma.mv` (multilevel / multivariate meta-analysis) remains Planned.

### Robustness

* `test-robustness-sweep.R` gains two rows: random-effects meta-
  analysis (no moderators) + meta-regression (with moderator).

# symbolizer 0.12.0

## v0.12 -- close the original-vision gaps: sdmTMB + MCMCglmm animal models

This release closes the two remaining gaps from the May 23 master
roadmap. sdmTMB lands as a first-class extractor; MCMCglmm gains an
animal-model branch with derived heritability.

### sdmTMB (new)

* `symbolize.sdmTMB()` -- first slice covers Gaussian fits with an
  optional spatial random field (`spatial = "on"`) and / or
  spatiotemporal field (`time = "..."`). Fixed-effect estimates and
  Wald CIs come from `sdmTMB::tidy(fit)`; spatial-range and field-SD
  parameters come from `sdmTMB::tidy(fit, "ran_pars")` and appear in
  the `variance_components` tibble with `kind = "spatial_random"` /
  `spatial_range`.
* Capability rows: `sdmTMB,gaussian,mu` / `omega` / `epsilon` all
  First slice; non-Gaussian families, delta-models, and
  `spatial_varying` slopes still Planned.
* `sdmTMB` added to `Suggests`.

### MCMCglmm animal models (extension)

* `symbolize.MCMCglmm()` now detects `fit$ginverse` and treats those
  groups as animal-model / phylogenetic effects. The
  `variance_components` tibble gains a `kind` column
  (`animal` / `random` / `residual`), and a heritability tibble
  `h^2 = sigma^2_A / (sigma^2_A + sigma^2_E)` is derived and attached
  to `sym$metadata$heritability` whenever both an animal effect and
  a residual variance are present.
* Capability row: `MCMCglmm,gaussian,animal` First slice. The
  flexible residual covariance structures (`us(trait):unit`,
  `idh(trait):unit`) remain Planned -- multi-response fixtures and
  matrix-rendering grammar are coming with the metafor v0.13 batch.

### Robustness sweep

* `test-robustness-sweep.R` gains two new rows: MCMCglmm animal +
  sdmTMB spatial. The full public renderer surface
  (`as_latex`, `equations`, `symbol_table`, `assumption_table`,
  `formula_bridge`, `parameter_interpretation`, `as_dag`,
  `warning_table`) is exercised on each.

### Roadmap text refresh

* README capability matrix and roadmap table rewritten to reflect
  v0.7 -> v0.12 as released, with metafor / mgcv / emmeans-depth
  listed as Planned for v0.13 / v0.14 / v0.15. Capabilities CSV's
  stale "Targeted for v0.X" notes updated.

# symbolizer 0.11.2

## v0.11.2 -- more brms families + interaction robustness

* `symbolize.brmsfit()` now handles `family = bernoulli()` and
  `family = poisson()`. brms's `bernoulli()` is aliased to
  `binomial` internally because mathematically Bernoulli is just
  Binomial(1, p); the same templates and parameterization apply.
* New `tests/testthat/test-robustness-interactions.R` fits `y ~ x *
  sex` (continuous-by-factor interaction) in each family / class
  combination and verifies the interaction row appears in
  `fixed_effects` with sensible estimate, CI columns are populated,
  and LaTeX renders. Covers lm gaussian, glm binomial / poisson /
  Gamma, glmmTMB poisson / binomial, lmer with random intercept,
  and drmTMB gaussian.

# symbolizer 0.11.1

## v0.11.1 -- two more deferred items

* `symbolize.brmsfit()` now handles `bf(y ~ x, sigma ~ z)`
  distributional fits. The sigma submodel shows up alongside mu with
  its own credible band; LaTeX renders both lines with the correct
  log link on sigma. brms's other distributional dpars (`nu`, `phi`,
  etc.) are still routed to the "Planned or reserved" status word.
* `symbolize.glmmTMB()` now handles `ziformula = ~ x` for poisson and
  nbinom2 fits. The zero-inflation submodel shows up alongside mu
  with its logit link in the LaTeX. Behaviour matches `drmTMB`'s
  zi / hu handling so the same fit through either package produces
  the same teachable story.
* Hardened: `brms::VarCorr(fit)` errors on fixed-effects-only fits;
  the extractor now catches that and treats it as "no random
  effects" rather than crashing.

# symbolizer 0.11.0

## v0.11 -- deferred items: non-Gaussian glmmTMB / glmer, glm Gamma, robustness

This release picks up the items deferred during the v0.7 -> v0.10
push and adds a robustness sweep so any future extractor regression
surfaces in one place.

### New family coverage

* glmmTMB binomial / poisson / nbinom2 (with `(1 | g)` random
  intercepts) -- the family check was the only thing blocking these;
  the CSV-driven prose layer already had templates from earlier
  releases. Reusing the same extractor code path means the LaTeX,
  assumption table, parameter readings, and methods text all line
  up across drmTMB and glmmTMB for the same family.
* `symbolize.glmerMod()` for lme4 generalised mixed models. First
  slice covers binomial / poisson with their canonical links.
* glm Gamma (`stats::Gamma(link = "log")`) is now First slice via
  the same CSV plumbing that drmTMB Gamma uses.

### Robustness

* New `tests/testthat/test-robustness-sweep.R` runs every
  `symbolize.*` method through every public renderer
  (`as_latex`, `equations`, `symbol_table`, `assumption_table`,
  `formula_bridge`, `parameter_interpretation`, `as_dag`,
  `warning_table`). 13 model classes / family combinations,
  ~120 expectations. Any new extractor must keep this sweep
  green.

### Still deferred (v0.11.x and later)

* sdmTMB (not installed in the dev environment).
* brms distributional formulas (`sigma ~ z`) and non-Gaussian brms
  families.
* MCMCglmm flexible covariance structures (animal models,
  multi-membership, per-trait residuals).
* glmmTMB zero-inflation submodels (`ziformula`).
* glm inverse.gaussian / quasi-families.

# symbolizer 0.10.0

## v0.10 -- base R + lme4

* New: `symbolize.lm()` for base R `lm()` fits (Gaussian + identity
  link only -- the only family `lm()` fits). Wald-t confidence
  intervals from `confint()`.
* New: `symbolize.glm()` for base R `glm()` fits. First slice covers
  Gaussian / binomial / poisson with their canonical links. Wald CIs
  via `confint.default()` (the default `confint()` for glm uses
  profile likelihood which is slow on big fits; the extractor opts
  into the faster Wald path).
* New: `symbolize.lmerMod()` for `lme4::lmer()` fits (Gaussian
  conditional submodel with optional `(1 | g)` random intercepts).
  CIs via `lme4::confint.merMod(fit, parm = "beta_", method = "Wald")`.
  Pass `ci_method = "profile"` for profile-likelihood CIs.
* methods_text() templates added for lm / glm / lmerMod.
* `glm` family classes for binomial / poisson are family-keyed in the
  capability registry; Gamma / inverse.gaussian / quasi families are
  deferred to v0.10.x.
* sdmTMB is deferred to v0.10.x (not installed in the dev
  environment; needs separate testing on a machine with sdmTMB
  available).

# symbolizer 0.9.0

## v0.9 -- MCMCglmm

* New: `symbolize.MCMCglmm()` (first slice). Builds a `symbolized_model`
  from an `MCMCglmm` fit for the Gaussian conditional submodel
  (identity link) with optional `~ g` random intercepts.
* MCMCglmm does NOT keep the data frame on the fitted object, so
  `symbolize.MCMCglmm(fit, data = ...)` takes a mandatory `data`
  argument. The function errors with a friendly message if `data` is
  omitted.
* CI band uses the 95% credible interval from `summary(fit)$solutions`
  (l-95% CI / u-95% CI, the highest-posterior-density bounds).
  `ci_method = "credible"`.
* methods_text() template for `MCMCglmm / gaussian` mentions Gibbs
  sampling with inverse-Wishart priors on the variance components.
* MCMCglmm's flexible covariance structures (per-trait residuals,
  multi-membership, animal models) are routed through the capability
  registry as "Planned or reserved" for v0.9.x.

# symbolizer 0.8.0

## v0.8 -- brms

* New: `symbolize.brmsfit()` (first slice). Builds a `symbolized_model`
  from a `brmsfit` for the Gaussian conditional submodel (identity
  link) with optional `(1 | g)` random intercepts.
* Bayesian-aware CI band: instead of frequentist Wald / profile, the
  extractor uses the posterior 2.5% / 97.5% quantiles from
  `brms::fixef(fit)` as the credible interval. `ci_method` is set to
  `"credible"` so downstream renderers can label the band correctly.
* `methods_text()` template for `brmsfit / gaussian` mentions Hamiltonian
  Monte Carlo via Stan, weakly-informative default priors, and
  credible (not confidence) intervals.
* brms's distributional-parameter formulas (`sigma ~ z`, etc.) and
  non-Gaussian families are routed through the capability registry as
  "Planned or reserved" for v0.8.x.

# symbolizer 0.7.1

## v0.7 audit pass

* `vignettes/symbolizer-families.Rmd` rendered seven distribution
  lines as raw LaTeX text instead of math. The chunks now use a
  small `render_math()` helper (defined in the vignette's setup
  chunk) that wraps the LaTeX string in `$$...$$` via
  `knitr::asis_output()`, so KaTeX / MathJax / pandoc pick it up and
  render proper display math.
* `methods_text()` now has a template for `glmmTMB / gaussian`.
  Previously the function errored "no template" on every glmmTMB
  fit; the new template covers both the bare conditional submodel
  and the `dispformula = ~ z` case (the residual-SD sentence is
  conditional).
* The "no template" error message now lists supported `class /
  family` combinations from the CSV itself, so it can't drift out
  of sync with reality the way it had (it was still naming three
  combos when 13 existed).
* `README.Rmd` capability matrix and roadmap updated to reflect
  v0.4 (zi / hu / cumulative_logit), v0.5 (gllvmTMB binomial),
  v0.6 (`as_dag()`), and v0.7 (glmmTMB) — previously they stopped
  at v0.3.

# symbolizer 0.7.0

## v0.7 — glmmTMB

* New: `symbolize.glmmTMB()` (first slice). Builds a `symbolized_model`
  from a `glmmTMB` fit for the Gaussian conditional submodel (identity
  link), with optional `(1 | g)` random intercepts and an optional
  `dispformula = ~ z` distributional sigma submodel. Non-Gaussian
  families and zero-inflation are routed through the capability
  registry as "Planned or reserved" for now.
* The new extractor reuses the prose layer (assumption / interpretation
  / symbol-dictionary / formula-bridge builders) by producing the same
  tibble shapes as `symbolize.drmTMB()`. Family-keyed CSVs in
  `inst/extdata/` drive prose, so a Gaussian glmmTMB fit produces the
  same teachable readings as the drmTMB equivalent.
* Confidence intervals come from `glmmTMB::confint(fit, parm = "beta_",
  method = ci_method)`. Default `ci_method = "wald"`; `"profile"` and
  `"uniroot"` available.

## Fixes

* `parameter_interpretation(sym, scale = ...)` now carries the
  confidence-band columns (`std_error`, `confint_low`, `confint_high`,
  `excludes_zero`, `ci_method`) on every scale, not just `scale = "all"`.
  Previously these were dropped when the user picked a specific scale,
  so the rendered Markdown / pkgdown table omitted the CI band even
  though the underlying interpretation tibble had it.

# symbolizer 0.6.0

## v0.6 — model diagrams

* New: `as_dag(sym)` returns a structural DAG of the fitted model with
  three slots: `nodes` (tibble — response, parameters, predictors,
  groups, random effects), `edges` (tibble — predictor→parameter
  edges, parameter→response distribution edges, group→random-effect
  edges, random-effect→parameter contributions), and `dot` (a single
  GraphViz / DOT-language string).
* The S3 class is `symbolic_dag`. `print()` summarises the node and
  edge counts and emits the DOT string with a copy/paste pointer to
  GraphvizOnline; `knit_print()` wraps the DOT inside a fenced
  `dot` code block so Quarto / Markdown engines that support DOT
  rendering pick it up automatically.
* Nodes are styled by kind:
  - response → double circle, salmon fill
  - parameter (μ, σ, ν, ...) → ellipse, cream fill
  - predictor → box, green fill
  - group variable → house shape, lavender fill
  - random effect → circle, orange fill
  Edges are styled by relationship: distribution edges are bold red;
  linear-predictor edges are solid; group / random-contribution
  edges are dashed.
* No new hard dependencies. To render the DAG live: paste the `$dot`
  string into <https://dreampuf.github.io/GraphvizOnline/>, or pass
  it to `DiagrammeR::grViz()` (DiagrammeR is not a symbolizer
  dependency).

# symbolizer 0.5.0

## v0.5 — gllvmTMB binomial (first non-Gaussian latent-variable family)

* `symbolize.gllvmTMB()` now reads binomial latent-variable models
  end-to-end. The conditional distribution renders as
  `y_{ij} | mu_{t(j)}, Lambda_B, z_{B,i} ~ Bernoulli(logit^{-1}(mu_{t(j)} + (Lambda_B z_{B,i})_{t(j)}))`,
  trait intercepts read as logit baseline success probabilities
  (e.g. "plogis(mu_t)"), and loadings on `Lambda_B` are noted as
  living on the logit scale (an odds-ratio per unit of `z`).
* `glm_build_distribution()` and the assumption / interpretation
  template lookups are now family-aware: each gllvm family slug
  (`gllvm_gaussian`, `gllvm_binomial`, ...) selects its own rows.
  Added `gllvm_template_family()` helper that maps an upstream
  family name to the slug.
* The sigma_eps capability check now fires only for Gaussian gllvm
  fits. drmTMB's binomial / Poisson / etc. carry a placeholder
  `fit$report$sigma_eps` that previously triggered a spurious
  capability error.
* Capability rows flipped to First slice for `gllvmTMB / binomial /
  mu`, `Lambda_B`, `Sigma_B`, `Psi_B`.

The other gllvm families (Poisson, nbinom2, Gamma, lognormal,
ordinal, ...) stay Planned or reserved. The pattern is now
straightforward: add a CSV slug, mirror the gllvm_gaussian rows
with family-appropriate wording, and add a branch in
`glm_build_distribution()`.

# symbolizer 0.4.0

## v0.4 — ordinal + zero-inflation + hurdle

* `cumulative_logit` — ordered categorical response, proportional-odds
  model. The conditional distribution renders as
  `P(Y_i ≤ k | X_i) = logit⁻¹(θ_k − X_i'β)` with K−1 thresholds
  replacing the intercept. The mu linear predictor is rendered
  without an intercept term (drmTMB suppresses it; symbolizer
  matches). Three new assumption rows (`proportional_odds`,
  `ordered_categorical_response`, `thresholds_ordered`) make the
  PO assumption explicit and stay-honest about who's responsible.
* `zi` (zero-inflation) submodel layered on Poisson and nbinom2.
  Rendered as an additional `zi_linear_predictor` component with
  `logit(π_zi,i) = α₀ + ...`, with interpretation rows reading the
  α coefficients as log-odds of being a structural zero. The
  conditional-distribution assumption row spells out the mixture
  `P(Y=0) = π_zi + (1−π_zi)·f(0|μ,...)`.
* `hu` (hurdle) submodel layered on truncated_nbinom2. Same
  shape as zi but with δ coefficients, and the assumption row
  reads as a two-part mixture
  (`P(Y=0) = π_hu; P(Y=k | Y>0) = NegBin⁺(k; μ, exp(σ))`).
* `drm_param_index_form()` now handles non-digit subscripts
  cleanly: `π_{zi}` becomes `π_{zi, i}` rather than the malformed
  `π_{zi}_i`. This was a latent bug that only surfaced once the
  zi/hu submodels started using subscripted Greek symbols.

## v0.3.2 — two more families, families-tour vignette, README refresh

* Two more non-Gaussian families ship via the CSV-only path:
  - **beta_binomial** (`drmTMB::beta_binomial()`) — overdispersed
    binomial counts. Response specified as
    `cbind(successes, failures)`; mean success probability via the
    logit link, precision (inverse-overdispersion) via the log link.
    Coefficients on mu read as odds ratios; the methods_text
    paragraph names the trial count requirement.
  - **truncated_nbinom2** (`drmTMB::truncated_nbinom2()`) —
    zero-truncated counts. The distribution latex flags the
    truncation via `\mathrm{NegBin}^{+}` and the support
    `y in {1, 2, 3, ...}`. The methods_text and assumption rows
    are explicit that mu is the mean of the *underlying
    untruncated* distribution; the observed mean is larger.
* `methods_text` univariate-family list grows to include both new
  families so the response / sigma / RE substitutions fire without
  `[unfilled: ...]` markers.
* New vignette `symbolizer-families` — a tour of the seven non-
  Gaussian families currently shipping. One small fit and one key
  surface per family (distribution latex, biological reading on
  mu, or methods_text excerpt), plus six rules of thumb for
  picking a family. Bivariate Gaussian is cross-referenced rather
  than repeated since it has its own section in the drmTMB tour.

# symbolizer 0.3.1

## v0.3.1 — random slopes, response-scale group_means, bigger hex

* Random slopes now work: `symbolize.drmTMB()` reads
  `(1 + x | group)` random-effect terms on the mu submodel
  end-to-end. The mu linear predictor renders the contribution as
  `+ u_{0, group(i)} + u_{1, group(i)} * x_i` (index form) and
  `+ Z_group u_group` (matrix form). The joint MVN distribution of
  the random components is rendered, plus a covariance-decomposition
  row that spells out the 2x2 (or k x k) Sigma_u in terms of the
  per-component SDs and the within-group correlation rho.
* The data shape is extended (forward-compatibly): `random_effects`
  gains `component`, `component_index`, and `predictor_factor`
  columns; `variance_components` gains `component`; a new top-level
  slot `covariance_components` carries the within-group correlations
  for multi-component groups. The intercept-only case
  (`(1 | group)`) keeps the historic simpler symbols and an empty
  `covariance_components` slot, so existing code that assumed the
  old shape still works.
* Capability row `drmTMB / gaussian / random_effects` updated to
  reflect the broader scope; nested / crossed / RE-on-sigma remain
  Planned or reserved.
* The friendly capability gate now distinguishes two unsupported
  shapes: RE on submodels other than mu, and slope-only RE without
  an intercept (each gets its own error message).
* `group_means()` and `group_slopes()` gain a `scale` argument
  (`"response"` (default) or `"link"`) and return a new `scale` column.
  Before this release, both functions returned emmeans output on the
  *link* scale for non-identity-link families — a Poisson "group mean"
  was reported as the log of the count rate, a Beta mean was reported
  as a log-odds, a Gamma mean as a log of the response, and so on.
  That was easy to misread as the response-scale value. The default is
  now `"response"`: the back-transformed mean (count rate for Poisson,
  proportion for Beta, response-scale mean for Gamma, geometric mean
  for lognormal, response-scale mean for nbinom2, mean for Gaussian and
  Student-t). Pass `scale = "link"` to get the linear-predictor scale
  used by the coefficient table.
* For `lognormal` fits drmTMB exposes mu on the identity link (because
  mu represents `log(Y)`), so emmeans's automatic back-transform doesn't
  fire. `group_means()` now tells emmeans about the implicit log
  transformation via `stats::update(emm, tran = "log")` so the
  response-scale output is the geometric mean with delta-method CI.
* `print.symbolizer_group_means()` and
  `print.symbolizer_group_slopes()` name the scale in their footer
  ("Scale: response. CI method: wald.").

# symbolizer 0.3.0

## v0.3 — non-Gaussian drmTMB families, polished methods_text

* `symbolize.drmTMB()` reads four more non-Gaussian families end-to-end
  via the CSV-driven path:
  - **Gamma** (`stats::Gamma(link = "log")`) — positive continuous,
    multiplicative mean reading on the response scale.
  - **Beta** (`drmTMB::beta()`) — Y in (0, 1) with logit-link mean and
    log-link precision; mean coefficients render as odds ratios.
  - **Poisson** (`stats::poisson()`) — counts with no dispersion
    parameter; mean coefficients render as rate ratios. The
    `variance = mean` constraint is called out in both the assumption
    table and the methods_text paragraph.
  - **nbinom2** (`drmTMB::nbinom2()`) — counts with overdispersion;
    the size parameter (`exp(sigma_i)`) controls the Poisson limit.
  Each family ships its own assumption rows, interpretation rows
  (per coefficient role on every relevant scale), and methods_text
  template — no shortcuts, because the biology of each family
  genuinely differs.
* Capability registry rows flipped to `First slice` for
  `drmTMB / Gamma / mu, sigma` (note the capital G — base R's
  `stats::Gamma()` uses that string), `drmTMB / beta / mu, sigma`,
  `drmTMB / poisson / mu`, and `drmTMB / nbinom2 / mu, sigma`.

* `methods_text(sym)` on biv_gaussian fits now reads cleanly when the
  three secondary submodels (sigma1, sigma2, rho12) are intercept-only.
  The old output included an awkward parenthesised
  `(an intercept only; an intercept only)` clause; the polished version
  uses dedicated `sigma_pair_clause` and `rho12_clause` slots that pick
  one of three readable phrasings (both intercept-only, mixed, or both
  with predictors). Templates for univariate families are unaffected;
  this is biv_gaussian-specific because the three-clause shape is
  genuinely unique to it.

* `symbolize.drmTMB()` reads Student-t fits (`family = drmTMB::student()`)
  end-to-end. The Student-t adds a `nu` (degrees-of-freedom) submodel
  alongside `mu` and `sigma`; drmTMB parameterises `nu` on the
  `log(nu - 2)` scale (the `logm2` link) so that `nu > 2` is always
  enforced and the modelled variance `nu / (nu - 2) * sigma^2` is
  finite. The structured symbolic object carries:
  - a Student-t distribution row in both index and matrix forms,
  - submodels for `mu` (identity), `sigma` (log), `nu` (logm2),
  - interpretation rows for the three submodels including a
    biological reading on `nu` that explains heavier vs lighter tails,
  - an assumption row `positivity_and_finite_variance` capturing the
    `nu > 2` constraint,
  - a `methods_text()` template covering the three submodels and the
    log(nu - 2) link explanation.
* Capability registry rows flipped from "Planned or reserved" to
  "First slice":
  - `drmTMB / student / mu`
  - `drmTMB / student / sigma`
  - `drmTMB / student / nu`
* `drm_link_for()` now generalises the multi-dpar link lookup. The
  previous biv_gaussian-only branch was extended to recognise any
  family whose links are exposed as a named vector (Student-t today;
  future families can land without further changes here).
* `symbolize.drmTMB()` reads lognormal fits
  (`family = drmTMB::lognormal()`) end-to-end. The conditional
  distribution row reads `Y_i | mu_i, sigma_i ~ Lognormal(mu_i,
  sigma_i^2) <=> log(Y_i) | mu_i, sigma_i ~ Normal(mu_i, sigma_i^2)`,
  spelling out the equivalence so the reader sees both views.
  Interpretation rows on mu speak in terms of the geometric mean of
  the response — a unit change in a predictor multiplies the
  geometric mean by `exp(beta)`.
* **Architectural refactor: distribution LaTeX is now CSV-driven.**
  `inst/extdata/family-distributions.csv` carries the conditional-
  distribution row (index + matrix form) for every family. The
  previous hardcoded family branches in `drm_build_distribution()`
  and `drm_build_components()` are gone. Adding a future univariate
  family (gamma, beta, Poisson, nbinom2, Tweedie, …) is now a
  CSV-only operation. Structural-shape families (biv_gaussian,
  future GLLVM extensions, ordinal models) still need code because
  their components-list shape differs.

# symbolizer 0.2.1

## v0.2.1 — methods_text, per-fit warnings, biv_gaussian gate

* New: `warning_table(sym)` returns the tibble of conditions that
  `symbolize()` flagged when building the model object. Each row is one
  warning with a `code`, `severity` (`info` / `warn` / `error`),
  templated `message`, and a `context` string. Prose is templated from
  `inst/extdata/warning-templates.csv`. Today the system ships one
  active check: `few_groups_wald` (warn) — Wald 95% CI used with a
  random-effect group of fewer than ~10 levels. The check is suppressed
  when the user passes `ci_method = "profile"` to `symbolize()`.
  `model_card(sym)` surfaces the warnings table when it's non-empty; the
  field also lives on `sym$warnings_registry` for raw access.
* New: `methods_text(sym)` returns a draft Methods-section paragraph
  for a fitted model — the kind of paragraph a biologist would
  otherwise write by hand into a paper. The prose is composed from a
  CSV template (`inst/extdata/methods-templates.csv`) using slots
  filled from the `symbolized_model`. No LLM is involved at runtime;
  every phrase traces to a template row plus the substituted slots.
  Returns a `symbolizer_methods_text` S3 object with three slots:
  `text` (the assembled paragraph), `slots` (the named substitutions),
  and `reminders` (editorial reminders for the author). Templates
  ship for `drmTMB / gaussian`, `drmTMB / biv_gaussian`, and
  `gllvmTMB / gaussian`. Treat the output as a draft; the print
  method appends a reminder to that effect.
* `group_means()` and `group_slopes()` now gate `biv_gaussian` fits at
  the symbolizer layer with a friendly explanation, instead of letting
  drmTMB's emmeans preflight surface a less explanatory error. A
  marginal mean in a bivariate fit is a joint 2-vector prediction
  `(mu1, mu2)`, not a scalar, so the emmeans abstraction does not
  apply. The gate's message points at
  `drmTMB::predict_parameters()` and at the fit-each-response-as-
  univariate alternative. Documented in the roxygen for both
  functions.

# symbolizer 0.2.0

## v0.2 — bivariate Gaussian, structural comparison, article tidy

* `symbolize.drmTMB()` reads bivariate Gaussian fits — the
  `biv_gaussian(y2 ~ ...)` family from drmTMB — through the same
  structured surface used for univariate fits. The response becomes a
  2-vector `(Y_{1i}, Y_{2i})`, the conditional distribution becomes
  `MVN_2((mu_{1i}, mu_{2i}), Sigma_i)`, and the symbolic story now
  carries five submodels (`mu1`, `mu2`, `sigma1`, `sigma2`, `rho12`).
* New capability rows: `drmTMB,biv_gaussian,{mu1,mu2,sigma1,sigma2,rho12}`
  flip from "Planned or reserved" to "First slice".
* Per-submodel response handling: `interpretation` rows for `mu1` /
  `sigma1` substitute `response_1`; `mu2` / `sigma2` substitute
  `response_2`; `rho12` rows reference both.
* `formula_bridge` carries one row per submodel including the new
  `mu1`, `mu2`, `sigma1`, `sigma2`, `rho12` parts; the `rho12`
  meaning reads as "Fisher-z residual correlation between {response_1}
  and {response_2} is a linear function of the correlation-model
  predictors".
* Interpretation templates and assumption templates gain
  `biv_gaussian` rows (`inst/extdata/interpretation-templates.csv`
  and `inst/extdata/assumption-templates.csv`).
* New: `compare_symbolic(sym_a, sym_b, metrics = FALSE)` returns a
  structural diff between two `symbolized_model` objects. Slots:
  `meta` (left / right model summaries — class, family, response,
  n_obs), `diff_submodels` (presence per submodel: `left_only` /
  `right_only` / `both`), `diff_terms` (presence per (submodel,
  term_label) pair), and `diff_assumptions` (status on each side
  plus a `same_status` flag). S3 class `symbolic_comparison`;
  `print()` produces a structured cli block and `knit_print()`
  produces side-by-side markdown tables. Passing `metrics = TRUE`
  adds a fifth slot `diff_metrics` with AIC, BIC, log-likelihood,
  and df on each side plus their delta (right - left); the metrics
  block refuses to compute deltas when the two fits are obviously
  incomparable (different family, response, or n_obs) and instead
  carries a `comparable = FALSE` attribute plus a `note` explaining
  why. For fit-time identifiability and convergence diagnostics, run
  `drmTMB::check_drm()` (or the gllvmTMB analogue) per fit before
  interpreting the structural diff.

# symbolizer 0.1.1

## v0.1.1 — confidence bands, marginal estimates, and categorical pedagogy

### Inference

* `symbolize.drmTMB()` gains a `ci_method = "wald"` argument and populates
  five new columns on `fixed_effects` and `interpretation`: `std_error`,
  `confint_low`, `confint_high`, `excludes_zero`, `ci_method`. Existing
  callers see additive columns only. Confidence bands come from
  `stats::confint(fit, parm, method, level)` dispatched on `confint.drmTMB`;
  passing `ci_method = "profile"` is honest (asymmetric) but slow.
  Satterthwaite / Kenward-Roger corrections wait on drmTMB.
* `print(parameter_interpretation(sym))` shows the band as `(lo, hi)` with
  a trailing `*` marker on rows whose 95% interval excludes zero;
  `knit_print()` adds a `95% CI` column to the rendered table and a footer
  naming the CI method. Renderers consume `metadata$ci_method`.

### Marginal estimates (new)

* `group_means(sym, by = NULL)` — categorical marginal means via
  `emmeans::emmeans()`. By default returns one row per combination of
  factor levels in the model. Returns a tibble classed
  `symbolizer_group_means` with the same column shape as the
  interpretation rows (`estimate`, `std_error`, `confint_low`,
  `confint_high`, `excludes_zero`).
* `group_slopes(sym, continuous, at = NULL)` — per-group slopes for a
  continuous predictor via `emmeans::emtrends()`. Handles both
  cont × factor (one row per factor level) and cont × cont
  (`at = list(other_predictor = c(...))` returns one row per value).
* `model_card(sym)` extraction calls and bundle gain `marginal_means`
  and `marginal_slopes` slots so the teaching bundle includes the
  derived per-group views alongside the contrasts.
* Adds `emmeans` to Suggests.

### Categorical pedagogy

* Interaction interpretation templates (`gaussian/mu/interaction_*`) now
  end with the call hint that takes the reader to the derived per-group
  view: `group_slopes(sym, continuous = ...)` for cont × factor,
  `group_means(sym, by = c(...))` for factor × factor,
  `group_slopes(sym, continuous, at = list(...))` for cont × cont.
* Intercept-less fits (`y ~ 0 + factor`) now produce cell-means
  descriptions in `symbol_table`: factor rows say
  `"factor (level_a, level_b — cell-means parameterisation)"` instead
  of marking a reference level. The interpretation rows pick a new
  `cell_mean` role with prose like "Expected {response} for
  {variable} = {level}".
* `inst/extdata/interpretation-templates.csv` adds the
  `gaussian/mu/cell_mean` row.
* `vignettes/symbolizer-factors.Rmd` grows by +341 lines:
  a new Step 5 walking through a continuous × continuous interaction
  end to end, and a new "Common pitfalls" section presenting six
  pitfalls (intercept ≠ average; contrast ≠ group mean; interaction ≠
  effect of A on B; Wald CIs can be too narrow; dropping the intercept
  doesn't always do what you think; `poly(x, 2)` ≠ `I(x^2)`) in the
  Symptom / Diagnosis / WRONG-vs-RIGHT code / Rule format borrowed
  from the gllvmTMB pitfalls page.

### API consolidation

* `validate_symbolized_model()` is now `@keywords internal`, removed
  from the public NAMESPACE, and reachable as
  `symbolizer:::validate_symbolized_model()` for advanced users
  hand-building objects. Still listed under the pkgdown reference
  page's "Internal: object construction" section.

### Documentation

* Adds `VISION.md`: mission, audience priorities, ten core principles,
  what symbolizer is and is not, long-term direction.

## v0.1 surface (Stable)

* `symbolize.drmTMB()` builds a structured `symbolized_model` from a fitted
  `drmTMB` Gaussian location-scale model with fixed effects in both the mu
  and sigma submodels. Reads `fit$formula$entries`, `fit$family`,
  `fit$coefficients`, and `drmTMB::fixef()` per dpar.
* `extract_terms()` is the term-grammar / model-matrix bridge: every renderer
  consumes this layer and never re-parses formulas.
* Capability registry (`symbolizer_capabilities()`) gates `symbolize()` with
  the five-level status vocabulary borrowed from drmTMB.

## Dual notation (index ↔ matrix)

* Every component carries both index-form and matrix-form LaTeX, with
  lowercase bold for vectors (`\mathbf{w}`, `\boldsymbol{\beta}`) and
  uppercase bold for matrices (`\mathbf{X}`, `\mathbf{Z}`).
* Symbol dictionary carries two dimension columns: abstract (`\mathbb{R}^n`)
  and concrete (e.g. `\mathbb{R}^{80}`).
* `notation_bridge()` returns an educator-facing translation table that
  pairs each model piece across both notations with its dimension.

## Renderers

* `equations(sym, notation)` returns the per-row LaTeX in either or both forms.
* `as_latex(sym, notation, env)` returns a single string ready to splice into
  a LaTeX document; stacks both forms when `notation = "both"`.
* `symbol_table(sym, notation)`, `assumption_table(sym)`, `formula_bridge(sym, notation)`.
* `parameter_interpretation(sym, scale)` exposes per-coefficient readings on
  link / natural / variance / biological scales.

## Random intercepts (First slice)

* `(1 | group)` on the mu submodel is supported. The mu linear predictor
  gains a `+ u_{group(i)}` term (index) / `+ \mathbf{u}` (matrix), a new
  random-effect distribution row appears in `components`, and the new
  `random_effects` and `variance_components` tibbles register the term.
* Random slopes and random effects on the sigma submodel raise a clear
  capability error pointing at the registry.
