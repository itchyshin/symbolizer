# explain_factors() surfaces mgcv factor-by smooths: s(x, by = fac) means the
# smooth shape differs across the factor's levels. The by-factor is recorded in
# metadata$smooths, so this needs no formula re-parsing.

smooth_sym <- function() {
  set.seed(1)
  n <- 200
  d <- data.frame(
    y    = rnorm(n),
    x    = rnorm(n),
    site = factor(sample(c("A", "B", "C"), n, TRUE))
  )
  symbolize(mgcv::gam(y ~ site + s(x, by = site), data = d))
}

test_that("a factor-by smooth surfaces as a smooth_by_factor interaction", {
  skip_if_not_installed("mgcv")
  ef <- explain_factors(smooth_sym())
  sbf <- Filter(function(it) it$type == "smooth_by_factor", ef$interactions)
  expect_equal(length(sbf), 1L)
  expect_match(sbf[[1L]]$term, "s\\(x, by = site\\)")
  expect_match(sbf[[1L]]$overview, "separate shape")
  expect_match(sbf[[1L]]$overview, "site")
})

test_that("a plain smooth (no by) creates no smooth_by_factor entry", {
  skip_if_not_installed("mgcv")
  set.seed(2)
  n <- 200
  d <- data.frame(
    y    = rnorm(n),
    x    = rnorm(n),
    site = factor(sample(c("A", "B", "C"), n, TRUE))
  )
  ef <- explain_factors(symbolize(mgcv::gam(y ~ site + s(x), data = d)))
  sbf <- Filter(function(it) it$type == "smooth_by_factor", ef$interactions)
  expect_equal(length(sbf), 0L)
})

test_that("the factor-by smooth is one entry even with many by-levels", {
  skip_if_not_installed("mgcv")
  ef <- explain_factors(smooth_sym())
  # 3 by-level smooths in metadata$smooths collapse to a single (x, site) entry.
  terms <- vapply(ef$interactions, `[[`, character(1L), "term")
  expect_equal(sum(grepl("by = site", terms)), 1L)
})

test_that("gamm fits surface the factor-by smooth via their $gam component", {
  skip_if_not_installed("mgcv")
  set.seed(3)
  n <- 180
  d <- data.frame(
    y    = rnorm(n),
    x    = rnorm(n),
    site = factor(sample(c("A", "B", "C"), n, TRUE)),
    g    = factor(sample(1:6, n, TRUE))
  )
  gm <- mgcv::gamm(y ~ s(x, by = site), random = list(g = ~1), data = d)
  ef <- explain_factors(symbolize(gm$gam))
  sbf <- Filter(function(it) it$type == "smooth_by_factor", ef$interactions)
  expect_equal(length(sbf), 1L)
})
