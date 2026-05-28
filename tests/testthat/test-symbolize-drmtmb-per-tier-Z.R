# v0.22.2-discipline Slice A1 tests.
#
# Per-tier Z matrix surfacing for multi-tier drmTMB fits. The existing
# `drm_build_expanded()` extracts only the first random-effect tier via
# `re_per_entry[[which(has_re)[1L]]]`. For phylo + study fits, that
# silently drops the phylo tier from the Tab 3 numeric expansion, hiding
# the article thesis from the widget.
#
# The fix delegates Z construction to `reformulas::mkReTrms` (the same
# helper glmmTMB / lme4 use). It returns per-tier Z matrices and per-tier
# factor lists; we map per-tier BLUPs back from drmTMB's storage
# (iid tiers from `fit$random_effects$mu$terms`, structured tiers from
# `fit$obj$report()$u_phylo` etc.).
#
# Contract per `docs/specs/import-from-sisters.md`:
#   ex$Z_per_tier:    named list of n x k_g one-hot incidence matrices
#   ex$u_per_tier:    named list of k_g BLUPs vectors per tier
#   ex$tier_kind:     named character vector: "iid" or "structured"
#   ex$Z_g, ex$u:     back-compat -- first tier only
#   Closure:          X*beta + sum_g(Z_per_tier[[g]] %*% u_per_tier[[g]])
#                     equals fit$obj$report()$mu to 1e-9 tolerance

test_that("two-tier iid drmTMB fit surfaces both Z matrices in $Z_per_tier", {
  # Two iid grouping vars (numeric) -- both must appear, no silent drop.
  set.seed(2026L)
  n_per_combo <- 4L
  n_studies   <- 5L
  n_sites     <- 6L
  combos      <- expand.grid(study_ID = seq_len(n_studies),
                             site_id  = seq_len(n_sites))
  dat <- combos[rep(seq_len(nrow(combos)), each = n_per_combo), ]
  dat$y <- rnorm(nrow(dat))
  dat$x <- rnorm(nrow(dat))

  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ 1 + x + (1 | study_ID) + (1 | site_id),
                        sigma ~ 1),
    data = dat
  )
  sym <- symbolize(fit)
  ex  <- sym$expanded

  # Both tiers must be present, named by group_var.
  expect_true("Z_per_tier" %in% names(ex))
  expect_true("u_per_tier" %in% names(ex))
  expect_setequal(names(ex$Z_per_tier), c("study_ID", "site_id"))
  expect_setequal(names(ex$u_per_tier), c("study_ID", "site_id"))

  # Each tier's Z is a one-hot incidence matrix of the right shape.
  expect_equal(dim(ex$Z_per_tier$study_ID),
               c(nrow(dat), n_studies))
  expect_equal(dim(ex$Z_per_tier$site_id),
               c(nrow(dat), n_sites))
  expect_true(all(rowSums(ex$Z_per_tier$study_ID) == 1L))
  expect_true(all(rowSums(ex$Z_per_tier$site_id) == 1L))

  # Each tier's u is a k-vector matching the Z column count.
  expect_equal(length(ex$u_per_tier$study_ID), n_studies)
  expect_equal(length(ex$u_per_tier$site_id),  n_sites)

  # Closure: X*beta + Z_study*u_study + Z_site*u_site == fit$obj$report()$mu
  X <- ex$X; beta <- ex$beta
  mu_predicted <-
    as.numeric(X %*% beta) +
    drop(ex$Z_per_tier$study_ID %*% ex$u_per_tier$study_ID) +
    drop(ex$Z_per_tier$site_id  %*% ex$u_per_tier$site_id)
  expect_equal(unname(mu_predicted),
               unname(as.numeric(fit$obj$report()$mu)),
               tolerance = 1e-9)
})

test_that("Pottier meta-multilevel fit surfaces both study AND phylogeny tiers", {
  # The exact fit from the v0.22.1.x article §4. The phylo tier was
  # silently dropped from Tab 3 in v0.22.1.3.
  skip_if_not_installed("ape")
  source(test_path("helper-meta-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drmtmb_phylo_multilevel())
  sym <- symbolize(fit)
  ex  <- sym$expanded

  # Both tiers must be present.
  expect_true("Z_per_tier" %in% names(ex))
  expect_true("u_per_tier" %in% names(ex))
  expect_true("study_ID"  %in% names(ex$Z_per_tier))
  expect_true("phylogeny" %in% names(ex$Z_per_tier))

  # Phylo tier has 35 species columns.
  expect_equal(ncol(ex$Z_per_tier$phylogeny), 35L)
  # Study tier has 39 study columns.
  expect_equal(ncol(ex$Z_per_tier$study_ID), 39L)

  # Each is a proper one-hot.
  expect_true(all(rowSums(ex$Z_per_tier$study_ID) == 1L))
  expect_true(all(rowSums(ex$Z_per_tier$phylogeny) == 1L))

  # u_phylo has 35 entries (tip-level BLUPs; all-nodes encoding is
  # 68-long but only the n_tips entries enter the linear predictor for
  # observations).
  expect_equal(length(ex$u_per_tier$phylogeny), 35L)
  expect_equal(length(ex$u_per_tier$study_ID),  39L)

  # tier_kind labels each tier.
  expect_true("tier_kind" %in% names(ex))
  expect_equal(ex$tier_kind[["study_ID"]],  "iid")
  expect_equal(ex$tier_kind[["phylogeny"]], "structured")

  # Closure: X*beta + Z_study*u_study + Z_phylo*u_phylo == fit$obj$report()$mu
  # at 1e-9 tolerance. This is the Fisher protocol check.
  X <- ex$X; beta <- ex$beta
  mu_predicted <-
    as.numeric(X %*% beta) +
    drop(ex$Z_per_tier$study_ID  %*% ex$u_per_tier$study_ID) +
    drop(ex$Z_per_tier$phylogeny %*% ex$u_per_tier$phylogeny)
  expect_equal(unname(mu_predicted),
               unname(as.numeric(fit$obj$report()$mu)),
               tolerance = 1e-9)
})

test_that("single-RE fits keep the back-compat $Z_g and $u slots populated", {
  # Critical: the v0.22.1.3 fix path is single-tier. Existing renderer
  # code reads ex$Z_g and ex$u directly. The refactor must keep these
  # slots present and equal to the first tier's Z/u.
  set.seed(7L)
  dat <- data.frame(
    y     = rnorm(20L),
    x     = rnorm(20L),
    group = factor(rep(c("A", "B", "C", "D", "E"), each = 4L))
  )
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ 1 + x + (1 | group),
                        sigma ~ 1),
    data = dat
  )
  sym <- symbolize(fit)
  ex  <- sym$expanded

  # Back-compat slots still populated.
  expect_equal(dim(ex$Z_g), c(20L, 5L))
  expect_equal(length(ex$u), 5L)

  # And per-tier slots populated, with the back-compat slots aliasing
  # to the first tier.
  expect_setequal(names(ex$Z_per_tier), "group")
  expect_equal(ex$Z_g, ex$Z_per_tier$group, ignore_attr = TRUE)
  expect_equal(ex$u, ex$u_per_tier$group, ignore_attr = TRUE)
})
