# v0.22.4 punch-list item #11 (NIT, reader improvement -- Fisher's
# standout finding in the families audit).
#
# From the families Beta widget's own numbers: mu_1 = logistic(-0.95) =
# 0.279, precision phi = sigma_1 = exp(-1.04) = 0.353, so the two implied
# Beta shape parameters are alpha = mu*phi = 0.098 and beta = (1-mu)*phi
# = 0.254 -- BOTH below 1. A Beta with both shapes < 1 is U-shaped: its
# density piles up near 0 and 1 rather than peaking at the mean. The
# widget labelled sigma a "precision" but never surfaced that the fitted
# distribution is bimodal at the boundaries. Surface it.

test_that("U-shape diagnostic fires when both Beta shapes are below 1", {
  x <- list(
    model = list(family = "beta"),
    expanded = list(mu_hat = c(0.279, 0.3), sigma_hat = c(0.353, 0.353))
  )
  note <- three_views_family_diagnostic(x)
  expect_true(nzchar(note), info = "U-shape note should fire for shapes (0.098, 0.254)")
  expect_true(grepl("U-shaped", note))
  expect_true(grepl("sym-biology", note))
})

test_that("U-shape diagnostic is silent when shapes are not both below 1", {
  x <- list(
    model = list(family = "beta"),
    expanded = list(mu_hat = c(0.5), sigma_hat = c(10))  # shapes 5, 5
  )
  expect_identical(three_views_family_diagnostic(x), "")
})

test_that("U-shape diagnostic is silent for non-Beta families", {
  x <- list(model = list(family = "poisson"),
            expanded = list(mu_hat = c(2.5), sigma_hat = c(0.2)))
  expect_identical(three_views_family_diagnostic(x), "")
})

test_that("Beta widget surfaces the U-shape note end-to-end", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-beta-ushape")
  expect_true(grepl("U-shaped", html),
              info = "the families Beta fit has both shapes < 1, so the widget must surface the U-shape")
})
