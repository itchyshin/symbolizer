# ----------------------------------------------------------------------------
# warnings.R
#
# Per-fit prose warnings. Each `symbolize()` extractor runs a battery of
# checks; matching checks add rows to `sym$warnings_registry`, a tibble
# with one row per fired warning. The accessor `warning_table(sym)`
# returns the tibble with a print method; `model_card(sym)` surfaces it
# in the teaching bundle.
#
# The prose is templated from `inst/extdata/warning-templates.csv` so
# every message traces to a CSV row + substituted slots — no LLM prose
# at runtime.
# ----------------------------------------------------------------------------

# Build the warnings tibble for a drmTMB fit. Returns a tibble with the
# canonical column shape:
#   code (chr) | severity (chr) | message (chr) | context (chr)
#
# severity is one of "info", "warn", "error" (today only "info" and "warn"
# fire). Conditions wrapped in tryCatch so a mis-built fit can't break
# symbolize().
drm_build_warnings <- function(fit, sym_partial) {
  tbl <- tryCatch(load_template("warning-templates"),
                  error = function(e) NULL)
  if (is.null(tbl)) return(warnings_empty())
  rows <- list()
  # Few-groups + Wald: only fires when ci_method is "wald" AND there's a
  # random effect on a grouping variable with < 10 levels.
  ci_method <- sym_partial$metadata$ci_method %||% "wald"
  if (identical(ci_method, "wald") &&
      !is.null(sym_partial$random_effects) &&
      nrow(sym_partial$random_effects) > 0L) {
    re <- sym_partial$random_effects
    for (i in seq_len(nrow(re))) {
      n_lev <- re$n_levels[[i]]
      gv    <- re$group_var[[i]]
      if (is.na(n_lev) || is.na(gv)) next
      if (n_lev < 10L) {
        rows[[length(rows) + 1L]] <- warnings_render(
          tbl, code = "few_groups_wald",
          slots = list(group_name = gv, n_groups = format(n_lev))
        )
      }
    }
  }
  if (length(rows) == 0L) return(warnings_empty())
  do.call(rbind, rows)
}

# Helper: build one warning row by template substitution.
warnings_render <- function(tbl, code, slots) {
  hit <- tbl[tbl$code == code, , drop = FALSE]
  if (nrow(hit) == 0L) {
    return(tibble::tibble(
      code     = code,
      severity = "warn",
      message  = paste0("(no template for warning code '", code, "')"),
      context  = ""
    ))
  }
  msg <- hit$template[[1L]]
  for (nm in names(slots)) {
    msg <- gsub(paste0("\\{", nm, "\\}"), slots[[nm]], msg, fixed = FALSE)
  }
  context <- paste(
    vapply(names(slots), function(nm) sprintf("%s = %s", nm, slots[[nm]]),
           character(1L)),
    collapse = "; "
  )
  tibble::tibble(
    code     = code,
    severity = hit$severity[[1L]],
    message  = msg,
    context  = context
  )
}

warnings_empty <- function() {
  tibble::tibble(
    code     = character(0L),
    severity = character(0L),
    message  = character(0L),
    context  = character(0L)
  )
}

# Coerce any warnings tibble to the canonical 4-column shape. Some extractors
# (base lm / glm) seed an empty 3-column registry without `context`; normalising
# lets coding warnings rbind onto it cleanly.
normalize_warnings <- function(w) {
  if (is.null(w)) return(warnings_empty())
  if (!"context" %in% names(w)) w$context <- rep("", nrow(w))
  w[, c("code", "severity", "message", "context"), drop = FALSE]
}

merge_warnings <- function(existing, extra) {
  base <- normalize_warnings(existing)
  if (is.null(extra) || nrow(extra) == 0L) return(base)
  rbind(base, normalize_warnings(extra))
}

# Detect-and-warn for non-default factor coding. A factor needs a warning when
# its contrast scheme is not the default treatment coding (sum / Helmert / poly
# / custom, or treatment with a non-first base) -- the coefficient table and the
# `[reference]` tag assume treatment coding and would otherwise mislead.
# Cell-means (`0 + factor`) is exempt: it is read correctly as group means.
#' @keywords internal
coding_warnings <- function(factor_coding) {
  if (is.null(factor_coding) || nrow(factor_coding) == 0L) {
    return(warnings_empty())
  }
  tbl <- tryCatch(load_template("warning-templates"), error = function(e) NULL)
  if (is.null(tbl)) return(warnings_empty())
  flag <- !factor_coding$is_default_treatment &
    factor_coding$contrast_type != "cell_means"
  idx <- which(flag)
  if (length(idx) == 0L) return(warnings_empty())
  rows <- lapply(idx, function(i) {
    warnings_render(
      tbl, code = "non_default_contrasts",
      slots = list(
        factor_name   = factor_coding$variable[[i]],
        contrast_type = factor_coding$contrast_type[[i]]
      )
    )
  })
  do.call(rbind, rows)
}

# -- accessor ----------------------------------------------------------------

#' Per-fit prose warnings for a symbolized model
#'
#' @description
#' Returns the tibble of conditions `symbolize()` flagged when it built
#' the model object. Each row is one warning with a `code` (machine
#' identifier), a `severity` (`info` / `warn` / `error`), a `message` (the
#' prose templated from `inst/extdata/warning-templates.csv`), and a
#' `context` string naming which slot values triggered the rule.
#'
#' Today the system ships two checks:
#'
#' * `few_groups_wald` *(warn)* — Wald 95% CI used with a random-effect
#'   group of fewer than ~10 levels.
#' * `small_n_wald` *(info)* — Wald CI on a small dataset. Currently
#'   defined in the template CSV but reserved; no extractor fires it yet
#'   (the threshold is fit-dependent and not always informative).
#'
#' New conditions are added by appending a row to
#' `inst/extdata/warning-templates.csv` and wiring the trigger in the
#' relevant `drm_build_warnings()` (or sibling for other classes).
#'
#' @param x A [`symbolized_model`][new_symbolized_model].
#' @param ... Reserved for future use.
#'
#' @return A tibble (S3 class `symbolizer_warning_table`) with columns
#'   `code`, `severity`, `message`, `context`.
#'
#' @export
warning_table <- function(x, ...) {
  UseMethod("warning_table")
}

#' @export
warning_table.default <- function(x, ...) {
  cli::cli_abort(c(
    "{.fn warning_table} has no method for {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
warning_table.symbolized_model <- function(x, ...) {
  out <- x$warnings_registry
  if (is.null(out)) out <- warnings_empty()
  class(out) <- c("symbolizer_warning_table", class(out))
  out
}

#' @export
print.symbolizer_warning_table <- function(x, ...) {
  if (nrow(x) == 0L) {
    cli::cli_text("{.emph No warnings flagged.}")
    return(invisible(x))
  }
  cli::cli_h2("Warnings ({nrow(x)})")
  for (i in seq_len(nrow(x))) {
    sev <- x$severity[[i]]
    msg <- x$message[[i]]
    switch(sev,
      info  = cli::cli_alert_info(msg),
      warn  = cli::cli_alert_warning(msg),
      error = cli::cli_alert_danger(msg),
      cli::cli_alert(msg)
    )
  }
  invisible(x)
}

#' @exportS3Method knitr::knit_print
knit_print.symbolizer_warning_table <- function(x, ...) {
  if (!requireNamespace("knitr", quietly = TRUE)) return(invisible(x))
  if (nrow(x) == 0L) {
    return(knitr::asis_output("\n*No warnings flagged.*\n"))
  }
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  df <- df[, c("severity", "message", "context"), drop = FALSE]
  kab <- knitr::kable(df, format = "pipe",
                      col.names = c("severity", "message", "context"))
  knitr::asis_output(paste(c("", kab, ""), collapse = "\n"))
}
