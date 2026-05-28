# Tests for symbolize.phylolm. v0.21-redo new extractor: PGLS in the
# marginalized form y = Xβ + e, e ~ N(0, σ² C(α)), where C(α) is a
# tree-derived correlation matrix (BM: C = A; lambda: C(λ) =
# λA + (1−λ)I when A_ii = 1; OU / EB / kappa / delta have other
# parameterizations and are out of first-slice scope).

test_that("symbolize.phylolm returns a symbolized_model", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_s3_class(sym, "symbolized_model")
})

test_that("symbolize.phylolm sets model$class = 'phylolm', package = 'phylolm'", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_equal(sym$model$class, "phylolm")
  expect_equal(sym$model$package, "phylolm")
  expect_equal(sym$model$family, "gaussian")
})

test_that("symbolize.phylolm sets detected_signals = 'phylo' (always)", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_true("phylo" %in% sym$metadata$detected_signals)
})

test_that("symbolize.phylolm sets phylo_representation = 'pgls_marginal'", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_equal(sym$metadata$phylo_representation, "pgls_marginal")
})

test_that("symbolize.phylolm records the evolutionary model in metadata$phylo_model", {
  bundle_bm <- fit_phylolm_bm()
  sym_bm <- symbolize(bundle_bm$fit, data = bundle_bm$data)
  expect_equal(sym_bm$metadata$phylo_model, "BM")

  bundle_lam <- fit_phylolm_lambda()
  sym_lam <- symbolize(bundle_lam$fit, data = bundle_lam$data)
  expect_equal(sym_lam$metadata$phylo_model, "lambda")
  # lambda has a free phylo parameter; BM does not.
  expect_true(is.numeric(sym_lam$metadata$phylo_param))
})

test_that("symbolize.phylolm adds a structured-correlation row for A", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  sd <- sym$symbol_dictionary
  expect_s3_class(sd, "data.frame")
  expect_true("role" %in% names(sd))
  expect_true("structured_correlation_phylo" %in% sd$role)
  a_row <- sd[sd$role == "structured_correlation_phylo", , drop = FALSE]
  expect_equal(nrow(a_row), 1L)
  expect_equal(a_row$symbol[[1L]], "\\mathbf{A}")
})

test_that("symbolize.phylolm fires phylo-gated assumption rows", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  a <- sym$assumptions
  expect_s3_class(a, "data.frame")
  expect_true("phylo_random_effect" %in% a$assumption)
  expect_true("phylo_brownian_motion" %in% a$assumption)
})

test_that("symbolize.phylolm fixed_effects carries estimate + Wald SE + CI", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  fe <- sym$fixed_effects
  expect_s3_class(fe, "data.frame")
  expect_true("estimate" %in% names(fe))
  expect_true("std_error" %in% names(fe))
  expect_true("confint_low" %in% names(fe))
  expect_true("confint_high" %in% names(fe))
  expect_true("ci_method" %in% names(fe))
  expect_true(all(fe$ci_method == "wald"))
  expect_true(all(is.finite(fe$estimate)))
  expect_true(all(is.finite(fe$std_error)))
  # Sanity: SE matches sqrt(diag(vcov(fit))) for the included coefficients.
  expect_equal(
    fe$std_error,
    unname(sqrt(diag(stats::vcov(bundle$fit)))[seq_len(nrow(fe))]),
    tolerance = 1e-8
  )
})

test_that("symbolize.phylolm variance_components has sigma2 row", {
  bundle <- fit_phylolm_bm()
  sym <- symbolize(bundle$fit, data = bundle$data)
  vc <- sym$variance_components
  expect_s3_class(vc, "data.frame")
  expect_true(nrow(vc) >= 1L)
  # The residual variance σ² is the fit$sigma2 estimate.
  expect_true(any(grepl("sigma", vc$parameter, ignore.case = TRUE)) ||
              any(vc$group == "residual" | vc$group == "phylo"))
  expect_true(any(is.finite(vc$var_estimate)))
})
