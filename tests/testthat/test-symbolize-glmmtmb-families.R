# Tests for v0.11 glmmTMB non-Gaussian families (binomial, poisson,
# nbinom2). The fit_glmm_binomial / fit_glmm_poisson / fit_glmm_nbinom2
# helpers live in helper-glmmtmb-fits.R so other test files can use
# them too.

test_that("symbolize.glmmTMB handles binomial fits", {
  fit <- fit_glmm_binomial()
  sym <- symbolize(fit)
  expect_equal(sym$model$family, "binomial")
  expect_match(as_latex(sym), "Binomial", fixed = TRUE)
})

test_that("symbolize.glmmTMB handles poisson fits", {
  fit <- fit_glmm_poisson()
  sym <- symbolize(fit)
  expect_equal(sym$model$family, "poisson")
  expect_match(as_latex(sym), "Poisson", fixed = TRUE)
})

test_that("symbolize.glmmTMB handles nbinom2 fits", {
  fit <- fit_glmm_nbinom2()
  sym <- symbolize(fit)
  expect_equal(sym$model$family, "nbinom2")
  expect_match(as_latex(sym), "NegBin", fixed = TRUE)
})
