# Tests for the v0.13.1 symbolize.rma.mv() extractor.

test_that("symbolize.rma.mv handles multilevel meta-analysis (~ 1 | district / study)", {
  fit <- fit_metafor_rma_mv()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "rma.mv")
  expect_equal(sym$model$family, "meta_normal")
  expect_equal(sym$model$n_random_tiers, 1L)  # nested syntax counts as 1 formula
})

test_that("rma.mv variance_components has one row per random-effect tier", {
  fit <- fit_metafor_rma_mv()
  sym <- symbolize(fit)
  vc <- sym$variance_components
  # district + district/study + sampling = 3 rows
  expect_true(nrow(vc) >= 3L)
  expect_true("heterogeneity" %in% vc$kind)
  expect_true("sampling_variance" %in% vc$kind)
  # Both heterogeneity rows have positive var_estimate
  hg <- vc[vc$kind == "heterogeneity", , drop = FALSE]
  expect_true(all(hg$var_estimate > 0))
})

test_that("rma.mv LaTeX shows multiple u_{tier(i)} terms in the linear predictor", {
  fit <- fit_metafor_rma_mv()
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  expect_match(tex, "u_{district", fixed = TRUE)
  expect_match(tex, "u_{district/study", fixed = TRUE)
})

test_that("rma.mv with R-matrix tags the tier kind = 'structured'", {
  fit <- fit_metafor_rma_mv_structured()
  sym <- symbolize(fit)
  vc <- sym$variance_components
  expect_true("structured" %in% vc$kind)
  expect_true("heterogeneity" %in% vc$kind)
  # The 'd2' row is the structured one
  struct_row <- vc[vc$kind == "structured", , drop = FALSE]
  expect_equal(struct_row$group[[1L]], "d2")
})

test_that("rma.mv structured_random metadata captures R-matrix dimension", {
  fit <- fit_metafor_rma_mv_structured()
  sym <- symbolize(fit)
  sr <- sym$metadata$structured_random
  expect_s3_class(sr, "data.frame")
  expect_equal(nrow(sr), 1L)
  expect_equal(sr$group[[1L]], "d2")
  expect_true(sr$matrix_dim[[1L]] > 1L)
  expect_equal(sr$matrix_kind[[1L]], "R")
})

test_that("rma.mv interpretation tibble has the moderator-readable rows", {
  fit <- fit_metafor_rma_mv()
  sym <- symbolize(fit)
  interp <- sym$interpretation
  expect_s3_class(interp, "data.frame")
  expect_true(nrow(interp) >= 1L)
})
