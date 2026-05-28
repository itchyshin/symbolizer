# Verifies that as_html_three_views() emits the implied-cov block when
# expanded$Sigma_B is present, AND the second block (W) plus repeatability
# row when expanded$Sigma_W is present.

test_that("Tab 3 emits a B-tier implied-cov block on a between-only gllvm fit", {
  fit <- fit_gllvm_with_unique()  # between only
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym, id = "test-B"))
  expect_match(html, "between-individual implied covariance", fixed = TRUE)
  expect_false(grepl("within-individual implied covariance", html, fixed = TRUE))
})

test_that("Tab 3 emits B + W blocks and Repeatability row on a two-tier fit", {
  fit <- fit_gllvm_two_tier()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym, id = "test-BW"))
  expect_match(html, "between-individual implied covariance", fixed = TRUE)
  expect_match(html, "within-individual implied covariance", fixed = TRUE)
  expect_match(html, "Per-trait repeatability", fixed = TRUE)
  R_vec <- sym$expanded$Repeatability
  for (k in seq_along(R_vec)) {
    expect_match(html, formatC(R_vec[k], digits = 3, format = "g"),
                 fixed = TRUE)
  }
})
