#' Equation rows from a symbolized_model
#'
#' @description
#' Returns the equation lines carried by a [`symbolized_model`][new_symbolized_model]
#' as a tibble. One row per renderable block in `x$components`. Both notations
#' (index and matrix) are always returned in their own columns; the `notation`
#' argument only controls how the result is *displayed* by [`print()`].
#'
#' For the LaTeX-string form ready to splice into a document, see
#' [`as_latex()`].
#'
#' @param x A [`symbolized_model`][new_symbolized_model].
#' @param notation One of `"index"`, `"matrix"`, or `"both"`. Sets the display
#'   preference recorded as the `"notation"` attribute and used by the
#'   `symbolizer_equations` `print()` method.
#' @param ... Reserved for future use.
#'
#' @return A tibble with columns `name`, `kind`, `submodel`, `index`, `matrix`
#'   and the additional class `"symbolizer_equations"`.
#' @export
#' @examples
#' # equations(symbolize(fit))
equations <- function(x, notation = c("index", "matrix", "both"), ...) {
  UseMethod("equations")
}

#' @export
equations.default <- function(x, notation = c("index", "matrix", "both"), ...) {
  cli::cli_abort(c(
    "{.fn equations} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
equations.symbolized_model <- function(x, notation = c("index", "matrix", "both"), ...) {
  notation <- match.arg(notation)
  comp <- x$components
  out <- tibble::tibble(
    name     = comp$name,
    kind     = comp$kind,
    submodel = comp$submodel,
    index    = comp$equation,
    matrix   = comp$equation_matrix
  )
  attr(out, "notation") <- notation
  class(out) <- c("symbolizer_equations", class(out))
  out
}

#' @export
print.symbolizer_equations <- function(x, ...) {
  notation <- attr(x, "notation") %||% "both"
  cli::cli_h2("Equations")
  for (i in seq_len(nrow(x))) {
    cli::cli_text("{.strong {x$name[[i]]}}")
    if (notation %in% c("index", "both")) {
      cli::cli_verbatim(paste0("  index:  ", x$index[[i]]))
    }
    if (notation %in% c("matrix", "both")) {
      cli::cli_verbatim(paste0("  matrix: ", x$matrix[[i]]))
    }
  }
  invisible(x)
}

#' Render a symbolized_model as LaTeX
#'
#' @description
#' `as_latex()` turns a [`symbolized_model`][new_symbolized_model] into a single
#' LaTeX string ready to splice into a document. By default the equations are
#' wrapped in an `aligned` environment with `&` alignment markers inserted
#' before `=` or `\sim` on each line.
#'
#' @param x A [`symbolized_model`][new_symbolized_model].
#' @param notation One of `"index"`, `"matrix"`, or `"both"`. With `"both"`,
#'   two `env` blocks are stacked, separated by a `\text{(matrix notation)}`
#'   header.
#' @param env LaTeX environment to wrap the equations in. Defaults to
#'   `"aligned"`. Other useful values: `"align*"`, `"gather"`.
#' @param ... Reserved for future use.
#'
#' @return A single character string.
#' @export
#' @examples
#' # cat(as_latex(symbolize(fit)))
as_latex <- function(x, notation = c("index", "matrix", "both"),
                     env = "aligned", ...) {
  UseMethod("as_latex")
}

#' @export
as_latex.default <- function(x, notation = c("index", "matrix", "both"),
                             env = "aligned", ...) {
  cli::cli_abort(c(
    "{.fn as_latex} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
as_latex.symbolized_model <- function(x, notation = c("index", "matrix", "both"),
                                      env = "aligned", ...) {
  notation <- match.arg(notation)
  if (!is.character(env) || length(env) != 1L || !nzchar(env)) {
    cli::cli_abort("{.arg env} must be a single non-empty string.")
  }
  comp <- x$components
  if (notation == "index") {
    return(wrap_env(vapply(comp$equation, align_at, character(1L),
                           USE.NAMES = FALSE), env))
  }
  if (notation == "matrix") {
    return(wrap_env(vapply(comp$equation_matrix, align_at, character(1L),
                           USE.NAMES = FALSE), env))
  }
  index_block  <- wrap_env(vapply(comp$equation, align_at, character(1L),
                                  USE.NAMES = FALSE), env)
  matrix_block <- wrap_env(vapply(comp$equation_matrix, align_at, character(1L),
                                  USE.NAMES = FALSE), env)
  paste(
    "\\text{(index notation)}",
    index_block,
    "\\text{(matrix notation)}",
    matrix_block,
    sep = "\n"
  )
}

# ---- internal helpers -------------------------------------------------------

#' Insert an alignment marker before `=` or `\\sim`
#'
#' Inserts a single `&` immediately before the first `=` (not part of `\=`) or
#' the first `\sim` token in a LaTeX equation line. Used to add `aligned`-style
#' alignment markers to the lines carried by `x$components`.
#'
#' @param line A character string (one LaTeX equation line, no outer math
#'   delimiters).
#' @return The line with `&` inserted before the alignment point. If no `=` or
#'   `\sim` is found the line is returned unchanged.
#' @keywords internal
align_at <- function(line) {
  if (is.na(line) || !nzchar(line)) return(line)
  # Match either ' = ' (with a leading space) or ' \sim ' as a whole token,
  # and place `&` immediately before it. We require a leading whitespace so
  # we never touch '\\=' or other escape sequences.
  sub("(\\s)(=|\\\\sim\\b)", " & \\2", line, perl = TRUE)
}

#' Wrap aligned LaTeX equation lines in a chosen environment
#'
#' A generalisation of [`wrap_aligned()`] that takes an arbitrary LaTeX
#' environment name (e.g. `"aligned"`, `"align*"`, `"gather"`).
#'
#' @param lines Character vector of LaTeX equation lines.
#' @param env LaTeX environment name. Single non-empty string.
#' @return A single string containing `\\begin{env} ... \\end{env}`.
#' @keywords internal
wrap_env <- function(lines, env) {
  body <- paste(lines, collapse = " \\\\\n")
  paste0("\\begin{", env, "}\n", body, "\n\\end{", env, "}")
}
