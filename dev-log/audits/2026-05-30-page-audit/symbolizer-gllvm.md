# Page audit — symbolizer-gllvm

Source: `vignettes/symbolizer-gllvm.Rmd` → `docs/articles/symbolizer-gllvm.html` (1507 lines).
Date: 2026-05-30. Lenses: (1) rendering, (2) math, (3) reader-flow, (4) consistency.

## Result

`symbolizer-gllvm: 0 blockers, 3 majors, 4 minors`

## Defects

### MAJOR

- [MAJOR] Tab 3 implied-covariance blocks render the `Λ_BΛ_Bᵀ` / `Λ_WΛ_Wᵀ` term as the *raw loading matrix* (5×2 for `Λ_B`, 5×1 for `Λ_W`) instead of the 5×5 outer product, in BOTH widgets (HTML 666-669, 1059-1062, 1083-1085); arithmetic does not close as printed (e.g. `0.817+0.358=1.175≠1.03`; `0.564+0.0172=0.581≠0.335`) — it only closes if the reader silently squares the shown entries and supplies the missing off-diagonal cross-products.
- [MAJOR] §6 prose "The arithmetic closes element-by-element to within rounding" (HTML 721-722) is false as rendered for the reason above — `Σ_B` middle term is shown 5×2, not the 5×5 it equals; the dimensional `5×5 = 5×2 + 5×5` (and `5×5 = 5×1 + 5×5` for `Σ_W`) does not conform and the flanking 5×5 matrices visibly outsize the middle term.
- [MAJOR] §9 prose `Ψ_B = (0.00004, 0.56, 0.48, 0.93, 0.41)` with reading "trait 1 (boldness) … uniqueness disappears" (HTML 1309-1314) contradicts the rendered Widget 1, whose `Ψ_B²` diag is `(0.358, 3.2e-08, 0.249, 0.142, 3.9e-16)` — trait 1 has the *largest* uniqueness; the near-zero entries are traits 2 and 5. The named biological interpretation points at the wrong trait.

### MINOR

- [MINOR] Orphan superscript `diagonal ^{5 }` rendered as literal plain text (not in a math span) in the `Ψ_B`/`ψ_{B,t}` dimension gloss, 4× (HTML 505, 568, 893, 961) — should be a typeset dimension (e.g. `ℝ^{5×5}`).
- [MINOR] Double-subscript `y_{ij}_{1}` and `y_{ij}_{\,600 \times 1}` in Tab 3 display math, 6× across both widgets (HTML 599, 607, 621, 991, 999, 1013) — user symbol `value="y_{ij}"` already has a subscript and the renderer appends another, producing a "Double subscript" TeX error that MathJax flags in-body.
- [MINOR] §10 bridge table code cells leak the pandoc pipe-escape: `latent(0 + trait \| g, d = k)`, `rr(0 + trait \| g, d = k)`, `unique(0 + trait \| g)`, `diag(0 + trait \| g)` (HTML 1365-1381) render with a literal backslash; other code spans use clean `|`.
- [MINOR] Two-tier Tab 1 "where:" gloss (HTML 854-895) is incomplete: its 9 items cover only between-tier symbols, but the equation above uses `λ_{W,t(j)ℓ}`, `z_{W,ijℓ}`, `ℓ`, `d_W`, `ψ_{W,t}` (all unglossed) and still lists `σ_ε` ("shared row-level residual SD") which §7 says is auto-suppressed in this exact fit.

## Clean / verified

- RENDERING: MathJax loaded site-wide (HTML 14) + per-panel re-typeset (698, 1120); no literal `\n`; §5 long/wide flex panels typeset (`\mathcal{MN}`, `Σ_W`, `\!\top` all fine); no `\times` inside `\text{}`; no markdown bold-leak; §7 info blockquote (ℹ/•) intact; all 10 Takeaway blocks rendered.
- WIDGET DUP: known copy-2-dead-interactivity bug ABSENT — each widget emits ONCE with unique id (`sym-syndromes-1780105229`, `sym-twotier-1780105230`); zero duplicate ids in file; one `<style>`+one `<script>` IIFE per widget, each scoped to its own root, interactivity live.
- MATH (correct parts): Tab 1 index panels carry proper `Σ_B`/`Σ_W` sums (`Σ_{k=1}^{d_B}`, `Σ_{ℓ=1}^{d_W}`); per-trait repeatability `R_t=[0.747,0.555,0.836,0.62,0.785]` closes exactly against the shown `Σ_B`/`Σ_W` diagonals; §3 univariate `R`, §4 param-count and reduced-rank `ΛΛᵀ+Ψ` formulas correct.
- CONSISTENCY: n=600 (=40×3×5) consistent across prose/code/widget; `d_B=2` (code `d=2`, gloss `ℝ^{5×2}`, axis `{1,…,2}`) and `d_W=1` (code `d=1`, single `ℓ`) consistent; `ℝ^{40×5}` matrix-form framing complementary, not contradictory.
- READER-FLOW: one-sentence biologist takeaways present per section; syndromes (between) vs integrated-plasticity (within) framing lands (§1, §6, §7, §8); t1–t5 ↔ boldness/exploration/aggression/activity/shelter mapping stated; glmmTMB bridge (§10) clear.

## Note (not scored)

- Tab 3 worked-row expansion (`y = Xβ̂ + ε̂`) treats `trait` as 5 fixed-effect dummies; the latent/BLUP contribution is folded into the residual (two-tier residuals ≈1e-6), so the "Partial pooling … BLUPs shown here" caption (HTML 1040-1045) describes a random-effect column the displayed equation does not actually show. Borderline; left unscored as it is generic-renderer boilerplate, not gllvm-specific breakage.
