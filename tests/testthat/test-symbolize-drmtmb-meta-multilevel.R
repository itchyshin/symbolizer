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

test_that("latex_marginal_cov_block emits one term per tier + diag(v)", {
  # v0.22.1.2: Tab 3 of the widget should *show* the marginal-covariance
  # decomposition (V2 Pat flow break 2). The helper returns a LaTeX
  # `Cov(y) = sigma_p^2 A + sigma_study^2 ZZ^T + diag(v)` block.
  fit <- fit_drmtmb_phylo_multilevel()
  sym <- symbolize(fit)
  block <- symbolizer:::latex_marginal_cov_block(sym)
  expect_true(!is.null(block))
  # Structured phylo tier carries A.
  expect_match(block, "\\\\mathbf\\{A\\}", perl = TRUE)
  # Unstructured study tier carries Z Z^T.
  expect_match(block, "\\\\mathbf\\{Z\\}_\\{study_ID\\}", perl = TRUE)
  # Meta-analytic sampling-variance tier carries diag(v).
  expect_match(block, "\\\\mathrm\\{diag\\}\\(\\\\mathbf\\{v\\}\\)",
               perl = TRUE)
  # LHS is Cov(y) underbraced with n.
  expect_match(block, "\\\\mathrm\\{Cov\\}\\(\\\\mathbf\\{y\\}\\)",
               perl = TRUE)
})

test_that("latex_marginal_cov_block returns NULL for single-RE non-meta fits", {
  # Standard textbook decomposition; nothing pedagogically interesting
  # to add over what the per-RE distribution row already shows.
  fit <- drmTMB::drmTMB(drmTMB::drm_formula(mpg ~ wt + (1 | cyl),
                                            sigma ~ 1),
                       data = mtcars)
  sym <- symbolize(fit)
  expect_null(symbolizer:::latex_marginal_cov_block(sym))
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
