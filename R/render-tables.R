#' Symbol dictionary as a reader-friendly table
#'
#' @description
#' Returns the symbol dictionary of a [`symbolized_model`][new_symbolized_model]
#' as a tibble suitable for tabular display. The dictionary lists every
#' mathematical symbol that appears in the rendered equations (response,
#' predictors, parameters, coefficients, and design matrices), together with
#' the original R variable, its units, and an abstract / concrete dimension.
#'
#' The renderer is a pure consumer of `x$symbol_dictionary`: it does not parse
#' formulas or invent prose. Use `notation` to control which symbol column(s)
#' are shown.
#'
#' @param x A `symbolized_model`.
#' @param notation One of `"both"` (default), `"index"`, or `"matrix"`.
#'   `"index"` keeps only the element-wise (`W_i`, `\mu_i`) form,
#'   `"matrix"` keeps only the bold matrix-form (`\mathbf{w}`,
#'   `\boldsymbol{\mu}`) and drops rows that have no matrix form (e.g.,
#'   continuous predictors whose only symbol is an indexed scalar).
#' @param ... Reserved for future use.
#'
#' @return A tibble (S3 class `symbolizer_symbol_table`) with `variable`,
#'   `units`, `role`, `dimension`, `dimension_concrete`, and `description`
#'   columns plus one or both of `symbol` and `symbol_matrix`.
#' @export
symbol_table <- function(x, notation = c("both", "index", "matrix"), ...) {
  UseMethod("symbol_table")
}

#' @export
symbol_table.default <- function(x, notation = c("both", "index", "matrix"), ...) {
  cli::cli_abort(c(
    "{.fn symbol_table} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
symbol_table.symbolized_model <- function(x,
                                          notation = c("both", "index", "matrix"),
                                          ...) {
  notation <- match.arg(notation)
  d <- x$symbol_dictionary
  out <- switch(
    notation,
    both = d[, c("symbol", "symbol_matrix", "variable", "units", "role",
                 "dimension", "dimension_concrete", "description"),
             drop = FALSE],
    index = d[, c("symbol", "variable", "units", "role",
                  "dimension", "dimension_concrete", "description"),
              drop = FALSE],
    matrix = {
      keep <- !is.na(d$symbol_matrix)
      d[keep, c("symbol_matrix", "variable", "units", "role",
                "dimension", "dimension_concrete", "description"),
        drop = FALSE]
    }
  )
  out <- tibble::as_tibble(out)
  class(out) <- c("symbolizer_symbol_table", class(out))
  attr(out, "notation") <- notation
  out
}

#' @export
print.symbolizer_symbol_table <- function(x, ...) {
  notation <- attr(x, "notation") %||% "both"
  cli::cli_h2("Symbol dictionary ({.val {notation}})")
  has_index  <- "symbol"        %in% names(x)
  has_matrix <- "symbol_matrix" %in% names(x)
  for (i in seq_len(nrow(x))) {
    role <- x$role[[i]]
    var  <- x$variable[[i]]
    head <- if (!is.na(var)) {
      sprintf("%s  [%s]", var, role)
    } else {
      sprintf("(%s)", role)
    }
    cli::cli_text("{.strong {head}}")
    if (has_index) {
      sym <- x$symbol[[i]]
      sym <- if (is.na(sym)) "(no index form)" else sym
      cli::cli_text("  index:     {.code {sym}}")
    }
    if (has_matrix) {
      symm <- x$symbol_matrix[[i]]
      symm <- if (is.na(symm)) "(no matrix form)" else symm
      cli::cli_text("  matrix:    {.code {symm}}")
    }
    units_i <- x$units[[i]]
    if (!is.na(units_i) && nzchar(units_i)) {
      cli::cli_text("  units:     {.val {units_i}}")
    }
    cli::cli_text(
      "  dimension: {.code {x$dimension[[i]]}} (= {.code {x$dimension_concrete[[i]]}})"
    )
    cli::cli_text("  {.emph {x$description[[i]]}}")
  }
  invisible(x)
}

#' Assumption table for a symbolized model
#'
#' @description
#' Returns the structured assumption tibble of a
#' [`symbolized_model`][new_symbolized_model] as a reader-friendly table. The
#' rows come straight from the template-substituted `x$assumptions` field; the
#' renderer never invents prose.
#'
#' @param x A `symbolized_model`.
#' @param ... Reserved for future use.
#'
#' @return A tibble (S3 class `symbolizer_assumption_table`) with columns
#'   `family`, `submodel`, `assumption`, `expression_latex`,
#'   `biological_meaning`, and `status`.
#' @export
assumption_table <- function(x, ...) {
  UseMethod("assumption_table")
}

#' @export
assumption_table.default <- function(x, ...) {
  cli::cli_abort(c(
    "{.fn assumption_table} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
assumption_table.symbolized_model <- function(x, ...) {
  out <- tibble::as_tibble(x$assumptions)
  class(out) <- c("symbolizer_assumption_table", class(out))
  out
}

#' Map an assumption-status key to a friendlier display label
#'
#' @description
#' Translates the CSV keys (`stated`, `implied`, `not_checked`) used in
#' `inst/extdata/assumption-templates.csv` to plain-language labels for
#' display in `print()` and `knit_print()` methods. The underlying data
#' column keeps the original key; only the user-visible rendering changes.
#'
#' @param status Character vector of status keys.
#'
#' @return Character vector of the same length carrying the friendlier label.
#'   Unknown keys pass through unchanged.
#' @keywords internal
friendly_status <- function(status) {
  map <- c(
    stated      = "explicit",
    implied     = "follows from the formula",
    not_checked = "your responsibility"
  )
  out <- map[status]
  unknown <- is.na(out)
  out[unknown] <- status[unknown]
  unname(out)
}

#' @export
print.symbolizer_assumption_table <- function(x, ...) {
  cli::cli_h2("Assumptions")
  for (i in seq_len(nrow(x))) {
    head <- x$assumption[[i]]
    sub  <- x$submodel[[i]]
    head_full <- if (!is.na(sub) && nzchar(sub)) {
      sprintf("%s (%s)", head, sub)
    } else {
      head
    }
    cli::cli_text("{.strong {head_full}}")
    cli::cli_text("  expression: {.code {x$expression_latex[[i]]}}")
    cli::cli_text("  meaning:    {x$biological_meaning[[i]]}")
    cli::cli_text("  status:     [{.val {friendly_status(x$status[[i]])}}]")
  }
  invisible(x)
}

#' Formula bridge table for a symbolized model
#'
#' @description
#' Returns the R-syntax-to-mathematics translation table built by
#' `symbolize()`. Each row corresponds to one submodel formula (e.g., `mu ~ ...`,
#' `sigma ~ ...`) and pairs the literal R syntax with a one-line statistical
#' meaning and the matching mathematics in either index or matrix form (or
#' both).
#'
#' @param x A `symbolized_model`.
#' @param notation One of `"both"` (default), `"index"`, or `"matrix"`.
#'   Controls which mathematics column(s) are returned.
#' @param ... Reserved for future use.
#'
#' @return A tibble (S3 class `symbolizer_formula_bridge`) with columns
#'   `submodel`, `r_syntax`, `statistical_meaning`, and one or both of
#'   `mathematics` (index form) and `mathematics_matrix` (matrix form).
#' @export
formula_bridge <- function(x, notation = c("both", "index", "matrix"), ...) {
  UseMethod("formula_bridge")
}

#' @export
formula_bridge.default <- function(x, notation = c("both", "index", "matrix"), ...) {
  cli::cli_abort(c(
    "{.fn formula_bridge} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
formula_bridge.symbolized_model <- function(x,
                                            notation = c("both", "index", "matrix"),
                                            ...) {
  notation <- match.arg(notation)
  b <- x$formula_bridge
  out <- switch(
    notation,
    both   = b[, c("submodel", "r_syntax", "statistical_meaning",
                   "mathematics", "mathematics_matrix"), drop = FALSE],
    index  = b[, c("submodel", "r_syntax", "statistical_meaning",
                   "mathematics"), drop = FALSE],
    matrix = b[, c("submodel", "r_syntax", "statistical_meaning",
                   "mathematics_matrix"), drop = FALSE]
  )
  out <- tibble::as_tibble(out)
  class(out) <- c("symbolizer_formula_bridge", class(out))
  attr(out, "notation") <- notation
  out
}

#' @export
print.symbolizer_formula_bridge <- function(x, ...) {
  notation <- attr(x, "notation") %||% "both"
  cli::cli_h2("Formula bridge ({.val {notation}})")
  has_index  <- "mathematics"        %in% names(x)
  has_matrix <- "mathematics_matrix" %in% names(x)
  for (i in seq_len(nrow(x))) {
    cli::cli_text("{.strong {x$submodel[[i]]}}")
    cli::cli_text("  R:       {.code {x$r_syntax[[i]]}}")
    cli::cli_text("  meaning: {x$statistical_meaning[[i]]}")
    if (has_index) {
      cli::cli_text("  math:    {.code {x$mathematics[[i]]}}")
    }
    if (has_matrix) {
      cli::cli_text("  matrix:  {.code {x$mathematics_matrix[[i]]}}")
    }
  }
  invisible(x)
}
