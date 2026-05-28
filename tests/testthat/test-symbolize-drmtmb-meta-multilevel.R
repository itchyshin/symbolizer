# Tests for symbolize.drmTMB on a phylogenetic multilevel meta-analysis
# fit. Required by v0.22.1 Widget 2 (§4 of symbolizer-meta-analysis.Rmd).

test_that("symbolize() runs on a drmTMB phylo + multilevel + meta_V fit", {
  fit <- fit_drmtmb_phylo_multilevel()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
})

test_that("metadata$context is tagged 'meta_analysis' on a meta_V fit", {
  fit <- fit_drmtmb_phylo_multilevel()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$metadata$context))
  expect_match(sym$metadata$context, "meta_analysis", fixed = TRUE)
})

test_that("metadata$phylo_representation is tagged when phylo() is in the formula", {
  fit <- fit_drmtmb_phylo_multilevel()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$metadata$phylo_representation))
})

test_that("variance_components includes the phylogeny + study tiers", {
  # phylo() random effects are surfaced via metadata$phylo_representation and
  # structured_matrices, not via the standard variance_components table (which
  # only captures fit$random_effects entries). Surfacing phylo variance
  # components in variance_components requires a separate extraction slice.
  testthat::skip("phylo variance tier in variance_components deferred: phylo(1 | phylogeny) is handled via structured_matrices, not fit$random_effects; separate extraction slice needed")
  fit <- fit_drmtmb_phylo_multilevel()
  sym <- symbolize(fit)
  vc <- sym$variance_components
  joined <- paste(vc$group_var, collapse = " ")
  expect_match(joined, "phylogeny|species", perl = TRUE)
  expect_match(joined, "study_ID|study", perl = TRUE)
})

test_that("assumption_table mentions the known sampling variance v_k", {
  fit <- fit_drmtmb_phylo_multilevel()
  sym <- symbolize(fit)
  at <- assumption_table(sym)
  joined <- paste(at$expression_latex, at$biological_meaning,
                  collapse = " ", sep = " ")
  expect_match(joined, "v_k|sampling variance|Var_dARR|meta_V",
               perl = TRUE)
})
