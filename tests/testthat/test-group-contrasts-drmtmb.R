# Tests for group_contrasts() on a drmTMB fit with a multi-level factor.
# Locks the finding that emmeans::contrast() works on drmTMB objects and
# that the symbolizer wrapper produces a CI-only (no-p-value) result.

gc_drm_factor_fit <- function(seed = 42L, n = 90L) {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(seed)
  site <- factor(rep(c("A", "B", "C"), length.out = n))
  mu_site <- c(A = 30, B = 33, C = 27)[as.character(site)]
  dat <- data.frame(y = rnorm(n, mu_site, 2), site = site)
  drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ site, sigma ~ 1),
    family = stats::gaussian(),
    data   = dat
  )
}

test_that("group_contrasts on a 3-level factor returns one row per pair", {
  skip_if_not_installed("drmTMB")
  skip_if_not_installed("emmeans")
  sym <- symbolize(gc_drm_factor_fit())
  gc <- group_contrasts(sym, by = "site")
  expect_s3_class(gc, "symbolizer_group_contrasts")
  expect_equal(nrow(gc), 3L)
  expect_setequal(gc$contrast, c("A - B", "A - C", "B - C"))
})

test_that("group_contrasts on drmTMB never emits a p-value column", {
  skip_if_not_installed("drmTMB")
  skip_if_not_installed("emmeans")
  sym <- symbolize(gc_drm_factor_fit())
  gc <- group_contrasts(sym, by = "site")
  expect_false("p.value" %in% names(gc))
  expect_false("t.ratio" %in% names(gc))
})

test_that("group_contrasts on drmTMB reports finite confidence bands", {
  skip_if_not_installed("drmTMB")
  skip_if_not_installed("emmeans")
  sym <- symbolize(gc_drm_factor_fit())
  gc <- group_contrasts(sym, by = "site")
  expect_true(all(is.finite(gc$confint_low)))
  expect_true(all(is.finite(gc$confint_high)))
  expect_true(all(gc$confint_high >= gc$confint_low))
})
