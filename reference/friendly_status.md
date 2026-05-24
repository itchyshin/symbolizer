# Map an assumption-status key to a friendlier display label

Translates the CSV keys (`stated`, `implied`, `not_checked`) used in
`inst/extdata/assumption-templates.csv` to plain-language labels for
display in [`print()`](https://rdrr.io/r/base/print.html) and
`knit_print()` methods. The underlying data column keeps the original
key; only the user-visible rendering changes.

## Usage

``` r
friendly_status(status)
```

## Arguments

- status:

  Character vector of status keys.

## Value

Character vector of the same length carrying the friendlier label.
Unknown keys pass through unchanged.
