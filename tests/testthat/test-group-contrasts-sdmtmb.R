# group_contrasts() on a sdmTMB fit with a multi-level factor predictor.
#
# emmeans dispatches to sdmTMB's own emmeans support, so group_contrasts()
# yields pairwise factor-level contrasts with confidence bands and -- per the
# VISION light-touch-uncertainty rule -- NO p-values. This fit is slow (it
# needs a SPDE mesh), hence skip_on_cran().

skip_if_no_emmeans <- function() skip_if_not_installed("emmeans")

# A small Gaussian spatial fit whose only fixed effect is a 3-level factor.
gc_sdmtmb_factor_fit <- function(seed = 1L, n = 200L) {
  skip_if_not_installed("sdmTMB")
  set.seed(seed)
  dat <- data.frame(x = runif(n), y_loc = runif(n))
  dat$grp <- factor(rep(c("A", "B", "C"), length.out = n))
  beta <- c(A = 0, B = 0.8, C = -0.5)
  dat$obs <- 2 + beta[as.character(dat$grp)] + rnorm(n, 0, 1)
  mesh <- sdmTMB::make_mesh(dat, c("x", "y_loc"), cutoff = 0.1)
  suppressWarnings(sdmTMB::sdmTMB(
    obs ~ grp, data = dat, mesh = mesh,
    family = stats::gaussian(), spatial = "on"
  ))
}

test_that("pairwise contrasts on a 3-level factor work for a sdmTMB fit", {
  skip_on_cran()
  skip_if_not_installed("sdmTMB")
  skip_if_no_emmeans()
  sym <- symbolize(gc_sdmtmb_factor_fit())
  gc <- group_contrasts(sym, by = "grp")
  expect_s3_class(gc, "symbolizer_group_contrasts")
  expect_equal(nrow(gc), 3L)
  expect_setequal(gc$contrast, c("A - B", "A - C", "B - C"))
  expect_true(all(is.finite(gc$confint_low)))
  expect_true(all(is.finite(gc$confint_high)))
})

test_that("no p-value column is produced for a sdmTMB contrast", {
  skip_on_cran()
  skip_if_not_installed("sdmTMB")
  skip_if_no_emmeans()
  sym <- symbolize(gc_sdmtmb_factor_fit())
  gc <- group_contrasts(sym, by = "grp")
  expect_false("p.value" %in% names(gc))
  expect_false("t.ratio" %in% names(gc))
})
