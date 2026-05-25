# Tests for the v0.15 rma.ls (location-scale meta-regression) path.

test_that("symbolize.rma.uni detects location-scale fits", {
  fit <- fit_metafor_rma_ls()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_true(sym$metadata$is_location_scale)
})

test_that("rma.ls adds a tau2 submodel to fixed_effects", {
  fit <- fit_metafor_rma_ls()
  sym <- symbolize(fit)
  fe <- sym$fixed_effects
  expect_true("tau2" %in% fe$submodel)
  tau_rows <- fe[fe$submodel == "tau2", , drop = FALSE]
  # Intercept + ni
  expect_true(nrow(tau_rows) >= 2L)
  # Alpha estimates match metafor's fit$alpha
  expect_equal(
    sort(as.numeric(tau_rows$estimate)),
    sort(as.numeric(fit$alpha[, 1L])),
    tolerance = 1e-6
  )
})

test_that("rma.ls alpha CIs come from fit$ci.lb.alpha / fit$ci.ub.alpha", {
  fit <- fit_metafor_rma_ls()
  sym <- symbolize(fit)
  tau_rows <- sym$fixed_effects[sym$fixed_effects$submodel == "tau2", , drop = FALSE]
  expect_false(any(is.na(tau_rows$confint_low)))
  expect_false(any(is.na(tau_rows$confint_high)))
  # Bounds should be ordered
  expect_true(all(tau_rows$confint_low < tau_rows$confint_high))
})

test_that("rma.ls LaTeX shows log(tau^2_i) on the scale line", {
  fit <- fit_metafor_rma_ls()
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  expect_match(tex, "tau", fixed = TRUE)
  expect_match(tex, "alpha", fixed = TRUE)
  expect_match(tex, "log(\\tau", fixed = TRUE)
})

test_that("rma.ls variance_components flags kind = heterogeneity_scale", {
  fit <- fit_metafor_rma_ls()
  sym <- symbolize(fit)
  vc <- sym$variance_components
  expect_true("heterogeneity_scale" %in% vc$kind)
  expect_true("sampling_variance" %in% vc$kind)
})

test_that("rma.ls interpretation rows for tau2 mention variance multiplicatively", {
  fit <- fit_metafor_rma_ls()
  sym <- symbolize(fit)
  interp <- sym$interpretation
  tau_interp <- interp[interp$submodel == "tau2", , drop = FALSE]
  expect_true(nrow(tau_interp) >= 2L)
  if ("natural_scale_reading" %in% names(tau_interp)) {
    expect_match(
      paste(tau_interp$natural_scale_reading, collapse = " "),
      "VARIANCE|tau\\^2 changes multiplicatively",
      ignore.case = TRUE
    )
  }
})
