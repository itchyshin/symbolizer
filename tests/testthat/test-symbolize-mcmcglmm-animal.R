# Tests for the v0.12 MCMCglmm animal-model extension.

test_that("symbolize.MCMCglmm detects animal models via ginverse", {
  bundle <- fit_mcmcglmm_animal()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_equal(sym$metadata$animal_groups, "animal")
  vc <- sym$variance_components
  expect_true("kind" %in% names(vc))
  expect_true("animal" %in% vc$kind)
  expect_true("residual" %in% vc$kind)
})

test_that("MCMCglmm animal model derives a heritability tibble in metadata", {
  bundle <- fit_mcmcglmm_animal()
  sym <- symbolize(bundle$fit, data = bundle$data)
  h <- sym$metadata$heritability
  expect_s3_class(h, "data.frame")
  expect_equal(nrow(h), 1L)
  expect_equal(h$group, "animal")
  expect_true(h$heritability >= 0 && h$heritability <= 1)
  expect_match(h$reading, "Heritability", fixed = TRUE)
})

test_that("symbolize.MCMCglmm without ginverse has no animal_groups", {
  bundle <- fit_mcmcglmm_gaussian_re()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_length(sym$metadata$animal_groups, 0L)
  expect_null(sym$metadata$heritability)
})

# v0.21-redo: lock in the phylo / structural-dependence signals that
# ride alongside ginverse detection. The extractor was producing these
# fields since v0.21.0 but they were not asserted anywhere; previous
# vignette claims went unverified.

test_that("symbolize.MCMCglmm with ginverse sets detected_signals = 'phylo'", {
  bundle <- fit_mcmcglmm_animal()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_true("phylo" %in% sym$metadata$detected_signals)
})

test_that("symbolize.MCMCglmm with ginverse sets phylo_representation = 'all_nodes'", {
  bundle <- fit_mcmcglmm_animal()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_equal(sym$metadata$phylo_representation, "all_nodes")
})

test_that("symbolize.MCMCglmm with ginverse adds a structured-correlation row for A to the symbol dictionary", {
  bundle <- fit_mcmcglmm_animal()
  sym <- symbolize(bundle$fit, data = bundle$data)
  sd <- sym$symbol_dictionary
  expect_s3_class(sd, "data.frame")
  expect_true("role" %in% names(sd))
  expect_true("structured_correlation_phylo" %in% sd$role)
  a_row <- sd[sd$role == "structured_correlation_phylo", , drop = FALSE]
  expect_equal(nrow(a_row), 1L)
  expect_equal(a_row$symbol[[1L]], "\\mathbf{A}")
})

test_that("symbolize.MCMCglmm with ginverse fires phylo-gated assumption rows", {
  bundle <- fit_mcmcglmm_animal()
  sym <- symbolize(bundle$fit, data = bundle$data)
  a <- sym$assumptions
  expect_s3_class(a, "data.frame")
  expect_true("assumption" %in% names(a))
  # The CSV gates these on requires = "phylo". Without the
  # detected_signals propagation, none of them would render.
  expect_true("phylo_random_effect" %in% a$assumption)
  expect_true("phylo_brownian_motion" %in% a$assumption)
  expect_true("phylo_A_positive_definite" %in% a$assumption)
  expect_true("phylo_ultrametric_tree" %in% a$assumption)
})

test_that("symbolize.MCMCglmm without ginverse does NOT fire phylo signals", {
  bundle <- fit_mcmcglmm_gaussian_re()
  sym <- symbolize(bundle$fit, data = bundle$data)
  # Negative control: a non-phylo MCMCglmm fit (random = ~g only) must
  # not pretend to be phylo.
  expect_false("phylo" %in% sym$metadata$detected_signals)
  expect_null(sym$metadata$phylo_representation)
  sd <- sym$symbol_dictionary
  if ("role" %in% names(sd)) {
    expect_false("structured_correlation_phylo" %in% sd$role)
  }
})
