#' Get the family parameterization contract
#'
#' Looks up family-specific scale meaning, links, and natural-scale transforms
#' from `inst/extdata/family-parameterizations.csv`. Errors if the family has
#' no row.
#'
#' @param family Family name (character), e.g. `"gaussian"`.
#'
#' @return A list with fields family, response_distribution, scale_parameter,
#'   scale_meaning, link_mu, link_sigma, variance_expression,
#'   natural_sd_ratio, natural_variance_ratio, notes.
#' @keywords internal
get_parameterization <- function(family) {
  tbl <- load_template("family-parameterizations")
  row <- tbl[tbl$family == family, , drop = FALSE]
  if (nrow(row) == 0L) {
    cli::cli_abort(c(
      "No parameterization contract for family {.val {family}}.",
      i = "Add a row to {.file inst/extdata/family-parameterizations.csv}."
    ))
  }
  as.list(row[1L, ])
}
