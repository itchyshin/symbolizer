# v0.22.4 Slice 1 — Tab 3 stacked-block family-awareness.
#
# Cross-confirmed BLOCKER from the families team review
# (docs/dev-log/figure-audits/v0.22.3-families-team-review/):
#
#   F1: Tab 3 stacked block emits `y = X β̂ + ε̂` regardless of family.
#       Arithmetic doesn't close for any non-Gaussian family.
#       Poisson row 1: 0.936 + (-1.55) = -0.614, but y_1 = 1.
#   F2: Caption "Middle: X β̂ = μ̂" asserts identity link universally.
#   F3: Lognormal symbol ε̂ overloaded across worked-row (log scale)
#       and stacked block (response scale).
#
# The fix mirrors v0.22.3 worked-row architecture into the stacked
# block. Three shapes:
#   additive_gaussian (Gaussian, Student-t): y = X β̂ + ε̂   (unchanged)
#   additive_log (Lognormal): log(y) = X β̂ + ε̂^{(log)}      (NEW)
#   generalized (Poisson, Beta, Gamma, NegBinom): η̂ = X β̂ as LP,
#       then μ̂ = link^{-1}(η̂), no additive ε̂                (NEW)

test_that("Poisson stacked block has no spurious additive epsilon", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_poisson())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-pois-stk")

  # Get the Tab 3 (panel-mat) content only -- the worked-row above
  # was already fixed in v0.22.3, so we don't want that match to
  # mask a missed fix in the stacked block.
  pos <- regexpr("panel-mat", html)
  panel_mat <- if (pos[[1L]] > 0L) substr(html, pos[[1L]], nchar(html)) else ""

  # No additive epsilon term anywhere in the stacked-block panel for
  # Poisson. Worked row already had this fixed in v0.22.3; this test
  # extends it to the stacked block.
  expect_false(grepl("\\\\hat\\{\\\\boldsymbol\\{\\\\varepsilon\\}\\}",
                     panel_mat),
               info = "Poisson stacked block must drop the additive epsilon")
})

test_that("Poisson stacked block uses eta-hat (linear predictor) as LHS", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_poisson())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-pois-stk2")

  pos <- regexpr("panel-mat", html)
  panel_mat <- if (pos[[1L]] > 0L) substr(html, pos[[1L]], nchar(html)) else ""

  # LHS of the stacked block should be the linear predictor eta-hat
  # (link scale), not the response-scale observation y, since the
  # rest of the equation is on link scale.
  expect_true(
    grepl("\\\\hat\\{\\\\boldsymbol\\{\\\\eta\\}\\}", panel_mat),
    info = "Poisson stacked block should display eta-hat (LP) as LHS"
  )
})

test_that("Beta stacked block has no spurious additive epsilon", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-beta-stk")

  pos <- regexpr("panel-mat", html)
  panel_mat <- if (pos[[1L]] > 0L) substr(html, pos[[1L]], nchar(html)) else ""

  expect_false(grepl("\\\\hat\\{\\\\boldsymbol\\{\\\\varepsilon\\}\\}",
                     panel_mat),
               info = "Beta stacked block must drop the additive epsilon")
})

test_that("Lognormal stacked block puts log(y) on the LHS, not raw y", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_lognormal())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-ln-stk")

  pos <- regexpr("panel-mat", html)
  panel_mat <- if (pos[[1L]] > 0L) substr(html, pos[[1L]], nchar(html)) else ""

  # Lognormal additive_log shape: log(y) = X β̂ + ε̂^{(log)}
  # The LHS underbrace label should contain `\log` (the LaTeX command
  # for the log function operator) -- but NOT inside a \text{} block,
  # to avoid the v0.22.3 sigma-caption rendering bug.
  expect_true(
    grepl("\\\\log\\\\!?\\\\underbrace|\\\\log\\\\,\\\\underbrace|\\\\log\\(.{0,500}\\\\underbrace.{0,100}\\\\text\\{\\(observed\\)",
          panel_mat, perl = TRUE) ||
      grepl("log\\(.{0,2000}observed", panel_mat),
    info = paste("Lognormal stacked block must put log(y) on LHS;",
                 "found content does not match log-of-y form")
  )
})

test_that("Lognormal residual symbol is the same scale top and bottom of Tab 3", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_lognormal())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-ln-eps-symbol")

  # Worked row already uses ε̂^{(log)}. Stacked block residual should
  # also be on log scale and labelled identically -- not overloaded
  # to mean "y - mu_hat" on response scale.
  #
  # Check: the rendered HTML should NOT contain a residual vector
  # whose values match `y - mu_hat` on response scale (the buggy
  # value); it SHOULD contain a residual whose values match
  # `log(y) - mu_hat`.
  ex <- sym$expanded
  bug_residual_1 <- formatC(ex$y[[1L]] - ex$mu_hat[[1L]],
                            digits = 3, format = "g")
  good_residual_1 <- formatC(log(ex$y[[1L]]) - ex$mu_hat[[1L]],
                             digits = 3, format = "g")
  # The bug value (2.77 on this fit) must NOT appear inside any
  # \begin{bmatrix} -- but it MIGHT appear in caption text like
  # "y_1 = 4.78". So check inside bmatrix contexts only.
  bmatrix_chunks <- regmatches(
    html,
    gregexpr("\\\\begin\\{bmatrix\\}.*?\\\\end\\{bmatrix\\}", html))[[1L]]
  bug_in_bmatrix <- any(vapply(bmatrix_chunks,
                                function(s) grepl(bug_residual_1,
                                                  s, fixed = TRUE),
                                logical(1L)))
  expect_false(bug_in_bmatrix,
               info = paste("Lognormal stacked block contains a residual",
                            "value", bug_residual_1, "on the response scale;",
                            "should be on log scale (", good_residual_1, ")"))
})

test_that("Gaussian stacked block keeps the historic y = X β̂ + ε̂ shape", {
  # Back-compat guard. The fix must not break the Gaussian-identity
  # path, which is the only family for which `y = X β̂ + ε̂` is
  # mathematically valid.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_location_scale())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-gauss-stk")

  pos <- regexpr("panel-mat", html)
  panel_mat <- if (pos[[1L]] > 0L) substr(html, pos[[1L]], nchar(html)) else ""

  # Historic shape: epsilon vector is emitted.
  expect_true(grepl("\\\\hat\\{\\\\boldsymbol\\{\\\\varepsilon\\}\\}",
                    panel_mat))
})

test_that("stacked-block caption drops universal 'X β̂ = μ̂' claim for non-Gaussian", {
  # F2: the caption "Middle: X β̂ = μ̂" is true only for Gaussian
  # identity-link. The fix should drop or branch the caption per
  # family shape.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)

  for (h in c("fit_drm_poisson", "fit_drm_beta")) {
    fit <- suppressWarnings(get(h)())
    sym <- symbolize(fit)
    html <- as_html_three_views(sym, id = paste0("test-cap-", h))

    # The universal caption text "X β̂ + Zû = μ̂" or "Xβ̂ = μ̂" must
    # NOT appear verbatim in non-Gaussian widgets.
    bad_caption <- grepl(
      "Middle.*the prediction.*\\\\hat\\{\\\\boldsymbol\\{\\\\mu\\}\\}",
      html, perl = TRUE
    ) ||
      grepl("Middle.*\\\\mathbf\\{X\\}\\\\hat\\{\\\\boldsymbol\\{\\\\beta\\}\\}.*=.*\\\\hat\\{\\\\boldsymbol\\{\\\\mu\\}\\}",
            html, perl = TRUE)
    expect_false(bad_caption,
                 info = paste(h, "stacked-block caption still asserts",
                              "the universal X β̂ = μ̂ relationship"))
  }
})
