# Equation rows from a symbolized_model

Returns the equation lines carried by a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
as a tibble. One row per renderable block in `x$components`. Both
notations (index and matrix) are always returned in their own columns;
the `notation` argument only controls how the result is *displayed* by
[`print()`](https://rdrr.io/r/base/print.html).

For the LaTeX-string form ready to splice into a document, see
[`as_latex()`](https://itchyshin.github.io/symbolizer/reference/as_latex.md).

## Usage

``` r
equations(x, notation = c("index", "matrix", "both"), ...)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md).

- notation:

  One of `"index"`, `"matrix"`, or `"both"`. Sets the display preference
  recorded as the `"notation"` attribute and used by the
  `symbolizer_equations` [`print()`](https://rdrr.io/r/base/print.html)
  method.

- ...:

  Reserved for future use.

## Value

A tibble with columns `name`, `kind`, `submodel`, `index`, `matrix` and
the additional class `"symbolizer_equations"`.

## Examples

``` r
# equations(symbolize(fit))
```
