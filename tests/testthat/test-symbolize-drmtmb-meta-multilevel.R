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
  fit <- fit_drmtmb_phylo_multilevel()
  sym <- symbolize(fit)
  vc <- sym$variance_components
  joined <- paste(vc$group_var, collapse = " ")
  expect_match(joined, "phylogeny|species", perl = TRUE)
  expect_match(joined, "study_ID|study", perl = TRUE)
})

test_that("equations show the structured phylo tier u_p ~ N(0, sigma_p^2 A)", {
  # V2 Pat blocker on symbolizer-meta-analysis.Rmd Sec 4: the article's
  # central thesis equation (phylogenetic random effect with the A
  # correlation matrix) must appear in the widget. Tests the matrix-form
  # equation rather than the index form because A only shows up on the
  # matrix side when the structured tier has it.
  fit <- fit_drmtmb_phylo_multilevel()
  sym <- symbolize(fit)
  eqs <- equations(sym, notation = "matrix")
  joined <- paste(eqs$matrix, collapse = " ")
  expect_match(joined, "\\\\mathbf\\{u\\}_\\{phylogeny\\}", perl = TRUE)
  expect_match(joined, "\\\\mathbf\\{A\\}", perl = TRUE)
})

test_that("structured_matrices metadata names the phylo A correlation matrix", {
  fit <- fit_drmtmb_phylo_multilevel()
  sym <- symbolize(fit)
  sm <- sym$metadata$structured_matrices
  expect_true(!is.null(sm))
  expect_true(length(sm) >= 1L)
  roles <- vapply(sm, function(x) x$role %||% NA_character_, character(1L))
  expect_true(any(grepl("phylo", roles)))
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
