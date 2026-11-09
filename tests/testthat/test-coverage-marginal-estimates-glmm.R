# group_* surfaces on glmmTMB / base fits (R/marginal-estimates.R).

test_that("group_means on glmmTMB Poisson back-transforms with emmeans", {
  skip_if_not_installed("glmmTMB")
  skip_if_not_installed("emmeans")
  set.seed(1L)
  d <- data.frame(
    y = rpois(120, 3),
    g = factor(rep(letters[1:3], each = 40)),
    x = rnorm(120)
  )
  fit <- suppressWarnings(glmmTMB::glmmTMB(y ~ g, data = d, family = poisson()))
  gm <- group_means(symbolize(fit))
  expect_s3_class(gm, "symbolizer_group_means")
  expect_equal(nrow(gm), 3L)
  expect_true(all(gm$estimate > 0))
  expect_match(attr(gm, "scale") %||% gm$scale[[1L]], "response")
})

test_that("group_slopes on lm interaction returns one slope per gear level", {
  skip_if_not_installed("emmeans")
  d <- transform(mtcars, gear = factor(gear))
  gs <- group_slopes(symbolize(lm(mpg ~ wt * gear, data = d)), continuous = "wt")
  expect_equal(nrow(gs), nlevels(d$gear))
  expect_true(all(gs$predictor == "wt"))
})

test_that("print.symbolizer_group_means names the response scale in the header", {
  skip_if_not_installed("emmeans")
  d <- transform(mtcars, cyl = factor(cyl))
  gm <- group_means(symbolize(lm(mpg ~ cyl, data = d)), scale = "response")
  out <- paste(utils::capture.output(print(gm), type = "message"), collapse = "\n")
  expect_match(out, "Group means", fixed = TRUE)
  expect_match(out, "response", fixed = TRUE)
})
