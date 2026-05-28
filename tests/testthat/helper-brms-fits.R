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

# v0.21-redo: phylogenetic random-effect fit via gr(species, cov = A).
# Uses a small (k = 8) ultrametric tree so brms compile + sample stays
# under ~30s. The data2 list carries the tips-only A matrix that brms
# expects. Returns a bundle with the fit, the data, and the A matrix so
# the caller can inspect any of the three.
fit_brms_phylo <- function() {
  testthat::skip_if_not_installed("brms")
  testthat::skip_if_not_installed("ape")
  if (is.null(.brms_fit_cache$phylo)) {
    set.seed(11L)
    k <- 8L
    tree <- ape::rcoal(k)
    tree$tip.label <- paste0("sp", seq_len(k))
    # Tips-only correlation matrix scaled so diag = 1.
    C <- ape::vcv(tree, corr = TRUE)
    sigma_p <- 1.0
    sigma_e <- 0.5
    u_phylo <- as.numeric(crossprod(chol(sigma_p^2 * C), rnorm(k)))
    dat <- data.frame(
      species = factor(tree$tip.label, levels = tree$tip.label),
      y = u_phylo + rnorm(k, sd = sigma_e)
    )
    .brms_fit_cache$phylo <- suppressMessages(suppressWarnings(brms::brm(
      y ~ 1 + (1 | gr(species, cov = A)),
      data = dat,
      data2 = list(A = C),
      family = stats::gaussian(),
      chains = 1, iter = 300, warmup = 150,
      refresh = 0, silent = 2
    )))
    .brms_fit_cache$phylo_data <- dat
    .brms_fit_cache$phylo_A    <- C
  }
  list(
    fit  = .brms_fit_cache$phylo,
    data = .brms_fit_cache$phylo_data,
    A    = .brms_fit_cache$phylo_A
  )
}
