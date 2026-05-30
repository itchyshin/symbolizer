# Audit: symbolizer-meta-analysis

Article `symbolizer-meta-analysis` — consolidated read of `docs/articles/symbolizer-meta-analysis.html` + `vignettes/symbolizer-meta-analysis.Rmd`. Four lenses: RENDERING / MATH / READER-FLOW / CONSISTENCY.

## Defects

### RENDERING
- [BLOCKER] §5 locscale widget Tab 3 ("Equations with data", `panel-mat`, HTML 1269–1274): placeholder prose `expanded$X`/`expanded$beta` has its `$…$` parsed as inline math, so it renders literally as `expanded\(X</code>, <code>expanded\)beta` — un-typeset `\( … \)` delimiters AND swallowed `</code>` tags shown as text. The §5 widget's third tab is broken (no matrix-with-data render).
- [MINOR] Both three-views widgets emit once with distinct, unique ids (`sym-phylomultilevel-1780144981`, `sym-locscalemeta-1780144981`); `\mathbf{A}`, `\mathbf{darr}`, and the stacked head/tail matrices (§4 Tab 3) are all inside `math display/inline` spans and typeset correctly. No other literal-LaTeX or literal-`\n` leaks (the `\n` hits are all inside displayed `cat()` source). No defect beyond the Tab-3 stub above.

### MATH
- [MAJOR] §4 drmTMB deep-dive Face is degenerate: widget Tab 3 variance partition reads study_ID 0.0% / phylogeny 0.0% / Residual 100.0% (HTML 695–703) and all BLUPs are ~1e-11…1e-15 (HTML 868–887) — both estimated tiers collapsed to ~0, contradicting the §4.5 metafor fit (σ²_p=0.0027, σ²_study=0.0355, both nonzero) and the §4.3/§6 prose that the widget "decomposes the marginal variance into the two estimated tiers" and "study-level variance dominates." The lead Face shows the opposite of the article's narrative, unacknowledged.
- [MINOR] meta_normal traditional form is correct (`Normal(θ_i, v_i), v_i known`; no free residual σ); §4 phylo `σ_p² A` present; §5 location-scale deep-Face = glmmTMB `dispformula=~habitat`, log-SD γ; α≈2γ variance-vs-SD table correct; drmTMB#417 caveat present. No "lands in v0.22.x" scaffolds remain. H² is given as a formula only (no fitted number), acceptable.

### READER-FLOW
- [MINOR] §5 locscale widget biology caption (both eq panels, HTML 1159 & 1212) says "the residual SD is constant across observations" — false for this `dispformula=~habitat` model; the index-tab equation directly below shows `log(σ_i)=γ_0+γ_1[habitat=terrestrial]`. Generic Normal blurb not specialized for the scale submodel; mildly misleads the reader on the section's whole point.
- [MINOR] §5.2 prose/§6 assert `γ_terrestrial ≈ -0.84` but the §5.2 glmmTMB fit never echoes any coefficient (chunk only `symbolize()`s + renders the widget; widget Tab 3 is the broken stub), so the headline -0.84 is ungrounded in any shown number. One-sentence takeaways present and clear in every §.

### CONSISTENCY
- [MAJOR] §3.3 glmmTMB `tau^2: 0.444 (vs metafor: 0.313)` (HTML 364) — a 42% gap, while prose says glmmTMB "reproduces the meta-analytic likelihood / the estimated random-intercept variance is τ̂²" and the §3.5 takeaway says glmmTMB "reproduce[s] the math." Discrepancy unexplained (likely REML-vs-ML / weights scaling); undercuts the "same math" claim.
- [MAJOR] §3.4 drmTMB residual output prints blank: `#> drmTMB residual sigma^2:` with no value (HTML 398) — chunk ran but `fit_drm$report$sigma_eps` returned empty. Dead numeric output shown to reader.
- [MINOR] §5.4 drmTMB prints `γ_terrestrial = -1.165` (intercept -0.957; HTML 1396–1397) but prose says "drmTMB recovers the same scale coefficients as glmmTMB" (-0.84). -1.16 vs -0.84 differ ~38%; the only γ the reader can actually see contradicts the "same" claim.
- [MINOR] τ vs τ² vs σ symbols consistent across §§1–6; α (variance scale, metafor) vs γ (SD scale, glmmTMB/drmTMB) used correctly throughout incl. §5.3 table and §6.
