# Page-audit reconciliation — 2026-05-30 (all 11 surviving articles)

Multi-agent fan-out, one read-only auditor per article (4 lenses: rendering / math /
reader-flow / consistency), reconciled here. Source: the per-article `.md` files in
this directory.

## Headline

- **2 clean:** `variance-components` (0/0/0), `families` (0/0/2 — only minor symbol-collision + a takeaway-coverage gap).
- **Totals:** ~3 blockers, ~23 majors, ~26 minors across 11 articles.
- **The capability MATH is validated:** families' family-aware worked rows are all correct (no additive ε for non-Gaussian, Beta precision labelled right, lognormal back-transform); structural-dependence renders the phylo `σ²A` (brms + phylolm fixes confirmed working, no false iid). The defects are overwhelmingly **rendering + stale-prose + a few real numeric** issues, NOT wrong capability math.
- **Big finding:** ~23 majors collapse into **7 cross-cutting root causes** — fixing each once clears defects on multiple pages.

## Cross-cutting root patterns (fix once → clears many)

**P1 — Tab-3 "matrix-with-data" scaffold garbled by MathJax.** `R/render-three-views.R`'s
fallback message uses bare `$` (`expanded$X`, `expanded$beta`, `expanded$mu_hat`,
"see issue #9"); site-wide MathJax (Pattern L) parses the `$…$` as math → garbled text.
Hits any fit whose extractor doesn't populate `expand()$X` (glm, glmmTMB, lme4, mgcv).
→ meta-analysis §5 **[BLOCKER]**, get-started **[MAJOR]**. Fix: escape/rephrase the
scaffold (no bare `$`); ideally populate `expand()` for glm/glmmTMB so the tab renders.

**P2 — phantom σ-submodel rows on Gaussian fits.** `drm_build_assumptions` emits
`log(σ_i)=γ_0+…` + `σ_i>0 via log link` rows even when the fit has no dispersion
submodel. → structural-dependence (brms gaussian) **[MAJOR]**; same family as the
phylolm rows (box 4 fixed) and mgcv (box 5). Fix: gate those rows on a *real* sigma
submodel.

**P3 — backslash-pipe `\|` / `&#124;` leaks in table code cells.** Markdown pipe-escape
rendered literally in "R syntax" cells. → drmtmb **[MAJOR]** (`(1 \&#124; site)`),
roadmap **[MAJOR]** (`(1 \| g)` ×3), gllvm **[MINOR]**. Fix: the cell emitter that
escapes `|` (one helper).

**P4 — stale claim/code drift (under-claiming shipped features).** Prose predates the
features. → roadmap **[BLOCKER]** (navbar 0.22.3 vs H2 "v0.1–v0.18.x"; release table
stops at v0.18.3; phylo flagship/gam smooths/meta bridges/gllvm within-unit all
missing) + **[MAJOR]** flagship "Considered" + **[MAJOR]** core-functions table drops
`variance_partition`/`icc`/`as_pdf_three_views`/`explain`/`notation_bridge`; drmtmb
**[MAJOR]** "all non-Gaussian Planned" (false); factors **[MAJOR]×2** "interaction
layer on roadmap / rows silent" (templates clearly landed). Fix: a stale-claims sweep
against `capabilities.csv` + the rendered tables.

**P5 — Tab-3 worked row folds the RE/latent into the residual + caption claims `û`.**
Generic worked-row renderer shows only `Xβ̂+ε̂`, drops the random/latent column, but the
caption says `Xβ̂+û=μ̂`. → structural-dependence **[MAJOR]×2**, gllvm (note),
meta-analysis (related). Fix: renderer shows the RE/latent column or the caption stops
claiming it.

**P6 — unescaped `_` in user var names + YAML title markdown.** `body_mass` → italic
*body* subscript *mass*; backticks literal in `<title>`/`<h1>`. → ladder **[MAJOR]×2**,
gllvm **[MINOR]** (double-subscript `y_{ij}_{1}`, orphan `^{5 }`). Fix: escape `_` in
symbol rendering; drop backticks from YAML titles.

**P7 — interaction templated-reading vs prose (factors-specific but template-rooted).**
factors **[MAJOR]×2**: prose says interaction rows are "silent"/manual but the table
emits full templated readings; and the `sex` main-effect template reading ("Average …
differs by 3.04") is wrong in the presence of an interaction (it's the difference at
`body_size=0`). Fix: update factors prose to match shipped templates; fix the
factor_contrast template wording when an interaction is present.

## Article-specific numeric issues (not pattern; need real fixes)

- **meta-analysis §4** drmTMB phylo Face is **degenerate** (variance 0/0/100%, BLUPs
  ~1e-11) — contradicts §4/§6 prose + the §4.5 metafor numbers. **[MAJOR]** (ties to
  the drmTMB convergence issue, drmTMB#417).
- **meta-analysis §3.3** glmmTMB τ²=0.444 vs metafor 0.313 (42% gap) vs "reproduces the
  math" claim **[MAJOR]**; **§3.4** drmTMB σ² prints blank **[MAJOR]**.
- **meta-analysis §5.4** my own false claim "drmTMB recovers the same coefficients"
  (γ −1.16 vs −0.84) **[MINOR-MAJOR]**.
- **compare** AIC-delta sign explainer contradicts the +46.54 shown **[MAJOR]**; the `*`
  marker prose points at a console-only feature absent from `knit_print` **[MAJOR]**.
- **gllvm** Tab-3 implied-cov shows the raw loading matrix (5×2) not the 5×5 outer
  product; §6 "arithmetic closes" false; §9 Ψ_B prose names the wrong trait **[MAJOR]×3**.

## Recommended fix order (by leverage)

1. **P1** (render-three-views `$` scaffold) — 1 file, clears a BLOCKER + a front-door MAJOR + latent across widgets.
2. **P3** (pipe-escape helper) — 1 file, clears 2 MAJORs + minors.
3. **P4** (stale-claims sweep, esp. roadmap) — clears a BLOCKER + several MAJORs; mostly prose.
4. **P2** (phantom σ rows) — 1 builder, clears a MAJOR + composes with box 4/5.
5. **factors blocker** (the `r round(...)` inline-R leak) — 1 line.
6. **meta-analysis numeric** (§4 degenerate / §3.3 gap / §3.4 blank / §5.4 claim) — needs re-fitting decisions; the heaviest.
7. **P5, P6, P7 + gllvm/compare specifics** — rendering + prose polish.

Per-article detail in the sibling `.md` files. Two agents (get-started, gllvm) hit a
529 on finalize; get-started was audited inline (this dir's `symbolizer.md`); gllvm wrote
its file before failing.

## Fixes applied — 2026-05-30 (capability-remediation, unpushed)

Fixed the unambiguous / single-right-answer / testable subset; full suite green
(FAIL 0 | PASS 2204 → 2209). Commits: `fix(render)` P1+P3, `fix(factors)`,
`docs(roadmap,drmtmb,ladder)` P4+P6a, `fix(brms)` P2, `docs(compare)`.

- **All 3 blockers cleared**: meta §5 Tab-3 garble (P1), factors Step-1 inline-R leak, roadmap version drift (P4).
- **P3** pipe leaks → HTML `<code>` tables (+ regression test). **P2** phantom σ rows on brms gaussian. **P4** roadmap rewrite + drmtmb/factors stale-claim sweep. **P6a** ladder title. **compare** AIC-sign + `*`-marker.
- Verified: roadmap/factors/compare render clean, 0 pipe leaks; brms gaussian has no σ rows.

**Meta-analysis numerics — now FIXED** (root-caused against the real fits;
commit `fix(meta)`): §3.4 blank σ² (wrong accessor → `sigma(fit)[1]^2` = 0.25);
§3.3 τ² gap relabelled honestly (0.444 vs 0.313 is the 1-effect-per-study knife
edge, not a REML/ML flip); §4 reordered to lead with the converging
`metafor::rma.mv` (real tiers 0.003/0.036; widget no longer degenerate) and
demote the non-converging drmTMB `meta_V()+phylo()` combo to a caveated idiom
(#417); §5.4 "same coefficients" replaced with honest magnitudes (drmTMB γ −1.16
vs glmmTMB −0.84); plus 2 newly-found §3.5 pipe leaks. Verified by full re-render.

**P6b underscore-escaping — now FIXED** (commits `fix(render)` P6b-1 + P6b-2):
a shared `default_response_symbol()` escapes `_` + wraps multi-letter names
upright in `\mathrm{}_i`; all 8 response resolvers + the predictor
`lookup_symbol()` delegate to it (Pattern G). Verified: ladder rungs 1–3 +
factors render `\mathrm{body\_mass}_i` / `\mathrm{body\_size}_i`, zero raw
underscore-in-math; suite green; only extract-terms snapshots churned
(escaping-only, accepted).

**Phantom-σ sweep — FIXED for lm / glm / lmer / glmmTMB** (commit
`fix(assumptions)`): the `constant_scale` guard drops the phantom
location-scale σ rows on homoscedastic Gaussian fits (base + lme4
unconditional; glmmTMB gated on `has_sigma_sub` so a real dispformula keeps
them). Verified (test-phantom-sigma.R; suite 2224; no churn). brms already
done in P2.

**Math-rendering migration to KaTeX + KaTeX-surfaced fixes — FIXED**
(commits `build(pkgdown)` KaTeX switch `0cb1462`, then `fix(render)` double-
subscript + `study_ID`):
- **`\boldsymbol` rendered as red raw text site-wide** (maintainer-flagged):
  MathJax's combined CDN bundle (`tex-mml-chtml`) cannot autoload the
  `[tex]/boldsymbol` extension, and pkgdown writes its math config *after* the
  script tag, so bold-Greek vectors broke on every page. Fix: switch
  `_pkgdown.yml` `math-rendering: mathjax → katex` (KaTeX bundles
  `\boldsymbol` + stretchy delimiters and renders at load). Full site rebuilt.
- **KaTeX is stricter than MathJax and surfaced 2 latent LaTeX bugs** the old
  renderer had masked, both now fixed in `R/render-three-views.R`:
  - **gllvm double subscript** (4 errors): the multi-trait response `y_{ij}`
    took a second bare subscript (`y_{ij}_{1}` worked row; `y_{ij}_{600×1}`
    matrix-block dimension) → "Double subscript". New `subscriptable_base()`
    wraps an already-subscripted base in a group so the index is a single
    subscript (`{y_{ij}}_{1}`). Closes the P6 gllvm `y_{ij}_{1}` minor.
  - **meta `study_ID` group name** (1 error): the snake_case group went raw
    into `\text{study_ID tier}` (illegal `_` in KaTeX text mode → "Expected
    'EOF', got '_'") and `\mathbf{Z}_{study_ID}`. Fix routes the group name
    through `escape_underscores_for_latex()` in the implied-covariance block.
- Verified by a **site-wide KaTeX-error sweep** (hidden-iframe, counts
  `.katex-error` per page): **0 errors across all 11 articles** (get-started
  29, ladder 99, drmtmb 161, factors 240, families 120, variance-components 3,
  gllvm 156, compare 1, structural-dependence 187, meta-analysis 192, roadmap
  0). gllvm 4→0, meta 1→0; the other 9 stay clean. Regression test:
  `test-double-subscript.R`. Full suite green (the lone `expand` failure is the
  known `Matrix::expand` S4-masking load-order flake #7 — passes in isolation).

**Remaining — feature / deep-extractor work (recommend fresh sessions, each a
small design+implement cycle; none are one-line fixes):**
- **P5** worked-row folds the random effect into the residual on the
  structural-dependence drmTMB **phylo** fit — root cause is that drmTMB
  consumes `phylo()` into its sparse-precision pipeline, so `expand()$Z_g/u`
  is unpopulated and `has_re` is false. Needs `symbolize.drmTMB` to expose the
  phylo tier in `expand()` (the caption logic already shows `+ Zû` when it can).
- **P7** factor_contrast reading is wrong under an interaction (it's the
  difference at the interacting var = 0, not the average) — needs the
  interpretation builder to detect the interaction and switch templates.
- **gllvm Λ** Tab-3 renders the raw 5×2 loading, not the 5×5 outer product —
  needs a design call on rendering `ΛΛᵀ`.
- **P1 feature-half** family-aware `$expanded` for base lm/glm so the
  get-started Poisson widget's Tab 3 renders numbers (must be link-aware: η̂
  then μ̂=exp(η̂), no additive ε).
- **P6b-3** symbol_table `\mathbf{}` wrap + `poly()` deparse + factor_contrast
  `[var = level]` raw variable (no flagged snake_case-factor case today).
- **phantom-σ** mcmcglmm + sdmtmb (probe-first; sdmTMB `phi` must be confirmed
  not a legitimate σ row).

See `.memory/reports/2026-05-30-page-audit-fixes.md`.
