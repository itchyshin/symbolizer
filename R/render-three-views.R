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
  matrix_block <- three_views_matrix_block(x, head = head, tail = tail)

  uid <- paste0("sym-", gsub("[^a-zA-Z0-9]", "", id), "-",
                as.integer(Sys.time()))

  css <- three_views_css()
  js  <- three_views_js(uid)

  eq_panel <- paste0(
    "<div class=\"sym-panel sym-active\" data-panel=\"eq\">\n",
    "  <p class=\"sym-caption\">The structural contract. No indices, no numbers -- the shape of the model.</p>\n",
    "  <div class=\"sym-eq\">$$\\begin{aligned}\n",
    paste0(vapply(eq_lines, align_at, character(1L)), collapse = " \\\\\n"),
    "\n\\end{aligned}$$</div>\n",
    "</div>\n"
  )
  idx_panel <- paste0(
    "<div class=\"sym-panel\" data-panel=\"idx\">\n",
    "  <p class=\"sym-caption\">What happens for each observation <em>i</em>.</p>\n",
    "  <div class=\"sym-eq\">$$\\begin{aligned}\n",
    paste0(vapply(idx_lines, align_at, character(1L)), collapse = " \\\\\n"),
    "\n\\end{aligned}$$</div>\n",
    "</div>\n"
  )
  mat_panel <- paste0(
    "<div class=\"sym-panel\" data-panel=\"mat\">\n",
    "  <p class=\"sym-caption\">The actual numbers stacked -- what the computer is multiplying. Showing first ", head, " and last ", tail, " rows of n = ", x$model$n_obs, ".</p>\n",
    matrix_block,
    "</div>\n"
  )

  html <- paste0(
    "<style>", css, "</style>\n",
    "<div class=\"sym-tabs\" id=\"", uid, "\">\n",
    "  <div class=\"sym-tablist\" role=\"tablist\">\n",
    "    <div class=\"sym-tab sym-active\" data-tab=\"eq\">1. Equation</div>\n",
    "    <div class=\"sym-tab\"            data-tab=\"idx\">2. Index</div>\n",
    "    <div class=\"sym-tab\"            data-tab=\"mat\">3. Matrix (with data)</div>\n",
    "  </div>\n",
    eq_panel, idx_panel, mat_panel,
    "</div>\n",
    "<script>", js, "</script>\n"
  )
  cat(html)
  invisible(html)
}

three_views_matrix_block <- function(x, head = 5L, tail = 2L) {
  ex <- x$expanded
  if (is.null(ex)) {
    return("<p><em>This symbolized_model carries no expanded numeric arrays.</em></p>\n")
  }
  fmt <- function(v) formatC(v, digits = 3, format = "fg", flag = "#")
  trunc_idx <- function(n, head, tail) {
    if (n <= head + tail + 1L) seq_len(n)
    else c(seq_len(head), NA_integer_, seq.int(n - tail + 1L, n))
  }
  n <- length(ex$y)
  rows <- trunc_idx(n, head, tail)

  pad <- function(s, w) formatC(s, width = w, flag = "-")
  cell <- function(label, idx) {
    if (is.na(idx)) return("vdots")
    paste0(label, " = ", fmt(ex$y[idx]))
  }

  # Build column vectors / matrices, all sharing the row index.
  y_col <- vapply(rows, function(i) {
    if (is.na(i)) "vdots" else sprintf("y_%d = %s", i, fmt(ex$y[i]))
  }, character(1L))

  X_col <- vapply(rows, function(i) {
    if (is.na(i)) "vdots"
    else paste(fmt(ex$X[i, ]), collapse = "  ")
  }, character(1L))

  beta_lines <- if (!is.null(ex$beta)) {
    nms <- names(ex$beta)
    if (is.null(nms)) nms <- paste0("beta_", seq_along(ex$beta) - 1L)
    paste0(nms, " = ", fmt(ex$beta))
  } else character(0L)

  Xs_col <- if (!is.null(ex$X_sigma)) {
    vapply(rows, function(i) {
      if (is.na(i)) "vdots"
      else paste(fmt(ex$X_sigma[i, ]), collapse = "  ")
    }, character(1L))
  } else NULL
  gamma_lines <- if (!is.null(ex$gamma)) {
    nms <- names(ex$gamma)
    if (is.null(nms)) nms <- paste0("gamma_", seq_along(ex$gamma) - 1L)
    paste0(nms, " = ", fmt(ex$gamma))
  } else character(0L)

  Zg_col <- if (!is.null(ex$Z_g)) {
    vapply(rows, function(i) {
      if (is.na(i)) "vdots"
      else paste(fmt(ex$Z_g[i, ]), collapse = "  ")
    }, character(1L))
  } else NULL
  u_lines <- if (!is.null(ex$u)) {
    nms <- names(ex$u)
    if (is.null(nms)) nms <- paste0("u_", seq_along(ex$u))
    paste0(nms, " = ", fmt(ex$u))
  } else character(0L)

  # Compose a fixed-width pre block.
  block <- paste0(
    "<pre class=\"sym-matrix\">\n",
    "  y                   X                          beta\n",
    paste(
      mapply(function(yc, Xc) {
        sprintf("  %-18s  %-22s  ", yc, Xc)
      }, y_col, X_col),
      collapse = "\n"
    ),
    "\n\n  Coefficients (beta, mu):\n",
    paste0("    ", beta_lines, collapse = "\n"),
    if (!is.null(Xs_col)) paste0(
      "\n\n  X_sigma                       gamma\n",
      paste(
        mapply(function(Xs) sprintf("  %-28s  ", Xs), Xs_col),
        collapse = "\n"
      ),
      "\n", paste0("    ", gamma_lines, collapse = "\n")
    ) else "",
    if (!is.null(Zg_col)) paste0(
      "\n\n  Z_g (group indicator)         u (random effects, BLUPs)\n",
      paste(
        mapply(function(Zr) sprintf("  %-28s  ", Zr), Zg_col),
        collapse = "\n"
      ),
      "\n", paste0("    ", u_lines, collapse = "\n")
    ) else "",
    if (!is.null(ex$mu_hat)) paste0(
      "\n\n  Fitted mu_hat (first ", head, "): ",
      paste(fmt(ex$mu_hat[seq_len(min(head, length(ex$mu_hat)))]),
            collapse = "  ")
    ) else "",
    if (!is.null(ex$sigma_hat)) paste0(
      "\n  Fitted sigma_hat (first ", head, "): ",
      paste(fmt(ex$sigma_hat[seq_len(min(head, length(ex$sigma_hat)))]),
            collapse = "  ")
    ) else "",
    "\n</pre>\n"
  )
  # Replace ASCII "vdots" placeholders with a proper vertical dots glyph row.
  block <- gsub("vdots", "...", block, fixed = TRUE)
  block
}

three_views_css <- function() {
'.sym-tabs { border: 1px solid #e5e7eb; border-radius: 8px; overflow: hidden; margin: 1em 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
.sym-tablist { display: flex; background: #f9fafb; border-bottom: 1px solid #e5e7eb; }
.sym-tab { flex: 1; text-align: center; padding: 0.6rem 0.5rem; cursor: pointer; font-weight: 600; color: #6b7280; border-right: 1px solid #e5e7eb; user-select: none; font-size: 0.92rem; }
.sym-tab:last-child { border-right: 0; }
.sym-tab:hover { background: #fbe7e7; color: #7a2a2a; }
.sym-tab.sym-active { background: #fff; color: #7a2a2a; box-shadow: inset 0 -3px 0 #a0282b; }
.sym-panel { padding: 1rem 1.1rem 1.2rem; display: none; }
.sym-panel.sym-active { display: block; }
.sym-eq { background: #fbe7e7; border: 1px solid #a0282b; border-radius: 6px; padding: 0.7rem 1rem; margin: 0.4rem 0; text-align: center; }
.sym-caption { color: #6b7280; font-size: 0.85rem; margin: 0.2rem 0 0.4rem; }
.sym-matrix { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 0.78rem; line-height: 1.35; white-space: pre; overflow-x: auto; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px; padding: 0.6rem 0.8rem; margin: 0.3rem 0; }'
}

three_views_js <- function(uid) {
  sprintf(
'(function() {
  var root = document.getElementById("%s");
  if (!root) return;
  root.querySelectorAll(".sym-tab").forEach(function(t) {
    t.addEventListener("click", function() {
      var id = t.dataset.tab;
      root.querySelectorAll(".sym-tab").forEach(function(x) {
        x.classList.toggle("sym-active", x.dataset.tab === id);
      });
      root.querySelectorAll(".sym-panel").forEach(function(p) {
        p.classList.toggle("sym-active", p.dataset.panel === id);
      });
    });
  });
})();', uid)
}
