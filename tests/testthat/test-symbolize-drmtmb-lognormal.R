# Lognormal landed as a CSV-only family after the v0.3 family-distributions
# refactor. These tests confirm that the templated path produces the right
# output without any new R code (other than the small methods_text slot
# generalisation).

test_that("symbolize.drmTMB reads a lognormal fit end-to-end", {
  fit <- fit_drm_lognormal()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$family, "lognormal")
})

test_that("lognormal distribution row mentions Lognormal and log(Y) ~ Normal", {
  fit <- fit_drm_lognormal()
  sym <- symbolize(fit)
  d <- sym$distribution
  expect_equal(d$family, "lognormal")
  expect_match(d$latex, "Lognormal", fixed = TRUE)
  # The CSV template uses the equivalence to log(Y) ~ Normal:
  expect_match(d$latex, "\\\\log\\(", fixed = FALSE)
})

test_that("lognormal interpretation has rows with biological-scale 'geometric mean' wording on mu", {
  fit <- fit_drm_lognormal()
  sym <- symbolize(fit)
  interp <- sym$interpretation
  expect_setequal(unique(interp$submodel), c("mu", "sigma"))
  mu_rows <- interp[interp$submodel == "mu", , drop = FALSE]
  expect_true(any(grepl("geometric mean", mu_rows$biological_reading, fixed = TRUE)))
})

test_that("lognormal methods_text mentions Lognormal, log-response scale, and exp(beta) geometric mean", {
  fit <- fit_drm_lognormal()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  expect_match(mt$text, "lognormal",     fixed = TRUE)
  expect_match(mt$text, "log-response",  fixed = TRUE)
  expect_match(mt$text, "geometric mean", fixed = TRUE)
})

test_that("lognormal capability rows are First slice", {
  caps <- symbolizer_capabilities()
  ln <- caps[caps$class == "drmTMB" & caps$family == "lognormal", ]
  expect_true(all(ln$status == "First slice"))
})

test_that("lognormal added without touching R distribution code paths (regression note)", {
  # This test isn't really a structural assertion — it's a marker. The
  # lognormal family was added to the package via CSV rows only (plus the
  # generalised methods_text slot block that covers all univariate drmTMB
  # families). If a future change adds an `if (identical(family,
  # "lognormal")) { ... }` branch to symbolize-drmtmb.R, this test does NOT
  # fail — but the design note at .memory/designs/v0.3-family-distributions-
  # refactor.md says we shouldn't be doing that.
  caps <- symbolizer_capabilities()
  ln <- caps[caps$class == "drmTMB" & caps$family == "lognormal", ]
  expect_equal(nrow(ln), 2L)
})
