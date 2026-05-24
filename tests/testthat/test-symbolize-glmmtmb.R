test_that("symbolize.glmmTMB builds a symbolized_model for a simple Gaussian fit", {
  fit <- fit_glmm_gaussian_simple()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "glmmTMB")
  expect_equal(sym$model$family, "gaussian")
  expect_equal(sym$model$response, "body_mass")
  expect_true(nrow(sym$fixed_effects) >= 2L)
  expect_true(all(c("submodel", "term_label", "estimate",
                    "confint_low", "confint_high",
                    "excludes_zero", "ci_method") %in%
                  names(sym$fixed_effects)))
})

test_that("symbolize.glmmTMB carries 95% Wald CIs that exclude zero on a strong slope", {
  fit <- fit_glmm_gaussian_simple()
  sym <- symbolize(fit)
  slope_row <- sym$fixed_effects[sym$fixed_effects$role == "predictor", , drop = FALSE]
  expect_equal(nrow(slope_row), 1L)
  expect_false(is.na(slope_row$confint_low))
  expect_false(is.na(slope_row$confint_high))
  expect_true(slope_row$confint_low < slope_row$confint_high)
  # The seeded simulation has slope 0.4 with sigma 1.5 across 80 obs and a
  # temperature range of 10-25, so the slope is well-separated from zero.
  expect_true(slope_row$excludes_zero)
  expect_equal(slope_row$ci_method, "wald")
})

test_that("symbolize.glmmTMB handles dispformula = ~ x and produces a sigma submodel", {
  fit <- fit_glmm_gaussian_dispformula()
  sym <- symbolize(fit)
  expect_true("sigma" %in% sym$fixed_effects$submodel)
  sigma_rows <- sym$fixed_effects[sym$fixed_effects$submodel == "sigma", , drop = FALSE]
  expect_true(nrow(sigma_rows) >= 2L)  # intercept + slope on temperature
  # Both should have non-NA CIs
  expect_false(any(is.na(sigma_rows$confint_low)))
  expect_false(any(is.na(sigma_rows$confint_high)))
})

test_that("symbolize.glmmTMB handles (1 | g) random intercepts on the conditional submodel", {
  fit <- fit_glmm_gaussian_re()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$random_effects) && nrow(sym$random_effects) >= 1L)
  expect_true("g" %in% sym$random_effects$group_var)
  expect_true("(Intercept)" %in% sym$random_effects$component)
  # Variance components should include both the RE SD and residual sigma
  vc <- sym$variance_components
  expect_true("residual" %in% vc$group)
  expect_true("g" %in% vc$group)
  # Residual SD should be positive
  resid_sd <- vc$sd_estimate[vc$group == "residual"]
  expect_true(resid_sd > 0)
})

test_that("symbolize.glmmTMB returns valid LaTeX for both mu-only and mu+sigma fits", {
  sym1 <- symbolize(fit_glmm_gaussian_simple())
  tex1 <- as_latex(sym1)
  expect_type(tex1, "character")
  expect_match(tex1, "Normal", fixed = TRUE)
  expect_match(tex1, "mu", fixed = TRUE)

  sym2 <- symbolize(fit_glmm_gaussian_dispformula())
  tex2 <- as_latex(sym2)
  expect_match(tex2, "log", fixed = TRUE)
  expect_match(tex2, "sigma", fixed = TRUE)
})

test_that("symbolize.glmmTMB rejects ziformula (not in v0.7 first slice)", {
  testthat::skip_if_not_installed("glmmTMB")
  set.seed(7L)
  n <- 60
  dat <- data.frame(y = rnorm(n), x = rnorm(n))
  fit <- suppressWarnings(glmmTMB::glmmTMB(
    y ~ x, ziformula = ~ x, data = dat, family = stats::gaussian()
  ))
  expect_error(symbolize(fit), "not in the first slice|Planned|reserved|not yet supported",
               ignore.case = TRUE)
})

test_that("symbolize.glmmTMB's interpretation tibble carries the CI columns", {
  fit <- fit_glmm_gaussian_simple()
  sym <- symbolize(fit)
  interp <- sym$interpretation
  expect_true(all(c("confint_low", "confint_high", "excludes_zero", "ci_method") %in%
                  names(interp)))
  # At least one row should have non-NA CI bounds (the intercept and slope)
  expect_true(sum(!is.na(interp$confint_low)) >= 1L)
})
