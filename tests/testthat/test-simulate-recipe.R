# Tests for simulate_recipe() (v0.18).

test_that("simulate_recipe builds a recipe for a Gaussian location-scale fit", {
  skip_if_not_installed("drmTMB")
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  rec <- simulate_recipe(sym, seed = 1L)
  expect_s3_class(rec, "symbolizer_simulation_recipe")
  expect_true(is.character(rec$pseudocode) && length(rec$pseudocode) >= 2L)
  expect_match(rec$r_code, "set.seed(1)", fixed = TRUE)
  expect_match(rec$r_code, "rnorm", fixed = TRUE)
})

test_that("simulate_recipe handles binomial family with logit link", {
  skip_if_not_installed("lme4")
  set.seed(1)
  d <- data.frame(y = rbinom(80, 1, 0.5), x = rnorm(80))
  fit <- glm(y ~ x, data = d, family = stats::binomial())
  sym <- symbolize(fit)
  rec <- simulate_recipe(sym)
  expect_match(rec$r_code, "plogis", fixed = TRUE)
  expect_match(rec$r_code, "rbinom", fixed = TRUE)
})

test_that("simulate_recipe handles Poisson family", {
  set.seed(2)
  d <- data.frame(y = rpois(80, 3), x = rnorm(80))
  fit <- glm(y ~ x, data = d, family = stats::poisson())
  sym <- symbolize(fit)
  rec <- simulate_recipe(sym)
  expect_match(rec$r_code, "rpois", fixed = TRUE)
})

test_that("simulate_recipe handles Gamma family", {
  set.seed(3)
  d <- data.frame(y = rgamma(80, 2, 0.5), x = rnorm(80))
  fit <- glm(y ~ x, data = d, family = stats::Gamma(link = "log"))
  sym <- symbolize(fit)
  rec <- simulate_recipe(sym)
  expect_match(rec$r_code, "rgamma", fixed = TRUE)
})

test_that("simulate_recipe handles meta-analysis (meta_normal) family", {
  skip_if_not_installed("metafor")
  fit <- fit_metafor_rma()
  sym <- symbolize(fit)
  rec <- simulate_recipe(sym)
  expect_match(rec$r_code, "tau2", fixed = TRUE)
  expect_match(rec$r_code, "v_i", fixed = TRUE)
})

test_that("simulate_recipe errors helpfully on non-symbolized input", {
  expect_error(simulate_recipe(list()), "has no method")
})

test_that("as_dag enrichment: mermaid + tikz slots are populated", {
  skip_if_not_installed("drmTMB")
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  dag <- as_dag(sym)
  expect_true(all(c("dot", "mermaid", "tikz") %in% names(dag)))
  expect_match(dag$mermaid, "^flowchart", fixed = FALSE)
  expect_match(dag$tikz, "begin{tikzpicture}", fixed = TRUE)
  expect_match(dag$tikz, "end{tikzpicture}", fixed = TRUE)
})
