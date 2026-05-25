# Tests for the v0.13 symbolize.rma.uni() metafor extractor.

test_that("symbolize.rma.uni builds a symbolized_model for a random-effects meta-analysis", {
  fit <- fit_metafor_rma()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "rma.uni")
  expect_equal(sym$model$family, "meta_normal")
  expect_equal(sym$metadata$method, "REML")
  expect_true(sym$metadata$tau2 > 0)
})

test_that("rma.uni without moderators has only the intercept fixed effect", {
  fit <- fit_metafor_rma()
  sym <- symbolize(fit)
  fe <- sym$fixed_effects
  expect_equal(nrow(fe), 1L)
  expect_equal(fe$term_label[[1L]], "(Intercept)")
  expect_false(is.na(fe$confint_low[[1L]]))
})

test_that("rma.uni with a moderator returns intercept + moderator rows", {
  fit <- fit_metafor_rma_mods()
  sym <- symbolize(fit)
  fe <- sym$fixed_effects
  expect_true(nrow(fe) >= 2L)
  expect_true("year" %in% fe$term_label)
})

test_that("rma.uni variance_components has tau^2 + mean sampling variance", {
  fit <- fit_metafor_rma()
  sym <- symbolize(fit)
  vc <- sym$variance_components
  expect_true("heterogeneity" %in% vc$kind)
  expect_true("sampling_variance" %in% vc$kind)
  tau_row <- vc[vc$kind == "heterogeneity", , drop = FALSE]
  expect_equal(as.numeric(tau_row$var_estimate), as.numeric(sym$metadata$tau2),
               tolerance = 1e-6)
})

test_that("rma.uni LaTeX renders the two-tier model", {
  fit <- fit_metafor_rma()
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  expect_match(tex, "theta_i", fixed = TRUE)
  expect_match(tex, "v_i", fixed = TRUE)
})

test_that("rma.uni assumption_table mentions sampling variance and tau^2", {
  fit <- fit_metafor_rma()
  sym <- symbolize(fit)
  at <- assumption_table(sym)
  txt <- paste(at$assumption, collapse = " ")
  expect_match(txt, "sampling_variance|known_sampling", ignore.case = TRUE)
  expect_match(txt, "linear_predictor|random_effects", ignore.case = TRUE)
})
