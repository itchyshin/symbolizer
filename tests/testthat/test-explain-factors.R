# Tests for explain_factors() -- the consolidated dummy-coding explainer.

ef_fit <- function() {
  set.seed(1)
  d <- data.frame(
    y    = rnorm(60),
    site = factor(rep(c("A", "B", "C"), 20)),
    sex  = factor(rep(c("f", "m"), 30)),
    bs   = rnorm(60)
  )
  lm(y ~ site + sex * bs, data = d)
}

test_that("explain_factors accepts a fit and a symbolized_model", {
  skip_if_not_installed("emmeans")
  fit <- ef_fit()
  e1 <- explain_factors(fit)
  e2 <- explain_factors(symbolize(fit))
  expect_s3_class(e1, "symbolized_factor_explanation")
  expect_s3_class(e2, "symbolized_factor_explanation")
  expect_equal(length(e1$factors), length(e2$factors))
})

test_that("each factor carries an overview, means, and contrasts", {
  skip_if_not_installed("emmeans")
  e <- explain_factors(ef_fit())
  expect_true(e$has_factors)
  expect_setequal(vapply(e$factors, `[[`, character(1L), "variable"),
                  c("site", "sex"))
  site <- Filter(function(f) f$variable == "site", e$factors)[[1L]]
  expect_match(site$overview, "reference|baseline|A")
  expect_s3_class(site$means, "symbolizer_group_means")
  expect_s3_class(site$contrasts, "symbolizer_group_contrasts")
})

test_that("the overview names the reference for treatment coding", {
  skip_if_not_installed("emmeans")
  e <- explain_factors(ef_fit())
  site <- Filter(function(f) f$variable == "site", e$factors)[[1L]]
  expect_match(site$overview, "A")          # reference level
  expect_match(site$overview, "difference") # contrast meaning
})

test_that("sum-to-zero coding gets the no-single-reference overview", {
  skip_if_not_installed("emmeans")
  set.seed(2)
  d <- data.frame(y = rnorm(30), g = factor(rep(c("p", "q", "r"), 10)))
  contrasts(d$g) <- contr.sum(3)
  e <- explain_factors(lm(y ~ g, data = d))
  g <- e$factors[[1L]]
  expect_match(g$overview, "sum-to-zero")
  expect_match(g$overview, "no single reference")
})

test_that("a continuous-by-factor interaction yields per-group slopes", {
  skip_if_not_installed("emmeans")
  e <- explain_factors(ef_fit())
  expect_true(length(e$interactions) >= 1L)
  cf <- Filter(function(it) it$type == "cont_factor", e$interactions)
  expect_true(length(cf) >= 1L)
  expect_s3_class(cf[[1L]]$slopes, "symbolizer_group_slopes")
})

test_that("a factor-by-factor interaction yields inline cells", {
  skip_if_not_installed("emmeans")
  set.seed(3)
  d <- data.frame(
    y = rnorm(60),
    a = factor(rep(c("a1", "a2"), 30)),
    b = factor(rep(c("b1", "b2", "b3"), 20))
  )
  e <- explain_factors(lm(y ~ a * b, data = d))
  ff <- Filter(function(it) it$type == "factor_factor", e$interactions)
  expect_true(length(ff) >= 1L)
  expect_s3_class(ff[[1L]]$cells, "symbolizer_group_means")
})

test_that("the no-factor path returns a message, not an error", {
  e <- explain_factors(lm(mpg ~ wt, data = mtcars))
  expect_false(e$has_factors)
  expect_match(e$no_factors_message, "no factor")
  expect_invisible(print(e))
})

test_that("model_card() carries the compact factor-coding overview", {
  skip_if_not_installed("emmeans")
  mc <- model_card(symbolize(ef_fit()))
  expect_true(length(mc$factor_coding) >= 2L)
  expect_true(any(grepl("site", mc$factor_coding)))
})

test_that("explain() carries the compact factor-coding overview", {
  skip_if_not_installed("emmeans")
  ex <- explain(ef_fit())
  expect_true(length(ex$factor_coding) >= 2L)
})

test_that("print walkthrough is stable", {
  skip_if_not_installed("emmeans")
  set.seed(4)
  d <- data.frame(y = rnorm(30), site = factor(rep(c("A", "B", "C"), 10)))
  expect_snapshot(print(explain_factors(lm(y ~ site, data = d))))
})
