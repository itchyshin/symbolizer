test_that("symbolize.MCMCglmm requires the data argument", {
  testthat::skip_if_not_installed("MCMCglmm")
  bundle <- fit_mcmcglmm_gaussian_simple()
  expect_error(symbolize(bundle$fit), "data.*required|MCMCglmm.*data",
               ignore.case = TRUE)
})

test_that("symbolize.MCMCglmm builds a symbolized_model for a Gaussian fit", {
  bundle <- fit_mcmcglmm_gaussian_simple()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "MCMCglmm")
  expect_equal(sym$model$family, "gaussian")
  expect_equal(sym$model$response, "body_mass")
  expect_equal(sym$metadata$ci_method, "credible")
})

test_that("MCMCglmm fixed_effects carries 95% credible band labelled 'credible'", {
  bundle <- fit_mcmcglmm_gaussian_simple()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_true(all(c("confint_low", "confint_high",
                    "excludes_zero", "ci_method") %in%
                  names(sym$fixed_effects)))
  expect_true(all(sym$fixed_effects$ci_method == "credible"))
  slope_row <- sym$fixed_effects[sym$fixed_effects$role == "predictor", ,
                                 drop = FALSE]
  expect_equal(nrow(slope_row), 1L)
  expect_false(is.na(slope_row$confint_low))
  expect_false(is.na(slope_row$confint_high))
})

test_that("MCMCglmm ~ g random intercepts produce group + RE rows", {
  bundle <- fit_mcmcglmm_gaussian_re()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_true(!is.null(sym$random_effects) && nrow(sym$random_effects) >= 1L)
  expect_true("g" %in% sym$random_effects$group_var)
  expect_true("(Intercept)" %in% sym$random_effects$component)
  vc <- sym$variance_components
  expect_true("g" %in% vc$group)
  expect_true("residual" %in% vc$group)
})

test_that("symbolize.MCMCglmm produces valid LaTeX", {
  bundle <- fit_mcmcglmm_gaussian_simple()
  sym <- symbolize(bundle$fit, data = bundle$data)
  tex <- as_latex(sym)
  expect_type(tex, "character")
  expect_match(tex, "Normal", fixed = TRUE)
})
