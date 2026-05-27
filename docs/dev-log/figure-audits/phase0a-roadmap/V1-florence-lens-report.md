# V1 Florence-lens audit — symbolizer-roadmap.html — 2026-05-26 overnight

## Methodology

- `preview_list`: server `symbolizer-pkgdown`, serverId `c2648b71-cdbd-434d-b7ad-4fe48a1a9a1b`, port 8766.
- Viewport: 1280×1200; article column `clientWidth = 776 px` (`main.col-md-9`, max-width 800 px).
- Page `<title>` = `Roadmap and capability matrix • symbolizer`; `<h1>` matches.
- **No tabbed widgets, no math runtime in scope.** `document.querySelectorAll('table').length = 5`. No `[id^='sym-']` (no widget UI). Article is a flat pkgdown vignette of 5 prose-and-table sections.
- All 5 tables: `scrollWidth === clientWidth === 776 px`, **no overflow at 1280-px viewport**. No table is wrapped in `.table-responsive` but none needs it — B66/B69/Pattern V & W are ABSENT on this surface.
- Heading slugs all match TOC `href`s; no `\n` artifacts, no slug ugliness (Pattern AA / B75 ABSENT).
- Lens scope: table layout, status-word vocabulary, cross-references, claim/code drift suspicions for V3.

## Per-section findings

### Status vocabulary (table #0) and What's covered (tables #1, #2)
Five rows in #0 match the five allowed status words exactly: no trailing punctuation, no case drift. Tables #1 / #2 render cleanly; no LaTeX leaks; no column-width regression; status cells use only `Stable` and `First slice (vX.X)` (vocabulary-conformant). H2 reads "(v0.1 – v0.14.1)" — see Drift section.

### What's planned (table #3)
4 rows: `v0.15`, `v0.15.x`, `v0.16+`, `Considered`. Layout clean. Cross-reference concerns logged below.

### Release history (selected) (table #4) — one defect (visible to V1)
16 rows v0.1 → v0.14.1. Row `v0.7` `<td>` innerHTML: `glmmTMB Gaussian + <code>(1 \| g)</code> + <code>dispformula</code>`. Visible text reads `(1 \| g)` — the backslash before the pipe leaks through into the rendered `<code>` element. Confirmed by `document.body.innerText.match(/\\\|/g).length === 1`. Other rows (`v0.1` row's `(1 | group)`; tables #1 `metafor` row's `~ 1 | study / id`; #1 `lme4` row's `(1|g)/(1+x|g)`) all render with a clean pipe. The source Rmd likely escaped `\|` to survive a markdown-table cell, but inside an inline-code span the escape is preserved literally. New defect `B92_roadmap_A`. Pattern Z (rendered+raw LaTeX dupe) family — markdown-escape leak into inline code.

### API discipline (closing section)
Lists 14 core public functions including `expand()` and `as_html_three_views()`. Both are absent from the cross-cutting surfaces status table (#2). See `B92_roadmap_C`.

## Cross-reference / claim-drift suspicions (forward to V3 Noether)

V1-readable inconsistencies; V3 to verify against R source / NEWS.md.

1. **Roadmap currency lag (B91).** Navbar `0.14.2`; H2 reads "(v0.1 – v0.14.1)"; Release history terminates at v0.14.1; "What's planned" still describes v0.15 / v0.15.x / v0.16+ as future. Git context names commits 7ff958a, 517b2ee, e494651, 1d7c7eb, 4ba86e1 implying v0.20.2 has shipped. Either the pkgdown build is stale or the Rmd is overdue for refresh. → `B92_roadmap_B`. **V3: confirm against NEWS.md.**

2. **`propto()` framing drift.** Table #3 row `v0.16+` describes "`glmmTMB equalto() / propto() bridge – detect meta-analysis fit via glmmTMB and route through meta-analysis prose`" — i.e. `propto()` as the **meta-analysis** bridge. Recent commit v0.20.0 corrective release reframes `propto()` as the **phylogenetic** bridge. If the commit is canonical, the roadmap text is now wrong. → `B92_roadmap_D`. **V3 owns source check.**

3. **Phylogenetic flagship status understated.** Table #3 puts "Phylogenetic flagship (`phylolm`, `phyloglm`, `phyr::pglmm`, `sommer`)" under "Considered" (weaker than "Planned or reserved"). Recent commit "phylogenetic capability scaffold" indicates work has begun. → `B92_roadmap_E`.

4. **Cross-cutting surfaces ≠ API discipline list.** Table #2 lists 9 surfaces; API discipline names 14 functions including `expand()` and `as_html_three_views()` which are absent from #2. A reader scanning #2 will conclude `as_html_three_views()` is not yet covered, but the closing prose says otherwise. → `B92_roadmap_C`. **V3: verify whether `as_html_three_views()` is a "First slice" surface that just needs a roadmap row.**

5. **Status-tag inconsistency (minor).** Of the 8 "First slice" rows in table #2, only `model_card()` omits the parenthetical version tag. Style nit, not a defect.

## Catalog cross-reference (B1–B91 + Patterns A–FF)

- B1, B50–B64, B72–B74 (math/widget): NOT APPLICABLE (no widgets, no displayed math on this surface).
- B66, B69, Patterns V & W (table overflow / column-width regression): ABSENT.
- B70, Pattern X (ASCII-math placeholders in prose tables): ABSENT — pseudo-math like `bf(sigma ~ z)` and `nu ~ z` is wrapped in `<code>` deliberately (R syntax citation, not stranded ASCII math).
- B75, Pattern AA (heading slug artifacts): ABSENT.
- B91 (version drift): **PRESENT** — navbar `0.14.2`; roadmap content frozen at v0.14.1. See `B92_roadmap_B`.

## NEW defects

**B92_roadmap_A_pipe_escape** — Backslash-pipe escape leak in `<code>` cell. Release history row `v0.7` renders `(1 \| g)` instead of `(1 | g)`. Other rows (`v0.1`, `lme4`, `metafor`, `glmmTMB`) all render the bare pipe correctly. **Fix**: in `vignettes/symbolizer-roadmap.Rmd`, change the v0.7 release-history cell from inline-code with `\|` to inline-code with bare `|` (or use an HTML entity if a markdown-table column delimiter conflict drove the original escape). **Pattern Z subtype: markdown escape inside inline `<code>` leaks as literal text.**

**B92_roadmap_B_version_drift** — Navbar version `0.14.2`, H2 heading "(v0.1 – v0.14.1)", Release history terminates at v0.14.1, and What's planned still describes v0.15 – v0.16+ as future work. The git context provided to V1 (commits 7ff958a, 517b2ee, e494651, 1d7c7eb, 4ba86e1) implies the package has reached v0.20.2. Either the rendered docs site is from a stale pkgdown build or the Rmd is overdue for a content refresh. **B91 application.**

**B92_roadmap_C_surface_list_mismatch** — Cross-cutting surfaces table (table #2, 9 rows) omits `expand()` and `as_html_three_views()`, both listed in the API discipline closing paragraph as core public functions. Roadmap-internal inconsistency.

**B92_roadmap_D_propto_framing** — Roadmap describes `propto()` as the meta-analysis bridge ("detect meta-analysis fit via glmmTMB and route through meta-analysis prose"). Recent commit v0.20.0 corrective release reframes `propto()` as the **phylogenetic** bridge. **V3 must verify against R source which framing the code now realises.**

**B92_roadmap_E_phylo_understated** — "Phylogenetic flagship" sits under "Considered" in table #3, weaker than "Planned or reserved". Recent commit "phylogenetic capability scaffold" indicates work has begun. Status word may need to escalate to "Planned or reserved" or "First slice" pending V3 source check.

## What V1 did NOT do

- Did not read `R/` source (out of lens — flagged D and E for V3 Noether instead).
- Did not check PDF parity (V4 scope).
- Did not assess reading-order quality of the section ordering (V2 scope).
- Did not assess whether the five status words are conceptually well-chosen (V2/V3 scope).

## Summary

The roadmap article renders **layout-clean** on a 1280-px viewport — no table overflow, no slug artifacts, no widget dupes, no math leaks (none expected). The Florence-lens findings concentrate on one inline-code escape leak (`B92_roadmap_A`) and four claim/code drift signals (`B92_roadmap_B/C/D/E`) for V3 to ground-truth against NEWS.md and R source. The roadmap as a "claim/code drift detector" is itself drifting; refreshing it is overdue.
