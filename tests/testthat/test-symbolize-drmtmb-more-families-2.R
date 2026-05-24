# Two more CSV-only families added in v0.3.2: beta_binomial and
# truncated_nbinom2. The tests mirror the structure of
# test-symbolize-drmtmb-more-families.R; the same registry, distribution,
# interpretation, and methods_text surfaces are checked per family.

# --- beta_binomial -----------------------------------------------------------

test_that("beta_binomial fit symbolizes end-to-end with logit / odds-ratio language", {
  fit <- fit_drm_beta_binomial()
  sym <- symbolize(fit)
  expect_equal(sym$model$family, "beta_binomial")
  expect_match(sym$distribution$latex, "BetaBinomial", fixed = TRUE)
  expect_match(sym$distribution$latex, "N_i",           fixed = TRUE)
  mu_rows <- sym$interpretation[sym$interpretation$submodel == "mu", , drop = FALSE]
  # The biological reading on mu speaks the odds-ratio / proportion language:
  expect_true(any(grepl("odds|plogis|probability",
                        mu_rows$biological_reading)))
})

test_that("beta_binomial methods_text mentions trials and the odds-ratio reading", {
  fit <- fit_drm_beta_binomial()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  expect_match(mt$text, "beta-binomial",          fixed = TRUE)
  expect_match(mt$text, "trials",                 fixed = TRUE)
  expect_match(mt$text, "logit link",             fixed = TRUE)
  expect_match(mt$text, "odds ratio",             fixed = TRUE)
  expect_match(mt$text, "overdispersion",         fixed = TRUE)
  expect_false(grepl("[unfilled:", mt$text, fixed = TRUE))
})

# --- truncated_nbinom2 ------------------------------------------------------

test_that("truncated_nbinom2 fit symbolizes with the truncation noted in the distribution", {
  fit <- fit_drm_truncated_nbinom2()
  sym <- symbolize(fit)
  expect_equal(sym$model$family, "truncated_nbinom2")
  expect_match(sym$distribution$latex, "NegBin",  fixed = TRUE)
  # The truncation indicator: \mathrm{NegBin}^{+}
  expect_match(sym$distribution$latex, "NegBin}^{+}", fixed = TRUE)
  # And the support is called out: y \in {1, 2, 3, ...}
  expect_match(sym$distribution$latex, "1, 2, 3", fixed = TRUE)
})

test_that("truncated_nbinom2 methods_text flags 'untruncated mean' vs 'observed truncated mean'", {
  fit <- fit_drm_truncated_nbinom2()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  expect_match(mt$text, "zero-truncated negative binomial", fixed = TRUE)
  expect_match(mt$text, "strictly positive",                fixed = TRUE)
  # The note about "the observed truncated mean is larger than mu" is a
  # subtle but important caveat — confirm it survives substitution.
  expect_match(mt$text, "observed truncated mean is larger than", fixed = TRUE)
  expect_false(grepl("[unfilled:", mt$text, fixed = TRUE))
})

# --- Capability registry ---------------------------------------------------

test_that("beta_binomial and truncated_nbinom2 capability rows are First slice", {
  caps <- symbolizer_capabilities()
  for (fam in c("beta_binomial", "truncated_nbinom2")) {
    rows <- caps[caps$class == "drmTMB" & caps$family == fam, ]
    expect_true(nrow(rows) >= 1L,
                info = sprintf("no capability rows for drmTMB / %s", fam))
    expect_true(all(rows$status == "First slice"),
                info = sprintf("not all First slice for drmTMB / %s", fam))
  }
})
