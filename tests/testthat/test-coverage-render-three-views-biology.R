# Biology gloss, variance panel, and coef-reading branches in render-three-views.

test_that("homoscedastic Gaussian three-views biology gloss mentions Normal residuals", {
  skip_if_not_installed("drmTMB")
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym, id = "bio-gauss"))
  expect_true(
    grepl("Normal", html, fixed = TRUE) ||
      grepl("Gaussian", html, fixed = TRUE)
  )
})

test_that("Poisson three-views coef-reading mentions rate / count language", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_poisson())
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym, id = "bio-pois"))
  expect_true(
    grepl("count", html, ignore.case = TRUE) ||
      grepl("rate", html, ignore.case = TRUE) ||
      grepl("Poisson", html, fixed = TRUE)
  )
})

test_that("location-scale fit surfaces sigma-varies caption when sigma has predictors", {
  skip_if_not_installed("drmTMB")
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym, id = "bio-sigma-var"))
  expect_true(
    grepl("sigma", html, ignore.case = TRUE) ||
      grepl("scale", html, ignore.case = TRUE)
  )
})

test_that("glmmTMB binomial three-views HTML renders without error and shows logit", {
  skip_if_not_installed("glmmTMB")
  set.seed(2L)
  d <- data.frame(
    y = rbinom(100, 1, 0.4),
    x = rnorm(100),
    g = factor(rep(1:5, each = 20))
  )
  fit <- suppressWarnings(glmmTMB::glmmTMB(
    y ~ x + (1 | g), data = d, family = binomial()
  ))
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym, id = "bio-binom"))
  expect_match(html, "1\\. Index", perl = TRUE)
  expect_true(grepl("logit", html, ignore.case = TRUE) || grepl("exp\\(", html, fixed = FALSE))
})

test_that("as_dag mermaid and tikz strings are non-empty for a drmTMB fit", {
  skip_if_not_installed("drmTMB")
  dag <- as_dag(symbolize(fit_drm_location_scale()))
  expect_true(nchar(dag$mermaid) > 20L)
  expect_true(nchar(dag$tikz) > 20L)
  expect_match(dag$mermaid, "flowchart", ignore.case = TRUE)
  expect_match(dag$tikz, "tikzpicture", fixed = TRUE)
})
