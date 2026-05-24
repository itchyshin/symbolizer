# Plain-English summary of a symbolized model

[`summary()`](https://rdrr.io/r/base/summary.html) walks the reader
through a
[`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
in plain English. It opens with one paragraph describing the model in
prose (class, family, response, sample size, submodels and links,
fitting approach), then prints the same reader tables that
[`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md)
returns: equations, the symbol dictionary, assumptions, the formula
bridge, the per-coefficient interpretations, and the notation bridge.

Unlike
[`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md),
[`summary()`](https://rdrr.io/r/base/summary.html) does not re-run
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md);
it simply renders the object you already have.

## Usage

``` r
# S3 method for class 'symbolized_model'
summary(object, ...)
```

## Arguments

- object:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md).

- ...:

  Reserved for future use.

## Value

Invisibly returns a `summary.symbolized_model` object (a list with the
rendered pieces). Called for its printed walkthrough.
