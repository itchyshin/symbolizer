# Render a symbolized_model as LaTeX

`as_latex()` turns a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
into a single LaTeX string ready to splice into a document. By default
the equations are wrapped in an `aligned` environment with `&` alignment
markers inserted before `=` or `\sim` on each line.

## Usage

``` r
as_latex(x, notation = c("index", "matrix", "both"), env = "aligned", ...)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md).

- notation:

  One of `"index"`, `"matrix"`, or `"both"`. With `"both"`, two `env`
  blocks are stacked, separated by a `\text{(matrix notation)}` header.

- env:

  LaTeX environment to wrap the equations in. Defaults to `"aligned"`.
  Other useful values: `"align*"`, `"gather"`.

- ...:

  Reserved for future use.

## Value

A single character string.

## Examples

``` r
# cat(as_latex(symbolize(fit)))
```
