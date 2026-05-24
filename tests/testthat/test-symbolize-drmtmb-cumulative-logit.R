# cumulative_logit: ordered categorical response, proportional-odds.
# Structurally different from the other families (no intercept on the
# linear predictor — K-1 thresholds replace it).

test_that("cumulative_logit symbolizes end-to-end", {
  fit <- fit_drm_cumulative_logit()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$family, "cumulative_logit")
})

test_that("cumulative_logit distribution row uses the cumulative-CDF form", {
  fit <- fit_drm_cumulative_logit()
  sym <- symbolize(fit)
  expect_match(sym$distribution$latex, "logit}^{-1}",  fixed = TRUE)
  expect_match(sym$distribution$latex, "theta_k",      fixed = TRUE)
  expect_match(sym$distribution$latex, "K-1",          fixed = TRUE)
})

test_that("cumulative_logit linear predictor has NO intercept term", {
  fit <- fit_drm_cumulative_logit()
  sym <- symbolize(fit)
  lp <- sym$components$equation[sym$components$name == "mu_linear_predictor"]
  # Expect "\beta_{1}" (the slope) but NOT "\beta_{0}" (no intercept).
  expect_match(lp, "beta_\\{1\\}", fixed = FALSE)
  expect_false(grepl("beta_\\{0\\}", lp, fixed = FALSE))
})

test_that("cumulative_logit interpretation uses proportional-odds language", {
  fit <- fit_drm_cumulative_logit()
  sym <- symbolize(fit)
  mu_rows <- sym$interpretation[sym$interpretation$submodel == "mu", , drop = FALSE]
  expect_true(any(grepl("proportional-odds|cumulative odds",
                        mu_rows$biological_reading)))
})

test_that("cumulative_logit assumption table flags proportional-odds + ordered-response", {
  fit <- fit_drm_cumulative_logit()
  sym <- symbolize(fit)
  expect_true("proportional_odds"           %in% sym$assumptions$assumption)
  expect_true("ordered_categorical_response" %in% sym$assumptions$assumption)
  expect_true("thresholds_ordered"           %in% sym$assumptions$assumption)
})

test_that("cumulative_logit methods_text explains proportional-odds", {
  fit <- fit_drm_cumulative_logit()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  expect_match(mt$text, "cumulative-logit",      fixed = TRUE)
  expect_match(mt$text, "proportional-odds",     fixed = TRUE)
  expect_match(mt$text, "K-1 thresholds",        fixed = TRUE)
  expect_false(grepl("[unfilled:", mt$text, fixed = TRUE))
})

test_that("cumulative_logit capability rows are First slice", {
  caps <- symbolizer_capabilities()
  rows <- caps[caps$class == "drmTMB" & caps$family == "cumulative_logit", ]
  expect_true(nrow(rows) >= 1L)
  expect_true(all(rows$status == "First slice"))
})
