# v0.22.4 punch-list item #10 (NIT).
#
# The symbol-glossary description for the dispersion parameter sigma was
# family-blind: sprintf("conditional %s of %s", dpar, response) produced
# "conditional sigma of y" for EVERY family. For Beta that is doubly
# misleading -- sigma is the PRECISION (larger sigma => tighter, the
# opposite of an SD). Source the description from the per-family
# scale_meaning column of family-parameterizations.csv instead.

test_that("Beta sigma gloss is the precision, not 'conditional sigma of y'", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-beta-sigma-gloss")

  expect_false(grepl("conditional sigma of", html),
               info = "Beta sigma gloss must not use the family-blind 'conditional sigma of y'")
  expect_true(grepl("Beta precision", html),
              info = "Beta sigma gloss should carry the family scale_meaning (precision)")
})

test_that("Lognormal sigma gloss is its log-scale meaning, not 'precision'", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_lognormal())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-ln-sigma-gloss")

  expect_false(grepl("conditional sigma of", html),
               info = "Lognormal sigma gloss must not use the family-blind wording")
  # Guard against an over-broad replacement turning lognormal into "precision".
  # Lognormal scale_meaning is "scale on the log-response".
  expect_true(grepl("log-response", html),
              info = "Lognormal sigma gloss should carry its own log-scale meaning")
})
