# v0.21.5-redo: tests for the widget-ready `$expanded` slots on
# symbolize.gllvmTMB output. The three-views widget renderer
# (R/render-three-views.R) needs: X, beta, Z_g, u, mu_hat, fitted,
# residuals, and M. These are NOT populated by glm_build_expanded()
# pre-this-slice; we extend the extractor to populate them.

# ---- between-only fit (no unique()) ----------------------------------------

test_that("symbolize.gllvmTMB populates X (n_obs x n_traits) for between-only fit", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$X), info = "expanded$X is NULL")
  expect_true(is.matrix(sym$expanded$X))
  expect_equal(nrow(sym$expanded$X), length(sym$expanded$y))
  expect_equal(ncol(sym$expanded$X), as.integer(fit$n_traits))
})

test_that("symbolize.gllvmTMB populates beta (trait intercepts) for between-only fit", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$beta), info = "expanded$beta is NULL")
  expect_true(is.numeric(sym$expanded$beta))
  expect_equal(length(sym$expanded$beta), as.integer(fit$n_traits))
})

test_that("symbolize.gllvmTMB populates u (per-observation RE contribution) for between-only fit", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$u), info = "expanded$u is NULL")
  expect_true(is.numeric(sym$expanded$u))
  expect_equal(length(sym$expanded$u), length(sym$expanded$y))
})

test_that("symbolize.gllvmTMB populates Z_g (identity over n_obs) for between-only fit", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$Z_g), info = "expanded$Z_g is NULL")
  expect_true(is.matrix(sym$expanded$Z_g))
  # Z_g is the identity-on-observations marker -- triggers the renderer's
  # Z-drop logic (n_obs == n_distinct_levels, one obs per level) so the
  # widget shows u_{n×1} directly without a wall of zeros.
  expect_equal(nrow(sym$expanded$Z_g), length(sym$expanded$y))
  expect_equal(ncol(sym$expanded$Z_g), length(sym$expanded$y))
})

test_that("symbolize.gllvmTMB populates mu_hat consistently for between-only fit", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$mu_hat), info = "expanded$mu_hat is NULL")
  expect_equal(length(sym$expanded$mu_hat), length(sym$expanded$y))
  # The stacked equation closes: mu_hat = X beta + u (Gaussian identity
  # link; u is the per-obs RE contribution).
  X    <- sym$expanded$X
  beta <- sym$expanded$beta
  u    <- sym$expanded$u
  predicted <- as.numeric(X %*% beta + u)
  expect_equal(sym$expanded$mu_hat, predicted, tolerance = 1e-6)
})

test_that("symbolize.gllvmTMB populates fitted + residuals consistently", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$fitted))
  expect_true(!is.null(sym$expanded$residuals))
  expect_equal(length(sym$expanded$fitted), length(sym$expanded$y))
  expect_equal(length(sym$expanded$residuals), length(sym$expanded$y))
  # Gaussian identity link: fitted == mu_hat; residuals == y - fitted.
  expect_equal(sym$expanded$fitted, sym$expanded$mu_hat, tolerance = 1e-6)
  expect_equal(sym$expanded$residuals,
               sym$expanded$y - sym$expanded$fitted, tolerance = 1e-6)
})

# ---- between + within fit (unique() term) ----------------------------------

test_that("symbolize.gllvmTMB populates expanded$Psi_B when unique() term is present", {
  # When the formula has a unique(0 + trait | unit) term, the fit has a
  # trait-specific between-unit uniqueness Psi_B (a length-n_traits vector
  # of per-trait diagonal SDs that gllvmTMB exposes as `sd_B`). Verify it
  # ends up in $expanded.
  fit <- fit_gllvm_with_unique()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$expanded$Psi_B),
              info = "expanded$Psi_B is NULL for a fit with unique() term")
  expect_true(is.numeric(sym$expanded$Psi_B))
  expect_equal(length(sym$expanded$Psi_B), as.integer(fit$n_traits))
})

test_that("symbolize.gllvmTMB still passes the widget-shape contract for unique() fit", {
  # The widget needs X, beta, Z_g, u, mu_hat, fitted, residuals on BOTH
  # the between-only and the between+within fits.
  fit <- fit_gllvm_with_unique()
  sym <- symbolize(fit)
  for (slot in c("X", "beta", "Z_g", "u", "mu_hat", "fitted", "residuals")) {
    expect_true(!is.null(sym$expanded[[slot]]),
                info = sprintf("expanded$%s is NULL on a unique() fit", slot))
  }
})

# ---- column naming: avoids Pattern A escape leak in renderer ---------------

test_that("symbolize.gllvmTMB labels columns of X with trait levels", {
  # The worked-row renderer (R/render-three-views.R, predictor_label())
  # falls back to "x_{k}" when colnames(X) are NULL, then LaTeX-escapes
  # the literal `_` to `\_`, producing visible `\mathrm{x\_{1}}` in the
  # rendered page. Naming X by trait_levels avoids the fallback entirely.
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_true(!is.null(colnames(sym$expanded$X)),
              info = "expanded$X has no colnames; renderer will fall back to x_{k}")
  expect_equal(length(colnames(sym$expanded$X)),
               as.integer(fit$n_traits))
  # Names must be LaTeX-safe inside \mathrm{...}: no curly-brace tokens.
  expect_false(any(grepl("[{}]", colnames(sym$expanded$X))),
               info = "X colnames contain braces; will mis-render in \\mathrm{}")
})

test_that("symbolize.gllvmTMB labels columns of Z_g with per-observation IDs", {
  # The renderer reads colnames(Z_g)[active_col] to label the per-obs RE
  # term. When Z_g is identity, the per-obs label should be the
  # observation index, giving `\hat{u}_{1}` rather than the generic
  # `\hat{u}_{\mathrm{group}(1)}` fallback.
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_true(!is.null(colnames(sym$expanded$Z_g)),
              info = "expanded$Z_g has no colnames; renderer will use group(1) fallback")
  expect_equal(length(colnames(sym$expanded$Z_g)),
               length(sym$expanded$y))
})

# ---- regression check: existing slots still work ---------------------------

test_that("symbolize.gllvmTMB still populates the historic slots (Lambda_B, Z_B, etc.)", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  # The extension MUST NOT remove anything from the prior contract.
  for (slot in c("y", "Y", "mu", "Lambda_B", "Z_B", "Sigma_B", "sigma_eps", "eta")) {
    expect_true(!is.null(sym$expanded[[slot]]),
                info = sprintf("expanded$%s regressed (was present pre-slice)", slot))
  }
})
