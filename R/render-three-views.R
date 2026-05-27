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
#' @param head Number of leading rows to show in the matrix view (default 5).
#' @param tail Number of trailing rows to show in the matrix view (default 2).
#' @param id A short identifier so multiple panels can co-exist on one page.
#' @param ... Reserved for future use.
#'
#' @return A character vector (HTML), invisible.
#' @export
as_html_three_views <- function(x, head = 5L, tail = 2L,
                                id = "sym", ...) {
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
                                                  id = "sym", ...) {
  eq_lines  <- x$components$equation_matrix
  idx_lines <- x$components$equation
  has_re <- !is.null(x$expanded) && !is.null(x$expanded$Z_g)
  matrix_block   <- three_views_matrix_block(x, head = head, tail = tail)
  matrix_summary <- three_views_matrix_summary(has_re)

  uid <- paste0("sym-", gsub("[^a-zA-Z0-9]", "", id), "-",
                as.integer(Sys.time()))
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
  idx_panel <- paste0(
    "<div class=\"sym-panel sym-active\" role=\"tabpanel\" id=\"", pan_idx,
    "\" aria-labelledby=\"", tab_idx, "\" data-panel=\"idx\" tabindex=\"0\">\n",
    "  <p class=\"sym-caption\">What happens for each observation <em>i</em> -- the per-individual reading.</p>\n",
    bio_gloss,
    "  <div class=\"sym-eq\">$$\\begin{aligned}\n",
    paste0(vapply(idx_lines, align_at, character(1L)), collapse = " \\\\\n"),
    "\n\\end{aligned}$$</div>\n",
    gloss_index,
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
  mat_panel <- paste0(
    "<div class=\"sym-panel\" role=\"tabpanel\" id=\"", pan_mat,
    "\" aria-labelledby=\"", tab_mat, "\" data-panel=\"mat\" hidden tabindex=\"0\">\n",
    "  <p class=\"sym-caption\">The same matrix equation, with your actual numbers stacked inside the brackets -- what the computer multiplies. Showing first ", head, " and last ", tail, " rows of n = ", x$model$n_obs, ".</p>\n",
    bio_gloss,
    "  <span class=\"sym-sr-only\">", matrix_summary, "</span>\n",
    matrix_block,
    "</div>\n"
  )

  marker <- "<span class=\"sym-tab-marker\" aria-hidden=\"true\">&#9656;</span>"
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
  cat(html)
  invisible(html)
}

three_views_matrix_summary <- function(has_re) {
  base <- paste0(
    "Matrix-form expansion of the model. Each row shows the response y_i ",
    "and the corresponding row of the design matrix X (showing head and ",
    "tail rows of the n total observations), with the coefficient vector ",
    "beta listed below."
  )
  if (has_re) {
    paste0(base,
           " A random-effect indicator matrix Z_g and the predicted BLUPs u ",
           "are also shown.")
  } else {
    base
  }
}

three_views_matrix_block <- function(x, head = 5L, tail = 2L) {
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
  # least one non-zero entry within the visible row band. Falls back to
  # plain head/tail when the matrix has no obvious sparsity story.
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
    if (length(nz_head) > 0L || length(nz_tail) > 0L) {
      # Smart truncation: fill head with informative cols first, then any
      # leading cols; same for tail. Keeps the non-zero entries visible.
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
        if (is.na(i) && is.na(j)) "\\ddots"          # row-trunc x col-trunc
        else if (is.na(i))         "\\vdots"          # row-trunc, real col
        else if (is.na(j))         "\\cdots"          # real row, col-trunc
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

  # --- Block 1: response equation `w = X beta_hat (+ Z_g u_hat) + eps_hat`
  # Pedagogically this is the matrix-form RESPONSE equation, not the
  # conditional-mean equation. Tab 2 (the abstraction tab) shows
  # `\boldsymbol{\mu} = \mathbf{X}\boldsymbol{\beta}` -- the conditional
  # mean, no error term. Tab 3 (this one) drops down a level of honesty:
  # it shows the observed vector `w`, the prediction `X\hat\beta`
  # (= `\hat\mu`), AND the residual vector `\hat\varepsilon = w - \hat\mu`.
  # Every row of THIS equation is exactly one of the per-observation
  # response equations the worked-row block right above shows in scalar
  # arithmetic. The matrix block IS the worked row, stacked n times.
  eps_hat  <- ex$y - ex$mu_hat
  y_vec    <- latex_vec(ex$y,     rows)
  X_mat    <- latex_mat(ex$X,     rows)
  beta_vec <- latex_vec(ex$beta)
  eps_vec  <- latex_vec(eps_hat,  rows)
  y_lab    <- sprintf("%s_{\\,%d \\times 1}\\;\\text{(observed)}",
                      resp_sym, n)
  X_lab    <- sprintf("\\mathbf{X}_{\\,%d \\times %d}", n, ncol(ex$X))
  beta_lab <- sprintf("\\hat{\\boldsymbol{\\beta}}_{\\,%d \\times 1}\\;\\text{(estimated)}",
                      length(ex$beta))
  eps_lab  <- sprintf("\\hat{\\boldsymbol{\\varepsilon}}_{\\,%d \\times 1}\\;\\text{(residual)}",
                      n)

  eq_mu <- paste0(
    underbrace(y_vec,    y_lab),    " \\;=\\; ",
    underbrace(X_mat,    X_lab),    "\\, ",
    underbrace(beta_vec, beta_lab)
  )
  if (has_re) {
    # Pattern O cont'd: Z's columns and u's rows share the random-effect
    # level dimension. When we truncate Z's columns (head + cdots + tail),
    # u's row truncation must use the SAME indices so the entries align
    # in the matrix multiplication Z u. Closes B77 (u-vector untruncated).
    z_col_idx <- trunc_col_idx(ex$Z_g, rows, head = 5L, tail = 2L)
    Zg_mat  <- latex_mat(ex$Z_g, rows)
    u_vec   <- latex_vec(ex$u, z_col_idx)
    Zg_lab  <- sprintf("\\mathbf{Z}_{\\,%d \\times %d}",
                       n, ncol(ex$Z_g))
    u_lab   <- sprintf("\\hat{\\mathbf{u}}_{\\,%d \\times 1}\\;\\text{(BLUP)}",
                       length(ex$u))
    eq_mu <- paste0(
      eq_mu, " \\;+\\; ",
      underbrace(Zg_mat, Zg_lab), "\\, ",
      underbrace(u_vec,  u_lab)
    )
  }
  # Close the response equation with the residual vector.
  eq_mu <- paste0(
    eq_mu, " \\;+\\; ",
    underbrace(eps_vec, eps_lab)
  )

  # --- Block 2: sigma submodel (only when distributional) ----------------
  eq_sigma <- if (has_sigma) {
    sigma_vec <- latex_vec(ex$sigma_hat, rows)
    Xs_mat    <- latex_mat(ex$X_sigma, rows)
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
  worked_mu    <- three_views_worked_row(ex, resp_sym)
  worked_sigma <- three_views_worked_row_sigma(ex)

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
    paste0("<p class=\"sym-caption\" style=\"font-size:0.85em;color:#6b7280;margin-top:0.4rem\"><strong>Left</strong>: observed vector \\(\\mathbf{w}\\). <strong>Middle</strong>: the prediction \\(\\mathbf{X}\\hat{\\boldsymbol{\\beta}}",
           if (has_re) " + \\mathbf{Z}\\hat{\\mathbf{u}}" else "",
           " = \\hat{\\boldsymbol{\\mu}}\\). <strong>Right</strong>: the residual vector \\(\\hat{\\boldsymbol{\\varepsilon}} = \\mathbf{w} - \\hat{\\boldsymbol{\\mu}}\\). Every row of this matrix equation is one of the response-equation rows from the worked row above.</p>\n"),
    if (!is.null(eq_sigma)) {
      c(
        "<p class=\"sym-caption\" style=\"font-size:0.95em;color:#374151;margin-top:1.2rem\">And the \\(\\sigma\\) submodel (no observed counterpart -- \\(\\sigma\\)'s job is to describe the spread of \\(\\hat{\\boldsymbol{\\varepsilon}}\\)). For the same observation <em>i</em> = 1:</p>\n",
        if (!is.null(worked_sigma)) worked_sigma else character(0),
        "<p class=\"sym-caption\" style=\"font-size:0.95em;color:#374151\">Stacking the same log-link equation for all <em>n</em> = ", n, " observations:</p>\n",
        paste0("<div class=\"sym-eq\">$$\n", eq_sigma, "\n$$</div>\n")
      )
    }
  )
  paste(pieces, collapse = "")
}

# Worked-row block: writes the per-observation scalar response equation
# `W_1 = beta_0 + beta_1 T_1 + ... + eps_1` once symbolically and once
# with the actual numbers. Returns a `$$ ... $$` MathJax block, or NULL
# if the model doesn't have enough structure to write a meaningful row.
three_views_worked_row <- function(ex, resp_sym = "\\mathbf{y}") {
  if (is.null(ex$y) || is.null(ex$X) || is.null(ex$beta) || is.null(ex$mu_hat))
    return(NULL)
  if (length(ex$y) < 1L || nrow(ex$X) < 1L) return(NULL)

  fmt <- function(v) formatC(v, digits = 3, format = "g")
  i  <- 1L
  X1 <- ex$X[i, ]
  W1 <- ex$y[i]
  mu1 <- ex$mu_hat[i]
  eps1 <- W1 - mu1

  # If the model has a random effect, the conditional mean for
  # observation i = 1 is `X[1,] beta + Z_g[1,] u`. The worked-row
  # symbolic + numeric line must include the RE contribution explicitly,
  # otherwise the arithmetic doesn't close (Pat's audit caught this:
  # readers who try to mentally check the row see `X*beta + eps` != W).
  has_re <- !is.null(ex$Z_g) && !is.null(ex$u)
  re_contrib_num <- if (has_re) sum(ex$Z_g[i, ] * ex$u) else 0
  # Find which level of which RE group observation i = 1 belongs to (we
  # use it to build a symbolic label `\hat{u}_{group(1)}`). For simple
  # `(1|group)` models, Z_g is a one-hot indicator and the active column
  # is the group label.
  re_group_label <- NULL
  if (has_re) {
    active_col <- which(ex$Z_g[i, ] != 0)
    if (length(active_col) == 1L) {
      lvl <- colnames(ex$Z_g)[active_col]
      if (!is.null(lvl) && nzchar(lvl)) {
        lvl_esc <- gsub("_", "\\_", lvl, fixed = TRUE)
        re_group_label <- sprintf("\\hat{u}_{\\mathrm{%s}}", lvl_esc)
      } else {
        re_group_label <- "\\hat{u}_{\\,\\mathrm{group}(1)}"
      }
    } else {
      re_group_label <- "\\hat{u}_{\\,\\mathrm{group}(1)}"
    }
  }

  # Detect intercept column.
  is_intercept <- vapply(seq_along(X1), function(k) {
    nm <- names(X1)[k]
    identical(nm, "(Intercept)") || (!is.null(nm) && grepl("Intercept", nm)) ||
      all(ex$X[, k] == 1)
  }, logical(1L))

  # Build symbolic and numeric term lists side by side.
  scalar_response_sym <- "W_{1}"   # i = 1 in scalar form for the response
  beta_k <- function(k) sprintf("\\hat\\beta_{%d}", k - 1L)
  # For non-intercept columns, use the column name as a Roman label
  # (sanitized for LaTeX) with subscript i = 1.
  predictor_label <- function(k) {
    nm <- names(X1)[k]
    if (is.null(nm) || !nzchar(nm)) nm <- paste0("x_{", k, "}")
    nm <- gsub("_", "\\_", nm, fixed = TRUE)
    sprintf("\\mathrm{%s}_{1}", nm)
  }

  sym_terms <- character(length(X1))
  num_terms <- character(length(X1))
  for (k in seq_along(X1)) {
    if (is_intercept[k]) {
      sym_terms[k] <- beta_k(k)
      num_terms[k] <- fmt(ex$beta[k])
    } else {
      sym_terms[k] <- paste0(beta_k(k), "\\,", predictor_label(k))
      num_terms[k] <- paste0(fmt(ex$beta[k]), " \\times ", fmt(X1[k]))
    }
  }
  # Append the RE term to both lists when present so the symbolic and
  # numeric rows close arithmetically.
  if (has_re) {
    sym_terms <- c(sym_terms, re_group_label)
    num_terms <- c(num_terms, sprintf("(%s)", fmt(re_contrib_num)))
  }
  sym_rhs <- paste(sym_terms, collapse = " + ")
  num_rhs <- paste(num_terms, collapse = " + ")

  paste0(
    "<div class=\"sym-eq\">$$\n\\begin{aligned}\n",
    scalar_response_sym, " &= ", sym_rhs, " + \\hat\\varepsilon_{1} ",
    "&\\quad(\\text{response equation, one row of the model}) \\\\\n",
    fmt(W1), " &= ", num_rhs, " + (", fmt(eps1), ") ",
    "&\\quad(\\text{with your numbers}) \\\\\n",
    "&= \\underbrace{", fmt(mu1),
    "}_{\\textstyle\\,\\hat\\mu_{1}\\,\\text{(predicted)}\\,} \\;+\\; ",
    "\\underbrace{(", fmt(eps1),
    ")}_{\\textstyle\\,\\hat\\varepsilon_{1}\\,\\text{(residual)}\\,}",
    "\n\\end{aligned}\n$$</div>\n"
  )
}

# Worked-row for the sigma submodel, parallel to three_views_worked_row().
# Walks observation 1 through the log-link prediction:
#   log(sigma_hat_1) = gamma_0 + gamma_1 * T_1
# in symbolic form, with numbers, and the back-transformed sigma_hat_1.
# Returns NULL if the model has no sigma submodel; matrix-block stitcher
# then skips this section.
three_views_worked_row_sigma <- function(ex) {
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
  num_rhs <- paste(num_terms, collapse = " + ")

  paste0(
    "<div class=\"sym-eq\">$$\n\\begin{aligned}\n",
    "\\log\\hat\\sigma_{1} &= ", sym_rhs, " ",
    "&\\quad(\\text{sigma submodel for observation 1, log link}) \\\\\n",
    "\\log\\hat\\sigma_{1} &= ", num_rhs, " = ", fmt(log_sig1), " ",
    "&\\quad(\\text{with your numbers}) \\\\\n",
    "\\hat\\sigma_{1} &= \\exp(", fmt(log_sig1), ") \\approx ", fmt(sigma1), " ",
    "&\\quad(\\text{predicted residual SD for observation 1})",
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
three_views_biology_gloss <- function(x) {
  family <- tryCatch(x$model$family, error = function(e) NULL)
  if (is.null(family) || !nzchar(family)) return("")

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
