# Model diagram for a symbolized model

Returns a structural DAG of the fitted model: nodes for the response,
each predictor, each parameter (mu, sigma, ...), and any random-effect
grouping variables; edges connecting predictors to the parameters they
enter, parameters to the response, and groups to their random-effect
contribution. The returned object is an S3 list with `nodes` and `edges`
tibbles plus a generated DOT-language string.

Rendering live needs a downstream tool that consumes DOT - the
`DiagrammeR` package (which symbolizer does NOT require) is one option;
pasting `as_dag(sym)$dot` into
<https://dreampuf.github.io/GraphvizOnline/> is another. The S3 print
method shows the DOT string and a brief summary; `as_dag(sym)$nodes` and
`$edges` are the raw tables.

This is a structural surface - it visualises *how* the symbolic object
connects predictors, parameters, and the response. It does not show
coefficient values; for those see
[`parameter_interpretation()`](https://itchyshin.github.io/symbolizer/reference/parameter_interpretation.md).

## Usage

``` r
as_dag(x, ...)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md).

- ...:

  Reserved for future use.

## Value

A list classed `c("symbolic_dag", "list")` with three slots: `nodes`
(tibble), `edges` (tibble), `dot` (single character string with the
GraphViz / DOT representation).

## Examples

``` r
# as_dag(symbolize(lm(mpg ~ wt, data = mtcars)))
```
