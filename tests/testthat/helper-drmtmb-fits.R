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
