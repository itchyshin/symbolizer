#' Three-views HTML rendering of a symbolized_model
#'
#' @description
#' Returns a single self-contained HTML string with three tabs over the same
#' fit:
#'
#' 1. **Equation** -- matrix-form structural equations.
#' 2. **Index** -- per-observation equations.
#' 3. **Matrix (with data)** -- the actual numeric arrays from the fit, with
#'    head + tail rows visible and `...` in the middle.
#'
#' Designed to be `cat()`-ed inside an Rmd / Quarto chunk with
#' `results = 'asis'`. The host document supplies math rendering (MathJax /
#' KaTeX via pandoc); this function emits semantic HTML, inline CSS, and a
#' small tab-switching script.
#'
#' @param x A `symbolized_model` with `$expanded` populated.
#' @param head Number of leading **rows** to show in the matrix view
#'   (Tab 3 "Equations with data") before the `\\vdots` ellipsis.
#'   Default `5`. Reasonable range 2--10; larger values produce taller
#'   widgets.
#' @param tail Number of trailing **rows** to show in the matrix view
#'   after the `\\vdots`. Default `2`. Together with `head`, controls
#'   how much per-observation data is visible: total rows shown =
#'   `head + tail + 1` ellipsis row (or fewer if `n_obs` is small
#'   enough to show all rows).
#' @param head_cols Number of leading **columns** to show in any matrix
#'   that has more than `head_cols + tail_cols` columns (e.g. the
#'   `Z`-matrix for a 60-species fit). Default `5`. Smart-truncation
#'   prefers non-zero columns within the visible row band.
#' @param tail_cols Number of trailing **columns** to show after the
#'   `\\cdots` ellipsis. Default `2`.
#' @param id A short identifier so multiple panels can co-exist on one page.
#' @param standalone If `TRUE`, wrap the fragment in a full HTML document
#'   with a MathJax CDN bootstrap so the file renders math when opened
#'   directly in a browser (`file://...`). Default `FALSE` returns the
#'   bare fragment for embedding in an Rmd / pkgdown / Quarto page where
#'   the host document already loads MathJax.
#' @param file If non-`NULL`, also write the HTML to this path. Returned
#'   value is unchanged.
#' @param ... Reserved for future use.
#'
#' @return A character vector (HTML), invisible.
#' @export
as_html_three_views <- function(x, head = 5L, tail = 2L,
                                head_cols = 5L, tail_cols = 2L,
                                id = "sym", standalone = FALSE,
                                file = NULL, ...) {
  UseMethod("as_html_three_views")
}

#' @export
as_html_three_views.default <- function(x, ...) {
  cli::cli_abort(c(
    "{.fn as_html_three_views} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
as_html_three_views.symbolized_model <- function(x, head = 5L, tail = 2L,
                                                  head_cols = 5L,
                                                  tail_cols = 2L,
                                                  id = "sym",
                                                  standalone = FALSE,
                                                  file = NULL, ...) {
  eq_lines  <- x$components$equation_matrix
  idx_lines <- x$components$equation
  has_re <- !is.null(x$expanded) && !is.null(x$expanded$Z_g)
  matrix_block   <- three_views_matrix_block(x, head = head, tail = tail,
                                              head_cols = head_cols,
                                              tail_cols = tail_cols)
  matrix_summary <- three_views_matrix_summary(has_re)

  uid <- paste0("sym-", gsub("[^a-zA-Z0-9]", "", id), "-",
                as.integer(Sys.time()))
  # Historical id naming: `idx` = Tab 1 (per-observation index form);
  # `eq` = Tab 2 (matrix-equation form — `eq` stands for the *equation*
  # form, not "equations with data"); `mat` = Tab 3 (matrix expansion
  # *with numbers*). The labels read as "Index / Matrix / Equations with
  # data" and the IDs read as "idx / eq / mat" — V1-D8 flagged that
  # `-tab-eq` showing matrix content and `-tab-mat` showing equations
  # reads as swapped. Kept as-is for external-anchor stability (URLs
  # like `#sym-foo-tab-eq` are user-facing); see V1 audit for the
  # historical naming rationale.
  tab_eq  <- paste0(uid, "-tab-eq")
  tab_idx <- paste0(uid, "-tab-idx")
  tab_mat <- paste0(uid, "-tab-mat")
  pan_eq  <- paste0(uid, "-panel-eq")
  pan_idx <- paste0(uid, "-panel-idx")
  pan_mat <- paste0(uid, "-panel-mat")
  end_id  <- paste0(uid, "-end")

  css <- three_views_css()
  js  <- three_views_js(uid)

  # Symbol gloss for each panel, in the notation that panel uses. The
  # tab order below is pedagogical: per-observation (familiar) -> matrix
  # form (the abstraction) -> matrix form populated with the data
  # (concrete grounding). This walks a biologist from the language they
  # already read fluently to the matrix algebra every textbook past
  # chapter 4 switches to, and shows the abstraction is the same model
  # in different notation.
  gloss_index   <- three_views_symbol_gloss(x, notation = "index")
  gloss_matrix  <- three_views_symbol_gloss(x, notation = "matrix")
  # One-sentence biology / whole-model reading per tab. Family-aware.
  # Returns "" if no template applies. Observational language only --
  # never "the effect of X on Y". Darwin's Move A from the v0.19 design
  # pass; the maintainer's vision is "help biologists connect statistical
  # results to biological phenomena" and the matrix algebra teaching needs
  # one sentence anchoring it to the model's whole-system story.
  bio_gloss <- three_views_biology_gloss(x)
  # v0.22.4 #6: the response-scale coefficient reading, INSIDE the widget
  # (Tab 1, where coefficients are introduced) so it travels with PDF
  # export and a Methods-section paste instead of being orphaned in the
  # surrounding article prose.
  coef_reading_txt <- three_views_coef_reading(tryCatch(x$model$family,
                                                        error = function(e) NULL))
  coef_gloss <- if (nzchar(coef_reading_txt)) {
    paste0("  <p class=\"sym-biology\"><strong>Coefficient reading.</strong> ",
           coef_reading_txt, "</p>\n")
  } else ""
  # v0.22.4 #11: per-family numeric diagnostic (e.g. Beta U-shape).
  family_diagnostic <- three_views_family_diagnostic(x)
  # Variance-components surface (S3): "where does the variation live?" panel,
  # placed beneath the random-effects glossary. "" for fits without RE.
  variance_panel <- three_views_variance_panel(x)
  idx_panel <- paste0(
    "<div class=\"sym-panel sym-active\" role=\"tabpanel\" id=\"", pan_idx,
    "\" aria-labelledby=\"", tab_idx, "\" data-panel=\"idx\" tabindex=\"0\">\n",
    "  <p class=\"sym-caption\">What happens for each observation <em>i</em> -- the per-individual reading.</p>\n",
    bio_gloss,
    coef_gloss,
    family_diagnostic,
    "  <div class=\"sym-eq\">$$\\begin{aligned}\n",
    paste0(vapply(idx_lines, align_at, character(1L)), collapse = " \\\\\n"),
    "\n\\end{aligned}$$</div>\n",
    gloss_index,
    variance_panel,
    "</div>\n"
  )
  eq_panel <- paste0(
    "<div class=\"sym-panel\" role=\"tabpanel\" id=\"", pan_eq,
    "\" aria-labelledby=\"", tab_eq, "\" data-panel=\"eq\" hidden tabindex=\"0\">\n",
    "  <p class=\"sym-caption\">The same model in matrix form -- the structural contract every textbook past chapter 4 switches to.</p>\n",
    bio_gloss,
    "  <div class=\"sym-eq\">$$\\begin{aligned}\n",
    paste0(vapply(eq_lines, align_at, character(1L)), collapse = " \\\\\n"),
    "\n\\end{aligned}$$</div>\n",
    gloss_matrix,
    "</div>\n"
  )
  # Implied-covariance blocks (gllvm two-tier widget). For a Widget-1
  # gllvm fit (between only) emit just the B-tier block; for a Widget-2
  # gllvm fit (two-tier) emit B then W, plus a per-trait repeatability
  # row. The latex_implied_cov_block() emitter returns NULL when the
  # matrices are absent, so the conditional below is naturally inert
  # for any non-gllvm fit.
  ex <- x$expanded
  sigma_B_block <- latex_implied_cov_block(
    tier = "B",
    Sigma = ex$Sigma_B, Lambda = ex$Lambda_B, Psi = ex$Psi_B
  )
  sigma_W_block <- latex_implied_cov_block(
    tier = "W",
    Sigma = ex$Sigma_W, Lambda = ex$Lambda_W, Psi = ex$Psi_W
  )
  implied_cov_html <- ""
  # v0.22.1.2: marginal-covariance decomposition for meta-analytic and
  # multilevel fits. Mutually exclusive with the gllvm Sigma_B / Sigma_W
  # path -- gllvm fits never carry `meta_analysis` in detected_signals
  # and never expose `metadata$structured_matrix_for_group`, so this
  # block fires only on the meta-analysis / multilevel widget path.
  marginal_block <- latex_marginal_cov_block(x)
  if (!is.null(marginal_block)) {
    has_meta <- !is.null(x$metadata$detected_signals) &&
                "meta_analysis" %in% x$metadata$detected_signals
    caption <- if (has_meta) {
      paste0(
        "Marginal covariance of the response decomposes into the ",
        "(known) sampling tier plus one term per random-effect group. ",
        "Structured tiers carry their correlation matrix; ",
        "unstructured tiers use the identity via $\\mathbf{Z}_g\\mathbf{Z}_g^{\\!\\top}$:")
    } else {
      paste0(
        "Marginal covariance of the response is the sum of one term ",
        "per random-effect group:")
    }
    implied_cov_html <- paste0(implied_cov_html,
      "<p class=\"sym-caption\" style=\"font-size:0.95em;color:#374151\">",
      caption,
      "</p>\n<div class=\"sym-eq\">", marginal_block, "</div>\n")
  }
  if (!is.null(sigma_B_block)) {
    implied_cov_html <- paste0(implied_cov_html,
      "<p class=\"sym-caption\" style=\"font-size:0.95em;color:#374151\">",
      "Implied between-individual trait covariance ",
      "$\\boldsymbol{\\Sigma}_B$ ",
      "decomposes into a shared low-rank part and per-trait uniquenesses:",
      "</p>\n<div class=\"sym-eq\">", sigma_B_block, "</div>\n")
  }
  if (!is.null(sigma_W_block)) {
    implied_cov_html <- paste0(implied_cov_html,
      "<p class=\"sym-caption\" style=\"font-size:0.95em;color:#374151\">",
      "Implied within-individual trait covariance ",
      "$\\boldsymbol{\\Sigma}_W$ ",
      "(replaces the $\\sigma^2_\\epsilon$ row-level residual in this fit):",
      "</p>\n<div class=\"sym-eq\">", sigma_W_block, "</div>\n")
    # Per-trait repeatability row when both tiers present.
    if (!is.null(ex$Repeatability)) {
      R_vec <- ex$Repeatability
      R_txt <- paste(vapply(R_vec, function(v)
        formatC(v, digits = 3, format = "g"), character(1L)),
        collapse = ", ")
      implied_cov_html <- paste0(implied_cov_html,
        "<p class=\"sym-caption\" style=\"font-size:0.95em;color:#374151\">",
        "Per-trait repeatability $R_t = (\\Sigma_B)_{tt} / ",
        "[(\\Sigma_B)_{tt} + (\\Sigma_W)_{tt}]$: $[",
        R_txt,
        "]$. Each $R_t$ is the share of trait $t$'s total variance that ",
        "lives at the <em>between-individual</em> tier.",
        "</p>\n")
    }
  }
  mat_panel <- paste0(
    "<div class=\"sym-panel\" role=\"tabpanel\" id=\"", pan_mat,
    "\" aria-labelledby=\"", tab_mat, "\" data-panel=\"mat\" hidden tabindex=\"0\">\n",
    "  <p class=\"sym-caption\">The same matrix equation, with your actual numbers stacked inside the brackets -- what the computer multiplies. Showing first ", head, " and last ", tail, " rows of n = ", x$model$n_obs, ".</p>\n",
    bio_gloss,
    "  <span class=\"sym-sr-only\">", matrix_summary, "</span>\n",
    matrix_block,
    implied_cov_html,
    "</div>\n"
  )

  # Tab marker glyph. Followed by a hair space + thin space (U+200A + U+2009)
  # so visual gap between `▸` and `1.` matches typographic convention. The
  # CSS `margin-right` on `.sym-tab-marker` is a fallback in case pandoc
  # strips the literal Unicode whitespace.
  marker <- "<span class=\"sym-tab-marker\" aria-hidden=\"true\" style=\"margin-right:0.35em\">&#9656;</span>"
  # IMPORTANT: never indent inner HTML lines with 4+ leading spaces.
  # Markdown processors (pandoc, commonmark) treat any line with 4+
  # leading spaces as the start of an indented code block, which
  # breaks the surrounding HTML block and emits the affected lines
  # as escaped text inside `<pre><code>`. The three `<button>` lines
  # below previously used 4-space indentation and silently leaked
  # raw tags into the rendered vignette / pkgdown article. Keep all
  # nested HTML at 0 or 2 spaces.
  html <- paste0(
    "<style>", css, "</style>\n",
    "<div class=\"sym-tabs\" id=\"", uid, "\">\n",
    "<a class=\"sym-skip\" href=\"#", end_id, "\">Skip three-views widget</a>\n",
    "<div class=\"sym-tablist\" role=\"tablist\" aria-label=\"Three views of the model\">\n",
    "<button type=\"button\" class=\"sym-tab sym-active\" role=\"tab\"",
    " id=\"", tab_idx, "\" aria-controls=\"", pan_idx, "\"",
    " aria-selected=\"true\" tabindex=\"0\" data-tab=\"idx\">",
    marker, "1. Index</button>\n",
    "<button type=\"button\" class=\"sym-tab\" role=\"tab\"",
    " id=\"", tab_eq, "\" aria-controls=\"", pan_eq, "\"",
    " aria-selected=\"false\" tabindex=\"-1\" data-tab=\"eq\">",
    marker, "2. Matrix</button>\n",
    "<button type=\"button\" class=\"sym-tab\" role=\"tab\"",
    " id=\"", tab_mat, "\" aria-controls=\"", pan_mat, "\"",
    " aria-selected=\"false\" tabindex=\"-1\" data-tab=\"mat\">",
    marker, "3. Equations with data</button>\n",
    "</div>\n",
    idx_panel, eq_panel, mat_panel,
    "</div>\n",
    "<span id=\"", end_id, "\" tabindex=\"-1\"></span>\n",
    "<script>", js, "</script>\n"
  )
  if (isTRUE(standalone)) {
    html <- three_views_standalone_wrap(html, title = "symbolizer three views")
  }
  if (!is.null(file)) {
    writeLines(html, con = file)
    if (!isTRUE(standalone)) {
      cli::cli_warn(c(
        "Wrote a fragment to {.path {file}} but {.arg standalone} is FALSE.",
        i = "Opening this file directly in a browser will NOT render math.",
        i = "Pass {.code standalone = TRUE} for a self-contained HTML page."
      ))
    }
    return(invisible(html))
  }
  cat(html)
  invisible(html)
}

#' PDF rendering of a symbolized_model in three stacked sections
#'
#' @description
#' Paper-ready PDF counterpart to [as_html_three_views()]. The same three
#' "views" of one fitted model, laid out vertically as three sections on
#' one PDF page (no tabs):
#'
#' 1. **Index form** -- the per-observation equations.
#' 2. **Matrix form** -- the same equations in matrix notation.
#' 3. **Worked observation** -- the index-form equations evaluated at
#'    observation i = 1 of the data, showing the coefficient estimates
#'    plugged in and the predicted / residual decomposition.
#'
#' Rendered via `rmarkdown::render()` with `output_format = "pdf_document"`;
#' a working LaTeX install (TinyTeX or system TeX) is required.
#'
#' The wide matrix-of-numbers view from the HTML widget's third tab is
#' deliberately not included -- on PDF the bmatrix of n x p numbers
#' overflows a portrait A4 page. The worked-row at i = 1 carries the
#' same teaching content in a fits-on-one-page form.
#'
#' @param x A `symbolized_model`.
#' @param file Output path (`.pdf`). Required.
#' @param title Optional document title. Defaults to a short auto-title
#'   built from the fit's class and response.
#' @param head Number of leading rows shown in any matrix block before
#'   the `\\vdots` ellipsis (default `5`).
#' @param tail Number of trailing rows shown after the `\\vdots` (default `2`).
#' @param head_cols Number of leading columns shown in any matrix block
#'   with more than `head_cols + tail_cols` columns (default `5`).
#'   Smart-truncation prefers non-zero columns within the visible row band.
#' @param tail_cols Number of trailing columns shown after the `\\cdots`
#'   ellipsis (default `2`).
#' @param keep_tex If `TRUE`, keep the intermediate `.tex` next to the PDF
#'   for inspection. Default `FALSE`.
#' @param ... Passed to `rmarkdown::render()`.
#'
#' @return The path to the rendered PDF (invisibly).
#' @export
as_pdf_three_views <- function(x, file, title = NULL,
                               head = 5L, tail = 2L,
                               head_cols = 5L, tail_cols = 2L,
                               keep_tex = FALSE, ...) {
  UseMethod("as_pdf_three_views")
}

#' @export
as_pdf_three_views.default <- function(x, ...) {
  cli::cli_abort(c(
    "{.fn as_pdf_three_views} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
as_pdf_three_views.symbolized_model <- function(x, file, title = NULL,
                                                 head = 5L, tail = 2L,
                                                 head_cols = 5L,
                                                 tail_cols = 2L,
                                                 keep_tex = FALSE, ...) {
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg rmarkdown} is required for {.fn as_pdf_three_views}.",
      i = "Install with {.code install.packages(\"rmarkdown\")}."
    ))
  }
  if (missing(file) || is.null(file) || !nzchar(file)) {
    cli::cli_abort("{.arg file} is required and must be a non-empty path.")
  }
  # Build an absolute output path BEFORE handing it to rmarkdown::render().
  # On macOS, normalizePath(<relative>, mustWork = FALSE) returns the
  # relative string unchanged when the file doesn't exist (no leading
  # working-directory expansion). Combined with rmarkdown's habit of
  # interpreting `output_file` relative to the input Rmd's location --
  # which we put in tempdir() -- the PDF silently lands in a tempdir
  # and the vignette's `<a href="fig-meta-phylo.pdf">` link goes 404.
  # Florence caught this on the v0.21.2 vignette render.
  if (!startsWith(file, "/") && !grepl("^[A-Za-z]:[\\/]", file)) {
    file <- file.path(getwd(), file)
  }
  file <- normalizePath(file, mustWork = FALSE)
  if (is.null(title) || !nzchar(title)) {
    title <- sprintf("Three views of a %s model (response: %s)",
                     x$model$class, x$model$response)
  }
  rmd_path <- tempfile(fileext = ".Rmd")
  rmd_body <- pdf_three_views_rmd_body(x, head = head, tail = tail,
                                       head_cols = head_cols,
                                       tail_cols = tail_cols,
                                       title = title, keep_tex = keep_tex)
  writeLines(rmd_body, rmd_path)
  out <- rmarkdown::render(
    rmd_path,
    output_file = file,
    quiet = TRUE,
    ...
  )
  invisible(out)
}

# Build the PDF Rmd body as a character vector. Extracted from
# as_pdf_three_views() so the PDF content is testable without a LaTeX
# toolchain and so the coefficient-reading callout (#6) can be verified
# to travel into the PDF (PDF/HTML parity).
pdf_three_views_rmd_body <- function(x, head = 5L, tail = 2L,
                                     head_cols = 5L, tail_cols = 2L,
                                     title = NULL, keep_tex = FALSE) {
  if (is.null(title) || !nzchar(title)) {
    title <- sprintf("Three views of a %s model (response: %s)",
                     x$model$class, x$model$response)
  }
  latex_index  <- as_latex(x, notation = "index")
  latex_matrix <- as_latex(x, notation = "matrix")
  worked <- pdf_three_views_worked_row(x)
  # v0.22.4 #6: response-scale coefficient reading, carried into the PDF
  # so it survives export (it used to live only in the article prose).
  coef_txt <- three_views_coef_reading(
    tryCatch(x$model$family, error = function(e) NULL))
  coef_line <- if (nzchar(coef_txt)) {
    c(sprintf("_**Coefficient reading.** %s_", coef_txt), "")
  } else character(0L)
  c(
    "---",
    sprintf("title: \"%s\"", gsub("\"", "'", title, fixed = TRUE)),
    "geometry: margin=2cm",
    "output:",
    "  pdf_document:",
    sprintf("    keep_tex: %s", if (isTRUE(keep_tex)) "true" else "false"),
    "    latex_engine: pdflatex",
    "header-includes:",
    # `bm` would give bold-italic math, but we use `\boldsymbol` from
    # amsbsy (loaded by amsmath), so the `bm` package isn't needed.
    # Dropped because tinytex's minimal install on GitHub Actions does
    # not include `bm.sty` by default and the auto-install can fail.
    "  - \\usepackage{amsmath, amssymb}",
    "---",
    "",
    "# 1. Index form",
    "",
    "_The per-observation reading: what happens for each row $i$ of your data._",
    "",
    "$$",
    latex_index,
    "$$",
    "",
    coef_line,
    "# 2. Matrix form",
    "",
    "_The same model in matrix notation. The structural contract every textbook past chapter 4 switches to._",
    "",
    "$$",
    latex_matrix,
    "$$",
    "",
    "# 3. Worked observation (i = 1)",
    "",
    "_The index-form equations evaluated at the first observation of your data, with coefficient estimates plugged in._",
    "",
    worked,
    "",
    # Pattern J fix (B57/B58): emit the same stacked-matrix block + Cov(u)
    # block that HTML Tab 3 shows. Column-truncated by Pattern O so the 60-
    # row matrices collapse to 8x8 and fit on the page.
    pdf_three_views_matrix_block_latex(x, head = head, tail = tail,
                                        head_cols = head_cols,
                                        tail_cols = tail_cols),
    ""
  )
}

# Pattern J seed: extract the matrix-form LaTeX equations from the HTML
# emitter so the PDF can re-use them. Returns a character vector of Rmd
# lines ready to splice into the rmd_body. Equations are wrapped in
# Pandoc-style $$...$$ display blocks.
# Until v0.21.1(redo) lands the one-canonical-payload refactor, this
# helper calls three_views_matrix_block() and extracts every `$$...$$`
# block past the worked-row scalar arithmetic. Worked-row blocks come
# first; eq_mu (the stacked matrix equation), eq_sigma (optional), and
# eq_M (the structured-covariance Cov(u) block) come last.
pdf_three_views_matrix_block_latex <- function(x, head = 5L, tail = 2L,
                                                 head_cols = 5L,
                                                 tail_cols = 2L) {
  ex <- x$expanded
  has_mu  <- !is.null(ex) && !is.null(ex$X) && !is.null(ex$beta) && !is.null(ex$mu_hat)
  if (!has_mu) return(character(0))
  html <- three_views_matrix_block(x, head = head, tail = tail,
                                    head_cols = head_cols,
                                    tail_cols = tail_cols)
  # Extract every $$...$$ display-math block from the emitted HTML.
  # Use [\s\S] for "any char including newline" since R PCRE doesn't
  # support `s` flag in regex options.
  m <- gregexpr("\\$\\$[\\s\\S]+?\\$\\$", html, perl = TRUE)
  if (m[[1]][1] == -1L) return(character(0))
  eqs <- regmatches(html, m)[[1]]
  # The worked-row block contains the scalar `i=1` arithmetic and is
  # already emitted via pdf_three_views_worked_row(); skip the first N
  # $$..$$ that have NO `\begin{bmatrix}` (those are worked-row scalars).
  # The matrix block, sigma block, and Cov(u) block ALL contain a
  # `\begin{bmatrix}` token. This filter is robust to worked-row variants.
  has_matrix <- grepl("\\\\begin\\{bmatrix\\}", eqs, fixed = FALSE)
  matrix_eqs <- eqs[has_matrix]
  if (length(matrix_eqs) == 0L) return(character(0))
  # Build Rmd lines. Each equation gets a short heading.
  has_re    <- !is.null(ex$Z_g) && !is.null(ex$u)
  has_sigma <- !is.null(ex$X_sigma) && !is.null(ex$gamma)
  has_M     <- !is.null(ex$M) && is.matrix(ex$M) && nrow(ex$M) > 0L
  n_obs <- length(ex$y)
  out <- character(0L)
  # First matrix-bearing $$..$$ is eq_mu (the stacked response equation).
  if (length(matrix_eqs) >= 1L) {
    out <- c(out,
      sprintf("_Stacking the same response equation for all $n = %d$ observations:_",
              n_obs),
      "",
      matrix_eqs[1L],
      "")
  }
  # If a sigma submodel was emitted, it is the next matrix block.
  idx <- 2L
  if (has_sigma && length(matrix_eqs) >= idx) {
    # v0.22.4 Slice 1, F3 (PDF parity): match the HTML side's per-shape
    # sigma caption. Without this, the PDF still claims sigma describes
    # "spread of epsilon-hat" for Beta / Gamma / NegBinom, where sigma
    # is actually a precision / shape / size parameter.
    resp_sym_pdf <- escape_underscores_for_latex(x$model$response)
    family_str_pdf <-
      if (!is.null(x$model$family)) as.character(x$model$family[[1L]])
      else "gaussian"
    block_shape_pdf <- switch(
      tolower(family_str_pdf),
      gaussian  = "additive_gaussian",
      student   = "additive_gaussian",
      lognormal = "additive_log",
      "generalized"
    )
    sigma_role_pdf <- switch(
      block_shape_pdf,
      additive_gaussian = "$\\sigma$'s job is to describe the spread of $\\hat{\\boldsymbol{\\varepsilon}}$",
      additive_log = paste0(
        "$\\sigma$'s job is to describe the spread of the log-scale ",
        "residual $\\hat{\\boldsymbol{\\varepsilon}}^{(\\log)}$, ",
        "i.e. the SD of $\\log ", resp_sym_pdf, "$"
      ),
      generalized = paste0(
        "$\\sigma$ here is the family's spread parameter ",
        "and is not a residual SD; see Tab 1 for its specific role ",
        "in this distribution"
      )
    )
    out <- c(out,
      paste0("_And the $\\sigma$ submodel (no observed counterpart -- ",
             sigma_role_pdf, "):_"),
      "",
      matrix_eqs[idx],
      "")
    idx <- idx + 1L
  }
  # Finally, the structured-covariance Cov(u) block (phylo / spatial / generic).
  if (has_M && length(matrix_eqs) >= idx) {
    out <- c(out,
      "_And the structured-covariance prior on $\\mathbf{u}$. The random effect that gives this model its structural-dependence character:_",
      "",
      matrix_eqs[idx],
      "")
  }
  out
}

# Single source of truth for the family-dependent SHAPE of a Tab 3 worked
# row, shared by the HTML emitter (three_views_worked_row) and the PDF
# emitter (pdf_three_views_worked_row) so the two cannot drift apart
# (PDF/HTML parity, Pattern J). Returns:
#   shape         -- "additive_gaussian" | "additive_log" | "generalized"
#   link_label    -- LaTeX for the inverse-link operator (\exp, logistic, ...)
#   family_label  -- LaTeX name of the distribution for the likelihood line
worked_row_family_spec <- function(family) {
  fam <- tolower(as.character(family))
  list(
    shape = switch(fam,
      gaussian  = "additive_gaussian",
      student   = "additive_gaussian",
      lognormal = "additive_log",
      "generalized"),
    link_label = switch(fam,
      poisson  = "\\exp",
      binomial = "\\mathrm{logistic}",
      beta     = "\\mathrm{logistic}",
      gamma    = "\\exp",
      nbinom1  = "\\exp",
      nbinom2  = "\\exp",
      "\\mathrm{link}^{-1}"),
    family_label = switch(fam,
      poisson  = "\\mathrm{Poisson}",
      binomial = "\\mathrm{Binomial}",
      beta     = "\\mathrm{Beta}",
      gamma    = "\\mathrm{Gamma}",
      nbinom1  = "\\mathrm{NegBinom}_1",
      nbinom2  = "\\mathrm{NegBinom}_2",
      paste0("\\mathrm{", family, "}"))
  )
}

# Family-aware likelihood argument list, mirroring each family's Tab 1
# parameterization, built from caller-supplied mean and dispersion
# symbols (so HTML can pass `\hat\mu_{1}` / `\hat\sigma_{1}` and PDF can
# pass `\hat\mu_1` / `\hat\sigma_1` in their own local styles). Drives
# both the spurious-ellipsis fix (#3) and the precision-hiding fix (#4),
# and now keeps HTML + PDF in lockstep.
worked_row_lik_args <- function(family, mu_sym, sigma_sym) {
  switch(tolower(as.character(family)),
    poisson  = sprintf("(%s)", mu_sym),
    binomial = sprintf("(%s)", mu_sym),
    beta     = sprintf("(%s%s,\\, (1 - %s)%s)", mu_sym, sigma_sym, mu_sym, sigma_sym),
    gamma    = sprintf("(\\mathrm{shape} = 1/%s^2,\\, \\mathrm{scale} = %s%s^2)",
                       sigma_sym, mu_sym, sigma_sym),
    nbinom1  = sprintf("(%s,\\, \\mathrm{size} = \\exp(%s))", mu_sym, sigma_sym),
    nbinom2  = sprintf("(%s,\\, \\mathrm{size} = \\exp(%s))", mu_sym, sigma_sym),
    sprintf("(%s, \\ldots)", mu_sym)
  )
}

# Build the LaTeX content for the "worked observation" section. Pure-LaTeX
# strings (math + prose). Returns one $$...$$ block per submodel that has
# data populated in $expanded.
pdf_three_views_worked_row <- function(x) {
  ex <- x$expanded
  if (is.null(ex) || is.null(ex$y) || length(ex$y) == 0L) {
    return("_(This `symbolized_model` carries no `\\$expanded` numeric arrays; the worked-row view requires them.)_")
  }
  fmt <- function(v) formatC(v, digits = 3, format = "g")
  i <- 1L
  y_i <- ex$y[[i]]
  X_i <- if (!is.null(ex$X)) ex$X[i, , drop = TRUE] else NULL
  beta <- ex$beta
  mu_i <- if (!is.null(ex$mu_hat)) ex$mu_hat[[i]] else NA_real_
  eps_i <- if (!is.na(mu_i)) y_i - mu_i else NA_real_

  parts <- character(0L)
  resp <- x$model$response
  resp_sym <- escape_underscores_for_latex(resp)
  # Random-effect contribution at row i = 1, parallel to
  # three_views_worked_row() (HTML version). Without this, the worked-row
  # arithmetic `y_1 = X*beta + eps` doesn't close for models that have
  # random effects -- the residual silently absorbs the BLUP and the
  # displayed sum is mathematically wrong. Florence caught this on the
  # v0.21.2 dat.moura2021 metafor + MCMCglmm fits.
  has_re <- !is.null(ex$Z_g) && !is.null(ex$u)
  re_contrib_num <- if (has_re) sum(ex$Z_g[i, ] * ex$u) else 0
  # v0.22.4 #1 (BLOCKER): the PDF worked row must branch on family/link
  # exactly as the HTML emitter does, via the shared family-spec helpers.
  # The old code hardcoded the Gaussian-additive `y = Xb + eps = y` form
  # for every family -- wrong scale, arithmetically false, and at odds
  # with the PDF's own link-scale stacked block.
  fam_spec <- worked_row_family_spec(x$model$family)
  shape    <- fam_spec$shape
  eta_i    <- if (!is.null(ex$eta_hat)) ex$eta_hat[[i]] else mu_i
  resp1    <- sprintf("\\mathrm{%s}_1", resp_sym)
  if (!is.null(X_i) && !is.null(beta) && length(X_i) == length(beta)) {
    # Build the displayed linear-predictor terms + the reader-facing
    # numeric value of each (for closing additive equations at display
    # precision -- same approach as the HTML worked row).
    terms_tex <- character(length(beta))
    num_vals  <- numeric(length(beta))
    for (k in seq_along(beta)) {
      if (k == 1L) {
        terms_tex[k] <- fmt(beta[[k]])
        num_vals[k]  <- as.numeric(fmt(beta[[k]]))
      } else {
        terms_tex[k] <- sprintf("%s \\cdot %s", fmt(beta[[k]]), fmt(X_i[[k]]))
        num_vals[k]  <- as.numeric(fmt(beta[[k]])) * as.numeric(fmt(X_i[[k]]))
      }
    }
    if (has_re) {
      terms_tex <- c(terms_tex, sprintf("(%s)", fmt(re_contrib_num)))
      num_vals  <- c(num_vals, as.numeric(fmt(re_contrib_num)))
    }
    rhs_lp  <- join_signed_terms(terms_tex)  # folds '+ -' -> '-' (#7)
    lp_disp <- sum(num_vals)

    if (shape == "additive_gaussian") {
      # #155: LP build with \approx, then the TRUE residual y - mu_hat
      # (matches the stacked matrix block, no balancing fudge).
      eps_true <- y_i - mu_i
      parts <- c(parts, "$$",
        sprintf("\\hat\\mu_1 \\;=\\; %s \\;\\approx\\; %s", rhs_lp, fmt(mu_i)),
        "$$", "",
        sprintf(paste0("_Observed $%s = %s$; predicted mean $\\hat\\mu_1 = %s$ ",
                       "(response scale); residual $\\hat\\varepsilon_1 = %s$ ",
                       "(observed = mean + residual)._"),
                resp1, fmt(y_i), fmt(mu_i), fmt(eps_true)))
    } else if (shape == "additive_log") {
      log_y    <- log(y_i)
      eps_true <- log_y - mu_i
      parts <- c(parts, "$$",
        sprintf("\\hat\\mu_1 \\;=\\; %s \\;\\approx\\; %s", rhs_lp, fmt(mu_i)),
        "$$", "",
        sprintf(paste0("_Observed $\\log %s = %s$ (log scale); predicted log-scale ",
                       "mean $\\hat\\mu_1 = %s$; log-scale residual ",
                       "$\\hat\\varepsilon_1^{(\\log)} = %s$ ",
                       "(observed = mean + residual). Back-transform to the ",
                       "response-scale mean with ",
                       "$\\mathbb{E}[%s] = \\exp(\\hat\\mu_1 + \\hat\\sigma_1^2/2)$._"),
                resp1, fmt(log_y), fmt(mu_i), fmt(eps_true), resp1))
    } else {
      # generalized: link-scale linear predictor, response-scale mean via
      # the inverse link, then the likelihood. No additive error term.
      link <- fam_spec$link_label
      lik  <- worked_row_lik_args(x$model$family, "\\hat\\mu_1", "\\hat\\sigma_1")
      parts <- c(parts, "$$", "\\begin{aligned}",
        sprintf("\\hat\\eta_1 &\\;=\\; %s \\;\\approx\\; %s \\\\", rhs_lp, fmt(eta_i)),
        sprintf("\\hat\\mu_1 &\\;=\\; %s(\\hat\\eta_1) \\;=\\; %s(%s) \\;\\approx\\; %s \\\\",
                link, link, fmt(eta_i), fmt(mu_i)),
        sprintf("%s &\\;\\sim\\; %s%s", resp1, fam_spec$family_label, lik),
        "\\end{aligned}", "$$", "",
        sprintf(paste0("_Linear predictor $\\hat\\eta_1 = %s$ on the link scale; ",
                       "predicted mean $\\hat\\mu_1 = %s(\\hat\\eta_1) \\approx %s$ on the ",
                       "response scale. No additive error term enters the linear ",
                       "predictor -- the spread is set by the likelihood above._"),
                fmt(eta_i), link, fmt(mu_i)))
    }
  }
  if (!is.null(ex$X_sigma) && !is.null(ex$gamma) &&
      !is.null(ex$sigma_hat) && length(ex$sigma_hat) >= 1L) {
    Xs_i <- ex$X_sigma[i, , drop = TRUE]
    gamma <- ex$gamma
    log_sigma_i <- if (length(Xs_i) == length(gamma)) sum(Xs_i * gamma) else NA_real_
    sigma_i <- exp(log_sigma_i)
    if (length(gamma) == 1L) {
      parts <- c(parts,
        "",
        sprintf("And the $\\sigma$ submodel at $i = 1$:"),
        "",
        "$$",
        sprintf("\\log \\hat\\sigma_1 \\;=\\; %s \\;\\Rightarrow\\; \\hat\\sigma_1 \\;=\\; \\exp(%s) \\;\\approx\\; %s",
                fmt(gamma[[1L]]), fmt(gamma[[1L]]), fmt(sigma_i)),
        "$$"
      )
    } else {
      terms_g <- vapply(seq_along(gamma), function(k) {
        if (k == 1L) fmt(gamma[[k]])
        else sprintf("%s \\cdot %s", fmt(gamma[[k]]), fmt(Xs_i[[k]]))
      }, character(1L))
      # Same seq.int(2L, n) bug-class as the mu branch above; the `else`
      # arm here is reached only when length(gamma) >= 2L so the loop is
      # safe today, but use paste/collapse for symmetry and future safety.
      rhs_g <- paste(terms_g, collapse = " + ")
      parts <- c(parts,
        "",
        sprintf("And the $\\sigma$ submodel at $i = 1$:"),
        "",
        "$$",
        sprintf("\\log \\hat\\sigma_1 \\;=\\; %s \\;=\\; %s \\;\\Rightarrow\\; \\hat\\sigma_1 \\;\\approx\\; %s",
                rhs_g, fmt(log_sigma_i), fmt(sigma_i)),
        "$$"
      )
    }
  }
  if (length(parts) == 0L) {
    return("_(Worked-row view requires `$expanded` with `y`, `X`, `beta`, and `mu_hat`.)_")
  }
  paste(parts, collapse = "\n")
}

# Underscore-escape a response name for use inside \mathrm{...} in LaTeX.
escape_underscores_for_latex <- function(s) {
  gsub("_", "\\_", s, fixed = TRUE)
}

# Join a vector of LaTeX numeric term strings into a sum, folding a
# leading minus sign on any term into the binary operator so the result
# reads `a - b` rather than the glued `a + -b` (punch-list #7). The first
# term keeps its own sign. Terms whose displayed value is already
# parenthesised (e.g. a random-effect or residual term `(-0.45)`) start
# with `(` not `-`, so they keep the `+ (...)` style -- the page's own
# convention for those, intentionally left intact.
join_signed_terms <- function(terms) {
  terms <- terms[nzchar(terms)]
  if (length(terms) == 0L) return("")
  out <- terms[[1L]]
  for (j in seq_along(terms)[-1L]) {
    t <- terms[[j]]
    if (grepl("^-", t)) {
      out <- paste0(out, " - ", sub("^-\\s*", "", t))
    } else {
      out <- paste0(out, " + ", t)
    }
  }
  out
}

# Wrap a three-views fragment with a full standalone HTML document that
# includes the MathJax CDN bootstrap, so the file renders math when
# opened from disk (file://...). Fragment-only mode (the default) leaves
# math rendering to the host document's MathJax / KaTeX.
three_views_standalone_wrap <- function(fragment, title = "symbolizer three views") {
  mathjax_config <- paste0(
    "window.MathJax = {",
    "tex: { inlineMath: [['$', '$']], displayMath: [['$$','$$']], processEscapes: true },",
    "options: { skipHtmlTags: ['script','noscript','style','textarea','pre','code'] }",
    "};"
  )
  paste0(
    "<!DOCTYPE html>\n",
    "<html lang=\"en\"><head>\n",
    "<meta charset=\"utf-8\">\n",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n",
    "<title>", title, "</title>\n",
    "<style>body { font-family: -apple-system, BlinkMacSystemFont, ",
    "\"Segoe UI\", Roboto, sans-serif; max-width: 980px; margin: 2rem auto; ",
    "padding: 0 1rem; color: #111; line-height: 1.5; }</style>\n",
    "<script>", mathjax_config, "</script>\n",
    "<script id=\"MathJax-script\" async ",
    "src=\"https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js\">",
    "</script>\n",
    "</head><body>\n",
    fragment,
    "\n</body></html>\n"
  )
}

three_views_matrix_summary <- function(has_re) {
  base <- paste0(
    "Matrix-form expansion of the model. Each row shows the response y_i ",
    "and the corresponding row of the design matrix X (showing head and ",
    "tail rows of the n total observations), with the coefficient vector ",
    "beta listed below."
  )
  if (has_re) {
    # Caption is read by screen readers; do not assume Z is visible (the
    # renderer drops Z when n_obs == n_distinct_levels, since Z is then
    # essentially the identity on the observed levels).
    paste0(base,
           " The predicted random-effect contribution to each observation ",
           "is also shown.")
  } else {
    base
  }
}

# ---------------------------------------------------------------------------
# Module-level LaTeX helpers used by latex_implied_cov_block and others.
# These are intentionally minimal — no row/column truncation beyond what
# the caller requests. The local versions inside three_views_matrix_block()
# are richer (Pattern O column selection); these serve the stand-alone
# tier-decomposition emitter.
# ---------------------------------------------------------------------------

# Emit \begin{bmatrix} ... \end{bmatrix} from a numeric matrix, displaying
# only the rows indicated by `rows` (a integer vector; NAs become \vdots).
# Columns are not truncated here; callers pass a pre-selected row index.
latex_mat <- function(M, rows = seq_len(nrow(M))) {
  fmt <- function(v) formatC(v, digits = 3, format = "g")
  rows_tex <- vapply(rows, function(i) {
    if (is.na(i)) {
      paste(rep("\\vdots", ncol(M)), collapse = " & ")
    } else {
      paste(vapply(seq_len(ncol(M)), function(j) fmt(M[i, j]), character(1L)),
            collapse = " & ")
    }
  }, character(1L))
  paste0("\\begin{bmatrix} ",
         paste(rows_tex, collapse = " \\\\ "),
         " \\end{bmatrix}")
}

# Wrap `content` in a LaTeX \underbrace{...}_{label} with \textstyle so
# the annotation renders at readable size in MathJax display math.
underbrace <- function(content, label)
  sprintf("\\underbrace{%s}_{\\textstyle\\,%s\\,}", content, label)

# Emit the implied-covariance block for one tier (B or W) of a gllvm
# fit: a stacked equation showing the numerical Σ matrix next to its
# Λ Λ^T + diag(Ψ²) decomposition. Returns a character string suitable
# for inclusion inside a `$$ ... $$` MathJax block, or NULL when any
# matrix is missing.
# Emit the symbolic marginal-covariance decomposition for a multilevel
# / meta-analytic fit. Returns a LaTeX `$$...$$` block of the shape
#
#   Cov(y) = sigma_p^2 A         (phylo tier, structured)
#          + sigma_study^2 Z Z^T (study tier, unstructured)
#          + diag(v)              (sampling variance, when meta_V present)
#
# with `\underbrace{...}_{label}` annotations naming each tier. Returns
# NULL when there's no meta-analytic context, no random effects, and no
# structured matrix -- i.e. when the decomposition is trivially
# `sigma^2 I` and would carry no pedagogy.
#
# Lives inside Tab 3 of the three-views widget. The widget already shows
# per-tier distribution rows on Tabs 1 + 2; this block makes the
# *implied* marginal covariance explicit, mirroring what V2 Pat's audit
# of the meta-analysis Widget 2 asked for: "Tab 3 should *show* the
# decomposition, not just announce it."
latex_marginal_cov_block <- function(x) {
  has_meta <- !is.null(x$metadata$detected_signals) &&
              "meta_analysis" %in% x$metadata$detected_signals
  re_tbl   <- x$random_effects
  has_re   <- !is.null(re_tbl) && nrow(re_tbl) > 0L
  # No work to do when the model has neither known sampling variance
  # nor a random-effect structure beyond residual.
  if (!has_meta && !has_re) return(NULL)
  # When there's a single iid RE and no meta_V, the decomposition
  # collapses to `sigma^2 Z Z^T + sigma_eps^2 I`, which is the standard
  # textbook form already shown in §1 of every regression chapter. Skip
  # to avoid cluttering simple fits.
  if (!has_meta && has_re && nrow(re_tbl) == 1L) return(NULL)

  smfg <- x$metadata$structured_matrix_for_group
  is_structured <- function(gv) {
    !is.null(smfg) && !is.null(smfg[[gv]])
  }

  # One term per random-effect group (mu submodel only -- variance-
  # submodel terms enter via the link function, not the marginal
  # covariance of y).
  re_mu <- re_tbl[re_tbl$submodel == "mu", , drop = FALSE]
  groups <- unique(re_mu$group_var)
  re_terms <- vapply(groups, function(gv) {
    sel    <- which(re_mu$group_var == gv)[[1L]]
    sigma  <- re_mu$sigma_symbol[[sel]]
    if (is_structured(gv)) {
      struct_sym <- smfg[[gv]]
      body  <- sprintf("%s^2\\, %s", sigma, struct_sym)
      label <- sprintf("\\text{%s tier}", gv)
    } else {
      body  <- sprintf("%s^2\\, \\mathbf{Z}_{%s}\\mathbf{Z}_{%s}^{\\!\\top}",
                       sigma, gv, gv)
      label <- sprintf("\\text{%s tier}", gv)
    }
    underbrace(body, label)
  }, character(1L))

  meta_term <- if (has_meta) {
    underbrace("\\mathrm{diag}(\\mathbf{v})",
               "\\text{known sampling}")
  } else NULL

  rhs <- paste(c(re_terms, meta_term), collapse = " \\;+\\; ")
  lhs <- underbrace("\\mathrm{Cov}(\\mathbf{y})",
                    sprintf("n \\times n,\\; n = %d", x$model$n_obs))
  paste0("$$\n", lhs, " \\;=\\; ", rhs, "\n$$\n")
}

latex_implied_cov_block <- function(tier = c("B", "W"), Sigma, Lambda, Psi) {
  tier <- match.arg(tier)
  if (is.null(Sigma) || is.null(Lambda) || is.null(Psi)) return(NULL)
  caption <- if (identical(tier, "B"))
    "between-individual implied covariance"
  else
    "within-individual implied covariance"
  T_n <- nrow(Sigma); d <- ncol(Lambda)
  sigma_mat <- latex_mat(Sigma, rows = seq_len(min(T_n, 7L)))
  lam_mat   <- latex_mat(Lambda, rows = seq_len(min(T_n, 7L)))
  psi_mat   <- latex_mat(diag(Psi^2), rows = seq_len(min(T_n, 7L)))
  sigma_lab <- sprintf("\\boldsymbol{\\Sigma}_%s\\;\\text{(%s)}",
                       tier, caption)
  lam_lab   <- sprintf("\\boldsymbol{\\Lambda}_%s\\,\\boldsymbol{\\Lambda}_%s^{\\!\\top}",
                       tier, tier)
  psi_lab   <- sprintf("\\boldsymbol{\\Psi}_%s^{\\,2}", tier)
  paste0(
    "$$\n",
    underbrace(sigma_mat, sigma_lab),
    " \\;=\\; ", underbrace(lam_mat, lam_lab),
    " \\;+\\; ", underbrace(psi_mat, psi_lab),
    "\n$$\n"
  )
}

three_views_matrix_block <- function(x, head = 5L, tail = 2L,
                                      head_cols = 5L, tail_cols = 2L) {
  ex <- x$expanded
  if (is.null(ex)) {
    return("<p><em>This symbolized_model carries no expanded numeric arrays.</em></p>\n")
  }
  # format = "g" (not "fg") + no "#" flag avoids dangling decimals like
  # "129." for values that happen to round to 3 sig figs as a whole
  # number. We still get "1.00", "14.0", "30.4" etc for the values that
  # need them.
  fmt <- function(v) formatC(v, digits = 3, format = "g")
  trunc_idx <- function(n, head, tail) {
    if (n <= head + tail + 1L) seq_len(n)
    else c(seq_len(head), NA_integer_, seq.int(n - tail + 1L, n))
  }
  n <- length(ex$y)
  rows <- trunc_idx(n, head, tail)

  # LaTeX helpers: emit \begin{bmatrix} ... \end{bmatrix} from a numeric
  # vector or matrix, with `\vdots` for the truncation row.
  latex_vec <- function(vals, idx = seq_along(vals)) {
    rows_tex <- vapply(idx, function(i) {
      if (is.na(i)) "\\vdots" else fmt(vals[i])
    }, character(1L))
    paste0("\\begin{bmatrix} ",
           paste(rows_tex, collapse = " \\\\ "),
           " \\end{bmatrix}")
  }
  # Column-truncation contract (Pattern O from v0.21-redo audit): when a
  # matrix has more than `head + tail + 1` columns, show `head` leading
  # columns, then a `\cdots` placeholder, then `tail` trailing columns.
  # For sparse one-hot matrices (e.g. random-effects design Z whose info
  # lives in the few 1s, not the many 0s), prefer columns that contain at
  # least one non-zero entry within the visible row band.
  trunc_col_idx <- function(M, idx_rows, head = 5L, tail = 2L) {
    p <- ncol(M)
    if (p <= head + tail + 1L) return(seq_len(p))
    rows_concrete <- idx_rows[!is.na(idx_rows)]
    informative <- if (length(rows_concrete) > 0L) {
      col_nz <- apply(M[rows_concrete, , drop = FALSE], 2L,
                      function(col) any(abs(col) > .Machine$double.eps^0.5))
      which(col_nz)
    } else integer(0L)
    nz_head <- intersect(seq_len(min(head, p)), informative)
    nz_tail <- intersect(seq.int(max(1L, p - tail + 1L), p), informative)
    # v0.22.2-discipline Slice A2 polish: when the informative columns
    # sit in the MIDDLE of a wide matrix (e.g. Z_phylo for a species
    # that's alphabetically mid-list), nz_head and nz_tail are both
    # empty and the old code fell to the structural head/tail (all
    # zeros for sparse one-hot). Surface middle informative cols by
    # promoting them into the head/tail sets so the visible window
    # contains the 1s the reader needs to see.
    nz_middle <- setdiff(informative, c(nz_head, nz_tail))
    if (length(nz_head) == 0L && length(nz_middle) > 0L) {
      take <- min(length(nz_middle), head)
      nz_head   <- nz_middle[seq_len(take)]
      nz_middle <- nz_middle[-seq_len(take)]
    }
    if (length(nz_tail) == 0L && length(nz_middle) > 0L) {
      take <- min(length(nz_middle), tail)
      nz_tail <- nz_middle[seq.int(length(nz_middle) - take + 1L,
                                    length(nz_middle))]
    }
    if (length(nz_head) > 0L || length(nz_tail) > 0L) {
      head_set <- unique(c(nz_head, head(setdiff(seq_len(p), nz_head),
                                          head - length(nz_head))))
      head_set <- sort(head_set)[seq_len(min(head, length(head_set)))]
      tail_set <- unique(c(nz_tail, tail(setdiff(seq.int(max(head_set) + 1L, p),
                                                  nz_tail),
                                          tail - length(nz_tail))))
      tail_set <- sort(tail_set)
      tail_set <- tail_set[tail_set > max(head_set)]
      tail_set <- tail(tail_set, tail)
    } else {
      head_set <- seq_len(head)
      tail_set <- seq.int(p - tail + 1L, p)
    }
    c(head_set, NA_integer_, tail_set)
  }
  latex_mat <- function(M, idx = seq_len(nrow(M)),
                        col_head = 5L, col_tail = 2L) {
    p <- ncol(M)
    cidx <- trunc_col_idx(M, idx, head = col_head, tail = col_tail)
    cells <- function(i) {
      vapply(cidx, function(j) {
        if (is.na(i) && is.na(j)) "\\ddots"
        else if (is.na(i))         "\\vdots"
        else if (is.na(j))         "\\cdots"
        else                       fmt(M[i, j])
      }, character(1L))
    }
    rows_tex <- vapply(idx, function(i) paste(cells(i), collapse = " & "),
                       character(1L))
    paste0("\\begin{bmatrix} ",
           paste(rows_tex, collapse = " \\\\ "),
           " \\end{bmatrix}")
  }
  # Underbrace label helper: LaTeX defaults `\underbrace{X}_{label}` to
  # `\scriptstyle` for the label, which renders at about half the text
  # size and is hard to read on the matrix-with-data panel. Force
  # `\textstyle` so the dimension annotations (`\mathbf{X}_{200\times 2}`
  # etc.) render at normal math size. Dropping the parens follows the
  # textbook convention `\mathbf{X}_{n \times p}` rather than the
  # programming-type-annotation look `\mathbf{X}\,(n \times p)`.
  underbrace <- function(latex, label) {
    paste0("\\underbrace{", latex, "}_{\\textstyle\\,", label, "\\,}")
  }

  has_sigma <- !is.null(ex$X_sigma) && !is.null(ex$gamma)
  has_re    <- !is.null(ex$Z_g)     && !is.null(ex$u)
  has_mu    <- !is.null(ex$X)       && !is.null(ex$beta) && !is.null(ex$mu_hat)
  has_M     <- !is.null(ex$M) && is.matrix(ex$M) && nrow(ex$M) > 0L
  if (!has_mu) {
    return(paste0(
      "<p><em>The matrix-with-data view needs <code>expanded$X</code>, ",
      "<code>expanded$beta</code>, and <code>expanded$mu_hat</code>. ",
      "This extractor populates only the response vector. See issue #9.</em></p>\n"
    ))
  }

  # Symbol for the response: default to `\mathbf{y}`, but use whatever the
  # model card carries so the matrix block matches the equation block.
  resp_sym <- tryCatch({
    rt <- symbol_table(x, notation = "matrix")
    resp_row <- rt[rt$role == "response", , drop = FALSE]
    if (nrow(resp_row) >= 1L) resp_row$symbol_matrix[[1L]] else "\\mathbf{y}"
  }, error = function(e) "\\mathbf{y}")
  # symbol_table returns LaTeX with `\\mathbf{...}` literally — that's
  # already R-string-encoded as a single backslash, so it can drop into
  # the cat'd HTML as-is.

  # --- Block 1: response equation, family-aware ---
  # Pedagogically this is the matrix-form RESPONSE equation. Tab 2
  # (abstraction) shows the conditional mean only. Tab 3 (here) drops
  # down a level of honesty: it shows the observed vector, the
  # prediction, and -- when the family is Gaussian-additive on some
  # scale -- the residual vector.
  #
  # v0.22.4 Slice 1: three shapes per family (mirrors the worked-row
  # architecture from v0.22.3, ensuring within-tab consistency):
  #
  #   additive_gaussian  -- y = X β̂ + ε̂ on response scale
  #                         (Gaussian, Student-t)
  #   additive_log       -- log(y) = X β̂ + ε̂^{(log)} on log scale
  #                         (Lognormal, drmTMB identity-on-mu-of-log-y)
  #   generalized        -- η̂ = X β̂ on link scale; μ̂ = link⁻¹(η̂);
  #                         y ~ Family(μ̂)
  #                         (Poisson, Beta, Binomial, Gamma, NegBinom)
  #
  # The pre-v0.22.4 build emitted `y = X β̂ + ε̂` for every family.
  # For non-Gaussian families that mixed response-scale y with
  # link-scale X β̂ in one additive equation -- arithmetically false,
  # cross-confirmed BLOCKER by all four V-agents in the families
  # team review (docs/dev-log/figure-audits/v0.22.3-families-team-review/).
  family_str_block <-
    if (!is.null(x$model$family)) as.character(x$model$family[[1L]])
    else "gaussian"
  block_shape <- switch(
    tolower(family_str_block),
    gaussian  = "additive_gaussian",
    student   = "additive_gaussian",
    lognormal = "additive_log",
    "generalized"
  )
  emit_eps <- block_shape %in% c("additive_gaussian", "additive_log")
  if (block_shape == "additive_log") {
    lhs_values <- log(ex$y)
    lhs_sym    <- sprintf("\\log(%s)", resp_sym)
    lhs_role   <- "observed, log scale"
    eps_vals   <- log(ex$y) - ex$mu_hat
    eps_sym    <- "\\hat{\\boldsymbol{\\varepsilon}}^{(\\log)}"
    eps_role   <- "log-scale residual"
  } else if (block_shape == "generalized") {
    lhs_values <- ex$eta_hat
    lhs_sym    <- "\\hat{\\boldsymbol{\\eta}}"
    lhs_role   <- "linear predictor, link scale"
    eps_vals   <- NULL
    eps_sym    <- NULL
    eps_role   <- NULL
  } else {
    # additive_gaussian (historic; back-compat path)
    lhs_values <- ex$y
    lhs_sym    <- resp_sym
    lhs_role   <- "observed"
    eps_vals   <- ex$y - ex$mu_hat
    eps_sym    <- "\\hat{\\boldsymbol{\\varepsilon}}"
    eps_role   <- "residual"
  }

  y_vec    <- latex_vec(lhs_values, rows)
  X_mat    <- latex_mat(ex$X,     rows,
                         col_head = head_cols, col_tail = tail_cols)
  beta_vec <- latex_vec(ex$beta)
  eps_vec  <- if (emit_eps) latex_vec(eps_vals, rows) else NULL
  y_lab    <- sprintf("%s_{\\,%d \\times 1}\\;\\text{(%s)}",
                      lhs_sym, n, lhs_role)
  X_lab    <- sprintf("\\mathbf{X}_{\\,%d \\times %d}", n, ncol(ex$X))
  beta_lab <- sprintf("\\hat{\\boldsymbol{\\beta}}_{\\,%d \\times 1}\\;\\text{(estimated)}",
                      length(ex$beta))
  eps_lab  <- if (emit_eps) {
    sprintf("%s_{\\,%d \\times 1}\\;\\text{(%s)}",
            eps_sym, n, eps_role)
  } else NULL

  eq_mu <- paste0(
    underbrace(y_vec,    y_lab),    " \\;=\\; ",
    underbrace(X_mat,    X_lab),    "\\, ",
    underbrace(beta_vec, beta_lab)
  )
  # 2026-05-27 (maintainer + Rose consistency scan): the Z incidence
  # matrix is only informative when observations are repeated within a
  # random-effect level (multi-obs-per-species, multi-trial-per-animal,
  # multi-effect-size-per-study). When n_obs == n_distinct_levels (one
  # obs per level), Z is essentially the identity on the observed
  # levels and renders as a wall of zeros (with the 1s scattered in
  # columns that the head/tail truncation misses). In that case, drop
  # the Z block entirely and emit the per-observation random effect
  # u_obs = Z * u_full directly as an n-vector. Each row of the
  # stacked equation then reads
  #   zr_i = β̂_0 + û_{species(i)} + ε̂_i
  # matching Tab 1's index-notation reading. Z is reintroduced only
  # when the data have multiple observations per level (so Z carries
  # genuine mapping content). The flag is computed once here so the
  # caption prose below can drop the "Z" factor too.
  # v0.22.2-discipline Slice A2: per-tier Tab 3 rendering. When the
  # extractor surfaced more than one random-effect tier (e.g. phylo +
  # study), emit one Z * u group PER tier so the article's multilevel
  # structure is visible in the matrix block, not hidden behind a
  # single bare `Z` aggregate. Single-tier fits fall through to the
  # historic shape (no `_g` subscripts on Z / u) for back-compat.
  per_tier_Z <- if (!is.null(ex$Z_per_tier) && length(ex$Z_per_tier) > 0L) {
    ex$Z_per_tier
  } else if (has_re) {
    stats::setNames(list(ex$Z_g), "")  # single-tier fallback, no subscript
  } else NULL
  per_tier_u <- if (!is.null(ex$u_per_tier) && length(ex$u_per_tier) > 0L) {
    ex$u_per_tier
  } else if (has_re) {
    stats::setNames(list(ex$u), "")
  } else NULL
  if (!is.null(per_tier_Z)) {
    # Sanitize a group_var name into a LaTeX-safe subscript. The
    # subscript is rendered in `\text{...}` so multi-character labels
    # like `study_ID` come through legibly; underscores are escaped so
    # they don't trigger subscript-of-subscript.
    latex_subscript <- function(gv) {
      if (!nzchar(gv)) return("")
      paste0("\\text{", gsub("_", "\\\\_", gv, fixed = FALSE), "}")
    }
    for (gv in names(per_tier_Z)) {
      Z_gv <- per_tier_Z[[gv]]
      u_gv <- per_tier_u[[gv]]
      if (is.null(Z_gv) || is.null(u_gv)) next
      sub_tex <- latex_subscript(gv)
      sub_with_comma <- if (nzchar(sub_tex)) paste0(sub_tex, ",\\,") else ""
      z_one_to_one <-
        nrow(Z_gv) >= 1L &&
        all(rowSums(Z_gv != 0) == 1L) &&
        all(colSums(Z_gv != 0) <= 1L)
      if (z_one_to_one) {
        u_per_obs <- as.numeric(Z_gv %*% u_gv)
        u_obs_vec <- latex_vec(u_per_obs, rows)
        u_obs_lab <- if (nzchar(sub_tex)) {
          sprintf(
            "\\hat{\\mathbf{u}}_{%s,\\,%d \\times 1}\\;\\text{(per-obs %s effect)}",
            sub_tex, n, gv
          )
        } else {
          sprintf(
            "\\hat{\\mathbf{u}}_{\\,%d \\times 1}\\;\\text{(per-obs random effect)}",
            n
          )
        }
        eq_mu <- paste0(
          eq_mu, " \\;+\\; ",
          underbrace(u_obs_vec, u_obs_lab)
        )
      } else {
        z_col_idx <- trunc_col_idx(Z_gv, rows,
                                   head = head_cols, tail = tail_cols)
        Zg_mat  <- latex_mat(Z_gv, rows,
                             col_head = head_cols, col_tail = tail_cols)
        u_vec   <- latex_vec(u_gv, z_col_idx)
        Zg_lab  <- sprintf("\\mathbf{Z}_{%s\\,%d \\times %d}",
                           sub_with_comma, n, ncol(Z_gv))
        u_lab   <- if (nzchar(sub_tex)) {
          sprintf("\\hat{\\mathbf{u}}_{%s,\\,%d \\times 1}\\;\\text{(BLUP)}",
                  sub_tex, length(u_gv))
        } else {
          sprintf("\\hat{\\mathbf{u}}_{\\,%d \\times 1}\\;\\text{(BLUP)}",
                  length(u_gv))
        }
        eq_mu <- paste0(
          eq_mu, " \\;+\\; ",
          underbrace(Zg_mat, Zg_lab), "\\, ",
          underbrace(u_vec,  u_lab)
        )
      }
    }
  }
  # Preserve the old single-tier "Z is identity-on-obs" flag for the
  # caption prose below (the caption decides whether to mention Z by
  # name based on whether ANY tier actually emitted a Z block).
  z_is_one_to_one_flag <- has_re &&
    !is.null(ex$Z_g) &&
    nrow(ex$Z_g) >= 1L &&
    all(rowSums(ex$Z_g != 0) == 1L) &&
    all(colSums(ex$Z_g != 0) <= 1L)
  # Close the response equation with the residual vector -- only for
  # families with additive Gaussian noise on some scale. For
  # generalized families (Poisson, Beta, etc.) the linear predictor
  # has no additive residual on link scale; emitting +eps would be a
  # math error of the same class as the v0.22.3 worked-row template.
  if (emit_eps) {
    eq_mu <- paste0(
      eq_mu, " \\;+\\; ",
      underbrace(eps_vec, eps_lab)
    )
  }

  # --- Block 2: sigma submodel (only when distributional) ----------------
  eq_sigma <- if (has_sigma) {
    sigma_vec <- latex_vec(ex$sigma_hat, rows)
    Xs_mat    <- latex_mat(ex$X_sigma, rows,
                            col_head = head_cols, col_tail = tail_cols)
    gamma_vec <- latex_vec(ex$gamma)
    sigma_lab <- sprintf("\\boldsymbol{\\sigma}_{\\,%d \\times 1}", n)
    # Sigma-submodel design matrix: rename `\mathbf{Z}` -> `\mathbf{X}_\sigma`
    # so `\mathbf{Z}` is reserved for random effects only (Noether's audit).
    Xs_lab    <- sprintf("\\mathbf{X}_{\\sigma,\\,%d \\times %d}",
                         n, ncol(ex$X_sigma))
    gamma_lab <- sprintf("\\boldsymbol{\\gamma}_{\\,%d \\times 1}",
                         length(ex$gamma))
    paste0(
      "\\log\\!",
      underbrace(sigma_vec, sigma_lab), " \\;=\\; ",
      underbrace(Xs_mat,    Xs_lab),    "\\, ",
      underbrace(gamma_vec, gamma_lab)
    )
  } else NULL

  # --- Worked-row blocks: walk observation 1 through both submodels -----
  # Mu: `W_1 = beta_0 + beta_1 T_1 + eps_1` in symbols, then with numbers,
  # then decomposed into `predicted + residual`.
  # Sigma (if distributional): `log sigma_1 = gamma_0 + gamma_1 T_1`, then
  # with numbers, then back-transformed to sigma_1 in original units.
  # Both anchor the matrix algebra immediately below: each matrix equation
  # is the corresponding worked row stacked n times.
  family_str <- if (!is.null(x$model$family)) as.character(x$model$family[[1L]]) else "gaussian"
  worked_mu    <- three_views_worked_row(ex, resp_sym, family = family_str)
  worked_sigma <- three_views_worked_row_sigma(ex, family = family_str)

  # --- Block 3: structured covariance matrix (phylo / spatial / temporal) -
  # When the model carries a structured random effect, render
  # Cov(u) = sigma^2 * M with M as a bmatrix of actual numbers (truncated
  # head-and-tail when k > head + tail + 1). M's symbol and surrounding
  # prose adapt to the detected context: A for phylogenetic / animal-model
  # contexts; Omega for spatial; M as a fallback. The kind is read from
  # metadata$phylo_representation / metadata$spatial_representation.
  eq_M <- NULL
  M_caption <- NULL
  if (has_M) {
    M_kind <- if (!is.null(x$metadata$phylo_representation)) "phylo"
              else if (!is.null(x$metadata$spatial_representation)) "spatial"
              else "structured"
    M_sym <- switch(M_kind,
      phylo   = "\\mathbf{A}",
      spatial = "\\boldsymbol{\\Omega}",
      "\\mathbf{M}"
    )
    sigma_sym <- switch(M_kind,
      phylo   = "\\sigma_p^2",
      spatial = "\\sigma_\\omega^2",
      "\\sigma^2"
    )
    k <- nrow(ex$M)
    # Truncate the M matrix for display. Rows use `head` / `tail`
    # (consistent with the y / X / Z / eps row truncation); columns
    # use `head_cols` / `tail_cols` so the user can dial cols independently
    # of rows. For small k, show all rows / columns.
    if (k <= head + tail + 1L) {
      M_idx_r <- seq_len(k)
    } else {
      M_idx_r <- c(seq_len(head), NA_integer_, seq.int(k - tail + 1L, k))
    }
    if (k <= head_cols + tail_cols + 1L) {
      M_idx_c <- seq_len(k)
    } else {
      M_idx_c <- c(seq_len(head_cols), NA_integer_,
                    seq.int(k - tail_cols + 1L, k))
    }
    # latex_mat assumes a contiguous index for rows; we need full
    # column truncation too. Local helper:
    latex_mat_2d <- function(M, idx_r, idx_c) {
      rows_tex <- vapply(idx_r, function(i) {
        if (is.na(i)) {
          paste(vapply(idx_c, function(j) "\\vdots", character(1L)),
                collapse = " & ")
        } else {
          paste(vapply(idx_c, function(j) {
            if (is.na(j)) "\\cdots" else fmt(M[i, j])
          }, character(1L)), collapse = " & ")
        }
      }, character(1L))
      paste0("\\begin{bmatrix} ",
             paste(rows_tex, collapse = " \\\\ "),
             " \\end{bmatrix}")
    }
    M_mat_tex <- latex_mat_2d(ex$M, M_idx_r, M_idx_c)
    M_lab <- sprintf("%s_{\\,%d \\times %d}", M_sym, k, k)
    eq_M <- sprintf(
      "\\mathrm{Cov}(\\hat{\\mathbf{u}}) \\;=\\; %s \\cdot \\underbrace{%s}_{\\textstyle\\,%s\\,}",
      sigma_sym, M_mat_tex, M_lab
    )
    M_caption <- sprintf(
      "<p class=\"sym-caption\" style=\"font-size:0.85em;color:#6b7280;margin-top:0.4rem\">The %s random effect $u$ has covariance $%s \\cdot %s$, where $%s$ is the %d &times; %d %s correlation matrix. Showing the head + tail rows / columns; full matrix is %d &times; %d.</p>\n",
      M_kind, sigma_sym, M_sym, M_sym, k, k,
      switch(M_kind,
        phylo = "phylogenetic", spatial = "spatial", "structured"),
      k, k
    )
  }

  # --- Stitch: worked row + matrix block, paired per submodel -----------
  pieces <- c(
    if (!is.null(worked_mu)) {
      c(
        "<p class=\"sym-caption\" style=\"font-size:0.95em;color:#374151\">For observation <em>i</em> = 1 of your data:</p>\n",
        worked_mu,
        "<p class=\"sym-caption\" style=\"font-size:0.95em;color:#374151\">Stacking the same response equation for all <em>n</em> = ",
        n, " observations:</p>\n"
      )
    },
    paste0("<div class=\"sym-eq\">$$\n", eq_mu, "\n$$</div>\n"),
    # v0.22.4 Slice 1, F2: family-aware caption. The universal
    # `Xβ̂ = μ̂` claim assumed identity-link Gaussian. For
    # additive_log (Lognormal) μ̂ is on log scale; for generalized
    # (Poisson, Beta, ...) Xβ̂ is the link-scale linear predictor η̂
    # and the back-transform μ̂ = link⁻¹(η̂) is what feeds the
    # likelihood, with no additive residual on link scale.
    {
      z_term_tex <- if (has_re) {
        # When Z is the identity on the observed levels (one obs per
        # level) the renderer drops Z from the visible block, so the
        # caption should also drop the Z factor; otherwise show Zu.
        if (isTRUE(z_is_one_to_one_flag)) " + \\hat{\\mathbf{u}}"
        else " + \\mathbf{Z}\\hat{\\mathbf{u}}"
      } else ""
      cap_open  <- "<p class=\"sym-caption\" style=\"font-size:0.85em;color:#6b7280;margin-top:0.4rem\">"
      cap_close <- "</p>\n"
      switch(
        block_shape,
        additive_gaussian = paste0(
          cap_open,
          "<strong>Left</strong>: observed vector $", resp_sym, "$. ",
          "<strong>Middle</strong>: the prediction ",
          "$\\mathbf{X}\\hat{\\boldsymbol{\\beta}}", z_term_tex,
          " = \\hat{\\boldsymbol{\\mu}}$. ",
          "<strong>Right</strong>: the residual vector ",
          "$\\hat{\\boldsymbol{\\varepsilon}} = ", resp_sym,
          " - \\hat{\\boldsymbol{\\mu}}$. ",
          "Every row of this matrix equation is one of the ",
          "response-equation rows from the worked row above.",
          cap_close
        ),
        additive_log = paste0(
          cap_open,
          "<strong>Left</strong>: log-scale observed vector ",
          "$\\log(", resp_sym, ")$. ",
          "<strong>Middle</strong>: the log-scale linear predictor ",
          "$\\mathbf{X}\\hat{\\boldsymbol{\\beta}}", z_term_tex, "$ ",
          "&mdash; this is $\\hat{\\boldsymbol{\\mu}}$, the mean of ",
          "$\\log ", resp_sym, "$ (as Tab 1 states). ",
          "<strong>Right</strong>: the log-scale residual vector ",
          "$\\hat{\\boldsymbol{\\varepsilon}}^{(\\log)} = ",
          "\\log(", resp_sym, ") - \\hat{\\boldsymbol{\\mu}}$. ",
          "Each row matches the log-scale worked row above; ",
          "back-transform via $E[", resp_sym,
          "] = \\exp(\\hat{\\mu} + \\hat{\\sigma}^2 / 2)$ to recover ",
          "the response-scale mean.",
          cap_close
        ),
        # generalized: Poisson, Beta, Binomial, Gamma, NegBinom, ...
        generalized = paste0(
          cap_open,
          "<strong>Left</strong>: linear predictor ",
          "$\\hat{\\boldsymbol{\\eta}}$ on the link scale. ",
          "<strong>Right</strong>: ",
          "$\\mathbf{X}\\hat{\\boldsymbol{\\beta}}", z_term_tex, "$ ",
          "&mdash; the same linear predictor in matrix form. ",
          "There is no additive residual on the link scale: each ",
          "$", resp_sym, "_i$ has its own likelihood row above, ",
          "$", resp_sym, "_i \\sim \\mathrm{Family}(\\hat{\\mu}_i)$, ",
          "with the response-scale mean recovered as ",
          "$\\hat{\\boldsymbol{\\mu}} = ",
          "g^{-1}(\\hat{\\boldsymbol{\\eta}})$ ",
          "(the inverse-link back-transform shown in the worked row).",
          cap_close
        )
      )
    },
    # S4: partial-pooling caption beside the BLUP block (RE fits only).
    three_views_shrinkage_caption(has_re),
    if (!is.null(eq_sigma)) {
      # v0.22.4 Slice 1, F3: per-shape sigma-submodel caption. The
      # "spread of ε̂" prose presumed additive residuals and pulled the
      # ε̂ symbol into the panel-mat for families (Beta, Gamma, ...)
      # whose sigma is a precision / shape parameter, not a residual SD.
      sigma_role_html <- switch(
        block_shape,
        additive_gaussian = paste0(
          "$\\sigma$'s job is to describe the spread of ",
          "$\\hat{\\boldsymbol{\\varepsilon}}$"
        ),
        additive_log = paste0(
          "$\\sigma$'s job is to describe the spread of the log-scale ",
          "residual $\\hat{\\boldsymbol{\\varepsilon}}^{(\\log)}$, ",
          "i.e. the SD of $\\log ", resp_sym, "$"
        ),
        # generalized: per-family meaning -- Beta precision, Gamma shape,
        # NegBinom size, etc. Defer the specific role to Tab 1 / the
        # per-family worked-row, which already labels it correctly.
        generalized = paste0(
          "$\\sigma$ here is the family's spread parameter ",
          "and is not a residual SD; see Tab 1 for its specific role ",
          "in this distribution"
        )
      )
      c(
        paste0(
          "<p class=\"sym-caption\" style=\"font-size:0.95em;",
          "color:#374151;margin-top:1.2rem\">And the $\\sigma$ submodel ",
          "(no observed counterpart -- ", sigma_role_html, "). ",
          "For the same observation <em>i</em> = 1:</p>\n"
        ),
        if (!is.null(worked_sigma)) worked_sigma else character(0),
        "<p class=\"sym-caption\" style=\"font-size:0.95em;color:#374151\">Stacking the same log-link equation for all <em>n</em> = ", n, " observations:</p>\n",
        paste0("<div class=\"sym-eq\">$$\n", eq_sigma, "\n$$</div>\n")
      )
    },
    if (!is.null(eq_M)) {
      c(
        "<p class=\"sym-caption\" style=\"font-size:0.95em;color:#374151;margin-top:1.2rem\"><strong>And the structured-covariance prior on <code>u</code></strong>. The random effect that gives this model its structural-dependence character:</p>\n",
        paste0("<div class=\"sym-eq\">$$\n", eq_M, "\n$$</div>\n"),
        M_caption
      )
    }
  )
  paste(pieces, collapse = "")
}

# Worked-row block: writes the per-observation scalar response equation
# `W_1 = beta_0 + beta_1 T_1 + ... + eps_1` once symbolically and once
# with the actual numbers. Returns a `$$ ... $$` MathJax block, or NULL
# if the model doesn't have enough structure to write a meaningful row.
three_views_worked_row <- function(ex, resp_sym = "\\mathbf{y}",
                                    family = "gaussian") {
  if (is.null(ex$y) || is.null(ex$X) || is.null(ex$beta) || is.null(ex$mu_hat))
    return(NULL)
  if (length(ex$y) < 1L || nrow(ex$X) < 1L) return(NULL)

  fmt <- function(v) formatC(v, digits = 3, format = "g")
  i  <- 1L
  X1 <- ex$X[i, ]
  W1 <- ex$y[i]
  # v0.22.2.1: mu_hat is now on response scale (link-inverted); eta_hat
  # is on linear-predictor scale. For Gaussian-additive families
  # (identity link, additive Gaussian noise) the two are equal. For
  # generalized families they differ and the worked row must show both.
  eta1 <- if (!is.null(ex$eta_hat)) ex$eta_hat[i] else ex$mu_hat[i]
  mu1  <- ex$mu_hat[i]
  eps1 <- W1 - mu1

  # If the model has random effects, the conditional mean for
  # observation i = 1 is `X[1,] beta + sum_g Z_g[1,] u_g`. The worked-row
  # symbolic + numeric line must include EVERY tier's RE contribution
  # explicitly, otherwise the arithmetic doesn't close (Pat's audit
  # caught this: readers who try to mentally check the row see
  # `X*beta + eps` != W).
  #
  # v0.22.2-discipline Slice A2: iterate ex$Z_per_tier so multi-tier
  # fits (phylo + study, animal + litter, ...) emit ONE re_group_label
  # and ONE re_contrib_num per tier. Single-tier fits fall back to the
  # historic single-term shape.
  has_re <- !is.null(ex$Z_g) && !is.null(ex$u)
  per_tier_Z_wr <- if (!is.null(ex$Z_per_tier) && length(ex$Z_per_tier) > 0L) {
    ex$Z_per_tier
  } else if (has_re) {
    stats::setNames(list(ex$Z_g), "")
  } else NULL
  per_tier_u_wr <- if (!is.null(ex$u_per_tier) && length(ex$u_per_tier) > 0L) {
    ex$u_per_tier
  } else if (has_re) {
    stats::setNames(list(ex$u), "")
  } else NULL
  re_terms_sym <- character(0L)
  re_terms_num <- character(0L)
  # Reader-facing numeric value of each displayed RE term (parallel to
  # re_terms_num) so the "with your numbers" equation can be closed at
  # display precision -- see lp_disp below.
  re_terms_val <- numeric(0L)
  if (!is.null(per_tier_Z_wr)) {
    for (gv in names(per_tier_Z_wr)) {
      Z_gv <- per_tier_Z_wr[[gv]]
      u_gv <- per_tier_u_wr[[gv]]
      if (is.null(Z_gv) || is.null(u_gv)) next
      contrib <- sum(Z_gv[i, ] * u_gv)
      active_col <- which(Z_gv[i, ] != 0)
      lvl <- if (length(active_col) == 1L) colnames(Z_gv)[active_col] else NULL
      lvl_esc <- if (!is.null(lvl) && nzchar(lvl)) {
        gsub("_", "\\_", lvl, fixed = TRUE)
      } else NULL
      group_label <- if (nzchar(gv)) {
        # Multi-tier: subscript both the tier name and the level
        # (e.g. \hat{u}_{study_ID,\,3} or \hat{u}_{phylogeny,\,Myzus\_persicae})
        gv_esc <- gsub("_", "\\_", gv, fixed = TRUE)
        if (!is.null(lvl_esc)) {
          sprintf("\\hat{u}_{\\mathrm{%s},\\,\\mathrm{%s}}", gv_esc, lvl_esc)
        } else {
          sprintf("\\hat{u}_{\\mathrm{%s},\\,\\mathrm{group}(1)}", gv_esc)
        }
      } else {
        # Single-tier back-compat: historic shape (no tier subscript)
        if (!is.null(lvl_esc)) {
          sprintf("\\hat{u}_{\\mathrm{%s}}", lvl_esc)
        } else {
          "\\hat{u}_{\\,\\mathrm{group}(1)}"
        }
      }
      re_terms_sym <- c(re_terms_sym, group_label)
      re_terms_num <- c(re_terms_num, sprintf("(%s)", fmt(contrib)))
      re_terms_val <- c(re_terms_val, as.numeric(fmt(contrib)))
    }
  }

  # Detect intercept column.
  is_intercept <- vapply(seq_along(X1), function(k) {
    nm <- names(X1)[k]
    identical(nm, "(Intercept)") || (!is.null(nm) && grepl("Intercept", nm)) ||
      all(ex$X[, k] == 1)
  }, logical(1L))

  # Build symbolic and numeric term lists side by side.
  # Derive the scalar response symbol from `resp_sym` (the matrix-form
  # symbol passed in from symbol_table). Common patterns:
  #   "\\mathbf{y}"           -> "y_{1}"
  #   "\\mathbf{body\\_mass}" -> "\\mathrm{body\\_mass}_{1}"
  #   "\\mathrm{log\\_mass}_i" -> "\\mathrm{log\\_mass}_{1}"
  # Previously hardcoded to "W_{1}" -- which was wrong for every response
  # column not named `W`. Florence-audit 2026-05-26.
  scalar_response_sym <- {
    s <- resp_sym
    # strip a trailing `_i` if present
    s <- sub("_i$", "", s)
    # \mathbf{x} -> scalar x (lowercase italic)
    bf_match <- regmatches(s, regexec("^\\\\mathbf\\{([^}]+)\\}$", s))[[1L]]
    if (length(bf_match) == 2L) {
      inner <- bf_match[[2L]]
      if (grepl("\\\\_", inner) || grepl("\\s", inner)) {
        # Multi-character / escaped underscore name: use \mathrm{...}.
        sprintf("\\mathrm{%s}_{1}", inner)
      } else {
        # Single letter: use plain italic scalar.
        sprintf("%s_{1}", tolower(inner))
      }
    } else if (grepl("^\\\\mathrm\\{", s)) {
      # already \mathrm{name}, just append _{1}
      sprintf("%s_{1}", s)
    } else {
      # fallback: assume it's a plain symbol, subscript 1
      sprintf("%s_{1}", s)
    }
  }
  beta_k <- function(k) sprintf("\\hat\\beta_{%d}", k - 1L)
  # For non-intercept columns, use the column name as a Roman label
  # (sanitized for LaTeX) with subscript i = 1.
  predictor_label <- function(k) {
    nm <- names(X1)[k]
    if (is.null(nm) || !nzchar(nm)) return(sprintf("x_{%d}", k))
    # Punch-list #9: a single-letter predictor is italic math (matching
    # Tab 1, the symbol glossary, and the dimension labels). Multi-letter
    # or transformed names stay upright \mathrm{} so they read as one
    # named object rather than a product of italic letters.
    if (grepl("^[A-Za-z]$", nm)) {
      sprintf("%s_{1}", nm)
    } else {
      sprintf("\\mathrm{%s}_{1}", gsub("_", "\\_", nm, fixed = TRUE))
    }
  }

  sym_terms <- character(length(X1))
  num_terms <- character(length(X1))
  # num_vals[k] = the value a reader gets by combining the DISPLAYED
  # (rounded) numbers in num_terms[k]: intercept -> round(beta0);
  # slope -> round(beta) * round(x). Used to close the printed equation
  # at display precision (punch-list #5) -- you cannot round a, b and
  # a+b independently and have them add up, so the residual is computed
  # against this reader-facing sum.
  num_vals  <- numeric(length(X1))
  for (k in seq_along(X1)) {
    if (is_intercept[k]) {
      sym_terms[k] <- beta_k(k)
      num_terms[k] <- fmt(ex$beta[k])
      num_vals[k]  <- as.numeric(fmt(ex$beta[k]))
    } else {
      sym_terms[k] <- paste0(beta_k(k), "\\,", predictor_label(k))
      num_terms[k] <- paste0(fmt(ex$beta[k]), " \\times ", fmt(X1[k]))
      num_vals[k]  <- as.numeric(fmt(ex$beta[k])) * as.numeric(fmt(X1[k]))
    }
  }
  # Append every tier's RE term to both lists so the symbolic and
  # numeric rows close arithmetically. Multi-tier fits emit multiple
  # \hat{u}_{...} terms in series; single-tier emits exactly one as
  # in the v0.22.1 shape.
  if (length(re_terms_sym) > 0L) {
    sym_terms <- c(sym_terms, re_terms_sym)
    num_terms <- c(num_terms, re_terms_num)
    num_vals  <- c(num_vals, re_terms_val)
  }
  sym_rhs <- paste(sym_terms, collapse = " + ")
  num_rhs <- join_signed_terms(num_terms)
  # Reader-facing linear predictor at display precision (sum of the
  # rounded terms exactly as the reader would add them up).
  lp_disp <- sum(num_vals)

  # v0.22.2.1: family-aware worked-row shape. Three patterns:
  #   "additive_gaussian"  -- y = X*beta + eps (Gaussian identity link)
  #   "additive_log"       -- log(y) = X*beta + eps_log (Lognormal,
  #                            additive Gaussian noise on log scale)
  #   "generalized"        -- eta = X*beta; mu = link_inv(eta);
  #                            y ~ Family(mu, ...); no additive eps
  # The bug surfaced by the Fisher pass on symbolizer-families.html was
  # that every family fell through to "additive_gaussian" -- mixing
  # link-scale and response-scale quantities additively and emitting a
  # meaningless ε for Poisson / Beta.
  fam_spec_wr <- worked_row_family_spec(family)
  shape <- fam_spec_wr$shape

  if (shape == "additive_gaussian") {
    # v0.22.4 #155: separate the linear-predictor build (row 2, shown with
    # \approx because the rounded terms only approximate mu_hat) from the
    # decomposition (row 3). The residual displayed is the TRUE residual
    # y - mu_hat -- identical to what the stacked matrix block shows -- so
    # the worked row and the matrix block agree on observation 1. (The old
    # #5 fix used a balancing figure that closed the explicit equation but
    # diverged from the matrix block's true residual; you cannot round a,
    # b and a+b independently and have all of {expanded row closes, true
    # residual shown, matrix block matches} hold, so we drop the
    # falsifiable numeric closure and keep the true, consistent residual.)
    eps_true <- W1 - mu1
    paste0(
      "<div class=\"sym-eq\">$$\n\\begin{aligned}\n",
      scalar_response_sym, " &= ", sym_rhs, " + \\hat\\varepsilon_{1} ",
      "&\\quad(\\text{response equation, one row of the model}) \\\\\n",
      "\\hat\\mu_{1} &= ", num_rhs, " \\approx ", fmt(mu1), " ",
      "&\\quad(\\text{predicted mean} = \\text{linear predictor}) \\\\\n",
      scalar_response_sym, " &= \\underbrace{", fmt(mu1),
      "}_{\\textstyle\\,\\hat\\mu_{1}\\,\\text{(predicted)}\\,} \\;+\\; ",
      "\\underbrace{(", fmt(eps_true),
      ")}_{\\textstyle\\,\\hat\\varepsilon_{1}\\,\\text{(residual)}\\,} ",
      "&\\quad(\\text{observed} = \\text{predicted mean} + \\text{residual})",
      "\n\\end{aligned}\n$$</div>\n"
    )
  } else if (shape == "additive_log") {
    # Lognormal: drmTMB parameterises log(Y) ~ Normal(mu, sigma^2). The
    # additive noise is on the LOG scale; the linear predictor equals the
    # mean of log(y). Same structure as additive_gaussian (#155): an
    # \approx linear-predictor build, then a decomposition that shows the
    # TRUE log-scale residual log(y) - mu_hat -- identical to the stacked
    # matrix block, so the two agree on observation 1.
    log_W1   <- log(W1)
    eps_true <- log_W1 - mu1
    paste0(
      "<div class=\"sym-eq\">$$\n\\begin{aligned}\n",
      "\\log(", scalar_response_sym, ") &= ", sym_rhs,
      " + \\hat\\varepsilon_{1}^{(\\log)} ",
      "&\\quad(\\text{response equation, log scale}) \\\\\n",
      "\\hat\\mu_{1} &= ", num_rhs, " \\approx ", fmt(mu1), " ",
      "&\\quad(\\text{log-scale mean} = \\text{linear predictor}) \\\\\n",
      "\\log(", scalar_response_sym, ") &= \\underbrace{", fmt(mu1),
      "}_{\\textstyle\\,\\hat\\mu_{1}\\,\\text{(log-scale mean)}\\,}",
      " \\;+\\; \\underbrace{(", fmt(eps_true),
      ")}_{\\textstyle\\,\\hat\\varepsilon_{1}^{(\\log)}\\,\\text{(log-scale residual)}\\,} ",
      "&\\quad(\\text{observed} = \\text{mean} + \\text{residual})",
      "\n\\end{aligned}\n$$</div>\n"
    )
  } else {
    # Generalized: no additive noise on the linear predictor. Show
    # eta_hat (linear predictor), mu_hat (response scale via link
    # inverse), and the distributional declaration. The family-dependent
    # link operator, distribution label, and likelihood argument list all
    # come from the shared family-spec helpers so the HTML and PDF
    # emitters cannot drift (#1/#3/#4, PDF/HTML parity).
    link_str     <- fam_spec_wr$link_label
    family_label <- fam_spec_wr$family_label
    lik_args     <- worked_row_lik_args(family, "\\hat\\mu_{1}", "\\hat\\sigma_{1}")
    paste0(
      "<div class=\"sym-eq\">$$\n\\begin{aligned}\n",
      "\\hat\\eta_{1} &= ", sym_rhs,
      "&\\quad(\\text{linear predictor, link scale}) \\\\\n",
      fmt(eta1), " &= ", num_rhs,
      "&\\quad(\\text{with your numbers}) \\\\\n",
      "\\hat\\mu_{1} &= ", link_str, "(\\hat\\eta_{1}) = ",
      link_str, "(", fmt(eta1), ") \\approx ", fmt(mu1),
      "&\\quad(\\text{response scale, predicted}) \\\\\n",
      scalar_response_sym, " &\\sim ", family_label, lik_args,
      "&\\quad(\\text{likelihood; no additive }\\varepsilon\\text{ here})",
      "\n\\end{aligned}\n$$</div>\n"
    )
  }
}

# Worked-row for the sigma submodel, parallel to three_views_worked_row().
# Walks observation 1 through the log-link prediction:
#   log(sigma_hat_1) = gamma_0 + gamma_1 * T_1
# in symbolic form, with numbers, and the back-transformed sigma_hat_1.
# Returns NULL if the model has no sigma submodel; matrix-block stitcher
# then skips this section.
three_views_worked_row_sigma <- function(ex, family = "gaussian") {
  if (is.null(ex$X_sigma) || is.null(ex$gamma) || is.null(ex$sigma_hat))
    return(NULL)
  if (length(ex$sigma_hat) < 1L || nrow(ex$X_sigma) < 1L) return(NULL)

  fmt <- function(v) formatC(v, digits = 3, format = "g")
  i        <- 1L
  Xs1      <- ex$X_sigma[i, ]
  sigma1   <- ex$sigma_hat[i]
  log_sig1 <- log(sigma1)

  is_intercept <- vapply(seq_along(Xs1), function(k) {
    nm <- names(Xs1)[k]
    identical(nm, "(Intercept)") || (!is.null(nm) && grepl("Intercept", nm)) ||
      all(ex$X_sigma[, k] == 1)
  }, logical(1L))

  gamma_k <- function(k) sprintf("\\hat\\gamma_{%d}", k - 1L)
  predictor_label <- function(k) {
    nm <- names(Xs1)[k]
    if (is.null(nm) || !nzchar(nm)) nm <- paste0("z_{", k, "}")
    nm <- gsub("_", "\\_", nm, fixed = TRUE)
    sprintf("\\mathrm{%s}_{1}", nm)
  }

  sym_terms <- character(length(Xs1))
  num_terms <- character(length(Xs1))
  for (k in seq_along(Xs1)) {
    if (is_intercept[k]) {
      sym_terms[k] <- gamma_k(k)
      num_terms[k] <- fmt(ex$gamma[k])
    } else {
      sym_terms[k] <- paste0(gamma_k(k), "\\,", predictor_label(k))
      num_terms[k] <- paste0(fmt(ex$gamma[k]), " \\times ", fmt(Xs1[k]))
    }
  }
  sym_rhs <- paste(sym_terms, collapse = " + ")
  num_rhs <- join_signed_terms(num_terms)  # fold '+ -' -> '-' (punch-list #7)

  # v0.22.2.1: per-family label for what the sigma submodel actually
  # parameterises. Gaussian/Student-t: residual SD. Lognormal: log-scale
  # residual SD (the SD of log y). Beta: precision phi (positive shape
  # parameter, NOT an SD). Gamma: dispersion. NegBinom: size parameter k.
  # Fisher pass on symbolizer-families.html flagged the Beta and
  # Lognormal mislabels as Pattern D.
  # NOTE: keep backslash commands OUT of these captions -- they sit
  # inside `\\text{...}` and any inline LaTeX (`\\log y`, `\\hat\\phi_{1}`,
  # etc.) breaks pandoc's math-block parser and the whole $$ aligned $$
  # block renders as raw source. Maintainer caught this on v0.22.3 with
  # the Lognormal + Beta widgets. Plain prose only.
  sigma_meaning <- switch(
    tolower(as.character(family)),
    gaussian  = "predicted residual SD for observation 1",
    student   = "predicted residual SD for observation 1",
    lognormal = "predicted log-scale residual SD for observation 1 (SD of log y)",
    beta      = "predicted precision parameter for observation 1 (positive shape, not an SD)",
    gamma     = "predicted dispersion for observation 1",
    nbinom1   = "predicted dispersion (size parameter k) for observation 1",
    nbinom2   = "predicted dispersion (size parameter k) for observation 1",
    "predicted dispersion parameter for observation 1"
  )
  # v0.22.4 Slice 1d: for intercept-only sigma submodels (sigma ~ 1),
  # `num_rhs` is the single number `fmt(gamma_0)` which numerically
  # equals `fmt(log_sig1)`. Emitting `&= num_rhs = fmt(log_sig1)` then
  # renders as `= -0.764 = -0.764` -- a visible redundancy in every
  # Lognormal / Beta / Gamma fit with the default `sigma ~ 1`. Drop
  # the trailing `= fmt(log_sig1)` when it would duplicate `num_rhs`.
  # Florence spotted this post-Slice-1 on the families article.
  # NOTE: use unname() because `ex$sigma_hat` is a named numeric vector
  # in drmTMB output, so `fmt(log_sig1)` carries a `names` attribute
  # that breaks `identical()` even when the string values match.
  log_sig1_str <- unname(fmt(log_sig1))
  num_rhs_value <- if (identical(unname(num_rhs), log_sig1_str)) {
    num_rhs
  } else {
    paste0(num_rhs, " = ", log_sig1_str)
  }
  paste0(
    "<div class=\"sym-eq\">$$\n\\begin{aligned}\n",
    "\\log\\hat\\sigma_{1} &= ", sym_rhs, " ",
    "&\\quad(\\text{sigma submodel for observation 1, log link}) \\\\\n",
    "\\log\\hat\\sigma_{1} &= ", num_rhs_value, " ",
    "&\\quad(\\text{with your numbers}) \\\\\n",
    "\\hat\\sigma_{1} &= \\exp(", fmt(log_sig1), ") \\approx ", fmt(sigma1), " ",
    "&\\quad(\\text{", sigma_meaning, "})",
    "\n\\end{aligned}\n$$</div>\n"
  )
}

# Symbol gloss for the Index / Matrix panels: one short line per symbol
# carrying the symbol (MathJax), its concrete dimension, and the meaning.
# Sourced from symbol_table(x, notation = "index" | "matrix") so the
# gloss matches the equation block on the same panel. Falls back silently
# to empty if the table is unavailable.
three_views_symbol_gloss <- function(x, notation = c("matrix", "index")) {
  notation <- match.arg(notation)
  rt <- tryCatch(symbol_table(x, notation = notation),
                 error = function(e) NULL)
  if (is.null(rt) || nrow(rt) == 0L) return("")
  sym_col <- if (notation == "matrix") "symbol_matrix" else "symbol_index"
  if (!sym_col %in% names(rt)) {
    # symbol_table with notation = "index" used to return the scalar
    # symbol under `symbol_matrix` for back-compat -- be defensive.
    sym_col <- intersect(c("symbol_index", "symbol_matrix", "symbol"),
                        names(rt))[1L]
    if (is.na(sym_col)) return("")
  }
  # Only wrap content that actually IS LaTeX (starts with `\`) in
  # math delimiters. We use `$...$` not `\(...\)` because pandoc
  # processes `<li>` content as markdown by default and DOESN'T
  # recognise `\(...\)` as math (the `tex_math_single_backslash`
  # extension is off by default), so it interprets `\mu` as an escape
  # sequence and eats it -- the gloss line ends up reading "(_i)
  # conditional mu" instead of "$\mu_i$ conditional mu". With `$...$`
  # pandoc uses `tex_math_dollars` (on by default) and preserves the
  # LaTeX intact for MathJax to render in the browser.
  # `dimension_concrete` for predictor columns carries prose like
  # "column of X (length 200)" which doesn't start with `\` and is
  # passed through unwrapped.
  # Two wrappers: the symbol column is ALWAYS math (e.g. `W_i`, `T_i`,
  # `\mu_i`, `\beta_{0}, \beta_{1}`). Always wrap. The dimension column
  # is sometimes math (`\mathbb{R}^{200}`) and sometimes prose
  # ("column of X (length 200)"); only wrap if it looks like LaTeX.
  wrap_always <- function(s) {
    if (is.na(s) || !nzchar(s)) return("")
    paste0("$", s, "$")
  }
  wrap_if_latex <- function(s) {
    if (is.na(s) || !nzchar(s)) return("")
    if (startsWith(s, "\\")) paste0("$", s, "$")
    else                     s
  }
  ok <- !is.na(rt[[sym_col]]) & nzchar(rt[[sym_col]]) &
        !is.na(rt$description)   & nzchar(rt$description)
  rt <- rt[ok, , drop = FALSE]
  if (nrow(rt) == 0L) return("")
  items <- vapply(seq_len(nrow(rt)), function(i) {
    sym  <- wrap_always(rt[[sym_col]][[i]])
    dim  <- if ("dimension_concrete" %in% names(rt))
              wrap_if_latex(rt$dimension_concrete[[i]]) else ""
    desc <- rt$description[[i]]
    paste0("<li>", sym, " &mdash; ", desc,
           if (nzchar(dim)) paste0(" &nbsp;<span class=\"sym-dim\">", dim, "</span>") else "",
           "</li>")
  }, character(1L))
  paste0(
    "<details class=\"sym-gloss\" open>\n",
    "<summary>where:</summary>\n",
    "<ul class=\"sym-gloss-list\">\n",
    paste(items, collapse = "\n"),
    "\n</ul>\n",
    "</details>\n"
  )
}

# One-sentence whole-model biological reading, shown above the equation
# on each tab. Family-aware: only Gaussian (location-only or
# location-scale, with or without random effects) has a template at
# v0.19; other families return "" and the panel renders without a
# biology gloss until templates are added. Observational language only
# ("rises with", "is multiplied by"); never causal ("effect of",
# "due to"). For v0.20 these templates move into a CSV so the prose
# can be edited without code changes.
# v0.22.4 #6: per-family "coefficient reading on the response scale" --
# the single most useful sentence for a biologist (rate ratio / odds
# ratio / geometric-mean multiplier). Prose lives in
# inst/extdata/coef-readings.csv (architectural rule: no string-spliced
# prose in R). Returns "" for families without a clean single-slope
# reading (latent-variable / ordinal), so the caller emits nothing.
three_views_coef_reading <- function(family) {
  if (is.null(family) || !nzchar(family)) return("")
  tbl <- tryCatch(load_template("coef-readings"), error = function(e) NULL)
  if (is.null(tbl) || !"family" %in% names(tbl)) return("")
  hit <- tbl[tbl$family == family, , drop = FALSE]
  if (nrow(hit) == 0L) return("")
  hit$coef_reading[[1L]]
}

# v0.22.4 #11: per-family numeric diagnostic surfaced inside the widget.
# Currently: a Beta fit whose implied shape parameters at observation 1
# (alpha = mu*phi, beta = (1-mu)*phi) are BOTH below 1 is U-shaped (mass
# piled near 0 and 1), which a "precision" label alone hides. The
# condition is checked in R from the already-available mu_hat / sigma_hat;
# the prose is templated from inst/extdata/family-diagnostics.csv (no
# string-spliced prose in R). Returns "" when the condition does not hold
# or for non-Beta families.
three_views_family_diagnostic <- function(x) {
  family <- tryCatch(x$model$family, error = function(e) NULL)
  if (is.null(family) || !identical(tolower(family), "beta")) return("")
  ex <- x$expanded
  if (is.null(ex) || is.null(ex$mu_hat) || is.null(ex$sigma_hat)) return("")
  mu1  <- ex$mu_hat[[1L]]
  phi1 <- ex$sigma_hat[[1L]]
  if (!is.finite(mu1) || !is.finite(phi1)) return("")
  a <- mu1 * phi1
  b <- (1 - mu1) * phi1
  if (!(is.finite(a) && is.finite(b) && a < 1 && b < 1)) return("")
  tbl <- tryCatch(load_template("family-diagnostics"), error = function(e) NULL)
  if (is.null(tbl) || !"family" %in% names(tbl)) return("")
  hit <- tbl[tbl$family == "beta", , drop = FALSE]
  if (nrow(hit) == 0L) return("")
  fmt <- function(v) formatC(v, digits = 2, format = "g")
  tmpl <- hit$template[[1L]]
  tmpl <- gsub("{alpha}", fmt(a), tmpl, fixed = TRUE)
  tmpl <- gsub("{beta}",  fmt(b), tmpl, fixed = TRUE)
  paste0("  <p class=\"sym-biology\">", tmpl, "</p>\n")
}

# Variance-components surface (docs/specs/variance-components.md, S3): the
# "where does the variation live?" panel for the Index tab, sitting beneath
# the random-effects glossary. Reuses the variance_partition() / icc()
# accessors and renders a plain-CSS-div bar (no JS, survives PDF): a single
# stacked between/within bar for exactly two variance components, per-component
# bars for three or more. Below the bar sit one sentence and the ICC line --
# with the latent-scale caption for binomial, or the "not available on this
# scale yet" line when the ICC is undefined (Poisson, location-scale, >1 RE).
# All prose is templated from inst/extdata/variance-readings.csv. Returns ""
# when the fit has no random effects (nothing to partition).
three_views_variance_panel <- function(x) {
  re <- tryCatch(vc_re_rows(x$variance_components), error = function(e) NULL)
  if (is.null(re) || nrow(re) == 0L) return("")
  vp <- tryCatch(variance_partition(x), error = function(e) NULL)
  ic <- tryCatch(icc(x), error = function(e) NULL)
  if (is.null(vp) || is.null(ic) || nrow(vp) == 0L) return("")

  has_pct <- all(is.finite(vp$pct))
  body <- if (has_pct) {
    if (nrow(vp) == 2L) vc_bar_stacked(vp) else vc_bar_per_component(vp)
  } else {
    vc_component_list(vp)
  }
  intro <- variance_reading("partition_intro")

  paste0(
    "<div class=\"sym-vc-panel\" style=\"margin-top:1rem;border-top:1px solid #eee;padding-top:0.7rem\">\n",
    "  <p class=\"sym-caption\"><strong>Where does the variation live?</strong> ",
    intro, "</p>\n",
    body,
    vc_icc_line(ic),
    "  <p class=\"sym-caption\" style=\"font-size:0.8em;color:#9ca3af;margin-top:0.3rem\">Point estimates only; uncertainty not shown.</p>\n",
    "</div>\n"
  )
}

# Variance-components surface (S4, contract clause 6): a prose-only
# partial-pooling caption that sits beside the worked-row BLUP block,
# explaining that the random-effect estimates are shrunk toward zero. Emitted
# only when the fit has random effects. No numbers (numeric shrinkage
# deferred). Prose from inst/extdata/variance-readings.csv.
three_views_shrinkage_caption <- function(has_re) {
  if (!isTRUE(has_re)) return("")
  txt <- variance_reading("shrinkage_caption")
  if (!nzchar(txt)) return("")
  paste0(
    "<p class=\"sym-caption\" style=\"font-size:0.85em;color:#6b7280;margin-top:0.3rem\">",
    "<strong>Partial pooling.</strong> ", txt, "</p>\n"
  )
}

# Option A: a single horizontal bar split into between / within segments
# (exactly two variance components). Colours: between = teal, residual = grey.
vc_bar_stacked <- function(vp) {
  cols <- c("#2c7fb8", "#d9d9d9")
  segs <- vapply(seq_len(nrow(vp)), function(i) {
    w   <- formatC(100 * vp$pct[[i]], digits = 1L, format = "f")
    col <- cols[[min(i, length(cols))]]
    txt <- if (i == 1L) "#fff" else "#333"
    sprintf(
      "<div style=\"width:%s%%;background:%s;color:%s;text-align:center;white-space:nowrap;overflow:hidden;text-overflow:ellipsis\" title=\"%s\">%s %s%%</div>",
      w, col, txt, vp$component[[i]], vp$component[[i]], w)
  }, character(1L))
  paste0(
    "  <div class=\"sym-vc-bar sym-vc-stacked\" role=\"img\" aria-label=\"variance partition\" style=\"display:flex;width:100%;height:1.8rem;border-radius:4px;overflow:hidden;font-size:0.78rem;line-height:1.8rem;margin:0.4rem 0\">\n    ",
    paste(segs, collapse = "\n    "),
    "\n  </div>\n"
  )
}

# Option B: one labelled track per component (three or more components).
vc_bar_per_component <- function(vp) {
  pal <- c("#2c7fb8", "#7fcdbb", "#fec44f", "#d95f0e", "#756bb1")
  rows <- vapply(seq_len(nrow(vp)), function(i) {
    w   <- formatC(100 * vp$pct[[i]], digits = 1L, format = "f")
    res <- grepl("^Residual", vp$component[[i]])
    col <- if (res) "#d9d9d9" else pal[[((i - 1L) %% length(pal)) + 1L]]
    sprintf(paste0(
      "    <div class=\"sym-vc-row\" style=\"display:flex;align-items:center;margin:0.25rem 0;font-size:0.8rem\">\n",
      "      <span style=\"flex:0 0 38%%;color:#374151;white-space:nowrap;overflow:hidden;text-overflow:ellipsis\">%s</span>\n",
      "      <span style=\"flex:1;background:#f3f4f6;border-radius:3px;overflow:hidden\"><span style=\"display:block;width:%s%%;background:%s;color:#fff;padding:0.1rem 0.35rem;white-space:nowrap;box-sizing:border-box\">%s%%</span></span>\n",
      "    </div>"),
      vp$component[[i]], w, col, w)
  }, character(1L))
  paste0(
    "  <div class=\"sym-vc-bar sym-vc-bars\" role=\"img\" aria-label=\"variance partition\" style=\"margin:0.4rem 0\">\n",
    paste(rows, collapse = "\n"),
    "\n  </div>\n"
  )
}

# Text fallback when shares are undefined (no residual on a single scale):
# the contract is "show the table" without a misleading bar.
vc_component_list <- function(vp) {
  items <- vapply(seq_len(nrow(vp)), function(i) {
    sprintf("<li>%s: variance = %s</li>", vp$component[[i]],
            formatC(vp$variance[[i]], digits = 3L, format = "fg", flag = "#"))
  }, character(1L))
  paste0(
    "  <ul class=\"sym-vc-list\" style=\"font-size:0.82rem;color:#374151;margin:0.3rem 0;padding-left:1.1rem\">\n    ",
    paste(items, collapse = "\n    "),
    "\n  </ul>\n"
  )
}

# The ICC line: scale-labelled value + caption, or the "not available" line
# with its reason. Prose from variance-readings.csv.
vc_icc_line <- function(ic) {
  v <- as.numeric(unclass(ic))
  if (!is.finite(v)) {
    msg    <- variance_reading("icc_unavailable")
    reason <- attr(ic, "reason")
    why <- if (!is.null(reason) && !is.na(reason) && nzchar(reason)) {
      sprintf(" <span style=\"color:#9ca3af\">(%s)</span>", reason)
    } else {
      ""
    }
    return(sprintf(
      "  <p class=\"sym-vc-icc\" style=\"margin:0.4rem 0\"><strong>ICC:</strong> %s%s</p>\n",
      msg, why))
  }
  sc  <- attr(ic, "scale")
  cap <- attr(ic, "caption")
  cap_html <- if (!is.null(cap) && !is.na(cap) && nzchar(cap)) {
    sprintf(" <span style=\"color:#6b7280;font-style:italic\">%s</span>", cap)
  } else {
    ""
  }
  sprintf(
    "  <p class=\"sym-vc-icc\" style=\"margin:0.4rem 0\"><strong>ICC (%s scale):</strong> %s.%s</p>\n",
    sc, formatC(v, digits = 3L, format = "f"), cap_html)
}

three_views_biology_gloss <- function(x) {
  family <- tryCatch(x$model$family, error = function(e) NULL)
  if (is.null(family) || !nzchar(family)) return("")

  # v0.21.1+ phylo / spatial branches. The default Gaussian biology gloss
  # "each observation is normally distributed around a mean..." is wrong
  # for comparative-phylogenetic and spatial models: those models exist
  # PRECISELY because observations are NOT independent. Detect via
  # metadata$phylo_representation / metadata$spatial_representation set by
  # extractors when phylo / spatial structured covariance is detected.
  phylo_rep <- tryCatch(x$metadata$phylo_representation,
                        error = function(e) NULL)
  spatial_rep <- tryCatch(x$metadata$spatial_representation,
                          error = function(e) NULL)
  if (!is.null(phylo_rep) && nzchar(phylo_rep)) {
    sentence <- paste0(
      "Species are not independent observations. Closely related species ",
      "tend to have similar trait values because of shared evolutionary ",
      "history; the phylogenetic correlation matrix $\\mathbf{A}$ encodes ",
      "those expected similarities (cell $A_{ij}$ = fraction of shared ",
      "branch length between species $i$ and $j$). The phylogenetic SD ",
      "$\\sigma_p$ measures how much across-species variation remains after ",
      "fixed-effect predictors are accounted for."
    )
    return(paste0("  <p class=\"sym-biology\">", sentence, "</p>\n"))
  }
  if (!is.null(spatial_rep) && nzchar(spatial_rep)) {
    sentence <- paste0(
      "Nearby locations are not independent observations. Sites close ",
      "together tend to have similar response values because of shared ",
      "environment; the spatial correlation matrix $\\boldsymbol{\\Omega}$ ",
      "encodes those expected similarities via a distance kernel (cell ",
      "$\\Omega_{ij}$ decreases with distance between locations $i$ and $j$). ",
      "The spatial SD $\\sigma_\\omega$ measures how much across-site ",
      "variation remains after fixed-effect predictors are accounted for."
    )
    return(paste0("  <p class=\"sym-biology\">", sentence, "</p>\n"))
  }
  # GLLVM (latent-variable) branch: detect via Lambda_B on $expanded.
  # Tailor the sentence to Widget 1 (between-only) vs Widget 2 (two-tier).
  has_Lambda_B <- !is.null(x$expanded) && !is.null(x$expanded$Lambda_B)
  has_Lambda_W <- !is.null(x$expanded) && !is.null(x$expanded$Lambda_W)
  if (has_Lambda_B) {
    sentence <- if (has_Lambda_W) {
      paste0(
        "Each observation is normally distributed around its trait's grand ",
        "mean shifted by <em>two</em> latent-axis contributions: the ",
        "individual's position on the shared between-individual axes ",
        "($\\boldsymbol{\\Lambda}_B \\mathbf{z}_{B,i}$) <em>and</em> the ",
        "(individual, session)'s position on the shared within-individual ",
        "axes ($\\boldsymbol{\\Lambda}_W \\mathbf{z}_{W,ij}$). Per-tier ",
        "trait-specific uniquenesses ($\\boldsymbol{\\Psi}_B$, ",
        "$\\boldsymbol{\\Psi}_W$) absorb the residual variance each tier's ",
        "shared axes do not explain."
      )
    } else {
      paste0(
        "Each observation is normally distributed around its trait's grand ",
        "mean shifted by the individual's position on the shared ",
        "between-individual axes ($\\boldsymbol{\\Lambda}_B \\mathbf{z}_{B,i}$). ",
        "Trait-specific between-individual uniquenesses ($\\boldsymbol{\\Psi}_B$) ",
        "absorb the residual variance the shared axes do not explain; the ",
        "scalar $\\sigma_\\epsilon^2$ captures within-individual ",
        "occasion-to-occasion noise."
      )
    }
    return(paste0("  <p class=\"sym-biology\">", sentence, "</p>\n"))
  }

  has_sigma_submodel <- !is.null(x$expanded) &&
                       !is.null(x$expanded$X_sigma) &&
                       !is.null(x$expanded$gamma)
  # A constant-sigma fit has X_sigma populated but with a single
  # intercept-only column -- the model says `sigma_i = exp(gamma_0)`,
  # i.e. the same value for every observation. Treat this the same as
  # no sigma submodel for the purpose of the biology gloss.
  sigma_varies <- has_sigma_submodel &&
                  !is.null(ncol(x$expanded$X_sigma)) &&
                  ncol(x$expanded$X_sigma) > 1L
  has_re <- !is.null(x$random_effects) &&
            (is.data.frame(x$random_effects) || is.list(x$random_effects)) &&
            length(x$random_effects) > 0L
  # The has_re check above is loose -- real "does this fit have random
  # effects" is whether any predictor is grouped. Use the expanded view
  # as the second tell.
  has_re <- has_re ||
            (!is.null(x$expanded) && !is.null(x$expanded$Z_g) && !is.null(x$expanded$u))

  sentence <- if (identical(family, "gaussian")) {
    if (sigma_varies && has_re) {
      "Each observation is normally distributed around a mean that may shift with the fixed-effect predictors and a group offset, with a residual SD that may also shift with its own predictors -- both location and spread are modeled."
    } else if (sigma_varies) {
      "Each observation is normally distributed around a mean that may shift with the predictors, and a residual SD that may also shift with its own predictors -- so both the centre and the spread of the response are modeled."
    } else if (has_re) {
      "Each observation is normally distributed around a group-specific mean; the random-effect SD captures how much groups vary, and the residual SD captures within-group variation."
    } else {
      "Each observation is normally distributed around a mean that may shift with the predictors; the residual SD is constant across observations."
    }
  } else if (identical(family, "binomial")) {
    "Each observation is a Bernoulli / binomial trial; the log-odds of success may shift with the predictors."
  } else if (identical(family, "poisson")) {
    "Each observation is a count; the log of the expected count may shift with the predictors."
  } else {
    return("")
  }
  paste0(
    "  <p class=\"sym-biology\">", sentence, "</p>\n"
  )
}

three_views_css <- function() {
'.sym-tabs { position: relative; border: 1px solid #e5e7eb; border-radius: 8px; overflow: hidden; margin: 1em 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
.sym-tablist { display: flex; background: #f9fafb; border-bottom: 1px solid #e5e7eb; }
.sym-tab { flex: 1; text-align: center; padding: 0.6rem 0.5rem; cursor: pointer; font-weight: 600; color: #6b7280; border: 0; border-right: 1px solid #e5e7eb; background: transparent; user-select: none; font-size: 0.92rem; font-family: inherit; }
.sym-tab:last-child { border-right: 0; }
.sym-tab:hover { background: #fbe7e7; color: #7a2a2a; }
.sym-tab.sym-active { background: #fff; color: #8a1f22; box-shadow: inset 0 -3px 0 #a0282b; }
.sym-tab:focus-visible { outline: 2px solid #a0282b; outline-offset: -2px; }
.sym-tab-marker { display: inline-block; margin-right: 0.35em; opacity: 0; transition: opacity 0.1s; }
.sym-tab.sym-active .sym-tab-marker { opacity: 1; }
.sym-panel { padding: 1rem 1.1rem 1.2rem; }
.sym-panel[hidden] { display: none; }
.sym-eq { background: #fbe7e7; border: 1px solid #a0282b; border-radius: 6px; padding: 0.7rem 1rem; margin: 0.4rem 0; text-align: center; overflow-x: auto; max-width: 100%; }
.sym-caption { color: #6b7280; font-size: 0.85rem; margin: 0.2rem 0 0.4rem; }
.sym-biology { color: #1f6feb; background: #f0f5ff; border-left: 3px solid #1f6feb; padding: 0.55rem 0.8rem; margin: 0.5rem 0 0.8rem; font-size: 0.95rem; line-height: 1.5; font-style: italic; }
.sym-gloss { margin: 0.8rem 0 0.2rem; font-size: 0.9rem; color: #374151; }
.sym-gloss > summary { cursor: pointer; font-weight: 600; color: #6b7280; padding: 0.2rem 0; }
.sym-gloss > summary:hover { color: #8a1f22; }
.sym-gloss-list { list-style: none; padding-left: 0.6rem; margin: 0.4rem 0 0.2rem; }
.sym-gloss-list li { margin: 0.4rem 0; line-height: 1.7; }
.sym-dim { color: #6b7280; font-size: 0.85rem; }
.sym-matrix { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 0.78rem; line-height: 1.35; white-space: pre; overflow-x: auto; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px; padding: 0.6rem 0.8rem; margin: 0.3rem 0; }
.sym-sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
.sym-skip { position: absolute; top: -100px; left: 0; padding: 0.4rem 0.7rem; background: #8a1f22; color: #fff; text-decoration: none; font-size: 0.85rem; z-index: 5; }
.sym-skip:focus { top: 0; }'
}

three_views_js <- function(uid) {
  # IMPORTANT: This JS contains `\"` escape sequences inside the
  # querySelectorAll() string literals. If you write this function
  # body as an ordinary R single- or double-quoted string, R's
  # string parser will strip the backslashes ("\"" -> '"'), and the
  # browser will then see invalid JS like
  #     querySelectorAll("[role="tab"]")
  # which is a syntax error -- the IIFE never installs the click
  # handlers and tab switching silently fails. Use a raw R string
  # (R >= 4.0) so the `\"` survives verbatim into the rendered
  # <script> block.
  sprintf(
r"---((function() {
  var root = document.getElementById("%s");
  if (!root) return;
  var tabs   = Array.prototype.slice.call(root.querySelectorAll("[role=\"tab\"]"));
  var panels = Array.prototype.slice.call(root.querySelectorAll("[role=\"tabpanel\"]"));
  function activate(idx) {
    tabs.forEach(function(t, i) {
      var on = (i === idx);
      t.classList.toggle("sym-active", on);
      t.setAttribute("aria-selected", on ? "true" : "false");
      t.setAttribute("tabindex", on ? "0" : "-1");
    });
    panels.forEach(function(p, i) {
      var on = (i === idx);
      p.classList.toggle("sym-active", on);
      if (on) { p.removeAttribute("hidden"); } else { p.setAttribute("hidden", ""); }
    });
    if (typeof window.MathJax !== "undefined" && window.MathJax.typesetPromise) {
      try { window.MathJax.typesetPromise([panels[idx]]); } catch (e) {}
    }
  }
  tabs.forEach(function(t, idx) {
    t.addEventListener("click", function() { activate(idx); t.focus(); });
    t.addEventListener("keydown", function(e) {
      var k = e.key;
      var n = tabs.length;
      var next = null;
      if (k === "ArrowRight") next = (idx + 1) %% n;
      else if (k === "ArrowLeft") next = (idx - 1 + n) %% n;
      else if (k === "Home") next = 0;
      else if (k === "End") next = n - 1;
      else if (k === "Enter" || k === " ") { activate(idx); e.preventDefault(); return; }
      if (next !== null) { activate(next); tabs[next].focus(); e.preventDefault(); }
    });
  });
})();)---", uid)
}
