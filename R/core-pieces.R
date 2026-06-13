# ----------------------------------------------------------------------------
# core-pieces.R
#
# `build_core_pieces()` renders the reader-facing pieces shared by explain()
# and model_card() so neither bundle has to list the builder calls itself.
# Both consume the same eight rendered tables; each constructor maps them onto
# its own field names and adds its own extras. Returned names are canonical
# (`formula_bridge`, `notation_bridge`); the legacy `$bridge` alias each bundle
# still exposes is assigned by the constructor, not here.
# ----------------------------------------------------------------------------

#' @keywords internal
build_core_pieces <- function(sym) {
  list(
    equations           = equations(sym, notation = "both"),
    symbols             = symbol_table(sym, notation = "both"),
    assumptions         = assumption_table(sym),
    formula_bridge      = formula_bridge(sym, notation = "both"),
    notation_bridge     = notation_bridge(sym),
    interpretation      = parameter_interpretation(sym, scale = "all"),
    factor_coding       = factor_overview_lines(sym),
    variance_components = sym$variance_components
  )
}
