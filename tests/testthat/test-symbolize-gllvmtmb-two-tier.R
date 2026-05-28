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
