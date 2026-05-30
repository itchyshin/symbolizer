# Tests for the PGLS marginal-covariance rendering of symbolize.phylolm.
#
# phylolm fits the PGLS MARGINAL form
#
#   y = X*beta + e,   e ~ N(0, sigma^2 * C(alpha))
#
# where C(alpha) is a dense, tree-derived correlation matrix (BM: C = A).
# There is NO u_p random effect: the phylogenetic signal lives entirely in
# the residual covariance. The pre-fix renderer reused the ordinary-Gaussian
# templates and produced a mathematically WRONG headline equation
# (N(mu, diag(sigma^2)) -- independent residuals) plus a self-contradicting
# assumptions block (an `independence` row firing next to the phylo rows, a
# `u_p` random-effect mislabel, and phantom sigma scale-submodel rows for a
# model that has a single scalar sigma^2). These tests lock in the corrected
# behavior. See docs/dev-log/audits/2026-05-29-capability-reverify.md
# (phylolm section).

test_that("as_latex(matrix) surfaces the dense PGLS covariance, not diag/OLS", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  tex <- as_latex(sym, notation = "matrix")
  # The phylogenetic correlation matrix A must appear in the headline
  # distribution line.
  expect_match(tex, "\\mathbf{A}", fixed = TRUE)
  # The covariance must be scaled by the phylogenetic variance sigma_p^2.
  expect_match(tex, "\\sigma_p^2", fixed = TRUE)
  # It must NOT assert an independent / diagonal residual covariance.
  expect_false(grepl("diag", tex, fixed = TRUE))
})

test_that("distribution$latex_matrix is the marginal covariance (sigma_p^2 A)", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  lm_tex <- sym$distribution$latex_matrix
  expect_match(lm_tex, "\\mathbf{A}", fixed = TRUE)
  expect_match(lm_tex, "\\sigma_p^2", fixed = TRUE)
  expect_false(grepl("diag", lm_tex, fixed = TRUE))
})

test_that("the assumptions block does NOT fire an independence row", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  a <- sym$assumptions
  # PGLS exists precisely because observations are NOT independent. The
  # plain `independence` row ("Observations are conditionally independent
  # given the predictors") must be dropped when a phylo signal is present.
  expect_false("independence" %in% a$assumption)
  expect_false("independence_given_random_effects" %in% a$assumption)
})

test_that("no phantom sigma scale-submodel assumption rows fire", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  a <- sym$assumptions
  # phylolm has ONE scalar sigma^2 and no scale submodel; the generic
  # gaussian sigma-submodel boilerplate (log(sigma_i) = gamma_0 + ...,
  # sigma_i > 0) must not appear.
  sigma_rows <- a[!is.na(a$submodel) & a$submodel == "sigma", , drop = FALSE]
  expect_equal(nrow(sigma_rows), 0L)
  expect_false(any(grepl("\\log(\\sigma_i)", a$expression_latex, fixed = TRUE)))
})

test_that("the phylo structure is NOT mislabeled as a u_p random effect", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  a <- sym$assumptions
  # phylolm marginalizes the phylo signal into the residual; there is no
  # u_p random-effect tibble, so the random-effect-style rows must not fire.
  expect_false("phylo_random_effect" %in% a$assumption)
  expect_false(any(grepl("\\mathbf{u}_p", a$expression_latex, fixed = TRUE)))
})

test_that("a phylo marginal-covariance assumption row IS present", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  a <- sym$assumptions
  # The corrected marginal form must state the residual covariance
  # e ~ N(0, sigma^2 C(alpha)) (with C = A under BM) somewhere in the block.
  cov_rows <- a[grepl("\\mathbf{A}", a$expression_latex, fixed = TRUE), ,
                drop = FALSE]
  expect_true(nrow(cov_rows) >= 1L)
  # The marginal residual-covariance row (Cov(e) = sigma_p^2 A) is the
  # defining statement and must be present.
  expect_true("phylo_residual_covariance" %in% a$assumption)
  # The Brownian-motion / positive-definite rows (marginal-form variants,
  # no u_p reference) remain useful and should still fire.
  expect_true("phylo_marginal_brownian_motion" %in% a$assumption)
  expect_true("phylo_marginal_A_positive_definite" %in% a$assumption)
})

test_that("Pagel's lambda fit renders the marginal covariance too", {
  bundle <- fit_phylolm_lambda()
  sym <- symbolize(bundle$fit, data = bundle$data)
  tex <- as_latex(sym, notation = "matrix")
  expect_match(tex, "\\mathbf{A}", fixed = TRUE)
  expect_false(grepl("diag", tex, fixed = TRUE))
  a <- sym$assumptions
  expect_false("independence" %in% a$assumption)
  expect_false("phylo_random_effect" %in% a$assumption)
})
