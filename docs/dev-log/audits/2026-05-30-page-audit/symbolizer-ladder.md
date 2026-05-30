# Page audit — symbolizer-ladder

Audited: `docs/articles/symbolizer-ladder.html` + `vignettes/symbolizer-ladder.Rmd` (2026-05-30, read-only).
Site version badge: 0.22.3. MathJax loaded site-wide.

## RENDERING
- [MAJOR] Bare `body_mass` in the rung 1/2/3 distribution lines renders malformed: source `body_mass \mid ...` (lines 191, 347, 503) has an unescaped `_`, so MathJax typesets it as italic *body* with subscript *mass* — rung 4 (line 595) correctly uses `\mathrm{body\_mass}`. Same response variable, three rungs, garbled rendering.
- [MAJOR] Page `<title>` and `<h1>` show literal backticks: "Building up: from `` `lm` `` to location-scale" (lines 8, 72) — YAML `title:` is plain text, pandoc does not render markdown, so the backticks surface in the browser tab and page heading.
- [MINOR] Rung 1–3 `\begin{aligned}` blocks (lines 190–194, 346–351, 502–508) lack `&` alignment markers, so equation lines center independently instead of aligning at `=`; the rung-4 three-views blocks do include `&` (e.g. line 707).
- [MINOR] Three-views widget tab `data-tab` keys are mislabeled vs their visible labels/content: key `eq` holds the "2. Matrix" panel and key `mat` holds the "3. Equations with data" panel (lines 680–684 vs 773, 836). User-visible behavior is correct (JS activates by positional index, DOM order matches labels); only the internal attribute names are swapped.

## MATH
- Rung 1 `\mu_i = \beta_0 + \beta_1 temperature_i` matches `lm(body_mass ~ temperature)`. ✓
- Rung 2 adds `+ \beta_2 [sex = M]` matching `+ sex`; reference level F stated. ✓
- Rung 3 adds `+ u_{site(i)}` plus `u_{site} ~ N(0, σ²_site)` matching `+ (1|site)`. ✓
- Rung 4 adds `\log(\sigma_i) = \gamma_0 + \gamma_1 temperature_i` (log-link sigma submodel) + retains `u_{site}` line, matching `drmTMB(..., sigma ~ temperature)`. ✓ No phantom terms at any rung.
- Different β₁ across fits (rung-1 lm slope 0.303 vs rung-4 matrix `0.3`) is correct — they are different models, not an inconsistency. ✓

## READER-FLOW
- Each rung has a clean one-sentence "What just got added" takeaway; prose and adjacent equations agree (e.g. "one new line — the log(σ) row" matches the rendered block). ✓
- Residual-SD interpretation (`exp(γ₁)` per °C, truth `exp(0.05)≈1.05`) is consistent between prose, the sigma interp table (0.0399), and the worked three-views numbers. ✓

## CONSISTENCY
- (folded into RENDERING MAJOR #1) `body_mass` symbol renders inconsistently across rungs 1–3 vs rung 4.
- "Skim the quickstart first" pointer → `../articles/symbolizer.html` resolves. ✓
- All four "Where to next" links (symbolizer-factors, symbolizer-families, symbolizer-meta-analysis, symbolizer-roadmap) and all reference links resolve to existing files. ✓
- No literal `\n`, no untyped `$$`, no duplicated widget DOM/ids, no stale version refs. ✓
