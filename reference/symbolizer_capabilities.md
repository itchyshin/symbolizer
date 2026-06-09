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
#> # A tibble: 136 × 7
#>    class  family            component      status           since notes lives_in
#>    <chr>  <chr>             <chr>          <chr>            <chr> <chr> <chr>   
#>  1 drmTMB gaussian          mu             Stable           0.1.0 Univ… symboli…
#>  2 drmTMB gaussian          sigma          Stable           0.1.0 Univ… symboli…
#>  3 drmTMB gaussian          random_effects First slice      0.3.1 Rand… symboli…
#>  4 drmTMB gaussian          zi             Planned or rese… NA    Zero… symboli…
#>  5 drmTMB gaussian          hu             Planned or rese… NA    Hurd… symboli…
#>  6 drmTMB poisson           zi             First slice      0.4.0 Zero… symboli…
#>  7 drmTMB nbinom2           zi             First slice      0.4.0 Zero… symboli…
#>  8 drmTMB truncated_nbinom2 hu             First slice      0.4.0 Hurd… symboli…
#>  9 drmTMB gaussian          rho12          Planned or rese… NA    Biva… symboli…
#> 10 drmTMB student           mu             First slice      0.2.2 Stud… symboli…
#> # ℹ 126 more rows
```
