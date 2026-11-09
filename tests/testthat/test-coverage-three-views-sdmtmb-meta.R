# Renderer smoke tests on sdmTMB / metafor paths that lack HTML three-views coverage.

test_that("sdmTMB spatial fit three-views HTML surfaces biology and variance panels", {
  skip_if_not_installed("sdmTMB")
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym, id = "sdm-cov"))
  expect_match(html, "1\\. Index", perl = TRUE)
  expect_match(html, "2\\. Matrix", perl = TRUE)
  expect_true(!is.null(sym$metadata$spatial_representation) ||
                grepl("spatial", html, ignore.case = TRUE))
})

test_that("sdmTMB symbolized model model_card bundles accessors without error", {
  skip_if_not_installed("sdmTMB")
  fit <- fit_sdmtmb_gaussian_spatial()
  sym <- symbolize(fit)
  expect_no_error(explain(fit))
  card <- model_card(sym)
  expect_true(length(card$extraction_calls) == 0L)
  expect_s3_class(card, "symbolizer_model_card")
})

test_that("metafor rma.ls three-views HTML includes heterogeneity scale wording", {
  skip_if_not_installed("metafor")
  fit <- fit_metafor_rma_ls()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym, id = "mv-ls"))
  expect_match(html, "tau", ignore.case = TRUE)
})

test_that("metafor rma.ls knit_print equations render aligned blocks", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("knitr")
  sym <- symbolize(fit_metafor_rma_ls())
  rendered <- as.character(knitr::knit_print(equations(sym, notation = "both")))
  expect_match(rendered, "Index form:", fixed = TRUE)
  expect_match(rendered, "Matrix form:", fixed = TRUE)
})
