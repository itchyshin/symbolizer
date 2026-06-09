# Where the variation lives: a variance partition for a mixed model

`variance_partition()` turns a fitted mixed model's variance components
into a one-row-per-source table: each random-effect variance plus, when
it is defined, the residual (within-group) variance. The `pct` column is
each source's share of the total, answering a biologist's first question
of a mixed model – *where does the variation live?*

The residual row (and therefore `pct`) appears only when the residual
variance is defined on a single scale: a homoscedastic Gaussian fit (one
residual SD) or a binomial fit (the known latent-scale residual,
\\\pi^2/3\\ for logit, 1 for probit). For other families, or a
location-scale Gaussian whose residual SD varies across observations,
the random-effect variances are still shown but `pct` is `NA` with a
reason – shares of a total are not meaningful without a residual.

Point estimates only; no confidence intervals (the package's uncertainty
contract).

## Usage

``` r
variance_partition(x, ...)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
  whose underlying fit is retained on `x$metadata$fit`.

- ...:

  Reserved for future use.

## Value

A tibble (S3 class `symbolizer_variance_partition`) with one row per
variance source. Columns: `component`, `variance`, `sd`, `pct`. Carries
a `reason` attribute (character or `NA`) explaining an all-`NA` `pct`.

## See also

[`icc()`](https://itchyshin.github.io/symbolizer/reference/icc.md) for
the single-number intraclass correlation.

## Examples

``` r
# variance_partition(symbolize(lme4::lmer(Reaction ~ Days + (1 | Subject),
#                                         data = lme4::sleepstudy)))
```
