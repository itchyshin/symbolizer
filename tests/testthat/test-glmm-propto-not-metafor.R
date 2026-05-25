# v0.20 regression: glmmTMB::propto() is NOT the meta-analytic bridge.
# v0.16 claimed otherwise; Fisher's empirical audit (k = 30, seed 1)
# showed propto multiplies V by an estimated free scalar (~0.94, not 1),
# adding a parameter relative to metafor::rma.mv(V = V, ...).
#
# This file pins the divergence so a future version of symbolizer can't
# silently re-claim the two models are equivalent. If they ever *are*
# equivalent in a future glmmTMB / metafor release, this test will
# need a deliberate update -- which is the point.

test_that("glmmTMB propto and metafor rma.mv(V=V) are NOT identical models", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("glmmTMB")
  suppressMessages(library(metafor))
  suppressMessages(library(glmmTMB))

  # Same simulated meta-analytic data Fisher used in the v0.20 audit.
  set.seed(1)
  k <- 30
  true_mu  <- 0.3
  true_tau <- sqrt(0.05)
  vi <- runif(k, 0.01, 0.1)
  u_study <- rnorm(k, 0, true_tau)
  yi <- true_mu + u_study + rnorm(k, 0, sqrt(vi))
  V  <- diag(vi)
  rownames(V) <- colnames(V) <- as.character(seq_len(k))
  dat <- data.frame(
    yi    = yi,
    vi    = vi,
    study = factor(seq_len(k)),
    obs   = factor(seq_len(k)),
    g     = factor("a")
  )

  m_metafor <- rma.mv(yi = yi, V = V, random = ~ 1 | study,
                      data = dat, method = "REML")
  m_propto  <- suppressMessages(
    glmmTMB(yi ~ 1 + (1 | study) + propto(0 + obs | g, V),
            data = dat, REML = TRUE, dispformula = ~ 0)
  )

  beta_metafor <- as.numeric(coef(m_metafor))
  beta_propto  <- as.numeric(fixef(m_propto)$cond)
  tau2_metafor <- as.numeric(m_metafor$sigma2)
  tau2_propto  <- as.numeric(VarCorr(m_propto)$cond$study[1])

  # The propto block carries an additional estimated scale parameter.
  # In Fisher's reference run this came out near 0.943 -- materially
  # different from 1. We don't pin the exact value (different glmmTMB
  # / TMB versions move it), but we do pin that it is NOT 1.
  propto_scale <- as.numeric(VarCorr(m_propto)$cond[["g"]])

  # 1. beta_0 estimates should be close but not equal.
  expect_lt(abs(beta_metafor - beta_propto), 0.01)
  expect_gt(abs(beta_metafor - beta_propto), 1e-6)

  # 2. tau^2 estimates should be close but not equal (propto absorbs
  # part of the variance via its scale).
  expect_lt(abs(tau2_metafor - tau2_propto), 0.02)
  expect_gt(abs(tau2_metafor - tau2_propto), 1e-6)

  # 3. The decisive evidence: propto's scale is a free parameter and
  # is not pinned to 1. Allow generous slack; the point is it can move.
  expect_false(isTRUE(all.equal(propto_scale, 1, tolerance = 1e-4)))

  # 4. Models have different parameter counts. metafor has 2 free
  # parameters (beta_0 + tau^2); propto has 3 (beta_0 + tau^2 +
  # propto scale).
  expect_gt(length(stats::coef(m_propto, complete = TRUE)),
            length(beta_metafor) + 1L)
})

test_that("symbolize.glmmTMB tags propto fits as structured-covariance, not meta-analysis", {
  skip_if_not_installed("glmmTMB")
  skip_if_not_installed("metafor")
  suppressMessages(library(glmmTMB))

  # Use the same fixture data so this works without re-simulating.
  set.seed(1)
  k <- 30
  vi <- runif(k, 0.01, 0.1)
  yi <- rnorm(k, 0.3, 0.2)
  V  <- diag(vi)
  rownames(V) <- colnames(V) <- as.character(seq_len(k))
  dat <- data.frame(
    yi    = yi,
    study = factor(seq_len(k)),
    obs   = factor(seq_len(k)),
    g     = factor("a")
  )
  fit <- suppressMessages(
    glmmTMB(yi ~ 1 + (1 | study) + propto(0 + obs | g, V),
            data = dat, REML = TRUE, dispformula = ~ 0)
  )
  sym <- symbolize(fit)

  # v0.20: metadata carries the new flag.
  expect_true(isTRUE(sym$metadata$propto_known_corr_block))

  # Back-compat: the old name still resolves for one minor version.
  expect_true(isTRUE(sym$metadata$meta_analysis_via_glmmTMB))

  # The info row carries the corrected prose: it must use
  # "phylogenetic" / "structured-covariance" language, NOT
  # "meta-analytic / fixed-V". Surface via warning_table().
  wt <- warning_table(sym)
  info_rows <- wt[wt$severity == "info", , drop = FALSE]
  info_text <- paste(info_rows$message, collapse = " ")
  expect_true(grepl("phylogenetic|structured-covariance", info_text,
                    ignore.case = TRUE))
  expect_true(grepl("sigma\\^2.*estimated", info_text))
  expect_true(grepl("NOT the meta-analytic", info_text,
                    ignore.case = TRUE))
})
