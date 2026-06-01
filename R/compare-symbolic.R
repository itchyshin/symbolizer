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
#' - **metrics** *(optional, when `metrics = TRUE`)* — AIC, BIC, log-
#'   likelihood, and residual degrees of freedom on each side plus their
#'   delta. The metrics block refuses to compute deltas when the two fits
#'   are obviously incomparable (different family, different response,
#'   different `n_obs`) and instead carries a `note` column explaining
#'   why.
#'
#' Use it to ask questions like "what's different between this fit and the
#' previous one?" — a structural answer rather than a numeric one.
#' Coefficient values are not compared; this is the structural-symbolic
#' diff. For coefficient-level differences, use the
#' [parameter_interpretation()] tibbles directly. For fit-level
#' identifiability and convergence diagnostics, run `drmTMB::check_drm()`
#' (or the analogous diagnostic for `gllvmTMB`) on each fit before
#' interpreting the structural diff.
#'
#' @param sym_a,sym_b Two `symbolized_model` objects.
#' @param metrics Logical, default `FALSE`. When `TRUE`, joins the AIC /
#'   BIC / log-likelihood / df from each side as a fifth slot
#'   `diff_metrics` and adds a `delta` column. Requires that each side
#'   carries its fit object on `metadata$fit` (this is the default for
#'   `symbolize.drmTMB()` and `symbolize.gllvmTMB()`).
#' @param ... Reserved for future use.
#'
#' @return A list classed `c("symbolic_comparison", "list")` with four
#'   slots (`meta`, `diff_submodels`, `diff_terms`, `diff_assumptions`),
#'   plus a fifth `diff_metrics` slot when `metrics = TRUE`.
#'
#' @examples
#' # a <- symbolize(lm(mpg ~ wt, data = mtcars))
#' # b <- symbolize(lm(mpg ~ wt + hp, data = mtcars))
#' # compare_symbolic(a, b)
#' @export
compare_symbolic <- function(sym_a, sym_b, metrics = FALSE, ...) {
  UseMethod("compare_symbolic")
}

#' @export
compare_symbolic.default <- function(sym_a, sym_b, metrics = FALSE, ...) {
  cli::cli_abort(c(
    "{.fn compare_symbolic} has no method for {.cls {class(sym_a)[1L]}}.",
    i = "Pass two outputs of {.fn symbolize}."
  ))
}

#' @export
compare_symbolic.symbolized_model <- function(sym_a, sym_b,
                                              metrics = FALSE, ...) {
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
  if (isTRUE(metrics)) {
    out$diff_metrics <- diff_metrics(sym_a, sym_b)
  }
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

# Compute AIC / BIC / logLik / df for each side. When the two fits are
# obviously incomparable on the same likelihood scale (different family,
# response, or n_obs) the function refuses to compute deltas and stores a
# `comparable` attribute = FALSE plus a `note` attribute explaining why.
diff_metrics <- function(sym_a, sym_b) {
  comp_note <- check_metric_comparability(sym_a, sym_b)
  comparable <- is.na(comp_note)
  m_a <- safe_fit_metrics(sym_a$metadata$fit)
  m_b <- safe_fit_metrics(sym_b$metadata$fit)
  out <- tibble::tibble(
    metric = c("AIC", "BIC", "logLik", "df"),
    left   = c(m_a$AIC, m_a$BIC, m_a$logLik, m_a$df),
    right  = c(m_b$AIC, m_b$BIC, m_b$logLik, m_b$df)
  )
  if (comparable) {
    out$delta <- out$right - out$left
  } else {
    out$delta <- NA_real_
  }
  attr(out, "comparable") <- comparable
  attr(out, "note")       <- comp_note
  out
}

# Same family + response + n_obs is the strict ML comparison criterion;
# returns NA_character_ when comparable, an explanatory string otherwise.
check_metric_comparability <- function(sym_a, sym_b) {
  ml <- sym_a$model
  mr <- sym_b$model
  if (!identical(ml$n_obs, mr$n_obs)) {
    return(sprintf(
      "incomparable: n_obs differs (left = %s, right = %s)",
      format(ml$n_obs %||% NA), format(mr$n_obs %||% NA)
    ))
  }
  if (!identical(ml$family, mr$family)) {
    return(sprintf(
      "incomparable: family differs (left = %s, right = %s)",
      ml$family %||% NA_character_, mr$family %||% NA_character_
    ))
  }
  if (!identical(ml$response, mr$response)) {
    return(sprintf(
      "incomparable: response differs (left = %s, right = %s)",
      ml$response %||% NA_character_, mr$response %||% NA_character_
    ))
  }
  NA_character_
}

# Extract AIC / BIC / logLik / df from a fit; on missing fit or error,
# return NA so the function never breaks the structural diff.
safe_fit_metrics <- function(fit) {
  na_result <- list(AIC = NA_real_, BIC = NA_real_,
                    logLik = NA_real_, df = NA_real_)
  if (is.null(fit)) return(na_result)
  tryCatch({
    aic_v <- stats::AIC(fit)
    bic_v <- stats::BIC(fit)
    ll    <- stats::logLik(fit)
    df_v  <- attr(ll, "df")
    list(
      AIC    = as.numeric(aic_v),
      BIC    = as.numeric(bic_v),
      logLik = as.numeric(ll),
      df     = as.numeric(df_v)
    )
  }, error = function(e) na_result)
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

  # metrics (only when compare_symbolic was called with metrics = TRUE)
  if (!is.null(x$diff_metrics)) {
    cli::cli_h3("Metrics")
    comp <- attr(x$diff_metrics, "comparable")
    note <- attr(x$diff_metrics, "note")
    if (!isTRUE(comp)) {
      cli::cli_text("{.emph deltas not computed:} {note}")
    }
    fmt <- function(v) if (is.na(v)) "NA" else
                       formatC(v, digits = 4L, format = "fg", flag = "#")
    for (i in seq_len(nrow(x$diff_metrics))) {
      m <- x$diff_metrics$metric[[i]]
      l <- x$diff_metrics$left[[i]]
      r <- x$diff_metrics$right[[i]]
      d <- x$diff_metrics$delta[[i]]
      if (is.na(d)) {
        cli::cli_text("  {.field {m}}: left = {fmt(l)}; right = {fmt(r)}")
      } else {
        sign <- if (d >= 0) "+" else ""
        cli::cli_text(
          "  {.field {m}}: left = {fmt(l)}; right = {fmt(r)} (",
          "{.strong delta = {sign}{fmt(d)}})"
        )
      }
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

  # metrics table (optional)
  metrics_block <- character(0)
  if (!is.null(x$diff_metrics)) {
    comp <- attr(x$diff_metrics, "comparable")
    note <- attr(x$diff_metrics, "note")
    fmt <- function(v) if (is.na(v)) "NA" else
                       formatC(v, digits = 4L, format = "fg", flag = "#")
    df_show <- data.frame(
      metric = x$diff_metrics$metric,
      left   = vapply(x$diff_metrics$left,  fmt, character(1L)),
      right  = vapply(x$diff_metrics$right, fmt, character(1L)),
      delta  = vapply(x$diff_metrics$delta, fmt, character(1L)),
      stringsAsFactors = FALSE
    )
    metric_md <- knitr::kable(df_show, format = "pipe")
    footer <- if (isTRUE(comp)) {
      "*delta = right - left*"
    } else {
      paste0("*Deltas not computed: ", note, "*")
    }
    metrics_block <- c("**Metrics**", "", metric_md, "", footer, "")
  }

  out <- paste(
    c("",
      "**Model summaries**", "", meta_md, "",
      "**Submodels**", "", sm_md, "",
      "**Terms**", "", tm_md, "",
      "**Assumptions**", "", as_md, "",
      metrics_block),
    collapse = "\n"
  )
  knitr::asis_output(out)
}
