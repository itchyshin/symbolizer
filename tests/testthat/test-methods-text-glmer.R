# Tests for methods_text() on lme4 glmer (glmerMod) fits.
#
# Regression for the renderer-coverage gap: methods_text() shipped a
# template for lmerMod / gaussian but NONE for glmerMod, so it hard-errored
# on the glmer poisson / binomial families the capability registry
# advertises as "First slice".

fit_glmer_poisson_mt <- function(seed = 1L, n = 200L, n_groups = 20L) {
  testthat::skip_if_not_installed("lme4")
  set.seed(seed)
  g <- factor(rep(seq_len(n_groups), each = n / n_groups))
  x <- runif(n)
  dat <- data.frame(y = rpois(n, exp(0.4 + 0.6 * x)), x = x, g = g)
  suppressWarnings(suppressMessages(lme4::glmer(
    y ~ x + (1 | g), data = dat, family = stats::poisson()
  )))
}

fit_glmer_binomial_mt <- function(seed = 1L, n = 200L, n_groups = 20L) {
  testthat::skip_if_not_installed("lme4")
  set.seed(seed)
  g <- factor(rep(seq_len(n_groups), each = n / n_groups))
  x <- runif(n)
  dat <- data.frame(y = rbinom(n, 1, plogis(-0.3 + 0.8 * x)), x = x, g = g)
  suppressWarnings(suppressMessages(lme4::glmer(
    y ~ x + (1 | g), data = dat, family = stats::binomial()
  )))
}

test_that("methods_text runs for a glmer poisson fit and reads link-honest", {
  sym <- symbolize(fit_glmer_poisson_mt())
  expect_no_error(mt <- methods_text(sym))
  expect_s3_class(mt, "symbolizer_methods_text")
  # Poisson: log link / rate ratio / variance = mean.
  expect_match(mt$text, "Poisson", fixed = TRUE)
  expect_match(mt$text, "log", fixed = TRUE)
  expect_match(mt$text, "rate ratio", fixed = TRUE)
  expect_match(mt$text, "variance", fixed = TRUE)
  # Core slots resolve (no leftover [unfilled: ...] markers).
  expect_false(grepl("[unfilled:", mt$text, fixed = TRUE))
  expect_match(mt$text, "y", fixed = TRUE)
  expect_match(mt$text, "x", fixed = TRUE)
  expect_match(mt$text, "200", fixed = TRUE)
  expect_match(mt$text, "lme4", fixed = TRUE)
  # Random-intercept clause for (1 | g).
  expect_match(mt$text, "random intercept", fixed = TRUE)
  expect_match(mt$text, "g", fixed = TRUE)
})

test_that("methods_text runs for a glmer binomial fit and reads link-honest", {
  sym <- symbolize(fit_glmer_binomial_mt())
  expect_no_error(mt <- methods_text(sym))
  expect_s3_class(mt, "symbolizer_methods_text")
  # Binomial: logit link / odds ratio.
  expect_match(mt$text, "logit", fixed = TRUE)
  expect_match(mt$text, "odds ratio", fixed = TRUE)
  # No leftover unfilled placeholders.
  expect_false(grepl("[unfilled:", mt$text, fixed = TRUE))
  expect_match(mt$text, "200", fixed = TRUE)
  expect_match(mt$text, "lme4", fixed = TRUE)
  # Random-intercept clause for (1 | g).
  expect_match(mt$text, "random intercept", fixed = TRUE)
})
