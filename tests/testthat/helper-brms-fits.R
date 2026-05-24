# Helper fits for symbolize.brmsfit tests. brms fits with MCMC take
# ~30s each even at tiny iter counts, so we cache the result in an
# environment-local lazy and only build once per R session.

.brms_fit_cache <- new.env(parent = emptyenv())

fit_brms_gaussian_simple <- function() {
  testthat::skip_if_not_installed("brms")
  if (is.null(.brms_fit_cache$simple)) {
    set.seed(1L)
    n <- 80L
    temperature <- runif(n, 10, 25)
    body_mass <- rnorm(n, 30 + 0.4 * temperature, 1.5)
    dat <- data.frame(body_mass = body_mass, temperature = temperature)
    .brms_fit_cache$simple <- suppressMessages(suppressWarnings(brms::brm(
      body_mass ~ temperature,
      data = dat,
      family = stats::gaussian(),
      chains = 1, iter = 300, warmup = 150,
      refresh = 0, silent = 2
    )))
  }
  .brms_fit_cache$simple
}

fit_brms_gaussian_re <- function() {
  testthat::skip_if_not_installed("brms")
  if (is.null(.brms_fit_cache$re)) {
    set.seed(2L)
    n <- 80L
    n_groups <- 10L
    g <- factor(rep(seq_len(n_groups), length.out = n))
    group_effect <- rnorm(n_groups, 0, 2)[as.integer(g)]
    temperature <- runif(n, 10, 25)
    body_mass <- rnorm(n, 30 + 0.4 * temperature + group_effect, 1.5)
    dat <- data.frame(body_mass = body_mass, temperature = temperature, g = g)
    .brms_fit_cache$re <- suppressMessages(suppressWarnings(brms::brm(
      body_mass ~ temperature + (1 | g),
      data = dat,
      family = stats::gaussian(),
      chains = 1, iter = 300, warmup = 150,
      refresh = 0, silent = 2
    )))
  }
  .brms_fit_cache$re
}
