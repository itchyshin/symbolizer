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
#> # A tibble: 37 × 6
#>    class  family    component      status              since notes              
#>    <chr>  <chr>     <chr>          <chr>               <chr> <chr>              
#>  1 drmTMB gaussian  mu             Stable              0.1.0 Univariate locatio…
#>  2 drmTMB gaussian  sigma          Stable              0.1.0 Univariate scale s…
#>  3 drmTMB gaussian  random_effects First slice         0.1.0 Gaussian random in…
#>  4 drmTMB gaussian  zi             Planned or reserved NA    Zero-inflation sub…
#>  5 drmTMB gaussian  hu             Planned or reserved NA    Hurdle submodel.   
#>  6 drmTMB gaussian  rho12          Planned or reserved NA    Bivariate residual…
#>  7 drmTMB student   mu             Planned or reserved NA    NA                 
#>  8 drmTMB student   sigma          Planned or reserved NA    NA                 
#>  9 drmTMB student   nu             Planned or reserved NA    NA                 
#> 10 drmTMB lognormal mu             Planned or reserved NA    NA                 
#> # ℹ 27 more rows
```
