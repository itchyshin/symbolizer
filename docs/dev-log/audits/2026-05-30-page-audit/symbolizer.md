# Audit — symbolizer.html (get-started quickstart)

Audited inline by the orchestrator (the dispatched agent hit a repeated 529 overload).
Article rewritten this session as a lean base-R glm Poisson quickstart (#3).

## Findings

- **[MAJOR] Tab-3 "Equations with data" shows the `expanded$X` / "issue #9" scaffold, garbled by MathJax.**
  The glm extractor populates only the response vector, so the three-views widget's
  Tab 3 renders the fallback text "...needs `expanded$X`, `expanded$beta`,
  `expanded$mu_hat`. ... populates only ... See issue #9." The bare `$` signs are
  parsed by the site-wide MathJax as math delimiters, so the sentence renders as
  broken/italic math. **Cross-cutting:** the same scaffold + `$`-breakage hits the
  meta-analysis §5 glmmTMB widget and any extractor that does not populate
  `expand()$X` (glm, glmmTMB, lme4, mgcv). Root fix in `R/render-three-views.R`:
  the fallback message must not use bare `$` (escape as `\$` or rephrase without
  `$`), and ideally `expand.glm`/etc. should populate X/beta/mu_hat so the data tab
  actually renders for the quickstart's own example.

## Clean / passing
- Equation renders (Poisson `Poisson(mu_i)`, `log(mu_i)=beta_0+beta_1 T_i`); the
  `\begin{aligned}`/`\boldsymbol`/`\mathbb{R}` in the HTML are MathJax source, not
  literal leaks (matches the families verdict).
- `parameter_interpretation` rate-ratio reading present ("rate ratio", "multiplies
  the expected count").
- Widget emits exactly once (no Pattern-M dupe).
- It is genuinely short (158 source lines); glossary + "where next" `vignette()`
  links resolve; no "lands in vX" placeholders.

symbolizer: 0 blockers, 1 majors, 0 minors  (the Tab-3 scaffold is the lone defect; tagged MAJOR — the article works, one tab of one widget shows a garbled note. The meta-analysis agent rated the same root issue BLOCKER on its page.)
