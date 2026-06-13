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
      "notation_bridge", "formula_bridge", "interpretation", "factor_coding",
      "variance_components", "warnings", "extraction_calls",
      "recommended_plots", "marginal_means", "marginal_slopes",
      "marginal_contrasts")
  )
  # `bridge` is the deprecated alias of `notation_bridge` in model_card output.
  expect_identical(card$bridge, card$notation_bridge)
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

test_that("model_card surfaces marginal_contrasts for a factor model", {
  skip_if_not_installed("emmeans")
  d <- transform(mtcars, gear = factor(gear))
  card <- model_card(symbolize(lm(mpg ~ gear, data = d)))
  expect_s3_class(card$marginal_contrasts, "symbolizer_group_contrasts")
  expect_false("p.value" %in% names(card$marginal_contrasts))
})

test_that("model_card marginal_contrasts is NULL for a factor-free model", {
  card <- model_card(symbolize(lm(mpg ~ wt, data = mtcars)))
  expect_null(card$marginal_contrasts)
})

test_that("model_card knit_print includes the Group contrasts section", {
  skip_if_not_installed("emmeans")
  skip_if_not_installed("knitr")
  dg <- transform(mtcars, gear = factor(gear))
  out <- as.character(knitr::knit_print(model_card(symbolize(lm(mpg ~ gear, data = dg)))))
  expect_match(out, "Group contrasts")
})

test_that("model_card.default errors with pointer to symbolize()", {
  expect_error(model_card(list()), "no method")
})
