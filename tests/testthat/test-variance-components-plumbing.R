# variance-components surface, Slice 1 (keystone plumbing).
# Spec: docs/specs/variance-components.md
#
# (a) The drmTMB variance_components builder must carry numeric estimates
#     (sd_estimate / var_estimate), like lme4 and glmmTMB already do. It
#     currently carries only symbol / n_levels / description, so every
#     downstream reading (partition %, ICC, repeatability) is blocked for
#     symbolizer's flagship class.
# (b) explain() and model_card() must surface variance_components -- they
#     omit it today, so a biologist never sees where the variation lives.

test_that("drmTMB variance_components carries finite sd/var estimates", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_with_re())
  sym <- symbolize(fit)
  vc  <- sym$variance_components

  expect_true(!is.null(vc) && nrow(vc) >= 1L,
              info = "RE fit should have >=1 variance component row")
  expect_true("sd_estimate" %in% names(vc),
              info = "drmTMB variance_components must carry sd_estimate")
  expect_true("var_estimate" %in% names(vc),
              info = "drmTMB variance_components must carry var_estimate")
  expect_true(all(is.finite(vc$sd_estimate)),
              info = "RE SD estimates must be finite numbers, not NA/symbols only")
  expect_equal(vc$var_estimate, vc$sd_estimate^2, tolerance = 1e-6)
  expect_gt(vc$sd_estimate[[1L]], 0)
})

test_that("explain() surfaces the variance components (how the variation splits)", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_with_re())
  ex  <- explain(fit)
  expect_false(is.null(ex$variance_components),
               info = "explain() must include variance_components in its pieces")
  # cli::cli_h2() headings write to the message stream (stderr), not stdout,
  # so capture both before grepping for the "How the variation splits" header.
  txt <- paste(c(
    utils::capture.output(print(ex), type = "output"),
    utils::capture.output(print(ex), type = "message")
  ), collapse = "\n")
  expect_match(txt, "variation", ignore.case = TRUE)
})

test_that("model_card() includes the variance components", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_with_re())
  sym <- symbolize(fit)
  mc  <- model_card(sym)
  expect_false(is.null(mc$variance_components),
               info = "model_card() must include variance_components")
  expect_true(nrow(mc$variance_components) >= 1L)
})

test_that("lme4 variance_components already carry numbers (no regression)", {
  skip_if_not_installed("lme4")
  fit <- suppressWarnings(lme4::lmer(
    Reaction ~ Days + (1 | Subject), data = lme4::sleepstudy))
  sym <- symbolize(fit)
  vc  <- sym$variance_components
  expect_true(all(c("sd_estimate", "var_estimate") %in% names(vc)))
  expect_true(all(is.finite(vc$sd_estimate)))
})
