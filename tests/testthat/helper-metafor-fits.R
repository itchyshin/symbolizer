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

# v0.13.1: multilevel rma.mv -- studies nested within districts.
.load_dat_konstantopoulos <- function() {
  e <- new.env()
  pkg <- if (requireNamespace("metadat", quietly = TRUE)) "metadat" else "metafor"
  utils::data("dat.konstantopoulos2011", package = pkg, envir = e)
  e$dat.konstantopoulos2011
}

fit_metafor_rma_mv <- function() {
  testthat::skip_if_not_installed("metafor")
  dat <- .load_dat_konstantopoulos()
  metafor::rma.mv(yi, vi,
                  random = ~ 1 | district / study,
                  data = dat, method = "REML")
}

# v0.13.1: rma.mv with an attached R-matrix random effect (synthetic
# phylogenetic-style correlation on the district level for testing).
.load_dat_bangert <- function() {
  e <- new.env()
  pkg <- if (requireNamespace("metadat", quietly = TRUE)) "metadat" else "metafor"
  utils::data("dat.bangertdrowns2004", package = pkg, envir = e)
  e$dat.bangertdrowns2004
}

# v0.15: location-scale rma (rma.ls). Models log(tau^2_i) = alpha_0 +
# alpha_1 * ni_i alongside the standard location-part mu_i = beta_0 +
# beta_1 * ni_i.
fit_metafor_rma_ls <- function() {
  testthat::skip_if_not_installed("metafor")
  dat <- .load_dat_bangert()
  metafor::rma(yi, vi, mods = ~ ni, scale = ~ ni, data = dat)
}

fit_metafor_rma_mv_structured <- function() {
  testthat::skip_if_not_installed("metafor")
  dat <- .load_dat_konstantopoulos()
  n_dist <- length(unique(dat$district))
  R_dist <- diag(n_dist) * 0.8 + matrix(0.2, n_dist, n_dist)
  rownames(R_dist) <- colnames(R_dist) <- as.character(sort(unique(dat$district)))
  dat$d2 <- dat$district
  metafor::rma.mv(yi, vi,
                  random = list(~ 1 | study, ~ 1 | d2),
                  R = list(d2 = R_dist),
                  data = dat, method = "REML")
}
