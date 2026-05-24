test_that("warning_table returns an empty tibble when no warnings fire", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  wt <- warning_table(sym)
  expect_s3_class(wt, "symbolizer_warning_table")
  expect_named(wt, c("code", "severity", "message", "context"))
  expect_equal(nrow(wt), 0L)
})

test_that("few_groups_wald fires for a (1|group) fit with < 10 levels", {
  # fit_drm_with_re() in the helper uses n_groups = 6 by default; ci_method
  # defaults to "wald", so the warning should fire.
  fit_re <- fit_drm_with_re()
  sym <- symbolize(fit_re)
  wt <- warning_table(sym)
  expect_equal(nrow(wt), 1L)
  expect_equal(wt$code, "few_groups_wald")
  expect_equal(wt$severity, "warn")
  expect_match(wt$message, "few levels", fixed = TRUE)
  expect_match(wt$message, "ci_method", fixed = FALSE)
  expect_match(wt$context, "n_groups = 6", fixed = TRUE)
})

test_that("few_groups_wald does NOT fire when ci_method = 'profile'", {
  fit_re <- fit_drm_with_re()
  # ci_method = "profile" suppresses the warning even with few groups.
  sym <- symbolize(fit_re, ci_method = "profile")
  wt <- warning_table(sym)
  expect_equal(nrow(wt), 0L)
})

test_that("few_groups_wald does NOT fire without random effects", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)  # default ci_method = "wald", no RE
  wt <- warning_table(sym)
  expect_equal(nrow(wt), 0L)
})

test_that("warning_table errors helpfully on non-symbolized input", {
  expect_error(warning_table(list()), "has no method")
})

test_that("print.symbolizer_warning_table behaves for both empty and populated tables", {
  fit <- fit_drm_location_scale()
  wt_empty <- warning_table(symbolize(fit))
  msgs <- testthat::capture_messages(print(wt_empty))
  expect_match(paste(msgs, collapse = ""), "No warnings flagged")

  fit_re <- fit_drm_with_re()
  wt_full <- warning_table(symbolize(fit_re))
  msgs <- testthat::capture_messages(print(wt_full))
  out <- paste(msgs, collapse = "")
  expect_match(out, "Warnings")
  expect_match(out, "few levels")
})

test_that("knit_print returns markdown asis_output", {
  fit_re <- fit_drm_with_re()
  wt <- warning_table(symbolize(fit_re))
  kp <- knitr::knit_print(wt)
  expect_s3_class(kp, "knit_asis")
  expect_match(as.character(kp), "severity", fixed = TRUE)
})
