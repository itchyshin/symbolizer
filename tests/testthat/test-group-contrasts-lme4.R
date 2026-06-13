# group_contrasts() on an lme4 (lmerMod) fit with a multi-level factor.
# emmeans ships an lmerMod method, so the wrapper works end-to-end; this
# test locks the contract (CIs, no p-values, finite bands) for that class.

gc_lmer_fit <- function() {
  testthat::skip_if_not_installed("lme4")
  set.seed(1)
  n <- 90L
  site <- factor(rep(c("A", "B", "C"), length.out = n))
  g <- factor(rep(seq_len(10L), length.out = n))
  g_eff <- rnorm(10, 0, 1.5)[as.integer(g)]
  site_eff <- c(A = 0, B = 1.2, C = -0.8)[as.character(site)]
  y <- rnorm(n, 5 + site_eff + g_eff, 1.0)
  dat <- data.frame(y = y, site = site, g = g)
  fit <- suppressWarnings(suppressMessages(
    lme4::lmer(y ~ site + (1 | g), data = dat)
  ))
  symbolize(fit)
}

test_that("group_contrasts works for an lme4 fit with a 3-level factor", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("emmeans")
  sym <- gc_lmer_fit()
  gc <- group_contrasts(sym, by = "site")
  expect_s3_class(gc, "symbolizer_group_contrasts")
  expect_true(nrow(gc) >= 1L)
  expect_equal(nrow(gc), 3L)
  expect_setequal(gc$contrast, c("A - B", "A - C", "B - C"))
  expect_false("p.value" %in% names(gc))
  expect_false("t.ratio" %in% names(gc))
  expect_true(all(is.finite(gc$confint_low)))
  expect_true(all(is.finite(gc$confint_high)))
})
