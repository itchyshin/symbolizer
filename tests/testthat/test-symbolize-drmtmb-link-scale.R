# v0.22.2.1 Fisher-pass families-fisher.md surfaced a BLOCKER:
# drm_build_expanded() stores X*beta in sym$expanded$mu_hat without
# applying the link inverse. For non-identity-link families, mu_hat
# therefore holds the LINEAR PREDICTOR (eta_hat), not the response-
# scale predicted mean. Tab 3 of the Beta widget displayed
# mu_hat = -0.95 -- IMPOSSIBLE for a Beta mean which must be in (0,1).
#
# The fix exposes both:
#   sym$expanded$eta_hat = X*beta + sum_g Z_g %*% u_g   (linear predictor)
#   sym$expanded$mu_hat  = link_inverse(eta_hat)         (response scale)
#
# Identity-link fits keep mu_hat == eta_hat == X*beta (+ RE), so the
# Gaussian path is unchanged.

test_that("Poisson fit: mu_hat is response-scale rate, not linear predictor", {
  # Poisson link is log; mu = exp(eta). The displayed predicted value
  # should be the rate, not the log-rate. Bug surfaced via Fisher pass
  # showed mu_hat[1] = 0.936 (= eta) instead of exp(0.936) = 2.55.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_poisson())
  sym <- symbolize(fit)
  ex  <- sym$expanded

  X <- ex$X
  beta <- ex$beta
  eta_1 <- as.numeric(X[1, ] %*% beta)
  mu_1_expected <- exp(eta_1)  # log-link inverse

  # mu_hat (response scale)
  expect_equal(as.numeric(ex$mu_hat[[1L]]),
               mu_1_expected,
               tolerance = 1e-9)
  # And eta_hat slot exposed for renderer use
  expect_true("eta_hat" %in% names(ex))
  expect_equal(as.numeric(ex$eta_hat[[1L]]),
               eta_1,
               tolerance = 1e-9)
})

test_that("Beta fit: mu_hat is in (0,1), not the negative logit-scale value", {
  # Beta link is logit; mu = plogis(eta). The Fisher-pass surfaced
  # mu_hat = -0.95 in the displayed Beta widget. A Beta mean MUST be
  # in (0,1); plogis(-0.95) = 0.279 is the correct response-scale
  # value.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  ex  <- sym$expanded

  X <- ex$X
  beta <- ex$beta
  eta_1 <- as.numeric(X[1, ] %*% beta)
  mu_1_expected <- stats::plogis(eta_1)

  expect_equal(as.numeric(ex$mu_hat[[1L]]),
               mu_1_expected,
               tolerance = 1e-9)
  # Every mu_hat value must be a valid Beta mean in (0,1)
  expect_true(all(ex$mu_hat > 0 & ex$mu_hat < 1))
})

test_that("Lognormal fit: mu_hat is on log scale (E[log Y]), as Lognormal mu is canonically defined", {
  # drmTMB's Lognormal parameterises Y so log(Y) ~ Normal(mu, sigma^2).
  # The 'mu' here IS the mean of log(Y) -- identity link on mu, log
  # link on the response Y. So sym$expanded$mu_hat should equal
  # X*beta directly (identity link); the back-transformed response-
  # scale mean E[Y] = exp(mu + sigma^2/2) is a SEPARATE quantity that
  # belongs in its own slot if exposed. This test pins the canonical
  # Lognormal parameterisation -- mu_hat stays on log scale and equals
  # eta_hat.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_lognormal())
  sym <- symbolize(fit)
  ex  <- sym$expanded

  X <- ex$X
  beta <- ex$beta
  eta_1 <- as.numeric(X[1, ] %*% beta)

  expect_equal(as.numeric(ex$mu_hat[[1L]]),
               eta_1,
               tolerance = 1e-9)
  expect_equal(as.numeric(ex$eta_hat[[1L]]),
               eta_1,
               tolerance = 1e-9)
})

test_that("Gaussian identity link: mu_hat == eta_hat == X*beta (back-compat)", {
  # No regression on the existing Gaussian path. Identity link, so
  # the two slots are identical.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_location_scale())
  sym <- symbolize(fit)
  ex  <- sym$expanded

  expect_equal(unname(ex$mu_hat),
               unname(ex$eta_hat),
               tolerance = 1e-12)
  expect_equal(unname(as.numeric(ex$mu_hat)),
               unname(as.numeric(ex$X %*% ex$beta)),
               tolerance = 1e-12)
})
