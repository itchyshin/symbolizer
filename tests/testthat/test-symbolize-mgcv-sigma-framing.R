# Capability remediation mgcv: honest sigma_i FRAMING for a single-constant-
# scale mgcv Gamma fit. Audit: docs/dev-log/audits/2026-05-29-capability-
# reverify.md (mgcv MAJOR, second half).
#
# A single-phi mgcv Gamma fit (gam/bam) has ONE constant dispersion phi and NO
# dispersion submodel: there is no log-linked log(sigma_i) = gamma_0 + ... Z
# predictor and no Z design matrix. But mgcv reuses the shared drmTMB Gamma
# templates, which assume a drmTMB-style log-link DISPERSION SUBMODEL. Two
# framing problems result and are fixed here:
#   (1) the symbol dictionary glosses sigma_i as "Gamma dispersion (on the log
#       scale)" -- but mgcv reports phi DIRECTLY, not on the log scale; and
#   (2) the assumptions block emits a PHANTOM sigma submodel: a linear_predictor
#       row log(sigma_i) = gamma_0 + sum_k gamma_k Z_{ki} and a positivity row
#       describing gamma coefficients / a Z design matrix / a log link on the
#       dispersion that this fit does not have.
# Both must be honest for mgcv WITHOUT disturbing genuine drmTMB Gamma location-
# scale fits, whose dispersion submodel IS real and IS log-linked.

# ---- (1) sigma_i gloss is constant-scale honest (no "log scale") -----------

test_that("mgcv Gamma sigma_i gloss does not falsely say 'on the log scale'", {
  skip_if_not_installed("mgcv")
  set.seed(1L); n <- 150L; x <- runif(n); z <- runif(n)
  d <- data.frame(ygam = rgamma(n, shape = 4, rate = 4 / exp(1 + 0.7 * x)),
                  x = x, z = z)
  fit <- mgcv::gam(ygam ~ x + z, family = Gamma(), data = d, method = "REML")
  sym <- symbolize(fit)
  sd <- sym$symbol_dictionary
  # which() is NA-safe: the dictionary has a design-matrix row with symbol = NA.
  sig <- sd[which(sd$symbol == "\\sigma_i"), , drop = FALSE]
  expect_equal(nrow(sig), 1L)
  desc <- sig$description[[1L]]
  # The single-phi mgcv fit reports the dispersion directly, NOT on a log scale.
  expect_false(grepl("log scale", desc, ignore.case = TRUE),
               info = sprintf("sigma_i gloss still claims a log scale: %s", desc))
  # It should still name the Gamma dispersion / scale honestly.
  expect_match(desc, "Gamma dispersion|dispersion|scale", ignore.case = TRUE)
})

# ---- (2) no phantom sigma SUBMODEL in the assumptions ----------------------

test_that("mgcv Gamma assumptions carry NO phantom sigma dispersion submodel", {
  skip_if_not_installed("mgcv")
  set.seed(1L); n <- 150L; x <- runif(n); z <- runif(n)
  d <- data.frame(ygam = rgamma(n, shape = 4, rate = 4 / exp(1 + 0.7 * x)),
                  x = x, z = z)
  fit <- mgcv::gam(ygam ~ x + z, family = Gamma(), data = d, method = "REML")
  sym <- symbolize(fit)
  a <- sym$assumptions
  sigma_lp <- a[a$submodel == "sigma" & a$assumption == "linear_predictor",
                , drop = FALSE]
  expect_equal(nrow(sigma_lp), 0L,
               info = "single-phi mgcv fit has no log(sigma_i) = gamma_0 + ... Z submodel")
  # The phantom log-link positivity row (gamma coefficients / log link on the
  # dispersion) must also be gone for a constant-scale fit.
  sigma_any <- a[!is.na(a$submodel) & a$submodel == "sigma", , drop = FALSE]
  expect_equal(nrow(sigma_any), 0L,
               info = "no sigma-submodel assumption rows for a constant-phi mgcv fit")
  # The mu linear predictor (inverse link) must still be present and honest.
  mu_lp <- a[a$submodel == "mu" & a$assumption == "linear_predictor", , drop = FALSE]
  expect_equal(nrow(mu_lp), 1L)
  expect_match(mu_lp$expression_latex[[1L]], "\\\\frac\\{1\\}\\{\\\\mu_i\\}")
})

test_that("mgcv Gamma/log fit also drops the phantom sigma submodel", {
  skip_if_not_installed("mgcv")
  set.seed(1L); n <- 150L; x <- runif(n); z <- runif(n)
  d <- data.frame(ygam = rgamma(n, shape = 4, rate = 4 / exp(1 + 0.7 * x)),
                  x = x, z = z)
  fit <- mgcv::gam(ygam ~ x + z, family = Gamma(link = "log"), data = d,
                   method = "REML")
  sym <- symbolize(fit)
  a <- sym$assumptions
  expect_equal(nrow(a[!is.na(a$submodel) & a$submodel == "sigma", , drop = FALSE]), 0L)
})

# ---- (3) regression guard: drmTMB Gamma location-scale is UNAFFECTED -------

test_that("drmTMB Gamma location-scale STILL shows its real sigma submodel", {
  skip_if_not_installed("drmTMB")
  set.seed(20260524L); n <- 120L
  dat <- data.frame(y = rgamma(n, shape = 2, rate = 0.5), x = rnorm(n))
  # A GENUINELY varying dispersion submodel: sigma ~ x (log-linked).
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ x, sigma ~ x),
    family = stats::Gamma(link = "log"), data = dat
  )
  sym <- symbolize(fit)
  a <- sym$assumptions
  # The real dispersion submodel's linear predictor row must remain.
  sigma_lp <- a[a$submodel == "sigma" & a$assumption == "linear_predictor",
                , drop = FALSE]
  expect_equal(nrow(sigma_lp), 1L)
  expect_match(sigma_lp$expression_latex[[1L]],
               "\\\\log\\(\\\\sigma_i\\) = \\\\gamma_0")
  # Its log-link positivity row must remain too.
  sigma_pos <- a[a$submodel == "sigma" & a$assumption == "positivity",
                 , drop = FALSE]
  expect_equal(nrow(sigma_pos), 1L)
})

test_that("drmTMB Gamma with constant sigma submodel (sigma ~ 1) keeps its submodel", {
  skip_if_not_installed("drmTMB")
  set.seed(20260524L); n <- 80L
  dat <- data.frame(y = rgamma(n, shape = 2, rate = 0.5), x = rnorm(n))
  # sigma ~ 1 is still a REAL drmTMB dispersion submodel (log-linked intercept),
  # unlike mgcv's single phi -- it must keep its sigma rows.
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ x, sigma ~ 1),
    family = stats::Gamma(link = "log"), data = dat
  )
  sym <- symbolize(fit)
  a <- sym$assumptions
  expect_equal(
    nrow(a[a$submodel == "sigma" & a$assumption == "linear_predictor", , drop = FALSE]),
    1L
  )
  # And its sigma_i gloss keeps the drmTMB dispersion meaning (loop branch, from
  # family-parameterizations.csv scale_meaning -- unaffected by the mgcv path).
  sd <- sym$symbol_dictionary
  sig <- sd[which(sd$symbol == "\\sigma_i"), , drop = FALSE]
  expect_equal(nrow(sig), 1L)
  expect_match(sig$description[[1L]], "Gamma dispersion", ignore.case = TRUE)
})
