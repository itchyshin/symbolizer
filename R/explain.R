# ----------------------------------------------------------------------------
# explain.R
#
# The first-time-user entry point. `explain(fit)` runs `symbolize()` and
# pre-renders the six reader-facing tables in one go. Returns a
# `symbolized_explanation` (S3 class) that prints a plain-English walkthrough
# at the console and renders a heading-and-kable section per piece in
# .Rmd / .qmd documents.
# ----------------------------------------------------------------------------

#' One-call explainer for a fitted model
#'
#' @description
#' `explain()` is the recommended entry point for first-time users. It runs
#' [`symbolize()`] internally and returns a `symbolized_explanation` that
#' bundles the original [`symbolized_model`][new_symbolized_model] together
#' with the six reader-facing pieces already rendered:
#'
#' * `equations`        -- the [`equations()`] tibble (both notations)
#' * `symbols`          -- the [`symbol_table()`] result
#' * `assumptions`      -- the [`assumption_table()`] result
#' * `bridge`           -- the [`formula_bridge()`] result
#' * `interpretation`   -- the [`parameter_interpretation()`] result
#' * `variance_components` -- where the variation lives (NULL when the model
#'   has no random effects)
#' * `notation_bridge`  -- the [`notation_bridge()`] result
#'
#' Print the result at the console for a walkthrough led by a plain-English
#' paragraph, or knit it inside a Quarto / R Markdown document for a
#' heading-and-kable section per piece.
#'
#' Use [`summary()`] on an already-symbolize'd object to get the same
#' walkthrough without re-running [`symbolize()`].
#'
#' @inheritParams symbolize
#'
#' @return A `symbolized_explanation` object with elements `model` (the
#'   underlying `symbolized_model`), `equations`, `symbols`, `assumptions`,
#'   `bridge`, `interpretation`, `variance_components` (NULL when the model
#'   has no random effects), `notation_bridge`.
#' @examples
#' # explain(symbolize(lm(mpg ~ wt, data = mtcars)))
#' @export
explain <- function(fit, symbols = NULL, units = NULL, context = NULL, ...) {
  sym <- symbolize(fit, symbols = symbols, units = units,
                   context = context, ...)
  new_symbolized_explanation(sym)
}

# Internal constructor. Takes a symbolized_model and pre-renders every
# reader-facing piece so the result can be printed or knit_print()'d without
# touching the original fit again.
new_symbolized_explanation <- function(sym) {
  if (!inherits(sym, "symbolized_model")) {
    cli::cli_abort("{.arg sym} must be a {.cls symbolized_model}.")
  }
  out <- list(
    model           = sym,
    equations       = equations(sym, notation = "both"),
    symbols         = symbol_table(sym, notation = "both"),
    assumptions     = assumption_table(sym),
    bridge          = formula_bridge(sym, notation = "both"),
    interpretation  = parameter_interpretation(sym, scale = "all"),
    factor_coding   = factor_overview_lines(sym),
    # v0.22.x: surface where the variation lives. Previously dropped even
    # though every mixed-model extractor computes the variance components.
    variance_components = sym$variance_components,
    notation_bridge = notation_bridge(sym)
  )
  class(out) <- c("symbolized_explanation", "list")
  out
}

#' @export
print.symbolized_explanation <- function(x, ...) {
  sym <- x$model
  cli::cli_h1(
    "== explaining your <{sym$model$class}> model =="
  )
  cli::cli_text(
    sym_overview_paragraph(sym$model, sym$submodels, sym$metadata)
  )

  cli::cli_h2("Equations (both notations)")
  print(x$equations)

  cli::cli_h2("The symbols")
  print(x$symbols)

  cli::cli_h2("What's assumed")
  print(x$assumptions)

  cli::cli_h2("R syntax to mathematics")
  print(x$bridge)

  cli::cli_h2("What each coefficient means")
  print(x$interpretation)

  if (length(x$factor_coding) > 0L) {
    cli::cli_h2("Factor coding")
    cli::cli_text("{.emph How each categorical predictor is dummy-coded -- call {.fn explain_factors} for the group means and pairwise contrasts.}")
    for (ln in x$factor_coding) cli::cli_text(ln)
  }

  if (!is.null(x$variance_components) && nrow(x$variance_components) > 0L) {
    cli::cli_h2("How the variation splits")
    print(x$variance_components)
  }

  cli::cli_h2("Index vs matrix notation")
  print(x$notation_bridge)

  invisible(x)
}

#' @exportS3Method knitr::knit_print
knit_print.symbolized_explanation <- function(x, ...) {
  if (!requireNamespace("knitr", quietly = TRUE)) {
    return(print(x))
  }
  sym <- x$model
  para <- sym_overview_paragraph(sym$model, sym$submodels, sym$metadata)
  sections <- list(
    list(title = "Equations", obj = x$equations),
    list(title = "Symbols", obj = x$symbols),
    list(title = "What's assumed", obj = x$assumptions),
    list(title = "R syntax to mathematics", obj = x$bridge),
    list(title = "What each coefficient means", obj = x$interpretation),
    if (!is.null(x$variance_components) && nrow(x$variance_components) > 0L)
      list(title = "How the variation splits", obj = x$variance_components),
    list(title = "Index vs matrix notation", obj = x$notation_bridge)
  )
  sections <- Filter(Negate(is.null), sections)
  parts <- c(
    sprintf("## Explaining your `%s` model", sym$model$class),
    "",
    para,
    ""
  )
  for (s in sections) {
    rendered <- knitr::knit_print(s$obj)
    parts <- c(
      parts,
      sprintf("### %s", s$title),
      "",
      as.character(rendered),
      ""
    )
  }
  if (length(x$factor_coding) > 0L) {
    parts <- c(parts, "### Factor coding", "",
               paste0("- ", x$factor_coding), "")
  }
  knitr::asis_output(paste(parts, collapse = "\n"))
}
