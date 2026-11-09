# Error and guard branches in R/marginal-estimates.R.

test_that("group_means.default and group_slopes.default point to symbolize()", {
  expect_error(group_means(list()), "symbolize")
  expect_error(group_slopes(list()), "symbolize")
})

test_that("group_means without emmeans aborts with install guidance", {
  sym <- symbolize(lm(mpg ~ wt, data = mtcars))
  if (requireNamespace("emmeans", quietly = TRUE)) {
    skip("emmeans is installed")
  }
  expect_error(group_means(sym), "emmeans")
})

test_that("group_means rejects biv_gaussian with a clear message", {
  skip_if_not_installed("drmTMB")
  skip_if_not_installed("emmeans")
  sym <- symbolize(fit_drm_biv_gaussian())
  expect_error(group_means(sym), "biv_gaussian")
})

test_that("group_slopes rejects biv_gaussian with a clear message", {
  skip_if_not_installed("drmTMB")
  skip_if_not_installed("emmeans")
  sym <- symbolize(fit_drm_biv_gaussian())
  expect_error(group_slopes(sym, continuous = "x1"), "biv_gaussian")
})
