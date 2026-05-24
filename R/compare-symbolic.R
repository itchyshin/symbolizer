#' Structural comparison of two symbolized models
#'
#' @description
#' Compares two [`symbolized_model`][new_symbolized_model] objects and
#' returns a structured diff covering:
#'
#' - **meta** — class, family, response, and `n_obs` for each side.
#' - **submodels** — which submodels appear only on the left, only on the
#'   right, or on both sides.
#' - **terms** — within each shared submodel, which term labels appear only
#'   on one side or on both.
#' - **assumptions** — for each assumption, the statuses on each side and
#'   whether they match.
#'
#' Use it to ask questions like "what's different between this fit and the
#' previous one?" — a structural answer rather than a numeric one.
#' Coefficient values are not compared; this is the structural-symbolic
#' diff. For coefficient-level differences, use the
#' [parameter_interpretation()] tibbles directly.
#'
#' @param sym_a,sym_b Two `symbolized_model` objects.
#' @param ... Reserved for future use.
#'
#' @return A list classed `c("symbolic_comparison", "list")` with four
#'   slots: `meta` (list of left / right model summaries), `diff_submodels`
#'   (tibble), `diff_terms` (tibble), `diff_assumptions` (tibble).
#'
#' @export
compare_symbolic <- function(sym_a, sym_b, ...) {
  UseMethod("compare_symbolic")
}

#' @export
compare_symbolic.default <- function(sym_a, sym_b, ...) {
  cli::cli_abort(c(
    "{.fn compare_symbolic} has no method for {.cls {class(sym_a)[1L]}}.",
    i = "Pass two outputs of {.fn symbolize}."
  ))
}

#' @export
compare_symbolic.symbolized_model <- function(sym_a, sym_b, ...) {
  if (!inherits(sym_b, "symbolized_model")) {
    cli::cli_abort(c(
      "{.arg sym_b} must also be a {.cls symbolized_model}.",
      i = "Got {.cls {class(sym_b)[1L]}}."
    ))
  }
  meta <- list(
    left  = comparison_meta(sym_a),
    right = comparison_meta(sym_b)
  )
  out <- list(
    meta             = meta,
    diff_submodels   = diff_submodels(sym_a, sym_b),
    diff_terms       = diff_terms(sym_a, sym_b),
    diff_assumptions = diff_assumptions(sym_a, sym_b)
  )
  class(out) <- c("symbolic_comparison", "list")
  out
}

# -- internal helpers --------------------------------------------------------

# Pull the small model summary that goes into meta.
comparison_meta <- function(sym) {
  m <- sym$model
  list(
    class    = m$class    %||% NA_character_,
    package  = m$package  %||% NA_character_,
    family   = m$family   %||% NA_character_,
    response = m$response %||% NA_character_,
    n_obs    = m$n_obs    %||% NA_integer_
  )
}

# Diff the submodel sets. Returns a tibble with one row per submodel name.
diff_submodels <- function(sym_a, sym_b) {
  left  <- if (is.null(sym_a$submodels$parameter)) character(0) else sym_a$submodels$parameter
  right <- if (is.null(sym_b$submodels$parameter)) character(0) else sym_b$submodels$parameter
  classify_presence(unique(c(left, right)), left, right, key_name = "submodel")
}

# Diff the term sets per shared submodel. Returns a tibble with one row per
# (submodel, term_label) pair from either side.
diff_terms <- function(sym_a, sym_b) {
  rows <- list()
  submodels_in_a <- if (is.null(sym_a$terms$submodel)) character(0) else sym_a$terms$submodel
  submodels_in_b <- if (is.null(sym_b$terms$submodel)) character(0) else sym_b$terms$submodel
  all_sub <- unique(c(submodels_in_a, submodels_in_b))
  for (sm in all_sub) {
    left  <- if (sm %in% submodels_in_a) {
      sym_a$terms$term_label[sym_a$terms$submodel == sm]
    } else character(0)
    right <- if (sm %in% submodels_in_b) {
      sym_b$terms$term_label[sym_b$terms$submodel == sm]
    } else character(0)
    sub_rows <- classify_presence(
      unique(c(left, right)), left, right, key_name = "term_label"
    )
    if (nrow(sub_rows) > 0L) {
      sub_rows$submodel <- sm
      sub_rows <- sub_rows[, c("submodel", "term_label", "presence"), drop = FALSE]
      rows[[length(rows) + 1L]] <- sub_rows
    }
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(submodel = character(0),
                          term_label = character(0),
                          presence = character(0)))
  }
  do.call(rbind, rows)
}

# Diff the assumption set. Returns one row per distinct assumption name with
# the status on each side and a logical same_status column.
diff_assumptions <- function(sym_a, sym_b) {
  left_names  <- if (is.null(sym_a$assumptions$assumption)) character(0) else sym_a$assumptions$assumption
  right_names <- if (is.null(sym_b$assumptions$assumption)) character(0) else sym_b$assumptions$assumption
  all_names <- unique(c(left_names, right_names))
  if (length(all_names) == 0L) {
    return(tibble::tibble(assumption = character(0),
                          left_status = character(0),
                          right_status = character(0),
                          same_status = logical(0)))
  }
  status_for <- function(sym, name) {
    if (is.null(sym$assumptions$assumption)) return(NA_character_)
    sel <- sym$assumptions$assumption == name
    if (!any(sel)) NA_character_ else sym$assumptions$status[which(sel)[1L]]
  }
  left_status  <- vapply(all_names, status_for, character(1L), sym = sym_a)
  right_status <- vapply(all_names, status_for, character(1L), sym = sym_b)
  tibble::tibble(
    assumption   = all_names,
    left_status  = left_status,
    right_status = right_status,
    same_status  = !is.na(left_status) & !is.na(right_status) &
                   left_status == right_status
  )
}

# Shared helper: given a sorted-ish universe of keys plus the left / right
# vectors, build a tibble with one row per key and a `presence` column whose
# value is one of "left_only", "right_only", "both".
classify_presence <- function(keys, left, right, key_name) {
  if (length(keys) == 0L) {
    out <- tibble::tibble(x = character(0), presence = character(0))
    names(out)[1L] <- key_name
    return(out)
  }
  in_left  <- keys %in% left
  in_right <- keys %in% right
  presence <- ifelse(
    in_left & in_right,  "both",
    ifelse(in_left,      "left_only",
           ifelse(in_right, "right_only", NA_character_))
  )
  out <- tibble::tibble(x = keys, presence = presence)
  names(out)[1L] <- key_name
  out
}

# -- print + knit_print methods ---------------------------------------------

#' @export
print.symbolic_comparison <- function(x, ...) {
  cli::cli_h1("Symbolic comparison")
  # meta
  cli::cli_h3("Model summaries")
  ml <- x$meta$left
  mr <- x$meta$right
  cli::cli_text("{.strong left:}  {ml$class} / {ml$family} / response {.field {ml$response}} / n = {.val {ml$n_obs}}")
  cli::cli_text("{.strong right:} {mr$class} / {mr$family} / response {.field {mr$response}} / n = {.val {mr$n_obs}}")

  # submodels
  cli::cli_h3("Submodels")
  print_presence_block(x$diff_submodels, key = "submodel")

  # terms
  cli::cli_h3("Terms")
  if (nrow(x$diff_terms) == 0L) {
    cli::cli_text("{.emph (no terms)}")
  } else {
    for (sm in unique(x$diff_terms$submodel)) {
      cli::cli_text("{.strong {sm}}:")
      sub <- x$diff_terms[x$diff_terms$submodel == sm, , drop = FALSE]
      print_presence_block(sub, key = "term_label", indent = "  ")
    }
  }

  # assumptions
  cli::cli_h3("Assumptions")
  if (nrow(x$diff_assumptions) == 0L) {
    cli::cli_text("{.emph (no assumptions)}")
  } else {
    n_diff <- sum(!x$diff_assumptions$same_status)
    cli::cli_text(
      "{.val {nrow(x$diff_assumptions)}} assumption{?s}; ",
      "{.val {n_diff}} differ{?s/} in status."
    )
    for (i in seq_len(nrow(x$diff_assumptions))) {
      a  <- x$diff_assumptions$assumption[[i]]
      ls <- x$diff_assumptions$left_status[[i]]
      rs <- x$diff_assumptions$right_status[[i]]
      marker <- if (isTRUE(x$diff_assumptions$same_status[[i]])) "" else " *"
      cli::cli_text("  {.field {a}}: left = {.val {ls}}; right = {.val {rs}}{marker}")
    }
  }
  invisible(x)
}

# Helper for the print method: list values by presence bucket.
print_presence_block <- function(df, key, indent = "") {
  if (nrow(df) == 0L) {
    cli::cli_text("{indent}{.emph (none)}")
    return(invisible(NULL))
  }
  for (p in c("left_only", "right_only", "both")) {
    sel <- df$presence == p
    if (any(sel)) {
      vals <- df[[key]][sel]
      label <- switch(
        p,
        left_only  = "left only",
        right_only = "right only",
        both       = "both"
      )
      cli::cli_text("{indent}{label}: {.field {vals}}")
    }
  }
  invisible(NULL)
}

#' @exportS3Method knitr::knit_print
knit_print.symbolic_comparison <- function(x, ...) {
  if (!requireNamespace("knitr", quietly = TRUE)) return(invisible(x))

  # meta table
  ml <- x$meta$left
  mr <- x$meta$right
  meta_df <- data.frame(
    field = c("class", "family", "response", "n_obs"),
    left  = c(ml$class, ml$family, ml$response, format(ml$n_obs)),
    right = c(mr$class, mr$family, mr$response, format(mr$n_obs)),
    stringsAsFactors = FALSE
  )
  meta_md <- knitr::kable(meta_df, format = "pipe",
                          col.names = c("", "left", "right"))

  # submodels table
  sm_md <- if (nrow(x$diff_submodels) > 0L) {
    knitr::kable(x$diff_submodels, format = "pipe")
  } else "*(no submodels)*"

  # terms table
  tm_md <- if (nrow(x$diff_terms) > 0L) {
    knitr::kable(x$diff_terms, format = "pipe")
  } else "*(no terms)*"

  # assumptions table
  as_md <- if (nrow(x$diff_assumptions) > 0L) {
    knitr::kable(x$diff_assumptions, format = "pipe")
  } else "*(no assumptions)*"

  out <- paste(
    c("",
      "**Model summaries**", "", meta_md, "",
      "**Submodels**", "", sm_md, "",
      "**Terms**", "", tm_md, "",
      "**Assumptions**", "", as_md, ""),
    collapse = "\n"
  )
  knitr::asis_output(out)
}
