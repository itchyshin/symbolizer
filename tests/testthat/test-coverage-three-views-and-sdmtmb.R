# Coverage for R/render-three-views.R marginal-cov captions and R/symbolize-sdmtmb.R.

test_that("as_html_three_views shows meta-specific marginal-cov caption text", {
  testthat::skip_if_not_installed("drmTMB")
  sym <- symbolize(fit_drmtmb_phylo_multilevel())
  html <- as_html_three_views(sym, id = "cov-meta-marg")
  expect_match(html, "known", ignore.case = TRUE)
  expect_match(html, "sampling", ignore.case = TRUE)
  expect_match(html, "Marginal covariance", fixed = TRUE)
})

test_that("as_html_three_views shows generic marginal-cov caption on multi-RE fits", {
  testthat::skip_if_not_installed("drmTMB")
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ 1 + x + (1 | study_ID) + (1 | site_id),
                        sigma ~ 1),
    data = data.frame(
      y = rnorm(60), x = rnorm(60),
      study_ID = factor(rep(1:6, each = 10)),
      site_id  = factor(rep(1:12, each = 5))
    ),
    family = stats::gaussian()
  )
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "cov-multi-re")
  expect_match(html, "Marginal covariance", fixed = TRUE)
  expect_match(html, "per random-effect group", fixed = TRUE)
  expect_false(grepl("known.*sampling tier", html, perl = TRUE))
})

test_that("symbolize.sdmTMB accepts custom response symbols and factor contrasts", {
  testthat::skip_if_not_installed("sdmTMB")
  set.seed(2L); n <- 120L
  dat <- data.frame(
    x = runif(n), y_loc = runif(n),
    grp = factor(rep(c("a", "b", "c"), length.out = n)),
    z = rnorm(n)
  )
  dat$obs <- 2 + 0.5 * dat$z + rnorm(n)
  mesh <- sdmTMB::make_mesh(dat, c("x", "y_loc"), cutoff = 0.15)
  fit <- suppressWarnings(sdmTMB::sdmTMB(
    obs ~ z + grp, data = dat, mesh = mesh,
    family = stats::gaussian(), spatial = "on"
  ))
  sym <- symbolize(fit, symbols = c(obs = "Y_i"))
  expect_match(sym$distribution$latex, "Y_i", fixed = TRUE)
  fe <- sym$fixed_effects
  expect_true(any(grepl("grp", fe$term_label, fixed = TRUE)))
})

test_that("sdmtmb_build_warnings surfaces Hessian diagnostics when flagged", {
  testthat::skip_if_not_installed("sdmTMB")
  fit <- fit_sdmtmb_gaussian_spatial()
  fit$bad_eig <- TRUE
  fit$pos_def_hessian <- FALSE
  sym_stub <- list(model = list(class = "sdmTMB"))
  warn <- symbolizer:::sdmtmb_build_warnings(fit, sym_stub)
  expect_equal(nrow(warn), 2L)
  expect_true(any(grepl("bad-eigenvalue", warn$message, fixed = TRUE)))
  expect_true(any(grepl("non-positive-definite", warn$message, fixed = TRUE)))
})

test_that("knit_print variance_partition uses per-component bars for 3+ sources", {
  testthat::skip_if_not_installed("lme4")
  testthat::skip_if_not_installed("knitr")
  fit <- suppressWarnings(lme4::lmer(
    diameter ~ (1 | plate) + (1 | sample),
    data = lme4::Penicillin
  ))
  vp <- variance_partition(symbolize(fit))
  out <- knitr::knit_print(vp)
  txt <- as.character(out)
  expect_s3_class(out, "knit_asis")
  expect_match(txt, "sym-vc-bars", fixed = TRUE)
})
