# Capability remediation mgcv-2a: link-honest prose for non-default links.
# Audit: docs/dev-log/audits/2026-05-29-capability-reverify.md (mgcv MAJOR).
#
# mgcv's Gamma() defaults to the INVERSE link, but symbolizer's prose layers
# (assumptions linear_predictor row; interpretation link/natural readings) were
# hard-coded to the family-default "log" link -- so they claimed "log link /
# exp(beta) multiplies the mean" for an inverse-link fit, inverting the science.
# The equation already reads the actual link correctly. This slice makes the
# prose consult the actual fit link; for a link without a simple multiplicative
# reading (inverse), it states the link honestly rather than fabricating one.

test_that("inverse-link Gamma prose is link-honest, not log (MAJOR)", {
  skip_if_not_installed("mgcv")
  set.seed(1L); n <- 150L; x <- runif(n); z <- runif(n)
  d <- data.frame(ygam = rgamma(n, shape = 4, rate = 4 / exp(1 + 0.7 * x)),
                  x = x, z = z)
  fit <- mgcv::gam(ygam ~ x + z, family = Gamma(), data = d, method = "REML")
  expect_equal(symbolize(fit)$submodels$link[1L], "inverse")  # sanity: inverse link
  sym <- symbolize(fit)

  lp <- sym$assumptions[sym$assumptions$assumption == "linear_predictor", , drop = FALSE]
  expect_no_match(lp$expression_latex[[1L]], "\\\\log")          # not log(mu)
  expect_match(lp$biological_meaning[[1L]], "inverse", ignore.case = TRUE)

  ip <- sym$interpretation
  # No false "Log mean ... / exp(beta) multiplies the mean" reading.
  expect_false(any(grepl("Log mean", ip$link_scale_reading, ignore.case = TRUE)))
  expect_true(any(grepl("inverse", c(ip$link_scale_reading, ip$natural_scale_reading),
                        ignore.case = TRUE)))
})

test_that("inverse-link override does not leak into the sigma submodel row (regression)", {
  # mgcv-2a regression guard: the mu link override (drm_build_assumptions) must
  # rewrite ONLY the mu-submodel linear_predictor row, never the sigma-submodel
  # row. A first cut matched every linear_predictor row, so the sigma row wrongly
  # showed "1/mu_i = ... / inverse link on mu".
  skip_if_not_installed("mgcv")
  set.seed(1L); n <- 150L; x <- runif(n); z <- runif(n)
  d <- data.frame(ygam = rgamma(n, shape = 4, rate = 4 / exp(1 + 0.7 * x)),
                  x = x, z = z)
  fit <- mgcv::gam(ygam ~ x + z, family = Gamma(), data = d, method = "REML")
  a <- symbolize(fit)$assumptions
  sig_lp <- a[a$submodel == "sigma" & a$assumption == "linear_predictor", , drop = FALSE]
  expect_false(any(grepl("inverse link on mu", sig_lp$biological_meaning, fixed = TRUE)))
  expect_false(any(grepl("\\frac{1}{\\mu_i}", sig_lp$expression_latex, fixed = TRUE)))
})

test_that("three-views coefficient-reading box is link-honest for inverse Gamma (MAJOR)", {
  # render-three-views.R three_views_coef_reading() was family-keyed only, so an
  # inverse-link Gamma widget showed "exp(beta) multiplies the mean (log link)"
  # above an equation that reads inverse(mu_i). The box must consult the link.
  skip_if_not_installed("mgcv")
  set.seed(1L); n <- 150L; x <- runif(n); z <- runif(n)
  d <- data.frame(ygam = rgamma(n, shape = 4, rate = 4 / exp(1 + 0.7 * x)),
                  x = x, z = z)
  fit <- mgcv::gam(ygam ~ x + z, family = Gamma(), data = d, method = "REML")
  html <- as_html_three_views(symbolize(fit))
  expect_false(grepl("multiplies the mean of the response", html, fixed = TRUE))
  expect_true(grepl("no single exp(beta) multiplier", html, fixed = TRUE))
})

test_that("three-views coefficient-reading box unchanged for log-link Gamma (regression)", {
  skip_if_not_installed("mgcv")
  set.seed(1L); n <- 150L; x <- runif(n); z <- runif(n)
  d <- data.frame(ygam = rgamma(n, shape = 4, rate = 4 / exp(1 + 0.7 * x)),
                  x = x, z = z)
  fit <- mgcv::gam(ygam ~ x + z, family = Gamma(link = "log"), data = d,
                   method = "REML")
  html <- as_html_three_views(symbolize(fit))
  expect_true(grepl("multiplies the mean of the response", html, fixed = TRUE))
})

test_that("log-link Gamma prose is unchanged (no regression)", {
  skip_if_not_installed("mgcv")
  set.seed(1L); n <- 150L; x <- runif(n); z <- runif(n)
  d <- data.frame(ygam = rgamma(n, shape = 4, rate = 4 / exp(1 + 0.7 * x)),
                  x = x, z = z)
  fit <- mgcv::gam(ygam ~ x + z, family = Gamma(link = "log"), data = d,
                   method = "REML")
  sym <- symbolize(fit)
  lp <- sym$assumptions[sym$assumptions$assumption == "linear_predictor", , drop = FALSE]
  expect_match(lp$expression_latex[[1L]], "\\\\log")            # still log link
  expect_true(any(grepl("Log mean", sym$interpretation$link_scale_reading,
                        ignore.case = TRUE)))
})
