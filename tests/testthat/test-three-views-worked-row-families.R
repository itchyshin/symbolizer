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

  # Pull the "with your numbers" row: starts with a decimal, has &=, \times.
  rows <- strsplit(block, "\\\\\\\\")[[1L]]
  num_row <- rows[grepl("&=", rows) & grepl("times", rows)]
  expect_length(num_row, 1L)

  # LHS = the number before &= ; RHS = between &= and the &\quad caption.
  lhs <- sub("^[^0-9.-]*(-?[0-9.]+)\\s*&=.*$", "\\1", num_row)
  rhs <- sub("^.*&=\\s*(.*?)\\s*&\\\\quad.*$", "\\1", num_row)
  # Turn the displayed RHS into an evaluable arithmetic expression.
  expr <- gsub("\\\\times", "*", rhs, fixed = FALSE)
  expr <- gsub("\\\\,", "", expr, fixed = FALSE)
  expr <- gsub("[^0-9.+*()\\-]", "", expr)
  rhs_val <- eval(parse(text = expr), envir = new.env())

  # The reader-summed RHS, formatted as the renderer formats numbers,
  # must equal the printed LHS string.
  expect_equal(formatC(rhs_val, digits = 3, format = "g"), lhs,
               info = paste0("Lognormal worked row does not close: LHS=", lhs,
                             " but RHS re-sums to ", rhs_val))
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
