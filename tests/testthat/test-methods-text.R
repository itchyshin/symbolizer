test_that("methods_text errors on non-symbolized input", {
  expect_error(methods_text(list()), "has no method")
})

test_that("methods_text returns a symbolizer_methods_text S3 with the expected slots", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i"),
                   units = c(body_mass = "g"))
  mt <- methods_text(sym)
  expect_s3_class(mt, "symbolizer_methods_text")
  expect_named(mt, c("text", "slots", "reminders"))
  expect_type(mt$text, "character")
  expect_length(mt$text, 1L)
})

test_that("methods_text for drmTMB gaussian substitutes response, predictors, n_obs, ci_method", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i"),
                   units = c(body_mass = "g"))
  mt <- methods_text(sym)
  expect_match(mt$text, "Gaussian location-scale model", fixed = TRUE)
  expect_match(mt$text, "body_mass",  fixed = TRUE)
  expect_match(mt$text, "temperature", fixed = TRUE)
  # n_obs from the helper is 80:
  expect_match(mt$text, "80 observations", fixed = TRUE)
  # Default ci_method is Wald:
  expect_match(mt$text, "Wald confidence intervals", fixed = TRUE)
  # Units clause:
  expect_match(mt$text, "units: g", fixed = TRUE)
})

test_that("methods_text for drmTMB gaussian without units omits the units clause", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)  # no units= argument
  mt <- methods_text(sym)
  # No "units:" should appear in the text:
  expect_false(grepl("units:", mt$text, fixed = TRUE))
})

test_that("methods_text mentions random effects when present", {
  fit_re <- fit_drm_with_re()
  sym <- symbolize(fit_re)
  mt <- methods_text(sym)
  expect_match(mt$text, "random intercept", fixed = TRUE)
  expect_match(mt$text, "group", fixed = TRUE)
  expect_match(mt$text, "was included in the model", fixed = TRUE)
  # And the reminders block calls it out:
  expect_true(any(grepl("Random-effect", mt$reminders, fixed = TRUE)))
})

test_that("methods_text for (1 + x | g) mentions both intercept and slope with the right verb agreement", {
  set.seed(20260524); n <- 200; n_g <- 8
  g <- factor(rep(letters[1:n_g], length.out = n))
  x <- rnorm(n)
  dat <- data.frame(
    y = 5 + 0.5 * x + rnorm(n_g, sd = 1.5)[g] + rnorm(n_g, sd = 0.4)[g] * x + rnorm(n),
    x = x, g = g
  )
  fit <- drmTMB::drmTMB(drmTMB::drm_formula(y ~ x + (1 + x | g), sigma ~ 1),
                        family = stats::gaussian(), data = dat)
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  # The polished clause names both pieces and uses plural "were":
  expect_match(mt$text, "random intercept and a random slope on .x.", fixed = FALSE)
  expect_match(mt$text, "were included in the model",                 fixed = TRUE)
  expect_false(grepl("on `x` for `g` was",  mt$text, fixed = TRUE))
})

test_that("methods_text for drmTMB biv_gaussian mentions both responses and rho12", {
  fit_bv <- fit_drm_biv_gaussian()
  sym <- symbolize(fit_bv)
  mt <- methods_text(sym)
  expect_match(mt$text, "bivariate Gaussian", fixed = TRUE)
  expect_match(mt$text, "y1", fixed = TRUE)
  expect_match(mt$text, "y2", fixed = TRUE)
  expect_match(mt$text, "Fisher-z", fixed = TRUE)
  # No bare "(an intercept only; an intercept only)" — the polished pair-clause
  # collapses it to "both intercept-only" when neither sigma submodel has
  # predictors. This protects against accidental regression to the awkward
  # parenthesised wording.
  expect_false(grepl("an intercept only;", mt$text, fixed = TRUE))
  expect_match(mt$text, "both intercept-only", fixed = TRUE)
})

test_that("biv_gaussian methods_text with non-trivial sigma predictors uses the predictor wording", {
  set.seed(20260524); n <- 80
  e1 <- rnorm(n); e2 <- 0.6 * e1 + sqrt(1 - 0.6^2) * rnorm(n)
  dat <- data.frame(
    y1 = 30 + 1.5 * rnorm(n) + e1,
    y2 = 10 + 0.8 * rnorm(n) + e2,
    x1 = rnorm(n), x2 = rnorm(n)
  )
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(mu1 = y1 ~ x1, mu2 = y2 ~ x2,
                        sigma1 = ~ x1, sigma2 = ~ x2, rho12 = ~ 1),
    family = drmTMB::biv_gaussian(), data = dat
  )
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  expect_match(mt$text, "the first scale a function of",  fixed = TRUE)
  expect_match(mt$text, "the second a function of",       fixed = TRUE)
  # rho12 is intercept-only here -> "with an intercept only on the Fisher-z..."
  expect_match(mt$text, "with an intercept only on the Fisher-z", fixed = TRUE)
})

test_that("methods_text errors with a friendly message on an unsupported class/family combo", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  # Fake a model class we don't ship a template for.
  sym$model$class  <- "unknown_engine"
  sym$model$family <- "unknown_family"
  expect_error(
    methods_text(sym),
    "No .*methods_text.* template"
  )
})

test_that("unfilled placeholders are flagged in the text, not silently dropped", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  # Inject a fake template via the cache. Easier and more honest test: call
  # methods_substitute() directly.
  out <- symbolizer:::methods_substitute(
    "We tested {real_slot} and {missing_slot} both.",
    list(real_slot = "X")
  )
  expect_match(out, "X", fixed = TRUE)
  expect_match(out, "[unfilled: missing_slot]", fixed = TRUE)
})

test_that("print.symbolizer_methods_text emits the text and the reminders", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  msgs <- testthat::capture_messages(print(mt))
  out <- paste(msgs, collapse = "")
  expect_match(out, "Methods text \\(draft\\)")
  expect_match(out, "Reminders before you paste")
})

test_that("knit_print.symbolizer_methods_text returns knit_asis with text + reminders", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  kp <- knitr::knit_print(mt)
  expect_s3_class(kp, "knit_asis")
  s <- as.character(kp)
  expect_match(s, "Gaussian location-scale", fixed = TRUE)
  expect_match(s, "*Reminders:*", fixed = TRUE)
})
