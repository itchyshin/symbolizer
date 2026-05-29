# v0.22.4 punch-list item #1 (BLOCKER, cross-confirmed by all 5 lenses).
#
# pdf_three_views_worked_row() was family-blind: it emitted the
# Gaussian-additive worked row `y_1 = b0 + b1 x_1 (+ Zu) + eps = y_1`
# plus "Predicted mu_1; residual eps_1" for EVERY family. For
# Poisson/Beta this is (a) the wrong scale (additive eps on the response
# scale), (b) arithmetically false (the printed `= y_1` does not equal
# the printed terms), and (c) self-contradictory with the PDF's own
# stacked block, which is on the link scale. The HTML worked row was
# made family-aware in v0.22.3/v0.22.4; the PDF emitter must mirror it
# (PDF/HTML parity, Pattern J).
#
# These tests call the internal emitter directly (it returns an Rmd
# LaTeX fragment) so they are fast and need no LaTeX toolchain.

test_that("PDF Beta worked row shows the inverse-link, not a response-scale residual", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  tex <- pdf_three_views_worked_row(sym)

  expect_true(grepl("logistic", tex),
              info = "Beta PDF worked row must surface the logit inverse-link")
  expect_false(grepl("\\\\hat\\\\varepsilon", tex),
               info = "Beta has no additive residual on the linear predictor")
  expect_false(grepl("residual", tex, ignore.case = TRUE),
               info = "Beta PDF worked row must not claim a response-scale residual")
})

test_that("PDF Poisson worked row shows eta -> exp(eta) -> likelihood, no additive eps", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_poisson())
  sym <- symbolize(fit)
  tex <- pdf_three_views_worked_row(sym)

  expect_true(grepl("\\\\exp", tex),
              info = "Poisson PDF worked row must surface the log inverse-link exp()")
  expect_true(grepl("Poisson", tex),
              info = "Poisson PDF worked row must declare the likelihood")
  expect_false(grepl("\\\\hat\\\\varepsilon", tex),
               info = "Poisson has no additive residual on the linear predictor")
  expect_false(grepl("residual", tex, ignore.case = TRUE),
               info = "Poisson PDF worked row must not claim a residual")
})

test_that("PDF Lognormal worked row is on the log scale", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_lognormal())
  sym <- symbolize(fit)
  tex <- pdf_three_views_worked_row(sym)

  # The response equation LHS must be log(y_1), not raw y_1, mirroring HTML.
  expect_true(grepl("\\\\log", tex),
              info = "Lognormal PDF worked row must be on the log scale")
  expect_true(grepl("log-scale", tex),
              info = "Lognormal residual must be labelled as log-scale")
})

test_that("PDF Gaussian worked row keeps the additive residual (back-compat)", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_location_scale())
  sym <- symbolize(fit)
  tex <- pdf_three_views_worked_row(sym)

  # Gaussian-identity is the ONLY family with a legitimate response-scale
  # additive residual; do not regress it.
  expect_true(grepl("residual", tex, ignore.case = TRUE),
              info = "Gaussian PDF worked row should keep its additive residual")
})

test_that("PDF worked rows fold negative coefficients into the operator (no '+ -')", {
  # Punch-list #7, PDF half: same sign-glue bug as the HTML worked row.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  for (h in c("fit_drm_poisson", "fit_drm_beta")) {
    fit <- suppressWarnings(get(h)())
    sym <- symbolize(fit)
    tex <- pdf_three_views_worked_row(sym)
    expect_false(grepl("\\+ -[0-9.]", tex),
                 info = paste(h, "PDF worked row still glues '+ -'"))
  }
})
