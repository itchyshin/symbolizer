# Page audit: symbolizer-factors

Date: 2026-05-30
Sources: `docs/articles/symbolizer-factors.html` (rendered, site version 0.22.3) + `vignettes/symbolizer-factors.Rmd`
Lenses: (1) rendering, (2) math, (3) reader-flow, (4) consistency.

## [BLOCKER]

- [BLOCKER] Step 1 prose: un-evaluated inline R leaks literally as `intercept + sexmale = r round(sum(sym1$fixed_effects$estimate[1:2]), 2)` (HTML L318). Cause: Rmd L105 wraps the whole phrase in ONE backtick code span starting `intercept`, so `` `r ...` `` is never an inline chunk — it is literal text. The other two inline-R calls in the same bullet list (L99, L103) DO evaluate (29.81, 4.99), so the reader sees two real numbers then a raw `r round(...)` expression, which is jarring and reads as a broken page.

## [MAJOR]

- [MAJOR] Prose-vs-table contradiction (Step 6): prose says "Three interaction rows are again silent. Read the cell-mean translations above in their place." (HTML L1658), but the `parameter_interpretation()` table immediately above is NOT silent — all three `interaction_factor_factor` rows carry full templated readings ("The site effect on body_mass differs by 0.276 between sex = male and sex = female. Call `group_means(...)` ...", HTML L1615-1644). Same issue weaker in Step 4 ("Read the prose above in place of a templated row", L1278) where the interaction row is also fully templated (L1257-1263).
- [MAJOR] Stale roadmap claim (Closing, HTML L2425): "The interaction layer is on the template roadmap; until it lands, the cell-mean translation in this vignette is the manual fallback." Interaction templates have clearly landed — both `interaction_cont_factor` (Step 4) and `interaction_factor_factor` (Step 6) emit dedicated templated prose in the rendered tables. The closing under-sells shipped functionality and contradicts the body.
- [MAJOR] Misleading templated reading vs. correct hand-derivation (Step 4): in the `sex * body_size` model the `sex` factor_contrast row reads "Average body_mass differs between male and female by 3.04" (HTML L1242), but the section's own correct math (L1199-1203) states this coefficient is the difference in intercepts at `body_size = 0`, explicitly "no longer the average male mass or the male-female mass difference at average body size". The generic "Average ... differs between male and female" template is wrong in the presence of the interaction and contradicts the prose three lines below it. (Template-content issue surfaced by the vignette, not a vignette-prose typo.)

## [MINOR]

- [MINOR] Transform-deparse leak (Pitfall 6, `poly()` symbol_table, HTML L2183-2185): index renders `body_size, 2_i` and variable `body_size, 2` — the `poly(body_size, 2)` term is deparsed with the comma/arg kept and a literal `_i` subscript that is not typeset (plain table cell, not math). Ugly but the pitfall is explicitly about `poly()`, so it is legible in context; the raw-quadratic row similarly shows `body_size^2_i` (L2304).
- [MINOR] Factor index symbols rendered as literal text, not math: `sex_i` (HTML L177, L652, L903), `site_i` (L406), `body_size_i` (L1754) appear as plain `sex_i` rather than typeset \(sex_i\) — the underscore subscript is not rendered. Consistent across all factor rows (response/parameter rows above them DO typeset), so it reads as a deliberate style for factor rows rather than a break, hence MINOR.
- [MINOR] Step 1 takeaway vs. Step 3 nuance (consistency): Step 1 takeaway calls the intercept "the reference-level mean" (HTML L326) flatly; correct for the intercept-only-factor case, but a reader carrying that phrasing forward collides with Step 3's "expected response at reference level AND zero of every continuous predictor". The body handles the shift well; only the bare takeaway sentence is potentially over-generalised.
- [MINOR] `group_means` cell-mean labels use space-padding to align level names: `sex=male , site=A` (HTML L2062) shows a stray space before the comma. Cosmetic table-formatting artefact from fixed-width level padding.

## Notes (not defects)

- Dummy/contrast math is correct throughout: k-level → k−1 columns with reference in intercept (Steps 1-2), additive intercept shift (Step 3), cont×factor slope-difference (Step 4), cont×cont sliding slope (Step 5), factor×factor difference-of-differences (Step 6). Cell-mean algebra in Step 6 (\(\bar W_{B,male}-\bar W_{B,female})-(\bar W_{A,male}-\bar W_{A,female}\)) is right.
- Three-views widget (Step 3) typesets cleanly; head/tail matrix truncation (5 + 2 of n=120) renders correctly; no `\n` literals, no clipped wide tables observed.
- All six pitfalls have a clear one-sentence "Rule of thumb"; reader-flow per section is good (every step + pitfall has an explicit Takeaway/Rule).
