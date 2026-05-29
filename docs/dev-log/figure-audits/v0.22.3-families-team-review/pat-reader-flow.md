# PAT — Reader-flow audit, v0.22.3 families widgets

Lens: a biologist reads prose, opens the widget, clicks the tabs. Does it
stay coherent and match the prose?

## Lognormal (`sym-lognormal-1780010418`)

**Article thesis (`.Rmd` 94-97):** "`Y > 0`, `log(Y)` is Gaussian; `exp(beta)`
multiplies the geometric mean of Y."

**Per tab:**
- Tab 1: `log(y_i) ~ Normal(mu_i, sigma_i^2)`, `mu_i = X beta`.
- Tab 2: matrix form, `log(y) ~ N(mu, diag(sigma^2))`.
- Tab 3 worked row: `log(y_1) = 1.56 = 2.02 + (-0.0136)(0.409) + (-0.448)`,
  mu_1 labelled "log-scale mean".
- Tab 3 stacked block: response-scale y (4.78, ...) = X beta + eps, same beta.
  Caption: "X beta = mu".

**Contradictions:**
1. Worked row LHS = `log(y_1)`; stacked LHS = response-scale y, same beta —
   two scales of one equation.
2. Caption "X beta = mu" overrides Tab 1's log-scale mu.
3. eps in stacked block (2.77, ...) is `y - exp(X beta)`, not the log-scale
   eps^(log) = -0.448 from the worked row.

**Standalone Tab 3 takeaway:** FAIL. Reader sees a Gaussian model on y.

## Beta (`sym-beta-1780010419`)

**Article thesis (`.Rmd` 148-151):** "Y in (0,1). Mean via logit link,
precision via log link."

**Per tab:**
- Tab 1: `y_i ~ Beta(mu_i sigma_i, (1-mu_i) sigma_i)`, `logit(mu_i) = X beta`.
- Tab 2: matrix form, still logit.
- Tab 3 worked row: `eta_1 = -0.95`, `mu_1 = logistic(-0.95) ~ 0.279`,
  `y_1 ~ Beta(mu_1, ...)` captioned "no additive eps here".
- Tab 3 stacked block: y = (0.175, ...) = X beta + eps. Caption asserts
  `X beta = mu`.

**Contradictions:**
1. Worked row says "no additive eps here" four lines above a block adding eps.
2. Tab 1's Beta likelihood contradicts Tab 3's `y = X beta + eps`.
3. eps (-0.103, ...) is `y - logistic(X beta)`, but equation is direct sum.
   Row 1: -0.95 + (-0.103) = -1.05, not 0.175.

**Standalone Tab 3 takeaway:** FAIL. Looks like a linear probability model.

## Poisson (`sym-poisson-1780010421`)

**Article thesis (`.Rmd` 205-208):** "Each observation is a count; the log
of the expected count may shift with the predictors."

**Per tab:**
- Tab 1: `y_i ~ Poisson(mu_i)`, `log(mu_i) = X beta`. No residual.
- Tab 2: matrix form.
- Tab 3 worked row: `eta_1 = 0.936`, `mu_1 = exp(0.936) ~ 2.55`, `y_1 ~
  Poisson(mu_1)` captioned "no additive eps here".
- Tab 3 stacked block: integer y = (1, 1, 2, 3, ..., 0, 5) = X beta + eps.
  Caption: `X beta = mu`.

**Contradictions:**
1. Tab 1 has no error term; Tab 3 adds one.
2. Worked row writes "no additive eps here" adjacent to a stacked block with eps.
3. Arithmetic broken. Row 1: 0.936 + (-1.55) = -0.614, not y_1 = 1. Clearest
   case: y is an integer count.

**Standalone Tab 3 takeaway:** FAIL, worst case.

## How this could serve the reader better

**Universal fix.** Replace the non-Gaussian Tab 3 stacked block. Drop
`y = X beta + eps`. Stack `eta = X beta`, then `mu = link^-1(eta)`, then
`y ~ Family(mu, ...)`. Caption: "no additive response-scale residual;
non-Gaussian families absorb dispersion into the likelihood."

**Lognormal.** Add: "`exp(beta_1) = 0.986` — each unit of x multiplies the
geometric mean by 0.986 (a 1.4% drop)." Gloss sigma: "for small sigma this
approximates the CV of y." Pick a worked row with x near 0; i=1 has x=0.409
which dilutes the intercept story.

**Beta.** Add odds-ratio: "`exp(beta_1) ~ 0.916` — each unit of x multiplies
the odds by 0.916." Gloss Beta(a,b) in Tab 1: "mean/precision form; total
concentration = sigma." Replace the all-identical sigma column with a scalar
plus "constant across all n observations".

**Poisson.** Add rate-ratio: "`exp(beta_1) ~ 0.957` — each unit of x
multiplies the expected count by 0.957 (a 4.3% drop)." Add Tab 1 callout:
"Poisson assumes variance = mean; if var > mean, use nbinom2." Tab 2 adds
nothing over Tab 1 for single-submodel families — collapse them, or use
Tab 2 for the X matrix structure.

**Family-aware bottom caption.** "Middle: X beta = mu" should read:
Poisson — "X beta = log(mu)"; Beta — "X beta = logit(mu)"; Lognormal —
"X beta = mean of log(y)". A reader trusting the current caption gets the
wrong scale.

**Worked-row choice.** Show two worked rows (one near x-mean, one at +1 SD)
or let the reader pick.

**"What this means for your study" italic line.** Lognormal: "report
exp(beta) on back-transformed mass/lifespan." Beta: "report as odds ratios."
Poisson: "report as incidence-rate ratios; flag overdispersion."
