#' Get the right-hand side of a formula
#' @param f A formula.
#' @return A language object.
#' @keywords internal
formula_rhs <- function(f) {
  if (!inherits(f, "formula")) {
    cli::cli_abort("{.arg f} must be a formula.")
  }
  if (length(f) == 2L) f[[2L]] else f[[3L]]
}

#' Get the left-hand side of a formula
#' @param f A formula.
#' @return A language object or `NULL` for one-sided formulas.
#' @keywords internal
formula_lhs <- function(f) {
  if (!inherits(f, "formula")) {
    cli::cli_abort("{.arg f} must be a formula.")
  }
  if (length(f) < 3L) NULL else f[[2L]]
}

#' All variable names appearing in a formula RHS
#'
#' Strips function calls and returns the base symbols. Useful for symbol
#' lookup and dictionary construction.
#'
#' @param f A formula.
#' @return A character vector of unique variable names.
#' @keywords internal
formula_vars <- function(f) {
  if (!inherits(f, "formula")) return(character(0))
  vars <- all.vars(formula_rhs(f))
  unique(vars)
}

#' Wrap a vector of equation lines in `aligned` environment
#' @param lines Character vector of LaTeX equation lines.
#' @keywords internal
wrap_aligned <- function(lines) {
  body <- paste(lines, collapse = " \\\\\n")
  paste0("\\begin{aligned}\n", body, "\n\\end{aligned}")
}
