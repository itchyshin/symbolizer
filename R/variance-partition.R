# ----------------------------------------------------------------------------
# variance-partition.R
#
# Two accessors that turn a fitted mixed model's variance components into the
# questions a biologist actually asks of a mixed model:
#   * variance_partition(x) -- "where does the variation live?"
#   * icc(x)                -- "how repeatable is the trait?" (intraclass
#                              correlation / repeatability)
#
# Both take a `symbolized_model`, read the numeric variance components carried
# on `x$variance_components` (populated by every mixed-model extractor; drmTMB
# gained numbers in S1), and pull the carried fit from `x$metadata$fit` for the
# residual variance. They return classed honest-print objects. All reader-facing
# prose is templated from inst/extdata/variance-readings.csv -- no string-spliced
# prose in R (architectural rule).
#
# Honesty contract (docs/specs/variance-components.md):
#  * Gaussian-identity, single random intercept -> data-scale ICC, a true
#    proportion of variance.
#  * Binomial logit -> latent-scale ICC with residual pi^2/3; probit -> 1.
#    Labelled "latent scale"; carries the "not observed-outcome variance"
#    caption.
#  * Any other family, a location-scale Gaussian whose residual SD varies, or
#    more than one random-effect term -> NA with a reason. Point estimates only.
#
# The residual is ALWAYS recomputed from the fit, family-aware, and any residual
# row already present in `x$variance_components` (lme4 / glmmTMB carry one;
# drmTMB does not) is dropped first so it is never double-counted. For a
# homoscedastic Gaussian fit `stats::sigma(fit)` reproduces the dropped lme4
# residual exactly, so the two paths agree.
# ----------------------------------------------------------------------------

# ---- prose ------------------------------------------------------------------

# Look up a reader-facing sentence from inst/extdata/variance-readings.csv.
# `...` are {placeholder} = value substitutions (fixed-string gsub), matching
# the templating convention used elsewhere in the package. Returns "" when the
# key is absent so a caller never crashes on a missing row.
variance_reading <- function(key, ...) {
  tbl <- tryCatch(load_template("variance-readings"), error = function(e) NULL)
  if (is.null(tbl) || !all(c("key", "text") %in% names(tbl))) return("")
  hit <- tbl[tbl$key == key, , drop = FALSE]
  if (nrow(hit) == 0L) return("")
  txt <- hit$text[[1L]]
  if (is.na(txt)) return("")
  subs <- list(...)
  for (nm in names(subs)) {
    txt <- gsub(paste0("{", nm, "}"), as.character(subs[[nm]]), txt, fixed = TRUE)
  }
  txt
}

# ---- variance_partition() ---------------------------------------------------

#' Where the variation lives: a variance partition for a mixed model
#'
#' @description
#' `variance_partition()` turns a fitted mixed model's variance components into
#' a one-row-per-source table: each random-effect variance plus, when it is
#' defined, the residual (within-group) variance. The `pct` column is each
#' source's share of the total, answering a biologist's first question of a
#' mixed model -- *where does the variation live?*
#'
#' The residual row (and therefore `pct`) appears only when the residual
#' variance is defined on a single scale: a homoscedastic Gaussian fit (one
#' residual SD) or a binomial fit (the known latent-scale residual,
#' \eqn{\pi^2/3} for logit, 1 for probit). For other families, or a
#' location-scale Gaussian whose residual SD varies across observations, the
#' random-effect variances are still shown but `pct` is `NA` with a reason --
#' shares of a total are not meaningful without a residual.
#'
#' Point estimates only; no confidence intervals (the package's uncertainty
#' contract).
#'
#' @param x A [`symbolized_model`][new_symbolized_model] whose underlying fit
#'   is retained on `x$metadata$fit`.
#' @param ... Reserved for future use.
#'
#' @return A tibble (S3 class `symbolizer_variance_partition`) with one row per
#'   variance source. Columns: `component`, `variance`, `sd`, `pct`. Carries a
#'   `reason` attribute (character or `NA`) explaining an all-`NA` `pct`.
#' @seealso [icc()] for the single-number intraclass correlation.
#' @examples
#' # variance_partition(symbolize(lme4::lmer(Reaction ~ Days + (1 | Subject),
#' #                                         data = lme4::sleepstudy)))
#' @export
variance_partition <- function(x, ...) {
  UseMethod("variance_partition")
}

#' @export
variance_partition.default <- function(x, ...) {
  cli::cli_abort(c(
    "{.fn variance_partition} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
variance_partition.symbolized_model <- function(x, ...) {
  re <- vc_re_rows(x$variance_components)
  if (is.null(re)) {
    re <- tibble::tibble(component = character(0L),
                         variance = numeric(0L), sd = numeric(0L))
  }
  resid <- vc_residual_variance(x)
  reason <- NA_character_
  rows <- re
  if (is.finite(resid$value)) {
    lbl <- if (identical(resid$scale, "latent")) {
      "Residual (latent scale)"
    } else {
      "Residual (within-group)"
    }
    rows <- tibble::add_row(re, component = lbl,
                            variance = resid$value, sd = sqrt(resid$value))
  } else {
    reason <- resid$reason
  }
  total <- sum(rows$variance, na.rm = TRUE)
  rows$pct <- if (is.finite(resid$value) && total > 0) {
    rows$variance / total
  } else {
    rep(NA_real_, nrow(rows))
  }
  vc_new_partition(rows, reason = reason)
}

# ---- icc() ------------------------------------------------------------------

#' Intraclass correlation (repeatability) for a mixed model
#'
#' @description
#' `icc()` returns the intraclass correlation -- the proportion of variance
#' that lies between groups -- for a mixed model with a single random-effect
#' term. For a biologist this is the *repeatability* of the trait.
#'
#' The returned value carries a `scale` attribute that is essential to its
#' interpretation:
#'
#' * **data scale** (`scale = "data"`): a Gaussian-identity fit with one
#'   random intercept. \eqn{\sigma^2_g / (\sigma^2_g + \sigma^2_\varepsilon)}
#'   is a genuine proportion of variance in the observed response.
#' * **latent scale** (`scale = "latent"`): a binomial fit, where the residual
#'   is the known link-scale constant (\eqn{\pi^2/3} for logit, 1 for probit).
#'   This is repeatability on the latent (link) scale and is **not** a
#'   proportion of variance in the observed 0/1 outcome -- the returned object
#'   carries that caption.
#'
#' When the quantity is not defined -- another family, a location-scale
#' Gaussian whose residual SD varies, or more than one random-effect term --
#' `icc()` returns `NA` with a human-readable `reason` attribute rather than a
#' misleading number. Use [variance_partition()] to see the full breakdown in
#' those cases. Point estimate only; no confidence interval.
#'
#' @param x A [`symbolized_model`][new_symbolized_model] whose underlying fit
#'   is retained on `x$metadata$fit`.
#' @param ... Reserved for future use.
#'
#' @return A length-1 numeric (S3 class `symbolizer_icc`) with attributes
#'   `scale` (`"data"`, `"latent"`, or `NA`), `reason` (character or `NA`), and
#'   `caption` (character or `NA`). Prints a one-line reading at the console.
#' @seealso [variance_partition()] for the full source-by-source breakdown.
#' @examples
#' # icc(symbolize(lme4::lmer(Reaction ~ Days + (1 | Subject),
#' #                          data = lme4::sleepstudy)))
#' @export
icc <- function(x, ...) {
  UseMethod("icc")
}

#' @export
icc.default <- function(x, ...) {
  cli::cli_abort(c(
    "{.fn icc} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
icc.symbolized_model <- function(x, ...) {
  re <- vc_re_rows(x$variance_components)
  if (is.null(re) || nrow(re) == 0L) {
    return(new_icc(NA_real_, scale = NA_character_,
                   reason = variance_reading("reason_no_re")))
  }
  if (nrow(re) > 1L) {
    return(new_icc(NA_real_, scale = NA_character_,
                   reason = variance_reading("reason_multiple_re")))
  }
  resid <- vc_residual_variance(x)
  if (!is.finite(resid$value)) {
    return(new_icc(NA_real_, scale = resid$scale, reason = resid$reason))
  }
  s2_g <- re$variance[[1L]]
  value <- s2_g / (s2_g + resid$value)
  caption <- if (identical(resid$scale, "latent")) {
    variance_reading("icc_caption_latent")
  } else {
    variance_reading("icc_caption_data")
  }
  new_icc(value, scale = resid$scale, reason = NA_character_, caption = caption)
}

# ---- residual-variance resolution -------------------------------------------

# Family-aware residual (within-group) variance for the partition denominator
# and the ICC. Returns list(value, scale, reason): `value` is NA when no single
# residual variance is defined, in which case `reason` carries the explanation
# (templated from variance-readings.csv).
vc_residual_variance <- function(x) {
  fam <- tolower(x$model$family %||% NA_character_)
  fit <- x$metadata$fit
  # Gaussian-identity: a single residual SD (when homoscedastic).
  if (fam %in% c("gaussian", "normal")) {
    # Prefer an explicit residual row already carried by the extractor
    # (lme4 / glmmTMB / MCMCglmm all carry one; for these `stats::sigma()`
    # would only reproduce the same number, and for MCMCglmm it warns "no
    # 'nobs' method is available"). Only drmTMB lacks a residual row -- there
    # we fall back to sigma(), which exposes the location-scale case.
    rv_tbl <- vc_residual_from_table(x$variance_components)
    if (is.finite(rv_tbl)) {
      return(list(value = rv_tbl, scale = "data", reason = NA_character_))
    }
    rv <- vc_gaussian_residual_var(fit)
    return(list(value = rv$value, scale = "data", reason = rv$reason))
  }
  # Binomial / Bernoulli: known latent-scale residual constant.
  if (fam %in% c("binomial", "bernoulli", "binary")) {
    lnk <- vc_link(fit)
    if (identical(lnk, "logit")) {
      return(list(value = pi^2 / 3, scale = "latent", reason = NA_character_))
    }
    if (identical(lnk, "probit")) {
      return(list(value = 1, scale = "latent", reason = NA_character_))
    }
    lab <- paste0("binomial (", lnk %||% "unknown", " link)")
    return(list(value = NA_real_, scale = "latent",
                reason = variance_reading("reason_no_residual_constant",
                                          family = lab)))
  }
  # Everything else (Poisson, Gamma, lognormal, ...): refuse on the data scale.
  list(value = NA_real_, scale = NA_character_,
       reason = variance_reading("reason_no_residual_constant",
                                 family = if (is.na(fam)) "this" else fam))
}

# The residual variance from an explicit "residual" row carried in the
# variance_components table (lme4 / glmmTMB / MCMCglmm). NA when no such row
# exists (drmTMB keeps the residual in its sigma submodel, not the table).
vc_residual_from_table <- function(vc) {
  if (is.null(vc) || nrow(vc) == 0L || !"var_estimate" %in% names(vc)) {
    return(NA_real_)
  }
  is_res <- vc_is_residual_row(vc)
  if (!any(is_res)) return(NA_real_)
  as.numeric(vc$var_estimate[which(is_res)[1L]])
}

# Residual variance for a Gaussian fit with no explicit residual row (drmTMB).
# `stats::sigma()` returns a scalar for lme4 / glmmTMB and a per-observation
# vector for a drmTMB location-scale fit; the latter only defines a single
# within-group variance when it is constant (sigma ~ 1). The call is wrapped
# in suppressWarnings because some fit classes (e.g. MCMCglmm) emit an
# uninformative "no 'nobs' method" warning; we handle a non-finite result
# below regardless.
vc_gaussian_residual_var <- function(fit) {
  if (is.null(fit)) {
    return(list(value = NA_real_,
                reason = "the original fit is not retained on this symbolized model."))
  }
  s <- suppressWarnings(tryCatch(stats::sigma(fit), error = function(e) NULL))
  if (is.null(s) || length(s) == 0L || !all(is.finite(s))) {
    return(list(value = NA_real_,
                reason = "could not retrieve a residual SD from the fit."))
  }
  if (length(s) == 1L) {
    return(list(value = as.numeric(s)^2, reason = NA_character_))
  }
  # Per-observation vector: defined only if the residual SD is constant.
  if (isTRUE(all.equal(max(s), min(s)))) {
    return(list(value = as.numeric(s[[1L]])^2, reason = NA_character_))
  }
  list(value = NA_real_, reason = variance_reading("reason_location_scale"))
}

vc_link <- function(fit) {
  if (is.null(fit)) return(NA_character_)
  tryCatch(stats::family(fit)$link, error = function(e) NA_character_)
}

# ---- variance-components row extraction -------------------------------------

# Random-effect rows of a variance_components tibble, normalized to
# tibble(component, variance, sd). Drops any residual row (lme4 / glmmTMB carry
# one labelled "residual"; drmTMB does not). Handles both column conventions:
# drmTMB (group_var / component) and lme4 (group / term).
vc_re_rows <- function(vc) {
  if (is.null(vc) || nrow(vc) == 0L) return(NULL)
  if (!all(c("sd_estimate", "var_estimate") %in% names(vc))) return(NULL)
  keep <- which(!vc_is_residual_row(vc))
  if (length(keep) == 0L) return(NULL)
  grp <- vc_first_col(vc, c("group_var", "group"))
  trm <- vc_first_col(vc, c("component", "term"))
  comp <- vapply(keep, function(i) {
    g <- if (!is.null(grp)) grp[[i]] else NA_character_
    t <- if (!is.null(trm)) trm[[i]] else NA_character_
    if (is.na(g) || !nzchar(g)) g <- t
    if (!is.na(t) && nzchar(t) && t != "(Intercept)" && !identical(t, g)) {
      paste0(g, " [", t, "]")
    } else {
      g
    }
  }, character(1L))
  tibble::tibble(
    component = comp,
    variance  = as.numeric(vc$var_estimate[keep]),
    sd        = as.numeric(vc$sd_estimate[keep])
  )
}

# A row is a residual row when any of its identifier columns reads "residual".
vc_is_residual_row <- function(vc) {
  res <- rep(FALSE, nrow(vc))
  for (col in c("parameter", "group", "term")) {
    if (col %in% names(vc)) {
      res <- res | (tolower(as.character(vc[[col]])) %in% "residual")
    }
  }
  res
}

vc_first_col <- function(vc, candidates) {
  hit <- candidates[candidates %in% names(vc)]
  if (length(hit) == 0L) return(NULL)
  as.character(vc[[hit[[1L]]]])
}

# ---- constructors + print methods -------------------------------------------

vc_new_partition <- function(rows, reason = NA_character_) {
  out <- tibble::tibble(
    component = as.character(rows$component),
    variance  = as.numeric(rows$variance),
    sd        = as.numeric(rows$sd),
    pct       = as.numeric(rows$pct)
  )
  attr(out, "reason") <- reason
  class(out) <- c("symbolizer_variance_partition", "tbl_df", "tbl", "data.frame")
  out
}

new_icc <- function(value, scale = NA_character_, reason = NA_character_,
                    caption = NA_character_) {
  structure(
    as.numeric(value),
    scale   = scale,
    reason  = reason,
    caption = caption,
    class   = "symbolizer_icc"
  )
}

#' @export
print.symbolizer_variance_partition <- function(x, ...) {
  cli::cli_h2("Where the variation lives")
  intro <- variance_reading("partition_intro")
  if (nzchar(intro)) cli::cli_text("{.emph {intro}}")
  if (nrow(x) == 0L) {
    cli::cli_text("{.emph (no variance components)}")
    return(invisible(x))
  }
  fmt <- function(v) formatC(v, digits = 3L, format = "fg", flag = "#")
  for (i in seq_len(nrow(x))) {
    pct <- x$pct[[i]]
    pct_str <- if (is.finite(pct)) {
      sprintf(" -- %s%% of total", formatC(100 * pct, digits = 1L, format = "f"))
    } else {
      ""
    }
    cli::cli_text(
      "{.strong {x$component[[i]]}}: variance = {.val {fmt(x$variance[[i]])}}, SD = {.val {fmt(x$sd[[i]])}}{pct_str}"
    )
  }
  reason <- attr(x, "reason")
  if (!is.null(reason) && !is.na(reason) && nzchar(reason)) {
    cli::cli_text("{.emph Shares (%) not shown: {reason}}")
  }
  cli::cli_text("{.emph Point estimates only; uncertainty not shown.}")
  invisible(x)
}

#' @export
print.symbolizer_icc <- function(x, ...) {
  v  <- as.numeric(unclass(x))
  sc <- attr(x, "scale")
  if (!is.finite(v)) {
    cli::cli_h2("ICC")
    msg <- variance_reading("icc_unavailable")
    if (nzchar(msg)) cli::cli_text("{.emph {msg}}")
    reason <- attr(x, "reason")
    if (!is.null(reason) && !is.na(reason) && nzchar(reason)) {
      cli::cli_text("Why: {reason}")
    }
    return(invisible(x))
  }
  scale_lab <- if (is.na(sc)) "" else sprintf(" (%s scale)", sc)
  cli::cli_h2("ICC{scale_lab}")
  cli::cli_text("ICC = {.val {formatC(v, digits = 3L, format = 'f')}}")
  cap <- attr(x, "caption")
  if (!is.null(cap) && !is.na(cap) && nzchar(cap)) {
    cli::cli_text("{.emph {cap}}")
  }
  invisible(x)
}
