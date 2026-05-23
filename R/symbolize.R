#' Symbolize a fitted statistical model
#'
#' @description
#' `symbolize()` converts a fitted model object into a structured
#' [`symbolized_model`][new_symbolized_model] from which LaTeX equations,
#' symbol dictionaries, assumption tables, formula bridges, and parameter
#' interpretations can be rendered.
#'
#' Methods exist for fitted-model classes registered in
#' [`symbolizer_capabilities()`]. The default method errors with a pointer
#' to the registry.
#'
#' @param fit A fitted statistical model object.
#' @param symbols Optional named character vector mapping variable names
#'   to user-supplied LaTeX symbols, e.g. `c(body_mass = "W_i", temperature = "T_i")`.
#' @param units Optional named character vector mapping variable names to
#'   units, e.g. `c(body_mass = "g", temperature = "C")`.
#' @param context Optional short character description of the model, e.g.
#'   `"avian body-size location-scale model"`.
#' @param ... Reserved for method-specific extra arguments.
#'
#' @return A [`symbolized_model`][new_symbolized_model] object.
#' @export
#'
#' @examples
#' # See methods listed in `symbolizer_capabilities()`.
symbolize <- function(fit, symbols = NULL, units = NULL, context = NULL, ...) {
  UseMethod("symbolize")
}

#' @export
symbolize.default <- function(fit, symbols = NULL, units = NULL, context = NULL, ...) {
  cls <- class(fit)[1L]
  cli::cli_abort(c(
    "{.fn symbolize} has no method for objects of class {.cls {cls}}.",
    i = "See {.fn symbolizer_capabilities} for supported model classes."
  ))
}
