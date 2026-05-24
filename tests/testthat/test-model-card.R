# Tests for the GF5 single-call teaching bundle: model_card(sym).
#
# Each bundle section is already covered by the renderer-level tests; here we
# only verify that model_card() collects them in one S3 object with the
# class-specific extraction calls and plot recipes.

test_that("model_card returns the full bundle for drmTMB", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  card <- model_card(sym)
  expect_s3_class(card, "symbolizer_model_card")
  expect_setequal(
    names(card),
    c("meta", "equation", "symbols", "assumptions", "bridge",
      "formula_bridge", "interpretation",
      "extraction_calls", "recommended_plots")
  )
  expect_true(any(grepl("drmTMB::fixef", card$extraction_calls, fixed = TRUE)))
  expect_true(any(grepl("Residuals vs fitted", names(card$recommended_plots), fixed = TRUE)))
})

test_that("model_card extraction calls switch by class for gllvmTMB", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  card <- model_card(sym)
  expect_true(any(grepl("getLoadings", card$extraction_calls, fixed = TRUE)))
  expect_true(any(grepl("Loading plot", names(card$recommended_plots), fixed = TRUE)))
})

test_that("model_card.default errors with pointer to symbolize()", {
  expect_error(model_card(list()), "no method")
})
