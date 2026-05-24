# Per-fit prose warnings for a symbolized model

Returns the tibble of conditions
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
flagged when it built the model object. Each row is one warning with a
`code` (machine identifier), a `severity` (`info` / `warn` / `error`), a
`message` (the prose templated from
`inst/extdata/warning-templates.csv`), and a `context` string naming
which slot values triggered the rule.

Today the system ships two checks:

- `few_groups_wald` *(warn)* — Wald 95% CI used with a random-effect
  group of fewer than ~10 levels.

- `small_n_wald` *(info)* — Wald CI on a small dataset. Currently
  defined in the template CSV but reserved; no extractor fires it yet
  (the threshold is fit-dependent and not always informative).

New conditions are added by appending a row to
`inst/extdata/warning-templates.csv` and wiring the trigger in the
relevant `drm_build_warnings()` (or sibling for other classes).

## Usage

``` r
warning_table(x, ...)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md).

- ...:

  Reserved for future use.

## Value

A tibble (S3 class `symbolizer_warning_table`) with columns `code`,
`severity`, `message`, `context`.
