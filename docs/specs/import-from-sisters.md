---
name: import-from-sisters
applies_to: symbolizer-wide discipline (AGENTS.md, tools/, V-agent dispatch, after-task)
status: draft
owner_pattern: discipline-meta (not a bug pattern; a process pattern)
last_review: 2026-05-28
---

# Import-from-sisters: discipline patterns symbolizer must adopt

## Why this exists

On 2026-05-28 the maintainer shipped two embarrassing bugs in the v0.22.1.x
phylo-multilevel widget:

1. **Z_g bug** — `drm_build_expanded()` built Z via
   `model.matrix(~ 0 + g_var)` without `factor()` coercion. For numeric
   `study_ID`, this produced a 164×1 column of literal integer values
   `[3, 3, 3, ..., 147, 147]` instead of a 164×39 one-hot incidence matrix.
   Latent in the extractor since v0.1. Fixed in `5586911` (v0.22.1.3).
2. **Missing phylo tier** — `drm_build_expanded()` reads only
   `re_per_entry[[which(has_re)[1L]]]`, so for any multi-tier fit the
   second tier is silently dropped from Tab 3's numerical expansion. The
   article's central thesis (phylogenetic multilevel) is invisible in the
   widget. NOT YET FIXED.

Both bugs were rubber-stamped by the V1 Florence (visual) and V3 Noether
(math) Cherry Club V-agents. The maintainer's diagnosis:

> "Think Codex team — Codex team even better than the Sherry Club team.
>  There's much to learn there."

Four parallel scouts (drmTMB, glmmTMB, gllvmTMB, Codex live demo) returned
on 2026-05-28. Three sister-package reports are saved under
`docs/dev-log/figure-audits/v0.22.1-meta-phylo/` and on the Agent task
output. The Codex CLI live demo was blocked by a CLI version mismatch
(codex-cli 0.120.0 vs backend `gpt-5.5`); a Claude-authored Fisher pass
substitutes (`claude-fisher-audit.md`).

This spec lists the patterns symbolizer is missing, in priority order.

## Contract (what MUST hold after this import)

1. **Symbolizer ships a `tools/` directory** (currently does not exist) with
   at least the four scripts in §1 below.
2. **`AGENTS.md` registers ≥ 8 standing review roles**, not just V1/V2/V3.
   Specifically: Fisher (numerical inference), Gauss (numerical stability),
   Curie (test fidelity), Grace (rendered-output evidence), Noether (math
   correctness), Florence (visual rendering), Pat (reader flow), Rose
   (cross-doc consistency). Each role has a one-sentence verification
   protocol; the protocol is non-skippable.
3. **`docs/dev-log/after-task/_TEMPLATE.md` exists** with the gllvmTMB
   10-section structure including §3a Decisions and §7a Issue Ledger.
4. **`docs/dev-log/figure-audits/<release>/<surface>-fisher-pass.md`**
   exists for every shipped widget. The Fisher pass file enumerates every
   displayed number, its actual value from the fit, the diff, and a
   pass/fail. Without this file, the release does not ship.
5. **`drm_build_expanded()` (and any sibling extractor) delegates Z
   construction** to a glmmTMB-style helper that factor-coerces upstream
   of `model.matrix`. (The architecturally cheapest place to fix the bug
   class permanently is to mirror `reformulas::mkReTrms`.)
6. **`.codex/agents/*.toml`** (or equivalent registry) is added even if
   Codex is not always available. The structure documents which reviewer
   roles Codex owns when available, so future maintainers can wire it in
   without rediscovering the pattern.

## Patterns to import (priority order)

### Priority 1 — kill the Z-matrix bug class at the source

**Source**: glmmTMB scout, Pattern 1 + 6.
**File reference**: `glmmTMB/R/glmmTMB.R:725-727` and `reformulas:::mkBlist`
(first line: `frloc <- factorize(x, frloc)`).
**Symbolizer fix**: rewrite `drm_build_expanded()` to delegate Z
construction to `reformulas::mkReTrms` (already an `lme4` dependency we
get transitively). The factor coercion happens INSIDE the helper, so
`model.matrix(~ 0 + g)` is never called on a raw numeric `g`. This
eliminates the entire bug class without requiring a test to guard it.

**Acceptance**: passing a numeric `study_ID` to the extractor and getting
a `n × k` one-hot Z back is structurally guaranteed, not test-guarded.

### Priority 2 — Fisher protocol as a non-skippable V-agent gate

**Source**: drmTMB scout Pattern 2 + 5; gllvmTMB scout Pattern 3 + 8;
glmmTMB scout Pattern 3.
**File references**:
- `drmTMB/AGENTS.md:132` (Fisher role definition)
- `drmTMB/tests/testthat/test-meta-known-v.R:237`
  (`expect_equal(length(tau_hat), nlevels(fit$data$id))`)
- `gllvmTMB/tests/testthat/test-extractors-extra.R:126-135`
  (`L <- fit$report$Lambda_B; expect_equal(diag(L%*%t(L))/diag(S), …, tolerance=1e-10)`)
- `glmmTMB/tests/testthat/test-basics.R` (numeric BLUP locks at tol=1e-5)

**Symbolizer adoption**:

1. Add `tools/fisher-pass.R`. Function `fisher_pass(sym, widget_html,
   observation_i = 1L)` runs five extractions:
   - Z_g shape per tier vs `nlevels(group_var)`
   - Every RE tier round-trips through Z %*% u to closure ≤ 1e-9
   - Every displayed widget number rounds-back to the fit at tol 5e-4
   - `length(unique(random_effects$group_var)) == count_blup_columns_in_widget`
   - "Known residuals" log: what was deliberately NOT checked

2. Add to `AGENTS.md`:
   > Fisher is a named standing reviewer. Fisher's protocol is
   > `tools/fisher-pass.R`. No widget ships without a green Fisher pass.
   > Skipping Fisher = release does not ship.

3. Run Fisher pass on every widget in CI (or `make release-check`).

**Acceptance**: re-running this pass on the Z_g bug or the missing-phylo-tier
bug produces a non-zero exit and writes a NOT-OK line into the audit log.

### Priority 3 — expand the V-agent registry from 3 to 8 named roles

**Source**: drmTMB Pattern 2; gllvmTMB Pattern 8.
**File references**:
- `drmTMB/AGENTS.md` lines 116-147 (13 named perspectives + shared figure
  judgment lines 139-147)
- `gllvmTMB/AGENTS.md` lines 341-369 + `gllvmTMB/.codex/agents/*.toml`

**Symbolizer adoption**: rewrite `AGENTS.md` standing-reviewer block to:

| # | Role | Single-sentence protocol |
|---|---|---|
| 1 | Florence | Open the rendered HTML in a browser, click every tab, screenshot. No source-only verdicts. |
| 2 | Pat | Read the rendered widget cold. Write a one-sentence takeaway. If the article's thesis is invisible in the widget = reject. |
| 3 | Noether | For every formula in the widget, write its index-form and matrix-form by hand and compare to what the renderer emitted. |
| 4 | **Fisher (NEW)** | Run `tools/fisher-pass.R`. Every displayed number round-trips to the fit at tol 5e-4. Every Z·u closes to 1e-9. State Known Residuals. |
| 5 | **Gauss (NEW)** | Numerical stability — check no `NaN`, no `Inf`, no exponent over ±20, no boundary-pinned parameter shown without footnote. |
| 6 | **Curie (NEW)** | "Tests of the tests": every new test must satisfy ONE of (a) failure-before-fix demo, (b) boundary case, (c) feature combination. No happy-path-only tests. |
| 7 | **Grace (NEW)** | Rendered-output evidence: every NEWS claim has a checked-in PNG screenshot of the rendered widget proving the claim. No prose-only claims. |
| 8 | Rose | Cross-document consistency. Reads the four reviewers above + scans `R/`, vignettes, NEWS, `inst/extdata/*.csv` for contradictions. Reconciles. |
| 9 | Twin | PDF/HTML parity (already in spec — keep). |

**Acceptance**: every PR description names which 8 reviewers ran. Missing
reviewer name = release does not ship.

### Priority 4 — after-task template with §7a Issue Ledger + Known Residuals

**Source**: drmTMB scout Pattern 4; gllvmTMB scout Patterns 1 + 2 + 5.
**File reference**: `gllvmTMB/docs/dev-log/after-task/_TEMPLATE.md` +
`gllvmTMB/docs/design/10-after-task-protocol.md` lines 266-311 (Tests of
Tests) + lines 94-160 (Consistency Audit with verbatim `rg` patterns).

**Symbolizer adoption**: create
`docs/dev-log/after-task/_TEMPLATE.md` with sections:

1. Goal (1-2 sentences)
2. Implemented (bullet list)
3. **§3a Decisions and Rejected Alternatives** (Memory-OS discipline)
4. Files touched (literal paths)
5. Checks run (literal commands, exact `rg` patterns)
6. **Tests of the Tests** — every new test demonstrates failure-before-fix
   OR boundary case OR feature combination, not happy path
7. **§7a Issue Ledger** (closed/updated/opened/cross-package/explicitly-not-relevant)
8. Consistency Audit (verbatim `rg` patterns + one-line verdicts)
9. **What Did Not Go Smoothly** (the explicit blind spots)
10. **Known Residuals** — what this close-out DELIBERATELY did NOT verify
11. Team learning

**Acceptance**: `tools/check-after-task.R` refuses release if §3a, §7a,
"Tests of Tests", "Known Residuals" are missing or blank.

### Priority 5 — `tools/` enforcement scripts

**Source**: drmTMB scout Patterns 5 + 6 + 9 + 10.

Symbolizer currently has no `tools/` directory. Port from drmTMB:

| Script | Purpose |
|---|---|
| `tools/fisher-pass.R` | Priority 2 above |
| `tools/install-smoke.R` | After install, fit a smoke model, assert dims, assert exported names |
| `tools/codex-checkpoint.R` | Per-session checkpoint (git status, diff, check-log, after-task) |
| `tools/check-florence.R` | Greps for `Rose approved:` line in after-task |
| `tools/check-after-task.R` | Refuses release if §3a/§7a/Tests-of-Tests/Known-Residuals missing |
| `tools/rose-pattern-scan.R` | Existing-bad-pattern lint (extending the v0.21-redo design) |
| `tools/check-dom-uniqueness.R` | Pattern M (DOM IDs unique) |
| `tools/check-mathjax-loaded.R` | Pattern L (MathJax in `<head>`) |

**Wired together via `Makefile` `release-check` target** — adapt the
v0.21-redo design (already in `.claude/plans/`).

**Acceptance**: `make release-check` exits non-zero if any of the eight
above fail. No release ships without `make release-check` passing.

### Priority 6 — `.codex/agents/` Codex persona registry (stub)

**Source**: drmTMB scout Pattern 8 (10 personas); gllvmTMB scout
characterization of Codex review style.

Even though my local Codex CLI is currently version-blocked, the
discipline pattern stands: configure Codex as a parallel review channel
with structured per-role TOML files. Future maintainers can wire it in
without re-deriving the pattern.

**Symbolizer adoption**: create skeleton `.codex/agents/` with at minimum
`reviewer.toml` (Noether/Fisher hybrid) and `systems-auditor.toml`
(Rose). Cargo-cult the structure from `drmTMB/.codex/agents/*.toml`,
adjust the prompts to symbolizer's surface (widgets, CSV templates,
extractors).

**Acceptance**: directory exists, files have schema-valid TOML, prompts
mention symbolizer-specific surfaces. Actual Codex dispatch deferred
until the CLI version mismatch is resolved.

## Verification

| Spec clause | Enforced by |
|---|---|
| Contract clause 1 (`tools/` exists with ≥ 4 scripts) | `make release-check` |
| Contract clause 2 (≥ 8 named roles in AGENTS.md) | manual review at PR time |
| Contract clause 3 (after-task `_TEMPLATE.md`) | `tools/check-after-task.R` |
| Contract clause 4 (every widget has Fisher pass file) | `tools/fisher-pass.R` + `make release-check` |
| Contract clause 5 (`reformulas::mkReTrms` delegation) | new test in `test-symbolize-drmtmb-Zg-numeric-group.R` |
| Contract clause 6 (`.codex/agents/`) | repo lint: directory present, ≥ 2 TOML files |

## Counter-examples (the two bugs that motivated this spec)

- **Z_g bug** (v0.22.1.3, fixed via factor-coercion):
  Would have been impossible under contract clause 5 (delegate to
  `reformulas::mkReTrms`). Would have been caught in seconds under
  contract clause 4 (Fisher pass extracts `Z_g` shape, compares to
  `nlevels(group_var)`, fails). Would have been caught by named-Florence
  visual check under contract clause 2.
- **Missing phylo tier** (NOT YET FIXED):
  Would have been caught under contract clause 4 (Fisher pass clause:
  `re_tier_count_fit == count_blup_columns_in_widget`; 2 ≠ 1, fail).
  Would have been caught under contract clause 2 by named-Pat reading the
  widget for the article's thesis (already caught it on the prose level
  but rubber-stamped at the widget level — the Fisher numerical check
  closes the gap).

## Implementation slice plan (v0.22.2-discipline)

Per maintainer's "do all six" answer on 2026-05-28:

| Step | Slice content | Estimated effort |
|---|---|---|
| 1 | Port `tools/` scripts (Priority 5) + Makefile | 1 session |
| 2 | Rewrite `AGENTS.md` standing reviewers (Priority 3) | 0.5 session |
| 3 | Write `_TEMPLATE.md` (Priority 4) | 0.5 session |
| 4 | Create `.codex/agents/` skeleton (Priority 6) | 0.5 session |
| 5 | `drm_build_expanded()` → `reformulas::mkReTrms` (Priority 1) | 1 session (includes Z_phylo extraction since multi-tier falls out naturally) |
| 6 | `tools/fisher-pass.R` against current widgets (Priority 2) | 1 session (will surface more bugs; expected) |

**Each slice has its own multi-V audit, after-task report (using the new
template), and Fisher pass. No slice ships without all of the above.**

**Article-by-article audit comes AFTER the discipline import lands.**
With the Fisher protocol and the expanded reviewer registry in place,
the audit pass has the structural tools to actually catch bugs instead
of rubber-stamping. Surfaces in order:
symbolizer-meta-analysis.html (this one) →
symbolizer-structural-dependence.html → symbolizer-families.html →
symbolizer-gllvm.html → symbolizer-drmtmb.html → symbolizer-factors.html →
symbolizer-ladder.html → symbolizer.html (get-started) → index.html →
roadmap.html.

## Open items

- **Codex CLI upgrade**: codex-cli 0.120.0 does not support the backend's
  current `gpt-5.5` model. Maintainer-side action: `npx openai-codex@latest`
  or whichever update path is current. Until then `.codex/agents/` files
  are spec stubs, not live dispatch targets.
- **`reformulas::mkReTrms` dependency**: confirm symbolizer can depend on
  `reformulas` directly (it's an lme4 transitive dep; explicit Imports:
  is cleaner).
- **Fisher pass on existing widgets**: deliberately deferred until step 6.
  Expect to surface bugs on every existing widget that has multi-tier
  random effects or numeric grouping variables. Plan for the breakage.
