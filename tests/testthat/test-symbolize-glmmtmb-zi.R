# Tests for glmmTMB zero-inflation submodel added in v0.11.

fit_glmm_poisson_zi <- function(seed = 21L, n = 200L) {
  testthat::skip_if_not_installed("glmmTMB")
  set.seed(seed)
  dat <- data.frame(y = rpois(n, 3) * rbinom(n, 1, 0.7), x = rnorm(n))
  suppressWarnings(glmmTMB::glmmTMB(
    y ~ x, ziformula = ~ x, data = dat, family = stats::poisson()
  ))
}

fit_glmm_nbinom2_zi <- function(seed = 22L, n = 200L) {
  testthat::skip_if_not_installed("glmmTMB")
  set.seed(seed)
  mu <- exp(1 + 0.1 * rnorm(n))
  y <- rnbinom(n, mu = mu, size = 2) * rbinom(n, 1, 0.7)
  dat <- data.frame(y = y, x = rnorm(n))
  suppressWarnings(glmmTMB::glmmTMB(
    y ~ x, ziformula = ~ 1, data = dat, family = glmmTMB::nbinom2()
  ))
}

test_that("symbolize.glmmTMB handles poisson + zi (~ x)", {
  fit <- fit_glmm_poisson_zi()
  sym <- symbolize(fit)
  expect_true("zi" %in% sym$fixed_effects$submodel)
  zi_rows <- sym$fixed_effects[sym$fixed_effects$submodel == "zi", , drop = FALSE]
  expect_true(nrow(zi_rows) >= 2L)
  expect_false(any(is.na(zi_rows$confint_low)))
  expect_false(any(is.na(zi_rows$confint_high)))
})

test_that("glmmTMB poisson + zi LaTeX includes logit(pi_zi)", {
  fit <- fit_glmm_poisson_zi()
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  expect_match(tex, "Poisson", fixed = TRUE)
  expect_match(tex, "logit", fixed = TRUE)
  expect_match(tex, "pi_{\\mathrm{zi}", fixed = TRUE)
})

test_that("symbolize.glmmTMB handles nbinom2 + zi (~ 1)", {
  fit <- fit_glmm_nbinom2_zi()
  sym <- symbolize(fit)
  expect_true("zi" %in% sym$fixed_effects$submodel)
  expect_match(as_latex(sym), "NegBin", fixed = TRUE)
})
