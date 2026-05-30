# Page audit: symbolizer-drmtmb

Date: 2026-05-30. Read-only audit of `docs/articles/symbolizer-drmtmb.html` + `vignettes/symbolizer-drmtmb.Rmd`. Four lenses: rendering, math, reader-flow, consistency.

Result: **0 blockers, 2 majors, 5 minors**

## Findings

- [MAJOR] CONSISTENCY — Section 10 bullet "All non-Gaussian families — **Planned or reserved**" (Rmd L576 / HTML L1606-1608) is false: the `caps` table shown directly above (HTML L1584-1588) lists `student/mu` (First slice, 0.2.2), `poisson/zi`, `nbinom2/zi`, `truncated_nbinom2/hu` (all First slice, 0.4.0), and the section's own Takeaway (Rmd L585-590) lists Student-t/lognormal/Gamma/beta/beta_binomial/Poisson/nbinom2/truncated_nbinom2/cumulative_logit + zi/hurdle as covered. Bullet contradicts both the table it summarizes and its own takeaway.
- [MAJOR] RENDERING — Literal escape artifact `(1 \&#124; site)` renders as visible text (backslash + ampersand + `#124;`) instead of `(1 | site)`. Two places: `sym_re$random_effects` table (HTML L568) and `formula_bridge(sym_rich)` mu-row "R syntax" cell (HTML L1013). Double-escaped pipe; the inline prose at L1035 shows the correct `(1 | site)`, so the table cells are visibly wrong against the surrounding text.
- [MINOR] RENDERING — `notation_bridge(sym_rich)` "site" row: shape and concrete cells wrapped in stray `$...$` delimiters — `$scalar; \(\mathbb{R}^{G_{site}}\) in matrix form$` (HTML L1154) and `$scalar; \(\mathbb{R}^{8}\) in matrix form$` (HTML L1156). The leading/trailing `$` are literal and risk MathJax mis-typesetting the mixed text/math cell.
- [MINOR] CONSISTENCY — Section 4 prose narrates the three status buckets as `stated` / `implied` / `not_checked` (HTML L395, L403, L409, L422-423), but the rendered `assumption_table()` `status` column shows `explicit` / `follows from the formula` / `your responsibility` (HTML L348, L372, L387). A reader cannot find the prose's status words anywhere in the table.
- [MINOR] CONSISTENCY — Section 4 cross-reference: "the first two belong in section 6 (diagnostics)" (Rmd L199 / HTML L418). Section 6 is "A richer worked example"; diagnostics are Section 8 ("What to inspect next"). Wrong section number.
- [MINOR] CONSISTENCY — Section 10 biv_gaussian bullet says "(see Section 6)" (Rmd L575 / HTML L1605), but the bivariate-Gaussian worked example is Section 7, not 6.
- [MINOR] RENDERING — `parameter_interpretation(sym_biv)` rho12 reading cells show literal `tanh^{-1}(0.674)` with un-typeset `^{-1}` (HTML L1380). Matches the table's plain-text convention (`exp(0.222)` etc.), so cosmetic only, but the `^{-1}` caret-brace reads awkwardly in prose cells.

## Lenses with no defects

- MATH — Gaussian location-scale `N(mu_i, sigma_i^2)`, log-link sigma submodel `log(sigma_i)=gamma_0+gamma_1 T_i`, and the equivalence to `exp(gamma_0)exp(gamma_1 T_i)` are all correct. Bivariate: `N_2((mu_1i,mu_2i), Sigma_i)` with symmetric 2x2 `Sigma_i` (off-diagonal `rho_{12,i} sigma_{1i} sigma_{2i}`) and matrix form `Sigma = diag(sigma_1) R(rho_12) diag(sigma_2)` are correct. Fisher-z (`tanh^{-1}`) link on rho12 stated consistently. No comma-as-thin-space artifacts; no phantom terms.
- RENDERING (math typesetting) — All display/inline math is in `\[...\]` / `\(...\)` form for MathJax; no raw un-typeset `$$` source left in the body. The three `\n` matches are all `\ne` (LaTeX not-equal) inside math, not literal newlines. The three-views widget (single id `sym-sym-1780105211`) is not duplicated; matrix/BLUP brackets use `\begin{bmatrix}` and head/tail-truncate cleanly (5 head + 2 tail rows of n=120).
- READER-FLOW — Every content section (1-10) ends with a one-sentence biologist **Takeaway**; Section 11 is a link list. No prose-vs-equation/widget contradictions found beyond the consistency items above.
