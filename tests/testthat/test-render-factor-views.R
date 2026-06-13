# Tests for as_html_factor_views() -- the interactive factor widget.

fv_sym <- function() {
  set.seed(42)
  n <- 120
  d <- data.frame(
    body_mass = rnorm(n, 10, 2),
    site      = factor(sample(c("north", "south", "east", "west"), n, TRUE)),
    sex       = factor(sample(c("female", "male"), n, TRUE)),
    body_size = rnorm(n)
  )
  symbolize(lm(body_mass ~ site + sex * body_size, data = d))
}

test_that("the widget has four tab panels with the expected labels", {
  html <- as_html_factor_views(fv_sym(), file = tempfile(fileext = ".html"))
  expect_equal(length(gregexpr("role=\"tab\"", html)[[1L]]), 4L)
  expect_equal(length(gregexpr("role=\"tabpanel\"", html)[[1L]]), 4L)
  expect_match(html, "Coding scheme")
  expect_match(html, "Group means")
  expect_match(html, "Pairwise")
  expect_match(html, "Interactions")
})

test_that("the coding tab shows one card per factor with a highlighted reference", {
  html <- as_html_factor_views(fv_sym(), file = tempfile(fileext = ".html"))
  expect_match(html, "fv-card")
  expect_match(html, "site")
  expect_match(html, "sex")
  # reference chip class is present (one per factor + the legend)
  expect_true(length(gregexpr("fv-chip-ref", html)[[1L]]) >= 2L)
})

test_that("Confidence-Eye rows carry a region, hollow point, and null line", {
  skip_if_not_installed("emmeans")
  html <- as_html_factor_views(fv_sym(), file = tempfile(fileext = ".html"))
  expect_match(html, "fv-region")  # pale compatibility region
  expect_match(html, "fv-pt")      # hollow point estimate
  expect_match(html, "fv-null")    # dashed null reference line
  expect_match(html, "class=\"fv-eye\"")
})

test_that("a continuous-by-continuous interaction shows no spurious 'install emmeans' note", {
  skip_if_not_installed("emmeans")
  set.seed(9)
  d <- data.frame(y = rnorm(60), a = rnorm(60), b = rnorm(60))
  html <- as_html_factor_views(symbolize(lm(y ~ a * b, data = d)),
                               file = tempfile(fileext = ".html"))
  # cont_cont has no cells/slopes by design; with emmeans installed there
  # must be no "(install emmeans ...)" note.
  expect_false(grepl("install emmeans", html))
})

test_that("no-factor models render a graceful coding message, not an error", {
  sym <- symbolize(lm(mpg ~ wt, data = mtcars))
  html <- as_html_factor_views(sym, file = tempfile(fileext = ".html"))
  expect_match(html, "no factor")
  expect_equal(length(gregexpr("role=\"tab\"", html)[[1L]]), 4L)
})

test_that("standalone wrapping yields a full HTML document", {
  html <- as_html_factor_views(fv_sym(), standalone = TRUE,
                               file = tempfile(fileext = ".html"))
  expect_match(html, "<!DOCTYPE html>", fixed = TRUE)
})

test_that("as_html_factor_views.default rejects non-symbolized input", {
  expect_error(as_html_factor_views(list()), "no method")
})
