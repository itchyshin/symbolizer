# Helper fits for symbolize.glmmTMB tests. Skips the calling test if
# glmmTMB is not installed.

fit_glmm_gaussian_simple <- function(seed = 1L, n = 80L) {
  testthat::skip_if_not_installed("glmmTMB")
  suppressPackageStartupMessages(suppressWarnings(requireNamespace("glmmTMB", quietly = TRUE)))
  set.seed(seed)
  temperature <- runif(n, 10, 25)
  body_mass <- rnorm(n, 30 + 0.4 * temperature, 1.5)
  dat <- data.frame(body_mass = body_mass, temperature = temperature)
  suppressWarnings(glmmTMB::glmmTMB(
    body_mass ~ temperature,
    data = dat,
    family = stats::gaussian()
  ))
}

fit_glmm_gaussian_dispformula <- function(seed = 2L, n = 100L) {
  testthat::skip_if_not_installed("glmmTMB")
  suppressPackageStartupMessages(suppressWarnings(requireNamespace("glmmTMB", quietly = TRUE)))
  set.seed(seed)
  temperature <- runif(n, 10, 25)
  body_mass <- rnorm(n, 30 + 0.4 * temperature,
                     exp(0.3 + 0.05 * temperature))
  dat <- data.frame(body_mass = body_mass, temperature = temperature)
  suppressWarnings(glmmTMB::glmmTMB(
    body_mass ~ temperature,
    dispformula = ~ temperature,
    data = dat,
    family = stats::gaussian()
  ))
}

fit_glmm_gaussian_re <- function(seed = 3L, n = 120L, n_groups = 10L) {
  testthat::skip_if_not_installed("glmmTMB")
  suppressPackageStartupMessages(suppressWarnings(requireNamespace("glmmTMB", quietly = TRUE)))
  set.seed(seed)
  g <- factor(rep(seq_len(n_groups), length.out = n))
  group_effect <- rnorm(n_groups, 0, 2)[as.integer(g)]
  temperature <- runif(n, 10, 25)
  body_mass <- rnorm(n, 30 + 0.4 * temperature + group_effect, 1.5)
  dat <- data.frame(body_mass = body_mass, temperature = temperature, g = g)
  suppressWarnings(glmmTMB::glmmTMB(
    body_mass ~ temperature + (1 | g),
    data = dat,
    family = stats::gaussian()
  ))
}
