# Get the family parameterization contract

Looks up family-specific scale meaning, links, and natural-scale
transforms from `inst/extdata/family-parameterizations.csv`. Errors if
the family has no row.

## Usage

``` r
get_parameterization(family)
```

## Arguments

- family:

  Family name (character), e.g. `"gaussian"`.

## Value

A list with fields family, response_distribution, scale_parameter,
scale_meaning, link_mu, link_sigma, variance_expression,
natural_sd_ratio, natural_variance_ratio, notes.
