# v0.16 introduced glmmTMB propto() detection and originally labelled
# it the meta-analysis pattern. v0.20 corrects that framing: propto is
# the phylogenetic / structured-covariance pattern (Sigma = sigma^2 * V
# with sigma^2 estimated), NOT the meta-analytic fixed-V pattern (which
# requires equalto, not yet in glmmTMB). The metadata flag is renamed
# propto_known_corr_block; the warning code is renamed to match. The
# old metadata field name is kept as a deprecation alias.

test_that("symbolize.glmmTMB detects propto() and flags propto_known_corr_block", {
  skip_if_not_installed("MASS")
  fit <- fit_glmm_meta_propto()
  sym <- symbolize(fit)
  # v0.20 canonical name:
  expect_true(isTRUE(sym$metadata$propto_known_corr_block))
  # Back-compat deprecation alias still set in v0.20:
  expect_true(isTRUE(sym$metadata$meta_analysis_via_glmmTMB))
})

test_that("propto detection surfaces a propto_known_corr_block info row", {
  skip_if_not_installed("MASS")
  fit <- fit_glmm_meta_propto()
  sym <- symbolize(fit)
  wt <- warning_table(sym)
  expect_true(nrow(wt) >= 1L)
  # v0.20 canonical row code:
  expect_true("propto_known_corr_block" %in% wt$code)
  # Confirm the message text uses corrected (non-meta-analytic) prose.
  msg <- wt$message[wt$code == "propto_known_corr_block"]
  expect_true(grepl("phylogenetic|structured-covariance", msg,
                    ignore.case = TRUE))
  expect_true(grepl("NOT the meta-analytic", msg, ignore.case = TRUE))
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
