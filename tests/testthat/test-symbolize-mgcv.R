# Tests for the v0.14 mgcv::gam extractor (covers gam, bam, gamm$gam,
# gamm4$gam).

test_that("symbolize.gam builds a symbolized_model for a Gaussian gam with s(x)", {
  fit <- fit_gam_simple()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "gam")
  expect_equal(sym$model$family, "gaussian")
  expect_equal(sym$model$smooth_count, 1L)
})

test_that("gam smooths are summarised in metadata$smooths with edf + bs_dim", {
  fit <- fit_gam_simple()
  sym <- symbolize(fit)
  sm <- sym$metadata$smooths
  expect_s3_class(sm, "data.frame")
  expect_equal(nrow(sm), 1L)
  expect_equal(sm$label[[1L]], "s(x)")
  expect_true(sm$bs_dim[[1L]] >= 1L)
  expect_true(sm$edf[[1L]] > 0)
})

test_that("gam parametric fixed effects come out with Wald CIs", {
  fit <- fit_gam_simple()
  sym <- symbolize(fit)
  fe <- sym$fixed_effects
  expect_true(nrow(fe) == 2L)  # intercept + z
  expect_false(any(is.na(fe$estimate)))
  expect_false(any(is.na(fe$confint_low)))
  expect_equal(fe$ci_method[[1L]], "wald")
})

test_that("gam LaTeX shows f_1(x_i) for the smooth term", {
  fit <- fit_gam_simple()
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  expect_match(tex, "f_{1}(x_i)", fixed = TRUE)
})

test_that("s(x, by = group) produces one smooth row per factor level in metadata", {
  fit <- fit_gam_by()
  sym <- symbolize(fit)
  expect_true(nrow(sym$metadata$smooths) >= 2L)
  tex <- as_latex(sym)
  expect_match(tex, "f_{2}", fixed = TRUE)
})

test_that("te(x, z) renders as a multivariate smooth f_1(x_i, z_i)", {
  fit <- fit_gam_te()
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  expect_match(tex, "f_{1}(x_i,", fixed = TRUE)
  expect_match(tex, "z_i)", fixed = TRUE)
})

test_that("gam variance_components include residual + smoothing parameters", {
  fit <- fit_gam_simple()
  sym <- symbolize(fit)
  vc <- sym$variance_components
  expect_true(any(vc$kind == "residual"))
  expect_true(any(vc$kind == "smoothing_param"))
})

test_that("gamm$gam slot symbolizes via symbolize.gam", {
  fit <- fit_gamm_simple()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_true(sym$model$smooth_count >= 1L)
})

test_that("gamm4$gam slot symbolizes via symbolize.gam", {
  skip_if_not_installed("gamm4")
  fit <- fit_gamm4_simple()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_true(sym$model$smooth_count >= 1L)
})

# Audit B1: the mgcv extractor must surface the design matrix (including
# the smooth basis columns, aligned to coef(fit)) and the fitted mean so
# Tab 3 fills with data.
test_that("symbolize.gam populates expanded$X / mu_hat (audit B1)", {
  fit <- fit_gam_simple()
  sym <- symbolize(fit)
  ex <- sym$expanded
  expect_true(is.matrix(ex$X))
  expect_equal(nrow(ex$X), sym$model$n_obs)
  expect_equal(length(ex$beta), ncol(ex$X))   # basis cols align with coef()
  expect_equal(as.numeric(ex$mu_hat),
               as.numeric(stats::fitted(fit)), tolerance = 1e-6)
  html <- as_html_three_views(sym)
  expect_false(grepl("not captured", html))
  expect_match(html, "mathbf\\{X\\}")
})
