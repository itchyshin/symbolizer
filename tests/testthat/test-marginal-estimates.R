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

test_that("group_means errors helpfully on biv_gaussian fits", {
  skip_if_no_marg_deps()
  fit_bv <- fit_drm_biv_gaussian()
  sym_bv <- symbolize(fit_bv)
  expect_error(
    group_means(sym_bv),
    "does not currently support"
  )
  expect_error(
    group_means(sym_bv),
    "biv_gaussian"
  )
})

test_that("group_slopes errors helpfully on biv_gaussian fits", {
  skip_if_no_marg_deps()
  fit_bv <- fit_drm_biv_gaussian()
  sym_bv <- symbolize(fit_bv)
  expect_error(
    group_slopes(sym_bv, continuous = "x1"),
    "does not currently support"
  )
  expect_error(
    group_slopes(sym_bv, continuous = "x1"),
    "biv_gaussian"
  )
})

# --- Response- vs link-scale handling for non-Gaussian families --------------

test_that("group_means defaults to response scale on Poisson", {
  skip_if_no_marg_deps()
  set.seed(1); n <- 80
  sex <- factor(rep(c("F", "M"), length.out = n))
  dat <- data.frame(y = rpois(n, ifelse(sex == "F", 3, 6)), sex = sex)
  fit <- drmTMB::drmTMB(drmTMB::drm_formula(y ~ sex),
                        family = stats::poisson(), data = dat)
  sym <- symbolize(fit)
  gm_response <- group_means(sym)
  # On the response scale these are count rates; sex=F should be near 3 and
  # sex=M near 6 (the simulated truth) — far above the link-scale numbers.
  expect_true(all(gm_response$scale == "response"))
  expect_gt(gm_response$estimate[gm_response$sex == "M"], 4)
  # Link scale is log(rate); the M row should be near log(6) ~ 1.8.
  gm_link <- group_means(sym, scale = "link")
  expect_true(all(gm_link$scale == "link"))
  expect_lt(gm_link$estimate[gm_link$sex == "M"], 3)
})

test_that("group_means defaults to response scale on beta", {
  skip_if_no_marg_deps()
  set.seed(1); n <- 80
  sex <- factor(rep(c("F", "M"), length.out = n))
  dat <- data.frame(y = rbeta(n, ifelse(sex == "F", 2, 5), 5), sex = sex)
  fit <- drmTMB::drmTMB(drmTMB::drm_formula(y ~ sex, sigma ~ 1),
                        family = drmTMB::beta(), data = dat)
  sym <- symbolize(fit)
  gm <- group_means(sym)
  expect_true(all(gm$scale == "response"))
  # All estimates should be in (0, 1) since beta supports proportions.
  expect_true(all(gm$estimate > 0 & gm$estimate < 1))
})

test_that("group_means lognormal back-transforms to the geometric-mean response", {
  skip_if_no_marg_deps()
  set.seed(1); n <- 80
  sex <- factor(rep(c("F", "M"), length.out = n))
  dat <- data.frame(y = exp(rnorm(n, ifelse(sex == "F", 2, 3), 0.3)), sex = sex)
  fit <- drmTMB::drmTMB(drmTMB::drm_formula(y ~ sex, sigma ~ 1),
                        family = drmTMB::lognormal(), data = dat)
  sym <- symbolize(fit)
  gm <- group_means(sym)
  expect_true(all(gm$scale == "response"))
  # Geometric means: sex=F ~ exp(2) = 7.4, sex=M ~ exp(3) = 20.
  expect_gt(gm$estimate[gm$sex == "M"], 10)
  expect_lt(gm$estimate[gm$sex == "F"], 10)
})

test_that("group_means on Gaussian is unchanged by the scale argument", {
  skip_if_no_marg_deps()
  set.seed(1); n <- 80
  sex <- factor(rep(c("F", "M"), length.out = n))
  dat <- data.frame(y = rnorm(n, ifelse(sex == "F", 10, 15)), sex = sex)
  fit <- drmTMB::drmTMB(drmTMB::drm_formula(y ~ sex, sigma ~ 1),
                        family = stats::gaussian(), data = dat)
  sym <- symbolize(fit)
  resp <- group_means(sym, scale = "response")
  link <- group_means(sym, scale = "link")
  expect_equal(resp$estimate, link$estimate)
})

test_that("group_slopes accepts a scale argument and defaults to response", {
  skip_if_no_marg_deps()
  set.seed(1); n <- 80
  sex <- factor(rep(c("F", "M"), length.out = n))
  dat <- data.frame(
    y = rpois(n, exp(0.5 + 0.3 * (sex == "M")) + 0.5 * rnorm(n)),
    sex = sex,
    x   = rnorm(n)
  )
  # cont x cat fit so emtrends has something to stratify on
  dat$y <- rpois(n, exp(0.5 + 0.3 * dat$x + 0.2 * (sex == "M")))
  fit <- drmTMB::drmTMB(drmTMB::drm_formula(y ~ x * sex),
                        family = stats::poisson(), data = dat)
  sym <- symbolize(fit)
  gs <- group_slopes(sym, continuous = "x")
  expect_true("scale" %in% names(gs))
  expect_true(all(gs$scale == "response"))
})

test_that("print method names the scale", {
  skip_if_no_marg_deps()
  set.seed(1); n <- 80
  sex <- factor(rep(c("F", "M"), length.out = n))
  dat <- data.frame(y = rpois(n, 3), sex = sex)
  fit <- drmTMB::drmTMB(drmTMB::drm_formula(y ~ sex),
                        family = stats::poisson(), data = dat)
  sym <- symbolize(fit)
  msgs <- testthat::capture_messages(print(group_means(sym)))
  out <- paste(msgs, collapse = "")
  expect_match(out, "Scale: response", fixed = TRUE)
})
