# variance-components surface, Slice 2 (accessors).
# Spec: docs/specs/variance-components.md (S2 — accessors).
#
# variance_partition(x): one row per variance source (component, variance,
#   sd, pct). Includes a residual row when the residual variance is known, so
#   pct sums to 1; otherwise pct = NA with a reason.
# icc(x): the intraclass correlation with an explicit `scale` attribute
#   ("data" for Gaussian-identity, "latent" for binomial logit/probit), a
#   mandatory latent caption, and an honest NA + reason when the quantity is
#   not defined (Poisson / other GLMM, location-scale Gaussian, >1 RE term).

# ---- generics dispatch -------------------------------------------------------

test_that("variance_partition / icc error on non-symbolized input", {
  expect_error(variance_partition(list()), "no method")
  expect_error(icc(list()), "no method")
})

# ---- Gaussian data-scale ICC -------------------------------------------------

test_that("Gaussian ICC is the between-group proportion; partition sums to 1", {
  skip_if_not_installed("lme4")
  fit <- suppressWarnings(lme4::lmer(
    Reaction ~ Days + (1 | Subject), data = lme4::sleepstudy))
  sym <- symbolize(fit)

  vp <- variance_partition(sym)
  expect_true(all(c("component", "variance", "sd", "pct") %in% names(vp)))
  expect_true(all(is.finite(vp$variance)))
  expect_equal(sum(vp$pct), 1, tolerance = 1e-6)

  ic <- icc(sym)
  expect_equal(attr(ic, "scale"), "data")
  s2_g   <- sym$variance_components$var_estimate[[1L]]
  s2_eps <- stats::sigma(fit)^2
  expect_equal(as.numeric(ic), s2_g / (s2_g + s2_eps), tolerance = 1e-6)
  expect_gt(as.numeric(ic), 0)
  expect_lt(as.numeric(ic), 1)
})

# ---- binomial latent-scale ICC ----------------------------------------------

test_that("binomial logit ICC uses the pi^2/3 latent residual", {
  skip_if_not_installed("lme4")
  fit <- suppressWarnings(lme4::glmer(
    cbind(incidence, size - incidence) ~ period + (1 | herd),
    data = lme4::cbpp, family = binomial))
  sym <- symbolize(fit)

  ic <- icc(sym)
  s2 <- sym$variance_components$var_estimate[[1L]]
  expect_equal(as.numeric(ic), s2 / (s2 + pi^2 / 3), tolerance = 1e-6)
  expect_equal(attr(ic, "scale"), "latent")
  expect_match(attr(ic, "caption"),
               "not a proportion of variance in the observed outcome",
               ignore.case = TRUE)
})

test_that("binomial probit ICC uses residual variance 1", {
  skip_if_not_installed("lme4")
  fit <- suppressWarnings(lme4::glmer(
    cbind(incidence, size - incidence) ~ period + (1 | herd),
    data = lme4::cbpp, family = binomial(link = "probit")))
  sym <- symbolize(fit)

  ic <- icc(sym)
  s2 <- sym$variance_components$var_estimate[[1L]]
  expect_equal(as.numeric(ic), s2 / (s2 + 1), tolerance = 1e-6)
  expect_equal(attr(ic, "scale"), "latent")
})

# ---- honesty refusals --------------------------------------------------------

test_that("Poisson ICC is refused with a family reason; the table still shows", {
  skip_if_not_installed("lme4")
  d <- lme4::cbpp
  set.seed(1L)
  d$cnt <- stats::rpois(nrow(d), 3)
  fit <- suppressWarnings(lme4::glmer(
    cnt ~ period + (1 | herd), data = d, family = poisson))
  sym <- symbolize(fit)

  ic <- icc(sym)
  expect_true(is.na(as.numeric(ic)))
  expect_match(attr(ic, "reason"), "poisson", ignore.case = TRUE)

  vp <- variance_partition(sym)
  expect_true(nrow(vp) >= 1L)
  expect_true(any(is.finite(vp$variance)))
})

test_that("more than one random-effect term refuses the single-number ICC", {
  skip_if_not_installed("lme4")
  fit <- suppressWarnings(lme4::lmer(
    Reaction ~ Days + (Days | Subject), data = lme4::sleepstudy))
  ic <- icc(symbolize(fit))
  expect_true(is.na(as.numeric(ic)))
  expect_match(attr(ic, "reason"), "more than one random-effect",
               ignore.case = TRUE)
})

test_that("drmTMB location-scale fit refuses ICC (no single within-group variance)", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_with_re())
  sym <- symbolize(fit)

  ic <- icc(sym)
  expect_true(is.na(as.numeric(ic)))
  expect_match(attr(ic, "reason"), "location-scale|varies", ignore.case = TRUE)
})

test_that("drmTMB homoscedastic random intercept yields a data-scale ICC", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_re_homosked())
  sym <- symbolize(fit)

  ic <- icc(sym)
  expect_equal(attr(ic, "scale"), "data")
  expect_true(is.finite(as.numeric(ic)))
  expect_gt(as.numeric(ic), 0)
  expect_lt(as.numeric(ic), 1)

  vp <- variance_partition(sym)
  expect_equal(sum(vp$pct), 1, tolerance = 1e-6)
})

# ---- honest print ------------------------------------------------------------

test_that("variance_partition prints a where-the-variation-lives section", {
  skip_if_not_installed("lme4")
  fit <- suppressWarnings(lme4::lmer(
    Reaction ~ Days + (1 | Subject), data = lme4::sleepstudy))
  vp <- variance_partition(symbolize(fit))
  txt <- paste(c(
    utils::capture.output(print(vp), type = "output"),
    utils::capture.output(print(vp), type = "message")
  ), collapse = "\n")
  expect_match(txt, "variation|between|within", ignore.case = TRUE)
})

test_that("icc prints its value and the mandatory latent caption for binomial", {
  skip_if_not_installed("lme4")
  fit <- suppressWarnings(lme4::glmer(
    cbind(incidence, size - incidence) ~ period + (1 | herd),
    data = lme4::cbpp, family = binomial))
  ic <- icc(symbolize(fit))
  txt <- paste(c(
    utils::capture.output(print(ic), type = "output"),
    utils::capture.output(print(ic), type = "message")
  ), collapse = "\n")
  expect_match(txt, "ICC", ignore.case = TRUE)
  expect_match(txt, "observed outcome", ignore.case = TRUE)
})
