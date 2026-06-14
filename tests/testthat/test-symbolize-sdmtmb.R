# Tests for the v0.12 symbolize.sdmTMB() extractor.

test_that("symbolize.sdmTMB builds a symbolized_model for a Gaussian spatial fit", {
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "sdmTMB")
  expect_equal(sym$model$family, "gaussian")
  expect_true(sym$model$spatial)
  expect_false(sym$model$spatiotemporal)
})

test_that("symbolize.sdmTMB fixed effects carry estimates and Wald CIs", {
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  fe <- sym$fixed_effects
  expect_true(nrow(fe) >= 2L)
  expect_true(all(is.finite(fe$estimate)))
  expect_equal(fe$ci_method[[1L]], "wald")
  expect_true(any(fe$role == "intercept"))
})

test_that("symbolize.sdmTMB variance_components has spatial parameters", {
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  vc <- sym$variance_components
  expect_true(nrow(vc) >= 2L)
  expect_true(any(vc$kind == "spatial_random"))
  expect_true(any(vc$kind == "residual"))
  # The Matern range is carried (a distance biologists need to read the field),
  # with its estimate in sd_estimate but NA var_estimate (it is not a variance).
  rng <- vc[vc$kind == "spatial_range", , drop = FALSE]
  expect_equal(nrow(rng), 1L)
  expect_true(is.finite(rng$sd_estimate[[1L]]))
  expect_true(is.na(rng$var_estimate[[1L]]))
})

test_that("symbolize.sdmTMB random_effects has a site/intercept row", {
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  re <- sym$random_effects
  expect_true(!is.null(re) && nrow(re) >= 1L)
  expect_equal(re$group_var[[1L]], "site")
})

test_that("symbolize.sdmTMB LaTeX renders the spatial random field", {
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  expect_match(tex, "Normal", fixed = TRUE)
  expect_match(tex, "u_{site", fixed = TRUE)
})

# Audit B1: the sdmTMB extractor must surface the fixed-effects design
# matrix X and the FE coefficient vector so Tab 3 fills with data. The
# spatial random field is NOT in X (it is a structured-covariance block),
# so mu_hat is the fixed-effects prediction X*beta and the residual
# y - mu_hat carries the field + noise.
test_that("symbolize.sdmTMB populates expanded$X / beta (audit B1)", {
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  ex <- sym$expanded
  expect_true(is.matrix(ex$X))
  expect_equal(nrow(ex$X), sym$model$n_obs)
  expect_equal(length(ex$beta), ncol(ex$X))
  expect_equal(as.numeric(ex$mu_hat),
               as.numeric(ex$X %*% ex$beta), tolerance = 1e-6)
  html <- as_html_three_views(sym)
  expect_false(grepl("not captured", html))
  expect_match(html, "mathbf\\{X\\}")
})
