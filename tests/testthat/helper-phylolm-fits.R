# Helper fits for symbolize.phylolm tests. phylolm fits are very fast
# (< 1s for k = 10 species), so no caching needed.

fit_phylolm_bm <- function(seed = 31L, k = 10L) {
  testthat::skip_if_not_installed("phylolm")
  testthat::skip_if_not_installed("ape")
  set.seed(seed)
  tree <- ape::rcoal(k)
  tree$tip.label <- paste0("sp", seq_len(k))
  # Generate phylo-correlated y via the BM covariance matrix.
  C <- ape::vcv(tree, corr = TRUE)
  sigma2_true <- 1.0
  y <- as.numeric(crossprod(chol(sigma2_true * C), rnorm(k)))
  x <- rnorm(k)
  dat <- data.frame(y = y, x = x, row.names = tree$tip.label)
  fit <- phylolm::phylolm(y ~ x, data = dat, phy = tree, model = "BM")
  list(fit = fit, data = dat, tree = tree, A = C)
}

fit_phylolm_lambda <- function(seed = 32L, k = 10L) {
  testthat::skip_if_not_installed("phylolm")
  testthat::skip_if_not_installed("ape")
  set.seed(seed)
  tree <- ape::rcoal(k)
  tree$tip.label <- paste0("sp", seq_len(k))
  C <- ape::vcv(tree, corr = TRUE)
  sigma2_true <- 1.0
  y <- as.numeric(crossprod(chol(sigma2_true * C), rnorm(k))) +
    rnorm(k, sd = 0.5)
  x <- rnorm(k)
  dat <- data.frame(y = y, x = x, row.names = tree$tip.label)
  fit <- suppressWarnings(
    phylolm::phylolm(y ~ x, data = dat, phy = tree, model = "lambda")
  )
  list(fit = fit, data = dat, tree = tree, A = C)
}
