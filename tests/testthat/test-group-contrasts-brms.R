# group_contrasts() on a brms (brmsfit) factor model.
#
# brms fits with MCMC are slow to compile + sample, so this whole file is
# skipped on CRAN and when brms / emmeans are absent. We fit one tiny
# Gaussian model with a 3-level factor (`site`) and contrast its levels.
#
# STATUS (locked here as a regression guard): group_contrasts() is WIRED for
# brmsfit -- emmeans dispatches, the object comes back with the right class,
# the right number of rows, and (per VISION) NO p-value column. The point
# estimate is the posterior median of the level difference.
#
# KNOWN LIMITATION, also locked here: for a Bayesian fit emmeans reports the
# credible band in columns named `lower.HPD` / `upper.HPD`, NOT the frequentist
# `asymp.LCL` / `lower.CL` / `LCL` columns that marg_tibble_contrasts() looks
# for (R/marginal-estimates.R, marg_first_present() candidate lists). The HPD
# columns are therefore dropped and confint_low / confint_high come back NA.
# These tests pin that current behaviour so a future fix (teaching the column
# matcher about *.HPD) flips the documented expectation deliberately, not by
# accident. See the `confint columns are currently NA` test below.

skip_if_no_emmeans <- function() skip_if_not_installed("emmeans")

gc_brms_factor_fit <- function() {
  skip_if_not_installed("brms")
  skip_if_no_emmeans()
  skip_on_cran()
  set.seed(101L)
  n <- 90L
  site <- factor(rep(c("A", "B", "C"), length.out = n))
  mu_by_site <- c(A = 0, B = 1.2, C = -0.8)[as.character(site)]
  y <- rnorm(n, 5 + mu_by_site, 1.0)
  dat <- data.frame(y = y, site = site)
  fit <- suppressMessages(suppressWarnings(brms::brm(
    y ~ site,
    data = dat,
    family = stats::gaussian(),
    chains = 1, iter = 300, warmup = 150,
    refresh = 0, silent = 2, seed = 101L
  )))
  symbolize(fit)
}

test_that("group_contrasts() on a brms factor returns a wired result", {
  sym <- gc_brms_factor_fit()
  gc <- group_contrasts(sym, by = "site")
  expect_s3_class(gc, "symbolizer_group_contrasts")
  # 3-level factor, pairwise -> one row per pair.
  expect_equal(nrow(gc), 3L)
  expect_setequal(gc$contrast, c("A - B", "A - C", "B - C"))
  expect_true(all(is.finite(gc$estimate)))
})

test_that("group_contrasts() on a brms fit reports no p-value", {
  sym <- gc_brms_factor_fit()
  gc <- group_contrasts(sym, by = "site")
  expect_false("p.value" %in% names(gc))
  expect_false("t.ratio" %in% names(gc))
})

test_that("brms credible band is carried through (HPD columns matched)", {
  # marg_tibble_contrasts() historically recognised only the
  # frequentist CI column names. It now also matches the Bayesian
  # `lower.HPD` / `upper.HPD` band emmeans reports for brms, so the credible
  # interval is carried through to confint_low / confint_high.
  sym <- gc_brms_factor_fit()
  gc <- group_contrasts(sym, by = "site")
  expect_true(all(is.finite(gc$confint_low)))
  expect_true(all(is.finite(gc$confint_high)))
})
