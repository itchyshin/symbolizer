# Regression: simulate_recipe() must resolve random-effect SDs from
# variance_components when the table uses `group_var` (drmTMB extractor)
# rather than `group`.

test_that("simulate_recipe runs on a drmTMB random-intercept fit without error", {
  testthat::skip_if_not_installed("drmTMB")
  sym <- symbolize(fit_drm_with_re())
  expect_error(simulate_recipe(sym), NA)
})

test_that("simulate_recipe embeds a numeric group SD when variance_components use group_var", {
  testthat::skip_if_not_installed("drmTMB")
  sym <- symbolize(fit_drm_with_re())
  vc <- sym$variance_components
  expect_true("group_var" %in% names(vc))
  expect_true(any(vc$group_var == "group", na.rm = TRUE))
  re_sd <- vc$sd_estimate[vc$group_var == "group"][[1L]]
  expect_true(is.finite(re_sd))

  rec <- simulate_recipe(sym)
  expect_match(rec$r_code, sprintf("%.4g", re_sd), fixed = FALSE)
  expect_match(paste(rec$pseudocode, collapse = " "), "group", fixed = TRUE)
})
