#' Expand a symbolized_model to its underlying numeric arrays
#'
#' @description
#' `expand()` returns the actual numeric pieces that make up the fitted model:
#' the response vector, design matrix per submodel, coefficient vectors,
#' random-effect indicator matrix and BLUPs (when present), residuals, and the
#' fitted conditional mean and SD vectors. This is the data side of the
#' [`symbolized_model`][new_symbolized_model] surface — the symbolic and matrix
#' views show *what shape* the model has; `expand()` shows *what numbers*
#' actually flow through it.
#'
#' Returned object is classed `c("symbolized_expanded", "list")` so it has a
#' compact `print()` method.
#'
#' @param x A `symbolized_model`.
#' @param ... Reserved for future use.
#'
#' @return A list with elements (NULL when not applicable to this fit):
#'   - `y`         response vector of length n
#'   - `X`         mu-submodel design matrix (n x p_mu)
#'   - `beta`      mu coefficient vector (p_mu)
#'   - `X_sigma`   sigma-submodel design matrix (n x p_sigma)
#'   - `gamma`     sigma coefficient vector (p_sigma)
#'   - `Z_g`       random-effect indicator matrix (n x G), if RE present
#'   - `u`         random-effect BLUPs (G), if RE present
#'   - `e`         residuals (n)
#'   - `mu_hat`    fitted conditional mean (n)
#'   - `sigma_hat` fitted per-observation SD (n)
#' @export
expand <- function(x, ...) {
  UseMethod("expand")
}

#' @export
expand.default <- function(x, ...) {
  cli::cli_abort(c(
    "{.fn expand} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
expand.symbolized_model <- function(x, ...) {
  if (is.null(x$expanded)) {
    cli::cli_abort(c(
      "This {.cls symbolized_model} carries no expanded numeric arrays.",
      i = "The extractor that built it did not populate {.field expanded}."
    ))
  }
  out <- x$expanded
  class(out) <- c("symbolized_expanded", "list")
  out
}

#' @export
print.symbolized_expanded <- function(x, head = 5L, tail = 2L, ...) {
  cli::cli_h2("Expanded numeric arrays")
  show_vec <- function(label, v) {
    if (is.null(v)) return(invisible())
    n <- length(v)
    body <- if (n <= head + tail + 2L) {
      paste(formatC(v, digits = 3, format = "fg", flag = "#"),
            collapse = "  ")
    } else {
      h <- formatC(v[seq_len(head)], digits = 3, format = "fg", flag = "#")
      t <- formatC(v[(n - tail + 1L):n], digits = 3, format = "fg", flag = "#")
      paste(c(h, "...", t), collapse = "  ")
    }
    cli::cli_text("{.strong {label}} ({n}): {.code {body}}")
  }
  show_mat <- function(label, M) {
    if (is.null(M)) return(invisible())
    nr <- nrow(M); nc <- ncol(M)
    cli::cli_text("{.strong {label}} ({nr} x {nc}):")
    head_rows <- min(head, nr)
    for (i in seq_len(head_rows)) {
      row <- paste(formatC(M[i, ], digits = 3, format = "fg", flag = "#"),
                   collapse = "  ")
      cli::cli_verbatim(paste0("  ", row))
    }
    if (nr > head_rows + tail) {
      cli::cli_verbatim("  ...")
      for (i in (nr - tail + 1L):nr) {
        row <- paste(formatC(M[i, ], digits = 3, format = "fg", flag = "#"),
                     collapse = "  ")
        cli::cli_verbatim(paste0("  ", row))
      }
    }
  }
  show_vec("y",         x$y)
  show_mat("X (mu)",    x$X)
  show_vec("beta",      x$beta)
  show_mat("X_sigma",   x$X_sigma)
  show_vec("gamma",     x$gamma)
  if (!is.null(x$Z_g)) show_mat("Z_g (RE)", x$Z_g)
  show_vec("u (BLUPs)", x$u)
  show_vec("mu_hat",    x$mu_hat)
  show_vec("sigma_hat", x$sigma_hat)
  show_vec("e (residuals)", x$e)
  invisible(x)
}
