test_that("as_html_three_views returns invisible character HTML", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_type(out, "character")
  expect_length(out, 1L)
})

test_that("HTML contains all three tab labels and panels", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  # v0.19 pedagogical reorder: Index first, then Matrix, then
  # Equations with data (was "Matrix with data" in 0.19.0; renamed in
  # 0.19.1 because Tab 3 now carries multiple equations -- scalar +
  # matrix, mu + sigma -- all populated with data).
  expect_match(html, "1\\. Index")
  expect_match(html, "2\\. Matrix")
  expect_match(html, "3\\. Equations with data")
  expect_match(html, "data-panel=\"eq\"")
  expect_match(html, "data-panel=\"idx\"")
  expect_match(html, "data-panel=\"mat\"")
})

test_that("equation panel uses matrix-form notation (bold lowercase vectors)", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i"))
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "\\\\boldsymbol\\{\\\\mu\\}")
  expect_match(html, "\\\\mathbf\\{w\\}")
})

test_that("index panel uses per-observation notation", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "\\\\mu_i")
  expect_match(html, "T_i")
})

test_that("matrix panel shows actual numeric data in bmatrix LaTeX", {
  # v0.19: matrix block now emits MathJax bmatrix LaTeX (not pre-formatted
  # text). The panel must contain (a) the bmatrix environment, (b) the
  # response vector w, (c) the coefficient vector beta_hat, and (d) the
  # residual vector eps_hat with its `(residual)` annotation.
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i"))
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "\\\\begin\\{bmatrix\\}")
  expect_match(html, "\\\\boldsymbol\\{\\\\beta\\}")
  expect_match(html, "\\\\hat\\{\\\\boldsymbol\\{\\\\varepsilon\\}\\}")
  # observed label on the response vector
  expect_match(html, "\\(observed\\)")
  # residual label on the residual vector
  expect_match(html, "\\(residual\\)")
})

test_that("matrix panel includes Z and u when RE is present", {
  # v0.19: random-effect design matrix labelled `\mathbf{Z}_{n x g}`
  # (Noether's audit -- sigma-submodel design renamed to X_sigma so Z is
  # free for random effects). BLUP vector labelled `\hat{\mathbf{u}}` with
  # a `(BLUP)` annotation.
  fit_re <- fit_drm_with_re()
  sym <- symbolize(fit_re, symbols = c(body_mass = "W_i"))
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "\\\\mathbf\\{Z\\}_\\{")
  expect_match(html, "\\\\hat\\{\\\\mathbf\\{u\\}\\}_\\{")
  expect_match(html, "\\(BLUP\\)")
})

test_that("default method errors with pointer to symbolize()", {
  expect_error(as_html_three_views(list()), "no method")
})

test_that("CSS and JS are embedded inline", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "<style>")
  expect_match(html, "<script>")
  expect_match(html, "\\.sym-tab")
})

test_that("emitted JS preserves the escaped CSS selector quotes", {
  # Regression for v0.18.1: the JS source was wrapped in an R
  # single-quoted string and contained `querySelectorAll("[role=\"tab\"]")`.
  # R's string parser strips `\"` -> `"`, which corrupted the JS to
  # `querySelectorAll("[role="tab"]")` -- a syntax error that
  # silently disabled tab switching on the rendered page. The fix
  # is a raw R string around the JS body; this test guards against
  # any regression to plain-quoted strings.
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  # The PROPER escaped form must appear:
  expect_match(html,
               'querySelectorAll\\("\\[role=\\\\"tab\\\\"\\]"\\)',
               perl = TRUE)
  expect_match(html,
               'querySelectorAll\\("\\[role=\\\\"tabpanel\\\\"\\]"\\)',
               perl = TRUE)
  # And the BROKEN un-escaped form must not:
  expect_false(grepl('querySelectorAll("[role="tab"]")', html, fixed = TRUE))
  expect_false(grepl('querySelectorAll("[role="tabpanel"]")', html, fixed = TRUE))
})

test_that("widget exposes WAI-ARIA tabs roles", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "role=\"tablist\"", fixed = TRUE)
  expect_match(html, "role=\"tab\"", fixed = TRUE)
  expect_match(html, "role=\"tabpanel\"", fixed = TRUE)
  expect_match(html, "aria-controls=", fixed = TRUE)
  expect_match(html, "aria-labelledby=", fixed = TRUE)
})

test_that("exactly one tab is aria-selected=true and the rest are false", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  count_true  <- length(gregexpr("aria-selected=\"true\"", html, fixed = TRUE)[[1L]])
  count_false <- length(gregexpr("aria-selected=\"false\"", html, fixed = TRUE)[[1L]])
  expect_equal(count_true, 1L)
  expect_equal(count_false, 2L)
})

test_that("tabs use buttons with a roving tabindex", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "<button[^>]*role=\"tab\"")
  count_tabindex0  <- length(gregexpr("tabindex=\"0\"",  html, fixed = TRUE)[[1L]])
  count_tabindexm1 <- length(gregexpr("tabindex=\"-1\"", html, fixed = TRUE)[[1L]])
  expect_gte(count_tabindex0, 1L)
  expect_gte(count_tabindexm1, 2L)
})

test_that("widget includes a keyboard skip-link", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "class=\"sym-skip\"", fixed = TRUE)
  expect_match(html, "Skip three-views widget", fixed = TRUE)
})

test_that("active-tab signal is not color-only (marker glyph present)", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "sym-tab-marker", fixed = TRUE)
  expect_match(html, "&#9656;", fixed = TRUE)
})

test_that("matrix panel includes a screen-reader summary", {
  # v0.19: the matrix block no longer uses `<pre class=\"sym-matrix\">`
  # (which the v0.18.x impl used for column-padded plain text). It now
  # uses `<div class=\"sym-eq\">` to host MathJax bmatrix equations. The
  # sym-sr-only summary is still there for assistive tech.
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  html <- withr::with_output_sink(tempfile(), as_html_three_views(sym))
  expect_match(html, "class=\"sym-sr-only\"", fixed = TRUE)
  expect_match(html, "Matrix-form expansion", fixed = TRUE)
  # No more <pre class=sym-matrix> — that's intentional in v0.19.
  expect_false(grepl("<pre class=\"sym-matrix\"", html, fixed = TRUE))
})

test_that("matrix summary mentions the RE contribution only when RE is present", {
  # v0.21.4 update: the matrix summary (a sym-sr-only block read by
  # screen readers) used to mention "Z_g" by name. Since the renderer
  # now drops Z from the visible stacked block when n_obs ==
  # n_distinct_levels (one obs per level), the summary was updated to
  # say "the predicted random-effect contribution to each observation
  # is also shown" without naming Z. This test was updated to the new
  # contract: presence of RE prose in the summary, not a literal Z_g.
  fit_re <- fit_drm_with_re()
  sym_re <- symbolize(fit_re, symbols = c(body_mass = "W_i"))
  html_re <- withr::with_output_sink(tempfile(), as_html_three_views(sym_re))
  sr_block_re <- regmatches(
    html_re,
    regexpr("class=\"sym-sr-only\">[^<]*</span>", html_re)
  )
  expect_match(sr_block_re, "random-effect", fixed = TRUE)

  fit_fe <- fit_drm_location_scale()
  sym_fe <- symbolize(fit_fe)
  html_fe <- withr::with_output_sink(tempfile(), as_html_three_views(sym_fe))
  sr_block_fe <- regmatches(
    html_fe,
    regexpr("class=\"sym-sr-only\">[^<]*</span>", html_fe)
  )
  expect_false(grepl("random-effect", sr_block_fe, fixed = TRUE))
})

# Audit M1: the location-scale biology gloss must read sigma-varies from
# the MODEL STRUCTURE (the sigma submodel formula), not only from the
# expanded numeric arrays. A fit with `sigma ~ predictor` must say the
# residual SD varies; a plain homoscedastic fit must say it is constant.
test_that("biology gloss detects sigma-varies from model structure (audit M1)", {
  sv <- getFromNamespace("three_views_sigma_varies", "symbolizer")
  gloss <- getFromNamespace("three_views_biology_gloss", "symbolizer")

  sym_ls <- symbolize(fit_drm_location_scale())  # sigma ~ temperature
  expect_true(sv(sym_ls))
  expect_false(grepl("constant", gloss(sym_ls)))

  # Audit scenario: a real sigma submodel but X_sigma not surfaced in the
  # expanded arrays -- structure-based detection must still fire.
  sym_no_xs <- sym_ls
  sym_no_xs$expanded$X_sigma <- NULL
  sym_no_xs$expanded$gamma   <- NULL
  expect_true(sv(sym_no_xs))
  expect_false(grepl("constant", gloss(sym_no_xs)))

  # A plain homoscedastic Gaussian (no RE, no sigma submodel) still says
  # the residual SD is constant.
  sym_lm <- symbolize(stats::lm(mpg ~ wt, data = mtcars))
  expect_false(sv(sym_lm))
  expect_match(gloss(sym_lm), "constant")
})

# Audit M3: the scale-submodel design matrix is \mathbf{X}_\sigma in BOTH
# Tab 2 (the matrix equation) and the symbol glossary; \mathbf{Z} is
# reserved for the random-effects design (Z*u). The same fit must never
# show \mathbf{Z} meaning the sigma design.
test_that("scale-submodel design is X_sigma, not Z, across tabs (audit M3)", {
  sym <- symbolize(fit_drm_with_re())  # mu ~ temp + (1|g), sigma ~ temp
  comp <- sym$components
  sig_eq <- comp$equation_matrix[comp$kind == "linear_predictor" &
                                   comp$submodel == "sigma"]
  expect_match(sig_eq, "\\mathbf{X}_{\\sigma} \\boldsymbol{\\gamma}",
               fixed = TRUE)
  expect_false(grepl("\\mathbf{Z} \\boldsymbol{\\gamma}", sig_eq, fixed = TRUE))
  # Glossary: the sigma design is X_sigma; Z (if present) is the RE design.
  des <- sym$symbol_dictionary[sym$symbol_dictionary$role == "design_matrix", ]
  expect_true("\\mathbf{X}_{\\sigma}" %in% des$symbol_matrix)
  expect_false("\\mathbf{Z}" %in% des$symbol_matrix)
})

# Audit M4: a fit with a single constant residual SD (no scale submodel)
# uses the unindexed scalar \sigma, not \sigma_i.
test_that("constant-SD fits use unindexed sigma in the glossary (audit M4)", {
  for (fit in list(stats::lm(mpg ~ wt, data = mtcars))) {
    sym <- symbolize(fit)
    r <- sym$symbol_dictionary[sym$symbol_dictionary$role == "residual_sd", ]
    expect_equal(nrow(r), 1L)
    expect_equal(r$symbol, "\\sigma")
    expect_false("\\sigma_i" %in% sym$symbol_dictionary$symbol)
  }
})

# Audit M7: when the structured covariance matrix is the all-nodes
# augmented phylogenetic block (non-unit diagonal -- internal-node rows
# have self-covariance < 1), the caption must NOT call it "the correlation
# matrix A" with an implied unit diagonal. A tips-only (unit-diagonal)
# matrix keeps the "correlation matrix" wording.
test_that("phylo matrix caption distinguishes augmented vs correlation (audit M7)", {
  blk <- getFromNamespace("three_views_matrix_block", "symbolizer")
  sym <- symbolize(fit_drm_location_scale())
  k <- 8L

  # All-nodes augmented: internal-node rows have diagonal < 1.
  A_aug <- diag(k)
  diag(A_aug)[1:3] <- c(0.6, 0.7, 0.55)
  sym_aug <- sym
  sym_aug$expanded$M <- A_aug
  sym_aug$metadata$phylo_representation <- "all_nodes"
  html_aug <- withr::with_output_sink(tempfile(), blk(sym_aug))
  expect_match(html_aug, "internal node")
  expect_false(grepl("phylogenetic correlation matrix", html_aug, fixed = TRUE))

  # Tips-only (unit diagonal): keep the "correlation matrix" wording.
  A_corr <- diag(k)
  sym_corr <- sym
  sym_corr$expanded$M <- A_corr
  sym_corr$metadata$phylo_representation <- "tips_only"
  html_corr <- withr::with_output_sink(tempfile(), blk(sym_corr))
  expect_match(html_corr, "phylogenetic correlation matrix")
  expect_false(grepl("internal node", html_corr, fixed = TRUE))
})
