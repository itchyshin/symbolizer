# Symbolize a fitted statistical model

`symbolize()` converts a fitted model object into a structured
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
from which LaTeX equations, symbol dictionaries, assumption tables,
formula bridges, and parameter interpretations can be rendered.

Methods exist for fitted-model classes registered in
[`symbolizer_capabilities()`](https://itchyshin.github.io/symbolizer/reference/symbolizer_capabilities.md).
The default method errors with a pointer to the registry.

## Usage

``` r
symbolize(fit, symbols = NULL, units = NULL, context = NULL, ...)
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

A
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
object.

## Examples

``` r
# See methods listed in `symbolizer_capabilities()`.
```
