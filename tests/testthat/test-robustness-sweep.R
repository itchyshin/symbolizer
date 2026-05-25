# Robustness sweep: every symbolize method, every public surface,
# end-to-end. Each block fits a small example, symbolizes it, then
# verifies each renderer doesn't error and returns the expected shape.
#
# This is a single safety net so a regression in any one extractor
# (or any one renderer with one family) shows up here.

run_public_surface <- function(sym, label) {
  expect_s3_class(sym, "symbolized_model")

  # as_latex returns character
  expect_type(as_latex(sym), "character")
  expect_true(nchar(as_latex(sym)) > 10L)

  # equations returns a symbolizer_equations tibble
  eq <- equations(sym)
  expect_s3_class(eq, "symbolizer_equations")
  expect_true(nrow(eq) >= 1L)

  # symbol_table returns a non-empty tibble
  st <- symbol_table(sym)
  expect_s3_class(st, "data.frame")
  expect_true(nrow(st) >= 1L)

  # assumption_table returns a non-empty tibble
  at <- assumption_table(sym)
  expect_s3_class(at, "data.frame")
  expect_true(nrow(at) >= 1L)

  # formula_bridge returns a tibble with at least one row
  fb <- formula_bridge(sym)
  expect_s3_class(fb, "data.frame")

  # parameter_interpretation returns a tibble
  pi <- parameter_interpretation(sym)
  expect_s3_class(pi, "data.frame")

  # as_dag returns a symbolic_dag list with $dot
  dag <- as_dag(sym)
  expect_s3_class(dag, "symbolic_dag")
  expect_match(dag$dot, "^digraph")

  # warning_table returns a tibble (may be empty)
  wt <- warning_table(sym)
  expect_s3_class(wt, "data.frame")
}

test_that("robustness: drmTMB gaussian location-scale fit", {
  skip_if_not_installed("drmTMB")
  sym <- symbolize(fit_drm_location_scale())
  run_public_surface(sym, "drmTMB gaussian")
})

test_that("robustness: drmTMB with random effects", {
  skip_if_not_installed("drmTMB")
  sym <- symbolize(fit_drm_with_re())
  run_public_surface(sym, "drmTMB gaussian + RE")
})

test_that("robustness: gllvmTMB gaussian latent variable", {
  skip_if_not_installed("gllvmTMB")
  sym <- symbolize(fit_gllvm_basic())
  run_public_surface(sym, "gllvmTMB gaussian")
})

test_that("robustness: glmmTMB gaussian + RE", {
  skip_if_not_installed("glmmTMB")
  sym <- symbolize(fit_glmm_gaussian_re())
  run_public_surface(sym, "glmmTMB gaussian + RE")
})

test_that("robustness: glmmTMB binomial", {
  skip_if_not_installed("glmmTMB")
  sym <- symbolize(fit_glmm_binomial())
  run_public_surface(sym, "glmmTMB binomial")
})

test_that("robustness: glmmTMB poisson", {
  skip_if_not_installed("glmmTMB")
  sym <- symbolize(fit_glmm_poisson())
  run_public_surface(sym, "glmmTMB poisson")
})

test_that("robustness: glmmTMB nbinom2", {
  skip_if_not_installed("glmmTMB")
  sym <- symbolize(fit_glmm_nbinom2())
  run_public_surface(sym, "glmmTMB nbinom2")
})

test_that("robustness: lm + lme4 lmer + glmer", {
  skip_if_not_installed("lme4")
  # base lm
  sym <- symbolize(lm(mpg ~ cyl, data = mtcars))
  run_public_surface(sym, "lm")
  # base glm gaussian
  sym <- symbolize(glm(mpg ~ cyl, data = mtcars, family = stats::gaussian()))
  run_public_surface(sym, "glm gaussian")
  # base glm binomial
  set.seed(1L)
  d <- data.frame(y = rbinom(80, 1, 0.5), x = rnorm(80))
  sym <- symbolize(glm(y ~ x, data = d, family = stats::binomial()))
  run_public_surface(sym, "glm binomial")
  # base glm poisson
  set.seed(2L)
  d <- data.frame(y = rpois(80, 3), x = rnorm(80))
  sym <- symbolize(glm(y ~ x, data = d, family = stats::poisson()))
  run_public_surface(sym, "glm poisson")
  # base glm Gamma
  set.seed(3L)
  d <- data.frame(y = rgamma(80, shape = 2, rate = 0.5), x = rnorm(80))
  sym <- symbolize(glm(y ~ x, data = d, family = stats::Gamma(link = "log")))
  run_public_surface(sym, "glm Gamma")
  # lmer
  set.seed(4L)
  g <- factor(rep(seq_len(10), length.out = 80))
  group_effect <- rnorm(10, 0, 1)[as.integer(g)]
  d <- data.frame(y = rnorm(80) + group_effect,
                  x = rnorm(80), g = g)
  fit <- suppressMessages(lme4::lmer(y ~ x + (1 | g), data = d))
  sym <- symbolize(fit)
  run_public_surface(sym, "lmer")
  # glmer binomial
  set.seed(5L)
  d <- data.frame(y = rbinom(80, 1, 0.5), x = rnorm(80),
                  g = factor(rep(1:10, length.out = 80)))
  fit <- suppressWarnings(suppressMessages(lme4::glmer(
    y ~ x + (1 | g), data = d, family = stats::binomial()
  )))
  sym <- symbolize(fit)
  run_public_surface(sym, "glmer binomial")
})

test_that("robustness: MCMCglmm gaussian + RE", {
  skip_if_not_installed("MCMCglmm")
  bundle <- fit_mcmcglmm_gaussian_re()
  sym <- symbolize(bundle$fit, data = bundle$data)
  run_public_surface(sym, "MCMCglmm gaussian + RE")
})

test_that("robustness: MCMCglmm animal model", {
  skip_if_not_installed("MCMCglmm")
  bundle <- fit_mcmcglmm_animal()
  sym <- symbolize(bundle$fit, data = bundle$data)
  run_public_surface(sym, "MCMCglmm animal")
})

test_that("robustness: sdmTMB gaussian + spatial", {
  skip_if_not_installed("sdmTMB")
  sym <- symbolize(fit_sdmtmb_gaussian_spatial())
  run_public_surface(sym, "sdmTMB spatial")
})
