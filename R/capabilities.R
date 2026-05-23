#' Symbolizer capability registry
#'
#' Returns the table of model classes, families, and components that
#' `symbolize()` knows about, together with their status. Use this to discover
#' what is currently supported and what is on the roadmap.
#'
#' Status words follow drmTMB's five-level vocabulary:
#'
#' - **Stable**: routine path with tests, diagnostics, and a reader-facing example.
#' - **First slice**: fitted and tested, but intentionally narrow.
#' - **Opt-in control**: available for hardening, not a general modelling guarantee.
#' - **Planned or reserved**: public grammar may exist, but `symbolize()` rejects it.
#' - **Unsupported or blocked**: do not use as analysis syntax.
#'
#' @return A tibble with columns `class`, `family`, `component`, `status`,
#'   `since`, `notes`.
#' @export
#' @examples
#' symbolizer_capabilities()
symbolizer_capabilities <- function() {
  load_template("capabilities")
}

#' Check whether a (class, family, component) tuple is supported
#'
#' Internal gate used by `symbolize()` methods. Errors via [`cli::cli_abort()`]
#' if the status is **Planned or reserved** or **Unsupported or blocked**.
#'
#' Wildcards: a row with value `"*"` in `class`, `family`, or `component`
#' matches any value in that slot.
#'
#' When the check fails, the error message also lists the currently-readable
#' tuples (status: Stable or First slice) so the user immediately sees what
#' they *can* do today.
#'
#' @param class Character. Fitted-object class.
#' @param family Character. Family name.
#' @param component Character. Component name.
#'
#' @return Invisibly returns the matched row's status word.
#' @keywords internal
capability_check <- function(class, family, component) {
  tbl <- symbolizer_capabilities()
  matches <- (tbl$class == class | tbl$class == "*") &
    (tbl$family == family | tbl$family == "*") &
    (tbl$component == component | tbl$component == "*")
  row <- tbl[matches, , drop = FALSE]
  if (nrow(row) == 0L) {
    cli::cli_abort(c(
      "No capability entry for class {.val {class}} / family {.val {family}} / component {.val {component}}.",
      i = "Add a row to {.file inst/extdata/capabilities.csv} before exporting a method."
    ))
  }
  # Prefer the most specific row (no wildcards) if multiple match
  specificity <- (row$class != "*") + (row$family != "*") + (row$component != "*")
  row <- row[order(-specificity), , drop = FALSE]
  status <- row$status[[1L]]
  if (status %in% c("Planned or reserved", "Unsupported or blocked")) {
    today_lines <- capability_today_bullets(tbl)
    cli::cli_abort(c(
      "{.fn symbolize} cannot read {class} / {family} / {component} yet (status: {status}).",
      i = "Today we can read:",
      today_lines,
      i = "See {.fn symbolizer_capabilities} for the full registry."
    ))
  }
  invisible(status)
}

# Build the cli bullet lines that summarise the currently-readable
# `(class, family, component)` tuples. Includes Stable and First slice rows
# only. Grouped by class, sorted by class then status (Stable first).
capability_today_bullets <- function(tbl) {
  ok <- tbl[tbl$status %in% c("Stable", "First slice"), , drop = FALSE]
  if (nrow(ok) == 0L) {
    return(c("*" = "(no readable tuples registered)"))
  }
  # Sort case-insensitively (tolower) so the ordering is locale-independent
  # and matches the convention used on case-insensitive collations (en_*).
  ok <- ok[order(tolower(ok$class),
                 factor(ok$status, levels = c("Stable", "First slice")),
                 tolower(ok$family),
                 tolower(ok$component)), , drop = FALSE]
  # Collapse rows with the same (class, status, family) but differing
  # components into one bullet so the message stays compact.
  key <- paste(ok$class, ok$status, ok$family, sep = "\r")
  out <- character(0)
  for (k in unique(key)) {
    rows <- ok[key == k, , drop = FALSE]
    cls <- rows$class[[1L]]
    fam <- rows$family[[1L]]
    stat <- rows$status[[1L]]
    comps <- paste(rows$component, collapse = ", ")
    out <- c(out, sprintf("%s %s: %s (%s)", cls, fam, comps, stat))
  }
  stats::setNames(out, rep("*", length(out)))
}
