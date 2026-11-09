# as_html_three_views file / standalone I/O branches (R/render-three-views.R).

test_that("as_html_three_views(..., file =) writes a fragment and warns without standalone", {
  skip_if_not_installed("drmTMB")
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  tf <- tempfile(fileext = ".html")
  expect_warning(
    as_html_three_views(sym, file = tf, standalone = FALSE, id = "io-frag"),
    "standalone"
  )
  html <- readLines(tf, warn = FALSE)
  expect_true(length(html) > 0L)
  expect_match(paste(html, collapse = "\n"), "data-panel=\"eq\"", fixed = TRUE)
})

test_that("as_html_three_views(..., file =, standalone = TRUE) writes a full document", {
  skip_if_not_installed("drmTMB")
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  tf <- tempfile(fileext = ".html")
  expect_no_warning(
    as_html_three_views(sym, file = tf, standalone = TRUE, id = "io-full")
  )
  html <- paste(readLines(tf, warn = FALSE), collapse = "\n")
  expect_match(html, "<!DOCTYPE html>", fixed = TRUE)
  expect_match(html, "MathJax", fixed = TRUE)
})

test_that("as_html_three_views.symbolized_model_set aborts on empty parts", {
  bad <- structure(list(parts = list()), class = "symbolized_model_set")
  expect_error(as_html_three_views(bad), "no nodes")
})

test_that("three_views helper functions format signed terms and escape underscores", {
  joined <- symbolizer:::join_signed_terms(c("1.2", "- 0.5"))
  expect_equal(joined, "1.2 - 0.5")
  esc <- symbolizer:::escape_underscores_for_latex("beta_0_hat")
  expect_true(grepl("_", esc, fixed = TRUE))
  expect_false(grepl("beta_0_hat", esc, fixed = TRUE))
  base <- symbolizer:::subscriptable_base("\\hat{\\beta}_0")
  expect_true(nzchar(base))
})
