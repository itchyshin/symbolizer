# Slice 2 of the families-fix. The Tab 3 worked-row helper hardcodes
# `y_i = β_0 + β_1 x_i + ε̂_i` -- Gaussian-identity. For non-Gaussian
# families this mixes scales: LHS y is on response scale, β_0 + β_1 x_i
# is on link scale (η̂), and the ε̂ is a meaningless "y - η̂" subtraction.
#
# Expected family-aware shape (Poisson example):
#   η̂_1 = β_0 + β_1 x_1            (linear predictor)
#   0.936 = 0.955 + (-0.0438)*0.45
#   μ̂_1 = exp(η̂_1) ≈ 2.55          (response-scale rate)
#   y_1 ~ Poisson(μ̂_1)              (likelihood declaration; no additive ε)
#
# Gaussian-identity keeps the historic shape for back-compat.

test_that("Poisson worked row drops spurious additive epsilon", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_poisson())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-pois")

  # No spurious `+ \hat\varepsilon_{1}` on the linear-predictor line.
  # The historic Gaussian template emits this; the family-aware form
  # drops it for Poisson (likelihood has no residual on linear predictor).
  expect_false(grepl("\\\\hat\\\\varepsilon_\\{1\\}", html))
})

test_that("Poisson worked row shows the back-transform on response scale", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_poisson())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-pois2")

  # The widget needs to make the link explicit: mu_hat = exp(eta_hat).
  # Either an inline `\exp(` or an explicit `\mu_{1}` line.
  expect_true(
    grepl("\\\\exp\\(", html) || grepl("\\\\hat\\\\mu_\\{1\\}", html),
    info = "Poisson Tab 3 must surface the log-link back-transform mu = exp(eta)"
  )
})

test_that("Beta worked row shows response-scale mu in (0,1), not raw eta", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  ex  <- sym$expanded
  html <- as_html_three_views(sym, id = "test-beta")

  # The rendered "predicted" value displayed for the worked row should
  # be the response-scale mu (∈ (0,1)), not the raw eta (potentially
  # negative). Look for plogis or for a digit-only block that matches
  # mu_hat[1] formatted at 3 sig figs.
  mu_1_str <- formatC(ex$mu_hat[[1L]], digits = 3, format = "g")
  expect_true(grepl(mu_1_str, html, fixed = TRUE),
              info = paste("Expected the response-scale mu_hat[1] =", mu_1_str,
                           "to appear in the rendered Tab 3"))
})

test_that("Gaussian-identity worked row keeps the historic y = Xb + eps shape", {
  # Back-compat: Gaussian-identity is the ONLY family that legitimately
  # has y = X*beta + eps on the linear-predictor scale. Don't break it.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_location_scale())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-gauss")

  # Historic shape: the worked row DOES include the additive epsilon
  # on the response equation. Don't regress.
  expect_true(grepl("\\\\hat\\\\varepsilon_\\{1\\}", html))
})
