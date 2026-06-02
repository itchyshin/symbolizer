#' Index vs matrix notation bridge
#'
#' @description
#' Returns the educator-facing translation table that pairs each piece of the
#' model in index (scalar / element-wise) notation with its matrix-form
#' counterpart, together with its dimension. This is the surface that lets
#' readers learn to read both notations side by side without having to
#' translate by hand.
#'
#' Columns:
#'
#' - `concept`: short label, e.g. `"response"`, `"mu_linear_predictor"`.
#' - `index`: scalar / element-wise LaTeX (e.g. `\mu_i = \beta_0 + \beta_1 T_i`).
#' - `matrix`: bold matrix-form LaTeX (e.g. `\boldsymbol{\mu} = \mathbf{X}\boldsymbol{\beta}`).
#' - `dimension`: LaTeX-formatted shape (e.g. `\mathbb{R}^n`,
#'   `\mathbb{R}^{n \times p_\mu}`, `scalar`).
#'
#' @param x A `symbolized_model`.
#' @param ... Reserved for future use.
#'
#' @return A tibble with columns `concept`, `index`, `matrix`, `dimension`.
#' @examples
#' # notation_bridge(symbolize(lm(mpg ~ wt, data = mtcars)))
#' @export
notation_bridge <- function(x, ...) {
  UseMethod("notation_bridge")
}

#' @export
notation_bridge.default <- function(x, ...) {
  cli::cli_abort(c(
    "{.fn notation_bridge} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
notation_bridge.symbolized_model <- function(x, ...) {
  n_obs <- x$model$n_obs
  rows <- list()
  comp <- x$components
  dist_row <- comp[comp$kind == "distribution", , drop = FALSE]
  if (nrow(dist_row) > 0L) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      concept            = "conditional_distribution",
      index              = dist_row$equation[[1L]],
      matrix             = dist_row$equation_matrix[[1L]],
      dimension          = "\\mathbb{R}^n",
      dimension_concrete = sprintf("\\mathbb{R}^{%d}", n_obs)
    )
  }
  lp <- comp[comp$kind == "linear_predictor", , drop = FALSE]
  for (i in seq_len(nrow(lp))) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      concept            = paste0(lp$submodel[[i]], "_linear_predictor"),
      index              = lp$equation[[i]],
      matrix             = lp$equation_matrix[[i]],
      dimension          = "\\mathbb{R}^n",
      dimension_concrete = sprintf("\\mathbb{R}^{%d}", n_obs)
    )
  }
  d <- x$symbol_dictionary
  for (i in seq_len(nrow(d))) {
    if (is.na(d$symbol_matrix[[i]])) next
    if (identical(d$role[[i]], "design_matrix")) {
      idx_sym <- "--"
    } else {
      idx_sym <- if (is.na(d$symbol[[i]])) "--" else d$symbol[[i]]
    }
    rows[[length(rows) + 1L]] <- tibble::tibble(
      concept            = if (!is.na(d$variable[[i]])) d$variable[[i]] else d$role[[i]],
      index              = idx_sym,
      matrix             = d$symbol_matrix[[i]],
      dimension          = d$dimension[[i]],
      dimension_concrete = d$dimension_concrete[[i]]
    )
  }
  out <- do.call(rbind, rows)
  class(out) <- c("notation_bridge", class(out))
  out
}

#' @export
print.notation_bridge <- function(x, ...) {
  cli::cli_h2("Notation bridge")
  for (i in seq_len(nrow(x))) {
    cli::cli_text("{.strong {x$concept[[i]]}}")
    cli::cli_text("  index:     {.code {x$index[[i]]}}")
    cli::cli_text("  matrix:    {.code {x$matrix[[i]]}}")
    cli::cli_text("  dimension: {.code {x$dimension[[i]]}} (= {.code {x$dimension_concrete[[i]]}})")
  }
  invisible(x)
}
