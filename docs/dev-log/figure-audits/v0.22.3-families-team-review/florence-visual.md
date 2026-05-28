# Florence — visual-rendering audit, v0.22.3 families vignette

Target: `docs/articles/symbolizer-families.html`, three widgets,
rendered DOM at localhost:8767. Lens: scale matching, raw-markup
leaks, layout weight, caption↔display consistency.

Tab map: 1=Index (`panel-idx`), 2=Matrix (`panel-eq`),
3=Equations-with-data (`panel-mat`, stacked numbers).

## Lognormal widget

| Block | Content | Scale | Flag |
| --- | --- | --- | --- |
| T1 index | `y_i ~ Lognormal(μ,σ²); μ=β₀+β₁x; log σ=γ₀` | log clean | NO |
| T2 matrix | `log(y)|μ,σ ~ N(μ,diag σ²); μ=Xβ` | clean | NO |
| T3 worked row (pink) | `log(y₁)=2.02+(−0.0136)·0.409+(−0.448)=1.56` | all log, reconciles | NO |
| T3 stacked block | `y_100×1=[4.78,7.94,3.99,…]=Xβ̂+ε̂`, `β̂=[2.02,−0.0136]`, `ε̂₁=2.77` | LHS response, Xβ̂≈2.014 log, ε̂=y−exp(Xβ̂) | **YES** — response y equated to log-scale Xβ̂; contradicts worked row using `log(y)` |
| T3 caption | "Middle: `Xβ̂=μ̂`. Right: `ε̂=y−μ̂`" | identifies link with response | **YES** — only true on identity link |
| T3 σ worked | `log σ̂₁=−0.764; σ̂₁≈0.466` | clean | NO |
| T3 σ stacked | `log[0.466 ×8 rows]_100×1` | identical rows | see proposals |

## Beta widget

| Block | Content | Scale | Flag |
| --- | --- | --- | --- |
| T1 index | `y_i ~ Beta(μσ,(1−μ)σ); logit μ=β₀+β₁x; log σ=γ₀` | clean | NO |
| T2 matrix | `y|μ,σ ~ Beta(μ,σ); logit μ=Xβ; log σ=Zγ` | clean | NO |
| T3 worked row | `η̂₁=−0.95; μ̂₁=logistic(η̂₁)≈0.279; y ~ Beta(μ̂,…)` + "no additive ε" | clean | NO |
| T3 stacked block | `y_100×1=[0.175,0.324,0.146,…]=Xβ̂+ε̂`, `β̂=[−0.824,−0.0874]`, `ε̂₁=−0.103` | y in (0,1); Xβ̂₁≈−0.949 logit; ε̂=y−logistic(Xβ̂)=−0.104 | **YES** — response y vs logit Xβ̂; equation not algebraically true as written |
| T3 caption | `Xβ̂=μ̂`; `ε̂=y−μ̂` | link vs response | **YES** — contradicts worked row two cells above |
| T3 worked→stacked | worked says "no additive ε"; stacked shows `+ ε̂` | — | **YES** — self-contradiction |
| T3 σ stacked | `log[0.353 ×8 rows]_100×1` | identical rows | see proposals |

## Poisson widget

| Block | Content | Scale | Flag |
| --- | --- | --- | --- |
| T1 index | `y_i ~ Poisson(μ_i); log μ=β₀+β₁x` | clean | NO |
| T2 matrix | `y|μ ~ Poisson(μ); log μ=Xβ` | clean | NO |
| T3 worked row | `η̂₁=0.936; μ̂₁=exp(η̂₁)≈2.55` + "no additive ε" | clean | NO |
| T3 stacked block | `y=[1,1,2,3,1,…,0,5]=Xβ̂+ε̂`, `β̂=[0.955,−0.0438]`, `ε̂₁=−1.55` | counts vs log Xβ̂≈0.935; ε̂=y−exp(Xβ̂) | **YES** — same class as Beta |
| T3 caption | `Xβ̂=μ̂; ε̂=y−μ̂` | claims `Xβ̂=μ̂` but worked says `μ̂=exp(Xβ̂)` | **YES** |
| T3 worked→stacked | "no additive ε" then `+ ε̂` | — | **YES** |

## Cross-widget patterns

1. **Tab 3 stacked block always shows `y=Xβ̂+ε̂`** regardless of family. Beta/Poisson: response y vs link Xβ̂. Lognormal: should be `log(y)=Xβ̂+ε̂` but LHS is raw y. One broken template, three widgets.
2. **Stacked-block caption asserts `Xβ̂=μ̂` in all three Tab 3 panels.** True only on identity link.
3. **Worked row says "no additive ε" for Beta/Poisson; stacked block shows additive ε̂.** Self-contradiction in one panel.
4. **Tabs 1 and 2 are scale-clean for all three widgets.** Bug is Tab-3-only.
5. **No raw `$$` visible.** Rendered MathML hides `<annotation>` source.
6. **σ stacked block renders 8 identical rows** (~209 px, equal to y/Xβ block) for intercept-only σ submodels.

## Visual-improvement proposals

1. **Constant-σ truncation.** When σ̂ is constant, show head 2 + ⋮ + tail 1, not 8 identical rows. Current weight equals the y vector, mis-signalling importance.
2. **σ block de-emphasis.** Render σ stacked equation at 0.9em, opacity 0.8.
3. **Stacked-block caption hierarchy.** "Left/Middle/Right" uses `<strong>` at 13.6 px and embeds inline math at body size, visually outweighing the worked-row tag inside the pink box. Drop `<strong>`, use plain prose at 0.85em.
4. **Pink-box bottom padding.** `padding: 11.2px 16px` leaves ~20 px empty under last equation in all three widgets. Reduce bottom to ~6 px so worked row leads into the stacked block.
5. **Worked-row → stacked-row hook.** Add a pink-tinted left border on row 1 of y, Xβ̂, ε̂ matrices so "this is the row I just walked" is visible.
6. **Scale-tag side-labels.** 0.75em uppercase tag (log/logit/response) to the right of each equation block; aids reading even after the math is fixed.
7. **Numeric precision.** Beta stacked vectors mix 3-/4-/6-sig-fig in one column. One per-matrix policy.
8. **Truncation `⋮` rhythm.** Beta `⋮` has tighter top- than bottom-spacing; equalise with `\vphantom`-padded `\vdots`.
9. **σ-row caption wrap.** Beta σ-tag with nested parentheses wraps awkwardly; split or move to margin.
10. **σ section header.** "And the σ submodel …" reads as a header but renders as body text. Use small-caps or h6-style.
