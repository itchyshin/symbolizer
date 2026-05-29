# Intraclass correlation (repeatability) for a mixed model

`icc()` returns the intraclass correlation – the proportion of variance
that lies between groups – for a mixed model with a single random-effect
term. For a biologist this is the *repeatability* of the trait.

The returned value carries a `scale` attribute that is essential to its
interpretation:

- **data scale** (`scale = "data"`): a Gaussian-identity fit with one
  random intercept. \\\sigma^2_g / (\sigma^2_g +
  \sigma^2\_\varepsilon)\\ is a genuine proportion of variance in the
  observed response.

- **latent scale** (`scale = "latent"`): a binomial fit, where the
  residual is the known link-scale constant (\\\pi^2/3\\ for logit, 1
  for probit). This is repeatability on the latent (link) scale and is
  **not** a proportion of variance in the observed 0/1 outcome – the
  returned object carries that caption.

When the quantity is not defined – another family, a location-scale
Gaussian whose residual SD varies, or more than one random-effect term –
`icc()` returns `NA` with a human-readable `reason` attribute rather
than a misleading number. Use
[`variance_partition()`](https://itchyshin.github.io/symbolizer/reference/variance_partition.md)
to see the full breakdown in those cases. Point estimate only; no
confidence interval.

## Usage

``` r
icc(x, ...)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
  whose underlying fit is retained on `x$metadata$fit`.

- ...:

  Reserved for future use.

## Value

A length-1 numeric (S3 class `symbolizer_icc`) with attributes `scale`
(`"data"`, `"latent"`, or `NA`), `reason` (character or `NA`), and
`caption` (character or `NA`). Prints a one-line reading at the console.

## See also

[`variance_partition()`](https://itchyshin.github.io/symbolizer/reference/variance_partition.md)
for the full source-by-source breakdown.
