# Where the variation lives: ICC and repeatability

> *A mixed model’s payoff for a biologist is two questions: **where does
> the variation live**, and **how repeatable is the trait**.
> `symbolizer` reads those answers off the fitted model – with an
> explicit, honest account of which scale each number lives on.*

When you fit a mixed model with a grouping factor – individuals measured
more than once, nests, populations, sites – the model splits the total
variation into a *between-group* part and a *within-group* (residual)
part.
[`variance_partition()`](https://itchyshin.github.io/symbolizer/reference/variance_partition.md)
reports that split, and
[`icc()`](https://itchyshin.github.io/symbolizer/reference/icc.md)
reports the **intraclass correlation**: the share of variation that is
between groups. For repeated measurements of the same individuals, the
ICC is exactly the **repeatability** R – the quantity the
[rptR](https://cran.r-project.org/package=rptR) package was built to
estimate (Nakagawa & Schielzeth 2010; Stoffel, Nakagawa & Schielzeth
2017).

This vignette uses ordinary GLMMs from `lme4` and `glmmTMB` – the
engines a biologist actually reaches for. Every number below is a point
estimate; no confidence intervals are shown (see the package’s
uncertainty contract). As everywhere in `symbolizer`, the readings come
from templates in `inst/extdata/`, not from a language model.

## 1. Gaussian repeatability with `lme4`

Suppose boldness is scored three times for each of 30 individuals, with
the assay temperature recorded each time. We want the **repeatability**
of boldness: how much of the variation is consistent differences
*between* individuals, versus variation *within* an individual across
repeats.

``` r

set.seed(1)
n_ind <- 30L; n_rep <- 3L
ind   <- factor(rep(seq_len(n_ind), each = n_rep))
temp  <- round(runif(n_ind * n_rep, 14, 24), 1)
u_ind <- rnorm(n_ind, sd = 1.2)                      # between-individual
boldness <- 2 + 0.10 * temp + u_ind[ind] + rnorm(n_ind * n_rep, sd = 1.0)
dat_g <- data.frame(boldness, temp, ind)

fit_g <- lme4::lmer(boldness ~ temp + (1 | ind), data = dat_g)
sym_g <- symbolize(fit_g)
```

[`variance_partition()`](https://itchyshin.github.io/symbolizer/reference/variance_partition.md)
shows where the variation lives – one row per source, as a share of the
total:

``` r

variance_partition(sym_g)
```

**Where does the variation live?** Where the variation lives – each row
is one variance component (shown as a share of the total when a single
total variance is defined).

ind 69.4%

Residual (within-group) 30.6%

| source                  | variance |    SD | % of total |
|-------------------------|---------:|------:|-----------:|
| ind                     |     1.62 |  1.27 |      69.4% |
| Residual (within-group) |    0.715 | 0.846 |      30.6% |

And [`icc()`](https://itchyshin.github.io/symbolizer/reference/icc.md)
turns that into a single repeatability number. Because this is a
Gaussian-identity fit with one random intercept, the ICC is a **true
proportion of variance in the observed response** – the *data scale*:

``` r

icc(sym_g)
```

**ICC (data scale):** 0.694. Data-scale ICC: the share of total variance
that lies between groups – a genuine proportion of variance.

**Takeaway.** A few tenths of the boldness variation is consistent
between individuals; the rest is within-individual. That
between-individual share *is* the repeatability of boldness.

## 2. Binomial repeatability with `lme4`

Now a binary outcome: whether each offspring survived, with several
offspring per nest. The “repeatability of survival across nests” is a
binomial GLMM with a `(1 | nest)` random intercept.

``` r

set.seed(2)
n_nest <- 25L; brood <- 5L
nest   <- factor(rep(seq_len(n_nest), each = brood))
temp_n <- round(runif(n_nest * brood, 14, 24), 1)
u_nest <- rnorm(n_nest, sd = 1.0)                    # between-nest, logit scale
eta    <- -0.2 + 0.05 * temp_n + u_nest[nest]
surv   <- rbinom(n_nest * brood, size = 1, prob = plogis(eta))
dat_b  <- data.frame(surv, temp_n, nest)

fit_b <- lme4::glmer(surv ~ temp_n + (1 | nest), data = dat_b,
                     family = binomial)
sym_b <- symbolize(fit_b)
```

For a binomial model there is no residual variance on the observed 0/1
scale. The model lives on the **latent (logit) scale**, where the
residual variance is the known constant \pi^2/3. So
[`icc()`](https://itchyshin.github.io/symbolizer/reference/icc.md)
reports a **latent-scale** ICC, and labels it as such – with the caption
that keeps you honest:

``` r

icc(sym_b)
```

**ICC (latent scale):** 0.116. Latent-scale ICC: not a proportion of
variance in the observed outcome – it is the repeatability on the link
(latent) scale.

This is exactly rptR’s *link-scale* (a.k.a. latent-scale) repeatability.
It is the repeatability of the underlying propensity to survive, **not**
a proportion of variance in the realized 0/1 outcome. `symbolizer`
refuses to pretend otherwise.

**Takeaway.** Proportion and binary data get a repeatability too – but
on the latent scale, with the residual fixed at \pi^2/3 (logit) or 1
(probit).

## 3. The same reading from a different engine: `glmmTMB`

[`variance_partition()`](https://itchyshin.github.io/symbolizer/reference/variance_partition.md)
and [`icc()`](https://itchyshin.github.io/symbolizer/reference/icc.md)
read the fitted object, not the package that produced it. Refit the same
binomial model with `glmmTMB` and the latent-scale repeatability is the
same:

``` r

fit_b2 <- glmmTMB::glmmTMB(surv ~ temp_n + (1 | nest), data = dat_b,
                           family = binomial)
icc(symbolize(fit_b2))
```

**ICC (latent scale):** 0.116. Latent-scale ICC: not a proportion of
variance in the observed outcome – it is the repeatability on the link
(latent) scale.

The reading – the quantity, the scale, the caption – is identical
whichever engine you used. (For *Gaussian* fits the point estimate can
differ slightly between engines because
[`lme4::lmer`](https://rdrr.io/pkg/lme4/man/lmer.html) defaults to REML
while `glmmTMB` defaults to maximum likelihood; the variance partition
is computed the same way from whatever the fit reports.)

## 4. When the ICC is not defined – and `symbolizer` says so

A single-number ICC needs a single residual variance on a known scale.
When that does not exist, `symbolizer` returns `NA` with a reason rather
than a misleading number:

- **Count models (Poisson, negative binomial)** have no fixed residual
  constant on the data scale, so the data-scale ICC is undefined.
  (Unlike the binomial’s fixed \pi^2/3, a count model’s latent/log-scale
  repeatability uses a *distribution-specific* observation-level
  variance – e.g. \ln(1 + 1/\lambda) for the Poisson-log case (Nakagawa
  & Schielzeth 2010). That latent-scale ICC is well defined, but
  `symbolizer` does not yet compute it, so it returns `NA` here rather
  than a half-specified number.)
- **Location-scale Gaussian** fits (where the residual SD itself varies
  across observations) have no single within-group variance.
- **More than one random-effect term**: the variance partition is still
  meaningful and shown, but a single-number ICC is not.

``` r

set.seed(3)
dat_p <- dat_b
dat_p$count <- rpois(nrow(dat_p), lambda = 3)
fit_p <- lme4::glmer(count ~ temp_n + (1 | nest), data = dat_p,
                     family = poisson)
icc(symbolize(fit_p))
```

**ICC:** ICC not available on this scale yet. (no known
residual-variance constant for the poisson family on the data scale, so
the ICC is not defined here.)

The partition still shows the random-effect variance; only the share and
the single-number ICC are withheld.

**Takeaway.** `symbolizer` reports repeatability where it is well
defined, names the scale when it is on the latent scale, and refuses –
with a reason – when it is not defined at all. That refusal is the
feature.

## See also

- [`variance_partition()`](https://itchyshin.github.io/symbolizer/reference/variance_partition.md)
  and [`icc()`](https://itchyshin.github.io/symbolizer/reference/icc.md)
  – the accessors used here.
- [`explain()`](https://itchyshin.github.io/symbolizer/reference/explain.md)
  and
  [`model_card()`](https://itchyshin.github.io/symbolizer/reference/model_card.md)
  – both surface a “How the variation splits” section for any fit with
  random effects.
- The three-views widget
  ([`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md))
  carries the same “where does the variation live?” panel on its first
  tab.

### References

Nakagawa, S. & Schielzeth, H. (2010). Repeatability for Gaussian and
non-Gaussian data: a practical guide for biologists. *Biological
Reviews*, 85, 935–956.

Stoffel, M. A., Nakagawa, S. & Schielzeth, H. (2017). rptR:
repeatability estimation and variance decomposition by generalized
linear mixed-effects models. *Methods in Ecology and Evolution*, 8,
1639–1644.
