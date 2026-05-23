test_that("as_html_three_views returns invisible character HTML", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_type(out, "character")
  expect_length(out, 1L)
})

test_that("HTML contains all three tab labels and panels", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "1\\. Equation")
  expect_match(html, "2\\. Index")
  expect_match(html, "3\\. Matrix \\(with data\\)")
  expect_match(html, "data-panel=\"eq\"")
  expect_match(html, "data-panel=\"idx\"")
  expect_match(html, "data-panel=\"mat\"")
})

test_that("equation panel uses matrix-form notation (bold lowercase vectors)", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i"))
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "\\\\boldsymbol\\{\\\\mu\\}")
  expect_match(html, "\\\\mathbf\\{w\\}")
})

test_that("index panel uses per-observation notation", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "\\\\mu_i")
  expect_match(html, "T_i")
})

test_that("matrix panel shows actual numeric data", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i"))
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "y_1 =")
  expect_match(html, "beta")
  expect_match(html, "Fitted mu_hat")
})

test_that("matrix panel includes Z_g and u when RE is present", {
  fit_re <- fit_drm_with_re()
  sym <- symbolize(fit_re, symbols = c(body_mass = "W_i"))
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "Z_g \\(group indicator\\)")
  expect_match(html, "u \\(random effects")
})

test_that("default method errors with pointer to symbolize()", {
  expect_error(as_html_three_views(list()), "no method")
})

test_that("CSS and JS are embedded inline", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "<style>")
  expect_match(html, "<script>")
  expect_match(html, "\\.sym-tab")
})
