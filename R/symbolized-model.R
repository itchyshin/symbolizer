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
#' @param loadings A tibble of latent-factor loadings (rows: one per
#'   `(submodel, trait, axis)` entry of a loading matrix) or `NULL`. Populated
#'   by extractors for reduced-rank latent-variable models such as gllvmTMB.
#' @param symbol_dictionary A tibble of `(symbol, variable, units, role, description)`.
#' @param assumptions A tibble of stated/implied assumptions.
#' @param components A tibble: one row per renderable block.
#' @param interpretation A tibble of per-parameter readings.
#' @param formula_bridge A tibble: R syntax to statistical meaning to mathematics.
#' @param warnings_registry A tibble or `NULL`.
#' @param graph A list or `NULL`.
#' @param expanded A list of actual numeric arrays (response vector, design
#'   matrices, coefficient vectors, random-effect BLUPs, residuals, fitted
#'   mu/sigma) or `NULL`. Populated by extractors that have access to the
#'   original fit; consumed by `expand()` and the three-views renderer.
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
  loadings = NULL,
  symbol_dictionary,
  assumptions,
  components,
  interpretation,
  formula_bridge,
  warnings_registry = NULL,
  graph = NULL,
  expanded = NULL,
  metadata
) {
  # Attach S3 sub-classes to optional tibbles so knit_print methods can render
  # them with math math-aware formatting in vignettes / knitr output. The
  # underlying tbl_df / tbl / data.frame classes remain intact, so all
  # downstream tibble operations are unaffected.
  if (!is.null(random_effects) &&
      !inherits(random_effects, "symbolizer_random_effects")) {
    class(random_effects) <- c("symbolizer_random_effects", class(random_effects))
  }
  if (!is.null(variance_components) &&
      !inherits(variance_components, "symbolizer_variance_components")) {
    class(variance_components) <- c("symbolizer_variance_components",
                                    class(variance_components))
  }

  # Precompute, in the model-building layer, whether each submodel's linear
  # predictor carries predictor terms. Renderers consume this flag instead of
  # re-parsing the formula string (architectural rule: no renderer parses
  # formulas itself).
  submodels <- add_submodel_predictor_flag(submodels)

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
    loadings = loadings,
    symbol_dictionary = symbol_dictionary,
    assumptions = assumptions,
    components = components,
    interpretation = interpretation,
    formula_bridge = formula_bridge,
    warnings_registry = warnings_registry,
    graph = graph,
    expanded = expanded,
    metadata = metadata
  )
  class(obj) <- "symbolized_model"
  validate_symbolized_model(obj)
  obj
}

#' Validate a symbolized_model object
#'
#' Checks that required fields are present and have the expected shape. Used
#' internally by [`new_symbolized_model()`]. Reachable as
#' `symbolizer:::validate_symbolized_model()` for advanced users who construct
#' or modify objects by hand.
#'
#' @param x A `symbolized_model`.
#'
#' @return Invisibly returns `x`. Errors via [`cli::cli_abort()`] if invalid.
#' @keywords internal
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
                       "covariance_components", "loadings",
                       "warnings_registry")
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

# Add a logical `has_predictors` column to the submodels tibble, recording
# whether each submodel's formula has any term labels (predictors beyond the
# intercept). Computed once here, in the object-construction layer, so that
# renderers can read structure rather than parsing the formula string. A
# no-op when there is no `formula` column or the flag is already present.
add_submodel_predictor_flag <- function(submodels) {
  if (is.null(submodels) || !is.data.frame(submodels) ||
      !("formula" %in% names(submodels)) ||
      "has_predictors" %in% names(submodels)) {
    return(submodels)
  }
  submodels$has_predictors <- vapply(submodels$formula, function(f) {
    tt <- tryCatch(stats::terms(stats::as.formula(f)),
                   error = function(e) NULL)
    !is.null(tt) && length(attr(tt, "term.labels")) > 0L
  }, logical(1L))
  submodels
}

#' @export
print.symbolized_model <- function(x, ...) {
  cli::cli_text(
    "{.cls symbolized_model} -- call {.fn summary} for a plain-English walkthrough, or {.fn explain} in one step from your fit."
  )
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
  sym_text <- ifelse(is.na(d$symbol), "--", d$symbol)
  width <- max(c(nchar(sym_text), 4L), na.rm = TRUE)
  for (i in seq_len(nrow(d))) {
    cli::cli_verbatim(
      sprintf("  %-*s  %s", width, sym_text[i], d$description[i])
    )
  }
  if (!is.null(x$random_effects) && nrow(x$random_effects) > 0L) {
    cli::cli_h2("Random effects")
    for (i in seq_len(nrow(x$random_effects))) {
      r <- x$random_effects[i, , drop = FALSE]
      cli::cli_text(
        "  {.code {r$term_label}}  on submodel {.val {r$submodel}}  ({r$n_levels} levels)"
      )
    }
  }
  if (!is.null(x$loadings) && nrow(x$loadings) > 0L) {
    cli::cli_h2("Loadings")
    n_traits <- length(unique(x$loadings$trait))
    n_axes <- length(unique(x$loadings$axis))
    cli::cli_text(
      "  {.code {unique(x$loadings$matrix)}}: {n_traits} trait{?s} x {n_axes} axis/axes"
    )
  }
  invisible(x)
}

#' Plain-English summary of a symbolized model
#'
#' @description
#' `summary()` walks the reader through a [`symbolized_model`][new_symbolized_model]
#' in plain English. It opens with one paragraph describing the model in
#' prose (class, family, response, sample size, submodels and links, fitting
#' approach), then prints the same reader tables that [`explain()`] returns:
#' equations, the symbol dictionary, assumptions, the formula bridge, the
#' per-coefficient interpretations, and the notation bridge.
#'
#' Unlike [`explain()`], `summary()` does not re-run [`symbolize()`]; it
#' simply renders the object you already have.
#'
#' @param object A [`symbolized_model`][new_symbolized_model].
#' @param ... Reserved for future use.
#'
#' @return Invisibly returns a `summary.symbolized_model` object (a list with
#'   the rendered pieces). Called for its printed walkthrough.
#' @export
summary.symbolized_model <- function(object, ...) {
  out <- list(
    model           = object$model,
    submodels       = object$submodels,
    metadata        = object$metadata,
    equations       = equations(object, notation = "both"),
    symbols         = symbol_table(object, notation = "both"),
    assumptions     = assumption_table(object),
    bridge          = formula_bridge(object, notation = "both"),
    interpretation  = parameter_interpretation(object, scale = "all"),
    notation_bridge = notation_bridge(object)
  )
  class(out) <- c("summary.symbolized_model", "list")
  print(out)
  invisible(out)
}

# Build the leading plain-English paragraph for summary() and explain().
# Reads only `model`, `submodels`, and `metadata` -- never parses formulas
# itself. Returns a single character string.
sym_overview_paragraph <- function(model, submodels, metadata) {
  fam <- model$family
  resp <- model$response
  n <- model$n_obs
  n_sub <- nrow(submodels)
  a_or_an <- function(word) {
    if (grepl("^[aeiou]", word, ignore.case = TRUE)) "an" else "a"
  }
  pieces <- vapply(seq_len(n_sub), function(i) {
    sm <- submodels[i, , drop = FALSE]
    link <- sm$link[[1L]]
    sprintf("%s explains the %s (using %s %s link)",
            sm$parameter[[1L]],
            sym_submodel_meaning(sm$parameter[[1L]]),
            a_or_an(link), link)
  }, character(1L))
  joined <- if (length(pieces) == 1L) {
    pieces
  } else if (length(pieces) == 2L) {
    paste(pieces, collapse = ", and ")
  } else {
    paste(c(paste(pieces[-length(pieces)], collapse = ", "),
            pieces[[length(pieces)]]),
          collapse = ", and ")
  }
  fitter <- sym_fitter_phrase(model$package)
  sprintf(
    "This is a %s model of `%s` (n = %d) with %d submodel%s: %s. Coefficients are fit by %s.",
    fam, resp, n, n_sub, if (n_sub == 1L) "" else "s", joined, fitter
  )
}

sym_submodel_meaning <- function(dpar) {
  switch(
    dpar,
    mu    = "mean",
    sigma = "residual standard deviation",
    nu    = "degrees of freedom",
    sprintf("%s submodel", dpar)
  )
}

sym_fitter_phrase <- function(pkg) {
  pkg <- pkg %||% ""
  if (!nzchar(pkg)) return("maximum likelihood")
  switch(
    pkg,
    drmTMB   = "maximum likelihood via drmTMB",
    gllvmTMB = "maximum likelihood via gllvmTMB",
    sprintf("maximum likelihood via %s", pkg)
  )
}

#' @export
print.summary.symbolized_model <- function(x, ...) {
  cli::cli_h1("Summary of <symbolized_model>")
  cli::cli_text(sym_overview_paragraph(x$model, x$submodels, x$metadata))

  cli::cli_h2("Equations (index and matrix notation)")
  print(x$equations)

  cli::cli_h2("Symbols")
  print(x$symbols)

  cli::cli_h2("What's assumed")
  print(x$assumptions)

  cli::cli_h2("R syntax to mathematics")
  print(x$bridge)

  cli::cli_h2("What each coefficient means")
  print(x$interpretation)

  cli::cli_h2("Index vs matrix notation bridge")
  print(x$notation_bridge)

  invisible(x)
}
