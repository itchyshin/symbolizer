# Capability remediation mgcv-2b: capture the Gamma scale/dispersion phi.
# Audit: docs/dev-log/audits/2026-05-29-capability-reverify.md (mgcv MAJOR).
#
# mgcv estimates a single Gamma scale parameter phi (summary(fit)$dispersion ==
# fit$sig2 == fit$scale, with fit$scale.estimated TRUE). symbolizer's Gamma
# distribution row uses the drmTMB convention sigma_i where sigma_i^2 = phi
# (Var(y) = sigma^2 * mu^2 = phi * mu^2). But mgcv_build_variance_components only
# captured fit$sig2 for gaussian and fit$sp for smooths -- never the Gamma scale.
# So variance_components was EMPTY for a Gamma GAM and sigma_i (which appears in
# every rendered equation) had no estimate behind it. This slice captures phi as
# a dispersion row (var_estimate = phi = sigma_i^2, sd_estimate = sqrt(phi) =
# sigma_i), without disturbing the gaussian residual row or emitting a spurious
# row for fixed-scale families (poisson, binomial: scale.estimated FALSE).

test_that("Gamma GAM captures the scale/dispersion phi into variance_components (MAJOR)", {
  skip_if_not_installed("mgcv")
  set.seed(1L); n <- 150L; x <- runif(n); z <- runif(n)
  d <- data.frame(ygam = rgamma(n, shape = 4, rate = 4 / exp(1 + 0.7 * x)),
                  x = x, z = z)
  fit <- mgcv::gam(ygam ~ x + z, family = Gamma(), data = d, method = "REML")
  phi <- as.numeric(summary(fit)$dispersion)
  sym <- symbolize(fit)
  vc <- sym$variance_components
  disp <- vc[vc$kind == "dispersion", , drop = FALSE]
  expect_equal(nrow(disp), 1L)
  expect_equal(disp$var_estimate[[1L]], phi)        # sigma_i^2 = phi
  expect_equal(disp$sd_estimate[[1L]], sqrt(phi))   # sigma_i   = sqrt(phi)
})

test_that("fixed-scale families (poisson) emit no spurious dispersion row (regression)", {
  skip_if_not_installed("mgcv")
  set.seed(1L); n <- 150L; x <- runif(n); z <- runif(n)
  d <- data.frame(yp = rpois(n, exp(0.5 + 0.6 * x)), x = x, z = z)
  fit <- mgcv::gam(yp ~ x + z, family = poisson(), data = d, method = "REML")
  sym <- symbolize(fit)
  vc <- sym$variance_components
  expect_false(any(vc$kind == "dispersion"))
})

test_that("Gaussian GAM residual row is unchanged (regression)", {
  skip_if_not_installed("mgcv")
  set.seed(1L); n <- 150L; x <- runif(n); z <- runif(n)
  d <- data.frame(yg = 1 + 0.5 * x + rnorm(n), x = x, z = z)
  fit <- mgcv::gam(yg ~ x + z, data = d, method = "REML")
  sym <- symbolize(fit)
  vc <- sym$variance_components
  res <- vc[vc$kind == "residual", , drop = FALSE]
  expect_equal(nrow(res), 1L)
  expect_equal(res$var_estimate[[1L]], as.numeric(fit$sig2))
  expect_false(any(vc$kind == "dispersion"))  # gaussian uses residual, not dispersion
})
