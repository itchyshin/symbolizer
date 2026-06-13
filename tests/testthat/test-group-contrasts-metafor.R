# Documents the metafor (rma.uni) status for group_contrasts().
#
# Finding: emmeans has no recover_data / emm_basis method for class "rma", so
# per-group means / contrasts cannot be built for a metafor fit. symbolizer
# detects this at the marginal layer (marg_check_family_supported) and raises
# an explanatory gate pointing at metafor's own moderator tools, rather than
# letting emmeans surface its generic "Can't handle an object" error. The
# tests below lock that gate.

# dat.bcg's `alloc` is a 3-level factor moderator (alternate / random /
# systematic), so this is the multi-level factor case for contrasts.
fit_metafor_rma_factor_mod <- function() {
  testthat::skip_if_not_installed("metafor")
  dat <- .load_dat_bcg()
  es <- metafor::escalc(measure = "RR",
                        ai = dat$tpos, bi = dat$tneg,
                        ci = dat$cpos, di = dat$cneg,
                        data = dat)
  es$alloc <- factor(es$alloc)
  metafor::rma(yi, vi, mods = ~ alloc, data = es, method = "REML")
}

test_that("the factor moderator and fit reach group_contrasts intact", {
  skip_if_not_installed("metafor")
  sym <- symbolize(fit_metafor_rma_factor_mod())
  # The moderator is recognised as a factor and the fit is retained, so the
  # call gets past every symbolizer-layer gate and into emmeans.
  expect_true("alloc" %in% symbolizer:::marg_factors(sym))
  expect_false(is.null(sym$metadata$fit))
})

test_that("group_contrasts on rma.uni is gated with an explanatory message", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("emmeans")
  sym <- symbolize(fit_metafor_rma_factor_mod())
  # symbolizer gates rma fits at the marginal layer with a clear message
  # naming the class and pointing at metafor's own tools.
  expect_error(
    group_contrasts(sym, by = "alloc"),
    "does not support|metafor|rma"
  )
})
