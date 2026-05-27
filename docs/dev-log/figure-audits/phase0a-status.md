# Phase 0a overnight sweep — live status

Last update: 2026-05-26 (start of overnight)

Maintainer: I'm running the multi-agent visual check across every Phase 0a surface while you sleep. Grep this file when you wake up to see where I got.

## Surfaces to audit

| # | Surface | V1 Florence | V2 Pat | V3 Noether | V4 Twin (PDF parity) | Rose reconciliation | Notes |
|---|---|---|---|---|---|---|---|
| 1 | symbolizer-structural-dependence.html | manual (maintainer) | — | — | — | — | Done by maintainer 2026-05-26; deep findings in plan |
| 2 | symbolizer-families.html | ✓ done | starting | pending | pending | pending | V1 found B31–B41 + Pattern P |
| 3 | symbolizer-drmtmb.html | pending | pending | pending | pending | pending | |
| 4 | symbolizer-factors.html | pending | pending | pending | pending | pending | |
| 5 | symbolizer-gllvm.html | pending | pending | pending | pending | pending | |
| 6 | symbolizer.html (get-started) | pending | pending | pending | pending | pending | |
| 7 | index.html | pending | — | — | — | — | Article ordering only |
| 8 | symbolizer-roadmap.html | pending | — | — | — | — | Claim/code drift |
| 9 | PDFs (fig-*.pdf) | — | — | — | pending | pending | V4 handles |

## Live log (newest at bottom)

- 2026-05-26 23:xx — Plan finalized to revision 6.
- 2026-05-26 23:xx — Overnight sweep starting. V2 Pat-lens on families.html dispatching next.
- 2026-05-26 ~23:xx — V2 Pat-lens on families.html DONE. 8 new defects B42-B49 + 4 reader-flow defects RF1-RF4. 3 new patterns proposed: Q (intra-panel self-consistency), R (widget self-sufficient as Methods paste), S (tab labels match content). B48 named as architectural root of B1, B42, B45, B49. Plan catalog now at B1-B49 + RF1-RF4; patterns A-S.
- Dispatching V3 Noether-lens next.
- 2026-05-26 ~23:xx — V3 Noether-lens on families.html DONE in ~6 min. 6 new math defects B50-B56. B56 is the architectural smoking gun: stacked-block arithmetic always balances because ε̂ = y - Xβ̂ is back-substituted — the renderer never asks the link function what scale Xβ̂ is on. Pattern T added (per-family symbol allocation + ID-to-label lint, covers B50 + B55). Plan catalog now B1-B56 + RF1-RF4; patterns A-T.
- Dispatching V4 Twin-lens next (PDF/HTML parity).
- 2026-05-26 ~00:xx — V4 Twin-lens on families.html ↔ fig-{poisson,beta,lognormal}.pdf DONE in ~8 min. 8 new parity defects B57-B64. **PDF carries ≈30% of HTML content**: every where-gloss table dropped, every stacked-matrix block + caption + σ-stacked block dropped. PDF inherits HTML math errors (B1, B37, B38) but DROPS the matrix evidence that would let reviewers see them. Pattern J updated to reflect actual scope. Plan catalog now B1-B64 + RF1-RF4; patterns A-T.
- families.html lens sweep: V1+V2+V3+V4 all done. Rose reconciliation next.
