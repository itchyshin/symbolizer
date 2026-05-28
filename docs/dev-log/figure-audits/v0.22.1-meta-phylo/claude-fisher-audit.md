# Claude Fisher-pass numerical audit — §4 phylogenetic-multilevel widget

Date: 2026-05-28
Version: symbolizer 0.22.1.3 (commit `5586911`)
Target: Tab 3 of the §4 widget in `vignettes/symbolizer-meta-analysis.Rmd`
Pass type: Fisher (numerical-extraction protocol — verify every displayed number
against the fitted object at tolerance ≤ 1e-9)
Reviewer: Claude (Codex CLI v0.120.0 was blocked by backend routing to
`gpt-5.5` which the CLI does not yet support; the user declined to auto-upgrade
and asked me to run the Fisher pass directly)

## Verdict

**NEEDS FIXES — BLOCKER on missing phylo tier.**

Numerical-arithmetic on the *visible* (study) tier is correct after v0.22.1.3.
The *invisible* phylo tier is the article's central thesis and renders
nowhere in the widget. Shipping a phylogenetic-multilevel article whose
widget has no phylo tier visible = misleading by omission.

## Per-value numerical audit

Tolerance for "displayed at 3 sig figs ≈ actual" treated as pass (the
renderer formats numbers with `formatC(digits = 3, format = "g")` so
`0.253664` displays as `0.254` and `9.739e-11` displays as `9.74e-11`).

| Symbol | Displayed | Actual (from fit) | Diff | Pass |
|---|---|---|---|---|
| `y_1` | `0.012` | `fit$data$dARR[1] = 0.012` | 1e-15 | ✓ |
| `β̂_0` | `0.254` | `fit$coefficients$mu[1] = 0.253664` | 3.4e-4 (rounding) | ✓ |
| `β̂_1` | `-0.208` | `fit$coefficients$mu[2] = -0.208475` | 4.8e-4 (rounding) | ✓ |
| `x_1` (habitat) | `1` | `fit$data$habitat[1] = terrestrial` ⇒ 1 | 0 | ✓ |
| `û_{study_ID=3}` | `9.74e-11` | `fit$random_effects$mu$terms[["(1 \| study_ID)"]][["3"]] = 9.739e-11` | < 1e-13 | ✓ |
| `Z_g %*% u at row 1` | `(9.74e-11)` | computed: `9.739e-11` | < 1e-13 | ✓ |
| `Z_g` shape | `164×39` | `dim(ex$Z_g) = c(164, 39)` | 0 | ✓ |
| `Z_g rowSums` | implied 1 | `all(rowSums(ex$Z_g) == 1)` | TRUE | ✓ |
| `Z_g values` | implied {0,1} | `unique = {0, 1}` | TRUE | ✓ |
| `ε̂_1` | `-0.0332` | `y_1 - μ̂_1 = -0.033188` | 1.2e-5 (rounding) | ✓ |

The Z_g fix in `5586911` is mathematically correct. All displayed
numbers for the visible (study) tier round-trip cleanly against the fit.

## Missing-phylo-tier diagnosis

```
n species in data:       35
fit$obj$report()$u_phylo length: 68   (n_tips + n_internal under all-nodes encoding)
ex$Z_phylo in expanded:  FALSE   ← absent
ex$u_phylo in expanded:  FALSE   ← absent
Tab 3 stacked block:     ONLY shows X β̂ + Z_{study} û_{study} + ε̂.
                         Phylo tier silently dropped.
Implied phylo contribution per obs (computed as μ̂ − Xβ̂ − Z_study û_study):
  range = [-1.0e-14, 1.6e-14]
  mean abs = 7.5e-15
  within-species spread: 0
```

**Two distinct things going on:**

1. **σ̂_p is boundary-pinned at zero** (V3 Noether already flagged this — the
   MLE collapsed the phylogenetic variance to ~0 on this 35-species fit). So
   the *numerical* phylo contribution per observation is ~7.5e-15. Reporting
   the BLUPs to 3 sig figs would show "0" everywhere for this fit.
2. **The tier itself is invisible to the renderer** regardless of magnitude.
   `drm_build_expanded()` reads `re_per_entry[[which(has_re)[1L]]]` — picks
   only the first iid tier and discards everything else. For multi-tier
   models — phylo+study, animal+litter, spatial+plot, etc. — the second
   tier is silently dropped from Tab 3.

The first is a statistical property of THIS dataset. The second is a
structural extractor bug affecting EVERY multi-tier drmTMB fit symbolizer
renders. It is the higher-leverage fix.

## Closure check (proof that the math is internally consistent)

```
max |Xβ̂ + Z_g·u_study + (μ̂ − Xβ̂ − Z_g·u_study) − μ̂| = 0   (by construction)
within-species spread of implied phylo contribution = 0   (sanity)
```

The phylo contribution per observation is well-defined and constant per
species. Once the extractor surfaces it, the renderer can show it as a
164×35 Z_phylo one-hot times a 35-vector of tip BLUPs.

## V-agent failure-mode critique

The Cherry Club passed all three checks on this widget. What each one
*should* have caught in seconds:

- **V1 Florence (visual)**. The pre-fix Tab 3 displayed a `Z_{164×1}`
  column of values `[3, 3, 3, ..., 147, 147]`. A one-hot matrix is by
  visual definition mostly zeros with exactly one 1 per row. Florence
  should have written: *"Z column shows integer values, not 0/1 — this is
  not an incidence matrix. Reject."* — and the bug would have closed in
  one round.
- **V3 Noether (math)**. The pre-fix worked row displayed
  `(3.29e − 18)` as the RE contribution at row 1. The BLUP for
  study_ID=3 was `9.74e-11`. Noether's protocol should have been:
  *extract one displayed BLUP from the rendered output, extract the same
  BLUP from `fit$random_effects$mu$terms`, expect_equal at 1e-9.* That
  one-line check fails instantly: `3.29e-18 ≠ 9.74e-11`. Bug closed in
  one round.
- **V2 Pat (reader flow)**. Pat *did* catch "widget equations omit the
  phylo random effect" as Flow Break 1 (BLOCKER) on 2026-05-28. Credit
  where due — Pat's prose-flow reading worked. But Pat's verdict came
  after V1 and V3 had already rubber-stamped, and the v0.22.1.1 fix only
  surfaced the symbolic equations (Tabs 1 + 2) without fixing the
  numerical expansion (Tab 3). That last mile — extending the numerical
  expansion to multi-tier fits — is what the current pass uncovered.

The common failure mode: **V1 and V3 wrote prose verdicts ("looks good",
"math renders") without running a single numerical extraction.** The
sister-package Fisher protocol pulls numbers from the fit and asserts
equality at 1e-9; the Cherry Club V-agents asserted nothing.

## Recommended Fisher protocol for symbolizer V-agents

Every widget audit MUST include the following five extractions, scripted,
non-skippable. Save as `tools/fisher-pass.R` per the import spec:

```r
fisher_pass <- function(sym, widget_html, observation_i = 1L) {
  fit <- sym$metadata$fit
  ex  <- sym$expanded
  # 1. Z_g shape vs nlevels(group_var)
  for (g in unique(sym$random_effects$group_var)) {
    nl <- length(unique(fit$data[[g]]))
    stopifnot(ncol(ex$Z_g_per_tier[[g]]) == nl)
    stopifnot(all(rowSums(ex$Z_g_per_tier[[g]]) == 1))
  }
  # 2. Every RE tier in $random_effects must round-trip through Z %*% u
  pred_re <- Reduce(`+`, lapply(sym$random_effects$group_var, function(g) {
    drop(ex$Z_g_per_tier[[g]] %*% ex$u_per_tier[[g]])
  }))
  X <- ex$X; beta <- ex$beta
  mu_predicted <- as.numeric(X %*% beta) + pred_re
  stopifnot(max(abs(mu_predicted - fit$obj$report()$mu)) < 1e-9)
  # 3. Displayed numbers in widget_html must match the fit
  displayed <- extract_displayed_numbers(widget_html)
  for (slot in names(displayed)) {
    actual <- get_actual_from_fit(slot, fit, ex)
    stopifnot(all.equal(displayed[[slot]], actual, tolerance = 5e-4))
  }
  # 4. Number of tiers in $random_effects MUST equal number of tiers in widget
  re_tier_count_fit    <- length(unique(sym$random_effects$group_var))
  re_tier_count_widget <- count_blup_columns_in_widget(widget_html)
  stopifnot(re_tier_count_fit == re_tier_count_widget)
  # 5. "Known residuals" — what this pass deliberately did NOT verify
  knitr::knit_print(list(
    knitr_caption = "Fisher pass: 5/5 checks ran; closure to 1e-9.",
    NOT_checked = c("PDF parity", "Cross-browser MathJax fallback", ...)
  ))
}
```

`fisher_pass()` is non-optional. Any V-agent verdict that does not include
the function's pass-line is invalid. This codifies what V1 and V3 each
skipped on this widget.

## Recommended fix scope (v0.22.1.4)

1. **Extend `drm_build_expanded()`** to populate per-tier slots:
   `ex$Z_g_per_tier = list(study_ID = …, phylogeny = …)` and
   `ex$u_per_tier = list(study_ID = …, phylogeny = …)`.
2. **Extract phylo BLUPs** from `fit$obj$report()$u_phylo`. Verify the
   tip-ordering convention (proposed: first `n_tips` entries are tips
   in `tree$tip.label` order — confirm by recomputing predicted μ̂ and
   checking closure to 1e-9 against `fit$obj$report()$mu`).
3. **Extend Tab 3 renderer** to iterate tiers and emit one Z·u block per
   tier, in `random_effects$group_var` order.
4. **Promote the boundary-pinned σ̂_p footnote** from §4.3 prose into the
   widget itself so a reader sees both the structural tier AND the
   numerical fact that this dataset collapsed σ̂_p to zero.
5. **Add `fisher_pass()` regression test** that runs on every drmTMB
   fixture with `length(unique(random_effects$group_var)) ≥ 2`.

## Known residuals (what this pass did NOT verify)

Per the gllvmTMB Codex pattern (state explicitly what was not checked):

- Did NOT visually inspect every tab of the rendered widget — only Tab 3.
- Did NOT verify the marginal-covariance block from v0.22.1.2 — only the
  expansion block.
- Did NOT exercise this protocol on other multi-tier drmTMB fits in the
  test suite — only the meta-multilevel fixture.
- Did NOT exercise on brms / metafor / MCMCglmm Faces of the same article
  (§4.4 / §4.5).
- Did NOT verify cross-browser MathJax rendering — only Chrome via the
  preview MCP.
- Did NOT run on a fit where the second tier is the iid one (e.g.
  `phylo() + (1|year)` instead of `(1|study) + phylo()`) — V-agents need
  to be paranoid about ordering.
- The Codex CLI Fisher pass was attempted via the `codex:codex-rescue`
  subagent but blocked by version mismatch (CLI v0.120.0 vs backend now
  routing `gpt-5.5`). This Claude-authored pass substitutes; the live
  Codex demo deferred until the user upgrades the CLI.
