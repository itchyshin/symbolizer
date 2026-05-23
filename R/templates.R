## Package-level cache of loaded template CSVs.
## Bound at package load time; reset on detach.
.symbolizer_template_cache <- new.env(parent = emptyenv())

#' Load a template CSV from inst/extdata
#'
#' Internal helper. Loads a CSV file from the installed `inst/extdata/`
#' directory. Caches per session in `.symbolizer_template_cache`.
#'
#' @param name File name without extension, e.g. `"interpretation-templates"`.
#'
#' @return A tibble.
#' @keywords internal
load_template <- function(name) {
  if (exists(name, envir = .symbolizer_template_cache, inherits = FALSE)) {
    return(get(name, envir = .symbolizer_template_cache, inherits = FALSE))
  }
  path <- system.file("extdata", paste0(name, ".csv"), package = "symbolizer")
  if (!nzchar(path)) {
    cli::cli_abort(c(
      "Template {.file {paste0(name, '.csv')}} not found in installed extdata.",
      i = "If running with {.fn devtools::load_all}, check {.file inst/extdata/}."
    ))
  }
  out <- tibble::as_tibble(utils::read.csv(
    path, stringsAsFactors = FALSE, na.strings = c("", "NA")
  ))
  assign(name, out, envir = .symbolizer_template_cache)
  out
}

#' Clear the template cache
#'
#' Internal helper. Useful in tests that modify templates between calls.
#' @keywords internal
clear_template_cache <- function() {
  rm(list = ls(envir = .symbolizer_template_cache),
     envir = .symbolizer_template_cache)
  invisible()
}
