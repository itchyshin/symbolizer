# V1 Florence-lens audit — index.html — 2026-05-26 overnight

Lens: article ordering, navigation, card layout, link integrity, claim-vs-content match.
Surface: `http://localhost:8766/articles/index.html` on `symbolizer-pkgdown` (serverId `c2648b71`).

## Methodology

- `preview_list` → server running on port 8766. Viewport set to 1280×1200.
- `preview_eval` to enumerate `<h3>` group headers, `<dl>/<dt>/<dd>` card structure, and link `href`s. `document.querySelectorAll('.section h2').length` returns 0 (pkgdown 2.1.3 uses `<h3>` group headings on the articles index, not `<h2>` inside `.section`). Counted 2 group `<h3>` and 13 links via `a[href$=".html"]` (link count includes navbar items + 7 article links).
- Per-card HEAD fetch (status 200/404) against `http://localhost:8766/articles/<slug>.html`.
- For each listed card, fetched the target article and read its `<h1>` to check claim-vs-content match.
- Cross-referenced against `_pkgdown.yml` (4 declared groups) and `vignettes/` (9 `.Rmd` sources).
- `preview_screenshot` to confirm logo collision.

## Article enumeration in display order

Two group headings rendered: "Get started" and "Where we're going".

| Group | Order | Card title | href | Target HEAD | Card description |
|---|---|---|---|---|---|
| Get started | 1 | Get started with symbolizer | symbolizer.html | 200 | *(empty `<dd>`)* |
| Get started | 2 | Understanding a drmTMB fit with symbolizer | symbolizer-drmtmb.html | 200 | *(empty `<dd>`)* |
| Get started | 3 | Reading factors, dummies, and interactions | symbolizer-factors.html | 200 | *(empty `<dd>`)* |
| Get started | 4 | A tour of non-Gaussian families | symbolizer-families.html | 200 | *(empty `<dd>`)* |
| Get started | 5 | Latent variables in ecology: a gllvmTMB worked example | symbolizer-gllvm.html | 200 | *(empty `<dd>`)* |
| Get started | 6 | Comparing two symbolized models | symbolizer-compare.html | 200 | *(empty `<dd>`)* |
| Where we're going | 1 | Roadmap and capability matrix | symbolizer-roadmap.html | 200 | "Where symbolizer is today, where it's going, and what every Stable / First slice / Planned status word actually means." |

All 7 listed targets exist (HTTP 200). All 7 article `<h1>` strings exactly match the card titles — Pattern F (title-vs-content drift) is **ABSENT** for the listed articles.

## Catalog cross-reference

- **B9 article ordering**: catalog wording is "Building up precedes canonical Get started with symbolizer". In the rendered build, "Get started with symbolizer" is the FIRST card under the FIRST group — i.e. no "Building up" / ladder card appears before it. So B9 as written is **ABSENT** in this build — but only because the underlying cause is worse: the canonical ladder vignette (`symbolizer-ladder.Rmd`, declared in `_pkgdown.yml` as the FIRST entry of the "Get started" group) was never built into `docs/articles/`. See B97_index_a.
- **B91 / B93 version drift**: **PRESENT**. Navbar `<small class="nav-text text-muted me-auto">` reads **0.14.2**, while `DESCRIPTION` is at **0.20.2** (6 minor versions stale). HTML built before the v0.20.x reorganization.

## NEW defects (not in B1–B96)

- **B97_index_a — missing built vignettes (`ladder`, `meta`)**. `_pkgdown.yml` declares groups "Get started" (`symbolizer-ladder`, `symbolizer`), "Deep dives" (drmtmb, factors, families, gllvm, compare), "Cross-package bridges" (`symbolizer-meta`), "Where we're going" (roadmap). `vignettes/symbolizer-ladder.Rmd` and `vignettes/symbolizer-meta.Rmd` exist as source but are NOT built into `docs/articles/` (both HEAD → 404 on `symbolizer-ladder.html` and `symbolizer-meta.html`). Index page therefore omits the canonical 4-rung intro and the meta-analysis bridge entirely. Evidence: `ls vignettes/` shows the two `.Rmd` files; `ls docs/articles/` does not show the corresponding `.html`.

- **B97_index_b — `_pkgdown.yml` group structure collapsed into two groups in rendered output**. The yaml declares 4 group titles; rendered HTML has only 2 `<h3>` tags ("Get started", "Where we're going"). All 5 "Deep dives" articles and any built "Cross-package bridges" articles are flattened under "Get started". This makes the page list 6 articles under one heading without typographic separation. Evidence: `grep "<h3>" docs/articles/index.html` returns exactly two matches.

- **B97_index_c — empty `<dd>` descriptions on every Get-started card**. The "Get started" group's `desc` from `_pkgdown.yml` ("Start here. The ladder builds up from lm() to location-scale on one shared dataset.") is NOT rendered as a group blurb, and the per-article `<dd>` blocks are empty strings for 6 of 7 cards. Only the Roadmap card has a non-empty `<dd>`. Cards are therefore title-only links with no orientation cue.

- **B97_index_d — hexagon logo overlaps article list on the index page**. The page-header places `img.logo` at boundingBox `{x: 476, y: 80, width: 400, height: 400}` on a 1280-wide viewport, while the article list runs from x≈125 to roughly y=500. The 400px logo sits in the right half of the content column and visually crowds the cards (see screenshot). Affects the articles index specifically (not other pkgdown pages — to be confirmed by V2 in their lens).

- **B97_index_e — navbar "Get started" link points to `articles/symbolizer.html`, not the new canonical ladder**. `_pkgdown.yml` `navbar.left` resolves "Get started" to the first article of the first group. Because `symbolizer-ladder` is missing from the built docs, the navbar's "Get started" entry currently points to the basic `symbolizer.html` rather than the 4-rung ladder. After B97_index_a is fixed, the "Get started" nav link will quietly change targets — worth flagging now so the change is intentional.

## Method failures

- None. All planned protocol steps (navigate, enumerate, HEAD-check, h1-cross-check, version inspect, screenshot) executed without tool error.

result: V1 audit complete — B91/B93 version drift PRESENT (navbar 0.14.2 vs DESCRIPTION 0.20.2); B9 as catalogued ABSENT because root cause is worse — 5 new defects B97_index_a..e covering missing built vignettes (ladder + meta), collapsed group structure, empty card descriptions, logo overlap, and stale navbar Get-started target. Report at /Users/z3437171/Dropbox/Github Local/symbolizer/docs/dev-log/figure-audits/phase0a-index/V1-florence-lens-report.md.
