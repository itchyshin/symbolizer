# Tests for symbolize.brms on a meta-analytic fit with se(sqrt(vi)).
# Required by v0.22.1 Widget 2 (§4 of symbolizer-meta-analysis.Rmd) +
# the v0.22.2 location-scale Widget 3.

test_that("symbolize() runs on a brms fit with se(sqrt(vi)) + phylo + multilevel", {
  testthat::skip_on_cran()
  fit <- fit_brms_phylo_meta()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
})

test_that("metadata$context is 'meta_analysis' on a brms se(sqrt(vi)) fit", {
  testthat::skip_on_cran()
  fit <- fit_brms_phylo_meta()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$metadata$context))
  expect_match(sym$metadata$context, "meta_analysis", fixed = TRUE)
})

test_that("metadata$phylo_representation is tagged when gr(., cov = A) is in the formula", {
  testthat::skip_on_cran()
  fit <- fit_brms_phylo_meta()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$metadata$phylo_representation))
})
