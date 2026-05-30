# Meta-vignette consolidation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline) — authorial vignette work + an iterative fit; not subagent-suited. Steps use `- [ ]` tracking.

**Goal:** Consolidate the two meta-analysis vignettes into one completed article (base = `symbolizer-meta-analysis.Rmd`; retire `symbolizer-meta.Rmd`), with §5/§6 finished and no placeholders.

**Architecture:** Edit one vignette + `_pkgdown.yml`; the only code risk is a real drmTMB location-scale fit (Task 1 de-risks it first, with a simulated-data + upstream-report fallback). Prose/equations follow the existing article's style; widgets via `as_html_three_views()`.

**Tech stack:** R Markdown vignette, drmTMB (location-scale), glmmTMB (light Face), symbolizer renderers, pkgdown.

Spec: `docs/dev-log/designs/2026-05-30-meta-consolidation.md`.

---

### Task 1: De-risk the §5 location-scale fit (GATING)

**Files:** Create scratch `/tmp/meta_locscale_probe.R` (not committed).

- [ ] **Step 1** — Write a probe that loads the thermal subset and fits the drmTMB location-scale meta model:

```r
suppressMessages(library(drmTMB)); library(symbolizer)
dat  <- read.csv(system.file("extdata","thermal_subset.csv", package="symbolizer"))
bf <- drmTMB::drm_formula
fit <- try(drmTMB::drmTMB(
  bf(dARR ~ 1 + habitat,
     sigma ~ 1 + habitat + offset(0.5 * log(Var_dARR))),
  family = stats::gaussian(), data = dat), silent = TRUE)
cat("class:", class(fit)[1], "\n")
if (!inherits(fit,"try-error")) {
  sd <- fit$sdreport %||% fit$report
  cat("pdHess:", isTRUE(fit$sdreport$pdHess), " any NaN SE:",
      any(is.na(sqrt(diag(fit$sdreport$cov.fixed)))), "\n")
  print(symbolize(fit, context="location-scale meta-analysis")$submodels)
}
```

- [ ] **Step 2** — Run `R -q -f /tmp/meta_locscale_probe.R`. **Decision gate:**
  - **Converges** (`pdHess TRUE`, finite SEs, sensible σ-submodel): record the exact fit call + key numbers → §5 uses the real thermal fit. Proceed to Task 2.
  - **Does NOT converge**: switch §5 to a small **simulated** location-scale dataset (labelled illustrative), AND draft `docs/dev-log/reports/2026-05-30-drmTMB-locscale-meta-convergence.md` with the minimal repro for the drmTMB team. Then proceed (§5 uses simulated data + a visible note).

---

### Task 2: Retire `symbolizer-meta.Rmd` + de-list it

**Files:** Delete `vignettes/symbolizer-meta.Rmd`; modify `_pkgdown.yml`.

- [ ] **Step 1** — `git rm vignettes/symbolizer-meta.Rmd`
- [ ] **Step 2** — In `_pkgdown.yml`, remove the `- symbolizer-meta` line from the "Cross-package bridges" group (leave `symbolizer-structural-dependence` + `symbolizer-meta-analysis`).
- [ ] **Step 3** — Scan for dangling references: `grep -rn "symbolizer-meta\b\|three faces" vignettes/ README.Rmd R/ inst/` (the `\b` avoids matching `symbolizer-meta-analysis`). Fix any link/text that pointed at the retired article.
- [ ] **Step 4** — Commit: `git commit -m "docs(meta): retire symbolizer-meta.Rmd (superseded by symbolizer-meta-analysis)"`

---

### Task 3: Complete §5 — location-scale meta-analysis

**Files:** Modify `vignettes/symbolizer-meta-analysis.Rmd` (replace the §5 scaffold, lines ~426-443).

- [ ] **Step 1** — Replace the §5 scaffold prose + the "*(Scaffold; lands in v0.22.2.)*" line with: (a) the intro equations (keep the existing $\log\tau(x_k)=\gamma_0+\gamma_1 x_k$ block), (b) a **real fit chunk** (from Task 1's verified call), (c) `symbolize()` + an `as_html_three_views(..., id="locscale-meta")` widget chunk (`results='asis', echo=FALSE`), (d) the **glmmTMB light Face** (`dispformula = ~habitat, weights = 1/Var_dARR`).
- [ ] **Step 2** — Add the **α≈2γ parameterization-gap table** (salvaged from the retired `symbolizer-meta.Rmd`):

```
| Package | Quantity modelled | Link | Coefficient |
| --- | --- | --- | --- |
| `metafor::rma(scale = ~ z)` | $\tau^2$ (variance) | $\log(\tau^2_i) = \alpha_0 + \alpha_1 z_i$ | $\alpha$ |
| `glmmTMB(dispformula = ~ z)` | $\sigma$ (SD) | $\log(\sigma_i) = \gamma_0 + \gamma_1 z_i$ | $\gamma$ |
| `drmTMB(sigma ~ z)` | $\sigma$ (SD) | $\log(\sigma_i) = \gamma_0 + \gamma_1 z_i$ | $\gamma$ |
```
plus the one-paragraph explanation that $\alpha_k \approx 2\gamma_k$ (variance scale vs SD scale; $\log\tau^2 = 2\log\tau + \text{const}$).

- [ ] **Step 3** — Add the **honest offset caveat** (one short paragraph): `offset(0.5*log(vi))` makes $\sigma_i \propto \sqrt{v_i}$ (proportional, not exactly equal) unless $\gamma_0$ is constrained to 0; the proportionality constant captures over/under-dispersion beyond the known sampling variance.
- [ ] **Step 4** — Run the article's chunks interactively (`rmarkdown::render` on just this vignette, or knit) to confirm §5 executes and the widget builds. Commit.

---

### Task 4: Write §6 — reading biologically

**Files:** Modify `vignettes/symbolizer-meta-analysis.Rmd` (replace the §6 scaffold, lines ~445-459).

- [ ] **Step 1** — Replace the "*(Will land in v0.22.3 …)*" scaffold with three written readings, grounded in the fitted numbers already in the article:
  - **τ² vs v_k**: τ² is real among-study disagreement; v_k is sampling imprecision (use the §3 BCG numbers: τ̂²≈0.31, I²≈92%).
  - **Phylogenetic σ_p²A + H²**: use §4's result (study-tier dominates; H² = σ_p²/(σ_p²+σ_study²)).
  - **Moderator-driven τ²(x)**: γ from §5 read on the log-SD scale; exp(γ) is the multiplicative change in heterogeneity SD per moderator level.
- [ ] **Step 2** — Commit.

---

### Task 5: Salvage the propto note as a one-liner

**Files:** Modify `vignettes/symbolizer-meta-analysis.Rmd` (§3.3 glmmTMB Face).

- [ ] **Step 1** — Add one sentence after the §3.3 glmmTMB Face: "Note: `glmmTMB::propto(…, V)` is **not** a meta-analytic surface — it estimates a free scalar on a *known* covariance, the phylogenetic/structured-covariance pattern; see `vignette('symbolizer-structural-dependence')`." (The meta bridge here is `weights = 1/vi` + `dispformula = ~0`, already shown.)
- [ ] **Step 2** — Commit.

---

### Task 6: Render + verify (no placeholders, both widgets, suite green)

- [ ] **Step 1** — `R -q -e 'devtools::load_all(quiet=TRUE); rmarkdown::render("vignettes/symbolizer-meta-analysis.Rmd", quiet=TRUE)'` → confirm it renders without error.
- [ ] **Step 2** — Placeholder scan: `grep -nE "lands in v0\.22|Scaffold|Will land|TODO" vignettes/symbolizer-meta-analysis.Rmd` → **expect zero matches**.
- [ ] **Step 3** — `pkgdown::build_article("symbolizer-meta-analysis")`; confirm both widgets present + MathJax-typeset: `grep -c "sym-tabs" docs/articles/symbolizer-meta-analysis.html` → expect 2; `grep -c "mathjax" …` → ≥1.
- [ ] **Step 4** — `R -q -e 'devtools::test()'` → FAIL 0 (no test references symbolizer-meta).
- [ ] **Step 5** — Final commit + update `_pkgdown.yml` group desc if needed.

---

## Self-review

- **Spec coverage:** base/retire (T2) ✓; §5 fit+table+caveat+glmmTMB+widget (T3) ✓; §6 readings (T4) ✓; propto one-liner (T5) ✓; _pkgdown.yml (T2) ✓; no placeholders (T6.2) ✓; fit fallback+report (T1) ✓; render+widgets+suite (T6) ✓. No gaps.
- **Placeholders:** the α≈2γ table + caveat + readings are spelled out; the only deferred content is the *fit numbers* (resolved in T1 at execution). OK.
- **Consistency:** widget id `locscale-meta` (T3) distinct from §4's `phylo-multilevel`; `Var_dARR` used throughout (matches §4).
