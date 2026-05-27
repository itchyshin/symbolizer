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
- 2026-05-26 ~00:xx — Rose reconciliation of families.html DONE in ~3 min. SIGN-OFF (not veto). All 4 V-lenses cleared regex-cosplay sniff test. 4 architectural roots named (family-blind template B48; link-function never consulted; duplicate DOM B27; no per-family parameter glossary). 6 new patterns ratified: P/Q/R/S/T/T-meta. **B48/ROOT-1 flagged as highest-leverage fix to land first in v0.21.1.** Surface families.html status table: V1✓ V2✓ V3✓ V4✓ Rose✓.
- families.html lens sweep complete. Breadth phase begins. Dispatching V1 on drmtmb.html next.
- 2026-05-26 ~00:xx — V1 Florence-lens on drmtmb.html DONE in ~12 min. Different surface = different bugs. 7 new defects B65-B71 + 5 new patterns U/V/W/X/Y. drmtmb is a flat vignette (no tabbed widgets) so families-style patterns L/M/N/O/P/Q/R/S don't apply here. Notable: B65 comma-drop in template math, B69 table overflow without .table-responsive, B70 rho12 row has ASCII math placeholders, B71 \mathrm{site} letter-spacing (same root cause as B24 / Pattern L). Plan catalog now B1-B71 + RF1-RF4; patterns A-Y.
- Status table updates: drmtmb V1✓ V2/V3/V4 not dispatched (low priority — flat vignette, V2/V3 less relevant).
- Dispatching V1 on structural-dependence.html next.
