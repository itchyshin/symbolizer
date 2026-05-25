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

test_that("emitted JS preserves the escaped CSS selector quotes", {
  # Regression for v0.18.1: the JS source was wrapped in an R
  # single-quoted string and contained `querySelectorAll("[role=\"tab\"]")`.
  # R's string parser strips `\"` -> `"`, which corrupted the JS to
  # `querySelectorAll("[role="tab"]")` -- a syntax error that
  # silently disabled tab switching on the rendered page. The fix
  # is a raw R string around the JS body; this test guards against
  # any regression to plain-quoted strings.
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  # The PROPER escaped form must appear:
  expect_match(html,
               'querySelectorAll\\("\\[role=\\\\"tab\\\\"\\]"\\)',
               perl = TRUE)
  expect_match(html,
               'querySelectorAll\\("\\[role=\\\\"tabpanel\\\\"\\]"\\)',
               perl = TRUE)
  # And the BROKEN un-escaped form must not:
  expect_false(grepl('querySelectorAll("[role="tab"]")', html, fixed = TRUE))
  expect_false(grepl('querySelectorAll("[role="tabpanel"]")', html, fixed = TRUE))
})

test_that("widget exposes WAI-ARIA tabs roles", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "role=\"tablist\"", fixed = TRUE)
  expect_match(html, "role=\"tab\"", fixed = TRUE)
  expect_match(html, "role=\"tabpanel\"", fixed = TRUE)
  expect_match(html, "aria-controls=", fixed = TRUE)
  expect_match(html, "aria-labelledby=", fixed = TRUE)
})

test_that("exactly one tab is aria-selected=true and the rest are false", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  count_true  <- length(gregexpr("aria-selected=\"true\"", html, fixed = TRUE)[[1L]])
  count_false <- length(gregexpr("aria-selected=\"false\"", html, fixed = TRUE)[[1L]])
  expect_equal(count_true, 1L)
  expect_equal(count_false, 2L)
})

test_that("tabs use buttons with a roving tabindex", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "<button[^>]*role=\"tab\"")
  count_tabindex0  <- length(gregexpr("tabindex=\"0\"",  html, fixed = TRUE)[[1L]])
  count_tabindexm1 <- length(gregexpr("tabindex=\"-1\"", html, fixed = TRUE)[[1L]])
  expect_gte(count_tabindex0, 1L)
  expect_gte(count_tabindexm1, 2L)
})

test_that("widget includes a keyboard skip-link", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "class=\"sym-skip\"", fixed = TRUE)
  expect_match(html, "Skip three-views widget", fixed = TRUE)
})

test_that("active-tab signal is not color-only (marker glyph present)", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "sym-tab-marker", fixed = TRUE)
  expect_match(html, "&#9656;", fixed = TRUE)
})

test_that("matrix panel includes a screen-reader summary, pre is aria-hidden", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "class=\"sym-sr-only\"", fixed = TRUE)
  expect_match(html, "Matrix-form expansion", fixed = TRUE)
  expect_match(html, "<pre class=\"sym-matrix\" aria-hidden=\"true\"", fixed = TRUE)
})

test_that("matrix summary mentions Z_g only when RE is present", {
  fit_re <- fit_drm_with_re()
  sym_re <- symbolize(fit_re, symbols = c(body_mass = "W_i"))
  html_re <- withr::with_output_sink(tempfile(), as_html_three_views(sym_re))
  expect_match(html_re, "Z_g", fixed = TRUE)

  fit_fe <- fit_drm_location_scale()
  sym_fe <- symbolize(fit_fe)
  html_fe <- withr::with_output_sink(tempfile(), as_html_three_views(sym_fe))
  sr_block <- regmatches(
    html_fe,
    regexpr("class=\"sym-sr-only\">[^<]*</span>", html_fe)
  )
  expect_false(grepl("Z_g", sr_block, fixed = TRUE))
})
