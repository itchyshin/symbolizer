# Audit: symbolizer-variance-components

Read-only audit of `docs/articles/symbolizer-variance-components.html` against
`vignettes/symbolizer-variance-components.Rmd`. Four lenses: rendering, math,
reader-flow, consistency.

## Result

**Clean.** 0 blockers, 0 majors, 0 minors.

## Lens notes (all pass)

- **Rendering** — All math wrapped in `math inline` spans (`\(R\)`,
  `\(\pi^2/3\)` x2); no un-typeset LaTeX in body, no literal `\n`. Variance
  partition is a real `<table>` (thead/tbody), not a `<pre>` dump. 5
  `sym-vc-panel`s = one per output chunk; no widget DOM duplication.
- **Math** — Gaussian data-scale ICC 1.62/(1.62+0.715)=0.694 matches bar
  (69.4%/30.6%) and rendered ICC; code `s2_g/(s2_g+resid)` confirms
  (R/variance-partition.R:190). Binomial latent residual pi^2/3 logit / 1
  probit (lines 226, 228); required "not a proportion of variance in the
  observed outcome" caption present verbatim. Poisson -> NA+reason;
  location-scale and >1 RE -> NA, documented and code-backed. Both engines
  report latent ICC 0.116 (cross-engine claim holds).
- **Reader-flow** — Blockquote gives one-sentence biologist takeaway; each
  section has a bolded Takeaway; rptR framing (Nakagawa & Schielzeth 2010;
  Stoffel et al. 2017) lands for an ecologist.
- **Consistency** — Symbols (sigma_g/sigma_e via R, pi^2/3) consistent; scale
  labels balanced (4 "data scale" / 4 "latent scale"); nav version 0.22.3
  matches DESCRIPTION; no stale version refs.
