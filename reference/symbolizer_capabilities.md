# Symbolizer capability registry

Returns the table of model classes, families, and components that
[`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
knows about, together with their status. Use this to discover what is
currently supported and what is on the roadmap.

## Usage

``` r
symbolizer_capabilities()
```

## Value

A tibble with columns `class`, `family`, `component`, `status`, `since`,
`notes`.

## Details

Status words follow drmTMB's five-level vocabulary:

- **Stable**: routine path with tests, diagnostics, and a reader-facing
  example.

- **First slice**: fitted and tested, but intentionally narrow.

- **Opt-in control**: available for hardening, not a general modelling
  guarantee.

- **Planned or reserved**: public grammar may exist, but
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)
  rejects it.

- **Unsupported or blocked**: do not use as analysis syntax.

## Examples

``` r
symbolizer_capabilities()
#> # A tibble: 122 × 6
#>    class  family            component      status              since notes      
#>    <chr>  <chr>             <chr>          <chr>               <chr> <chr>      
#>  1 drmTMB gaussian          mu             Stable              0.1.0 Univariate…
#>  2 drmTMB gaussian          sigma          Stable              0.1.0 Univariate…
#>  3 drmTMB gaussian          random_effects First slice         0.3.1 Random int…
#>  4 drmTMB gaussian          zi             Planned or reserved NA    Zero-infla…
#>  5 drmTMB gaussian          hu             Planned or reserved NA    Hurdle sub…
#>  6 drmTMB poisson           zi             First slice         0.4.0 Zero-infla…
#>  7 drmTMB nbinom2           zi             First slice         0.4.0 Zero-infla…
#>  8 drmTMB truncated_nbinom2 hu             First slice         0.4.0 Hurdle sub…
#>  9 drmTMB gaussian          rho12          Planned or reserved NA    Bivariate …
#> 10 drmTMB student           mu             First slice         0.2.2 Student-t …
#> # ℹ 112 more rows
```
