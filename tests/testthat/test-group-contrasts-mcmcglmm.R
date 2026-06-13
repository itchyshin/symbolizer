# group_contrasts() on MCMCglmm fits: fully wired.
#
# emmeans ships native MCMCglmm support (recover_data.MCMCglmm +
# emm_basis.MCMCglmm). Two pieces make it work end to end through symbolizer:
#   1. symbolize.MCMCglmm now retains the model frame on `metadata$data`, and
#      the group_* wrappers forward it via emmeans(..., data = metadata$data),
#      so recover_data.MCMCglmm has the frame it needs.
#   2. marg_tibble_contrasts() recognises the Bayesian credible-band columns
#      `lower.HPD` / `upper.HPD` (MCMCglmm reports no `SE`), so confint_low /
#      confint_high come back finite rather than NA.

skip_if_no_emmeans <- function() skip_if_not_installed("emmeans")

gc_mcmcglmm_factor_fit <- function(seed = 101L, n = 90L) {
  skip_if_not_installed("MCMCglmm")
  set.seed(seed)
  site <- factor(rep(c("A", "B", "C"), length.out = n))
  mu <- c(A = 0, B = 1.5, C = -1)[as.character(site)]
  dat <- data.frame(y = rnorm(n, mu, 1), site = site)
  fit <- suppressWarnings(suppressMessages(MCMCglmm::MCMCglmm(
    y ~ site, data = dat, family = "gaussian",
    nitt = 1500, burnin = 500, thin = 2, verbose = FALSE
  )))
  list(fit = fit, data = dat)
}

test_that("group_contrasts() works on MCMCglmm with finite credible bands", {
  skip_on_cran()
  skip_if_no_emmeans()
  bundle <- gc_mcmcglmm_factor_fit()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_true("site" %in% symbolizer:::marg_factors(sym))
  # data is retained on metadata$data and forwarded to emmeans, so
  # recover_data.MCMCglmm succeeds; the HPD band is carried through.
  gc <- group_contrasts(sym, by = "site")
  expect_s3_class(gc, "symbolizer_group_contrasts")
  expect_equal(nrow(gc), 3L)
  expect_false("p.value" %in% names(gc))
  expect_true(all(is.finite(gc$confint_low)))
  expect_true(all(is.finite(gc$confint_high)))
})

test_that("the emmeans contrast pipeline itself works once data is forwarded", {
  # Characterises the gate: emmeans supports MCMCglmm natively, so the
  # only thing standing between symbolizer and a working contrast is
  # forwarding `data` and recognising the *.HPD band columns.
  skip_on_cran()
  skip_if_no_emmeans()
  bundle <- gc_mcmcglmm_factor_fit()
  emm <- emmeans::emmeans(bundle$fit, ~ site, data = bundle$data)
  ctr <- emmeans::contrast(emm, method = "pairwise", adjust = "none")
  df <- as.data.frame(summary(ctr, infer = c(TRUE, FALSE),
                              type = "response", level = 0.95))
  expect_equal(nrow(df), 3L)              # 3-level factor -> 3 pairs
  expect_false("p.value" %in% names(df))  # symbolizer contract: no p-values
  # MCMCglmm reports a credible band as lower.HPD / upper.HPD -- the exact
  # column names marg_tibble_contrasts() must learn for a real fix.
  expect_true(all(c("lower.HPD", "upper.HPD") %in% names(df)))
  expect_true(all(is.finite(df$lower.HPD)))
  expect_true(all(is.finite(df$upper.HPD)))
})
