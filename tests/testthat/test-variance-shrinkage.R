# variance-components surface, Slice 4 (shrinkage caption).
# Spec: docs/specs/variance-components.md (S4) + contract clause 6.
#
# A prose-only partial-pooling caption sits beside the worked-row BLUP when
# the fit has random effects. No numbers (numeric shrinkage deferred). Prose
# from inst/extdata/variance-readings.csv.

test_that("worked row carries a partial-pooling caption when the fit has RE", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit  <- suppressWarnings(fit_drm_re_homosked())
  html <- as_html_three_views(symbolize(fit))
  expect_match(html, "partially pooled", ignore.case = TRUE)
  expect_match(html, "shrunk toward", ignore.case = TRUE)
})

test_that("no shrinkage caption when the fit has no random effects", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit  <- suppressWarnings(fit_drm_location_scale())  # no (1 | group)
  html <- as_html_three_views(symbolize(fit))
  expect_no_match(html, "partially pooled", ignore.case = TRUE)
})
