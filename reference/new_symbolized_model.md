# Construct a symbolized_model object

`new_symbolized_model()` is the internal S3 constructor. It validates
field presence and types and returns an object of class
`"symbolized_model"`. Tier-specific extractors such as
[`symbolize.drmTMB()`](https://itchyshin.github.io/symbolizer/reference/symbolize.drmTMB.md)
call this constructor to wrap the fields they have populated.

## Usage

``` r
new_symbolized_model(
  model,
  index,
  parameterization,
  distribution,
  submodels,
  terms,
  fixed_effects,
  random_effects = NULL,
  variance_components = NULL,
  covariance_components = NULL,
  loadings = NULL,
  factor_coding = NULL,
  symbol_dictionary,
  assumptions,
  components,
  interpretation,
  formula_bridge,
  warnings_registry = NULL,
  graph = NULL,
  expanded = NULL,
  metadata
)
```

## Arguments

- model:

  A list with at least `class`, `package`, `family`, `response`,
  `n_obs`.

- index:

  A list of index symbols (`observation`, `individual`, `group`,
  `trait`, `time`).

- parameterization:

  A list capturing the family-specific scale meaning.

- distribution:

  A tibble of response distribution rows.

- submodels:

  A tibble with one row per linked distributional parameter.

- terms:

  A tibble: the term-grammar / model-matrix bridge.

- fixed_effects:

  A tibble of fixed-effect estimates joined to terms.

- random_effects:

  A tibble or `NULL`.

- variance_components:

  A tibble or `NULL`.

- covariance_components:

  A tibble or `NULL`.

- loadings:

  A tibble of latent-factor loadings (rows: one per
  `(submodel, trait, axis)` entry of a loading matrix) or `NULL`.
  Populated by extractors for reduced-rank latent-variable models such
  as gllvmTMB.

- factor_coding:

  A tibble (one row per factor predictor) recording each factor's
  `levels`, `reference_level`, `contrast_type`, `n_dummies`, and
  `is_default_treatment`, or `NULL`. Populated during extraction by
  `build_factor_coding()`.

- symbol_dictionary:

  A tibble of `(symbol, variable, units, role, description)`.

- assumptions:

  A tibble of stated/implied assumptions.

- components:

  A tibble: one row per renderable block.

- interpretation:

  A tibble of per-parameter readings.

- formula_bridge:

  A tibble: R syntax to statistical meaning to mathematics.

- warnings_registry:

  A tibble or `NULL`.

- graph:

  A list or `NULL`.

- expanded:

  A list of actual numeric arrays (response vector, design matrices,
  coefficient vectors, random-effect BLUPs, residuals, fitted mu/sigma)
  or `NULL`. Populated by extractors that have access to the original
  fit; consumed by
  [`expand()`](https://itchyshin.github.io/symbolizer/reference/expand.md)
  and the three-views renderer.

- metadata:

  A list with at least `call`, `context`, `package_versions`,
  `created_by`.

## Value

A `symbolized_model` S3 object.
