# Tests for symbolize.lm() and symbolize.glm() (v0.10 first slice).

test_that("symbolize.lm builds a symbolized_model for a Gaussian fit", {
  fit <- lm(mpg ~ cyl, data = mtcars)
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "lm")
  expect_equal(sym$model$family, "gaussian")
  expect_equal(sym$model$response, "mpg")
  expect_true(nrow(sym$fixed_effects) >= 2L)
  expect_true(all(c("confint_low", "confint_high",
                    "excludes_zero", "ci_method") %in%
                  names(sym$fixed_effects)))
  # The strong cyl effect in mtcars excludes zero
  slope_row <- sym$fixed_effects[sym$fixed_effects$role == "predictor", ,
                                 drop = FALSE]
  expect_true(slope_row$excludes_zero[[1L]])
})

test_that("symbolize.lm captures the residual SD as a variance component", {
  fit <- lm(mpg ~ cyl, data = mtcars)
  sym <- symbolize(fit)
  vc <- sym$variance_components
  expect_equal(nrow(vc), 1L)
  expect_equal(vc$group, "residual")
  expect_equal(vc$sd_estimate, as.numeric(sigma(fit)))
})

test_that("symbolize.glm handles a Gaussian glm identically to lm", {
  fit_lm <- lm(mpg ~ cyl, data = mtcars)
  fit_glm <- glm(mpg ~ cyl, data = mtcars, family = stats::gaussian())
  sym_lm <- symbolize(fit_lm)
  sym_glm <- symbolize(fit_glm)
  # Class and package differ but coefficient estimates should match
  expect_equal(sym_lm$fixed_effects$estimate, sym_glm$fixed_effects$estimate,
               tolerance = 1e-6)
  expect_equal(sym_glm$model$class, "glm")
})

test_that("symbolize.glm handles a binomial fit", {
  set.seed(1L)
  n <- 100L
  dat <- data.frame(y = rbinom(n, 1, 0.5), x = rnorm(n))
  fit <- glm(y ~ x, data = dat, family = stats::binomial())
  sym <- symbolize(fit)
  expect_equal(sym$model$family, "binomial")
  expect_true(nrow(sym$fixed_effects) >= 2L)
  expect_equal(sym$fixed_effects$ci_method[[1L]], "wald")
})

test_that("symbolize.glm handles a Poisson fit", {
  set.seed(1L)
  n <- 100L
  dat <- data.frame(y = rpois(n, lambda = 3), x = rnorm(n))
  fit <- glm(y ~ x, data = dat, family = stats::poisson())
  sym <- symbolize(fit)
  expect_equal(sym$model$family, "poisson")
})

test_that("lm symbolize produces valid LaTeX", {
  fit <- lm(mpg ~ cyl, data = mtcars)
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  expect_match(tex, "Normal", fixed = TRUE)
})
