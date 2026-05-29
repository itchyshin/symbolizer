# Capability remediation: non-Gaussian GAMs with smooth terms.
# Audit: docs/dev-log/audits/2026-05-29-capability-reverify.md (mgcv section).
#
# BLOCKER: capabilities.csv had only `gam,gaussian,smooth`, so a poisson /
# binomial / Gamma GAM with ANY smooth fell through to `gam,*,*,Planned or
# reserved` and aborted -- i.e. essentially every real non-Gaussian GAM was
# rejected, despite gam,{family},mu being advertised First slice.
#
# This slice (mgcv-1) opens poisson + binomial smooths, which use standard
# log / logit links and have no dispersion parameter, so the family-agnostic
# smooth machinery (already correct for gaussian) applies directly. Gamma is
# handled separately (inverse-link prose + scale capture) in mgcv-2.

test_that("poisson GAM with a smooth symbolizes with correct output (BLOCKER)", {
  skip_if_not_installed("mgcv")
  set.seed(1L); n <- 150L; x <- runif(n); z <- runif(n)
  d <- data.frame(ycount = rpois(n, exp(0.5 + 0.8 * x)), x = x, z = z)
  fit <- mgcv::gam(ycount ~ s(x) + z, family = poisson(), data = d,
                   method = "REML")

  expect_no_error(sym <- symbolize(fit))
  expect_equal(sym$model$family, "poisson")
  lat <- as_latex(sym)
  expect_match(lat, "Poisson")          # count likelihood
  expect_match(lat, "\\\\log")          # log link (not identity/inverse)
  expect_match(lat, "f_\\{")            # smooth term f_j(x) in the equation
  expect_false(is.null(sym$metadata$smooths))
})

test_that("binomial GAM with a smooth symbolizes with correct output (BLOCKER)", {
  skip_if_not_installed("mgcv")
  set.seed(2L); n <- 200L; x <- runif(n); z <- runif(n)
  d <- data.frame(ybin = rbinom(n, 1, plogis(-0.4 + 1.1 * x)), x = x, z = z)
  fit <- mgcv::gam(ybin ~ s(x) + z, family = binomial(), data = d,
                   method = "REML")

  expect_no_error(sym <- symbolize(fit))
  expect_equal(sym$model$family, "binomial")
  lat <- as_latex(sym)
  expect_match(lat, "Binomial")
  expect_match(lat, "logit")            # logit link
  expect_match(lat, "f_\\{")            # smooth term present
  expect_false(is.null(sym$metadata$smooths))
})
