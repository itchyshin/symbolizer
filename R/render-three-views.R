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

  eq_panel <- paste0(
    "<div class=\"sym-panel sym-active\" role=\"tabpanel\" id=\"", pan_eq,
    "\" aria-labelledby=\"", tab_eq, "\" data-panel=\"eq\" tabindex=\"0\">\n",
    "  <p class=\"sym-caption\">The structural contract. No indices, no numbers -- the shape of the model.</p>\n",
    "  <div class=\"sym-eq\">$$\\begin{aligned}\n",
    paste0(vapply(eq_lines, align_at, character(1L)), collapse = " \\\\\n"),
    "\n\\end{aligned}$$</div>\n",
    "</div>\n"
  )
  idx_panel <- paste0(
    "<div class=\"sym-panel\" role=\"tabpanel\" id=\"", pan_idx,
    "\" aria-labelledby=\"", tab_idx, "\" data-panel=\"idx\" hidden tabindex=\"0\">\n",
    "  <p class=\"sym-caption\">What happens for each observation <em>i</em>.</p>\n",
    "  <div class=\"sym-eq\">$$\\begin{aligned}\n",
    paste0(vapply(idx_lines, align_at, character(1L)), collapse = " \\\\\n"),
    "\n\\end{aligned}$$</div>\n",
    "</div>\n"
  )
  mat_panel <- paste0(
    "<div class=\"sym-panel\" role=\"tabpanel\" id=\"", pan_mat,
    "\" aria-labelledby=\"", tab_mat, "\" data-panel=\"mat\" hidden tabindex=\"0\">\n",
    "  <p class=\"sym-caption\">The actual numbers stacked -- what the computer is multiplying. Showing first ", head, " and last ", tail, " rows of n = ", x$model$n_obs, ".</p>\n",
    "  <span class=\"sym-sr-only\">", matrix_summary, "</span>\n",
    matrix_block,
    "</div>\n"
  )

  marker <- "<span class=\"sym-tab-marker\" aria-hidden=\"true\">&#9656;</span>"
  html <- paste0(
    "<style>", css, "</style>\n",
    "<div class=\"sym-tabs\" id=\"", uid, "\">\n",
    "  <a class=\"sym-skip\" href=\"#", end_id, "\">Skip three-views widget</a>\n",
    "  <div class=\"sym-tablist\" role=\"tablist\" aria-label=\"Three views of the model\">\n",
    "    <button type=\"button\" class=\"sym-tab sym-active\" role=\"tab\"",
    " id=\"", tab_eq, "\" aria-controls=\"", pan_eq, "\"",
    " aria-selected=\"true\" tabindex=\"0\" data-tab=\"eq\">",
    marker, "1. Equation</button>\n",
    "    <button type=\"button\" class=\"sym-tab\" role=\"tab\"",
    " id=\"", tab_idx, "\" aria-controls=\"", pan_idx, "\"",
    " aria-selected=\"false\" tabindex=\"-1\" data-tab=\"idx\">",
    marker, "2. Index</button>\n",
    "    <button type=\"button\" class=\"sym-tab\" role=\"tab\"",
    " id=\"", tab_mat, "\" aria-controls=\"", pan_mat, "\"",
    " aria-selected=\"false\" tabindex=\"-1\" data-tab=\"mat\">",
    marker, "3. Matrix (with data)</button>\n",
    "  </div>\n",
    eq_panel, idx_panel, mat_panel,
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
  # The visually-stacked pre is read linearly by screen readers, which is
  # confusing. Hide it from assistive tech; the sym-sr-only summary above
  # carries the announcement.
  sub("<pre class=\"sym-matrix\">",
      "<pre class=\"sym-matrix\" aria-hidden=\"true\">",
      block, fixed = TRUE)
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
.sym-eq { background: #fbe7e7; border: 1px solid #a0282b; border-radius: 6px; padding: 0.7rem 1rem; margin: 0.4rem 0; text-align: center; }
.sym-caption { color: #6b7280; font-size: 0.85rem; margin: 0.2rem 0 0.4rem; }
.sym-matrix { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 0.78rem; line-height: 1.35; white-space: pre; overflow-x: auto; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px; padding: 0.6rem 0.8rem; margin: 0.3rem 0; }
.sym-sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
.sym-skip { position: absolute; top: -100px; left: 0; padding: 0.4rem 0.7rem; background: #8a1f22; color: #fff; text-decoration: none; font-size: 0.85rem; z-index: 5; }
.sym-skip:focus { top: 0; }'
}

three_views_js <- function(uid) {
  sprintf(
'(function() {
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
})();', uid)
}
