# Check whether a (class, family, component) tuple is supported

Internal gate used by
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
methods. Errors via
[`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html) if
the status is **Planned or reserved** or **Unsupported or blocked**.

## Usage

``` r
capability_check(class, family, component)
```

## Arguments

- class:

  Character. Fitted-object class.

- family:

  Character. Family name.

- component:

  Character. Component name.

## Value

Invisibly returns the matched row's status word.

## Details

Wildcards: a row with value `"*"` in `class`, `family`, or `component`
matches any value in that slot.

When the check fails, the error message also lists the
currently-readable tuples (status: Stable or First slice) so the user
immediately sees what they *can* do today.
