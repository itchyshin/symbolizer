# ----------------------------------------------------------------------------
# render-factor-views.R
#
# `as_html_factor_views()` is the interactive, web-facing companion to
# `explain_factors()`. It mirrors `as_html_three_views()` (same tab machinery,
# CSS and JS) but tells the dummy-coding story across four tabs:
#
#   1. Coding scheme  -- each factor's levels, with the reference highlighted,
#                        the contrast type and how many indicator columns.
#   2. Group means    -- per-level means as Confidence-Eye rows.
#   3. Pairwise       -- which levels differ from each other (group_contrasts),
#                        ratio-aware (the null line sits at 1 for log/logit).
#   4. Interactions   -- inline cells (factor x factor) / per-group slopes.
#
# It is a pure consumer of the symbolized_model: the coding scheme comes from
# `x$factor_coding`, the prose from the factor-coding templates, the numbers
# from group_means() / group_contrasts() / group_slopes(). Uncertainty is drawn
# in the Confidence-Eye grammar (pale compatibility region + interval outline +
# hollow point); language is confidence/compatibility, never posterior.
# ----------------------------------------------------------------------------

#' Interactive HTML widget for a model's factors and dummy coding
#'
#' @description
#' `as_html_factor_views()` renders a four-tab interactive widget that walks a
#' reader through the categorical structure of a fit: the coding scheme (levels,
#' reference, indicator columns), the per-group means, the pairwise comparisons,
#' and the interactions. It is the web-facing companion to [`explain_factors()`].
#'
#' Estimates are drawn in the Confidence-Eye grammar -- a pale compatibility
#' region with a darker interval outline and a hollow point estimate; the
#' language is confidence/compatibility, never posterior. Tabs 2-4 need
#' \pkg{emmeans}; without it they show a short note.
#'
#' @param x A [`symbolized_model`][new_symbolized_model] (output of
#'   [`symbolize()`]).
#' @param id Character id stem for the widget's element ids. Default `"symfv"`.
#' @param standalone Logical; if `TRUE`, wrap the fragment in a self-contained
#'   HTML page (with a MathJax bootstrap) suitable for opening directly in a
#'   browser. Default `FALSE` (an embeddable fragment).
#' @param file Optional path; if given, the HTML is written there and returned
#'   invisibly instead of printed.
#' @param ... Reserved for future use.
#'
#' @return A character vector (HTML), invisibly.
#' @seealso [`explain_factors()`], [`as_html_three_views()`]
#' @export
as_html_factor_views <- function(x, id = "symfv", standalone = FALSE,
                                 file = NULL, ...) {
  UseMethod("as_html_factor_views")
}

#' @export
as_html_factor_views.default <- function(x, ...) {
  cli::cli_abort(c(
    "{.fn as_html_factor_views} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
as_html_factor_views.symbolized_model <- function(x, id = "symfv",
                                                  standalone = FALSE,
                                                  file = NULL, ...) {
  uid <- paste0("symfv-", gsub("[^a-zA-Z0-9]", "", id), "-",
                as.integer(Sys.time()))
  ids <- lapply(c("coding", "means", "pair", "ix"), function(k) {
    list(tab = paste0(uid, "-tab-", k), pan = paste0(uid, "-panel-", k))
  })
  names(ids) <- c("coding", "means", "pair", "ix")
  end_id <- paste0(uid, "-end")

  css <- paste0(three_views_css(), "\n", fv_extra_css())
  js  <- three_views_js(uid)

  panels <- c(
    fv_panel(ids$coding$pan, ids$coding$tab, "coding", active = TRUE,
             caption = "How each categorical predictor is entered into the model.",
             body = fv_coding_panel(x)),
    fv_panel(ids$means$pan, ids$means$tab, "means", active = FALSE,
             caption = "Each group's expected response, with a 95% compatibility interval.",
             body = fv_means_panel(x)),
    fv_panel(ids$pair$pan, ids$pair$tab, "pair", active = FALSE,
             caption = "Which levels differ from each other. The dashed line is the null.",
             body = fv_pairwise_panel(x)),
    fv_panel(ids$ix$pan, ids$ix$tab, "ix", active = FALSE,
             caption = "Where an effect depends on another predictor: the cells / slopes directly.",
             body = fv_interactions_panel(x))
  )

  marker <- "<span class=\"sym-tab-marker\" aria-hidden=\"true\" style=\"margin-right:0.35em\">&#9656;</span>"
  tab_btn <- function(slot, n, label, active) {
    paste0(
      "<button type=\"button\" class=\"sym-tab", if (active) " sym-active" else "",
      "\" role=\"tab\" id=\"", ids[[slot]]$tab, "\" aria-controls=\"", ids[[slot]]$pan,
      "\" aria-selected=\"", if (active) "true" else "false",
      "\" tabindex=\"", if (active) "0" else "-1", "\" data-tab=\"", slot, "\">",
      marker, n, ". ", label, "</button>\n"
    )
  }

  html <- paste0(
    "<style>", css, "</style>\n",
    "<div class=\"sym-tabs\" id=\"", uid, "\">\n",
    "<a class=\"sym-skip\" href=\"#", end_id, "\">Skip factor-views widget</a>\n",
    "<div class=\"sym-tablist\" role=\"tablist\" aria-label=\"Factor views of the model\">\n",
    tab_btn("coding", 1, "Coding scheme", TRUE),
    tab_btn("means", 2, "Group means", FALSE),
    tab_btn("pair", 3, "Pairwise", FALSE),
    tab_btn("ix", 4, "Interactions", FALSE),
    "</div>\n",
    paste0(panels, collapse = ""),
    "</div>\n",
    "<span id=\"", end_id, "\" tabindex=\"-1\"></span>\n",
    "<script>", js, "</script>\n"
  )
  if (isTRUE(standalone)) {
    html <- three_views_standalone_wrap(html, title = "symbolizer factor views")
  }
  if (!is.null(file)) {
    writeLines(html, con = file)
    return(invisible(html))
  }
  cat(html)
  invisible(html)
}

# ---- panel shell -----------------------------------------------------------

fv_panel <- function(pan_id, tab_id, key, active, caption, body) {
  paste0(
    "<div class=\"sym-panel", if (active) " sym-active" else "",
    "\" role=\"tabpanel\" id=\"", pan_id, "\" aria-labelledby=\"", tab_id,
    "\" data-panel=\"", key, "\"", if (active) "" else " hidden", " tabindex=\"0\">\n",
    "<p class=\"sym-caption\">", caption, "</p>\n",
    body, "\n</div>\n"
  )
}

# ---- tab 1: coding scheme --------------------------------------------------

fv_coding_panel <- function(x) {
  fc <- x$factor_coding
  if (is.null(fc) || nrow(fc) == 0L) {
    return(paste0("<p class=\"sym-biology\">",
                  fv_esc(factor_template_prose("no_factors_message", "any", list())),
                  "</p>"))
  }
  cards <- vapply(seq_len(nrow(fc)), function(i) {
    row <- fc[i, , drop = FALSE]
    lv  <- row$levels[[1L]]
    ref <- row$reference_level
    chips <- paste0(vapply(lv, function(l) {
      is_ref <- !is.na(ref) && identical(l, ref)
      paste0("<span class=\"fv-chip", if (is_ref) " fv-chip-ref" else "", "\">",
             fv_esc(l), if (is_ref) " &#9733;" else "", "</span>")
    }, character(1L)), collapse = "")
    meta <- sprintf("%s coding &middot; %d indicator column%s",
                    fv_esc(row$contrast_type), row$n_dummies,
                    if (row$n_dummies == 1L) "" else "s")
    paste0(
      "<div class=\"fv-card\">\n",
      "<div class=\"fv-card-h\">", fv_esc(row$variable), "</div>\n",
      "<div class=\"fv-chips\">", chips, "</div>\n",
      "<div class=\"fv-meta\">", meta, "</div>\n",
      "<p class=\"fv-prose\">", fv_esc(factor_overview_prose(row)), "</p>\n",
      "</div>\n"
    )
  }, character(1L))
  paste0("<p class=\"fv-legend\">",
         "<span class=\"fv-chip fv-chip-ref\">level &#9733;</span> = reference (baseline)</p>\n",
         paste0(cards, collapse = ""))
}

# ---- tabs 2-4: emmeans-backed eye rows -------------------------------------

fv_means_panel <- function(x) {
  fv_require_emmeans_block(x, function() {
    fc <- x$factor_coding
    if (is.null(fc) || nrow(fc) == 0L) {
      return("<p class=\"sym-caption\">This model has no factors.</p>")
    }
    blocks <- vapply(fc$variable, function(v) {
      gm <- tryCatch(group_means(x, by = v), error = function(e) NULL)
      paste0("<div class=\"fv-block\"><div class=\"fv-block-h\">", fv_esc(v),
             "</div>", fv_eye_rows(gm, "level_combo", null_val = 0),
             "</div>\n")
    }, character(1L))
    paste0(blocks, collapse = "")
  })
}

fv_pairwise_panel <- function(x) {
  fv_require_emmeans_block(x, function() {
    fc <- x$factor_coding
    if (is.null(fc) || nrow(fc) == 0L) {
      return("<p class=\"sym-caption\">This model has no factors.</p>")
    }
    blocks <- vapply(fc$variable, function(v) {
      gc <- tryCatch(group_contrasts(x, by = v), error = function(e) NULL)
      null_val <- if (!is.null(gc) && nrow(gc) > 0L &&
                      gc$effect_type[[1L]] %in% c("ratio", "odds_ratio")) 1 else 0
      note <- if (!is.null(gc) && nrow(gc) > 0L &&
                  gc$effect_type[[1L]] %in% c("ratio", "odds_ratio")) {
        " <span class=\"fv-note\">(ratios &middot; null = 1)</span>"
      } else ""
      paste0("<div class=\"fv-block\"><div class=\"fv-block-h\">", fv_esc(v),
             note, "</div>", fv_eye_rows(gc, "contrast", null_val = null_val),
             "</div>\n")
    }, character(1L))
    paste0(blocks, collapse = "")
  })
}

fv_interactions_panel <- function(x) {
  fc <- x$factor_coding
  factor_vars <- if (is.null(fc)) character(0L) else fc$variable
  pieces <- factor_interaction_pieces(x, factor_vars)
  if (length(pieces) == 0L) {
    return("<p class=\"sym-caption\">No interactions in this model.</p>")
  }
  blocks <- vapply(pieces, function(it) {
    tbl <- it$cells %||% it$slopes
    label_col <- if (!is.null(it$slopes)) "level_combo" else "level_combo"
    body <- if (is.null(tbl)) {
      "<p class=\"sym-caption\">(install emmeans for the cells / slopes)</p>"
    } else {
      fv_eye_rows(tbl, label_col, null_val = 0)
    }
    paste0("<div class=\"fv-block\"><div class=\"fv-block-h\">", fv_esc(it$term),
           "</div><p class=\"fv-prose\">", fv_esc(it$overview), "</p>", body,
           "</div>\n")
  }, character(1L))
  paste0(blocks, collapse = "")
}

fv_require_emmeans_block <- function(x, fn) {
  if (!requireNamespace("emmeans", quietly = TRUE)) {
    return(paste0("<p class=\"sym-biology\">Install the <code>emmeans</code> ",
                  "package to see group means, pairwise comparisons and ",
                  "per-group slopes here.</p>"))
  }
  fn()
}

# ---- Confidence-Eye row chart ----------------------------------------------

# Render a tibble of estimate / confint_low / confint_high as one SVG row each:
# a pale compatibility region (lo..hi) with a darker outline, a hollow point at
# the estimate, and a dashed null reference line. Shared linear scale per block.
fv_eye_rows <- function(tbl, label_col, null_val = NA_real_) {
  if (is.null(tbl) || nrow(tbl) == 0L) {
    return("<p class=\"sym-caption\">(no estimates)</p>")
  }
  est <- as.numeric(tbl$estimate)
  lo  <- as.numeric(tbl$confint_low)
  hi  <- as.numeric(tbl$confint_high)
  labs <- as.character(tbl[[label_col]])
  excl <- if ("excludes_zero" %in% names(tbl)) as.logical(tbl$excludes_zero) else rep(FALSE, nrow(tbl))

  vals <- c(lo, hi, est, if (is.finite(null_val)) null_val)
  vals <- vals[is.finite(vals)]
  if (length(vals) == 0L) return("<p class=\"sym-caption\">(no finite estimates)</p>")
  xmin <- min(vals); xmax <- max(vals)
  if (xmin == xmax) { xmin <- xmin - 1; xmax <- xmax + 1 }
  pad <- (xmax - xmin) * 0.08
  xmin <- xmin - pad; xmax <- xmax + pad
  W <- 340; H <- 30; mid <- H / 2
  px <- function(v) (v - xmin) / (xmax - xmin) * W
  fmt <- function(v) formatC(v, digits = 3L, format = "fg", flag = "#")

  rows <- vapply(seq_len(nrow(tbl)), function(i) {
    if (!is.finite(est[i])) {
      return(paste0("<div class=\"fv-row\"><span class=\"fv-lab\">", fv_esc(labs[i]),
                    "</span><span class=\"fv-val\">n/a</span></div>"))
    }
    x_lo <- px(lo[i]); x_hi <- px(hi[i]); x_e <- px(est[i])
    if (!is.finite(x_lo)) x_lo <- x_e
    if (!is.finite(x_hi)) x_hi <- x_e
    null_line <- if (is.finite(null_val)) {
      xn <- px(null_val)
      paste0("<line x1=\"", round(xn, 1), "\" y1=\"3\" x2=\"", round(xn, 1),
             "\" y2=\"", H - 3, "\" class=\"fv-null\"/>")
    } else ""
    pt_cls <- if (isTRUE(excl[i])) "fv-pt fv-pt-sig" else "fv-pt"
    ci_str <- if (is.finite(lo[i]) && is.finite(hi[i])) {
      paste0(" (", fmt(lo[i]), ", ", fmt(hi[i]), ")")
    } else ""
    svg <- paste0(
      "<svg class=\"fv-eye\" viewBox=\"0 0 ", W, " ", H, "\" preserveAspectRatio=\"none\" role=\"img\">",
      "<line x1=\"0\" y1=\"", mid, "\" x2=\"", W, "\" y2=\"", mid, "\" class=\"fv-axis\"/>",
      null_line,
      "<rect x=\"", round(x_lo, 1), "\" y=\"", mid - 6, "\" width=\"",
      round(max(x_hi - x_lo, 1), 1), "\" height=\"12\" rx=\"3\" class=\"fv-region\"/>",
      "<circle cx=\"", round(x_e, 1), "\" cy=\"", mid, "\" r=\"4.5\" class=\"", pt_cls, "\"/>",
      "</svg>"
    )
    paste0("<div class=\"fv-row\"><span class=\"fv-lab\">", fv_esc(labs[i]),
           "</span>", svg, "<span class=\"fv-val\">", fmt(est[i]), ci_str,
           if (isTRUE(excl[i])) " <span class=\"fv-star\">&#8902;</span>" else "",
           "</span></div>")
  }, character(1L))

  scale_note <- sprintf("<p class=\"fv-scale\">scale: %s to %s</p>",
                        fmt(xmin), fmt(xmax))
  paste0(paste0(rows, collapse = ""), scale_note)
}

# ---- styling + escaping ----------------------------------------------------

fv_extra_css <- function() {
'.fv-legend { font-size:0.82rem; color:#6b7280; margin:0.2rem 0 0.7rem; }
.fv-card { border:1px solid #e5e7eb; border-radius:8px; padding:0.7rem 0.9rem; margin:0.5rem 0; }
.fv-card-h { font-weight:700; font-size:1rem; color:#111827; margin-bottom:0.4rem; }
.fv-chips { margin:0.2rem 0 0.4rem; }
.fv-chip { display:inline-block; padding:2px 9px; margin:2px 4px 2px 0; border-radius:14px; background:#f3f4f6; color:#374151; font-size:0.82rem; border:1px solid #e5e7eb; }
.fv-chip-ref { background:#eef5ff; color:#0b4f9e; border-color:#9cc4f3; font-weight:600; }
.fv-meta { font-size:0.8rem; color:#6b7280; margin-bottom:0.3rem; }
.fv-prose { font-size:0.9rem; color:#374151; margin:0.3rem 0 0; line-height:1.5; }
.fv-block { margin:0.7rem 0 1rem; }
.fv-block-h { font-weight:700; color:#8a1f22; font-size:0.95rem; margin:0.3rem 0; }
.fv-note { font-weight:400; color:#6b7280; font-size:0.82rem; }
.fv-row { display:flex; align-items:center; gap:0.5rem; margin:0.18rem 0; }
.fv-lab { flex:0 0 30%; max-width:30%; font-size:0.85rem; color:#374151; font-family:ui-monospace,Menlo,monospace; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.fv-eye { flex:1; height:30px; }
.fv-val { flex:0 0 30%; max-width:30%; text-align:right; font-size:0.8rem; color:#6b7280; font-variant-numeric:tabular-nums; }
.fv-axis { stroke:#e5e7eb; stroke-width:1; }
.fv-null { stroke:#9ca3af; stroke-width:1; stroke-dasharray:3 3; }
.fv-region { fill:#1f6feb; fill-opacity:0.13; stroke:#1f6feb; stroke-opacity:0.5; stroke-width:1; }
.fv-pt { fill:#ffffff; stroke:#0b4f9e; stroke-width:2; }
.fv-pt-sig { stroke:#a0282b; }
.fv-star { color:#a0282b; }
.fv-scale { font-size:0.72rem; color:#9ca3af; text-align:right; margin:0.1rem 0 0; }'
}

fv_esc <- function(s) {
  s <- as.character(s)
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  s <- gsub(">", "&gt;", s, fixed = TRUE)
  s
}
