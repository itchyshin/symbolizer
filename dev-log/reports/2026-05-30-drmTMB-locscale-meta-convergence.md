# drmTMB report: location-scale meta-analysis — `offset()` rejected in `sigma`, and `meta_V() + sigma~x` returns pdHess = FALSE

Date: 2026-05-30
Filed upstream: https://github.com/itchyshin/drmTMB/issues/417
From: symbolizer maintainer (building the location-scale meta-analysis vignette)
drmTMB version probed: the `itchyshin/drmTMB` checkout installed locally on 2026-05-30
(`drm_formula`, `meta_V`, location-scale `sigma ~` submodel).
Context: symbolizer §5 wants a **location-scale meta-analysis** deep Face in drmTMB —
known per-effect sampling variance `v_k`, with the between-study heterogeneity SD
modelled as a function of a moderator: `mu ~ x`, `log σ(x) = γ0 + γ1 x`.

## Two issues, smallest first

### Issue A — `offset()` is rejected inside the `sigma` formula

The natural location-scale-meta idiom (and the one symbolizer's own v0.16 vignette
documented) folds the known sampling variance into the scale submodel via an offset:

```r
drmTMB::drmTMB(
  drm_formula(dARR ~ 1 + habitat,
              sigma ~ 1 + habitat + offset(0.5 * log(Var_dARR))),
  family = stats::gaussian(), data = dat)
#> Error in drm_reject_phase1_terms(sigma_entry$rhs, "sigma") :
#>   This formula contains unsupported model terms.
#>   x The `sigma` formula contains unsupported term: "offset".
```

`offset()` is accepted in many GLM scale submodels (it is how one pins the known
sampling SE in a meta-analysis). If `offset()` in `sigma` is intentionally
unsupported, a doc note + a pointer to `meta_V()` would help; if it is an
oversight, supporting it would restore the standard meta idiom.

### Issue B — `meta_V() + sigma ~ x` gives accurate point estimates but `pdHess = FALSE`

The modern drmTMB idiom (used in symbolizer §4) is `meta_V(V = v)` for the known
sampling variance. Combining it with a scale submodel `sigma ~ x` fits and returns
**accurate** estimates, but the sdreport Hessian is **not** positive-definite —
even on clean, well-identified **simulated** data:

```r
set.seed(42)
K  <- 80; x <- rep(c(0,1), each = K/2)
vk <- runif(K, 0.01, 0.05)          # small KNOWN sampling variances
mu  <- 0.3 - 0.2 * x                # truth: beta0 = 0.3, beta1 = -0.2
tau <- exp(-0.7 - 1.0 * x)          # truth: gamma0 = -0.7, gamma1 = -1.0
y   <- rnorm(K, mu, sqrt(vk + tau^2))
d   <- data.frame(y = y, v = vk,
                  habitat = factor(ifelse(x == 0, "aquatic", "terrestrial")))

bf <- drmTMB::drm_formula; meta_V <- drmTMB::meta_V
fit <- drmTMB::drmTMB(
  bf(y ~ 1 + habitat + meta_V(V = v), sigma ~ 1 + habitat),
  family = stats::gaussian(), data = d)

isTRUE(fit$sdreport$pdHess)                 #> FALSE
drmTMB::fixef(fit, "mu")                     #> 0.343, -0.236   (truth 0.30, -0.20)
drmTMB::fixef(fit, "sigma")                  #> -0.816, -0.975  (truth -0.70, -1.00)
any(!is.finite(sqrt(diag(fit$sdreport$cov.fixed))))  #> FALSE  (SEs are finite)
```

The point estimates recover the data-generating truth to ~2 decimals, so the
optimiser is finding the right mode — but `pdHess = FALSE` means the reported
SEs / CIs are not trustworthy. Reproduced identically on the real 164-effect
thermal subset (no RE; with a `(1|study_ID)` RE; simplified) — always
`pdHess = FALSE`. So this is a **Hessian / sdreport issue for the
`meta_V + scale-submodel` combination**, independent of the dataset.

Hypothesis (unverified): `meta_V()`'s fixed per-observation variance and a free
`sigma ~ x` submodel are weakly separated in the information matrix near the
optimum, or the sdreport is computed before/around the fixed-V contribution in a
way that leaves the joint Hessian rank-deficient. A reproducible flat/degenerate
direction even when the marginal likelihood is well-peaked.

## What symbolizer is doing in the meantime

- §5's **deep Face** uses `glmmTMB` (`dispformula = ~habitat, weights = 1/v_k`),
  which converges cleanly (`pdHess = TRUE`) on the same data.
- drmTMB is shown as a **light Face** with an honest note: it recovers the same
  point estimates but currently reports `pdHess = FALSE` for this model class,
  reported here.
- symbolizer renders **point estimates** only (its widgets state "uncertainty not
  shown"), so the symbolic/teaching output is unaffected; the caution is about SEs.

## Ask

1. Is `offset()` in the `sigma` formula intended to be unsupported? (doc note vs fix)
2. Is the `pdHess = FALSE` for `meta_V() + sigma ~ x` a known limitation? If a
   reparameterisation or a `getReportCovariance` / `skip.delta.method` knob exists
   that yields a PD Hessian for this combination, that would let drmTMB be the
   location-scale-meta deep Face it is otherwise ideal for.
