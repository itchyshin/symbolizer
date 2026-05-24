# Validate a symbolized_model object

Checks that required fields are present and have the expected shape.
Used internally by
[`new_symbolized_model()`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md).
Reachable as `symbolizer:::validate_symbolized_model()` for advanced
users who construct or modify objects by hand.

## Usage

``` r
validate_symbolized_model(x)
```

## Arguments

- x:

  A `symbolized_model`.

## Value

Invisibly returns `x`. Errors via
[`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html) if
invalid.
