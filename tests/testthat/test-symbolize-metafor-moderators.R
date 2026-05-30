# Capability remediation: metafor moderator formula fidelity.
# Audit: docs/dev-log/audits/2026-05-29-capability-reverify.md (metafor section).
#
# Root cause: symbolize.rma.uni / .rma.mv reconstructed the moderator formula
# from fit$beta dummy row-names (intrcpt, gb, gc) instead of the original
# fit$formula.mods (~g). That (a) CRASHED on factor moderators ("object 'gb'
# not found"), (b) mis-rendered rma.mv factor moderators as continuous
# predictors, and (c) injected a phantom intercept on no-intercept (~x - 1)
# formulas. The fix uses fit$formula.mods + fit$data and maps factor-contrast
# terms to metafor's model.matrix beta names (paste0(variable, level)).

test_that("rma.uni factor moderator symbolizes without crashing (BLOCKER)", {
  skip_if_not_installed("metafor")
  set.seed(1L); k <- 18L
  g <- factor(rep(c("a", "b", "c"), length.out = k))
  d <- data.frame(yi = rnorm(k, 0.2, 0.3), vi = runif(k, 0.02, 0.08), g = g)
  fit <- metafor::rma(yi, vi, mods = ~ g, data = d)

  expect_no_error(sym <- symbolize(fit))
  fe <- sym$fixed_effects
  # g must render as factor contrasts, not as predictors named "gb"/"gc".
  contr <- fe[!is.na(fe$role) & fe$role == "factor_contrast", , drop = FALSE]
  expect_true(all(contr$variable == "g"))
  expect_setequal(contr$contrast_level, c("b", "c"))
  # Estimates must map to fit$beta (gb, gc), not be NA.
  expect_true(all(is.finite(contr$estimate)))
  gb <- fe$estimate[!is.na(fe$contrast_level) & fe$contrast_level == "b"][[1L]]
  expect_equal(gb, as.numeric(fit$beta["gb", 1L]), tolerance = 1e-6)
})

test_that("rma.mv factor moderator renders as a contrast, not a continuous predictor (MAJOR)", {
  skip_if_not_installed("metafor")
  set.seed(2L); k <- 18L
  g2 <- factor(rep(c("x", "y"), length.out = k))
  trial <- factor(rep(1:9, length.out = k))
  d <- data.frame(yi = rnorm(k, 0.3, 0.3), vi = runif(k, 0.02, 0.08),
                  g2 = g2, trial = trial)
  fit <- metafor::rma.mv(yi, vi, mods = ~ g2, random = ~ 1 | trial, data = d)

  sym <- symbolize(fit)
  fe <- sym$fixed_effects
  g2row <- fe[!is.na(fe$variable) & fe$variable == "g2", , drop = FALSE]
  expect_true(nrow(g2row) >= 1L)
  expect_true(all(g2row$role == "factor_contrast"))   # not "predictor"
  expect_equal(g2row$contrast_level[[1L]], "y")
  expect_true(all(is.finite(g2row$estimate)))
})

test_that("no-intercept moderator formula injects no phantom intercept (MAJOR)", {
  skip_if_not_installed("metafor")
  set.seed(3L); k <- 18L
  d <- data.frame(yi = rnorm(k, 0.2, 0.3), vi = runif(k, 0.02, 0.08),
                  xn = rnorm(k))
  fit <- metafor::rma(yi, vi, mods = ~ xn - 1, data = d)

  sym <- symbolize(fit)
  fe <- sym$fixed_effects
  # The model has no intercept, so there must be no (Intercept) row at all
  # (previously a phantom beta_0 with NA estimate was injected).
  expect_false(any(fe$term_label == "(Intercept)", na.rm = TRUE))
  expect_false(any(!is.na(fe$role) & fe$role == "intercept"))
  # The real slope maps to fit$beta["xn", ].
  xn_est <- fe$estimate[!is.na(fe$variable) & fe$variable == "xn"][[1L]]
  expect_equal(xn_est, as.numeric(fit$beta["xn", 1L]), tolerance = 1e-6)
  expect_true(all(is.finite(fe$estimate)))   # no NA-estimate phantom rows
})
