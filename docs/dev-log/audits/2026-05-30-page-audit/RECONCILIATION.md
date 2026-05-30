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
