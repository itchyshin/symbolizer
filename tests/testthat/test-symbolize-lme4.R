fit_lmer_simple <- function(seed = 1L, n = 80L, n_groups = 10L) {
  testthat::skip_if_not_installed("lme4")
  set.seed(seed)
  g <- factor(rep(seq_len(n_groups), length.out = n))
  group_effect <- rnorm(n_groups, 0, 2)[as.integer(g)]
  temperature <- runif(n, 10, 25)
  body_mass <- rnorm(n, 30 + 0.4 * temperature + group_effect, 1.5)
  dat <- data.frame(body_mass = body_mass, temperature = temperature, g = g)
  suppressWarnings(suppressMessages(lme4::lmer(
    body_mass ~ temperature + (1 | g), data = dat
  )))
}

test_that("symbolize.lmerMod builds a symbolized_model for a Gaussian RE fit", {
  fit <- fit_lmer_simple()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "lmerMod")
  expect_equal(sym$model$family, "gaussian")
  expect_equal(sym$model$response, "body_mass")
  expect_true(nrow(sym$random_effects) >= 1L)
  expect_true("g" %in% sym$random_effects$group_var)
})

test_that("lme4 fixed_effects carries the 95% Wald confidence band", {
  fit <- fit_lmer_simple()
  sym <- symbolize(fit)
  expect_true(all(c("confint_low", "confint_high",
                    "excludes_zero", "ci_method") %in%
                  names(sym$fixed_effects)))
  expect_true(all(sym$fixed_effects$ci_method == "wald"))
  slope_row <- sym$fixed_effects[sym$fixed_effects$role == "predictor", ,
                                 drop = FALSE]
  expect_false(is.na(slope_row$confint_low))
  expect_false(is.na(slope_row$confint_high))
})

test_that("lme4 variance_components include both the RE SD and residual sigma", {
  fit <- fit_lmer_simple()
  sym <- symbolize(fit)
  vc <- sym$variance_components
  expect_true("g" %in% vc$group)
  expect_true("residual" %in% vc$group)
  expect_equal(vc$sd_estimate[vc$group == "residual"],
               as.numeric(stats::sigma(fit)),
               tolerance = 1e-6)
})

test_that("lme4 symbolize produces valid LaTeX", {
  fit <- fit_lmer_simple()
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  expect_match(tex, "Normal", fixed = TRUE)
})
