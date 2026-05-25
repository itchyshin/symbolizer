# Helper fits for symbolize.MCMCglmm tests. MCMCglmm fits are fast at
# small iter counts (~1-2s), so we don't cache aggressively.

fit_mcmcglmm_gaussian_simple <- function(seed = 1L, n = 80L) {
  testthat::skip_if_not_installed("MCMCglmm")
  set.seed(seed)
  temperature <- runif(n, 10, 25)
  body_mass <- rnorm(n, 30 + 0.4 * temperature, 1.5)
  dat <- data.frame(body_mass = body_mass, temperature = temperature)
  fit <- suppressWarnings(suppressMessages(MCMCglmm::MCMCglmm(
    body_mass ~ temperature,
    data = dat,
    family = "gaussian",
    nitt = 1500, burnin = 500, thin = 2, verbose = FALSE
  )))
  list(fit = fit, data = dat)
}

fit_mcmcglmm_gaussian_re <- function(seed = 2L, n = 80L, n_groups = 10L) {
  testthat::skip_if_not_installed("MCMCglmm")
  set.seed(seed)
  g <- factor(rep(seq_len(n_groups), length.out = n))
  group_effect <- rnorm(n_groups, 0, 2)[as.integer(g)]
  temperature <- runif(n, 10, 25)
  body_mass <- rnorm(n, 30 + 0.4 * temperature + group_effect, 1.5)
  dat <- data.frame(body_mass = body_mass, temperature = temperature, g = g)
  fit <- suppressWarnings(suppressMessages(MCMCglmm::MCMCglmm(
    body_mass ~ temperature,
    random = ~g,
    data = dat,
    family = "gaussian",
    nitt = 1500, burnin = 500, thin = 2, verbose = FALSE
  )))
  list(fit = fit, data = dat)
}
