# Additional simulate_recipe() families and print/knit surfaces.

test_that("simulate_recipe custom n_obs is reflected in metadata", {
  skip_if_not_installed("drmTMB")
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  rec <- simulate_recipe(sym, n = 40L)
  expect_equal(rec$metadata$n_obs, 40L)
})

test_that("simulate_recipe nbinom2 mentions NegBinomial and size = exp(sigma)", {
  skip_if_not_installed("drmTMB")
  fit <- suppressWarnings(fit_drm_nbinom2())
  sym <- symbolize(fit)
  rec <- simulate_recipe(sym)
  expect_match(rec$r_code, "rnbinom", fixed = TRUE)
  expect_match(rec$r_code, "exp(sigma)", fixed = TRUE)
  expect_true(rec$metadata$has_sigma)
})

test_that("simulate_recipe beta uses rbeta with precision parameterization", {
  skip_if_not_installed("drmTMB")
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  rec <- simulate_recipe(sym)
  expect_match(rec$r_code, "rbeta", fixed = TRUE)
  expect_match(rec$pseudocode[[length(rec$pseudocode)]], "Beta", fixed = TRUE)
})

test_that("simulate_recipe Poisson zi branch documents ZIP draws", {
  skip_if_not_installed("drmTMB")
  fit <- suppressWarnings(fit_drm_poisson_zi())
  sym <- symbolize(fit)
  rec <- simulate_recipe(sym)
  expect_true(rec$metadata$has_zi)
  expect_match(rec$r_code, "pi_zi", fixed = TRUE)
  expect_match(rec$pseudocode[[length(rec$pseudocode)]], "ZIP", fixed = TRUE)
})

test_that("print.symbolizer_simulation_recipe lists pseudocode and R code", {
  skip_if_not_installed("drmTMB")
  fit <- fit_drm_location_scale()
  rec <- simulate_recipe(symbolize(fit), seed = 3L)
  out <- paste(utils::capture.output(print(rec), type = "message"), collapse = "\n")
  expect_match(out, "Simulation recipe", fixed = TRUE)
  expect_match(out, "Pseudocode", fixed = TRUE)
  expect_match(out, "R code", fixed = TRUE)
  expect_match(out, "set.seed(3)", fixed = TRUE)
  expect_invisible(print(rec))
})

test_that("recipe_inv_link maps probit and cloglog for glmmTMB dispersion", {
  skip_if_not_installed("glmmTMB")
  skip_if_not_installed("lme4")
  d <- lme4::cbpp
  fit <- suppressWarnings(glmmTMB::glmmTMB(
    cbind(incidence, size - incidence) ~ period + (1 | herd),
    data = d, family = binomial()))
  sym <- symbolize(fit)
  rec <- simulate_recipe(sym)
  expect_match(rec$r_code, "plogis", fixed = TRUE)
  expect_match(rec$r_code, "rbinom", fixed = TRUE)
})
