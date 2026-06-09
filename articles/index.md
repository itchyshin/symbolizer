# Articles

### Get started

Start here: a five-minute quickstart, then the ladder that builds up
from lm() to location-scale on one shared dataset.

- [Get started with
  symbolizer](https://itchyshin.github.io/symbolizer/articles/symbolizer.md):

  A five-minute first contact: fit a model, then read its equation,
  assumptions, and plain-English interpretation.

- [Building up: from lm to
  location-scale](https://itchyshin.github.io/symbolizer/articles/symbolizer-ladder.md):

  One synthetic dataset, four models of increasing complexity, the same
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  call. Watch the symbolic equation grow one row at a time as you add a
  factor, then a random effect, then a heterogeneity submodel.

### Deep dives

One renderer or concept at a time: the drmTMB extractor, factor
contrasts and interactions, non-Gaussian families, variance components,
latent variables (gllvm), and structural model comparison.

- [Understanding a drmTMB fit with
  symbolizer](https://itchyshin.github.io/symbolizer/articles/symbolizer-drmtmb.md):

  Read a distributional (location-scale) regression: the mean submodel,
  the variance submodel, and what each coefficient means.

- [Reading factors, dummies, and
  interactions](https://itchyshin.github.io/symbolizer/articles/symbolizer-factors.md):

  How factors, dummy coding, contrasts, and interactions appear in the
  equation – and the pitfalls that trip up interpretation.

- [A tour of non-Gaussian
  families](https://itchyshin.github.io/symbolizer/articles/symbolizer-families.md):

  Poisson, Beta, Gamma, lognormal and more – each family’s distribution,
  link function, and coefficient reading.

- [Where the variation lives: ICC and
  repeatability](https://itchyshin.github.io/symbolizer/articles/symbolizer-variance-components.md):

  Partition variance into components, then read ICC and repeatability –
  and which scale each number lives on.

- [Latent variables in ecology: a gllvmTMB worked
  example](https://itchyshin.github.io/symbolizer/articles/symbolizer-gllvm.md):

  Generalized linear latent-variable (GLLVM) models for multivariate
  ecology: factors, loadings, and the implied trait covariance.

- [Comparing two symbolized
  models](https://itchyshin.github.io/symbolizer/articles/symbolizer-compare.md):

  See what changes between two model specifications – terms,
  assumptions, and structure – side by side.

### Cross-package bridges

Models whose structure lives in another package: phylogenetic,
animal-model, and spatial dependence, meta-analysis across metafor /
brms / MCMCglmm, and multi-node structural equation models (piecewiseSEM
/ drmSEM).

- [Structural dependence: phylogenetic, animal-model, and spatial random
  effects](https://itchyshin.github.io/symbolizer/articles/symbolizer-structural-dependence.md):

  Phylogenetic, animal-model, and spatial random effects as one grammar
  – the same dependence model across metafor, MCMCglmm, brms, and
  phylolm.

- [Three flavors of meta-analysis: a cross-package
  tour](https://itchyshin.github.io/symbolizer/articles/symbolizer-meta-analysis.md):

  The same meta-analytic model across metafor, glmmTMB, and drmTMB –
  known sampling variances and the heterogeneity they leave behind.

- [Multi-node structural equation models: piecewiseSEM and
  drmSEM](https://itchyshin.github.io/symbolizer/articles/symbolizer-sem.md):

### Where we’re going

The capability roadmap: what is Stable, what is a First slice, and what
is planned or reserved.

- [Roadmap and capability
  matrix](https://itchyshin.github.io/symbolizer/articles/symbolizer-roadmap.md):

  Where symbolizer is today, where it’s going, and what every Stable /
  First slice / Planned status word actually means.
