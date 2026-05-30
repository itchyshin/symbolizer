# Regression tests for two sdmTMB extractor defects
# (docs/dev-log/audits/2026-05-29-capability-reverify.md, sdmTMB section):
#
#   (A) delta_gamma() fits set fit$family$family to the length-2 vector
#       c("binomial", "Gamma"). The family-resolution guard must route a
#       length-2 (delta) family to the clean `delta_model` capability
#       message ("Planned or reserved"), NOT crash with the base-R
#       "'length = 2' in coercion to 'logical(1)'" coercion error.
#
#   (B) A Gaussian + spatial fit's spatial random field must NOT be
#       rendered as an ordinary iid random intercept
#       (u_{site} ~ N(0, sigma^2)). The signature sdmTMB spatial field is
#       a spatially-correlated Gaussian random field, so the equation must
#       surface its structured (GMRF / Matern-SPDE) covariance.

# Local fixture for the delta-family crash. Kept in this test file (rather
# than the shared helper-sdmtmb-fits.R) to keep the change surface minimal.
fit_sdmtmb_delta_gamma_spatial <- function(seed = 1L, n = 300L) {
  testthat::skip_if_not_installed("sdmTMB")
  set.seed(seed)
  dat <- data.frame(x = stats::runif(n), y_loc = stats::runif(n),
                    z = stats::rnorm(n))
  dat$obs <- 2 + 0.5 * dat$z + stats::rnorm(n, 0, 1)
  mesh <- sdmTMB::make_mesh(dat, c("x", "y_loc"), cutoff = 0.1)
  suppressWarnings(sdmTMB::sdmTMB(
    obs ~ z, data = dat, mesh = mesh,
    family = sdmTMB::delta_gamma(), spatial = "on"
  ))
}

# ---- (A) delta family routes to the clean capability message ----------------

test_that("delta_gamma() sdmTMB fit carries a length-2 family vector", {
  skip_if_not_installed("sdmTMB")
  fit <- fit_sdmtmb_delta_gamma_spatial()
  # fit$family$family is the length-2 vector c("binomial", "Gamma").
  expect_length(fit$family$family, 2L)
})

test_that("delta_gamma() does not crash with the length-2 coercion error", {
  skip_if_not_installed("sdmTMB")
  fit <- fit_sdmtmb_delta_gamma_spatial()
  err <- tryCatch(symbolize(fit), error = function(e) conditionMessage(e))
  expect_false(grepl("coercion to 'logical", err, fixed = TRUE))
})

test_that("delta_gamma() error names the delta_model capability and its status", {
  skip_if_not_installed("sdmTMB")
  fit <- fit_sdmtmb_delta_gamma_spatial()
  expect_error(symbolize(fit), "delta_model")
  expect_error(symbolize(fit), "Planned or reserved")
})

# ---- (B) spatial random field is not rendered as iid independence ------------

test_that("Gaussian+spatial as_latex() does not render the spatial field as iid", {
  skip_if_not_installed("sdmTMB")
  sym <- symbolize(fit_sdmtmb_gaussian_spatial())
  tex <- as_latex(sym, notation = "both")
  # The buggy iid scalar marginal "u_{site} \sim \mathcal{N}(0, sigma^2)"
  # (note: NO \mathbf, and a bare 0) must be gone.
  expect_false(grepl("u_{site} \\sim \\mathcal{N}(0,", tex, fixed = TRUE))
  # The identity-covariance matrix form must be gone for the field.
  expect_false(grepl("\\sigma_{site}^2 \\mathbf{I}", tex, fixed = TRUE))
})

test_that("Gaussian+spatial as_latex() surfaces the structured spatial covariance", {
  skip_if_not_installed("sdmTMB")
  sym <- symbolize(fit_sdmtmb_gaussian_spatial())
  tex <- as_latex(sym, notation = "both")
  # The spatial field must carry its structured covariance matrix symbol
  # (a spatially-correlated Gaussian random field), not the identity.
  expect_match(tex, "\\boldsymbol{\\Omega}", fixed = TRUE)
})

test_that("Gaussian+spatial assumptions include a spatial-field row, not independence", {
  skip_if_not_installed("sdmTMB")
  sym <- symbolize(fit_sdmtmb_gaussian_spatial())
  asmp <- sym$assumptions
  expect_true(any(grepl("spatial", asmp$assumption)))
  # No assumption row may assert plain observational independence.
  expect_false(any(asmp$assumption == "independence"))
})

test_that("Gaussian+spatial sets metadata$spatial_representation", {
  skip_if_not_installed("sdmTMB")
  sym <- symbolize(fit_sdmtmb_gaussian_spatial())
  expect_false(is.null(sym$metadata$spatial_representation))
})

test_that("Gaussian+spatial does not leak literal NA into the matrix dimension", {
  skip_if_not_installed("sdmTMB")
  sym <- symbolize(fit_sdmtmb_gaussian_spatial())
  tex <- as_latex(sym, notation = "both")
  expect_false(grepl("\\mathbf{I}_{NA}", tex, fixed = TRUE))
  expect_false(grepl("mathbb{R}^{NA}", tex, fixed = TRUE))
})
