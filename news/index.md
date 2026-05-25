# Changelog

## symbolizer 0.18.1

### v0.18.1 – audit pass: doc + vignette consistency

A documentation-consistency sweep. Three exploration agents (vignette
audit, R/ documentation audit, top-level files audit) surfaced the
following inconsistencies, now fixed:

#### Vignette staleness

- `vignettes/symbolizer-gllvm.Rmd` no longer says “`symbolize.gllvmTMB`
  is a v0.4 First slice still being wired in” with
  [`tryCatch()`](https://rdrr.io/r/base/conditions.html) guards – the
  extractor has been live since v0.4-v0.5. Section 5 now invokes
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  directly. Section 9 (“What’s available now, what’s next”) rewritten to
  reflect current scope (Gaussian + binomial latent variable shipped;
  further families and bootstrap uncertainty still planned).
- `vignettes/symbolizer.Rmd` “Today (v0.15)
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  reads ten package families” -\>
  “[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  currently reads ten package families” (drop the stale version anchor).
- `vignettes/symbolizer-drmtmb.Rmd` line 482 “v0.1 surface does not plot
  live” rewritten as “`symbolizer` does not draw the plots itself” (the
  v0.1 reference is irrelevant by now).
- `vignettes/symbolizer-drmtmb.Rmd` section 10 “v0.1 ships … v0.2 added
  …” rewritten to describe the current drmTMB capability set.
- `vignettes/symbolizer-factors.Rmd` “v0.1 does not yet ship an
  interaction template” – removed; interaction templates have been in
  `interpretation-templates.csv` since v0.1.1.

#### R/ documentation

`@references` blocks added to every `symbolize.X` method that didn’t
already have one:

- `drmTMB` (Nakagawa; Kristensen et al. 2016 TMB)
- `gllvmTMB` (Nakagawa)
- `glmmTMB` (Brooks et al. 2017)
- `brmsfit` (Bürkner 2017)
- `lmerMod` / `glmerMod` (Bates et al. 2015)
- `MCMCglmm` (Hadfield 2010)
- `sdmTMB` (Anderson et al. 2022)
- `gam` / `bam` (Wood 2017; Wood 2011)
- `lm` (Chambers 1992)
- `glm` (McCullagh & Nelder 1989)

`@section Confidence intervals:` blocks added to `symbolize.gam` / `bam`
(Wald approximations on parametric coefs; smooths summarised separately)
and `symbolize.gllvmTMB` (Wald via sd_report). `symbolize.glm` gets an
explicit “profile likelihood” CI note.

#### Top-level files

- `README.Rmd` Positioning paragraph now mentions classical (base-R)
  regression explicitly, not just GLMM / meta-analysis / additive-model
  / Bayesian-multilevel.
- `NEWS.md` v0.15.0 “Still planned beyond this batch” – two items that
  shipped in v0.16.0 (Slices C + D) are now annotated as shipped.

#### Bug fix: three-views widget rendering in pkgdown / knitted vignettes

- [`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md)
  previously emitted the three tab `<button>` elements with 4-space
  cosmetic indentation. Pandoc’s markdown reader treats any line with 4+
  leading spaces as the start of an indented code block, so the buttons
  were silently re-emitted inside `<pre><code>...</code></pre>` with
  HTML-escaped angle brackets, causing the raw tags and stylesheet to
  leak into the rendered page (visible on the deployed pkgdown ladder
  vignette and any external re-render). The function now keeps all
  nested HTML at 0-2 spaces of indentation and carries a header comment
  warning against re-introducing 4+-space indents.
- `vignettes/symbolizer-ladder.Rmd` no longer wraps the call in
  `htmltools::tagList(as_html_three_views(sym4))`. `tagList()` treats
  the character return value as a text node and re-emits the same HTML
  escaped, on top of the rendered widget. The chunk now uses
  `invisible(as_html_three_views(sym4))` and a `results = "asis"`
  context, which lets the function’s internal
  [`cat()`](https://rdrr.io/r/base/cat.html) write raw HTML once. The
  “(opens in the Viewer pane)” caption was also wrong –
  [`cat()`](https://rdrr.io/r/base/cat.html) writes to the console, not
  to RStudio’s Viewer – and has been replaced with an accurate
  description of the [`cat()`](https://rdrr.io/r/base/cat.html) + `asis`
  pattern.

No other code changes. No behaviour changes for the other extractors.
`testthat::test_file("tests/testthat/test-three-views.R")` continues to
pass all 40 assertions (the de-indent only changes cosmetic whitespace,
which the test suite did not depend on).

## symbolizer 0.18.0

### v0.18 – Option B debt cleared: simulate_recipe() and diagram surfaces

Closes the long-standing Option B debt named in the master plan
(simulate_recipe + diagrams beyond as_dag).

- New exported function `simulate_recipe(sym, n = NULL, seed = NULL)`.
  Returns a `symbolizer_simulation_recipe` S3 object with two slots:
  - `$pseudocode` – numbered prose steps describing the generative model
    (draw random effects, build linear predictor, apply inverse link,
    sample response).
  - `$r_code` – runnable R code with the right RNG calls for the fitted
    family (rnorm / rbinom / rpois / rgamma / rnbinom for Gaussian /
    binomial / Poisson / Gamma / negative-binomial, and a two-tier draw
    for `meta_normal`). Family-aware via the symbolized_model’s
    `submodels` and `random_effects` tibbles; honours link functions and
    detects optional sigma / zi submodels.
- `as_dag(sym)` is enriched with two new slots (no new exports):
  - `$mermaid` – Mermaid-flowchart string suitable for pasting into
    Markdown / Quarto.
  - `$tikz` – TikZ string suitable for inclusion in a LaTeX document
    (requires `\\usepackage{tikz}` and the
    `positioning,shapes.geometric` libraries). The existing `$dot`
    (GraphViz) slot is unchanged.
- pkgdown reference page gains a “Simulation recipe” section listing
  `simulate_recipe`; the “Model diagram” section is rewritten to mention
  all three syntactic frames (DOT / Mermaid / TikZ).
- `as_dag` test updated to assert the five-slot shape.

## symbolizer 0.17.0

### v0.17 – ladder vignette and homepage refresh

This release replaces the abrupt “jump straight into a complex
location-scale model” on-ramp with a gentle 4-rung ladder, on one shared
synthetic dataset.

- New article `vignettes/symbolizer-ladder.Rmd` (“Building up: from `lm`
  to location-scale”). One synthetic
  `body_mass ~ temperature + sex + site` dataset, four rungs:
  1.  `lm(body_mass ~ temperature)`, (2) `+ sex`, (3) `lmer` with
      `(1 | site)`, (4) `drmTMB` location-scale with
      `sigma ~ temperature`. At each rung the same
      [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
      call produces a richer symbolic specification; “what just got
      added” callouts highlight the new line(s).
- The interactive
  [`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md)
  widget renders live at the end of the ladder (Rung 4) so the reader
  sees Equation / Index-expansion / Matrix-with-data tabs side by side.
- New homepage screenshot of the widget at
  `man/figures/three-views-widget.png` – the README’s “Three views of
  the same fit” section now shows the widget instead of just describing
  it.
- `_pkgdown.yml`: navbar Articles dropdown reorganised. “Get started” is
  now Ladder -\> Concepts (the existing `symbolizer.Rmd`); remaining
  articles moved into “Deep dives”.
- README “Tiny example” gets a callout pointing readers at the ladder
  for a gentler on-ramp.

Option B debt
([`simulate_recipe()`](https://itchyshin.github.io/symbolizer/reference/simulate_recipe.md),
`as_mermaid()`, `as_tikz()`, `render_model_notebook()`) stays deferred
to v0.18.

## symbolizer 0.16.0

### v0.16 – meta-analysis bridge complete

Three slices that together close the cross-package meta-analysis story:

#### Slice B – rma.mv `struct = "UN"` (bivariate / multivariate covariance)

[`symbolize.rma.mv()`](https://itchyshin.github.io/symbolizer/reference/symbolize.rma.mv.md)
now handles fits constructed with `~ inner | outer, struct = "UN"` – the
bivariate / multivariate meta-analysis pattern (e.g., two outcome
measures per trial). When detected:

- Per-inner-level diagonal variances appear in `variance_components`
  with `kind = "heterogeneity_un"` (one row per inner level).
- Off-diagonal correlations (from `fit$rho`) appear as rows with
  `kind = "correlation"`.
- LaTeX renders one `u_{level(i)}` random-effect symbol per inner level.

New capability row `rma.mv,meta_normal,struct_UN` (First slice).

#### Slice C – glmmTMB `propto()` (and future `equalto()`) detection

[`symbolize.glmmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.glmmTMB.md)
now detects the meta-analytic / phylogenetic / pedigree-controlled
pattern used in
`glmmTMB(y ~ 1 + (1 | study) + propto(0 + obs | g, V), ...)`. When the
conditional RE blocks include a `propto()` (covariance code 11) or
future `equalto()` term:

- `sym$metadata$meta_analysis_via_glmmTMB` is set to `TRUE`.
- [`warning_table()`](https://itchyshin.github.io/symbolizer/reference/warning_table.md)
  adds an info-level row pointing at the equivalent metafor
  `rma.mv(yi, V, random = ..., R = ...)` and drmTMB location-scale
  constructions, citing Williams (2023), Viechtbauer & Lopez-Lopez
  (2022), and Nakagawa et al. (2025).
- The propto / equalto block is stripped from the rhs before
  [`extract_terms()`](https://itchyshin.github.io/symbolizer/reference/extract_terms.md)
  runs (`glmm_strip_meta_calls()`), so the formula bridge and LaTeX
  render cleanly.

New capability rows: `glmmTMB,{gaussian,binomial,poisson},propto` (First
slice).

#### Slice D – “Three faces of meta-analysis” article

New vignette `vignettes/symbolizer-meta.Rmd`. Fits the same two-tier
meta-analytic model via
[`metafor::rma.mv`](https://wviechtb.github.io/metafor/reference/rma.mv.html),
`glmmTMB` with `propto()`, and `drmTMB` location-scale. Shows
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
output side by side, explains the variance ($`\tau^2`$, $`\alpha`$) vs
SD ($`\sigma`$, $`\gamma`$) parameterization gap with the
$`\alpha_k \approx 2 \gamma_k`$ relationship, and points to when each
package is the natural choice.

The article is reachable from a new pkgdown navbar group “Cross-package
bridges”.

#### Deferred to later

- Full prose re-routing for glmmTMB-as-meta-analysis (currently flagged
  via warning, but `family` stays Gaussian for prose templating) –
  v0.16.x
- Double-hierarchical location-scale via brms (Nakagawa Eq 19-22) –
  v0.17 candidate
- Publication-bias detection layer (Nakagawa Sec 2.5) – v0.17 candidate
- I^2 / CV heterogeneity partitioning – v0.17 candidate

## symbolizer 0.15.1

### v0.15.1 – positioning text refresh: not just drmTMB

Stale framing pass: the homepage positioning paragraph still described
`symbolizer` as “for drmTMB” even though the package now reads ten
package families. This release rewrites the user-facing prose so the
multi-package scope is visible from the homepage and Get-started
vignette.

- README `Positioning` paragraph rewritten: now describes `symbolizer`
  as making “a fitted model auditable” across “the GLMM, meta-analysis,
  additive-model, and Bayesian-multilevel packages an ecologist or
  evolutionary biologist actually uses”.
- README “Built first for…” paragraph: now reads “Currently reads ten
  package families” with the list spelt out, and a direct link to the
  Roadmap article.
- DESCRIPTION text: extended to name `drmTMB`, `gllvmTMB`, `glmmTMB`,
  `brms`, `lme4`, `MCMCglmm`, `sdmTMB`,
  [`stats::lm`](https://rdrr.io/r/stats/lm.html)/`glm`, `metafor`,
  `mgcv` explicitly.
- [`vignette("symbolizer")`](https://itchyshin.github.io/symbolizer/articles/symbolizer.md)
  “What’s supported, what’s planned”: no longer claims “v0.1 marks … as
  Stable”; reflects v0.15 reality and links to the Roadmap article.
- [`vignette("symbolizer-families")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-families.md):
  no longer says “Eight distribution families ship today”; clarifies
  that this vignette walks the drmTMB non-Gaussian families
  specifically, while the same `symbolize(fit)` interface applies to all
  ten package families.

No code changes. Test sweep + check unchanged.

## symbolizer 0.15.0

### v0.15 – location-scale meta-regression (rma.ls)

First slice of the cross-package meta-analysis bridge:
[`metafor::rma`](https://wviechtb.github.io/metafor/reference/rma.uni.html)
with `scale = ~ z` (the `rma.ls` location-scale model) is now recognised
by
[`symbolize.rma.uni()`](https://itchyshin.github.io/symbolizer/reference/symbolize.rma.uni.md).
A second submodel `tau2` is added with the variance-faithful
parameterisation:

log(tau^2_i) = alpha_0 + alpha_1 z\_{1i} + … + alpha_q z\_{qi}

This is **log of the variance**, not log of the SD – coefficients are
`alpha` (Greek alpha) and the natural-scale reading is “tau^2_i changes
multiplicatively by exp(alpha_k) per unit of z_k”. The distinction
matters because brms / glmmTMB / drmTMB parameterise the same structural
model via `log(sigma)` (the SD), with `gamma` coefficients, and the
relationship is alpha_k ~ 2 \* gamma_k.

- New `tau2` submodel in the symbolizer-wide registry:
  `drm_coef_family_for("tau2") = "alpha"`,
  `drm_link_for(..., "tau2") = "log"`,
  `drm_param_greek("tau2") = "\\tau^{2}"`.
- New capability row `rma.uni,meta_normal,tau2_scale` (First slice).
- New interpretation templates
  `meta_normal,tau2,{intercept,slope,factor_contrast}` that explicitly
  contrast variance vs SD parameterisations and cite Viechtbauer &
  Lopez-Lopez 2022 / Nakagawa et al. 2025.
- Alpha estimates pulled from `fit$alpha` with Wald CIs from
  `fit$ci.lb.alpha` / `fit$ci.ub.alpha`.
- For rma.ls, `variance_components` reports the mean tau^2_i with
  `kind = "heterogeneity_scale"`; the per-observation vector lives in
  `metadata$tau2`.
- Robustness sweep gains one row: rma.ls location-scale.

#### Still planned beyond this batch

Wider meta-analysis bridge items not in v0.15.0. **Update:** the first
two shipped in v0.16.0:

- ✅ glmmTMB `equalto()` / `propto()` detection – **shipped in v0.16.0**
  (Slice C).
- ✅ Cross-package “Three faces of meta-analysis” article – **shipped in
  v0.16.0** as
  [`vignette("symbolizer-meta")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-meta.md)
  (Slice D).
- Double-hierarchical location-scale via brms (Nakagawa et al. 2025 Eq
  19-22): random effects on the scale part with bivariate (u^(l), u^(s))
  distribution. Still planned.
- Publication-bias detection layer (Nakagawa et al. 2025 Section 2.5):
  small-study effect / decline effect / small-study divergence / Proteus
  effect, surfaced via
  [`warning_table()`](https://itchyshin.github.io/symbolizer/reference/warning_table.md).
  Still planned.
- I^2 / CV partitioning (Eq 14-16, 26-31): derived heterogeneity
  measures attached to `metadata$heterogeneity_partition`. Still
  planned.

The brms double-hierarchical / publication-bias / I^2 items are queued
for v0.19+.

## symbolizer 0.14.2

### v0.14.2 – Roadmap moved to its own page; README slimmed

The README homepage had grown to ~250 lines because the capability
matrix and roadmap tables sat alongside the introductory material. That
layout was hard to scan once the package crossed ten model classes.

- New article `vignettes/symbolizer-roadmap.Rmd` (“Roadmap and
  capability matrix”) – the canonical home for the status vocabulary,
  full capability matrix, planned releases, and release history. It’s
  reachable from a new top-level **Roadmap** entry in the pkgdown
  navbar.
- README slimmed: capability matrix and roadmap tables removed; in their
  place a single “At a glance” paragraph naming the 10 covered package
  families and linking to the Roadmap article. README is now ~170 lines.
- `_pkgdown.yml`: navbar gains a “Roadmap” link
  (`articles/symbolizer-roadmap.html`); the article is also listed under
  a new “Where we’re going” article group.
- NEWS continues to record past releases (no overlap with the Roadmap
  article, which is forward-looking).

No code changes; no behaviour changes. devtools::check() unchanged.

## symbolizer 0.14.1

### v0.14.1 – metafor rma.mv (multilevel + structured meta-analysis)

[`symbolize.rma.mv()`](https://itchyshin.github.io/symbolizer/reference/symbolize.rma.mv.md)
for
[`metafor::rma.mv`](https://wviechtb.github.io/metafor/reference/rma.mv.html)
fits. Covers the two patterns that dominate modern ecology / evolution /
education meta-analyses:

- **Multilevel meta-analysis** – multiple random-effect tiers via
  `random = list(~ 1 | study, ~ 1 | id)` or the nested syntax
  `random = ~ 1 | district / study`. Each tier gets a row in
  `variance_components` with `kind = "heterogeneity"`, and a
  `u_{tier(i)} \sim \mathcal{N}(0, \sigma^2_{tier})` line in the LaTeX.

- **Structured random effects (phylogenetic / pedigree / spatial)** –
  when `R = list(group = R_matrix)` is attached to the fit, the tier is
  tagged `kind = "structured"` and listed in
  `sym$metadata$structured_random` with the R-matrix dimension.

The fixed-effects extraction reuses the rma.uni infrastructure (intrcpt
row-name mapping + Wald CIs via `fit$ci.lb` / `fit$ci.ub`), so
meta-regression moderators work the same way for `rma.mv` as for
`rma.uni`. The two-tier sampling-distribution / linear-predictor
structure inherits from `family = meta_normal` so the assumption /
interpretation prose is shared with `rma.uni`.

Two new helper fits (`fit_metafor_rma_mv()`,
`fit_metafor_rma_mv_structured()`) and two new robustness-sweep rows.

Capability rows: `rma.mv,meta_normal,mu` and
`rma.mv,meta_normal,structured` (both First slice). `struct = "UN"` /
`"HCS"` / `"AR"` covariance structures and selection / publication-bias
variants remain Planned.

## symbolizer 0.14.0

### v0.14 – mgcv additive grammar (gam / bam / gamm / gamm4)

- [`symbolize.gam()`](https://itchyshin.github.io/symbolizer/reference/symbolize.gam.md)
  (and `symbolize.bam = symbolize.gam` since `bam` inherits from `gam`)
  for [`mgcv::gam`](https://rdrr.io/pkg/mgcv/man/gam.html) /
  [`mgcv::bam`](https://rdrr.io/pkg/mgcv/man/bam.html) fits. First slice
  covers gaussian / poisson / binomial / Gamma families with smooth
  specifications `s(x)`, `s(x, by = factor)`, and `te(x, z)`.
  Method-of-fit (REML / GCV.Cp) is captured as metadata.
- Smooth terms are summarised in `sym$metadata$smooths` – one row per
  smooth with `label`, `bs_dim` (basis dimension K), `edf` (effective
  degrees of freedom), p-value, underlying `variable`(s), and `by_var`
  (for `s(x, by = group)`).
- LaTeX rendering appends a smooth term `f_l(x_i)` (or `f_l(x_i, z_i)`
  for tensor products) to the linear predictor for each smooth, so the
  additive structure
  `g(mu_i) = beta_0 + sum beta_k x_ki + sum_l f_l(z_li)` is visible.
- Smoothing parameters lambda_l appear in `variance_components` with
  `kind = "smoothing_param"`; the residual SD (for Gaussian) appears
  with `kind = "residual"`.
- [`mgcv::gamm()`](https://rdrr.io/pkg/mgcv/man/gamm.html) and
  [`gamm4::gamm4()`](https://rdrr.io/pkg/gamm4/man/gamm4.html) return
  lists with a `$gam` slot of class `gam`. Document the pattern
  `symbolize(fit_gamm$gam)`; both are covered by the test sweep.
- Warning surface: when a smooth’s `edf` approaches its basis dimension
  `K`, the extractor flags it with the same suggestion
  [`mgcv::gam.check()`](https://rdrr.io/pkg/mgcv/man/gam.check.html)
  makes – “consider increasing k”.
- mgcv + gamm4 added to `Suggests`.
- Two new robustness-sweep rows: gam with `s(x)`, gam with `te(x, z)`.

## symbolizer 0.13.0

### v0.13 – metafor (research-synthesis flagship)

This release adds the meta-analytic grammar – a distinct two-tier
structure with sampling variance, true effects, and between-study
heterogeneity that’s substantively different from the GLMMs the package
has covered until now.

#### New extractor

- [`symbolize.rma.uni()`](https://itchyshin.github.io/symbolizer/reference/symbolize.rma.uni.md)
  for
  [`metafor::rma.uni`](https://wviechtb.github.io/metafor/reference/rma.uni.html)
  fits. Covers random and mixed-effects meta-regression with the model:

      y_i | theta_i ~ N(theta_i, v_i)             (sampling level, v_i known)
      theta_i = beta_0 + sum beta_k x_ki + u_i    (true-effect level)
      u_i ~ N(0, tau^2)                            (heterogeneity)
      w_i = 1 / (v_i + tau^2)                      (inverse-variance weight)

- Sampling variances `v_i` are treated as KNOWN (inputs, not
  parameters). `tau^2` shows up in `variance_components` with
  `kind = "heterogeneity"`; mean sampling variance is reported with
  `kind = "sampling_variance"` for reader reference.

- New family `meta_normal` in `family-distributions.csv` /
  `family-parameterizations.csv`. 9 new rows in
  `assumption-templates.csv` covering known sampling variance, the
  linear predictor for true effects, between-study heterogeneity,
  inverse-variance weights, publication-bias responsibility, correct
  effect-metric responsibility, and conditional independence. 3 new
  interpretation rows for intercept / slope / factor-contrast on the
  meta-analytic scale.

- metafor’s `intrcpt` row name (vs. R’s usual `(Intercept)`) is handled
  in the hit-name mapper.

- `rma.mv` (multilevel / multivariate meta-analysis) remains Planned.

#### Robustness

- `test-robustness-sweep.R` gains two rows: random-effects meta-
  analysis (no moderators) + meta-regression (with moderator).

## symbolizer 0.12.0

### v0.12 – close the original-vision gaps: sdmTMB + MCMCglmm animal models

This release closes the two remaining gaps from the May 23 master
roadmap. sdmTMB lands as a first-class extractor; MCMCglmm gains an
animal-model branch with derived heritability.

#### sdmTMB (new)

- [`symbolize.sdmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.sdmTMB.md)
  – first slice covers Gaussian fits with an optional spatial random
  field (`spatial = "on"`) and / or spatiotemporal field
  (`time = "..."`). Fixed-effect estimates and Wald CIs come from
  `sdmTMB::tidy(fit)`; spatial-range and field-SD parameters come from
  `sdmTMB::tidy(fit, "ran_pars")` and appear in the
  `variance_components` tibble with `kind = "spatial_random"` /
  `spatial_range`.
- Capability rows: `sdmTMB,gaussian,mu` / `omega` / `epsilon` all First
  slice; non-Gaussian families, delta-models, and `spatial_varying`
  slopes still Planned.
- `sdmTMB` added to `Suggests`.

#### MCMCglmm animal models (extension)

- [`symbolize.MCMCglmm()`](https://itchyshin.github.io/symbolizer/reference/symbolize.MCMCglmm.md)
  now detects `fit$ginverse` and treats those groups as animal-model /
  phylogenetic effects. The `variance_components` tibble gains a `kind`
  column (`animal` / `random` / `residual`), and a heritability tibble
  `h^2 = sigma^2_A / (sigma^2_A + sigma^2_E)` is derived and attached to
  `sym$metadata$heritability` whenever both an animal effect and a
  residual variance are present.
- Capability row: `MCMCglmm,gaussian,animal` First slice. The flexible
  residual covariance structures (`us(trait):unit`, `idh(trait):unit`)
  remain Planned – multi-response fixtures and matrix-rendering grammar
  are coming with the metafor v0.13 batch.

#### Robustness sweep

- `test-robustness-sweep.R` gains two new rows: MCMCglmm animal + sdmTMB
  spatial. The full public renderer surface (`as_latex`, `equations`,
  `symbol_table`, `assumption_table`, `formula_bridge`,
  `parameter_interpretation`, `as_dag`, `warning_table`) is exercised on
  each.

#### Roadmap text refresh

- README capability matrix and roadmap table rewritten to reflect v0.7
  -\> v0.12 as released, with metafor / mgcv / emmeans-depth listed as
  Planned for v0.13 / v0.14 / v0.15. Capabilities CSV’s stale “Targeted
  for v0.X” notes updated.

## symbolizer 0.11.2

### v0.11.2 – more brms families + interaction robustness

- [`symbolize.brmsfit()`](https://itchyshin.github.io/symbolizer/reference/symbolize.brmsfit.md)
  now handles `family = bernoulli()` and `family = poisson()`. brms’s
  `bernoulli()` is aliased to `binomial` internally because
  mathematically Bernoulli is just Binomial(1, p); the same templates
  and parameterization apply.
- New `tests/testthat/test-robustness-interactions.R` fits `y ~ x * sex`
  (continuous-by-factor interaction) in each family / class combination
  and verifies the interaction row appears in `fixed_effects` with
  sensible estimate, CI columns are populated, and LaTeX renders. Covers
  lm gaussian, glm binomial / poisson / Gamma, glmmTMB poisson /
  binomial, lmer with random intercept, and drmTMB gaussian.

## symbolizer 0.11.1

### v0.11.1 – two more deferred items

- [`symbolize.brmsfit()`](https://itchyshin.github.io/symbolizer/reference/symbolize.brmsfit.md)
  now handles `bf(y ~ x, sigma ~ z)` distributional fits. The sigma
  submodel shows up alongside mu with its own credible band; LaTeX
  renders both lines with the correct log link on sigma. brms’s other
  distributional dpars (`nu`, `phi`, etc.) are still routed to the
  “Planned or reserved” status word.
- [`symbolize.glmmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.glmmTMB.md)
  now handles `ziformula = ~ x` for poisson and nbinom2 fits. The
  zero-inflation submodel shows up alongside mu with its logit link in
  the LaTeX. Behaviour matches `drmTMB`’s zi / hu handling so the same
  fit through either package produces the same teachable story.
- Hardened: `brms::VarCorr(fit)` errors on fixed-effects-only fits; the
  extractor now catches that and treats it as “no random effects” rather
  than crashing.

## symbolizer 0.11.0

### v0.11 – deferred items: non-Gaussian glmmTMB / glmer, glm Gamma, robustness

This release picks up the items deferred during the v0.7 -\> v0.10 push
and adds a robustness sweep so any future extractor regression surfaces
in one place.

#### New family coverage

- glmmTMB binomial / poisson / nbinom2 (with `(1 | g)` random
  intercepts) – the family check was the only thing blocking these; the
  CSV-driven prose layer already had templates from earlier releases.
  Reusing the same extractor code path means the LaTeX, assumption
  table, parameter readings, and methods text all line up across drmTMB
  and glmmTMB for the same family.
- [`symbolize.glmerMod()`](https://itchyshin.github.io/symbolizer/reference/symbolize.glmerMod.md)
  for lme4 generalised mixed models. First slice covers binomial /
  poisson with their canonical links.
- glm Gamma (`stats::Gamma(link = "log")`) is now First slice via the
  same CSV plumbing that drmTMB Gamma uses.

#### Robustness

- New `tests/testthat/test-robustness-sweep.R` runs every `symbolize.*`
  method through every public renderer (`as_latex`, `equations`,
  `symbol_table`, `assumption_table`, `formula_bridge`,
  `parameter_interpretation`, `as_dag`, `warning_table`). 13 model
  classes / family combinations, ~120 expectations. Any new extractor
  must keep this sweep green.

#### Still deferred (v0.11.x and later)

- sdmTMB (not installed in the dev environment).
- brms distributional formulas (`sigma ~ z`) and non-Gaussian brms
  families.
- MCMCglmm flexible covariance structures (animal models,
  multi-membership, per-trait residuals).
- glmmTMB zero-inflation submodels (`ziformula`).
- glm inverse.gaussian / quasi-families.

## symbolizer 0.10.0

### v0.10 – base R + lme4

- New:
  [`symbolize.lm()`](https://itchyshin.github.io/symbolizer/reference/symbolize.lm.md)
  for base R [`lm()`](https://rdrr.io/r/stats/lm.html) fits (Gaussian +
  identity link only – the only family
  [`lm()`](https://rdrr.io/r/stats/lm.html) fits). Wald-t confidence
  intervals from [`confint()`](https://rdrr.io/r/stats/confint.html).
- New:
  [`symbolize.glm()`](https://itchyshin.github.io/symbolizer/reference/symbolize.glm.md)
  for base R [`glm()`](https://rdrr.io/r/stats/glm.html) fits. First
  slice covers Gaussian / binomial / poisson with their canonical links.
  Wald CIs via
  [`confint.default()`](https://rdrr.io/r/stats/confint.html) (the
  default [`confint()`](https://rdrr.io/r/stats/confint.html) for glm
  uses profile likelihood which is slow on big fits; the extractor opts
  into the faster Wald path).
- New:
  [`symbolize.lmerMod()`](https://itchyshin.github.io/symbolizer/reference/symbolize.lmerMod.md)
  for [`lme4::lmer()`](https://rdrr.io/pkg/lme4/man/lmer.html) fits
  (Gaussian conditional submodel with optional `(1 | g)` random
  intercepts). CIs via
  `lme4::confint.merMod(fit, parm = "beta_", method = "Wald")`. Pass
  `ci_method = "profile"` for profile-likelihood CIs.
- methods_text() templates added for lm / glm / lmerMod.
- `glm` family classes for binomial / poisson are family-keyed in the
  capability registry; Gamma / inverse.gaussian / quasi families are
  deferred to v0.10.x.
- sdmTMB is deferred to v0.10.x (not installed in the dev environment;
  needs separate testing on a machine with sdmTMB available).

## symbolizer 0.9.0

### v0.9 – MCMCglmm

- New:
  [`symbolize.MCMCglmm()`](https://itchyshin.github.io/symbolizer/reference/symbolize.MCMCglmm.md)
  (first slice). Builds a `symbolized_model` from an `MCMCglmm` fit for
  the Gaussian conditional submodel (identity link) with optional `~ g`
  random intercepts.
- MCMCglmm does NOT keep the data frame on the fitted object, so
  `symbolize.MCMCglmm(fit, data = ...)` takes a mandatory `data`
  argument. The function errors with a friendly message if `data` is
  omitted.
- CI band uses the 95% credible interval from `summary(fit)$solutions`
  (l-95% CI / u-95% CI, the highest-posterior-density bounds).
  `ci_method = "credible"`.
- methods_text() template for `MCMCglmm / gaussian` mentions Gibbs
  sampling with inverse-Wishart priors on the variance components.
- MCMCglmm’s flexible covariance structures (per-trait residuals,
  multi-membership, animal models) are routed through the capability
  registry as “Planned or reserved” for v0.9.x.

## symbolizer 0.8.0

### v0.8 – brms

- New:
  [`symbolize.brmsfit()`](https://itchyshin.github.io/symbolizer/reference/symbolize.brmsfit.md)
  (first slice). Builds a `symbolized_model` from a `brmsfit` for the
  Gaussian conditional submodel (identity link) with optional `(1 | g)`
  random intercepts.
- Bayesian-aware CI band: instead of frequentist Wald / profile, the
  extractor uses the posterior 2.5% / 97.5% quantiles from
  `brms::fixef(fit)` as the credible interval. `ci_method` is set to
  `"credible"` so downstream renderers can label the band correctly.
- [`methods_text()`](https://itchyshin.github.io/symbolizer/reference/methods_text.md)
  template for `brmsfit / gaussian` mentions Hamiltonian Monte Carlo via
  Stan, weakly-informative default priors, and credible (not confidence)
  intervals.
- brms’s distributional-parameter formulas (`sigma ~ z`, etc.) and
  non-Gaussian families are routed through the capability registry as
  “Planned or reserved” for v0.8.x.

## symbolizer 0.7.1

### v0.7 audit pass

- `vignettes/symbolizer-families.Rmd` rendered seven distribution lines
  as raw LaTeX text instead of math. The chunks now use a small
  `render_math()` helper (defined in the vignette’s setup chunk) that
  wraps the LaTeX string in `$$...$$` via
  [`knitr::asis_output()`](https://rdrr.io/pkg/knitr/man/asis_output.html),
  so KaTeX / MathJax / pandoc pick it up and render proper display math.
- [`methods_text()`](https://itchyshin.github.io/symbolizer/reference/methods_text.md)
  now has a template for `glmmTMB / gaussian`. Previously the function
  errored “no template” on every glmmTMB fit; the new template covers
  both the bare conditional submodel and the `dispformula = ~ z` case
  (the residual-SD sentence is conditional).
- The “no template” error message now lists supported `class / family`
  combinations from the CSV itself, so it can’t drift out of sync with
  reality the way it had (it was still naming three combos when 13
  existed).
- `README.Rmd` capability matrix and roadmap updated to reflect v0.4 (zi
  / hu / cumulative_logit), v0.5 (gllvmTMB binomial), v0.6
  ([`as_dag()`](https://itchyshin.github.io/symbolizer/reference/as_dag.md)),
  and v0.7 (glmmTMB) — previously they stopped at v0.3.

## symbolizer 0.7.0

### v0.7 — glmmTMB

- New:
  [`symbolize.glmmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.glmmTMB.md)
  (first slice). Builds a `symbolized_model` from a `glmmTMB` fit for
  the Gaussian conditional submodel (identity link), with optional
  `(1 | g)` random intercepts and an optional `dispformula = ~ z`
  distributional sigma submodel. Non-Gaussian families and
  zero-inflation are routed through the capability registry as “Planned
  or reserved” for now.
- The new extractor reuses the prose layer (assumption / interpretation
  / symbol-dictionary / formula-bridge builders) by producing the same
  tibble shapes as
  [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md).
  Family-keyed CSVs in `inst/extdata/` drive prose, so a Gaussian
  glmmTMB fit produces the same teachable readings as the drmTMB
  equivalent.
- Confidence intervals come from
  `glmmTMB::confint(fit, parm = "beta_", method = ci_method)`. Default
  `ci_method = "wald"`; `"profile"` and `"uniroot"` available.

### Fixes

- `parameter_interpretation(sym, scale = ...)` now carries the
  confidence-band columns (`std_error`, `confint_low`, `confint_high`,
  `excludes_zero`, `ci_method`) on every scale, not just
  `scale = "all"`. Previously these were dropped when the user picked a
  specific scale, so the rendered Markdown / pkgdown table omitted the
  CI band even though the underlying interpretation tibble had it.

## symbolizer 0.6.0

### v0.6 — model diagrams

- New: `as_dag(sym)` returns a structural DAG of the fitted model with
  three slots: `nodes` (tibble — response, parameters, predictors,
  groups, random effects), `edges` (tibble — predictor→parameter edges,
  parameter→response distribution edges, group→random-effect edges,
  random-effect→parameter contributions), and `dot` (a single GraphViz /
  DOT-language string).
- The S3 class is `symbolic_dag`.
  [`print()`](https://rdrr.io/r/base/print.html) summarises the node and
  edge counts and emits the DOT string with a copy/paste pointer to
  GraphvizOnline; `knit_print()` wraps the DOT inside a fenced `dot`
  code block so Quarto / Markdown engines that support DOT rendering
  pick it up automatically.
- Nodes are styled by kind:
  - response → double circle, salmon fill
  - parameter (μ, σ, ν, …) → ellipse, cream fill
  - predictor → box, green fill
  - group variable → house shape, lavender fill
  - random effect → circle, orange fill Edges are styled by
    relationship: distribution edges are bold red; linear-predictor
    edges are solid; group / random-contribution edges are dashed.
- No new hard dependencies. To render the DAG live: paste the `$dot`
  string into <https://dreampuf.github.io/GraphvizOnline/>, or pass it
  to `DiagrammeR::grViz()` (DiagrammeR is not a symbolizer dependency).

## symbolizer 0.5.0

### v0.5 — gllvmTMB binomial (first non-Gaussian latent-variable family)

- [`symbolize.gllvmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.gllvmTMB.md)
  now reads binomial latent-variable models end-to-end. The conditional
  distribution renders as
  `y_{ij} | mu_{t(j)}, Lambda_B, z_{B,i} ~ Bernoulli(logit^{-1}(mu_{t(j)} + (Lambda_B z_{B,i})_{t(j)}))`,
  trait intercepts read as logit baseline success probabilities
  (e.g. “plogis(mu_t)”), and loadings on `Lambda_B` are noted as living
  on the logit scale (an odds-ratio per unit of `z`).
- `glm_build_distribution()` and the assumption / interpretation
  template lookups are now family-aware: each gllvm family slug
  (`gllvm_gaussian`, `gllvm_binomial`, …) selects its own rows. Added
  `gllvm_template_family()` helper that maps an upstream family name to
  the slug.
- The sigma_eps capability check now fires only for Gaussian gllvm fits.
  drmTMB’s binomial / Poisson / etc. carry a placeholder
  `fit$report$sigma_eps` that previously triggered a spurious capability
  error.
- Capability rows flipped to First slice for `gllvmTMB / binomial / mu`,
  `Lambda_B`, `Sigma_B`, `Psi_B`.

The other gllvm families (Poisson, nbinom2, Gamma, lognormal, ordinal,
…) stay Planned or reserved. The pattern is now straightforward: add a
CSV slug, mirror the gllvm_gaussian rows with family-appropriate
wording, and add a branch in `glm_build_distribution()`.

## symbolizer 0.4.0

### v0.4 — ordinal + zero-inflation + hurdle

- `cumulative_logit` — ordered categorical response, proportional-odds
  model. The conditional distribution renders as
  `P(Y_i ≤ k | X_i) = logit⁻¹(θ_k − X_i'β)` with K−1 thresholds
  replacing the intercept. The mu linear predictor is rendered without
  an intercept term (drmTMB suppresses it; symbolizer matches). Three
  new assumption rows (`proportional_odds`,
  `ordered_categorical_response`, `thresholds_ordered`) make the PO
  assumption explicit and stay-honest about who’s responsible.
- `zi` (zero-inflation) submodel layered on Poisson and nbinom2.
  Rendered as an additional `zi_linear_predictor` component with
  `logit(π_zi,i) = α₀ + ...`, with interpretation rows reading the α
  coefficients as log-odds of being a structural zero. The
  conditional-distribution assumption row spells out the mixture
  `P(Y=0) = π_zi + (1−π_zi)·f(0|μ,...)`.
- `hu` (hurdle) submodel layered on truncated_nbinom2. Same shape as zi
  but with δ coefficients, and the assumption row reads as a two-part
  mixture (`P(Y=0) = π_hu; P(Y=k | Y>0) = NegBin⁺(k; μ, exp(σ))`).
- `drm_param_index_form()` now handles non-digit subscripts cleanly:
  `π_{zi}` becomes `π_{zi, i}` rather than the malformed `π_{zi}_i`.
  This was a latent bug that only surfaced once the zi/hu submodels
  started using subscripted Greek symbols.

### v0.3.2 — two more families, families-tour vignette, README refresh

- Two more non-Gaussian families ship via the CSV-only path:
  - **beta_binomial**
    ([`drmTMB::beta_binomial()`](https://itchyshin.github.io/drmTMB/reference/beta_binomial.html))
    — overdispersed binomial counts. Response specified as
    `cbind(successes, failures)`; mean success probability via the logit
    link, precision (inverse-overdispersion) via the log link.
    Coefficients on mu read as odds ratios; the methods_text paragraph
    names the trial count requirement.
  - **truncated_nbinom2**
    ([`drmTMB::truncated_nbinom2()`](https://itchyshin.github.io/drmTMB/reference/truncated_nbinom2.html))
    — zero-truncated counts. The distribution latex flags the truncation
    via `\mathrm{NegBin}^{+}` and the support `y in {1, 2, 3, ...}`. The
    methods_text and assumption rows are explicit that mu is the mean of
    the *underlying untruncated* distribution; the observed mean is
    larger.
- `methods_text` univariate-family list grows to include both new
  families so the response / sigma / RE substitutions fire without
  `[unfilled: ...]` markers.
- New vignette `symbolizer-families` — a tour of the seven non- Gaussian
  families currently shipping. One small fit and one key surface per
  family (distribution latex, biological reading on mu, or methods_text
  excerpt), plus six rules of thumb for picking a family. Bivariate
  Gaussian is cross-referenced rather than repeated since it has its own
  section in the drmTMB tour.

## symbolizer 0.3.1

### v0.3.1 — random slopes, response-scale group_means, bigger hex

- Random slopes now work:
  [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  reads `(1 + x | group)` random-effect terms on the mu submodel
  end-to-end. The mu linear predictor renders the contribution as
  `+ u_{0, group(i)} + u_{1, group(i)} * x_i` (index form) and
  `+ Z_group u_group` (matrix form). The joint MVN distribution of the
  random components is rendered, plus a covariance-decomposition row
  that spells out the 2x2 (or k x k) Sigma_u in terms of the
  per-component SDs and the within-group correlation rho.
- The data shape is extended (forward-compatibly): `random_effects`
  gains `component`, `component_index`, and `predictor_factor` columns;
  `variance_components` gains `component`; a new top-level slot
  `covariance_components` carries the within-group correlations for
  multi-component groups. The intercept-only case (`(1 | group)`) keeps
  the historic simpler symbols and an empty `covariance_components`
  slot, so existing code that assumed the old shape still works.
- Capability row `drmTMB / gaussian / random_effects` updated to reflect
  the broader scope; nested / crossed / RE-on-sigma remain Planned or
  reserved.
- The friendly capability gate now distinguishes two unsupported shapes:
  RE on submodels other than mu, and slope-only RE without an intercept
  (each gets its own error message).
- [`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
  and
  [`group_slopes()`](https://itchyshin.github.io/symbolizer/reference/group_slopes.md)
  gain a `scale` argument (`"response"` (default) or `"link"`) and
  return a new `scale` column. Before this release, both functions
  returned emmeans output on the *link* scale for non-identity-link
  families — a Poisson “group mean” was reported as the log of the count
  rate, a Beta mean was reported as a log-odds, a Gamma mean as a log of
  the response, and so on. That was easy to misread as the
  response-scale value. The default is now `"response"`: the
  back-transformed mean (count rate for Poisson, proportion for Beta,
  response-scale mean for Gamma, geometric mean for lognormal,
  response-scale mean for nbinom2, mean for Gaussian and Student-t).
  Pass `scale = "link"` to get the linear-predictor scale used by the
  coefficient table.
- For `lognormal` fits drmTMB exposes mu on the identity link (because
  mu represents `log(Y)`), so emmeans’s automatic back-transform doesn’t
  fire.
  [`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
  now tells emmeans about the implicit log transformation via
  `stats::update(emm, tran = "log")` so the response-scale output is the
  geometric mean with delta-method CI.
- `print.symbolizer_group_means()` and `print.symbolizer_group_slopes()`
  name the scale in their footer (“Scale: response. CI method: wald.”).

## symbolizer 0.3.0

### v0.3 — non-Gaussian drmTMB families, polished methods_text

- [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  reads four more non-Gaussian families end-to-end via the CSV-driven
  path:

  - **Gamma** (`stats::Gamma(link = "log")`) — positive continuous,
    multiplicative mean reading on the response scale.
  - **Beta**
    ([`drmTMB::beta()`](https://itchyshin.github.io/drmTMB/reference/beta.html))
    — Y in (0, 1) with logit-link mean and log-link precision; mean
    coefficients render as odds ratios.
  - **Poisson**
    ([`stats::poisson()`](https://rdrr.io/r/stats/family.html)) — counts
    with no dispersion parameter; mean coefficients render as rate
    ratios. The `variance = mean` constraint is called out in both the
    assumption table and the methods_text paragraph.
  - **nbinom2**
    ([`drmTMB::nbinom2()`](https://itchyshin.github.io/drmTMB/reference/nbinom2.html))
    — counts with overdispersion; the size parameter (`exp(sigma_i)`)
    controls the Poisson limit. Each family ships its own assumption
    rows, interpretation rows (per coefficient role on every relevant
    scale), and methods_text template — no shortcuts, because the
    biology of each family genuinely differs.

- Capability registry rows flipped to `First slice` for
  `drmTMB / Gamma / mu, sigma` (note the capital G — base R’s
  [`stats::Gamma()`](https://rdrr.io/r/stats/family.html) uses that
  string), `drmTMB / beta / mu, sigma`, `drmTMB / poisson / mu`, and
  `drmTMB / nbinom2 / mu, sigma`.

- `methods_text(sym)` on biv_gaussian fits now reads cleanly when the
  three secondary submodels (sigma1, sigma2, rho12) are intercept-only.
  The old output included an awkward parenthesised
  `(an intercept only; an intercept only)` clause; the polished version
  uses dedicated `sigma_pair_clause` and `rho12_clause` slots that pick
  one of three readable phrasings (both intercept-only, mixed, or both
  with predictors). Templates for univariate families are unaffected;
  this is biv_gaussian-specific because the three-clause shape is
  genuinely unique to it.

- [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  reads Student-t fits (`family = drmTMB::student()`) end-to-end. The
  Student-t adds a `nu` (degrees-of-freedom) submodel alongside `mu` and
  `sigma`; drmTMB parameterises `nu` on the `log(nu - 2)` scale (the
  `logm2` link) so that `nu > 2` is always enforced and the modelled
  variance `nu / (nu - 2) * sigma^2` is finite. The structured symbolic
  object carries:

  - a Student-t distribution row in both index and matrix forms,
  - submodels for `mu` (identity), `sigma` (log), `nu` (logm2),
  - interpretation rows for the three submodels including a biological
    reading on `nu` that explains heavier vs lighter tails,
  - an assumption row `positivity_and_finite_variance` capturing the
    `nu > 2` constraint,
  - a
    [`methods_text()`](https://itchyshin.github.io/symbolizer/reference/methods_text.md)
    template covering the three submodels and the log(nu - 2) link
    explanation.

- Capability registry rows flipped from “Planned or reserved” to “First
  slice”:

  - `drmTMB / student / mu`
  - `drmTMB / student / sigma`
  - `drmTMB / student / nu`

- `drm_link_for()` now generalises the multi-dpar link lookup. The
  previous biv_gaussian-only branch was extended to recognise any family
  whose links are exposed as a named vector (Student-t today; future
  families can land without further changes here).

- [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  reads lognormal fits (`family = drmTMB::lognormal()`) end-to-end. The
  conditional distribution row reads
  `Y_i | mu_i, sigma_i ~ Lognormal(mu_i, sigma_i^2) <=> log(Y_i) | mu_i, sigma_i ~ Normal(mu_i, sigma_i^2)`,
  spelling out the equivalence so the reader sees both views.
  Interpretation rows on mu speak in terms of the geometric mean of the
  response — a unit change in a predictor multiplies the geometric mean
  by `exp(beta)`.

- **Architectural refactor: distribution LaTeX is now CSV-driven.**
  `inst/extdata/family-distributions.csv` carries the conditional-
  distribution row (index + matrix form) for every family. The previous
  hardcoded family branches in `drm_build_distribution()` and
  `drm_build_components()` are gone. Adding a future univariate family
  (gamma, beta, Poisson, nbinom2, Tweedie, …) is now a CSV-only
  operation. Structural-shape families (biv_gaussian, future GLLVM
  extensions, ordinal models) still need code because their
  components-list shape differs.

## symbolizer 0.2.1

### v0.2.1 — methods_text, per-fit warnings, biv_gaussian gate

- New: `warning_table(sym)` returns the tibble of conditions that
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  flagged when building the model object. Each row is one warning with a
  `code`, `severity` (`info` / `warn` / `error`), templated `message`,
  and a `context` string. Prose is templated from
  `inst/extdata/warning-templates.csv`. Today the system ships one
  active check: `few_groups_wald` (warn) — Wald 95% CI used with a
  random-effect group of fewer than ~10 levels. The check is suppressed
  when the user passes `ci_method = "profile"` to
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md).
  `model_card(sym)` surfaces the warnings table when it’s non-empty; the
  field also lives on `sym$warnings_registry` for raw access.
- New: `methods_text(sym)` returns a draft Methods-section paragraph for
  a fitted model — the kind of paragraph a biologist would otherwise
  write by hand into a paper. The prose is composed from a CSV template
  (`inst/extdata/methods-templates.csv`) using slots filled from the
  `symbolized_model`. No LLM is involved at runtime; every phrase traces
  to a template row plus the substituted slots. Returns a
  `symbolizer_methods_text` S3 object with three slots: `text` (the
  assembled paragraph), `slots` (the named substitutions), and
  `reminders` (editorial reminders for the author). Templates ship for
  `drmTMB / gaussian`, `drmTMB / biv_gaussian`, and
  `gllvmTMB / gaussian`. Treat the output as a draft; the print method
  appends a reminder to that effect.
- [`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md)
  and
  [`group_slopes()`](https://itchyshin.github.io/symbolizer/reference/group_slopes.md)
  now gate `biv_gaussian` fits at the symbolizer layer with a friendly
  explanation, instead of letting drmTMB’s emmeans preflight surface a
  less explanatory error. A marginal mean in a bivariate fit is a joint
  2-vector prediction `(mu1, mu2)`, not a scalar, so the emmeans
  abstraction does not apply. The gate’s message points at
  [`drmTMB::predict_parameters()`](https://itchyshin.github.io/drmTMB/reference/predict_parameters.html)
  and at the fit-each-response-as- univariate alternative. Documented in
  the roxygen for both functions.

## symbolizer 0.2.0

### v0.2 — bivariate Gaussian, structural comparison, article tidy

- [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  reads bivariate Gaussian fits — the `biv_gaussian(y2 ~ ...)` family
  from drmTMB — through the same structured surface used for univariate
  fits. The response becomes a 2-vector `(Y_{1i}, Y_{2i})`, the
  conditional distribution becomes `MVN_2((mu_{1i}, mu_{2i}), Sigma_i)`,
  and the symbolic story now carries five submodels (`mu1`, `mu2`,
  `sigma1`, `sigma2`, `rho12`).
- New capability rows:
  `drmTMB,biv_gaussian,{mu1,mu2,sigma1,sigma2,rho12}` flip from “Planned
  or reserved” to “First slice”.
- Per-submodel response handling: `interpretation` rows for `mu1` /
  `sigma1` substitute `response_1`; `mu2` / `sigma2` substitute
  `response_2`; `rho12` rows reference both.
- `formula_bridge` carries one row per submodel including the new `mu1`,
  `mu2`, `sigma1`, `sigma2`, `rho12` parts; the `rho12` meaning reads as
  “Fisher-z residual correlation between {response_1} and {response_2}
  is a linear function of the correlation-model predictors”.
- Interpretation templates and assumption templates gain `biv_gaussian`
  rows (`inst/extdata/interpretation-templates.csv` and
  `inst/extdata/assumption-templates.csv`).
- New: `compare_symbolic(sym_a, sym_b, metrics = FALSE)` returns a
  structural diff between two `symbolized_model` objects. Slots: `meta`
  (left / right model summaries — class, family, response, n_obs),
  `diff_submodels` (presence per submodel: `left_only` / `right_only` /
  `both`), `diff_terms` (presence per (submodel, term_label) pair), and
  `diff_assumptions` (status on each side plus a `same_status` flag). S3
  class `symbolic_comparison`;
  [`print()`](https://rdrr.io/r/base/print.html) produces a structured
  cli block and `knit_print()` produces side-by-side markdown tables.
  Passing `metrics = TRUE` adds a fifth slot `diff_metrics` with AIC,
  BIC, log-likelihood, and df on each side plus their delta (right -
  left); the metrics block refuses to compute deltas when the two fits
  are obviously incomparable (different family, response, or n_obs) and
  instead carries a `comparable = FALSE` attribute plus a `note`
  explaining why. For fit-time identifiability and convergence
  diagnostics, run
  [`drmTMB::check_drm()`](https://itchyshin.github.io/drmTMB/reference/check_drm.html)
  (or the gllvmTMB analogue) per fit before interpreting the structural
  diff.

## symbolizer 0.1.1

### v0.1.1 — confidence bands, marginal estimates, and categorical pedagogy

#### Inference

- [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  gains a `ci_method = "wald"` argument and populates five new columns
  on `fixed_effects` and `interpretation`: `std_error`, `confint_low`,
  `confint_high`, `excludes_zero`, `ci_method`. Existing callers see
  additive columns only. Confidence bands come from
  `stats::confint(fit, parm, method, level)` dispatched on
  `confint.drmTMB`; passing `ci_method = "profile"` is honest
  (asymmetric) but slow. Satterthwaite / Kenward-Roger corrections wait
  on drmTMB.
- `print(parameter_interpretation(sym))` shows the band as `(lo, hi)`
  with a trailing `*` marker on rows whose 95% interval excludes zero;
  `knit_print()` adds a `95% CI` column to the rendered table and a
  footer naming the CI method. Renderers consume `metadata$ci_method`.

#### Marginal estimates (new)

- `group_means(sym, by = NULL)` — categorical marginal means via
  [`emmeans::emmeans()`](https://rvlenth.github.io/emmeans/reference/emmeans.html).
  By default returns one row per combination of factor levels in the
  model. Returns a tibble classed `symbolizer_group_means` with the same
  column shape as the interpretation rows (`estimate`, `std_error`,
  `confint_low`, `confint_high`, `excludes_zero`).
- `group_slopes(sym, continuous, at = NULL)` — per-group slopes for a
  continuous predictor via
  [`emmeans::emtrends()`](https://rvlenth.github.io/emmeans/reference/emtrends.html).
  Handles both cont × factor (one row per factor level) and cont × cont
  (`at = list(other_predictor = c(...))` returns one row per value).
- `model_card(sym)` extraction calls and bundle gain `marginal_means`
  and `marginal_slopes` slots so the teaching bundle includes the
  derived per-group views alongside the contrasts.
- Adds `emmeans` to Suggests.

#### Categorical pedagogy

- Interaction interpretation templates (`gaussian/mu/interaction_*`) now
  end with the call hint that takes the reader to the derived per-group
  view: `group_slopes(sym, continuous = ...)` for cont × factor,
  `group_means(sym, by = c(...))` for factor × factor,
  `group_slopes(sym, continuous, at = list(...))` for cont × cont.
- Intercept-less fits (`y ~ 0 + factor`) now produce cell-means
  descriptions in `symbol_table`: factor rows say
  `"factor (level_a, level_b — cell-means parameterisation)"` instead of
  marking a reference level. The interpretation rows pick a new
  `cell_mean` role with prose like “Expected {response} for {variable} =
  {level}”.
- `inst/extdata/interpretation-templates.csv` adds the
  `gaussian/mu/cell_mean` row.
- `vignettes/symbolizer-factors.Rmd` grows by +341 lines: a new Step 5
  walking through a continuous × continuous interaction end to end, and
  a new “Common pitfalls” section presenting six pitfalls (intercept ≠
  average; contrast ≠ group mean; interaction ≠ effect of A on B; Wald
  CIs can be too narrow; dropping the intercept doesn’t always do what
  you think; `poly(x, 2)` ≠ `I(x^2)`) in the Symptom / Diagnosis /
  WRONG-vs-RIGHT code / Rule format borrowed from the gllvmTMB pitfalls
  page.

#### API consolidation

- [`validate_symbolized_model()`](https://itchyshin.github.io/symbolizer/reference/validate_symbolized_model.md)
  is now `@keywords internal`, removed from the public NAMESPACE, and
  reachable as `symbolizer:::validate_symbolized_model()` for advanced
  users hand-building objects. Still listed under the pkgdown reference
  page’s “Internal: object construction” section.

#### Documentation

- Adds `VISION.md`: mission, audience priorities, ten core principles,
  what symbolizer is and is not, long-term direction.

### v0.1 surface (Stable)

- [`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
  builds a structured `symbolized_model` from a fitted `drmTMB` Gaussian
  location-scale model with fixed effects in both the mu and sigma
  submodels. Reads `fit$formula$entries`, `fit$family`,
  `fit$coefficients`, and
  [`drmTMB::fixef()`](https://itchyshin.github.io/drmTMB/reference/fixef.html)
  per dpar.
- [`extract_terms()`](https://itchyshin.github.io/symbolizer/reference/extract_terms.md)
  is the term-grammar / model-matrix bridge: every renderer consumes
  this layer and never re-parses formulas.
- Capability registry
  ([`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md))
  gates
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  with the five-level status vocabulary borrowed from drmTMB.

### Dual notation (index ↔︎ matrix)

- Every component carries both index-form and matrix-form LaTeX, with
  lowercase bold for vectors (`\mathbf{w}`, `\boldsymbol{\beta}`) and
  uppercase bold for matrices (`\mathbf{X}`, `\mathbf{Z}`).
- Symbol dictionary carries two dimension columns: abstract
  (`\mathbb{R}^n`) and concrete (e.g. `\mathbb{R}^{80}`).
- [`notation_bridge()`](https://itchyshin.github.io/symbolizer/reference/notation_bridge.md)
  returns an educator-facing translation table that pairs each model
  piece across both notations with its dimension.

### Renderers

- `equations(sym, notation)` returns the per-row LaTeX in either or both
  forms.
- `as_latex(sym, notation, env)` returns a single string ready to splice
  into a LaTeX document; stacks both forms when `notation = "both"`.
- `symbol_table(sym, notation)`, `assumption_table(sym)`,
  `formula_bridge(sym, notation)`.
- `parameter_interpretation(sym, scale)` exposes per-coefficient
  readings on link / natural / variance / biological scales.

### Random intercepts (First slice)

- `(1 | group)` on the mu submodel is supported. The mu linear predictor
  gains a `+ u_{group(i)}` term (index) / `+ \mathbf{u}` (matrix), a new
  random-effect distribution row appears in `components`, and the new
  `random_effects` and `variance_components` tibbles register the term.
- Random slopes and random effects on the sigma submodel raise a clear
  capability error pointing at the registry.
