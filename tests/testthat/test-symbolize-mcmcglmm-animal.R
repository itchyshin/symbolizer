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
