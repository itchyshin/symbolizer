# Helper fits for symbolize.psem tests. piecewiseSEM `psem()` glues
# per-node fits (here lm) into a structural equation model; the bridge
# walks the list and delegates to symbolize.<class>() per node.

fit_psem_lm_chain <- function(seed = 1L, n = 80L) {
  testthat::skip_if_not_installed("piecewiseSEM")
  set.seed(seed)
  d <- data.frame(x = stats::rnorm(n), z = stats::rnorm(n))
  d$m <- 0.5 * d$x + stats::rnorm(n)
  d$y <- 0.4 * d$m + 0.3 * d$z + stats::rnorm(n)
  m1 <- stats::lm(m ~ x, data = d)
  m2 <- stats::lm(y ~ m + z, data = d)
  fit <- piecewiseSEM::psem(m1, m2, data = d)
  list(fit = fit, data = d, node_names = c("m", "y"))
}

fit_psem_lm_with_cor <- function(seed = 2L, n = 80L) {
  testthat::skip_if_not_installed("piecewiseSEM")
  set.seed(seed)
  d <- data.frame(x = stats::rnorm(n), w = stats::rnorm(n))
  d$m <- 0.5 * d$x + stats::rnorm(n)
  d$y <- 0.4 * d$m + 0.3 * d$w + stats::rnorm(n)
  m1 <- stats::lm(m ~ x, data = d)
  m2 <- stats::lm(y ~ m + w, data = d)
  arc <- piecewiseSEM::`%~~%`(w, x)
  fit <- piecewiseSEM::psem(m1, m2, arc, data = d)
  list(fit = fit, data = d, node_names = c("m", "y"))
}
