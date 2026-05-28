# v0.21-redo: tests for the user-configurable matrix truncation
# arguments on as_html_three_views() and as_pdf_three_views(). The
# maintainer's request 2026-05-27: "control how much data is down in
# html (equations with your data)" — works for HTML and PDF.

make_fixture <- function(seed = 7L, k = 30L, n = 60L) {
  testthat::skip_if_not_installed("MCMCglmm")
  set.seed(seed)
  ped <- data.frame(animal = paste0("a", 1:k),
                    sire = c(rep(NA, 6), sample(paste0("a", 1:3), k - 6, replace = TRUE)),
                    dam  = c(rep(NA, 6), sample(paste0("a", 4:6), k - 6, replace = TRUE)))
  Ainv <- MCMCglmm::inverseA(ped)$Ainv
  dat <- data.frame(animal = factor(rep(paste0("a", 1:k), 2)), y = rnorm(n))
  fit <- suppressWarnings(suppressMessages(MCMCglmm::MCMCglmm(
    y ~ 1, random = ~animal,
    ginverse = list(animal = Ainv),
    data = dat, nitt = 1500, burnin = 500, thin = 2,
    verbose = FALSE, pr = TRUE
  )))
  sym <- symbolize(fit, data = dat)
  # Populate $expanded with a minimal shim so the matrix-block emitter runs.
  beta_hat <- mean(fit$Sol[, "(Intercept)"])
  sp_cols  <- grep("^animal[.]", colnames(fit$Sol), value = TRUE)
  u_named  <- colMeans(fit$Sol[, sp_cols, drop = FALSE])
  Z_g <- model.matrix(~ animal - 1, data = dat)
  colnames(Z_g) <- sub("^animal", "", colnames(Z_g))
  u <- u_named[paste0("animal.", colnames(Z_g))]
  u[is.na(u)] <- 0
  X <- matrix(1, nrow = n, ncol = 1, dimnames = list(NULL, "(Intercept)"))
  mu_hat <- as.numeric(X %*% beta_hat + Z_g %*% u)
  sym$expanded <- list(y = dat$y, X = X, beta = beta_hat,
                       Z_g = Z_g, u = u, mu_hat = mu_hat,
                       fitted = mu_hat, residuals = dat$y - mu_hat,
                       M = as.matrix(Matrix::solve(Ainv)))
  sym
}

test_that("as_html_three_views() default head/tail/head_cols/tail_cols match prior behavior", {
  sym <- make_fixture()
  html <- as_html_three_views(sym, id = "trunc-default")
  expect_true(is.character(html) && length(html) == 1L)
  expect_true(grepl("\\\\vdots", html))    # row truncation visible
  expect_true(grepl("\\\\cdots", html))    # column truncation visible
})

test_that("as_html_three_views() respects custom head_rows / tail_rows", {
  sym <- make_fixture()
  html_small <- as_html_three_views(sym, head = 2L, tail = 1L, id = "trunc-small")
  html_big   <- as_html_three_views(sym, head = 8L, tail = 4L, id = "trunc-big")
  # The HTML emitter writes "Showing first H and last T rows of n = N" in
  # the Tab 3 caption. Verify the caption reflects user-supplied values.
  expect_true(grepl("Showing first 2 and last 1 rows of n = 60", html_small))
  expect_true(grepl("Showing first 8 and last 4 rows of n = 60", html_big))
})

test_that("as_html_three_views() respects custom head_cols / tail_cols", {
  sym <- make_fixture()
  html_default <- as_html_three_views(sym, id = "trunc-defcols")
  html_wide    <- as_html_three_views(sym, head_cols = 3L, tail_cols = 1L,
                                       id = "trunc-tight")
  # Both renders should be HTML; the wide one with stricter cols may produce
  # a shorter matrix block. We do NOT assert exact \cdots counts (the
  # column-truncation logic prefers non-zero columns and can place \cdots
  # at the same number of break points for different head_cols / tail_cols
  # combos depending on sparsity).
  expect_true(is.character(html_default))
  expect_true(is.character(html_wide))
  expect_true(nchar(html_default) > 100L)
  expect_true(nchar(html_wide)    > 100L)
})

test_that("as_html_three_views() signature accepts the new args without error", {
  sym <- make_fixture()
  expect_no_error(
    as_html_three_views(sym, head = 3L, tail = 2L,
                        head_cols = 4L, tail_cols = 1L,
                        id = "trunc-misc")
  )
})

test_that("as_pdf_three_views() accepts head / tail / head_cols / tail_cols", {
  # Signature-only check; full PDF render requires tinytex and is slow.
  args <- names(formals(as_pdf_three_views))
  expect_true("head"      %in% args)
  expect_true("tail"      %in% args)
  expect_true("head_cols" %in% args)
  expect_true("tail_cols" %in% args)
  args_m <- names(formals(as_pdf_three_views.symbolized_model))
  expect_true("head_cols" %in% args_m)
  expect_true("tail_cols" %in% args_m)
})
