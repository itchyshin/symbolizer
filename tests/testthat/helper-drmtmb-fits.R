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
