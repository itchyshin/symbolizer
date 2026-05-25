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

fit_glmm_binomial <- function(seed = 11L, n = 100L) {
  testthat::skip_if_not_installed("glmmTMB")
  suppressPackageStartupMessages(suppressWarnings(requireNamespace("glmmTMB", quietly = TRUE)))
  set.seed(seed)
  dat <- data.frame(y = rbinom(n, 1, 0.5), x = rnorm(n))
  suppressWarnings(glmmTMB::glmmTMB(y ~ x, data = dat,
                                    family = stats::binomial()))
}

fit_glmm_poisson <- function(seed = 12L, n = 120L) {
  testthat::skip_if_not_installed("glmmTMB")
  suppressPackageStartupMessages(suppressWarnings(requireNamespace("glmmTMB", quietly = TRUE)))
  set.seed(seed)
  dat <- data.frame(y = rpois(n, lambda = 3), x = rnorm(n))
  suppressWarnings(glmmTMB::glmmTMB(y ~ x, data = dat,
                                    family = stats::poisson()))
}

fit_glmm_nbinom2 <- function(seed = 13L, n = 120L) {
  testthat::skip_if_not_installed("glmmTMB")
  suppressPackageStartupMessages(suppressWarnings(requireNamespace("glmmTMB", quietly = TRUE)))
  set.seed(seed)
  dat <- data.frame(y = rnbinom(n, mu = 3, size = 2), x = rnorm(n))
  suppressWarnings(glmmTMB::glmmTMB(y ~ x, data = dat,
                                    family = glmmTMB::nbinom2()))
}

# v0.16: meta-analysis-via-glmmTMB via propto() covariance structure.
# Simulates a small block-diagonal V matrix (within-study sampling
# correlation rho = 0.5), then fits y ~ 1 + (1|study) + propto(0+obs|g, V).
fit_glmm_meta_propto <- function(seed = 16L, k_studies = 10L, k_per = 3L) {
  testthat::skip_if_not_installed("glmmTMB")
  testthat::skip_if_not_installed("MASS")
  suppressPackageStartupMessages(suppressWarnings(requireNamespace("glmmTMB", quietly = TRUE)))
  set.seed(seed)
  study <- rep(seq_len(k_studies), times = k_per)
  k <- length(study)
  id <- seq_len(k)
  vi <- rbeta(k, 2, 20)
  V <- matrix(0, nrow = k, ncol = k)
  for (s in unique(study)) {
    idx <- which(study == s)
    for (i in idx) for (j in idx) {
      V[i, j] <- if (i == j) vi[i] else 0.5 * sqrt(vi[i] * vi[j])
    }
  }
  rownames(V) <- colnames(V) <- as.character(id)
  true_y <- 0 + rnorm(k_studies, 0, 0.5)[study]
  y <- true_y + as.numeric(MASS::mvrnorm(1, rep(0, k), V))
  dat <- data.frame(y = y, vi = vi, study = factor(study),
                    obs = factor(id), g = factor(1))
  # glmmTMB's propto() is not exported; the formula is evaluated in
  # the glmmTMB namespace at fit time, so writing it without a
  # namespace qualifier is correct.
  suppressWarnings(glmmTMB::glmmTMB(
    y ~ 1 + (1 | study) + propto(0 + obs | g, V),
    data = dat, REML = TRUE
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
