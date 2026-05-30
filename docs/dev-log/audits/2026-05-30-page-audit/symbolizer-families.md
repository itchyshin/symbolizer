# Page audit: symbolizer-families

Date: 2026-05-30
Sources: `docs/articles/symbolizer-families.html` (rendered) + `vignettes/symbolizer-families.Rmd`
Lenses: (1) rendering, (2) math (per family: distribution + link, family-aware Tab-3, Beta precision, lognormal log-scale residual, link-matched coefficient callouts), (3) reader-flow, (4) consistency.

## [BLOCKER]

- None.

## [MAJOR]

- None.

## [MINOR]

- [MINOR] Symbol collision in the Beta Tab-1 heads-up (HTML L581-583): the same panel uses `\(\exp(\hat\beta)\)` for the regression slope / odds ratio (L577) and then `\(\hat\beta = (1-\hat\mu)\hat\sigma\)` for the second Beta *shape* parameter two lines later. `\hat\beta` carries two different meanings within one Tab-1 panel. Conventional (α, β are the standard Beta shape names) but a careful reader can trip on it; a distinct symbol (e.g. `\hat\beta^{\text{shape}}` or `b`) would remove the ambiguity.
- [MINOR] Uneven plain-language takeaway across the three widgets (reader-flow): only the Poisson widget carries the biologist one-sentence "Each observation is a count; the log of the expected count may shift with the predictors." sentence (HTML L915/953/991, in all three panels). The lognormal and Beta widgets open Tab-1 directly with the "Coefficient reading" paragraph (L249, L577) and have no equivalent "what each observation *is*" sentence. Every family still has a biological coefficient reading, so this is a coverage gap, not a contradiction.

## Notes (not defects)

- RENDERING: all math is wrapped in MathJax spans (`\[...\]` display, `\(...\)` inline); zero literal `$$`, zero un-typeset LaTeX in the body, no literal `\n` (the only `\n` hits are `\nu` Greek-nu, L127-128). MathJax 3.2.2 (tex-mml-chtml) loaded. No `asis_output` / `[1]` / `NULL` print artifacts.
- RENDERING: the three family widgets (`sym-lognormal-1780105221`, `sym-beta-1780105223`, `sym-poisson-1780105224`) each emit EXACTLY once; ids, `<style>`, and `<script>` are all scoped to the unique root id (`getElementById` at L435/769/1050). No duplicated DOM/ids.
- RENDERING: matrices use `\begin{bmatrix}` inside `\[...\]` (MathJax auto-stretching brackets); `.sym-eq` has `overflow-x:auto; max-width:100%` so wide matrices scroll rather than clip. Head/tail truncation (first 5 + last 2 of n=100, `\vdots`) renders in every stacked matrix.
- MATH — distribution + link correct for every family: Student-t `Student-t(μ,σ,ν)` (L127); Lognormal `Lognormal(μ,σ²) ⟺ log(y)~Normal(μ,σ²)` (L255); Gamma `Gamma(shape=1/σ², scale=μσ²)` mean=μ (L493); Beta `Beta(μσ, (1-μ)σ)` mean-precision (L521); Beta-binomial `BetaBinomial(N,μ,σ); E=Nμ` (L833); Poisson `Poisson(μ)` (L861); nbinom2 `NegBin(μ, size=exp σ); Var=μ+μ²/exp(σ)` (L1109); truncated `NegBin⁺(μ, size=exp σ); y∈{1,2,3,…}` (L1133).
- MATH — Tab-3 worked rows are family-aware (the area the capability fix touched), all correct:
  - Lognormal (L348-413): residual on the LOG scale `log(y₁)=β̂₀+β̂₁x₁+ε̂₁^(log)`, back-transform note `E[y]=exp(μ̂+σ̂²/2)`; σ described as "log-scale residual SD (SD of log y)". Correct.
  - Beta (L685-746): NO additive ε — shows `η̂₁=β̂₀+β̂₁x₁` then `μ̂₁=logistic(η̂₁)≈0.279` then `y₁~Beta(μ̂σ̂,(1-μ̂)σ̂)` tagged "no additive ε here"; σ row tagged "precision parameter ... positive shape, not an SD". Correct. Arithmetic checks (−0.824−0.0874×1.43≈−0.95; logistic(−0.95)≈0.279).
  - Poisson (L1001-1044): NO additive ε and NO σ submodel block (no dispersion param) — `η̂₁=β̂₀+β̂₁x₁`, `μ̂₁=exp(η̂₁)≈2.55`, `y₁~Poisson(μ̂₁)`. Correct. Arithmetic checks (exp(0.936)≈2.55).
- MATH — coefficient-reading callouts match the link: Poisson/nbinom2/truncated = rate ratio (log link); Beta/Beta-binomial = odds ratio of success prob (logit link); lognormal/Gamma = multiplier on geometric mean / mean (log link). All consistent between body prose and widget Tab-1.
- MATH — Beta U-shape heads-up arithmetic correct: α̂=μ̂σ̂=0.279×0.353≈0.098, β̂=(1-μ̂)σ̂≈0.25, both <1 ⇒ U-shaped; statistically sound diagnostic.
- CONSISTENCY: σ named the same across tabs within each family — Beta "Beta precision (larger sigma → tighter)" (Tab-1 L610, Tab-2 L650, Tab-3 "precision parameter, not an SD"); lognormal "scale on the log-response" (Tab-1/2) = "SD of log y" (Tab-3). Poisson has no σ anywhere (Tab-1/2/3). No mu-on-wrong-scale contradictions.
- CONSISTENCY: intro "ten package families" claim matches the enumerated list (drmTMB, gllvmTMB, glmmTMB, brms, lme4, MCMCglmm, sdmTMB, stats::lm/glm [one], metafor, mgcv = 10). "Picking a family" six rules map onto the body sections.
