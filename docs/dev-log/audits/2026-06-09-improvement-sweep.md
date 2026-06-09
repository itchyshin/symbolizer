# Documentation improvement sweep — 2026-06-09

Full-site multi-agent sweep of the deployed pkgdown site + docs to find
**improvement opportunities** (the site is green and bug-audited; this is
polish/clarity/consistency, not blockers). Protocol: v0.21-redo Phase-0a.

## Method (members + lenses)
- **Wave 1 — content lenses (5 parallel member-agents, live pages via WebFetch):**
  onboarding (home/index/get-started/ladder), families/factors/variance-components,
  drmtmb/gllvm/compare, structural-dependence/meta-analysis, reference/roadmap/README.
  Lenses: reader-flow (Pat), math-content correctness (Noether), consistency, completeness.
- **Wave 2 — Florence visual (orchestrator, preview MCP on built docs; rendering == live):**
  home + families widget screenshots; rendered-DOM health metrics on the 9 articles.
- **Wave 3 — Twin (PDF parity):** `pdftotext` on fig-lognormal / fig-poisson.
- **Rose reconciliation:** clustered + ranked below.

**Method notes / false positives caught (honesty):** a `fetch()`+DOMParser pass
was discarded — it reads *source* HTML (pre-KaTeX), so its "raw-LaTeX-leak"
counts were false; the real rendered-DOM check (123–208 `.katex`, 0 raw `$$`)
is authoritative. One flagged paragraph (`\mathbf M` in `innerText`) was KaTeX's
hidden MathML annotation bleeding into text extraction, not a visible bug
(confirmed `isKatexRendered:true`).

## Confirmed HEALTHY (no action)
- **Visual/rendering:** home has no hero/logo overlap; dev-status badges green;
  families/structural-dependence widgets render cleanly (KaTeX math, in-widget
  "Coefficient reading" callout, Lognormal⟺Normal bridge, `ℝ¹⁰⁰` dims, PDF button).
  Zero duplicate IDs across all 9 article pages; zero real raw-LaTeX leaks; no red
  `\boldsymbol`; matrices fit (only a 42px code-block scroll on structural-dependence).
  Every historical visual bug (B2/B3/B24/B27/AA, red-`\boldsymbol`) is ABSENT.
- **PDF/HTML parity (Twin):** PDFs carry all three views + are family-aware
  (Lognormal back-transform `E[y]=exp(μ̂+σ̂²/2)`; Poisson `μ̂=exp(η̂)`, no additive ε).
  The old B57–B64 content-drop + B1/B37/B53 family-blindness are fixed.

## HIGH value
1. **Entry-point inconsistency (cross-surface).** Home/README + get-started call
   `symbolize()` "the single entry point"; the reference index + `explain()` help
   call `explain()` "the recommended entry point for first-time users." Three
   surfaces disagree on the front door. → Lead onboarding with `explain(fit)`
   everywhere; introduce `symbolize()` as the object builder underneath.
2. **README "Tiny example" is non-runnable.** It uses `drmTMB` (non-CRAN, most
   readers can't run) and `symbolize()` (not the advertised `explain()`). → Lead
   with a base-R `lm()`/`glm()` + `explain(fit)`; keep `drmTMB` as the "scales up" follow-up.
3. **`explain()` + `symbolize()` reference pages lack runnable examples.** The
   marquee entry point is undemonstrated (no `@examples`/`@seealso`). → Add base-R
   `@examplesIf requireNamespace(...)` + `@seealso`. NOTE: needs roxygen2 8.0.0
   installed (pkg pins 8.0.0; installed is 7.3.2) — same blocker as CRAN-prep item 5b.
4. **Articles index cards mostly have empty descriptions.** The primary discovery
   surface shows bare titles. → Add `description:` to each vignette YAML front matter.
5. **Beta prose contradicts its own widget (correctness).** families prose: `exp(β)`
   = "odds ratio of the **success probability**" (binary framing); the widget +
   `interpretation-templates.csv` correctly say "odds ratio for the **mean
   proportion** μ/(1−μ)" and warn it is NOT a binary trial. → Fix the prose +
   inline example to "mean proportion."
6. **Cross-package agreement overclaims (correctness/honesty).** structural-dependence
   calls σ̂²_p values 26% apart "the same in expectation" and H² spanning 0.70–0.82
   agreement; meta-analysis says glmmTMB "reproduces the math" despite a ~40% τ̂² gap
   vs metafor without naming the likely cause (ML vs REML). → Honest framing + a
   small per-package comparison table; name ML/REML (verify the cause).
7. **gllvm §9 illustrative numbers don't match the displayed Tab-3 output
   (agent-reported, verify).** The Ψ_B example vector and the communality "high
   t1 / low t3" narrative cite values that don't match the rendered matrix/accessor
   output (where t2,t5 collapse and t4 is the low one). → Reconcile to the actual
   fit, or mark as a different seed.
8. **structural-dependence forward-links a "v0.22 phylogenetic meta-analysis" as
   future work, but meta-analysis §4 already ships it** — stale/contradictory
   cross-ref. → Replace with a live `vignette("symbolizer-meta-analysis")` link.

## MEDIUM value
- "μ_i — conditional mu of y" gloss used identically for Poisson/Beta/Lognormal —
  three different semantics (E[y] / logit / E[log y]); imprecise for Lognormal.
  → per-family gloss wording.
- Count-ICC asymmetry: binomial gets a latent-scale ICC, counts are refused with no
  acknowledgement that a latent/log-scale count ICC exists (Nakagawa & Schielzeth).
  → one explanatory sentence.
- Beta σ-vs-φ: σ overloaded for the precision parameter; the notation contract
  reserves φ. → per-family symbol allocation.
- `compare` AIC delta sign framing invites a sign-inversion misread. → restate
  `delta = AIC(right) − AIC(left)` with the direction spelled out.
- Both cross-package articles lack a "which package should I pick?" decision table.
- Identifiability-caveat asymmetry: structural-dependence warns the phylo/non-phylo
  variance split is weakly identified; meta-analysis §4 fits the same structure
  (H²≈0.07) with no caveat. → add the caveat + cross-ref.
- Terminology drift: "structured symbolic model" vs "…specification" (3 phrasings);
  occasion/session/obs (gllvm); h²/H²/λ (cross-article heritability symbol).
- Reference index: six "Internal:" groups inline-inflate the index; two have no
  `desc`; the "See the data flow" group desc omits `as_pdf_three_views`.
- Capability count: README "14 fitted-class methods" vs ~15 `symbolize.*` reference
  rows — recount and source from `capabilities.csv` (verify).
- families/factors lack the point-estimates-only caveat that variance-components states.
- Gamma "the variance scales as μ²σ², not log(Y)" — compares a variance to a
  transformed variable; rephrase to contrast like-with-like (CV interpretation).
- ladder title/slug: page titled "Building up: from lm to location-scale" but
  referred to as "the ladder" everywhere — reconcile the name.

## LOW value / polish
- Verify every `vignette("…")` cross-ref slug resolves (get-started + ladder).
- Grade the "Deep dives" article ordering to match the ladder's "read next" pointers.
- 42px horizontal scroll on one structural-dependence code block.
- README vs roadmap reword the same five status-word definitions differently.
- Per-section pedagogy adds: show the ICC formula; introduce the "ladder/rung"
  metaphor up front; one-line bridge before Rung 4 (location-scale); a
  sum-to-zero/Helmert contrast callout in factors.

## Recommended sequencing
The quick, high-leverage wins that need no model refits: #1 (entry-point), #2
(README example), #4 (card descriptions), #5 (Beta wording), #8 (stale forward-link),
plus the MEDIUM terminology/gloss items — all are CSV/Rmd/YAML prose edits. #3
(reference examples) is gated on roxygen2 8.0.0. #6 and #7 should be verified
against a fresh fit before editing (they touch reported numbers).
