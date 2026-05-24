# Four non-Gaussian families added in v0.3 via the family-distributions CSV
# refactor. The tests confirm each family's distribution row, biological
# reading on the mean, methods_text language, and capability status.

# --- Gamma -------------------------------------------------------------------

test_that("Gamma fit symbolizes end-to-end with a multiplicative-mean reading", {
  fit <- fit_drm_gamma()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$family, "Gamma")
  expect_match(sym$distribution$latex, "Gamma", fixed = TRUE)
  expect_match(sym$distribution$latex, "shape", fixed = TRUE)
  mu_rows <- sym$interpretation[sym$interpretation$submodel == "mu", , drop = FALSE]
  expect_true(any(grepl("multiplies the mean", mu_rows$biological_reading,
                         fixed = TRUE)))
})

test_that("Gamma methods_text uses log-link / multiplicative language", {
  fit <- fit_drm_gamma()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  expect_match(mt$text, "Gamma generalised linear model", fixed = TRUE)
  expect_match(mt$text, "log link",   fixed = TRUE)
  expect_match(mt$text, "exp(beta)",  fixed = TRUE)
})

# --- Beta --------------------------------------------------------------------

test_that("Beta fit symbolizes end-to-end with a logit-scale / odds reading", {
  fit <- fit_drm_beta()
  sym <- symbolize(fit)
  expect_equal(sym$model$family, "beta")
  expect_match(sym$distribution$latex, "Beta", fixed = TRUE)
  mu_rows <- sym$interpretation[sym$interpretation$submodel == "mu", , drop = FALSE]
  # The biological reading on mu mentions either odds or logit
  # (intercept reading uses plogis() / "proportion"; slope reading uses
  # "odds"; factor_contrast uses "odds"). All readings should reference
  # the (0, 1) world.
  expect_true(any(grepl("plogis|odds|proportion",
                        mu_rows$biological_reading)))
})

test_that("Beta methods_text uses logit / odds-ratio language", {
  fit <- fit_drm_beta()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  expect_match(mt$text, "Beta regression",  fixed = TRUE)
  expect_match(mt$text, "(0, 1)",           fixed = TRUE)
  expect_match(mt$text, "logit link",       fixed = TRUE)
  expect_match(mt$text, "odds ratio",       fixed = TRUE)
})

# --- Poisson -----------------------------------------------------------------

test_that("Poisson fit symbolizes with only a mu submodel", {
  fit <- fit_drm_poisson()
  sym <- symbolize(fit)
  expect_equal(sym$model$family, "poisson")
  expect_equal(unique(sym$submodels$parameter), "mu")
  # No sigma in the interpretation rows:
  expect_false("sigma" %in% sym$interpretation$submodel)
})

test_that("Poisson interpretation uses rate-ratio / log-count language", {
  fit <- fit_drm_poisson()
  sym <- symbolize(fit)
  mu_rows <- sym$interpretation[sym$interpretation$submodel == "mu", , drop = FALSE]
  expect_true(any(grepl("multiplies the expected count",
                        mu_rows$biological_reading, fixed = TRUE)))
})

test_that("Poisson methods_text calls out variance = mean and uses log-link / rate-ratio language", {
  fit <- fit_drm_poisson()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  expect_match(mt$text, "Poisson regression", fixed = TRUE)
  expect_match(mt$text, "no dispersion parameter", fixed = TRUE)
  expect_match(mt$text, "variance is constrained equal to the mean", fixed = TRUE)
  expect_match(mt$text, "rate ratio",       fixed = TRUE)
  # No sigma clause should appear or be left as [unfilled]:
  expect_false(grepl("[unfilled:", mt$text, fixed = TRUE))
})

# --- Negative binomial (nbinom2) --------------------------------------------

test_that("nbinom2 fit symbolizes with mu and sigma submodels", {
  fit <- fit_drm_nbinom2()
  sym <- symbolize(fit)
  expect_equal(sym$model$family, "nbinom2")
  expect_setequal(unique(sym$submodels$parameter), c("mu", "sigma"))
  expect_match(sym$distribution$latex, "NegBin", fixed = TRUE)
  expect_match(sym$distribution$latex, "size",   fixed = TRUE)
})

test_that("nbinom2 methods_text contrasts size / overdispersion against Poisson", {
  fit <- fit_drm_nbinom2()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  expect_match(mt$text, "negative binomial",    fixed = TRUE)
  expect_match(mt$text, "overdispersion",       fixed = TRUE)
  expect_match(mt$text, "approach Poisson",     fixed = TRUE)
  expect_false(grepl("[unfilled:", mt$text, fixed = TRUE))
})

# --- Capability registry ---------------------------------------------------

test_that("New families are First slice in the capability registry", {
  caps <- symbolizer_capabilities()
  for (fam in c("Gamma", "beta", "poisson", "nbinom2")) {
    rows <- caps[caps$class == "drmTMB" & caps$family == fam, ]
    expect_true(nrow(rows) >= 1L,
                info = sprintf("no capability rows for drmTMB / %s", fam))
    expect_true(all(rows$status == "First slice"),
                info = sprintf("not all First slice for drmTMB / %s", fam))
  }
})
