test_that("intercept-only formula returns one row", {
  dat <- data.frame(y = 1:5, x = 1:5)
  tt <- extract_terms(y ~ 1, dat, "mu")
  expect_equal(nrow(tt), 1L)
  expect_equal(tt$role, "intercept")
  expect_equal(tt$coefficient_symbol, "\\beta_{0}")
})

test_that("single continuous predictor", {
  dat <- data.frame(y = 1:5, x = 1:5)
  tt <- extract_terms(y ~ x, dat, "mu", symbols = c(x = "X_i"))
  expect_equal(nrow(tt), 2L)
  expect_equal(tt$role, c("intercept", "predictor"))
  expect_equal(tt$variable, c(NA_character_, "x"))
  expect_equal(tt$symbol[[2L]], "X_i")
  expect_match(tt$latex_term[[2L]], "\\\\beta_\\{1\\}\\s+\\\\,\\s+X_i")
})

test_that("factor with treatment contrast", {
  dat <- data.frame(y = 1:6, sex = factor(rep(c("female", "male"), 3)))
  tt <- extract_terms(y ~ sex, dat, "mu")
  expect_equal(nrow(tt), 2L)
  expect_equal(tt$role[[2L]], "factor_contrast")
  expect_equal(tt$variable[[2L]], "sex")
  expect_equal(tt$contrast_level[[2L]], "male")
})

test_that("two-way continuous-continuous interaction", {
  dat <- data.frame(y = 1:8, x = 1:8, z = 1:8)
  tt <- extract_terms(y ~ x + z + x:z, dat, "mu",
                      symbols = c(x = "X_i", z = "Z_i"))
  expect_equal(nrow(tt), 4L)
  inter <- tt[tt$role == "interaction", , drop = FALSE]
  expect_equal(nrow(inter), 1L)
  expect_equal(inter$variable, "x:z")
  expect_match(inter$latex_term, "X_i\\s+\\\\,\\s+Z_i")
})

test_that("continuous-by-factor interaction", {
  dat <- data.frame(y = 1:8, x = 1:8,
                    sex = factor(rep(c("female", "male"), 4)))
  tt <- extract_terms(y ~ x * sex, dat, "mu",
                      symbols = c(x = "X_i", sex = "S_i"))
  expect_true(any(tt$role == "interaction"))
  expect_true(any(tt$role == "factor_contrast"))
})

test_that("log transformation", {
  dat <- data.frame(y = 1:5, x = 2:6)
  tt <- extract_terms(y ~ log(x), dat, "mu", symbols = c(x = "X_i"))
  expect_equal(tt$role, c("intercept", "transformation"))
  expect_equal(tt$transform[[2L]], "log")
  expect_equal(tt$variable[[2L]], "x")
  expect_match(tt$latex_term[[2L]], "\\\\mathrm\\{log\\}\\(X_i\\)")
})

test_that("scale transformation", {
  dat <- data.frame(y = 1:5, x = 1:5)
  tt <- extract_terms(y ~ scale(x), dat, "mu", symbols = c(x = "X_i"))
  expect_equal(tt$transform[[2L]], "scale")
  expect_match(tt$latex_term[[2L]], "\\\\mathrm\\{scale\\}\\(X_i\\)")
})

test_that("offset is detected and gets no coefficient", {
  dat <- data.frame(y = 1:5, x = 1:5, exposure = c(1, 2, 4, 8, 16))
  tt <- extract_terms(y ~ x + offset(log(exposure)), dat, "mu",
                      symbols = c(x = "X_i", exposure = "E_i"))
  offset_rows <- tt[tt$role == "offset", , drop = FALSE]
  expect_equal(nrow(offset_rows), 1L)
  expect_true(is.na(offset_rows$coefficient_symbol))
  expect_equal(offset_rows$transform, "log")
  expect_match(offset_rows$latex_term, "\\\\mathrm\\{log\\}\\(E_i\\)")
})

test_that("one-sided formula works (sigma submodel)", {
  dat <- data.frame(y = 1:5, x = 1:5)
  tt <- extract_terms(~ x, dat, "sigma", coefficient_family = "gamma")
  expect_equal(tt$coefficient_symbol, c("\\gamma_{0}", "\\gamma_{1}"))
})

test_that("auto-generated symbols when user does not supply them", {
  dat <- data.frame(y = 1:5, temperature = 1:5)
  tt <- extract_terms(y ~ temperature, dat, "mu")
  expect_equal(tt$symbol[[2L]], "temperature_i")
})

test_that("user-supplied symbols override defaults", {
  dat <- data.frame(y = 1:5, temperature = 1:5)
  tt <- extract_terms(y ~ temperature, dat, "mu",
                      symbols = c(temperature = "T_i"))
  expect_equal(tt$symbol[[2L]], "T_i")
})
