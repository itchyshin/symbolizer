# brms fits use MCMC; these tests skip on CRAN to avoid the multi-second
# per-test cost. NOT_CRAN=true is set by devtools::test() locally.
skip_if_brms_too_slow <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("brms")
}

test_that("symbolize.brmsfit builds a symbolized_model for a Gaussian fit", {
  skip_if_brms_too_slow()
  fit <- fit_brms_gaussian_simple()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "brmsfit")
  expect_equal(sym$model$family, "gaussian")
  expect_equal(sym$model$response, "body_mass")
  expect_equal(sym$metadata$ci_method, "credible")
})

test_that("brmsfit fixed_effects carries the 95% credible band with ci_method='credible'", {
  skip_if_brms_too_slow()
  fit <- fit_brms_gaussian_simple()
  sym <- symbolize(fit)
  expect_true(all(c("confint_low", "confint_high",
                    "excludes_zero", "ci_method") %in%
                  names(sym$fixed_effects)))
  expect_true(all(sym$fixed_effects$ci_method == "credible"))
  slope_row <- sym$fixed_effects[sym$fixed_effects$role == "predictor", ,
                                 drop = FALSE]
  expect_equal(nrow(slope_row), 1L)
  expect_false(is.na(slope_row$confint_low))
  expect_false(is.na(slope_row$confint_high))
  expect_true(slope_row$confint_low < slope_row$confint_high)
})

test_that("brmsfit (1 | g) random intercepts produce group + RE nodes", {
  skip_if_brms_too_slow()
  fit <- fit_brms_gaussian_re()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$random_effects) && nrow(sym$random_effects) >= 1L)
  expect_true("g" %in% sym$random_effects$group_var)
  expect_true("(Intercept)" %in% sym$random_effects$component)
  vc <- sym$variance_components
  expect_true("g" %in% vc$group)
  expect_true("residual" %in% vc$group)
  expect_true(all(vc$sd_estimate > 0))
})

test_that("brmsfit symbolize() produces valid LaTeX and a DAG", {
  skip_if_brms_too_slow()
  sym <- symbolize(fit_brms_gaussian_simple())
  tex <- as_latex(sym)
  expect_type(tex, "character")
  expect_match(tex, "Normal", fixed = TRUE)
  dag <- as_dag(sym)
  expect_s3_class(dag, "symbolic_dag")
  expect_true(nrow(dag$nodes) >= 3L)
})

test_that("parameter_interpretation on a brmsfit carries the credible band", {
  skip_if_brms_too_slow()
  sym <- symbolize(fit_brms_gaussian_simple())
  interp <- parameter_interpretation(sym, scale = "biological")
  expect_true(all(c("confint_low", "confint_high", "ci_method") %in%
                  names(interp)))
  expect_true(all(interp$ci_method == "credible"))
})
