# Robustness: interactions across the full family / class matrix.
# Each fit is `y ~ x * sex` (continuous-by-factor). The test checks
# that the interaction row appears in fixed_effects with a sensible
# estimate, the CI band columns are populated, and LaTeX renders.

interaction_smoke <- function(sym, expect_response = "y") {
  expect_s3_class(sym, "symbolized_model")
  fe <- sym$fixed_effects
  expect_true(any(fe$role == "interaction"))
  ix_rows <- fe[fe$role == "interaction", , drop = FALSE]
  expect_true(nrow(ix_rows) >= 1L)
  # Interaction estimate should be finite
  expect_true(all(is.finite(ix_rows$estimate)))
  # CI band columns should exist (NA is allowed on tiny fits)
  expect_true(all(c("confint_low", "confint_high", "ci_method") %in%
                  names(fe)))
  expect_match(as_latex(sym), expect_response, fixed = TRUE)
}

make_factor_data <- function(seed = 1L, n = 200L, response_kind = c("normal","binary","count","gamma")) {
  response_kind <- match.arg(response_kind)
  set.seed(seed)
  sex <- factor(rep(c("F", "M"), each = n / 2))
  x <- rnorm(n)
  eta <- 1 + 0.3 * x + 0.2 * (sex == "M") - 0.4 * x * (sex == "M")
  y <- switch(response_kind,
              normal = eta + rnorm(n, 0, 1),
              binary = rbinom(n, 1, plogis(eta)),
              count  = rpois(n, exp(eta)),
              gamma  = rgamma(n, shape = 2, scale = exp(eta) / 2))
  data.frame(y = y, x = x, sex = sex)
}

test_that("interactions: lm gaussian", {
  d <- make_factor_data(response_kind = "normal")
  fit <- lm(y ~ x * sex, data = d)
  interaction_smoke(symbolize(fit))
})

test_that("interactions: glm binomial", {
  d <- make_factor_data(response_kind = "binary")
  fit <- glm(y ~ x * sex, data = d, family = stats::binomial())
  interaction_smoke(symbolize(fit))
})

test_that("interactions: glm poisson", {
  d <- make_factor_data(response_kind = "count")
  fit <- glm(y ~ x * sex, data = d, family = stats::poisson())
  interaction_smoke(symbolize(fit))
})

test_that("interactions: glm Gamma", {
  d <- make_factor_data(response_kind = "gamma")
  fit <- glm(y ~ x * sex, data = d, family = stats::Gamma(link = "log"))
  interaction_smoke(symbolize(fit))
})

test_that("interactions: glmmTMB poisson", {
  testthat::skip_if_not_installed("glmmTMB")
  d <- make_factor_data(response_kind = "count")
  fit <- suppressWarnings(glmmTMB::glmmTMB(y ~ x * sex, data = d,
                                           family = stats::poisson()))
  interaction_smoke(symbolize(fit))
})

test_that("interactions: glmmTMB binomial", {
  testthat::skip_if_not_installed("glmmTMB")
  d <- make_factor_data(response_kind = "binary")
  fit <- suppressWarnings(glmmTMB::glmmTMB(y ~ x * sex, data = d,
                                           family = stats::binomial()))
  interaction_smoke(symbolize(fit))
})

test_that("interactions: lmer with random intercept", {
  testthat::skip_if_not_installed("lme4")
  d <- make_factor_data(response_kind = "normal")
  d$g <- factor(rep(seq_len(20), length.out = nrow(d)))
  fit <- suppressMessages(lme4::lmer(y ~ x * sex + (1 | g), data = d))
  interaction_smoke(symbolize(fit))
})

test_that("interactions: drmTMB gaussian", {
  testthat::skip_if_not_installed("drmTMB")
  d <- make_factor_data(response_kind = "normal")
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ x * sex, sigma ~ 1),
    family = stats::gaussian(), data = d
  )
  interaction_smoke(symbolize(fit))
})
