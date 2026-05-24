# Changelog

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
