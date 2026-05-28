## V2 Pat audit — 2026-05-27 — symbolizer-structural-dependence.html

### Setup
- Server: `ec3a7713-8caf-4818-968e-5c1ce769e287` (port 8767, `symbolizer-hotfix`)
- URL: `http://localhost:8767/articles/symbolizer-structural-dependence.html?t=NEWTIMESTAMP`
- Viewport: 1400 × 900 (desktop)
- Navigation: cache-busted reloads; `document.body.style.transform = "translateY(-Npx)"` for scroll (window.scrollTo locked)
- Tab clicks: synthetic `tab.click()` works; the active tab updates the panel display correctly
- Source `.Rmd`: `vignettes/symbolizer-structural-dependence.Rmd`
- Rendered HTML inspected: `docs/articles/symbolizer-structural-dependence.html` (live)

### Three-sentence summary (mine, after reading)
This article teaches that the GLMM `b ~ N(0, σ²M)` becomes a phylogenetic / animal / spatial model only by changing the matrix M, and shows the same 60-species Pearson-correlation phylo-LMM fitted in MCMCglmm (all-nodes Ainv), brms (`gr(species, cov = A)`), and phylolm (Pagel's λ in the marginalised PGLS form). MCMCglmm gets a three-views interactive widget (index notation / matrix algebra / matrix-with-data) so the reader can see the same fit at three resolutions; brms and phylolm are "light" Faces relying on `symbolize()` metadata and `assumption_table()` for verification. The closing prose ties the marginal form back to the random-effect form via `C(λ) = λA + (1−λ)I`, `σ_p² = λσ²`, `σ_e² = (1−λ)σ²`, and the same λ is the phylogenetic heritability H² from the §"Animal-model unification" section.

That summary IS what the article teaches if a reader perseveres. Several reader-flow defects below stop a first-time reader from arriving at it.

### Skip-around test
- **Land on Face 3 (phylolm) from a search engine**: a reader sees the marginalisation prose (`Zr_i = β_0 + e'_i`, `e' ~ N(0, σ² C(α))`), the `C(λ) = λA + (1−λ)I` bridge, and the closed-form ML fit. They can follow the math, but `tree`, `dat`, `dat_pl` are pre-built objects from chunk 0; the `library(phylolm)` line is the only fresh import. The prose says "These will be very close to the MCMCglmm / brms variance-component estimates — try it" but the reader has no MCMCglmm / brms numbers on this scroll-screen — they'd have to scroll backward. The H² ↔ λ connection ("So λ = σ_p² / (σ_p² + σ_e²) — the phylogenetic heritability H² from §"Animal-model unification"") references a section that's BELOW this one in document order, so a reader who landed here can't follow the link backward in the prose narrative.
- **Land on Face 2 (brms)**: a reader sees `library(brms)`, `data2_list <- list(A = A_tips)`, `brm(Zr ~ 1 + (1 | gr(species, cov = A)), ...)`. `A_tips`, `dat`, `tree` are all pre-built and not redefined here. Worse, the `assumption_table(sym_brms)` output has the **status column clipped off the right edge** (overflow 48 px — confirmed via `scrollWidth=824 > parentWidth=776`). The Cinar et al. citation in note 1 above this section is "Cinar et al. 2021" but the bibliography entry is dated 2022.
- **Land on Animal-model unification**: brief and self-contained, but introduces `σ_A²` and `σ_e²` for h² when the §6 model used `σ_p²` and `σ_e²` — a reader who hasn't read §6 won't know whether σ_A here is the same as σ_p there. The cross-package "symbolize.MCMCglmm()" mention is a deep-dive pointer to a function that has no entry on this page.

### Code-paste test
- **MCMCglmm chunk**: needs chunk 0 to run first (`A_all`, `dat`). Then needs the ~40-line `shim_mcmcglmm()` helper to feed the widget. A reader running standalone gets a working MCMCglmm fit but no widget unless they also paste the shim.
- **brms chunk**: needs chunk 0 (`A_tips`, `dat`). Self-contained otherwise. Notable: `file = "fig-brms-phylo-cache"` is left in; this saves a cache file in the reader's working directory.
- **phylolm chunk**: needs chunk 0 (`dat`, `tree`). Self-contained otherwise.
- **Spatial chunk (§"Spatial: same grammar, different matrix")**: **NOT runnable**. Uses `sdmTMB` and `mgcv` without prior `library()`, references `dat_spatial` and `mesh` that are defined nowhere in the article. This is illustrative pseudocode in a chunk that looks runnable. See finding F9.

### Reader-flow findings

#### F1: §6 gloss table doesn't define the indices `i`, `k`, `k[i]`
- **Severity**: serious
- **Where**: §"Three packages, one phylogenetic LMM" — the "where:" table immediately after the model statement
- **What**: A first reader sees `Zr_i = β_0 + u_{p_{k[i]}} + e_i` and the gloss table defines 7 symbols (`Zr_i, β_0, u_{p_{k[i]}}, σ_p², A, e_i, σ_e²`) but does NOT define what `i`, `k`, or `k[i]` are. A biologist who knows lme4's `(1|species)` will guess that `i` is observation index and `k` is the number of species, but the leap from `(1|species)` to `u_{p_{k[i]}}` is exactly where new readers stumble. The "1-observation-per-species" nature of this particular fit happens to make `k[i] = i`, but the article uses general indexing as if there were repeated measurements — leaving the reader to figure out that `k = 60` from later context (`A k × k`).
- **Evidence**: Gloss table cell for `u_{p_{k[i]}}` reads "phylogenetic random effect, indexed by species k[i] for observation i — estimated (latent)". No row defines `i`, `k`, or `k[i]` as standalone indices.
- **Suggested fix**: Add a one-line note before the table: "Here `i` indexes observations (n = 60), `k = 60` is the number of species, and `k[i]` returns the species ID for observation `i`. In this dataset each species has one Zr so `k[i] = i`, but the indexing generalises to repeated measurements."

#### F2: §6 model notation does not match the widget notation
- **Severity**: serious
- **Where**: §6 model statement vs Tab 1 (Index) inside the three-views widget
- **What**: §6 introduces the model as `Zr_i = β_0 + u_{p_{k[i]}} + e_i` with `u_p ~ N(0, σ_p² A)` and `e_i ~ N(0, σ_e²)`. The widget Tab 1 then re-renders the model as `Zr_i | μ_i, σ_i ~ Normal(μ_i, σ_i²)`, `μ_i = β_0 + u_{species(i)}`, `u_species ~ N(0, σ_species² A)`. The mappings are:
  - `u_{p_{k[i]}}` (§6) ↔ `u_{species(i)}` (widget)
  - `σ_p²` (§6) ↔ `σ_species²` (widget)
  - `e_i, σ_e²` (§6) ↔ `σ_i` collapsed into the response distribution (widget)
  A reader who clicks the widget hoping to see the §6 model at the next resolution sees a re-parameterised model with different symbols, no transition note. The widget's "where:" gloss table re-defines the symbols from scratch, in conflict with the §6 gloss table.
- **Evidence**: DOM inspection of `#sym-mcmc-XXX-panel-idx` content shows `σ_species`, `σ_i`, `u_{species(i)}` notation; §6 H2 prose uses `σ_p`, `σ_e`, `u_{p_{k[i]}}`. The widget has its own independent gloss block (visible behind a `▾ where:` disclosure).
- **Suggested fix**: Either (a) re-key the widget templates to use the §6 symbols, or (b) add a one-paragraph "the widget uses package-style notation; here is the mapping" bridge between §6 and the widget.

#### F3: §6 model is tips-only (k = 60) but Tab 3 (Equations with data) shows all-nodes (116 dimensions)
- **Severity**: serious
- **Where**: §6 model statement says "`A` is the `k × k` tips-only phylogenetic correlation matrix"; Tab 3 displays `Z_{60×116}`, `û_{116×1}`, `A_{116×116}`.
- **What**: §6 promises the reader a tips-only `k × k` matrix where `k = 60`. The Tab 3 worked-arithmetic view, which is supposed to be the most concrete face of the model, suddenly shows 60-observation Z mapping into 116-dim u-vector against a 116×116 A. The three "trip-up" notes don't warn the reader that the widget uses the all-nodes augmentation MCMCglmm fits internally. Tab 3 also shows BLUPs for `Alcatorda` (= Alca torda, the great auk) — a species name; this is helpful, but Tab 3's worked equation `zr_1 = β̂_0 + û_Alcatorda + ε̂_1 = 0.366 + (−0.152) + (−0.0482) = 0.166` is in `k × 1 = 60 × 1` u-space conceptually but `116 × 1` in the matrix view that follows. The reader is silently asked to absorb the all-nodes augmentation here without it being flagged as "this is the all-nodes form §6 mentioned".
- **Evidence**: Tab 3 panel innerText: `𝒁_{60×116}`, `𝒖̂_{116×1} (BLUP)`, `Cov(𝒖̂) = σ_p² · [A_{116×116}]`.
- **Suggested fix**: Add a one-line caption above the widget: "The widget shows MCMCglmm's all-nodes internal parameterisation (60 tips + 56 internal nodes = 116 latent random-effect entries). This is the same model as §6 but in the parameterisation MCMCglmm actually fits — see §"Tips-only vs all-nodes" for why."

#### F4: Two `assumption_table()` outputs overflow horizontally, clipping the "status" column
- **Severity**: serious
- **Where**: Face 2 brms `assumption_table(sym_brms)` and Face 3 phylolm `assumption_table(sym_pl)`
- **What**: The Face 2 brms assumption table is 824 px wide in a 776 px container (48 px overflow); the Face 3 phylolm table is 786 px in 776 px (10 px overflow). The "status" column is on the right and gets clipped. Status is the pedagogical payload of this table — it tells the reader which assumptions are explicit vs follow from the formula vs the reader's responsibility. Clipping it makes the widget pointless for half of the rows on screen.
- **Evidence**: DOM `scrollWidth` vs `parentElement.clientWidth` for tables idx 4 (brms) and idx 6 (phylolm). Visual confirmation: screenshot of brms table shows "follows from t..." and "your_responsi..." truncated mid-word.
- **Suggested fix**: Add `df-print: paged` or shrink the column widths in the rendered table; OR wrap the table in a horizontal-scroll container with visible scrollbar.

#### F5: Citation year mismatch — "Cinar et al. 2021" in prose, "Cinar, O., ... (2022)" in references
- **Severity**: serious (citation integrity)
- **Where**: §6 trip-up note 1 cites "(Cinar et al. 2021, Eq. 1–10)"; References lists "Cinar, O., Nakagawa, S. & Viechtbauer, W. (2022). Phylogenetic multilevel meta-analysis: A simulation study on the importance of modelling the phylogeny. Methods in Ecology and Evolution, 13, 383–395."
- **What**: A reader who wants to check Eq. 1–10 in Cinar (2021) won't find a 2021 paper in the bibliography. The published MEE paper is 2022.
- **Evidence**: `document.body.innerText` searches for `Cinar`: two hits — "Cinar et al. 2021, Eq. 1–10" (prose) and "Cinar, O., Nakagawa, S. & Viechtbauer, W. (2022)" (refs).
- **Suggested fix**: Change in-text to "Cinar et al. 2022, Eq. 1–10" (verify equation numbers match the 2022 published version).

#### F6: Cross-references in prose are plain text, not hyperlinks
- **Severity**: serious (navigation)
- **Where**: Throughout — every `§"Animal-model unification" below`, `§"Tips-only vs all-nodes"`, `§"Face 3" Face below`, etc.
- **What**: I checked all `<a href="#...">` internal links inside the article body: the only ones are TOC sidebar anchors (with empty link text — these are autogenerated by pkgdown next to headings) and the "Skip three-views widget" link. The dozen-or-so `§"..."` cross-references in the prose are NOT clickable. A reader who reads "see § "Tips-only vs all-nodes" for why" or "see § "Face 3" Face below makes the bridge explicit" cannot click; they must scroll or use the right-sidebar TOC. For an article whose pedagogy depends on weaving forward and backward references, this is bad reader-flow.
- **Evidence**: `document.querySelectorAll('a[href^="#"]')` returns 15 links, all from sidebar TOC and "skip widget". Zero are in the prose.
- **Suggested fix**: Convert §"X" mentions to actual hyperlinks (Rmd: `[§ Tips-only vs all-nodes](#tips-only-vs-all-nodes)`).

#### F7: One cross-reference text doesn't match its target heading
- **Severity**: minor (broken-link adjacent)
- **Where**: §"Where the matrix comes from", final paragraph
- **What**: Prose says: "a result we'll return to in §"Tips vs all-nodes"". The actual section is heading-cased "Tips-only vs all-nodes". So even if F6 were fixed (links converted), this reference points to the wrong slug.
- **Evidence**: `document.body.innerText.indexOf('Tips vs all-nodes')` returns a hit in the §3 paragraph; H2 heading is "Tips-only vs all-nodes" (id `tips-only-vs-all-nodes`).
- **Suggested fix**: change `§"Tips vs all-nodes"` → `§"Tips-only vs all-nodes"` (and add hyperlink).

#### F8: Bridge prose ("try it") doesn't follow through with the worked numbers
- **Severity**: minor (pedagogy)
- **Where**: Face 3 phylolm, paragraph after `summary(fit_pl)`
- **What**: The bridge prose says: "take the estimated σ̂² and λ̂ from the summary above, then `sigma_p^2_hat = lambda_hat * sigma^2_hat` and `sigma_e^2_hat = (1 - lambda_hat) * sigma^2_hat`. These will be very close to the MCMCglmm / brms variance-component estimates (modulo MCMC sampling noise) — try it."
- The reader has σ̂² = 0.1410606 and λ̂ = 0.7632042 displayed above. The bridge gives them homework instead of showing the result. The worked numbers would be: σ_p² ≈ 0.108 (vs MCMCglmm 0.106; agree to 2%), σ_e² ≈ 0.0334 (vs MCMCglmm 0.0459, vs brms 0.0278; these don't agree — sampling noise plus prior choice). A reader who actually does the arithmetic discovers the discrepancy and is confused; a reader who doesn't, never sees the bridge close.
- The MCMCglmm heritability output also shows `heritability = 0.697`, which is NOT what `λ̂ = 0.7632` gives. The article's promise "λ = H²" doesn't reconcile with the displayed numbers; a careful reader notices the gap, an inattentive reader misses the verification entirely.
- **Evidence**: chunk 3 output: `variance_A = 0.106, variance_E = 0.0459, heritability = 0.697`. chunk 9 output: `phylo_param = 0.7632042`, `sigma^2 = 0.1410606`. brms `sd_estimate = 0.167, var_estimate = 0.0278` (chunk 7 output table).
- **Suggested fix**: Add a small comparison table after the bridge: "Translated to RE-form variances: σ̂_p² = 0.108 (MCMC: 0.106; brms: 0.136), σ̂_e² = 0.033 (MCMC: 0.046; brms: 0.028). Agreement is within MCMC sampling noise except brms's lower residual variance, which reflects the brms default prior on `sd`."

#### F9: Spatial code block is pseudocode that looks runnable
- **Severity**: serious (code-paste reliability)
- **Where**: §"Spatial: same grammar, different matrix"
- **What**: The code chunk shows `library(sdmTMB); fit_sp <- sdmTMB(y ~ 1, data = dat_spatial, mesh = mesh, ...); ...; library(mgcv); fit_gp <- gam(y ~ s(x, y, bs = "gp"), data = dat_spatial)` — `sdmTMB` and `mgcv` were not loaded earlier; `dat_spatial` and `mesh` are not defined anywhere. A reader who pastes this into RStudio gets `Error in dat_spatial : object 'dat_spatial' not found`. The chunk has no `eval = FALSE` styling, no callout warning that this is illustrative.
- **Evidence**: search for `dat_spatial` in article: only mentions in this one code chunk; no setup code defining it. `sdmTMB`, `mgcv` not in chunk 0 library() calls.
- **Suggested fix**: Either (a) build a tiny synthetic `dat_spatial` and `mesh` in this chunk before fitting; (b) mark the chunk as illustrative with `eval = FALSE` and a caption; (c) replace with `symbolize()` output snippets without showing a faux fit.

#### F10: "Three-views widget for the MCMCglmm fit" has no introductory or concluding prose
- **Severity**: serious (pedagogy)
- **Where**: H4 subsection "Three-views widget for the MCMCglmm fit" inside Face 1
- **What**: The subsection consists of: (a) a 40-line `shim_mcmcglmm()` helper function dump (internal plumbing); (b) the widget itself; (c) ONE sentence "The same extractor branch handles animal models (where A comes from a pedigree, not a tree) — see §Animal-model unification below." There is NO prose telling the reader:
  - What the widget is for (the article's headline pedagogical device)
  - Which tab to look at first (Tab 1? Tab 2?)
  - What synthesis they should leave with
  - That the shim function is internal plumbing they can ignore
  The widget appears, lives, dies without commentary. The §6 introduction promised "Face 1 (deep dive)" but the deep dive teaches MCMCglmm syntax via the code chunk — the widget reads like a bonus thing some reader might or might not explore.
- **Evidence**: DOM walk from H4 `#three-views-widget-for-the-mcmcglmm-fit` to the next H3/H2: the only `<p>` between the H4 and the widget is the "Download as PDF" button p; after the widget is the one-sentence about animal models.
- **Suggested fix**: Add a 2-3 paragraph intro before the widget: "What you're about to see is the same MCMCglmm fit at three resolutions. Tab 1 is index notation — what symbolize.MCMCglmm() generates by default, the per-observation reading. Tab 2 is the matrix form — what every textbook past Chapter 4 switches to. Tab 3 is the same matrix populated with your fitted values — useful for sanity-checking that the prediction X β̂ + Z û really equals the observed Zr. Browse the tabs; the takeaway is that the same fit can be read three ways without changing the model." The shim function should be moved to a collapsed `<details>` block or to an "If you want to know how the widget gets its data" appendix.

#### F11: Sidebar TOC doesn't list the three Face subsections
- **Severity**: minor (navigation)
- **Where**: Right-sidebar "On this page" TOC
- **What**: The sidebar lists H2 sections only. The Face 1 / Face 2 / Face 3 entries are H3 and don't appear. For an article whose body lives in three packages × three views, the reader's most likely navigation target is "jump to Face 3 phylolm", and that jump isn't in the sidebar.
- **Evidence**: TOC innerText: "The shared grammar / Where the matrix comes from / Three packages, one phylogenetic LMM / Animal-model unification / Tips-only vs all-nodes / Spatial: same grammar, different matrix / When unification breaks: identifiability / Forward links / References" — no Face entries.
- **Suggested fix**: Either promote Face headings to H2, OR configure pkgdown to show H3 entries in the page TOC (`toc-depth: 3`).

#### F12: σ-symbol drift across heritability output vs §6 gloss
- **Severity**: minor (notation consistency)
- **Where**: §6 gloss uses `σ_p²` and `σ_e²`; `sym_mcmc$metadata$heritability` output uses `variance_A` and `variance_E`; §"Animal-model unification" introduces `σ_A²`.
- **What**: The reader is asked to map `σ_p² ↔ variance_A ↔ σ_A²` and `σ_e² ↔ variance_E` mentally. The article unifies the phylogenetic and animal-model interpretation in §"Animal-model unification" but doesn't note that the `_A` ↔ `_p` mapping happens. A new reader sees "Heritability h^2 = sigma^2_A / (sigma^2_A + sigma^2_E)" in the chunk output and wonders if `sigma^2_A` is a typo or a new symbol — they have to scroll forward to §"Animal-model unification" to find the bridge.
- **Evidence**: chunk output: `variance_A ... variance_E ... Heritability h^2 = sigma^2_A / (s...`; §6 gloss: `σ_p²`, `σ_e²`; §"Animal-model unification": `u_a ~ N(0, σ_A² A)`, `h² = σ_A² / (σ_A² + σ_e²)`.
- **Suggested fix**: Footnote the chunk output: "The heritability uses `variance_A` (= σ_p²) and `variance_E` (= σ_e²) to match the animal-model convention; see §"Animal-model unification" for why phylogenetic and animal-model variance are the same object."

#### F13: Moura et al. (2021) cited in code comment but not in References
- **Severity**: minor (orphaned reference)
- **Where**: Chunk 0 code comment mentions "Moura et al. (2021)'s assortative-mating dataset"; the metadata for the dataset comes from `metadat::dat.moura2021`. References list includes Mizuno et al. (2026) but not Moura.
- **What**: A reader who wants the original data source has to either dig through Mizuno (2026)'s paper or chase the URL hint. Comparative-biology readers will recognise the dataset, but the article uses it as a teaching example and citing it would close the loop.
- **Evidence**: References list does not contain "Moura"; chunk 0 comment is the only mention.
- **Suggested fix**: Add to References: "Moura, A. E., et al. (2021). [Full title]. [Journal]." (the metadat help page should give the full citation).

#### F14: Prime mark `e'` introduced without explanation
- **Severity**: minor (pedagogy)
- **Where**: Face 3, marginal PGLS form: `Zr_i = β_0 + e'_i, e' ~ N(0, σ² C(α))`
- **What**: The §6 model used `e_i`. The marginal form uses `e'_i` with a prime, presumably to flag "this is the new residual = old residual + absorbed random effect". The article never tells the reader this. A reader has to infer that the prime distinguishes the two.
- **Evidence**: Face 3 paragraph: "phylolm absorbs u_p into the residual to give Zr_i = β_0 + e'_i, e' ~ N(0, σ² C(α))". No definition of the prime symbol.
- **Suggested fix**: Add "(the prime distinguishes the marginalised residual `e'` from the RE-form residual `e` — `e'_i = u_p_{k[i]} + e_i`)" right after introducing `e'`.

### Glossary check
Symbols introduced and where they're defined / used:

| Symbol | Defined in | Used in | Status |
|---|---|---|---|
| `Zr_i` | §6 gloss table ("Fisher-z transformed correlation") | §6, Face 1/2/3, widget | OK |
| `β_0` | §6 gloss table | §6, all Faces, widget | OK |
| `u_{p_{k[i]}}` | §6 gloss table | §6 only | drift to `u_p` (Face 3), `u_{species(i)}` (widget) |
| `σ_p²` | §6 gloss table | §6, Face 3 bridge | mapped silently to `variance_A` (chunk), `σ_species²` (widget), `σ_A²` (animal-model) |
| `A` | §6 gloss table | §6, all Faces, widget | OK; widget adds `A_{60×60}` (Tab 2) and `A_{116×116}` (Tab 3) without flagging dimension change |
| `e_i` | §6 gloss table | §6 | drift to `ε̂_i` (widget Tab 3), `e'_i` (Face 3 marginal) |
| `σ_e²` | §6 gloss table | §6, Face 3 bridge, Animal-model unif. h² | mapped to `variance_E` silently |
| `k`, `k[i]`, `i` | NOT defined | §6 model statement, `A_{k×k}` | F1 — orphan indices |
| `C(α)`, `λ` | Face 3 prose | Face 3 only | OK in scope, bridge prose is clear |
| `H²`, `σ_A²` | Animal-model unif. paragraph | Animal-model only | OK in scope, but the `σ_A² ↔ σ_p²` mapping is implicit |
| `M`, `Ω` | §"The shared grammar" Context/Symbol/encodes table | §"Shared grammar", §"Spatial" | OK |
| `T_ij`, `T` | §"Where the matrix comes from" | §3 only | OK |
| `M ≠ I` | §"Shared grammar" prose | §"Shared grammar" | OK |
| `u_p` (no index) | §"Animal-model unification" `u_a ~ N(0, σ_A² A)` | §"Animal-model unification" | OK as concept |
| `prime` on `e'` | NOT defined | Face 3 marginal form | F14 |
| `H²` vs `h²` | Animal-model unif. (capital H²) vs heritability output (lower h^2) | mixed | minor inconsistency |

Total: 7 symbols cleanly defined in §6, 4 indices not defined (F1), 4 cases of notation drift between the gloss and downstream Faces/widgets (F2, F12, F14), and 1 dimension drift between gloss `k×k` and Tab 3 `116×116` (F3).

### Cross-reference check

| Quoted in prose | Target heading | Resolves? | Hyperlink? |
|---|---|---|---|
| `§ "Tips vs all-nodes"` (in §3 final paragraph) | "Tips-only vs all-nodes" | text mismatch (F7) | no (F6) |
| `§ "Tips-only vs all-nodes"` (in §6 trip-up note 3) | "Tips-only vs all-nodes" | yes | no (F6) |
| `§Animal-model unification below` (after Tab 2 panel) | "Animal-model unification" | yes | no (F6) |
| `§ "Animal-model unification"` (in Face 3 bridge) | "Animal-model unification" | yes | no (F6) |
| `§ "Face 3" Face below` (in §6 trip-up note 3) | "Face 3 (light): phylolm::phylolm() — the marginal PGLS form" | yes | no (F6) |
| `§3` (in §6 gloss table for `A`) | refers to Hadfield & Nakagawa 2010 §3.2 (external) | external paper section, not internal | n/a |
| `§4` (in §"When unification breaks") | refers to Mizuno et al. 2026 §4 (external) | external paper section | n/a |
| `§"Tips vs all-nodes"` (in §3) | wrong slug (F7) | text mismatch | no |

Net: every quoted internal section reference is text-only (no hyperlink), one has the wrong target text (F7), but the targets all exist as headings. Two `§3`, `§4` refer to external paper sections — fine in context.

### What works well
1. **The Cinar / trip-up notes idea**: three numbered notes that pre-emptively address (a) σ_e² ≠ v_i (meta-analyst's confusion), (b) Moura data has v_i but we strip it (data-provenance honesty), (c) phylolm marginalises (the bridge to Face 3). This is genuinely good pedagogy for a reader who reads the notes carefully. A biologist who's been bitten by `metafor::rma.mv(V = vi, ...)` will appreciate note 1. The notes do their job — they just live in a wall of math where readers in skim mode may miss them. Severity of the missed-context risk is mitigated by the notes' presence; finding F8 (the bridge homework) and F12 (variance-component-symbol drift) survive even with the notes.
2. **The §"The shared grammar" table** (`Context | Symbol | What M encodes`) cleanly establishes the three families before any code. A reader who reads only §1–§2 leaves with the right one-sentence takeaway: "structural dependence = `M ≠ I` in `b ~ N(0, σ²M)`".
3. **The §"When unification breaks: identifiability" section** is well-targeted. The point that `σ_p²` and `σ_s²` are weakly identified when both phylo and non-phylo tiers share the same grouping column is exactly the practical pitfall users hit. Linking to `phylo_nonphylo_unidentifiable` in `warning_table()` closes the loop to the package's diagnostic.
4. **The Hadfield 2010 / Hadfield-Nakagawa 2010 references are well-placed**: chunk 0 names the all-nodes shim as "per Hadfield's course notes section 8.2.1", the §"Tips-only vs all-nodes" wraps with "Hadfield-Nakagawa equivalence". Provenance is honest.
5. **`set.seed(1)` + cache file for brms** make the article reproducible across renders. The deterministic data subset means the displayed numbers (`σ_p ≈ 0.325`, `λ̂ ≈ 0.7632`) are stable.
