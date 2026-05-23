#' Per-parameter interpretations for a symbolized model
#'
#' @description
#' Returns the per-coefficient reading tibble carried by a
#' [`symbolized_model`][new_symbolized_model] as a reader-friendly table. Each
#' row corresponds to one fixed-effect coefficient and pairs it with the prose
#' readings already templated by `symbolize()`: a link-scale reading, a
#' natural-scale reading, an optional variance-scale reading (for scale
#' submodels), and a biological reading.
#'
#' The renderer is a pure consumer of `x$interpretation`. All prose was
#' substituted from `inst/extdata/interpretation-templates.csv` at extract
#' time; this surface only displays it.
#'
#' @param x A [`symbolized_model`][new_symbolized_model].
#' @param scale One of `"all"` (default), `"link"`, `"natural"`, `"variance"`,
#'   or `"biological"`. `"all"` returns every reading column; the other values
#'   return just the identifier columns (`submodel`, `term_label`,
#'   `coefficient_role`, `estimate`) plus the matching single reading column.
#' @param ... Reserved for future use.
#'
#' @return A tibble (S3 class `symbolizer_interpretation`) with `submodel`,
#'   `term_label`, `coefficient_role`, `estimate`, and one or more reading
#'   columns. The `"scale"` attribute records which scale was requested.
#' @export
parameter_interpretation <- function(x,
                                     scale = c("all", "link", "natural",
                                               "variance", "biological"),
                                     ...) {
  UseMethod("parameter_interpretation")
}

#' @export
parameter_interpretation.default <- function(x,
                                             scale = c("all", "link", "natural",
                                                       "variance", "biological"),
                                             ...) {
  cli::cli_abort(c(
    "{.fn parameter_interpretation} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
parameter_interpretation.symbolized_model <- function(x,
                                                      scale = c("all", "link",
                                                                "natural",
                                                                "variance",
                                                                "biological"),
                                                      ...) {
  scale <- match.arg(scale)
  interp <- x$interpretation
  id_cols <- c("submodel", "term_label", "coefficient_role", "estimate")
  reading_col <- switch(
    scale,
    all        = c("link_scale_reading", "natural_scale_reading",
                   "variance_scale_reading", "biological_reading"),
    link       = "link_scale_reading",
    natural    = "natural_scale_reading",
    variance   = "variance_scale_reading",
    biological = "biological_reading"
  )
  out <- tibble::as_tibble(interp[, c(id_cols, reading_col), drop = FALSE])
  attr(out, "scale") <- scale
  class(out) <- c("symbolizer_interpretation", class(out))
  out
}

#' @export
print.symbolizer_interpretation <- function(x, ...) {
  scale <- attr(x, "scale") %||% "all"
  cli::cli_h2("Parameter interpretation ({.val {scale}})")
  if (nrow(x) == 0L) {
    cli::cli_text("{.emph (no interpretable coefficients)}")
    return(invisible(x))
  }
  has_link       <- "link_scale_reading"       %in% names(x)
  has_natural    <- "natural_scale_reading"    %in% names(x)
  has_variance   <- "variance_scale_reading"   %in% names(x)
  has_biological <- "biological_reading"       %in% names(x)
  submodels <- unique(x$submodel)
  for (sm in submodels) {
    cli::cli_h3("{.strong submodel: {sm}}")
    rows <- which(x$submodel == sm)
    for (i in rows) {
      est <- formatC(x$estimate[[i]], digits = 3L, format = "fg", flag = "#")
      cli::cli_text(
        "{.emph {x$term_label[[i]]}} [{.val {x$coefficient_role[[i]]}}]  estimate = {.val {est}}"
      )
      if (has_link) {
        v <- x$link_scale_reading[[i]]
        if (interp_show(v)) {
          cli::cli_text("  link:       {v}")
        }
      }
      if (has_natural) {
        v <- x$natural_scale_reading[[i]]
        if (interp_show(v)) {
          cli::cli_text("  natural:    {v}")
        }
      }
      if (has_variance) {
        v <- x$variance_scale_reading[[i]]
        if (interp_show(v)) {
          cli::cli_text("  variance:   {v}")
        }
      }
      if (has_biological) {
        v <- x$biological_reading[[i]]
        if (interp_show(v)) {
          cli::cli_text("  biological: {v}")
        }
      }
    }
  }
  invisible(x)
}

# Drop empty / placeholder readings from the print output.
interp_show <- function(s) {
  !is.na(s) && nzchar(s) && !identical(s, "--")
}
