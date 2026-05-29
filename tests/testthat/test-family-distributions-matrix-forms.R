# v0.22.4 punch-list item #2 (+ bug-class siblings).
#
# Cross-confirmed by 4 lenses in the families audit
# (docs/dev-log/figure-audits/): the matrix_latex column of
# family-distributions.csv collapsed several families to a degenerate
# Family(mu, sigma) placeholder that reads as a DIFFERENT distribution
# than the index_latex column of the same row. The clearest case:
#
#   Beta  index : y_i ~ Beta(mu_i sigma_i, (1 - mu_i) sigma_i)   [mean-precision]
#   Beta  matrix: y   ~ Beta(mu, sigma)                          [reads shape1=mu, shape2=sigma -- WRONG]
#
# A reader toggling Tab 1 -> Tab 2 of the Beta widget sees the mean
# silently become a shape argument. The fix: every matrix_latex form
# must MIRROR the parameterization of its own index_latex form.
#
# The same degenerate collapse is present (though not currently rendered
# in a widget) for Gamma, nbinom2, and truncated_nbinom2 -- fixed here as
# the same bug class so it cannot resurface when those families get a
# widget. beta_binomial already mirrors its index (N, mu, sigma) and is
# left alone.

read_family_distributions <- function() {
  p <- system.file("extdata", "family-distributions.csv", package = "symbolizer")
  testthat::expect_true(nzchar(p), info = "family-distributions.csv must be findable")
  utils::read.csv(p, stringsAsFactors = FALSE)
}

test_that("Beta matrix form is mean-precision, not the degenerate Beta(mu, sigma)", {
  csv <- read_family_distributions()
  beta_matrix <- csv$matrix_latex[csv$family == "beta"]
  expect_length(beta_matrix, 1L)

  # The degenerate two-argument placeholder must be gone.
  expect_false(
    grepl("\\\\mathrm\\{Beta\\}\\(\\\\boldsymbol\\{\\\\mu\\},\\\\,? \\\\boldsymbol\\{\\\\sigma\\}\\)",
          beta_matrix),
    info = "Beta matrix form still uses the degenerate Beta(mu, sigma) placeholder"
  )
  # The mean-precision shape (1 - mu) must be present, mirroring the index form.
  expect_true(grepl("1 - \\\\boldsymbol\\{\\\\mu\\}", beta_matrix),
              info = "Beta matrix form must show the (1 - mu) precision shape")
})

test_that("Gamma matrix form mirrors its index shape/scale parameterization", {
  csv <- read_family_distributions()
  gamma_matrix <- csv$matrix_latex[csv$family == "Gamma"]
  expect_length(gamma_matrix, 1L)
  expect_false(
    grepl("\\\\mathrm\\{Gamma\\}\\(\\\\boldsymbol\\{\\\\mu\\},\\\\,? \\\\boldsymbol\\{\\\\sigma\\}\\)",
          gamma_matrix),
    info = "Gamma matrix form still uses the degenerate Gamma(mu, sigma) placeholder"
  )
  expect_true(grepl("shape", gamma_matrix) && grepl("scale", gamma_matrix),
              info = "Gamma matrix form must surface shape and scale, mirroring the index form")
})

test_that("nbinom2 + truncated_nbinom2 matrix forms surface the size parameter", {
  csv <- read_family_distributions()
  for (fam in c("nbinom2", "truncated_nbinom2")) {
    m <- csv$matrix_latex[csv$family == fam]
    expect_length(m, 1L)
    expect_false(
      grepl("\\(\\\\boldsymbol\\{\\\\mu\\},\\\\,? \\\\boldsymbol\\{\\\\sigma\\}\\)$", m),
      info = paste(fam, "matrix form still ends in the degenerate (mu, sigma) placeholder")
    )
    expect_true(grepl("\\\\mathrm\\{size\\}", m),
                info = paste(fam, "matrix form must surface the size parameter, mirroring the index form"))
  }
})

test_that("Beta widget Tab 2 renders the mean-precision matrix form end-to-end", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  # The matrix-form distribution string the widget Tab 2 renders.
  m <- sym$distribution$latex_matrix
  expect_true(grepl("1 - \\\\boldsymbol\\{\\\\mu\\}", m),
              info = "Rendered Beta Tab 2 must show the mean-precision (1 - mu) shape")
})
