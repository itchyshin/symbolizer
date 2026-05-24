# Structural comparison of two symbolized models

Compares two
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
objects and returns a structured diff covering:

- **meta** — class, family, response, and `n_obs` for each side.

- **submodels** — which submodels appear only on the left, only on the
  right, or on both sides.

- **terms** — within each shared submodel, which term labels appear only
  on one side or on both.

- **assumptions** — for each assumption, the statuses on each side and
  whether they match.

Use it to ask questions like "what's different between this fit and the
previous one?" — a structural answer rather than a numeric one.
Coefficient values are not compared; this is the structural-symbolic
diff. For coefficient-level differences, use the
[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
tibbles directly.

## Usage

``` r
compare_symbolic(sym_a, sym_b, ...)
```

## Arguments

- sym_a, sym_b:

  Two `symbolized_model` objects.

- ...:

  Reserved for future use.

## Value

A list classed `c("symbolic_comparison", "list")` with four slots:
`meta` (list of left / right model summaries), `diff_submodels`
(tibble), `diff_terms` (tibble), `diff_assumptions` (tibble).
