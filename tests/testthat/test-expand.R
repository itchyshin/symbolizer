test_that("expand() returns the underlying numeric arrays", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  ex <- expand(sym)
  expect_s3_class(ex, "symbolized_expanded")
  expect_named(ex, c("y", "X", "beta", "X_sigma", "gamma", "Z_g", "u",
                     "e", "mu_hat", "sigma_hat"))
  expect_length(ex$y, sym$model$n_obs)
  expect_equal(dim(ex$X), c(sym$model$n_obs, 2L))
  expect_equal(length(ex$beta), 2L)
  expect_equal(length(ex$gamma), 2L)
  expect_null(ex$Z_g)
  expect_null(ex$u)
  expect_length(ex$mu_hat, sym$model$n_obs)
  expect_length(ex$sigma_hat, sym$model$n_obs)
  expect_true(all(ex$sigma_hat > 0))
})

test_that("expand() returns RE indicator matrix and BLUPs when RE present", {
  fit_re <- fit_drm_with_re()
  sym <- symbolize(fit_re, symbols = c(body_mass = "W_i"))
  ex <- expand(sym)
  expect_false(is.null(ex$Z_g))
  expect_equal(nrow(ex$Z_g), sym$model$n_obs)
  expect_equal(ncol(ex$Z_g), 6L)
  expect_true(all(rowSums(ex$Z_g) == 1)) # each row picks exactly one group
  expect_length(ex$u, 6L)
})

test_that("mu_hat matches X %*% beta on the fitted-effects part", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  ex <- expand(sym)
  expect_equal(as.numeric(ex$mu_hat),
               as.numeric(ex$X %*% ex$beta),
               tolerance = 1e-12)
})

test_that("sigma_hat matches exp(X_sigma %*% gamma)", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  ex <- expand(sym)
  expect_equal(as.numeric(ex$sigma_hat),
               as.numeric(exp(ex$X_sigma %*% ex$gamma)),
               tolerance = 1e-12)
})

test_that("expand.default errors with a pointer to symbolize()", {
  expect_error(expand(list()), "no method")
  expect_error(expand(42),     "no method")
})

test_that("print(expand(sym)) runs without error and returns its input invisibly", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  ex <- expand(sym)
  out <- withr::with_output_sink(tempfile(), print(ex))
  expect_s3_class(out, "symbolized_expanded")
})
