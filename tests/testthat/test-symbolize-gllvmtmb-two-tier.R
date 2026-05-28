# v0.21.6-redo: tests for the two-tier (Sigma_B + Sigma_W) widget contract on
# `symbolize.gllvmTMB`. The three-views renderer's Tab 3 needs Lambda_W,
# Z_W, Psi_W, Sigma_W, and a per-trait Repeatability vector.

test_that("glm_has_within_unit() detects an obs-level latent() term", {
  fit <- fit_gllvm_two_tier()
  expect_true(symbolizer:::glm_has_within_unit(fit))
})

test_that("glm_has_within_unit() returns FALSE for a between-only fit", {
  fit <- fit_gllvm_with_unique()  # between only; no obs-level term
  expect_false(symbolizer:::glm_has_within_unit(fit))
})

test_that("expanded$Lambda_W is populated for a two-tier fit (n_traits x d_W)", {
  fit <- fit_gllvm_two_tier()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$Lambda_W),
              info = "expanded$Lambda_W is NULL on a two-tier fit")
  expect_true(is.matrix(sym$expanded$Lambda_W))
  expect_equal(nrow(sym$expanded$Lambda_W), as.integer(fit$n_traits))
  # d_W stored in tmb_data
  expect_equal(ncol(sym$expanded$Lambda_W),
               as.integer(fit$tmb_data$d_W))
})

test_that("expanded$Z_W is the n_obs x d_W observation-level latent matrix", {
  fit <- fit_gllvm_two_tier()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$Z_W))
  expect_true(is.matrix(sym$expanded$Z_W))
  expect_equal(nrow(sym$expanded$Z_W), length(sym$expanded$y))
  expect_equal(ncol(sym$expanded$Z_W),
               as.integer(fit$tmb_data$d_W))
})

test_that("expanded$Psi_W is a length-n_traits SD vector on a two-tier fit", {
  fit <- fit_gllvm_two_tier()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$Psi_W))
  expect_true(is.numeric(sym$expanded$Psi_W))
  expect_equal(length(sym$expanded$Psi_W), as.integer(fit$n_traits))
})

test_that("expanded$Lambda_W / Z_W / Psi_W stay NULL on a between-only fit", {
  fit <- fit_gllvm_with_unique()  # between only
  sym <- symbolize(fit)
  expect_null(sym$expanded$Lambda_W)
  expect_null(sym$expanded$Z_W)
  expect_null(sym$expanded$Psi_W)
})

test_that("expanded$Sigma_W closes Λ_W Λ_W^T + diag(Ψ_W²) to 1e-6", {
  fit <- fit_gllvm_two_tier()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$Sigma_W))
  expect_true(is.matrix(sym$expanded$Sigma_W))
  T_n <- as.integer(fit$n_traits)
  expect_equal(dim(sym$expanded$Sigma_W), c(T_n, T_n))
  closure <- sym$expanded$Lambda_W %*% t(sym$expanded$Lambda_W) +
             diag(sym$expanded$Psi_W^2)
  expect_equal(sym$expanded$Sigma_W, closure, tolerance = 1e-6)
})

test_that("expanded$Sigma_B closes Λ_B Λ_B^T + diag(Ψ_B²) to 1e-6", {
  fit <- fit_gllvm_two_tier()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$Sigma_B))
  closure <- sym$expanded$Lambda_B %*% t(sym$expanded$Lambda_B) +
             diag(sym$expanded$Psi_B^2)
  expect_equal(sym$expanded$Sigma_B, closure, tolerance = 1e-6)
})

# ---- Task 5 ----
test_that("glm_compute_repeatability returns the per-trait R_t formula", {
  Sigma_B <- diag(c(0.62, 0.45, 0.58, 0.31, 0.40))
  Sigma_W <- diag(c(0.38, 0.55, 0.42, 0.69, 0.60))
  rep_v   <- symbolizer:::glm_compute_repeatability(Sigma_B, Sigma_W)
  expect_equal(rep_v, diag(Sigma_B) / (diag(Sigma_B) + diag(Sigma_W)),
               tolerance = 1e-12)
  expect_equal(length(rep_v), 5L)
})

test_that("glm_compute_repeatability returns NULL when Sigma_W is NULL", {
  Sigma_B <- diag(c(0.62, 0.45, 0.58))
  expect_null(symbolizer:::glm_compute_repeatability(Sigma_B, NULL))
})

# ---- Task 6 ----
test_that("expanded$Repeatability is the per-trait R_t vector on a two-tier fit", {
  fit <- fit_gllvm_two_tier()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$Repeatability))
  expect_equal(length(sym$expanded$Repeatability),
               as.integer(fit$n_traits))
  expected_R <- diag(sym$expanded$Sigma_B) /
                (diag(sym$expanded$Sigma_B) + diag(sym$expanded$Sigma_W))
  expect_equal(sym$expanded$Repeatability, expected_R, tolerance = 1e-12)
})

test_that("expanded$Repeatability stays NULL on a between-only fit", {
  fit <- fit_gllvm_with_unique()
  sym <- symbolize(fit)
  expect_null(sym$expanded$Repeatability)
})
