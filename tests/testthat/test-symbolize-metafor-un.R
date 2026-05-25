# Tests for v0.16 rma.mv with struct = "UN" (bivariate meta-analysis).

test_that("symbolize.rma.mv handles ~ outcome | trial with struct = 'UN'", {
  fit <- fit_metafor_rma_mv_un()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "rma.mv")
  expect_true("UN" %in% (fit$struct %||% character(0)))
})

test_that("UN structure produces per-inner-level heterogeneity_un rows", {
  fit <- fit_metafor_rma_mv_un()
  sym <- symbolize(fit)
  vc <- sym$variance_components
  expect_true("heterogeneity_un" %in% vc$kind)
  un_rows <- vc[vc$kind == "heterogeneity_un", , drop = FALSE]
  expect_true(nrow(un_rows) >= 2L)  # one per outcome level
  # Variances are positive
  expect_true(all(un_rows$var_estimate > 0))
})

test_that("UN structure produces an off-diagonal correlation row", {
  fit <- fit_metafor_rma_mv_un()
  sym <- symbolize(fit)
  vc <- sym$variance_components
  expect_true("correlation" %in% vc$kind)
  rho_rows <- vc[vc$kind == "correlation", , drop = FALSE]
  expect_equal(nrow(rho_rows), 1L)
  rho <- as.numeric(rho_rows$var_estimate[[1L]])
  expect_true(rho >= -1 && rho <= 1)
})

test_that("UN structure LaTeX renders multiple u_{inner(i)} random-effect terms", {
  fit <- fit_metafor_rma_mv_un()
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  # Each outcome level becomes its own u_{level(i)} symbol
  inner_levels <- fit$g.levels.f[[1L]]
  for (lvl in inner_levels) {
    expect_match(tex, paste0("u_{", lvl), fixed = TRUE)
  }
})
