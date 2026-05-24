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
      out[i] <- "—"
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
  kab <- sym_kable(df[, cols, drop = FALSE], col.names = unname(col.names))
  knitr::asis_output(paste(c("", kab, ""), collapse = "\n"))
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_formula_bridge <- function(x, ...) {
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  if ("mathematics" %in% names(df))        df$mathematics <- sym_dollar(df$mathematics)
  if ("mathematics_matrix" %in% names(df)) df$mathematics_matrix <- sym_dollar(df$mathematics_matrix)
  if ("r_syntax" %in% names(df))           df$r_syntax <- paste0("`", df$r_syntax, "`")
  cols <- intersect(
    c("submodel", "r_syntax", "statistical_meaning",
      "mathematics", "mathematics_matrix"),
    names(df)
  )
  col.names <- c(submodel = "submodel", r_syntax = "R syntax",
                 statistical_meaning = "meaning",
                 mathematics = "math (index)",
                 mathematics_matrix = "math (matrix)")[cols]
  kab <- sym_kable(df[, cols, drop = FALSE], col.names = unname(col.names))
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
