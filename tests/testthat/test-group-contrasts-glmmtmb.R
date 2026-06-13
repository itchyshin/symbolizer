# group_contrasts() on a glmmTMB fit with a multi-level factor.
# emmeans ships a glmmTMB method, so the wrapper works end-to-end; this
# test locks the contract (CIs, no p-values, finite bands) for that class.

gc_glmmtmb_fit <- function() {
  testthat::skip_if_not_installed("glmmTMB")
  suppressPackageStartupMessages(
    suppressWarnings(requireNamespace("glmmTMB", quietly = TRUE))
  )
  set.seed(42)
  n <- 90L
  site <- factor(rep(c("A", "B", "C"), length.out = n))
  count <- rpois(n, lambda = c(A = 3, B = 5, C = 8)[as.character(site)])
  dat <- data.frame(count = count, site = site)
  fit <- suppressWarnings(glmmTMB::glmmTMB(
    count ~ site, data = dat, family = stats::poisson()
  ))
  symbolize(fit)
}

test_that("group_contrasts works for a glmmTMB fit with a 3-level factor", {
  skip_if_not_installed("glmmTMB")
  skip_if_not_installed("emmeans")
  sym <- gc_glmmtmb_fit()
  gc <- group_contrasts(sym, by = "site")
  expect_s3_class(gc, "symbolizer_group_contrasts")
  expect_true(nrow(gc) >= 1L)
  expect_equal(nrow(gc), 3L)
  # Poisson is log-link, so response-scale contrasts are ratios ("A / B").
  expect_setequal(gc$contrast, c("A / B", "A / C", "B / C"))
  expect_equal(unique(gc$effect_type), "ratio")
  expect_false("p.value" %in% names(gc))
  expect_false("t.ratio" %in% names(gc))
  expect_true(all(is.finite(gc$confint_low)))
  expect_true(all(is.finite(gc$confint_high)))
})
