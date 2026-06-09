# One-call explainer for a fitted model

`explain()` is the recommended entry point for first-time users. It runs
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
internally and returns a `symbolized_explanation` that bundles the
original
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
together with the six reader-facing pieces already rendered:

- `equations` – the
  [`equations()`](https://itchyshin.github.io/symbolizer/reference/equations.md)
  tibble (both notations)

- `symbols` – the
  [`symbol_table()`](https://itchyshin.github.io/symbolizer/reference/symbol_table.md)
  result

- `assumptions` – the
  [`assumption_table()`](https://itchyshin.github.io/symbolizer/reference/assumption_table.md)
  result

- `bridge` – the
  [`formula_bridge()`](https://itchyshin.github.io/symbolizer/reference/formula_bridge.md)
  result

- `interpretation` – the
  [`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md)
  result

- `variance_components` – where the variation lives (NULL when the model
  has no random effects)

- `notation_bridge` – the
  [`notation_bridge()`](https://itchyshin.github.io/symbolizer/reference/notation_bridge.md)
  result

Print the result at the console for a walkthrough led by a plain-English
paragraph, or knit it inside a Quarto / R Markdown document for a
heading-and-kable section per piece.

Use [`summary()`](https://rdrr.io/r/base/summary.html) on an
already-symbolize'd object to get the same walkthrough without
re-running
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md).

## Usage

``` r
explain(fit, symbols = NULL, units = NULL, context = NULL, ...)
```

## Arguments

- fit:

  A fitted statistical model object.

- symbols:

  Optional named character vector mapping variable names to
  user-supplied LaTeX symbols, e.g.
  `c(body_mass = "W_i", temperature = "T_i")`.

- units:

  Optional named character vector mapping variable names to units, e.g.
  `c(body_mass = "g", temperature = "C")`.

- context:

  Optional short character description of the model, e.g.
  `"avian body-size location-scale model"`.

- ...:

  Reserved for method-specific extra arguments.

## Value

A `symbolized_explanation` object with elements `model` (the underlying
`symbolized_model`), `equations`, `symbols`, `assumptions`, `bridge`,
`interpretation`, `variance_components` (NULL when the model has no
random effects), `notation_bridge`.

## Examples

``` r
# explain(symbolize(lm(mpg ~ wt, data = mtcars)))
```
