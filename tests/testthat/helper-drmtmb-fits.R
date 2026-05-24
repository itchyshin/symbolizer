# Helper: build the canonical drmTMB Gaussian location-scale fit used across
# symbolize.drmTMB tests. Skips the calling test if drmTMB is not installed.
fit_drm_location_scale <- function(seed = 1L, n = 80L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  temperature <- runif(n, 10, 25)
  dat <- data.frame(
    body_mass   = rnorm(n, 30 + 0.4 * temperature,
                       exp(0.5 + 0.1 * temperature)),
    temperature = temperature
  )
  drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ temperature, sigma ~ temperature),
    family = stats::gaussian(),
    data   = dat
  )
}

fit_drm_biv_gaussian <- function(seed = 20260524L, n = 80L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  x1 <- rnorm(n)
  x2 <- rnorm(n)
  # Cholesky factorisation for two correlated standard normals (rho = 0.6),
  # no extra package needed (avoids a Suggests dependency on MASS):
  e1 <- rnorm(n)
  e2 <- 0.6 * e1 + sqrt(1 - 0.6^2) * rnorm(n)
  dat <- data.frame(
    y1 = 30 + 1.5 * x1 + e1,
    y2 = 10 + 0.8 * x2 + e2,
    x1 = x1,
    x2 = x2
  )
  drmTMB::drmTMB(
    drmTMB::drm_formula(
      mu1    = y1 ~ x1,
      mu2    = y2 ~ x2,
      sigma1 = ~ 1,
      sigma2 = ~ 1,
      rho12  = ~ 1
    ),
    family = drmTMB::biv_gaussian(),
    data   = dat
  )
}

fit_drm_with_re <- function(seed = 2L, n = 80L, n_groups = 6L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  group <- factor(rep(letters[seq_len(n_groups)], length.out = n))
  temperature <- runif(n, 10, 25)
  re <- rnorm(n_groups, sd = 1)
  dat <- data.frame(
    body_mass = rnorm(
      n,
      30 + 0.4 * temperature + re[as.integer(group)],
      exp(0.5 + 0.05 * temperature)
    ),
    temperature = temperature,
    group = group
  )
  drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ temperature + (1 | group),
                        sigma ~ temperature),
    family = stats::gaussian(),
    data   = dat
  )
}

fit_drm_student <- function(seed = 20260524L, n = 80L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  dat <- data.frame(
    y = rt(n, df = 5) * 2 + 10 + 0.5 * rnorm(n),
    x = rnorm(n)
  )
  drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ x, sigma ~ x, nu ~ 1),
    family = drmTMB::student(),
    data   = dat
  )
}

fit_drm_lognormal <- function(seed = 20260524L, n = 80L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  dat <- data.frame(
    y = exp(rnorm(n, mean = 2 + 0.5 * rnorm(n), sd = 0.3)),
    x = rnorm(n)
  )
  drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ x, sigma ~ 1),
    family = drmTMB::lognormal(),
    data   = dat
  )
}

fit_drm_gamma <- function(seed = 20260524L, n = 80L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  dat <- data.frame(
    y = rgamma(n, shape = 2, rate = 0.5),
    x = rnorm(n)
  )
  drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ x, sigma ~ 1),
    family = stats::Gamma(link = "log"),
    data   = dat
  )
}

fit_drm_beta <- function(seed = 20260524L, n = 80L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  dat <- data.frame(
    y = rbeta(n, 2, 5),
    x = rnorm(n)
  )
  drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ x, sigma ~ 1),
    family = drmTMB::beta(),
    data   = dat
  )
}

fit_drm_poisson <- function(seed = 20260524L, n = 80L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  dat <- data.frame(
    y = rpois(n, lambda = 4),
    x = rnorm(n)
  )
  drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ x),
    family = stats::poisson(),
    data   = dat
  )
}

fit_drm_nbinom2 <- function(seed = 20260524L, n = 80L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  dat <- data.frame(
    y = rnbinom(n, size = 3, mu = 5),
    x = rnorm(n)
  )
  drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ x, sigma ~ 1),
    family = drmTMB::nbinom2(),
    data   = dat
  )
}

fit_drm_beta_binomial <- function(seed = 20260524L, n = 80L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  trials <- sample(5:20, n, replace = TRUE)
  p <- plogis(0.5 + 0.5 * rnorm(n))
  successes <- rbinom(n, trials, p)
  dat <- data.frame(
    successes = successes,
    failures  = trials - successes,
    x         = rnorm(n)
  )
  drmTMB::drmTMB(
    drmTMB::drm_formula(cbind(successes, failures) ~ x, sigma ~ 1),
    family = drmTMB::beta_binomial(),
    data   = dat
  )
}

fit_drm_truncated_nbinom2 <- function(seed = 20260524L, n = 80L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  dat <- data.frame(
    y = pmax(1L, rnbinom(n, size = 2, mu = 4)),
    x = rnorm(n)
  )
  drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ x, sigma ~ 1),
    family = drmTMB::truncated_nbinom2(),
    data   = dat
  )
}

fit_drm_cumulative_logit <- function(seed = 20260524L, n = 200L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  x <- rnorm(n)
  y <- factor(
    cut(0.5 * x + rnorm(n), c(-Inf, -0.5, 0.5, Inf),
        labels = c("low", "mid", "high")),
    ordered = TRUE
  )
  drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ x),
    family = drmTMB::cumulative_logit(),
    data   = data.frame(y = y, x = x)
  )
}
