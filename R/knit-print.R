# knit_print methods for the symbolizer table classes.
#
# These methods make accessor calls render as markdown tables (with LaTeX
# cells wrapped in $...$ so MathJax / KaTeX picks them up) inside any
# .Rmd / .qmd document, including the README, the vignettes, the pkgdown
# articles, and a user's own analysis report. The interactive print
# methods (cli-styled) keep working at the console.

#' @keywords internal
sym_dollar <- function(x) {
  out <- character(length(x))
  for (i in seq_along(x)) {
    v <- x[[i]]
    if (is.na(v) || !nzchar(v) || identical(v, "--")) {
      out[i] <- "\u2014"  # em dash; \u escape keeps R source ASCII-only
    } else if (grepl("\\\\", v) ||
               grepl("\\^\\{|_\\{", v) ||
               grepl("^[A-Za-z]_[ijk]$", v)) {
      # Looks like LaTeX: has a backslash, or _{ / ^{ subscript-with-brace,
      # or matches the single-letter X_i / X_j / X_k subscript pattern.
      # NOT triggered by bare underscore (so snake_case identifiers like
      # `body_mass` stay unwrapped).
      out[i] <- paste0("$", v, "$")
    } else {
      # Plain prose like "column of design matrix" stays unwrapped.
      out[i] <- v
    }
  }
  out
}

#' @keywords internal
sym_kable <- function(df, col.names = NULL) {
  if (!requireNamespace("knitr", quietly = TRUE)) return(invisible(df))
  if (is.null(col.names)) {
    knitr::kable(df, format = "pipe")
  } else {
    knitr::kable(df, col.names = col.names, format = "pipe")
  }
}

# Wrap a knitr::kable() output in a Bootstrap `.table-responsive` container
# so wide tables (assumption_table is the chronic offender; V1-D4 / V2-F4)
# get a horizontal scrollbar instead of silently clipping the right edge.
# The HTML output is asis-emitted; pandoc passes it through untouched. We
# emit a blank line before AND after the div so pandoc treats it as a
# block-level element (otherwise the leading `|` of the pipe table can
# be parsed as inline text inside the div).
#' @keywords internal
sym_kable_responsive <- function(df, col.names = NULL) {
  kab <- sym_kable(df, col.names = col.names)
  paste(c("",
          "<div class=\"table-responsive\" style=\"overflow-x:auto;\">",
          "",
          kab,
          "",
          "</div>",
          ""), collapse = "\n")
}

# HTML-escape plain text destined for an escape = FALSE kable cell. Order
# matters: `&` first, then `<`/`>`.
#' @keywords internal
esc_html <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;",  x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

# Render as an HTML-format table (not a markdown pipe table). Required when
# a cell must carry a literal `|` inside monospace -- R mixed-model syntax
# `(1 | g)`. A pipe table parses the column boundary on `|` BEFORE the cell
# is parsed as markdown, so a code span can never hold a literal pipe: `\|`
# and `&#124;` both render verbatim inside backticks (leaking `(1 \| g)` /
# `(1 &#124; g)`). HTML format sidesteps the pipe-table parser; pandoc still
# converts any `$...$` math inside the asis HTML block, so math cells render.
# Callers must pre-escape plain columns with `esc_html()` and wrap code /
# math columns themselves (escape = FALSE here).
#' @keywords internal
sym_kable_html <- function(df, col.names = NULL) {
  if (!requireNamespace("knitr", quietly = TRUE)) return(invisible(df))
  if (is.null(col.names)) {
    knitr::kable(df, format = "html", escape = FALSE)
  } else {
    knitr::kable(df, col.names = col.names, format = "html", escape = FALSE)
  }
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_symbol_table <- function(x, ...) {
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  if ("symbol" %in% names(df))             df$symbol <- sym_dollar(df$symbol)
  if ("symbol_matrix" %in% names(df))      df$symbol_matrix <- sym_dollar(df$symbol_matrix)
  if ("dimension" %in% names(df))          df$dimension <- sym_dollar(df$dimension)
  if ("dimension_concrete" %in% names(df)) df$dimension_concrete <- sym_dollar(df$dimension_concrete)
  cols <- intersect(
    c("symbol", "symbol_matrix", "variable", "units", "role",
      "dimension", "dimension_concrete", "description"),
    names(df)
  )
  col.names <- c(symbol = "index", symbol_matrix = "matrix",
                 variable = "variable", units = "units", role = "role",
                 dimension = "shape", dimension_concrete = "concrete",
                 description = "description")[cols]
  kab <- sym_kable(df[, cols, drop = FALSE], col.names = unname(col.names))
  knitr::asis_output(paste(c("", kab, ""), collapse = "\n"))
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_assumption_table <- function(x, ...) {
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  if ("expression_latex" %in% names(df)) df$expression_latex <- sym_dollar(df$expression_latex)
  if ("status" %in% names(df))           df$status <- friendly_status(df$status)
  cols <- intersect(
    c("assumption", "expression_latex", "biological_meaning", "status"),
    names(df)
  )
  col.names <- c(assumption = "assumption", expression_latex = "expression",
                 biological_meaning = "biological meaning",
                 status = "status")[cols]
  kab <- sym_kable_responsive(df[, cols, drop = FALSE], col.names = unname(col.names))
  knitr::asis_output(kab)
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_formula_bridge <- function(x, ...) {
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  if ("mathematics" %in% names(df))        df$mathematics <- sym_dollar(df$mathematics)
  if ("mathematics_matrix" %in% names(df)) df$mathematics_matrix <- sym_dollar(df$mathematics_matrix)
  if ("r_syntax" %in% names(df)) {
    # The "R syntax" column carries mixed-model formulas containing `|`
    # (e.g. `(1 | site)`). A markdown pipe table parses the column
    # boundary on `|` before the cell is parsed as markdown, so a code
    # span can never hold a literal pipe -- both `\|` and `&#124;` leak
    # verbatim inside backticks. Render the table as HTML and wrap the
    # syntax in <code> (see sym_kable_html). Pre-escape first so an R
    # comparison operator in a transform never breaks the markup.
    df$r_syntax <- paste0("<code>", esc_html(df$r_syntax), "</code>")
  }
  if ("submodel" %in% names(df)) df$submodel <- esc_html(df$submodel)
  if ("statistical_meaning" %in% names(df)) {
    df$statistical_meaning <- esc_html(df$statistical_meaning)
  }
  cols <- intersect(
    c("submodel", "r_syntax", "statistical_meaning",
      "mathematics", "mathematics_matrix"),
    names(df)
  )
  col.names <- c(submodel = "submodel", r_syntax = "R syntax",
                 statistical_meaning = "meaning",
                 mathematics = "math (index)",
                 mathematics_matrix = "math (matrix)")[cols]
  kab <- sym_kable_html(df[, cols, drop = FALSE], col.names = unname(col.names))
  knitr::asis_output(paste(c("", kab, ""), collapse = "\n"))
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_interpretation <- function(x, ...) {
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  fmt <- function(v) formatC(v, digits = 3, format = "fg", flag = "#")
  if ("estimate" %in% names(df)) df$estimate <- fmt(df$estimate)
  # Render the confidence band as a single column "lo, hi" with a star
  # marker when the band excludes zero. Both columns visible together so
  # the reader can see the number AND the indicator side by side.
  if (all(c("confint_low", "confint_high") %in% names(df))) {
    has_ci <- !is.na(df$confint_low) & !is.na(df$confint_high)
    band <- ifelse(
      has_ci,
      paste0(fmt(df$confint_low), ", ", fmt(df$confint_high)),
      "--"
    )
    if ("excludes_zero" %in% names(df)) {
      band <- ifelse(isTRUE_vec(df$excludes_zero), paste0(band, " *"), band)
    }
    df$`95% CI` <- band
  }
  cols <- intersect(
    c("submodel", "term_label", "coefficient_role", "estimate", "95% CI",
      "link_scale_reading", "natural_scale_reading",
      "variance_scale_reading", "biological_reading"),
    names(df)
  )
  kab <- sym_kable(df[, cols, drop = FALSE])
  # Footer announces which CI method produced the band.
  footer <- if ("ci_method" %in% names(df)) {
    m <- unique(df$ci_method[!is.na(df$ci_method)])
    if (length(m) == 1L) {
      paste0(
        "*Rows marked `*` have a 95% confidence interval that excludes zero",
        " (CI method: `", m, "`).*"
      )
    } else ""
  } else ""
  knitr::asis_output(paste(c("", kab, "", footer, ""), collapse = "\n"))
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_group_means <- function(x, ...) {
  marg_kable(x, predictor = NULL)
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_group_slopes <- function(x, ...) {
  predictor <- if ("predictor" %in% names(x) && nrow(x) >= 1L) {
    x$predictor[[1L]]
  } else NA_character_
  marg_kable(x, predictor = predictor)
}

# Shared kable renderer for both group_means and group_slopes tibbles.
#' @keywords internal
marg_kable <- function(x, predictor = NULL) {
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  fmt <- function(v) formatC(v, digits = 3, format = "fg", flag = "#")
  if ("estimate" %in% names(df)) df$estimate <- fmt(df$estimate)
  if (all(c("confint_low", "confint_high") %in% names(df))) {
    has_ci <- !is.na(df$confint_low) & !is.na(df$confint_high)
    band <- ifelse(
      has_ci,
      paste0(fmt(df$confint_low), ", ", fmt(df$confint_high)),
      "--"
    )
    if ("excludes_zero" %in% names(df)) {
      band <- ifelse(isTRUE_vec(df$excludes_zero), paste0(band, " *"), band)
    }
    df$`95% CI` <- band
  }
  drop_cols <- c("confint_low", "confint_high", "excludes_zero", "ci_method",
                 "std_error")
  cols <- setdiff(names(df), drop_cols)
  kab <- sym_kable(df[, cols, drop = FALSE])
  header <- if (!is.null(predictor) && !is.na(predictor) && nzchar(predictor)) {
    sprintf("**Group slopes for `%s`**", predictor)
  } else "**Group means**"
  footer <- if ("ci_method" %in% names(x)) {
    m <- unique(x$ci_method[!is.na(x$ci_method)])
    if (length(m) == 1L) {
      paste0(
        "*Rows marked `*` have a 95% confidence interval that excludes zero",
        " (CI method: `", m, "`).*"
      )
    } else ""
  } else ""
  knitr::asis_output(paste(c("", header, "", kab, "", footer, ""),
                           collapse = "\n"))
}

#' @keywords internal
isTRUE_vec <- function(x) {
  if (is.null(x)) return(logical(0))
  out <- as.logical(x)
  out[is.na(out)] <- FALSE
  out
}

#' @exportS3Method knitr::knit_print
knit_print.notation_bridge <- function(x, ...) {
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  if ("index" %in% names(df))              df$index  <- sym_dollar(df$index)
  if ("matrix" %in% names(df))             df$matrix <- sym_dollar(df$matrix)
  if ("dimension" %in% names(df))          df$dimension <- sym_dollar(df$dimension)
  if ("dimension_concrete" %in% names(df)) df$dimension_concrete <- sym_dollar(df$dimension_concrete)
  cols <- intersect(
    c("concept", "index", "matrix", "dimension", "dimension_concrete"),
    names(df)
  )
  col.names <- c(concept = "concept", index = "index", matrix = "matrix",
                 dimension = "shape", dimension_concrete = "concrete")[cols]
  kab <- sym_kable(df[, cols, drop = FALSE], col.names = unname(col.names))
  knitr::asis_output(paste(c("", kab, ""), collapse = "\n"))
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_model_card <- function(x, ...) {
  if (!requireNamespace("knitr", quietly = TRUE)) {
    return(print(x))
  }
  meta <- x$meta
  header <- sprintf(
    "## Model card: `%s` model\n\n%s (`%s`) -- family `%s` -- response `%s` (n = %d).",
    meta$class, meta$class, meta$package, meta$family,
    meta$response, meta$n_obs
  )
  context <- if (!is.null(meta$context) && nzchar(meta$context)) {
    sprintf("\nContext: *%s*", meta$context)
  } else ""
  sections <- list(
    list(title = "Equations",                              obj = x$equation),
    list(title = "Symbols",                                obj = x$symbols),
    list(title = "Assumptions",                            obj = x$assumptions),
    list(title = "Notation bridge (index vs matrix)",      obj = x$bridge),
    list(title = "Formula bridge (R syntax to math)",      obj = x$formula_bridge),
    list(title = "Parameter interpretation",               obj = x$interpretation)
  )
  if (!is.null(x$warnings) && nrow(x$warnings) > 0L) {
    sections <- c(sections, list(list(title = "Warnings",
                                      obj = x$warnings)))
  }
  if (!is.null(x$marginal_means)) {
    sections <- c(sections, list(list(title = "Group means",
                                      obj = x$marginal_means)))
  }
  if (!is.null(x$marginal_slopes)) {
    sections <- c(sections, list(list(title = "Group slopes",
                                      obj = x$marginal_slopes)))
  }
  parts <- c(header, context, "")
  for (s in sections) {
    rendered <- knitr::knit_print(s$obj)
    parts <- c(
      parts,
      sprintf("### %s", s$title),
      "",
      as.character(rendered),
      ""
    )
  }
  ec <- x$extraction_calls
  parts <- c(parts, "### Extraction calls", "")
  if (length(ec) == 0L) {
    parts <- c(parts,
               sprintf("*No extraction calls registered for class `%s`.*",
                       meta$class),
               "")
  } else {
    rows <- vapply(seq_along(ec), function(i) {
      sprintf("| %s | `%s` |", names(ec)[[i]], ec[[i]])
    }, character(1L))
    parts <- c(
      parts,
      "| What you want | R code |",
      "|---|---|",
      rows,
      ""
    )
  }
  rp <- x$recommended_plots
  parts <- c(parts, "### Recommended plots", "")
  if (length(rp) == 0L) {
    parts <- c(parts,
               sprintf("*No plot recipes registered for class `%s`.*",
                       meta$class),
               "")
  } else {
    rows <- vapply(seq_along(rp), function(i) {
      sprintf("| %s | %s |", names(rp)[[i]], rp[[i]])
    }, character(1L))
    parts <- c(
      parts,
      "| Plot | Recipe |",
      "|---|---|",
      rows,
      ""
    )
  }
  knitr::asis_output(paste(parts, collapse = "\n"))
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_equations <- function(x, ...) {
  notation <- attr(x, "notation", exact = TRUE) %||% "both"
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  lines <- if (notation == "index") {
    paste0("$$\n\\begin{aligned}\n",
           paste(df$index, collapse = " \\\\\n"),
           "\n\\end{aligned}\n$$")
  } else if (notation == "matrix") {
    paste0("$$\n\\begin{aligned}\n",
           paste(df$matrix, collapse = " \\\\\n"),
           "\n\\end{aligned}\n$$")
  } else {
    paste(
      "**Index form:**\n",
      paste0("$$\n\\begin{aligned}\n",
             paste(df$index, collapse = " \\\\\n"),
             "\n\\end{aligned}\n$$"),
      "\n**Matrix form:**\n",
      paste0("$$\n\\begin{aligned}\n",
             paste(df$matrix, collapse = " \\\\\n"),
             "\n\\end{aligned}\n$$"),
      sep = "\n"
    )
  }
  knitr::asis_output(lines)
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_random_effects <- function(x, ...) {
  if (!requireNamespace("knitr", quietly = TRUE)) return(print(x))
  df <- as.data.frame(x, stringsAsFactors = FALSE)

  # The term column carries mixed-model syntax with `|` (e.g. `(1 | site)`).
  # A markdown pipe table cannot hold a literal pipe inside monospace, so
  # render via HTML (sym_kable_html) and wrap the term in <code>.
  term_lab <- if ("term_label" %in% names(df)) {
    ifelse(nzchar(df$term_label),
           paste0("<code>", esc_html(df$term_label), "</code>"),
           "\u2014")
  } else {
    rep("\u2014", nrow(df))
  }

  out <- data.frame(
    submodel  = if ("submodel" %in% names(df))  esc_html(df$submodel)  else "",
    term      = term_lab,
    group     = if ("group_var" %in% names(df)) esc_html(df$group_var) else "",
    levels    = if ("n_levels"  %in% names(df)) df$n_levels  else NA_integer_,
    effect    = if ("u_symbol_index" %in% names(df)) sym_dollar(df$u_symbol_index) else "",
    sd        = if ("sigma_symbol"   %in% names(df)) sym_dollar(df$sigma_symbol)   else "",
    stringsAsFactors = FALSE
  )
  kab <- sym_kable_html(
    out,
    col.names = c("submodel", "term", "group", "levels",
                  "random effect", "between-group SD")
  )
  knitr::asis_output(paste(c("", kab, ""), collapse = "\n"))
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_variance_components <- function(x, ...) {
  if (!requireNamespace("knitr", quietly = TRUE)) return(print(x))
  df <- as.data.frame(x, stringsAsFactors = FALSE)

  # The variance_components tibble carries numeric SDs and variances. No
  # LaTeX bleed in these columns -- the value of a knit_print method here
  # is just consistent table styling and round-tripping to a clean kable
  # in vignette output (no `# A tibble: N x M` header, no truncated names).
  fmt_num <- function(v) {
    if (!is.numeric(v)) return(as.character(v))
    ifelse(is.na(v), "\u2014",
           formatC(v, digits = 3, format = "g", flag = "#"))
  }
  cols <- intersect(
    c("parameter", "group", "term", "sd_estimate", "var_estimate"),
    names(df)
  )
  out <- df[, cols, drop = FALSE]
  if ("sd_estimate" %in% cols)  out$sd_estimate  <- fmt_num(out$sd_estimate)
  if ("var_estimate" %in% cols) out$var_estimate <- fmt_num(out$var_estimate)

  kab <- sym_kable(out)
  knitr::asis_output(paste(c("", kab, ""), collapse = "\n"))
}

# ---------------------------------------------------------------------------
# Variance-components surface (S5): knit_print for the variance_partition() /
# icc() accessors. These emit asis HTML so the bar + ICC reading render in a
# knitted vignette, reusing the S3 widget helpers (vc_bar_*, vc_icc_line,
# variance_reading) -- the bar now travels outside the drmTMB-only widget.
# ---------------------------------------------------------------------------

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_variance_partition <- function(x, ...) {
  intro   <- variance_reading("partition_intro")
  has_pct <- nrow(x) > 0L && all(is.finite(x$pct))
  bar <- if (has_pct) {
    if (nrow(x) == 2L) vc_bar_stacked(x) else vc_bar_per_component(x)
  } else {
    vc_component_list(x)
  }
  reason <- attr(x, "reason")
  reason_html <- if (!is.null(reason) && !is.na(reason) && nzchar(reason)) {
    sprintf(paste0(
      "<p class=\"sym-caption\" style=\"font-size:0.8rem;color:#9ca3af\">",
      "Shares (%%) not shown: %s</p>"), reason)
  } else {
    ""
  }
  html <- paste0(
    "<div class=\"sym-vc-panel\">",
    if (nzchar(intro)) {
      sprintf("<p class=\"sym-caption\"><strong>Where does the variation live?</strong> %s</p>", intro)
    } else {
      ""
    },
    bar,
    vc_numbers_table(x),
    reason_html,
    "</div>"
  )
  knitr::asis_output(vc_html_oneline(html))
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_icc <- function(x, ...) {
  knitr::asis_output(vc_html_oneline(paste0(
    "<div class=\"sym-vc-panel\">", vc_icc_line(x), "</div>")))
}

# Collapse newlines + inter-tag indentation so the emitted HTML is a single
# line. The bar helpers indent their <div> rows; pandoc's markdown reader
# (used by html_vignette / pkgdown) treats 4+ leading spaces as a CODE BLOCK
# and would escape the bar's HTML as literal text. One line side-steps that
# entirely while leaving text content (which never sits around a newline)
# untouched.
#' @keywords internal
vc_html_oneline <- function(html) {
  gsub("\\s*\\n\\s*", "", html)
}

# Inline-HTML numbers table for the variance partition (source / variance / SD
# / % of total), so the figures travel alongside the bar in one asis block.
#' @keywords internal
vc_numbers_table <- function(vp) {
  fmt <- function(v) formatC(v, digits = 3L, format = "fg", flag = "#")
  rows <- vapply(seq_len(nrow(vp)), function(i) {
    pct <- vp$pct[[i]]
    pct_s <- if (is.finite(pct)) {
      sprintf("%s%%", formatC(100 * pct, digits = 1L, format = "f"))
    } else {
      "&mdash;"
    }
    sprintf(paste0(
      "<tr><td>%s</td><td style=\"text-align:right\">%s</td>",
      "<td style=\"text-align:right\">%s</td>",
      "<td style=\"text-align:right\">%s</td></tr>"),
      vp$component[[i]], fmt(vp$variance[[i]]), fmt(vp$sd[[i]]), pct_s)
  }, character(1L))
  paste0(
    "<table class=\"sym-vc-table\" style=\"border-collapse:collapse;",
    "font-size:0.85rem;margin:0.4rem 0\">",
    "<thead><tr><th style=\"text-align:left\">source</th>",
    "<th style=\"padding-left:1rem\">variance</th>",
    "<th style=\"padding-left:1rem\">SD</th>",
    "<th style=\"padding-left:1rem\">% of total</th></tr></thead>",
    "<tbody>", paste(rows, collapse = ""), "</tbody></table>"
  )
}
