# Helper fits for symbolize.rma.uni tests. metafor's bcg dataset is
# small (13 effect sizes) so the fits are instant.

.load_dat_bcg <- function() {
  e <- new.env()
  # metafor 4.x moved the bundled datasets to the `metadat` package.
  # Fall back to the legacy metafor location if metadat isn't installed.
  pkg <- if (requireNamespace("metadat", quietly = TRUE)) "metadat" else "metafor"
  utils::data("dat.bcg", package = pkg, envir = e)
  e$dat.bcg
}

fit_metafor_rma <- function() {
  testthat::skip_if_not_installed("metafor")
  dat <- .load_dat_bcg()
  es <- metafor::escalc(measure = "RR",
                        ai = dat$tpos, bi = dat$tneg,
                        ci = dat$cpos, di = dat$cneg,
                        data = dat)
  metafor::rma(yi, vi, data = es, method = "REML")
}

fit_metafor_rma_mods <- function() {
  testthat::skip_if_not_installed("metafor")
  dat <- .load_dat_bcg()
  es <- metafor::escalc(measure = "RR",
                        ai = dat$tpos, bi = dat$tneg,
                        ci = dat$cpos, di = dat$cneg,
                        data = dat)
  metafor::rma(yi, vi, mods = ~ year, data = es, method = "REML")
}
