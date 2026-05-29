# V2 Pat-lens audit — symbolizer-meta-analysis §4 (v0.22.1)
Date: 2026-05-28
Slice: v0.22.1
Target: http://localhost:8767/articles/symbolizer-meta-analysis.html

## Verdict
NEEDS FIXES

## §4 subsection takeaways (biologist's perspective)
- 4.1 model in symbols: "The reader should leave with: When you have effect sizes from multiple species, you can split the between-study variance into a phylogenetic piece (correlated by shared ancestry) and a study-level piece, on top of the known sampling variance." — The equation block delivers this clearly; the marginal-variance line is the key pedagogical sentence.
- 4.2 data: "The reader should leave with: We are now using 164 dARR effects from 35 species across 39 studies, with habitat (aquatic vs terrestrial) as the moderator." — The `cat()` output line makes this concrete and scannable.
- 4.3 drmTMB widget: "The reader should leave with: In drmTMB you write meta_V() and phylo() directly inside the formula, which is the cleanest idiom." — But the widget equations do NOT show the phylo random effect in the mean; see Flow break 1 below.
- 4.4 brms light: "The reader should leave with: In brms the same model uses se(sqrt(vi)) and gr(phylogeny, cov=A), which map one-to-one to drmTMB's idioms." — The bridge sentence "(cf. §7): brms se(sqrt(vi)) ↔ drmTMB meta_V(V=vi); brms gr(g, cov=A) ↔ drmTMB phylo(...)" is clear.
- 4.5 metafor light: "The reader should leave with: metafor's rma.mv fits the same model via V= and R=; the two sigma2 rows correspond to the phylo and study tiers." — The `$sigma2` output and the two-sentence interpretation deliver this. Correct.

## Build-up: §3 → §4 transition
- Does the dataset switch land cleanly? Y — the "Dataset switch." callout at the top of §4 explicitly names why BCG doesn't work (only one study per row) and introduces the thermal acclimation dataset with its species/effect/study counts. Smooth.
- Does §4 build on §3 or feel disconnected? Mostly Y — the opening sentence anchors on §3's τ² and then says "that between-study tier splits" when species are related. The conceptual build-up from §1's Flavor 2 preview to §4's full model is clear. One minor roughness: §4's intro paragraph introduces matrix A in the same sentence as the concept ("phylogenetic piece (constrained by the phylogeny via A)"), so the concept and symbol arrive simultaneously rather than concept-first; A has already appeared in §1 so this is defensible.

## Widget §4.3 standalone test
- Reader opens only the widget (skips prose): what one-sentence takeaway? Plausible? NO.
- The widget's biological callout explains what A and σ_p mean, but gives no numerical result to anchor on. The fitted β estimates (β_0 = 0.254, β_1 = −0.208 for terrestrial) are visible in Tab 3 but are never interpreted in biological terms anywhere in or around the widget. A reader skipping the prose would see the equations, the matrix expansion, and the σ callout but leave without knowing whether aquatic species show larger dARR than terrestrial, or by how much. There is no standalone summary sentence.

## Cross-package equivalence (§4.3/4.4/4.5)
- Do the three Faces fit the SAME math? PARTIALLY — the model structure is algebraically equivalent across the three, but there is a presentational inconsistency that creates reader confusion (see Flow break 1 below).

## Flow breaks (numbered)

1. **Widget equations omit the phylo random effect.** The symbolizer output in the drmTMB widget (all three tabs) shows the mean as μ_i = β_0 + β_1[habitat] + u_studyID(i) only, with log(σ_i) = γ_0 as a separate scale intercept. The phylogenetic random effect u_p,s(k) ~ N(0, σ_p² A) — the defining feature of §4 — does not appear in any equation in the widget. The symbol A is listed in the glossary with a correct description, and the biological callout mentions σ_p, but a reader who reads the widget equations and then returns to §4.1 sees a contradiction: §4.1 shows the phylo term in the mean; the widget does not. This is the most serious flow break.

2. **§4.1 marginal-variance equation is incomplete relative to §4.3 widget.** §4.1 writes Var(y_kt) = v_kt + σ_study² + σ_p² A_{s(k),s(k)}, but the widget's Tab 3 shows only σ_studyID² as the random-effect tier and a separate residual σ ≈ 0.346 (from the drmTMB sigma submodel). The implied-covariance decomposition promised by the spec (§4 design doc) — showing the two estimated tiers separately — is not displayed; the text only says "Tab 3 decomposes the marginal variance" without actually showing a decomposition block.

3. **§4.3 intro leads with syntax before biology.** The first sentence of §4.3 says "drmTMB's native idiom uses meta_V() inside the formula..." A biologist unfamiliar with drmTMB immediately hits package-specific syntax before understanding what model is being fit. A one-sentence model description (e.g., "The model adds a phylogenetic random effect on top of §3's study tier") before the meta_V/phylo sentence would smooth entry.

4. **No biological interpretation of fitted estimates in §4.** The metafor output in §4.5 shows sigma2 = [0.00274, 0.0355] without saying which number is phylogenetic and which is study-level. A biologist reading this cannot state which heterogeneity source dominates. The brms and drmTMB faces similarly provide no numerical summary of σ_p versus σ_study.
