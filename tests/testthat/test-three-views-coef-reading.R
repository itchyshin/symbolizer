# v0.22.4 punch-list item #6 (MAJOR).
#
# The single most useful sentence for a biologist -- what the slope does
# on the RESPONSE scale (rate ratio / odds ratio / geometric-mean
# multiplier) -- lived only in the page prose OUTSIDE every widget, so it
# was lost on PDF export and on a Methods-section paste. Promote it to a
# per-family coefficient-reading callout INSIDE the widget, sourced from
# inst/extdata/coef-readings.csv (prose lives in CSV, per the
# architectural rule), so it travels with the widget and the PDF.

test_that("coefficient reading is family-correct at the function level", {
  expect_match(three_views_coef_reading("poisson"),   "rate ratio")
  expect_match(three_views_coef_reading("beta"),      "odds ratio")
  expect_match(three_views_coef_reading("lognormal"), "geometric mean")
  expect_match(three_views_coef_reading("Gamma"),     "multiplies the mean")
  expect_match(three_views_coef_reading("binomial"),  "odds ratio")
  # Unknown / latent-variable families return empty (no misleading reading).
  expect_identical(three_views_coef_reading("gllvm_gaussian"), "")
  expect_identical(three_views_coef_reading("not_a_family"),   "")
})

test_that("Beta widget embeds the odds-ratio coefficient reading inside the widget", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-beta-coef")

  expect_true(grepl("sym-biology", html),
              info = "widget must carry a sym-biology callout")
  expect_true(grepl("odds ratio", html),
              info = "Beta widget must surface the odds-ratio coefficient reading inside the widget")
})

test_that("Poisson widget embeds the rate-ratio coefficient reading", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_poisson())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-pois-coef")
  expect_true(grepl("rate ratio", html),
              info = "Poisson widget must surface the rate-ratio coefficient reading")
})

test_that("Lognormal widget embeds the geometric-mean coefficient reading", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_lognormal())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-ln-coef")
  expect_true(grepl("geometric mean", html),
              info = "Lognormal widget must surface the geometric-mean coefficient reading")
})

test_that("PDF body carries the coefficient reading (Beta odds ratio)", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  rmd <- paste(pdf_three_views_rmd_body(sym), collapse = "\n")
  expect_true(grepl("odds ratio", rmd),
              info = "PDF body must carry the coefficient reading so it survives export")
})
