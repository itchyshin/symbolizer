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

test_that("worked-row predictor renders italic x, not upright mathrm{x}", {
  # Punch-list #9. The worked-row LHS used \mathrm{x}_{1} (upright,
  # conventionally for multi-letter operators) while Tab 1, the gloss,
  # and the dimension labels all use italic math x. A single-letter
  # predictor should be italic so it reads as the same object.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_poisson())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-pred-italic")
  expect_false(grepl("\\\\mathrm\\{x\\}", html),
               info = "single-letter predictor should be italic x_{1}, not \\mathrm{x}_{1}")
})

test_that("worked rows fold negative coefficients into the operator (no '+ -')", {
  # Punch-list #7. Negative coefficients rendered as a binary plus glued
  # to a negative literal: '0.955 + -0.0438 \\times 0.45'. Fold the sign
  # into the operator: '0.955 - 0.0438 \\times 0.45'. The parenthesized
  # residual / random-effect style '+ (-0.448)' is the page's own
  # convention and is left intact (only bare '+ -<digit>' is the bug).
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)

  for (h in c("fit_drm_poisson", "fit_drm_beta", "fit_drm_lognormal")) {
    fit <- suppressWarnings(get(h)())
    sym <- symbolize(fit)
    html <- as_html_three_views(sym, id = paste0("test-sign-", h))
    expect_false(
      grepl("\\+ -[0-9.]", html),
      info = paste(h, "worked row still glues '+ -' before a negative coefficient")
    )
  }
})

# --- helpers for the lognormal additive_log worked-row checks -------------
.extract_additive_log_block <- function(html) {
  blocks <- regmatches(
    html,
    gregexpr("\\\\begin\\{aligned\\}.*?\\\\end\\{aligned\\}", html))[[1L]]
  hit <- blocks[grepl("varepsilon_\\{1\\}\\^\\{\\(\\\\log\\)\\}", blocks) &
                  grepl("times", blocks)]
  if (length(hit) == 0L) "" else hit[[1L]]
}

test_that("Lognormal worked-row 'with your numbers' equation closes at display precision", {
  # Punch-list #5. The row printed `1.55 = 1.96 + 0.131 x -0.167 + (-0.383)`
  # but the rounded RHS re-summed to 1.56, not the printed LHS 1.55 -- an
  # arithmetically FALSE '='. You cannot round a, b and a+b independently
  # and have them add up; the residual must be the balancing figure so the
  # printed numbers reconcile (families-audit option b).
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_lognormal())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-ln-close")

  block <- .extract_additive_log_block(html)
  expect_true(nzchar(block), info = "additive_log worked-row block not found")

  # v0.22.4 #155: the worked row now separates the linear-predictor build
  # (row 2, "mu_hat = <terms> \approx <value>") from the decomposition
  # (row 3). The LP-build row's displayed terms must re-sum to the
  # displayed mu_hat (the `\approx` value).
  rows <- strsplit(block, "\\\\\\\\")[[1L]]
  lp_row <- rows[grepl("hat\\\\mu_\\{1\\}", rows) & grepl("times", rows) &
                   grepl("approx", rows)]
  expect_length(lp_row, 1L)

  # RHS = terms between &= and \approx ; target = the value after \approx.
  rhs    <- sub("^.*&=\\s*(.*?)\\s*\\\\approx.*$", "\\1", lp_row)
  target <- sub("^.*\\\\approx\\s*(-?[0-9.]+).*$", "\\1", lp_row)
  expr <- gsub("\\\\times", "*", rhs, fixed = FALSE)
  expr <- gsub("\\\\,", "", expr, fixed = FALSE)
  expr <- gsub("[^0-9.+*()\\-]", "", expr)
  rhs_val <- eval(parse(text = expr), envir = new.env())

  expect_equal(formatC(rhs_val, digits = 3, format = "g"), target,
               info = paste0("Lognormal LP build does not reach mu_hat: terms re-sum to ",
                             rhs_val, " but mu_hat shown as ", target))
})

test_that("worked-row residual equals the true residual shown in the stacked matrix block", {
  # Punch-list #155: the worked-row residual must be the TRUE residual
  # (log(y_1) - mu_hat_1 on log scale; y_1 - mu_hat_1 on response scale),
  # identical to what the stacked matrix block displays, so the two views
  # agree on observation 1. (Earlier the worked row used a balancing
  # figure that diverged from the matrix block by a 3rd significant figure.)
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)

  # Lognormal (additive_log): residual on the log scale.
  fit_ln <- suppressWarnings(fit_drm_lognormal())
  sym_ln <- symbolize(fit_ln)
  ex_ln  <- sym_ln$expanded
  true_eps_ln <- formatC(log(ex_ln$y[[1L]]) - ex_ln$mu_hat[[1L]],
                         digits = 3, format = "g")
  html_ln <- as_html_three_views(sym_ln, id = "test-ln-resid")
  wr_ln   <- .extract_additive_log_block(html_ln)
  expect_true(grepl(true_eps_ln, wr_ln, fixed = TRUE),
              info = paste("Lognormal worked row should show the true residual",
                           true_eps_ln))
  # And the matrix block (panel-mat) shows the same value.
  pos <- regexpr("panel-mat", html_ln)
  panel_mat <- substr(html_ln, pos[[1L]], nchar(html_ln))
  expect_true(grepl(true_eps_ln, panel_mat, fixed = TRUE),
              info = "matrix block should show the same true residual")

  # Gaussian (additive_gaussian): residual on the response scale.
  fit_g <- suppressWarnings(fit_drm_location_scale())
  sym_g <- symbolize(fit_g)
  ex_g  <- sym_g$expanded
  true_eps_g <- formatC(ex_g$y[[1L]] - ex_g$mu_hat[[1L]], digits = 3, format = "g")
  html_g <- as_html_three_views(sym_g, id = "test-g-resid")
  # The worked-row decomposition underbrace residual must be the true one.
  expect_true(grepl(paste0("(", true_eps_g, ")"), html_g, fixed = TRUE),
              info = paste("Gaussian worked row should show the true residual",
                           true_eps_g))
})

test_that("Lognormal worked-row aligned block has uniform alignment-cell counts", {
  # Punch-list #8. The underbrace decomposition row carried 1 '&' where
  # the two rows above carry 2, so amsmath ragged the column and the
  # caption cell did not line up.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_lognormal())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-ln-grid")

  block <- .extract_additive_log_block(html)
  expect_true(nzchar(block), info = "additive_log worked-row block not found")
  # Strip the \begin/\end wrappers, split into rows, count & per row.
  body <- sub("^.*\\\\begin\\{aligned\\}", "", block)
  body <- sub("\\\\end\\{aligned\\}.*$", "", body)
  rows <- trimws(strsplit(body, "\\\\\\\\")[[1L]])
  rows <- rows[nzchar(rows)]
  amp_counts <- vapply(rows,
                       function(r) lengths(regmatches(r, gregexpr("&", r))),
                       integer(1L))
  expect_equal(length(unique(amp_counts)), 1L,
               info = paste("Ragged alignment: & counts per row =",
                            paste(amp_counts, collapse = ", ")))
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

test_that("Poisson worked-row likelihood drops the spurious ellipsis (one-parameter family)", {
  # Punch-list #3. Poisson is strictly one-parameter; the worked-row
  # likelihood line emitted `Poisson(\hat\mu_1, \ldots)`, implying a
  # hidden second parameter that does not exist and contradicting this
  # widget's own Tab 1 (Poisson(mu)) and matrix-tail caption.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_poisson())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-pois-lik")

  expect_false(
    grepl("\\\\mathrm\\{Poisson\\}\\(\\\\hat\\\\mu_\\{1\\}, \\\\ldots\\)", html),
    info = "Poisson likelihood must not carry a trailing ellipsis"
  )
  expect_true(
    grepl("\\\\mathrm\\{Poisson\\}\\(\\\\hat\\\\mu_\\{1\\}\\)", html),
    info = "Poisson likelihood should read Poisson(mu_hat_1) with no second argument"
  )
})

test_that("Beta worked-row likelihood shows mean-precision shapes, not Beta(mu, ...)", {
  # Punch-list #4. Tab 1 of the Beta widget writes the full
  # mean-precision form Beta(mu_i sigma_i, (1-mu_i) sigma_i); the Tab 3
  # worked-row likelihood collapsed it to Beta(\hat\mu_1, \ldots),
  # hiding the precision the widget derives one line below.
  skip_if_not_installed("drmTMB")
  source(test_path("helper-drmtmb-fits.R"), local = TRUE)
  fit <- suppressWarnings(fit_drm_beta())
  sym <- symbolize(fit)
  html <- as_html_three_views(sym, id = "test-beta-lik")

  expect_false(
    grepl("\\\\mathrm\\{Beta\\}\\(\\\\hat\\\\mu_\\{1\\}, \\\\ldots\\)", html),
    info = "Beta likelihood must not collapse to Beta(mu_hat_1, ...)"
  )
  expect_true(
    grepl("\\(1 - \\\\hat\\\\mu_\\{1\\}\\)\\s*\\\\hat\\\\sigma_\\{1\\}", html, perl = TRUE),
    info = "Beta likelihood should show the (1 - mu_hat_1) sigma_hat_1 precision shape"
  )
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

test_that("worked-row inverse-link operator follows the actual link, not the family", {
  # The back-transform mu = f(eta) shown in Tab 3 is derived from the LINK, not
  # the family name. Previously it was hard-coded by family (gamma -> exp,
  # binomial -> logistic), so a non-default link showed the wrong operator.
  set.seed(1); n <- 80
  d <- data.frame(x = rnorm(n))
  d$pos <- rgamma(n, shape = 2, rate = exp(-(0.5 + 0.3 * d$x)))
  d$bin <- rbinom(n, 1, plogis(0.2 + 0.5 * d$x))

  # Gamma defaults to the inverse link: mu = 1/eta, NOT exp(eta).
  h_inv <- as_html_three_views(symbolize(glm(pos ~ x, Gamma("inverse"), d)))
  expect_true(grepl("1/(\\hat\\eta_{1}", h_inv, fixed = TRUE))
  expect_false(grepl("\\exp(\\hat\\eta_{1}", h_inv, fixed = TRUE))

  # Gamma with an explicit log link still shows exp.
  h_log <- as_html_three_views(symbolize(glm(pos ~ x, Gamma("log"), d)))
  expect_true(grepl("\\exp(\\hat\\eta_{1}", h_log, fixed = TRUE))

  # binomial(probit) is the normal CDF Phi, not the logistic.
  h_prb <- as_html_three_views(symbolize(glm(bin ~ x, binomial("probit"), d)))
  expect_true(grepl("\\Phi(\\hat\\eta_{1}", h_prb, fixed = TRUE))
  expect_false(grepl("logistic}(\\hat\\eta_{1}", h_prb, fixed = TRUE))
})
