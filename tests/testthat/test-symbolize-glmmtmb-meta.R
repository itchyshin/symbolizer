# Tests for v0.16 glmmTMB propto/equalto meta-analysis detection.

test_that("symbolize.glmmTMB detects propto() and flags meta-analysis pattern", {
  skip_if_not_installed("MASS")
  fit <- fit_glmm_meta_propto()
  sym <- symbolize(fit)
  expect_true(isTRUE(sym$metadata$meta_analysis_via_glmmTMB))
})

test_that("propto detection surfaces a meta_analysis_via_glmmTMB warning row", {
  skip_if_not_installed("MASS")
  fit <- fit_glmm_meta_propto()
  sym <- symbolize(fit)
  wt <- warning_table(sym)
  expect_true(nrow(wt) >= 1L)
  expect_true("meta_analysis_via_glmmTMB" %in% wt$code)
})

test_that("propto fit still produces a clean LaTeX block (propto stripped from rhs)", {
  skip_if_not_installed("MASS")
  fit <- fit_glmm_meta_propto()
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  # Should NOT contain "propto" as raw text -- it's a covariance
  # structure, not a renderable term
  expect_false(grepl("propto", tex, fixed = TRUE))
  # Should still have the (1|study) part rendering u_{study}
  expect_match(tex, "u_{study", fixed = TRUE)
})
