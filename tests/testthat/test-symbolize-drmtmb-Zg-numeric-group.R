# Regression test for the long-standing drmTMB Z_g extractor bug
# (B102, found via maintainer Fisher-pass on the v0.22.1.2 rendered widget).
#
# Bug shape:
#   drm_build_expanded() built Z_g via
#     stats::model.matrix(reformulate(paste0("0+", g_var)), data = fit$data)
#   When g_var is NUMERIC in fit$data (very common -- study_ID, site_id,
#   animal_id codes are typically integer-coded), model.matrix does NOT
#   build a one-hot incidence matrix. It returns a single-column matrix
#   carrying the literal integer values. The renderer then shows a
#   165 x 1 Z column of integers next to a 39-vector u of BLUPs, which
#   is meaningless arithmetic.
#
# Fix: convert g_var to factor before model.matrix so model.matrix emits
# the one-hot incidence matrix.

test_that("drm_build_expanded()$Z_g is a one-hot incidence matrix when group_var is numeric", {
  set.seed(42L)
  n_groups <- 8L
  rep_per  <- 6L
  # Numeric integer codes that LOOK like real study IDs (3, 6, 15, ...)
  # — non-consecutive, mirroring the Pottier thermal CSV.
  group_ids <- c(3L, 6L, 15L, 20L, 21L, 28L, 33L, 40L)
  dat <- data.frame(
    y        = rnorm(n_groups * rep_per),
    x        = rnorm(n_groups * rep_per),
    study_ID = rep(group_ids, each = rep_per)
  )
  # study_ID is NUMERIC -- exactly the shape that triggers the bug.
  expect_true(is.numeric(dat$study_ID))

  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ 1 + x + (1 | study_ID),
                        sigma ~ 1),
    data = dat
  )
  sym <- symbolize(fit)
  ex  <- sym$expanded

  # Z_g must be the one-hot incidence matrix (n x k), not the literal
  # study_ID column.
  expect_equal(dim(ex$Z_g), c(nrow(dat), n_groups))
  # Each row of a one-hot is exactly one 1 and the rest 0.
  row_sums <- rowSums(ex$Z_g)
  expect_true(all(row_sums == 1L))
  # No literal study_ID integers anywhere (range must be {0, 1}).
  expect_setequal(unique(as.vector(ex$Z_g)), c(0, 1))

  # And the columns must be ordered to match the BLUPs vector u.
  # Otherwise Z %*% u gives the wrong per-observation RE contribution.
  expect_equal(length(ex$u), n_groups)
  expect_equal(ncol(ex$Z_g), length(ex$u))
})

test_that("drm_build_expanded()$Z_g %*% u gives the per-observation RE contribution", {
  # End-to-end correctness: for any row i, the predicted random-effect
  # contribution should equal the BLUP for that row's group.
  set.seed(101L)
  group_ids <- c(11L, 22L, 33L, 44L, 55L)
  dat <- data.frame(
    y        = rnorm(20L),
    x        = rnorm(20L),
    study_ID = rep(group_ids, each = 4L)
  )
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ 1 + x + (1 | study_ID),
                        sigma ~ 1),
    data = dat
  )
  sym <- symbolize(fit)
  ex  <- sym$expanded

  re_contrib <- unname(drop(ex$Z_g %*% ex$u))

  # Compare to BLUPs indexed by row's group level.
  blups <- fit$random_effects$mu$terms[["(1 | study_ID)"]]
  expected <- unname(as.numeric(blups[as.character(dat$study_ID)]))

  expect_equal(re_contrib, expected, tolerance = 1e-10)
})

test_that("drm_build_expanded()$Z_g is also correct when group_var is already a factor", {
  # Regression guard: the fix must not break the factor-input path
  # (which was already correct).
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

  expect_equal(dim(ex$Z_g), c(20L, 5L))
  expect_true(all(rowSums(ex$Z_g) == 1L))
  expect_setequal(unique(as.vector(ex$Z_g)), c(0, 1))
})
