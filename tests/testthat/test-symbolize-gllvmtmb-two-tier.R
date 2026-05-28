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
