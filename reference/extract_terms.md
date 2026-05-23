# Build the term-grammar / model-matrix bridge for one submodel

`extract_terms()` is the prerequisite for every renderer. It bridges R
formula terms \<-\> model-matrix columns \<-\> biological symbols.
Without this layer, equations silently break on factor contrasts,
interactions, offsets, and transformations.

For each model-matrix column (plus offsets), it returns one row giving
the term label, source variable, role classification, factor contrast
level, transformation applied, biological symbol, coefficient symbol,
and a ready-to-splice LaTeX fragment.

Supported roles in v0.1: `intercept`, `predictor`, `factor_contrast`,
`interaction`, `transformation`, `offset`. Random-effect terms are
detected upstream and removed before `extract_terms()` runs in v0.1.

## Usage

``` r
extract_terms(
  formula,
  data,
  submodel,
  symbols = NULL,
  coefficient_family = "beta"
)
```

## Arguments

- formula:

  One-sided or two-sided formula for the submodel.

- data:

  Data frame used for fitting.

- submodel:

  Character. Name of the submodel, e.g. `"mu"`, `"sigma"`.

- symbols:

  Named character vector mapping variable names to LaTeX symbols.
  Missing variables receive auto-generated symbols.

- coefficient_family:

  Character. Coefficient symbol family used in `coefficient_symbol`,
  e.g. `"beta"` for mu, `"gamma"` for log sigma.

## Value

A tibble with columns: `submodel`, `term_label`, `variable`, `role`,
`contrast_level`, `transform`, `symbol`, `coefficient_symbol`,
`latex_term`.
