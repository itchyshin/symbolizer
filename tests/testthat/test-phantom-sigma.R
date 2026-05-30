# Audit P2 (phantom-sigma sweep). A homoscedastic Gaussian fit has a single
# residual SD, not a scale submodel, so assumption_table must NOT carry the
# location-scale sigma rows (log(sigma_i) = gamma_0 + ..., sigma_i > 0) that
# the shared Gaussian template injects. A real dispersion submodel (glmmTMB
# dispformula with predictors) KEEPS them.

has_sigma_rows <- function(fit) {
  at <- assumption_table(symbolize(fit))
  any(at$submodel == "sigma", na.rm = TRUE)
}

test_that("homoscedastic Gaussian fits carry no scale-submodel rows", {
  set.seed(1)
  d <- data.frame(y = rnorm(60), x = rnorm(60),
                  g = factor(rep(letters[1:6], 10)))
  expect_false(has_sigma_rows(lm(y ~ x, data = d)))
  expect_false(has_sigma_rows(stats::glm(y ~ x, family = gaussian, data = d)))
  skip_if_not_installed("lme4")
  expect_false(has_sigma_rows(lme4::lmer(y ~ x + (1 | g), data = d)))
  skip_if_not_installed("glmmTMB")
  expect_false(has_sigma_rows(glmmTMB::glmmTMB(y ~ x + (1 | g), data = d)))
})

test_that("a real glmmTMB dispformula KEEPS the scale-submodel rows", {
  skip_if_not_installed("glmmTMB")
  set.seed(1)
  d <- data.frame(y = rnorm(60), x = rnorm(60))
  fit <- glmmTMB::glmmTMB(y ~ x, dispformula = ~ x, data = d)
  expect_true(has_sigma_rows(fit))  # location-scale: the sigma rows are real
})
