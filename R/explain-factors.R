# ----------------------------------------------------------------------------
# explain-factors.R
#
# `explain_factors()` is the one-call demystifier for dummy / contrast coding.
# For each factor it states the coding scheme (levels, reference, how many
# indicator columns) in plain language, then shows the group means and the
# pairwise contrasts; for each interaction it gives the difference-of-differences
# reading and the inline cells / per-group slopes -- so the reader never has to
# add coefficients by hand or be told to "go call group_means()".
#
# It is a pure consumer of the symbolized_model: the coding scheme comes from
# `x$factor_coding`, the prose from `inst/extdata/factor-coding-templates.csv`,
# and the numbers from group_means() / group_contrasts() / group_slopes(). The
# same object backs the standalone `explain_factors()` entry point and the
# auto-section inside `explain()` / `model_card()`.
# ----------------------------------------------------------------------------

#' Explain a model's factors and dummy coding in one call
#'
#' @description
#' `explain_factors()` is the recommended entry point for understanding the
#' categorical predictors in a fit. For every factor it states, in plain
#' language, the coding scheme (its levels, which level is the reference, and
#' how many indicator columns it contributes), then shows the per-group means
#' ([`group_means()`]) and the pairwise comparisons ([`group_contrasts()`]).
#' For every interaction it gives the difference-of-differences reading together
#' with the inline cell means or per-group slopes.
#'
#' Pass a fitted model (it is run through [`symbolize()`] for you) or an existing
#' [`symbolized_model`][new_symbolized_model].
#'
#' Print the result at the console for a walkthrough, or knit it inside a Quarto
#' / R Markdown document for a heading-and-table section per factor.
#'
#' @param x A fitted model supported by [`symbolize()`], or a
#'   [`symbolized_model`][new_symbolized_model].
#' @param ... Passed to [`symbolize()`] when `x` is a fit.
#'
#' @return A `symbolized_factor_explanation` object.
#' @seealso [`group_means()`], [`group_contrasts()`], [`explain()`]
#' @examples
#' d <- transform(mtcars, gear = factor(gear))
#' if (requireNamespace("emmeans", quietly = TRUE)) {
#'   # one call: coding scheme, group means, and pairwise contrasts per factor
#'   explain_factors(lm(mpg ~ gear, data = d))
#' }
#' @export
explain_factors <- function(x, ...) {
  if (!inherits(x, "symbolized_model")) {
    x <- symbolize(x, ...)
  }
  new_symbolized_factor_explanation(x)
}

# Internal constructor. Pre-renders every per-factor and per-interaction piece
# by reuse (never recompute): coding overview from the template, means/contrasts
# from the emmeans wrappers (tryCatch-guarded so a missing emmeans degrades to
# the prose-only view).
new_symbolized_factor_explanation <- function(sym) {
  if (!inherits(sym, "symbolized_model")) {
    cli::cli_abort("{.arg sym} must be a {.cls symbolized_model}.")
  }
  fc <- sym$factor_coding
  has_factors <- !is.null(fc) && nrow(fc) > 0L
  factor_vars <- if (has_factors) fc$variable else character(0L)

  factors <- list()
  if (has_factors) {
    factors <- lapply(seq_len(nrow(fc)), function(i) {
      row <- fc[i, , drop = FALSE]
      v <- row$variable
      list(
        variable  = v,
        coding    = row,
        overview  = factor_overview_prose(row),
        means     = tryCatch(group_means(sym, by = v), error = function(e) NULL),
        contrasts = tryCatch(group_contrasts(sym, by = v), error = function(e) NULL)
      )
    })
  }

  interactions <- factor_interaction_pieces(sym, factor_vars)

  out <- list(
    model              = sym,
    has_factors        = has_factors,
    factors            = factors,
    interactions       = interactions,
    no_factors_message = factor_template_prose("no_factors_message", "any", list())
  )
  class(out) <- c("symbolized_factor_explanation", "list")
  out
}

# ---- templated prose -------------------------------------------------------

# Look up one prose row by (kind, contrast_type) with an "any" fallback, then
# substitute {slot} placeholders. All factor prose is CSV-sourced.
#' @keywords internal
factor_template_prose <- function(kind, contrast_type, slots) {
  tbl <- tryCatch(load_template("factor-coding-templates"),
                  error = function(e) NULL)
  if (is.null(tbl)) return("")
  hit <- tbl[tbl$template_kind == kind & tbl$contrast_type == contrast_type, ,
             drop = FALSE]
  if (nrow(hit) == 0L) {
    hit <- tbl[tbl$template_kind == kind & tbl$contrast_type == "any", ,
               drop = FALSE]
  }
  if (nrow(hit) == 0L) return("")
  prose <- hit$prose[[1L]]
  for (nm in names(slots)) {
    prose <- gsub(paste0("\\{", nm, "\\}"), slots[[nm]], prose)
  }
  prose
}

# Plain-language overview for one factor_coding row.
#' @keywords internal
factor_overview_prose <- function(coding_row) {
  lv <- coding_row$levels[[1L]]
  ref <- coding_row$reference_level
  factor_template_prose(
    "factor_overview", coding_row$contrast_type,
    list(
      variable        = coding_row$variable,
      k               = length(lv),
      levels          = paste(lv, collapse = ", "),
      reference_level = if (is.na(ref)) "(no single reference)" else ref,
      n_dummy         = coding_row$n_dummies
    )
  )
}

# A compact, one-line-per-factor overview reused by explain() / model_card().
# Returns a character vector (empty when the model has no factors).
#' @keywords internal
factor_overview_lines <- function(sym) {
  fc <- sym$factor_coding
  if (is.null(fc) || nrow(fc) == 0L) return(character(0L))
  vapply(seq_len(nrow(fc)),
         function(i) factor_overview_prose(fc[i, , drop = FALSE]),
         character(1L))
}

# ---- interactions ----------------------------------------------------------

# Build the per-interaction pieces: the overview reading plus the inline cells
# (factor x factor) or per-group slopes (continuous x factor).
#' @keywords internal
factor_interaction_pieces <- function(sym, factor_vars) {
  out <- list()
  terms_tbl <- sym$terms
  inter <- if (is.null(terms_tbl) || nrow(terms_tbl) == 0L) {
    character(0L)
  } else {
    unique(terms_tbl$variable[terms_tbl$role == "interaction" &
                                !is.na(terms_tbl$variable)])
  }
  for (term in inter) {
    pieces <- strsplit(term, ":", fixed = TRUE)[[1L]]
    is_f   <- pieces %in% factor_vars
    n_f    <- sum(is_f)
    if (n_f == 0L) {
      out[[length(out) + 1L]] <- list(
        term = term, type = "cont_cont",
        overview = factor_template_prose("interaction_overview", "cont_cont",
                                         list(cont_a = pieces[[1L]],
                                              cont_b = pieces[[2L]])),
        cells = NULL, slopes = NULL
      )
    } else if (n_f == length(pieces)) {
      out[[length(out) + 1L]] <- list(
        term = term, type = "factor_factor",
        overview = factor_template_prose("interaction_overview", "factor_factor",
                                         list(fac_a = pieces[[1L]],
                                              fac_b = pieces[[2L]])),
        cells = tryCatch(group_means(sym, by = pieces[is_f]),
                         error = function(e) NULL),
        slopes = NULL
      )
    } else {
      cont <- pieces[!is_f][[1L]]
      fac  <- pieces[is_f][[1L]]
      out[[length(out) + 1L]] <- list(
        term = term, type = "cont_factor",
        overview = factor_template_prose("interaction_overview", "cont_factor",
                                         list(cont = cont, fac = fac)),
        cells = NULL,
        slopes = tryCatch(group_slopes(sym, continuous = cont),
                          error = function(e) NULL)
      )
    }
  }
  # mgcv factor-by smooths: s(x, by = fac) is recorded in metadata$smooths
  # (one row per by-level) with `variable` (the smoothed predictor) and
  # `by_var` (the factor). Surface each (variable, by_var) pair once as a
  # smooth-by-factor entry -- the shape of the smooth differs across levels.
  sm <- sym$metadata$smooths
  if (!is.null(sm) && all(c("variable", "by_var") %in% names(sm))) {
    by_rows <- sm[!is.na(sm$by_var) & nzchar(sm$by_var), , drop = FALSE]
    if (nrow(by_rows) > 0L) {
      seen <- character(0L)
      for (i in seq_len(nrow(by_rows))) {
        cont <- by_rows$variable[[i]]
        fac  <- by_rows$by_var[[i]]
        key  <- paste0(cont, "", fac)
        if (key %in% seen) next
        seen <- c(seen, key)
        out[[length(out) + 1L]] <- list(
          term = sprintf("s(%s, by = %s)", cont, fac),
          type = "smooth_by_factor",
          overview = factor_template_prose("interaction_overview",
                                           "smooth_by_factor",
                                           list(cont = cont, fac = fac)),
          cells = NULL, slopes = NULL
        )
      }
    }
  }
  out
}

# ---- print -----------------------------------------------------------------

#' @export
print.symbolized_factor_explanation <- function(x, ...) {
  cls <- x$model$model$class %||% "model"
  cli::cli_h1("Factors in your <{cls}> model")
  if (!x$has_factors) {
    cli::cli_text(x$no_factors_message)
    return(invisible(x))
  }
  for (f in x$factors) {
    cli::cli_h2("{f$variable}")
    cli::cli_text(f$overview)
    if (!is.null(f$means)) {
      cli::cli_text("")
      print(f$means)
    }
    if (!is.null(f$contrasts)) {
      cli::cli_text("")
      print(f$contrasts)
    }
  }
  if (length(x$interactions) > 0L) {
    cli::cli_h2("Interactions")
    for (it in x$interactions) {
      cli::cli_text("{.strong {it$term}} -- {it$overview}")
      if (!is.null(it$cells)) print(it$cells)
      if (!is.null(it$slopes)) print(it$slopes)
    }
  }
  invisible(x)
}

#' @exportS3Method knitr::knit_print
knit_print.symbolized_factor_explanation <- function(x, ...) {
  if (!requireNamespace("knitr", quietly = TRUE)) {
    return(print(x))
  }
  kab <- function(tb) {
    if (is.null(tb) || nrow(tb) == 0L) return(NULL)
    paste(knitr::kable(as.data.frame(tb), format = "pipe"), collapse = "\n")
  }
  parts <- c("## Factors", "")
  if (!x$has_factors) {
    parts <- c(parts, x$no_factors_message)
    return(knitr::asis_output(paste(parts, collapse = "\n")))
  }
  for (f in x$factors) {
    parts <- c(parts, sprintf("### %s", f$variable), "", f$overview, "")
    km <- kab(f$means)
    if (!is.null(km)) parts <- c(parts, "**Group means**", "", km, "")
    kc <- kab(f$contrasts)
    if (!is.null(kc)) parts <- c(parts, "**Pairwise contrasts**", "", kc, "")
  }
  if (length(x$interactions) > 0L) {
    parts <- c(parts, "### Interactions", "")
    for (it in x$interactions) {
      parts <- c(parts, sprintf("**%s** -- %s", it$term, it$overview), "")
      kx <- kab(it$cells %||% it$slopes)
      if (!is.null(kx)) parts <- c(parts, kx, "")
    }
  }
  knitr::asis_output(paste(parts, collapse = "\n"))
}
