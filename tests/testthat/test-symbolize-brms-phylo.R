# v0.21-redo: tests for symbolize.brmsfit on phylogenetic fits attached
# via gr(species, cov = A). The extractor's detection logic was added in
# v0.21.0 but no test ever exercised it; the article Face was eval=FALSE.

test_that("symbolize.brmsfit on gr(species, cov = A) sets detected_signals = 'phylo'", {
  bundle <- fit_brms_phylo()
  sym <- symbolize(bundle$fit)
  expect_true("phylo" %in% sym$metadata$detected_signals)
})

test_that("symbolize.brmsfit on gr(species, cov = A) sets phylo_representation = 'tips_only'", {
  bundle <- fit_brms_phylo()
  sym <- symbolize(bundle$fit)
  expect_equal(sym$metadata$phylo_representation, "tips_only")
})

test_that("symbolize.brmsfit on gr(species, cov = A) adds a structured-correlation row for A to the symbol dictionary", {
  bundle <- fit_brms_phylo()
  sym <- symbolize(bundle$fit)
  sd <- sym$symbol_dictionary
  expect_s3_class(sd, "data.frame")
  expect_true("role" %in% names(sd))
  expect_true("structured_correlation_phylo" %in% sd$role)
  a_row <- sd[sd$role == "structured_correlation_phylo", , drop = FALSE]
  expect_equal(nrow(a_row), 1L)
  expect_equal(a_row$symbol[[1L]], "\\mathbf{A}")
})

test_that("symbolize.brmsfit on gr(species, cov = A) fires phylo-gated assumption rows", {
  bundle <- fit_brms_phylo()
  sym <- symbolize(bundle$fit)
  a <- sym$assumptions
  expect_s3_class(a, "data.frame")
  expect_true("assumption" %in% names(a))
  expect_true("phylo_random_effect" %in% a$assumption)
  expect_true("phylo_brownian_motion" %in% a$assumption)
  expect_true("phylo_A_positive_definite" %in% a$assumption)
  expect_true("phylo_ultrametric_tree" %in% a$assumption)
})

test_that("symbolize.brmsfit without gr(cov = A) does NOT fire phylo signals", {
  fit <- fit_brms_gaussian_re()
  sym <- symbolize(fit)
  # Negative control: a plain (1 | g) brms fit must not pretend to be phylo.
  expect_false("phylo" %in% sym$metadata$detected_signals)
  expect_null(sym$metadata$phylo_representation)
  sd <- sym$symbol_dictionary
  if ("role" %in% names(sd)) {
    expect_false("structured_correlation_phylo" %in% sd$role)
  }
})

test_that("symbolize.brmsfit on gr(species, cov = A) carries the phylo group name and surfaces variance components", {
  bundle <- fit_brms_phylo()
  sym <- symbolize(bundle$fit)
  # The variance_components tibble should carry a row for the phylo
  # group (species) plus the residual. We don't assert exact estimates
  # (brms with 300 iter is noisy) — only that the rows exist.
  vc <- sym$variance_components
  expect_s3_class(vc, "data.frame")
  expect_true("species" %in% vc$group)
  expect_true("residual" %in% vc$group)
})
