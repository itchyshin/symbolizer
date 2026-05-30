# Roadmap and capability matrix

`symbolizer` is built first for two TMB sister packages — `drmTMB` and
`gllvmTMB` — and now reads across the GLMM ecosystem used in ecology and
evolution: `glmmTMB`, `brms`, `MCMCglmm`, `sdmTMB`, `lme4`,
[`stats::lm`](https://rdrr.io/r/stats/lm.html) /
[`stats::glm`](https://rdrr.io/r/stats/glm.html), `metafor`, `mgcv`, and
`phylolm`.

The **capability registry**
([`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md))
is the source of truth: any class / family / component not marked Stable
or First slice there will be refused by
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
with an informative message.

## Status vocabulary

| Status | Meaning |
|----|----|
| Stable | Battle-tested public surface; full prose + LaTeX + interpretation coverage. |
| First slice | Public surface works for the common case; some shapes still defer. |
| Opt-in control | Surface exists but the user must explicitly opt in. |
| Planned or reserved | The grammar may exist, but [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md) rejects it as design-only. |
| Unsupported or blocked | Do not use as analysis syntax; fit the nearest implemented model. |

## What’s covered today (v0.1 – v0.22.x)

### Model classes

| Package family | Classes | Families / shapes |
|----|----|----|
| **drmTMB** | `drmTMB` | Gaussian location-scale, bivariate Gaussian, Student-t, lognormal, Gamma, beta, beta_binomial, Poisson, nbinom2, truncated_nbinom2 (+ zero-inflation, hurdle, cumulative_logit) |
| **gllvmTMB** | `gllvmTMB` | Gaussian latent variable, binomial latent variable |
| **glmmTMB** | `glmmTMB` | Gaussian / binomial / poisson / nbinom2 conditional + `dispformula` + `ziformula` + (1\|g) |
| **brms** | `brmsfit` | Gaussian / binomial / poisson + `bf(sigma ~ z)` distributional + (1\|g) |
| **lme4** | `lmerMod`, `glmerMod` | lmer Gaussian + (1\|g)/(1+x\|g); glmer binomial / poisson + (1\|g) |
| **MCMCglmm** | `MCMCglmm` | Gaussian + ~g + **animal models via `ginverse`** (with derived heritability) |
| **sdmTMB** | `sdmTMB` | Gaussian + spatial random field (omega) + spatiotemporal field (epsilon) |
| **stats** | `lm`, `glm` | lm (Gaussian), glm (Gaussian / binomial / poisson / Gamma) |
| **metafor** | `rma.uni`, `rma.mv` | Random / mixed-effects meta-analysis + meta-regression + multilevel `~ 1 | study / id` + structured (phylogenetic) random effects via `R = list(...)` |
| **mgcv** | `gam`, `bam` | gaussian / poisson / binomial / Gamma + `s(x)` + `s(x, by =)` + `te(x, z)`; `gamm` / `gamm4` covered via the `$gam` slot |
| **phylolm** | `phylolm` | Phylogenetic Gaussian regression (PGLS); Brownian-motion / OU residual correlation via the `phylo` marker |

That’s 11 package families, 14 fitted-class methods, ~30 family-class
combinations with their own assumption / interpretation / methods-text
prose coverage. **Phylogenetic (`phylo` / structured-covariance) support
landed (First slice, v0.21)** across `drmTMB`, `metafor`, `brms`,
`MCMCglmm`, `glmmTMB`, and `gllvmTMB`, plus the standalone `phylolm`
PGLS extractor — see
[`vignette("symbolizer-structural-dependence")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-structural-dependence.md).

### Cross-cutting surfaces

| Surface | Status |
|----|----|
| [`as_latex()`](https://itchyshin.github.io/symbolizer/reference/as_latex.md) / [`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md) / [`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md) | Stable |
| [`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md) / [`formula_bridge()`](https://itchyshin.github.io/symbolizer/reference/formula_bridge.md) / [`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md) | Stable |
| [`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md) 95% confidence bands (Wald / profile / credible) | Stable |
| [`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md), [`group_slopes()`](https://itchyshin.github.io/symbolizer/reference/group_slopes.md) via `emmeans` (response- and link-scale) | First slice |
| [`compare_symbolic()`](https://itchyshin.github.io/symbolizer/reference/compare_symbolic.md) structural diff + optional AIC/BIC metrics | First slice |
| [`methods_text()`](https://itchyshin.github.io/symbolizer/reference/methods_text.md) draft Methods-section paragraph (template-based) | First slice |
| [`warning_table()`](https://itchyshin.github.io/symbolizer/reference/warning_table.md) per-fit prose warnings | First slice |
| [`model_card()`](https://itchyshin.github.io/symbolizer/reference/model_card.md) teaching bundle (equation + assumptions + readings + extraction calls) | First slice |
| [`as_dag()`](https://itchyshin.github.io/symbolizer/reference/as_dag.md) structural model diagram (nodes / edges + `$mermaid` and `$tikz` slots since v0.18) | First slice |
| [`simulate_recipe()`](https://itchyshin.github.io/symbolizer/reference/simulate_recipe.md) generative pseudocode + runnable R code for the fitted model | First slice (v0.18) |
| [`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md) interactive Equation / Index / Matrix-with-data widget | First slice |
| [`as_pdf_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_pdf_three_views.md) standalone PDF of the three-views widget | First slice |
| [`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md) first-call plain-English summary of a `symbolized_model` | First slice |
| [`notation_bridge()`](https://itchyshin.github.io/symbolizer/reference/notation_bridge.md) index ↔︎ matrix notation cross-reference | First slice |
| [`variance_partition()`](https://itchyshin.github.io/symbolizer/reference/variance_partition.md) / [`icc()`](https://itchyshin.github.io/symbolizer/reference/icc.md) variance decomposition + repeatability (ICC) | First slice |

## What’s planned

| Target | Theme |
|----|----|
| Near-term | brms negative-binomial + other distributional dpars (`nu ~ z`, `phi ~ z`); glmmTMB hurdle (`truncated_nbinom2 + ziformula`); MCMCglmm flexible covariance (`us(trait):unit`, `idh(trait):unit`); deeper publication-bias and I² / CV partitioning for `metafor`. |
| Considered | Remaining phylogenetic classes (`phyloglm`, `phyr::pglmm`, `sommer`) — the `phylolm` PGLS flagship and structured-covariance phylo bridges across the six classes above have **shipped**; [`nlme::lme`](https://rdrr.io/pkg/nlme/man/lme.html) standalone; `survival`; `ordinal::clm`; `geepack`; `marginaleffects` / `ggeffects` companion layer; `DHARMa` / `performance` / `gratia` integration as [`warning_table()`](https://itchyshin.github.io/symbolizer/reference/warning_table.md) sources. |

Items previously listed here that have **shipped** in the v0.13 – v0.22
window are now in the Release history table below. The kept-public
function surface stays tight: new model-class support arrives as S3
methods (invisible in `ls("package:symbolizer")`), not as new exported
helpers.

## Release history (selected)

| Version | Theme |
|----|----|
| v0.1 | drmTMB Gaussian location-scale + (1 \| group); gllvmTMB Gaussian latent variables; [`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md) / [`model_card()`](https://itchyshin.github.io/symbolizer/reference/model_card.md) / dual notation |
| v0.1.1 | Confidence bands via `drmTMB::confint`; `group_means` / `group_slopes` via emmeans |
| v0.2 | Bivariate Gaussian extractor; [`compare_symbolic()`](https://itchyshin.github.io/symbolizer/reference/compare_symbolic.md) structural diff |
| v0.2.1 | [`methods_text()`](https://itchyshin.github.io/symbolizer/reference/methods_text.md); [`warning_table()`](https://itchyshin.github.io/symbolizer/reference/warning_table.md) |
| v0.3 | Seven non-Gaussian drmTMB families; families-distributions CSV refactor |
| v0.4 | drmTMB zero-inflation / hurdle / cumulative_logit |
| v0.5 | gllvmTMB binomial (first non-Gaussian latent-variable family) |
| v0.6 | `as_dag(sym)` structural model diagram (DOT) |
| v0.7 | glmmTMB Gaussian + (1 \| g) + `dispformula` |
| v0.8 – v0.10 | brms, MCMCglmm, lme4, stats::lm / stats::glm Gaussian first slices |
| v0.11.x | Non-Gaussian glmmTMB / glmer / brms families; robustness sweep |
| v0.12 | sdmTMB spatial fields; MCMCglmm animal models |
| v0.13 | metafor `rma.uni` (research-synthesis flagship) |
| v0.14 | mgcv `gam` / `bam` (additive grammar) |
| v0.14.1 | metafor `rma.mv` (multilevel + structured / phylogenetic) |
| v0.15 | metafor `rma.uni` location-scale (`scale = ~ z`, `rma.ls`); `tau2_scale` capability row |
| v0.16 | metafor `rma.mv` `struct = "UN"` (bivariate / multivariate meta-analysis); glmmTMB `propto` covariance code → originally framed as meta-analysis bridge (**corrected in v0.20**: propto is the phylogenetic / structured-covariance pattern, not meta-analysis); “three faces of meta-analysis” article |
| v0.17 | “Building up” ladder vignette (`lm` → `lm + sex` → `lmer` + (1 \| site) → `drmTMB` location-scale on one shared dataset); homepage three-views widget screenshot |
| v0.18 | `simulate_recipe(sym)` (numbered pseudocode + family-aware runnable R); `as_dag(sym)$mermaid` and `$tikz` slots for diagram rendering |
| v0.18.1 | Audit pass: `@references` blocks on all 10 extractors; widget HTML render fix (de-indent `<button>` lines so pandoc stops wrapping them as code blocks); inline-R guards in vignettes |
| v0.18.2 | Tab-switching JavaScript fix in [`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md) (raw R string so `\"` escapes inside `querySelectorAll` survive into the browser) |
| v0.18.3 | First pipe-encoding fix in `formula_bridge` rendering; roadmap article rewritten to match shipped reality |
| v0.19 – v0.20 | Audit passes (Fisher / Emmy / Pat / Rose lenses); `propto` reframed as the phylogenetic / structured-covariance pattern (not a meta-analysis bridge); phylogenetic capability scaffold; R-output vs LaTeX parity fixes across articles |
| v0.21 | **Phylogenetic flagship**: [`vignette("symbolizer-structural-dependence")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-structural-dependence.md); `phylo` structured-covariance bridges across `drmTMB` / `metafor` / `brms` / `MCMCglmm` / `glmmTMB` / `gllvmTMB`; `phylolm` PGLS extractor; three-views widget rollout; standalone HTML + PDF export + Copy-LaTeX buttons |
| v0.22 | Meta-analysis bridges (`meta_known_vi`, `meta_phylo_multilevel`) + consolidated [`vignette("symbolizer-meta-analysis")`](https://itchyshin.github.io/symbolizer/articles/symbolizer-meta-analysis.md); [`variance_partition()`](https://itchyshin.github.io/symbolizer/reference/variance_partition.md) / [`icc()`](https://itchyshin.github.io/symbolizer/reference/icc.md) repeatability; mgcv poisson / binomial / Gamma smooths; family-aware Tab-3 worked rows |

See `NEWS.md` (Changelog tab) for the full per-release log.

## API discipline

The kept-public function surface stays **tight** on purpose. Adding S3
methods (`symbolize.rma.uni`, `symbolize.gam`, etc.) does not grow the
user-facing function list because methods are invisible in
`ls("package:symbolizer")`. New work that would add exported helpers is
rejected by default; instead, we extend existing functions with new
arguments and use articles to organise and explain.

Core public functions (the things users actually call):
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md),
[`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md),
[`as_latex()`](https://itchyshin.github.io/symbolizer/reference/as_latex.md),
[`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md),
[`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md),
[`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md),
[`formula_bridge()`](https://itchyshin.github.io/symbolizer/reference/formula_bridge.md),
[`notation_bridge()`](https://itchyshin.github.io/symbolizer/reference/notation_bridge.md),
[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md),
[`variance_partition()`](https://itchyshin.github.io/symbolizer/reference/variance_partition.md),
[`icc()`](https://itchyshin.github.io/symbolizer/reference/icc.md),
[`model_card()`](https://itchyshin.github.io/symbolizer/reference/model_card.md),
[`as_dag()`](https://itchyshin.github.io/symbolizer/reference/as_dag.md),
[`compare_symbolic()`](https://itchyshin.github.io/symbolizer/reference/compare_symbolic.md),
[`methods_text()`](https://itchyshin.github.io/symbolizer/reference/methods_text.md),
[`warning_table()`](https://itchyshin.github.io/symbolizer/reference/warning_table.md),
[`group_means()`](https://itchyshin.github.io/symbolizer/reference/group_means.md),
[`group_slopes()`](https://itchyshin.github.io/symbolizer/reference/group_slopes.md),
[`expand()`](https://itchyshin.github.io/symbolizer/reference/expand.md),
[`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md),
[`as_pdf_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_pdf_three_views.md),
[`simulate_recipe()`](https://itchyshin.github.io/symbolizer/reference/simulate_recipe.md),
[`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md).
