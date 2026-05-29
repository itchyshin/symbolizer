# ----------------------------------------------------------------------------
# model-card.R
#
# Single-call teaching bundle. `model_card(sym)` returns the entire teachable
# package -- equation, assumptions, notation bridge, extraction calls,
# recommended plots -- as a `symbolizer_model_card` S3 object.
#
# Like `explain()` but oriented toward "how do I read AND act on this fit?":
# adds extraction calls (R code lines for pulling out blocks of the fit) and
# recommended plots (one-line text recipes; no live plotting in v0.1).
# ----------------------------------------------------------------------------

#' One-call teaching bundle for a symbolized model
#'
#' @description
#' `model_card()` returns the entire teachable package for a symbolized
#' model in a single S3 object: equation, symbol dictionary, assumptions,
#' notation bridge, formula bridge, per-coefficient interpretations,
#' extraction calls (R code to pull out blocks of the fit), and
#' recommended plots (one-line text recipes).
#'
#' Use [`explain()`] when you want the first-time-user walkthrough of the
#' symbols and equations. Use `model_card()` when you also want a quick
#' reference of *what to extract from the fit and what to plot next*.
#'
#' The bundle is a plain list; print it at the console for a structured
#' walkthrough, or knit it inside a Quarto / R Markdown document for a
#' heading-and-table section per piece.
#'
#' @param x A [`symbolized_model`][new_symbolized_model] (output of
#'   [`symbolize()`]).
#' @param ... Reserved for future use.
#'
#' @return A `symbolizer_model_card` (a list) with elements:
#'   `meta`, `equation`, `symbols`, `assumptions`, `bridge`,
#'   `formula_bridge`, `interpretation`, `variance_components` (NULL when
#'   the model has no random effects), `warnings`, `extraction_calls`,
#'   `recommended_plots`, `marginal_means` (NULL when the model has no
#'   factors), `marginal_slopes` (NULL when no continuous-by-* interaction
#'   is present).
#' @export
model_card <- function(x, ...) {
  UseMethod("model_card")
}

#' @export
model_card.default <- function(x, ...) {
  cli::cli_abort(c(
    "{.fn model_card} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
model_card.symbolized_model <- function(x, ...) {
  meta <- list(
    class   = x$model$class,
    package = x$model$package,
    family  = x$model$family,
    response = x$model$response,
    n_obs   = x$model$n_obs,
    context = x$metadata$context
  )
  out <- list(
    meta              = meta,
    equation          = equations(x, notation = "both"),
    symbols           = symbol_table(x, notation = "both"),
    assumptions       = assumption_table(x),
    bridge            = notation_bridge(x),
    formula_bridge    = formula_bridge(x, notation = "both"),
    interpretation    = parameter_interpretation(x, scale = "all"),
    variance_components = x$variance_components,
    warnings          = warning_table(x),
    extraction_calls  = model_card_extraction_calls(x),
    recommended_plots = model_card_recommended_plots(x),
    marginal_means    = model_card_marginal_means(x),
    marginal_slopes   = model_card_marginal_slopes(x)
  )
  class(out) <- c("symbolizer_model_card", "list")
  out
}

# Pre-render group means when the model has factors and emmeans is
# available. Returns NULL on either count, or on any extraction error.
model_card_marginal_means <- function(x) {
  if (!requireNamespace("emmeans", quietly = TRUE)) return(NULL)
  d <- x$symbol_dictionary
  if (is.null(d) || !any(d$role == "factor", na.rm = TRUE)) return(NULL)
  tryCatch(group_means(x), error = function(e) NULL)
}

# Pre-render group slopes when the model has a continuous-by-* interaction
# and emmeans is available. Picks the first continuous predictor appearing
# in any interaction; returns NULL when there is none.
model_card_marginal_slopes <- function(x) {
  if (!requireNamespace("emmeans", quietly = TRUE)) return(NULL)
  terms_tbl <- x$terms
  if (is.null(terms_tbl) || nrow(terms_tbl) == 0L) return(NULL)
  inter <- terms_tbl[terms_tbl$role == "interaction", , drop = FALSE]
  if (nrow(inter) == 0L) return(NULL)
  # The set of continuous predictors anywhere in the terms table: a
  # variable with at least one "predictor" / "transformation" row in this
  # model.
  cont_predictors <- unique(terms_tbl$variable[
    terms_tbl$role %in% c("predictor", "transformation") &
      !is.na(terms_tbl$variable)
  ])
  if (length(cont_predictors) == 0L) return(NULL)
  # Pick the first continuous predictor that actually appears in an
  # interaction; emtrends needs that variable as `var`.
  in_interaction <- vapply(cont_predictors, function(v) {
    any(vapply(inter$variable, function(iv) {
      v %in% strsplit(iv, ":", fixed = TRUE)[[1L]]
    }, logical(1L)))
  }, logical(1L))
  if (!any(in_interaction)) return(NULL)
  pick <- cont_predictors[in_interaction][[1L]]
  tryCatch(group_slopes(x, continuous = pick), error = function(e) NULL)
}

# Class-specific extraction calls. Returns a named character vector of R
# code lines that pull out the blocks a user typically wants from a fit of
# this class. Keys are descriptions; values are the R code. Defaults to an
# empty character vector for unknown classes.
model_card_extraction_calls <- function(x) {
  cls <- x$model$class
  switch(
    cls,
    drmTMB = c(
      # Diagnostics-first ordering per drmTMB team: a reader should know
      # whether the fit is trustworthy before reading the coefficients.
      "Convergence and diagnostic checks" = "drmTMB::check_drm(fit)",
      "Residuals"                = "residuals(fit)",
      "Fitted values"            = "predict(fit)",
      # Public extractors over $-internals: prefer drmTMB::ranef(fit)
      # to fit$random_effects.
      "Fixed effects (mu)"       = "drmTMB::fixef(fit, dpar = \"mu\")",
      "Fixed effects (sigma)"    = "drmTMB::fixef(fit, dpar = \"sigma\")",
      "Random effects (BLUPs)"   = "drmTMB::ranef(fit)",
      "Symbolic story"           = "symbolizer::symbolize(fit)",
      "Teaching bundle"          = "symbolizer::model_card(symbolizer::symbolize(fit))",
      "Group means (alongside contrasts)"        = "symbolizer::group_means(sym)",
      "Per-group slopes (alongside interactions)" = "symbolizer::group_slopes(sym, continuous = <one of your continuous predictors>)"
    ),
    gllvmTMB = c(
      "Loading matrix Lambda_B"        = "gllvmTMB::getLoadings(fit)",
      "Latent scores Z_B"              = "gllvmTMB::getLV(fit, level = \"unit\")",
      "Implied covariance Sigma_B"     = "gllvmTMB::extract_Omega(fit)",
      "Between-unit communality"       = "gllvmTMB::extract_communality(fit)",
      "Between-unit correlations"      = "gllvmTMB::extract_correlations(fit)",
      "Trait-specific unique variance" = "gllvmTMB::getResidualCov(fit)$Psi",
      "Symbolic story"                 = "symbolizer::symbolize(fit)"
    ),
    character(0L)
  )
}

# Class-specific recommended plots. Returns a named character vector of
# one-line text recipes (no live plotting in v0.1). Keys are plot names;
# values are the prose recipe. Defaults to empty for unknown classes.
model_card_recommended_plots <- function(x) {
  cls <- x$model$class
  switch(
    cls,
    drmTMB = c(
      # Diagnostic plots first, interpretation plots second.
      "Residuals vs fitted"        = "Pearson residuals vs fitted; check for trend",
      "Residuals on the sigma scale" = "abs residuals vs scale-model predictor; check that the sigma submodel captures the heteroscedasticity",
      "Mean vs predictor"          = "plot fitted mu against the mean-model predictor; overlay raw data",
      "Sigma vs predictor"         = "plot fitted sigma against the scale-model predictor; on log scale",
      "Random-effect distribution" = "histogram or QQ of BLUPs"
    ),
    gllvmTMB = c(
      "Loading plot"        = "barplot or heatmap of Lambda_B; one bar per trait, panels by latent axis",
      "Ordination"          = "scatter of z_{B,i1} vs z_{B,i2} colored by a grouping variable",
      "Communality"         = "barplot of c^2_{B,t} per trait",
      "Correlation matrix"  = "heatmap of extract_correlations(fit) (between-unit)",
      "Residual diagnostic" = "QQ plot of standardized residuals on long-form data"
    ),
    character(0L)
  )
}

#' @export
print.symbolizer_model_card <- function(x, ...) {
  sym <- attr(x, "symbolized_model")
  meta <- x$meta
  cli::cli_h1("== model card: <{meta$class}> ==")

  # Reconstruct the same plain-English overview paragraph that summary()
  # / explain() lead with. We have the original symbolized_model pieces
  # captured implicitly in `x` (equation / formula_bridge etc.) but the
  # overview helper needs `model`, `submodels`, `metadata`, so rebuild a
  # lightweight shim from `meta`.
  cli::cli_text(
    "{.cls {meta$class}} ({meta$package})  family = {.val {meta$family}}  response = {.val {meta$response}}  (n = {meta$n_obs})"
  )
  if (!is.null(meta$context) && nzchar(meta$context)) {
    cli::cli_text("Context: {.emph {meta$context}}")
  }

  cli::cli_h2("Equations")
  cli::cli_text("{.emph The equation block, in both index and matrix notations.}")
  print(x$equation)

  cli::cli_h2("Symbols")
  cli::cli_text("{.emph What each mathematical symbol stands for.}")
  print(x$symbols)

  cli::cli_h2("Assumptions")
  cli::cli_text("{.emph What the model assumes (stated, implied, or your responsibility).}")
  print(x$assumptions)

  cli::cli_h2("Notation bridge (index vs matrix)")
  cli::cli_text("{.emph Reading the same model in both notations side by side.}")
  print(x$bridge)

  cli::cli_h2("Formula bridge (R syntax to mathematics)")
  cli::cli_text("{.emph What each piece of the R formula means mathematically.}")
  print(x$formula_bridge)

  cli::cli_h2("Parameter interpretation")
  cli::cli_text("{.emph What each fitted coefficient says, in plain English.}")
  print(x$interpretation)

  if (!is.null(x$warnings) && nrow(x$warnings) > 0L) {
    cli::cli_h2("Warnings")
    cli::cli_text("{.emph Conditions {.fn symbolize} flagged for this fit.}")
    print(x$warnings)
  }

  if (!is.null(x$marginal_means)) {
    cli::cli_h2("Group means")
    cli::cli_text("{.emph Per-level marginal means alongside the factor contrasts above.}")
    print(x$marginal_means)
  }
  if (!is.null(x$marginal_slopes)) {
    cli::cli_h2("Group slopes")
    cli::cli_text("{.emph Per-group slopes alongside the interaction contrasts above.}")
    print(x$marginal_slopes)
  }

  cli::cli_h2("Extraction calls")
  cli::cli_text("{.emph R code to pull out blocks of the fit.}")
  ec <- x$extraction_calls
  if (length(ec) == 0L) {
    cli::cli_text("{.emph (no extraction calls registered for class {.cls {meta$class}})}")
  } else {
    for (nm in names(ec)) {
      cli::cli_text("{.strong {nm}}")
      cli::cli_verbatim(paste0("  ", ec[[nm]]))
    }
  }

  cli::cli_h2("Recommended plots")
  cli::cli_text("{.emph One-line recipes for diagnostic and effect plots.}")
  rp <- x$recommended_plots
  if (length(rp) == 0L) {
    cli::cli_text("{.emph (no plot recipes registered for class {.cls {meta$class}})}")
  } else {
    for (nm in names(rp)) {
      cli::cli_text("{.strong {nm}}: {rp[[nm]]}")
    }
  }
  invisible(x)
}
