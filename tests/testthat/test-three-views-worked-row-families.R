# Slice 2 of the families-fix. The Tab 3 worked-row helper hardcodes
# `y_i = β_0 + β_1 x_i + ε̂_i` -- Gaussian-identity. For non-Gaussian
# families this mixes scales: LHS y is on response scale, β_0 + β_1 x_i
# is on link scale (η̂), and the ε̂ is a meaningless "y - η̂" subtraction.
#
# Expected family-aware shape (Poisson example):
#   η̂_1 = β_0 + β_1 x_1            (linear predictor)
#   0.936 = 0.955 + (-0.0438)*0.45
#   μ̂_1 = exp(η̂_1) ≈ 2.55          (response-scale rate)
#   y_1 ~ Poisson(μ̂_1)              (likelihood declaration; no additive ε)
#
# Gaussian-identity keeps the historic shape for back-compat.

test_that("Poisson worked row drops spurious additive epsilon", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_poisson())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-pois")

  # No spurious `+ \hat\varepsilon_{1}` on the linear-predictor line.
  # The historic Gaussian template emits this; the family-aware form
  # drops it for Poisson (likelihood has no residual on linear predictor).
  expect_false(grepl("\\\\hat\\\\varepsilon_\\{1\\}", html))
})

test_that("Poisson worked row shows the back-transform on response scale", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_poisson())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-pois2")

  # The widget needs to make the link explicit: mu_hat = exp(eta_hat).
  # Either an inline `\exp(` or an explicit `\mu_{1}` line.
  expect_true(
    grepl("\\\\exp\\(", html) || grepl("\\\\hat\\\\mu_\\{1\\}", html),
    info = "Poisson Tab 3 must surface the log-link back-transform mu = exp(eta)"
  )
})

test_that("Beta worked row shows response-scale mu in (0,1), not raw eta", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  ex  <- sym$expanded
  html <- as_html_three_views(sym, id = "test-beta")

  # The rendered "predicted" value displayed for the worked row should
  # be the response-scale mu (∈ (0,1)), not the raw eta (potentially
  # negative). Look for plogis or for a digit-only block that matches
  # mu_hat[1] formatted at 3 sig figs.
  mu_1_str <- formatC(ex$mu_hat[[1L]], digits = 3, format = "g")
  expect_true(grepl(mu_1_str, html, fixed = TRUE),
              info = paste("Expected the response-scale mu_hat[1] =", mu_1_str,
                           "to appear in the rendered Tab 3"))
})

test_that("Beta sigma worked row labels the dispersion as precision phi, not SD", {
  # Fisher pass families-fisher.md Pattern D: Beta's "sigma" parameter
  # is the precision phi (a positive shape parameter), NOT a residual
  # standard deviation. Labelling it "residual SD" is wrong twice
  # over (it isn't an SD, and Beta has no residual structure on the
  # linear predictor).
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-beta-sigma")

  # Either the dispersion line is omitted (acceptable -- it's redundant
  # with Tab 1) OR it labels the parameter as precision phi.
  has_label <- grepl("precision", html) ||
               grepl("\\\\hat\\\\phi", html) ||
               !grepl("predicted residual SD", html)
  expect_true(has_label)
  # And the misleading caption must be gone.
  expect_false(grepl("predicted residual SD", html, fixed = TRUE))
})

test_that("Lognormal sigma caption uses plain prose (no backslash commands inside text)", {
  # Backslash commands like `\log y` or `\hat\phi_{1}` inside `\text{...}`
  # break pandoc's math-block parser and the whole $$...$$ block is
  # emitted as raw text instead of rendered as MathJax. Maintainer's
  # screenshot on v0.22.3 caught both Lognormal and Beta sigma blocks
  # rendering as raw LaTeX source for this reason.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_lognormal())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-ln-sigma")

  # No backslash command inside any \text{...} caption.
  text_chunks <- regmatches(html, gregexpr("\\\\text\\{[^}]*\\}", html))[[1L]]
  bad <- grep("\\\\(log|hat|exp|alpha|beta|gamma|sigma|phi|mu|eta|sin|cos)",
              text_chunks, value = TRUE)
  expect_equal(bad, character(0L),
               info = "Backslash LaTeX commands found inside \\text{}; will break pandoc")
})

test_that("Beta sigma caption uses plain prose for the precision parameter", {
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-beta-sigma-text")

  text_chunks <- regmatches(html, gregexpr("\\\\text\\{[^}]*\\}", html))[[1L]]
  bad <- grep("\\\\(log|hat|exp|alpha|beta|gamma|sigma|phi|mu|eta|sin|cos)",
              text_chunks, value = TRUE)
  expect_equal(bad, character(0L))
})

test_that("Gaussian-identity worked row keeps the historic y = Xb + eps shape", {
  # Back-compat: Gaussian-identity is the ONLY family that legitimately
  # has y = X*beta + eps on the linear-predictor scale. Don't break it.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_location_scale())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-gauss")

  # Historic shape: the worked row DOES include the additive epsilon
  # on the response equation. Don't regress.
  expect_true(grepl("\\\\hat\\\\varepsilon_\\{1\\}", html))
})

test_that("sigma worked row does not emit duplicated `= -X = -X` for intercept-only sigma", {
  # Florence caught (post-Slice-1) that intercept-only sigma submodels
  # (Lognormal, Beta, ...) emit a line like
  #   `\log\hat\sigma_1 &= -0.764 = -0.764  (with your numbers)`
  # because the renderer hardcodes `&= num_rhs = fmt(log_sig1)` and
  # for intercept-only models `num_rhs == fmt(log_sig1)`. The middle
  # numeric form is the same as the final value, so the duplicate `=`
  # is visually nonsense ("eq dash zero point seven six four equals
  # dash zero point seven six four").
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)

  for (h in c("fit_drm_lognormal", "fit_drm_beta")) {
    fit <- suppressWarnings(get(h)())
    sym <- symbolize(fit)
    html <- as_html_three_views(sym, id = paste0("test-sig-", h))

    # Match the literal LaTeX-source pattern `<num> = <num>` where the
    # two <num> are the same negative decimal. The MathML annotation
    # carries the same TeX source, so this fires whether or not pandoc
    # converted the math block.
    bad <- regmatches(
      html,
      gregexpr("(-?\\d+\\.\\d+) = \\1(?!\\d)", html, perl = TRUE)
    )[[1L]]
    expect_equal(bad, character(0L),
                 info = paste(h, "sigma worked row emits a duplicated",
                              "`= X = X` redundancy:", paste(bad, collapse = "; ")))
  }
})
