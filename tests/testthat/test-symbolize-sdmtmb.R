# Tests for the v0.12 symbolize.sdmTMB() extractor.

test_that("symbolize.sdmTMB builds a symbolized_model for a Gaussian spatial fit", {
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "sdmTMB")
  expect_equal(sym$model$family, "gaussian")
  expect_true(sym$model$spatial)
  expect_false(sym$model$spatiotemporal)
})

test_that("symbolize.sdmTMB fixed effects carry estimates and Wald CIs", {
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  fe <- sym$fixed_effects
  expect_true(nrow(fe) >= 2L)
  expect_true(all(is.finite(fe$estimate)))
  expect_equal(fe$ci_method[[1L]], "wald")
  expect_true(any(fe$role == "intercept"))
})

test_that("symbolize.sdmTMB variance_components has spatial parameters", {
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  vc <- sym$variance_components
  expect_true(nrow(vc) >= 2L)
  expect_true(any(vc$kind == "spatial_random"))
  expect_true(any(vc$kind == "residual"))
})

test_that("symbolize.sdmTMB random_effects has a site/intercept row", {
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  re <- sym$random_effects
  expect_true(!is.null(re) && nrow(re) >= 1L)
  expect_equal(re$group_var[[1L]], "site")
})

test_that("symbolize.sdmTMB LaTeX renders the spatial random field", {
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  expect_match(tex, "Normal", fixed = TRUE)
  expect_match(tex, "u_{site", fixed = TRUE)
})
