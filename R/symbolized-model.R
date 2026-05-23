#' Construct a symbolized_model object
#'
#' @description
#' `new_symbolized_model()` is the internal S3 constructor. It validates field
#' presence and types and returns an object of class `"symbolized_model"`.
#' Tier-specific extractors such as `symbolize.drmTMB()` call this constructor
#' to wrap the fields they have populated.
#'
#' @param model A list with at least `class`, `package`, `family`, `response`, `n_obs`.
#' @param index A list of index symbols (`observation`, `individual`, `group`, `trait`, `time`).
#' @param parameterization A list capturing the family-specific scale meaning.
#' @param distribution A tibble of response distribution rows.
#' @param submodels A tibble with one row per linked distributional parameter.
#' @param terms A tibble: the term-grammar / model-matrix bridge.
#' @param fixed_effects A tibble of fixed-effect estimates joined to terms.
#' @param random_effects A tibble or `NULL`.
#' @param variance_components A tibble or `NULL`.
#' @param covariance_components A tibble or `NULL`.
#' @param symbol_dictionary A tibble of `(symbol, variable, units, role, description)`.
#' @param assumptions A tibble of stated/implied assumptions.
#' @param components A tibble: one row per renderable block.
#' @param interpretation A tibble of per-parameter readings.
#' @param formula_bridge A tibble: R syntax to statistical meaning to mathematics.
#' @param warnings_registry A tibble or `NULL`.
#' @param graph A list or `NULL`.
#' @param metadata A list with at least `call`, `context`, `package_versions`, `created_by`.
#'
#' @return A `symbolized_model` S3 object.
#' @keywords internal
new_symbolized_model <- function(
  model,
  index,
  parameterization,
  distribution,
  submodels,
  terms,
  fixed_effects,
  random_effects = NULL,
  variance_components = NULL,
  covariance_components = NULL,
  symbol_dictionary,
  assumptions,
  components,
  interpretation,
  formula_bridge,
  warnings_registry = NULL,
  graph = NULL,
  metadata
) {
  obj <- list(
    model = model,
    index = index,
    parameterization = parameterization,
    distribution = distribution,
    submodels = submodels,
    terms = terms,
    fixed_effects = fixed_effects,
    random_effects = random_effects,
    variance_components = variance_components,
    covariance_components = covariance_components,
    symbol_dictionary = symbol_dictionary,
    assumptions = assumptions,
    components = components,
    interpretation = interpretation,
    formula_bridge = formula_bridge,
    warnings_registry = warnings_registry,
    graph = graph,
    metadata = metadata
  )
  class(obj) <- "symbolized_model"
  validate_symbolized_model(obj)
  obj
}

#' Validate a symbolized_model object
#'
#' Checks that required fields are present and have the expected shape. Used
#' internally by [`new_symbolized_model()`] but exported for advanced users who
#' construct or modify objects manually.
#'
#' @param x A `symbolized_model`.
#'
#' @return Invisibly returns `x`. Errors via [`cli::cli_abort()`] if invalid.
#' @export
#' @examples
#' # validate_symbolized_model(symbolize(fit))
validate_symbolized_model <- function(x) {
  if (!inherits(x, "symbolized_model")) {
    cli::cli_abort("{.arg x} must be a {.cls symbolized_model} object.")
  }
  required_list <- c("model", "index", "parameterization", "metadata")
  required_tibble <- c(
    "distribution", "submodels", "terms", "fixed_effects",
    "symbol_dictionary", "assumptions", "components",
    "interpretation", "formula_bridge"
  )
  optional_tibble <- c("random_effects", "variance_components",
                       "covariance_components", "warnings_registry")
  for (f in required_list) {
    if (!is.list(x[[f]]) || length(x[[f]]) == 0L) {
      cli::cli_abort(c(
        "Field {.field {f}} is required and must be a non-empty list.",
        i = "Found {.cls {class(x[[f]])[1]}}."
      ))
    }
  }
  for (f in required_tibble) {
    if (!inherits(x[[f]], "data.frame")) {
      cli::cli_abort(c(
        "Field {.field {f}} is required and must be a data frame / tibble.",
        i = "Found {.cls {class(x[[f]])[1]}}."
      ))
    }
  }
  for (f in optional_tibble) {
    if (!is.null(x[[f]]) && !inherits(x[[f]], "data.frame")) {
      cli::cli_abort("Field {.field {f}} must be NULL or a data frame.")
    }
  }
  for (f in c("class", "package", "family", "response")) {
    if (is.null(x$model[[f]]) || !nzchar(as.character(x$model[[f]]))) {
      cli::cli_abort("Field {.field model${f}} is required.")
    }
  }
  invisible(x)
}

#' @export
print.symbolized_model <- function(x, ...) {
  cli::cli_h1("<symbolized_model>")
  cli::cli_text("Class: {.cls {x$model$class}}  ({x$model$package})")
  cli::cli_text("Family: {.val {x$model$family}}")
  cli::cli_text("Response: {.val {x$model$response}}  (n = {x$model$n_obs})")
  if (!is.null(x$metadata$context) && nzchar(x$metadata$context)) {
    cli::cli_text("Context: {.emph {x$metadata$context}}")
  }
  cli::cli_h2("Submodels")
  for (i in seq_len(nrow(x$submodels))) {
    s <- x$submodels[i, , drop = FALSE]
    f <- s$formula[[1L]]
    f_text <- if (inherits(f, "formula")) paste(deparse(f), collapse = " ") else as.character(f)
    cli::cli_text(
      "  {.code {s$parameter}}: {.code {f_text}}  (link: {.val {s$link}})"
    )
  }
  cli::cli_h2("Equations")
  for (eq in x$components$equation) {
    cli::cli_verbatim(paste0("  ", eq))
  }
  cli::cli_h2("Symbols")
  d <- x$symbol_dictionary
  width <- max(nchar(d$symbol), 4L)
  for (i in seq_len(nrow(d))) {
    cli::cli_verbatim(
      sprintf("  %-*s  %s", width, d$symbol[i], d$description[i])
    )
  }
  invisible(x)
}
