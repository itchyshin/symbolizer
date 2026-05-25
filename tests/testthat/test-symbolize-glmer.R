# Tests for v0.11 lme4 glmer (glmerMod) extractor.

fit_glmer_binomial <- function(seed = 1L, n = 100L, n_groups = 10L) {
  testthat::skip_if_not_installed("lme4")
  set.seed(seed)
  g <- factor(rep(seq_len(n_groups), length.out = n))
  dat <- data.frame(y = rbinom(n, 1, 0.5), x = rnorm(n), g = g)
  suppressWarnings(suppressMessages(lme4::glmer(
    y ~ x + (1 | g), data = dat, family = stats::binomial()
  )))
}

fit_glmer_poisson <- function(seed = 2L, n = 120L, n_groups = 10L) {
  testthat::skip_if_not_installed("lme4")
  set.seed(seed)
  g <- factor(rep(seq_len(n_groups), length.out = n))
  dat <- data.frame(y = rpois(n, lambda = 3), x = rnorm(n), g = g)
  suppressWarnings(suppressMessages(lme4::glmer(
    y ~ x + (1 | g), data = dat, family = stats::poisson()
  )))
}

test_that("symbolize.glmerMod handles binomial fits with (1 | g)", {
  fit <- fit_glmer_binomial()
  sym <- symbolize(fit)
  expect_equal(sym$model$class, "glmerMod")
  expect_equal(sym$model$family, "binomial")
  expect_true(nrow(sym$random_effects) >= 1L)
  expect_true("g" %in% sym$random_effects$group_var)
  expect_match(as_latex(sym), "Binomial", fixed = TRUE)
})

test_that("symbolize.glmerMod handles poisson fits with (1 | g)", {
  fit <- fit_glmer_poisson()
  sym <- symbolize(fit)
  expect_equal(sym$model$family, "poisson")
  expect_match(as_latex(sym), "Poisson", fixed = TRUE)
})
