# Helper fits for symbolize.sdmTMB tests.

fit_sdmtmb_gaussian_spatial <- function(seed = 1L, n = 300L) {
  testthat::skip_if_not_installed("sdmTMB")
  set.seed(seed)
  dat <- data.frame(x = runif(n), y_loc = runif(n), z = rnorm(n))
  dat$obs <- 2 + 0.5 * dat$z + rnorm(n, 0, 1)
  mesh <- sdmTMB::make_mesh(dat, c("x", "y_loc"), cutoff = 0.1)
  suppressWarnings(sdmTMB::sdmTMB(
    obs ~ z, data = dat, mesh = mesh,
    family = stats::gaussian(), spatial = "on"
  ))
}
