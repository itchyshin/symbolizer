# group_contrasts() on an mgcv gam fit with a parametric (plain) factor.
# Factor-by-smooth terms (s(x, by = fac)) are a separate track deferred to a
# later slice; this locks the plain-factor case, which emmeans handles via its
# native gam support.

test_that("group_contrasts() works on an mgcv plain factor", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("emmeans")
  set.seed(3)
  n <- 120
  d <- data.frame(
    y    = rnorm(n),
    site = factor(sample(c("A", "B", "C"), n, TRUE)),
    x    = rnorm(n)
  )
  sym <- symbolize(mgcv::gam(y ~ site + s(x), data = d))
  gc <- group_contrasts(sym, by = "site")
  expect_s3_class(gc, "symbolizer_group_contrasts")
  expect_equal(nrow(gc), 3L)
  expect_false("p.value" %in% names(gc))
  expect_true(all(is.finite(gc$confint_low)))
  expect_true(all(is.finite(gc$confint_high)))
})
