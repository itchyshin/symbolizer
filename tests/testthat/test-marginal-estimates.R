# Tests for the v0.1.1 S2 emmeans wrappers: group_means() and group_slopes().
#
# Each test fits a small drmTMB Gaussian fit, symbolize()s it, and checks
# that the wrapper returns a properly classed tibble with the S1 column
# shape. emmeans is a Suggests dependency; tests skip when it is not
# installed.

skip_if_no_marg_deps <- function() {
  testthat::skip_if_not_installed("drmTMB")
  testthat::skip_if_not_installed("emmeans")
}

test_that("group_means returns one row per level for a one-factor fit", {
  skip_if_no_marg_deps()
  set.seed(1); n <- 80
  dat <- data.frame(
    body_mass = rnorm(n, 30),
    sex = factor(rep(c("female", "male"), length.out = n))
  )
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ sex, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  gm <- group_means(sym)
  expect_s3_class(gm, "symbolizer_group_means")
  expect_equal(nrow(gm), 2L)
  expect_true(all(c("estimate", "std_error", "confint_low", "confint_high",
                    "excludes_zero", "ci_method") %in% names(gm)))
  expect_true("sex" %in% names(gm))
  expect_setequal(as.character(gm$sex), c("female", "male"))
})

test_that("group_means works on intercept-less cell-means fits", {
  skip_if_no_marg_deps()
  set.seed(1); n <- 80
  dat <- data.frame(
    body_mass = rnorm(n, 30),
    sex = factor(rep(c("female", "male"), length.out = n))
  )
  fit_int <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ sex, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  fit_cell <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ 0 + sex, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  gm_int  <- group_means(symbolize(fit_int))
  gm_cell <- group_means(symbolize(fit_cell))
  # emmeans sorts rows the same way for both; pair on the sex column.
  expect_equal(
    gm_int$estimate[order(gm_int$sex)],
    gm_cell$estimate[order(gm_cell$sex)],
    tolerance = 1e-6
  )
})

test_that("group_slopes returns per-group slope for cont x cat interaction", {
  skip_if_no_marg_deps()
  set.seed(2); n <- 120
  body_size <- rnorm(n)
  sex <- factor(rep(c("female", "male"), length.out = n))
  body_mass <- 30 + 2 * body_size + 3 * (sex == "male") +
    1.5 * body_size * (sex == "male") + rnorm(n)
  dat <- data.frame(body_mass = body_mass, sex = sex, body_size = body_size)
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ sex * body_size, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  gs <- group_slopes(sym, continuous = "body_size")
  expect_s3_class(gs, "symbolizer_group_slopes")
  expect_equal(nrow(gs), 2L)
  expect_true("predictor" %in% names(gs))
  expect_equal(unique(gs$predictor), "body_size")
})

test_that("group_slopes with numeric `at` supports cont x cont interactions", {
  skip_if_no_marg_deps()
  set.seed(3); n <- 120
  x <- rnorm(n); z <- rnorm(n)
  y <- 2 + 0.5 * x + 0.3 * z + 0.4 * x * z + rnorm(n)
  dat <- data.frame(y = y, x = x, z = z)
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ x * z, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  gs <- group_slopes(sym, continuous = "x", at = list(z = c(-1, 0, 1)))
  expect_s3_class(gs, "symbolizer_group_slopes")
  expect_equal(nrow(gs), 3L)
  expect_true("z" %in% names(gs))
})

test_that("group_means errors when the model has no factors", {
  skip_if_no_marg_deps()
  set.seed(4); n <- 80
  dat <- data.frame(body_mass = rnorm(n, 30), temperature = runif(n, 10, 25))
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ temperature, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  expect_error(group_means(sym), "no factors")
})

test_that("group_means.default errors with pointer to symbolize()", {
  expect_error(group_means(list()), "no method")
})

test_that("group_slopes.default errors with pointer to symbolize()", {
  expect_error(group_slopes(list(), continuous = "x"), "no method")
})

test_that("model_card carries marginal_means and marginal_slopes when applicable", {
  skip_if_no_marg_deps()
  set.seed(5); n <- 120
  body_size <- rnorm(n)
  sex <- factor(rep(c("female", "male"), length.out = n))
  body_mass <- 30 + 2 * body_size + 3 * (sex == "male") +
    1.5 * body_size * (sex == "male") + rnorm(n)
  dat <- data.frame(body_mass = body_mass, sex = sex, body_size = body_size)
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ sex * body_size, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  card <- model_card(sym)
  expect_s3_class(card$marginal_means,  "symbolizer_group_means")
  expect_s3_class(card$marginal_slopes, "symbolizer_group_slopes")
  expect_true(any(grepl("group_means",  card$extraction_calls, fixed = TRUE)))
  expect_true(any(grepl("group_slopes", card$extraction_calls, fixed = TRUE)))
})

test_that("model_card$marginal_slopes is NULL with no interaction", {
  skip_if_no_marg_deps()
  set.seed(6); n <- 80
  dat <- data.frame(
    body_mass = rnorm(n, 30),
    sex = factor(rep(c("female", "male"), length.out = n))
  )
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ sex, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  card <- model_card(sym)
  expect_null(card$marginal_slopes)
  expect_s3_class(card$marginal_means, "symbolizer_group_means")
})
