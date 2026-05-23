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
  if ("estimate" %in% names(df)) {
    df$estimate <- formatC(df$estimate, digits = 3, format = "fg", flag = "#")
  }
  cols <- intersect(
    c("submodel", "term_label", "coefficient_role", "estimate",
      "link_scale_reading", "natural_scale_reading",
      "variance_scale_reading", "biological_reading"),
    names(df)
  )
  kab <- sym_kable(df[, cols, drop = FALSE])
  knitr::asis_output(paste(c("", kab, ""), collapse = "\n"))
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
