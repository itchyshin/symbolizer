# ----------------------------------------------------------------------------
# marginal-estimates.R
#
# Thin emmeans wrappers: `group_means()` for categorical marginal means,
# `group_slopes()` for per-group slopes. They take a `symbolized_model`,
# pull the carried fit reference from `x$metadata$fit`, and delegate to
# `emmeans::emmeans()` / `emmeans::emtrends()`. The returned tibbles mirror
# the S1 column shape used elsewhere in the package: `level_combo`,
# `estimate`, `std_error`, `confint_low`, `confint_high`, `excludes_zero`,
# `ci_method`.
#
# emmeans is a Suggests dependency; every call is guarded by
# `requireNamespace()`.
# ----------------------------------------------------------------------------

#' Per-group marginal means for a symbolized model
#'
#' @description
#' `group_means()` returns categorical marginal means for the factors in a
#' [`symbolized_model`][new_symbolized_model], delegating to
#' [`emmeans::emmeans()`] under the hood. Each row is one combination of the
#' requested factors' levels with a point estimate, standard error, 95%
#' confidence band, and an `excludes_zero` indicator.
#'
#' Use this alongside [`parameter_interpretation()`] for any fit that contains
#' a factor: the coefficient table shows contrasts (differences from the
#' reference level); `group_means()` shows each group's expected response.
#'
#' Not supported on bivariate Gaussian (`biv_gaussian`) fits — a marginal
#' mean in a bivariate fit is a joint 2-vector `(mu1, mu2)`, not a scalar,
#' so the emmeans abstraction does not apply. Use
#' [`drmTMB::predict_parameters()`] on the fit directly, or refit each
#' response as a univariate Gaussian and call `group_means()` on each.
#'
#' @param x A [`symbolized_model`][new_symbolized_model] whose underlying fit
#'   is retained on `x$metadata$fit`.
#' @param by Optional character vector of factor names to marginalize over.
#'   Defaults to all factors in the model.
#' @param scale One of `"response"` (default) or `"link"`. Controls the
#'   scale of the returned estimate and confidence band. For families with
#'   identity link on the mean (Gaussian, Student-t), the two are
#'   equivalent. For log-link families (Gamma, lognormal, Poisson, nbinom2)
#'   `"response"` reports back-transformed means; `"link"` reports the
#'   log-scale linear predictor. For the logit-link Beta family,
#'   `"response"` reports proportions and `"link"` reports log-odds.
#' @param ci_method Confidence-interval method. Defaults to the `ci_method`
#'   stored on `x$metadata$ci_method` so the band matches the symbolize()
#'   call. emmeans currently produces asymptotic Wald-style intervals
#'   regardless of this argument, but the column is propagated for
#'   consistency with [`parameter_interpretation()`].
#' @param ... Reserved for future use.
#'
#' @return A tibble (S3 class `symbolizer_group_means`) with one row per
#'   level combination. Columns: `level_combo`, one column per factor in
#'   `by`, `estimate`, `std_error`, `confint_low`, `confint_high`,
#'   `excludes_zero`, `ci_method`, `scale`.
#' @export
group_means <- function(x, by = NULL, scale = c("response", "link"),
                        ci_method = NULL, ...) {
  UseMethod("group_means")
}

#' @export
group_means.default <- function(x, by = NULL, scale = c("response", "link"),
                                ci_method = NULL, ...) {
  cli::cli_abort(c(
    "{.fn group_means} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
group_means.symbolized_model <- function(x, by = NULL,
                                         scale = c("response", "link"),
                                         ci_method = NULL, ...) {
  scale <- match.arg(scale)
  marg_require_emmeans()
  marg_check_family_supported(x, "group_means")
  fit <- marg_require_fit(x, "group_means")
  factors <- marg_factors(x)
  if (length(factors) == 0L) {
    cli::cli_abort(c(
      "This model has no factors -- {.fn group_means} is for categorical marginals.",
      i = "For continuous-predictor slopes use {.fn group_slopes}."
    ))
  }
  if (is.null(by)) {
    by <- factors
  } else {
    if (!is.character(by) || any(!nzchar(by))) {
      cli::cli_abort("{.arg by} must be a non-empty character vector of factor names.")
    }
    unknown <- setdiff(by, factors)
    if (length(unknown) > 0L) {
      cli::cli_abort(c(
        "Unknown factor{?s} in {.arg by}: {.val {unknown}}.",
        i = "Known factors in this model: {.val {factors}}."
      ))
    }
  }
  ci_method <- ci_method %||% x$metadata$ci_method %||% "wald"
  rhs <- paste(by, collapse = " * ")
  spec <- stats::as.formula(paste("~", rhs))
  emm <- marg_emmeans(fit, spec, x$metadata$data)
  # Lognormal special case: drmTMB exposes mu on the IDENTITY link
  # because mu represents log(Y), so emmeans's automatic back-transform
  # on type = "response" is a no-op (it can't see the implicit log). Tell
  # emmeans about the transformation explicitly so the response-scale
  # estimate is the geometric mean exp(mu) with delta-method CI.
  if (identical(x$model$family, "lognormal") && scale == "response") {
    emm <- stats::update(emm, tran = "log")
  }
  # Back-transform to the response scale when requested (the default).
  # For identity-link families this is a no-op and gives the same numbers
  # as the link-scale path. For log / logit / logm2 links the user sees
  # rates / proportions / etc. instead of the raw linear-predictor scale.
  df <- as.data.frame(emm, type = if (scale == "response") "response" else "link")
  marg_tibble_means(df, by = by, ci_method = ci_method, scale = scale)
}

#' Per-group slopes for a continuous predictor
#'
#' @description
#' `group_slopes()` returns the slope of a continuous predictor stratified by
#' one or more factors (or by values of another continuous predictor),
#' delegating to [`emmeans::emtrends()`]. Each row is one stratum with a
#' point estimate, standard error, 95% confidence band, and an
#' `excludes_zero` indicator.
#'
#' Use this alongside [`parameter_interpretation()`] for any fit with a
#' continuous-by-categorical interaction (or continuous-by-continuous): the
#' coefficient table reports contrast slopes (differences from the reference
#' group's slope); `group_slopes()` reports each group's slope directly.
#'
#' Not supported on bivariate Gaussian (`biv_gaussian`) fits — see
#' [`group_means()`] for the same limitation and the recommended
#' alternatives.
#'
#' @param x A [`symbolized_model`][new_symbolized_model] whose underlying fit
#'   is retained on `x$metadata$fit`.
#' @param continuous Name of the continuous predictor whose slope is wanted.
#' @param at How to stratify. Three accepted shapes:
#'   * `NULL` (default): use every factor in the model that interacts with
#'     `continuous` (determined from `x$terms`).
#'   * A character vector of factor names: stratify by those factors' levels.
#'   * A named list (e.g. `list(z = c(-1, 0, 1))`): for continuous-by-
#'     continuous interactions, get the slope at those values of `z`.
#' @param scale One of `"response"` (default) or `"link"`. For
#'   identity-link families the two are equivalent. For other families
#'   the slope is reported on the requested scale: `"link"` gives the
#'   linear-predictor slope (which is what the coefficient table shows),
#'   `"response"` gives the slope after back-transformation. Note that
#'   for non-identity links the response-scale slope depends on the
#'   level of the predictor.
#' @param ci_method Confidence-interval method. Defaults to
#'   `x$metadata$ci_method`. See [group_means()] for details.
#' @param ... Reserved for future use.
#'
#' @return A tibble (S3 class `symbolizer_group_slopes`) with one row per
#'   stratum. Columns: `predictor`, `level_combo`, one column per stratifying
#'   variable, `estimate`, `std_error`, `confint_low`, `confint_high`,
#'   `excludes_zero`, `ci_method`, `scale`.
#' @export
group_slopes <- function(x, continuous, at = NULL,
                         scale = c("response", "link"),
                         ci_method = NULL, ...) {
  UseMethod("group_slopes")
}

#' @export
group_slopes.default <- function(x, continuous, at = NULL,
                                 scale = c("response", "link"),
                                 ci_method = NULL, ...) {
  cli::cli_abort(c(
    "{.fn group_slopes} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
group_slopes.symbolized_model <- function(x, continuous, at = NULL,
                                          scale = c("response", "link"),
                                          ci_method = NULL, ...) {
  scale <- match.arg(scale)
  marg_require_emmeans()
  marg_check_family_supported(x, "group_slopes")
  if (missing(continuous) || !is.character(continuous) ||
      length(continuous) != 1L || !nzchar(continuous)) {
    cli::cli_abort("{.arg continuous} must be a single non-empty character string.")
  }
  fit <- marg_require_fit(x, "group_slopes")
  factors <- marg_factors(x)
  # Resolve stratifier(s). Three input shapes -> one canonical (by_vars, at_list).
  resolved <- marg_resolve_at(at, continuous, x, factors)
  by_vars <- resolved$by_vars
  at_list <- resolved$at_list
  if (length(by_vars) == 0L) {
    cli::cli_abort(c(
      "No stratifier found for {.fn group_slopes} on {.val {continuous}}.",
      i = "Pass {.arg at} as a factor name (for cont x cat) or as a named list (for cont x cont).",
      i = "Detected factors in the model: {.val {factors}}."
    ))
  }
  ci_method <- ci_method %||% x$metadata$ci_method %||% "wald"
  rhs <- paste(by_vars, collapse = " * ")
  spec <- stats::as.formula(paste("~", rhs))
  emm <- marg_emtrends(fit, spec, continuous, at = at_list,
                       data = x$metadata$data)
  df <- as.data.frame(emm,
                      type = if (scale == "response") "response" else "link")
  marg_tibble_slopes(df, by_vars = by_vars, predictor = continuous,
                     ci_method = ci_method, scale = scale)
}

# ---- internals --------------------------------------------------------------

marg_require_emmeans <- function() {
  if (!requireNamespace("emmeans", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg emmeans} is required for {.fn group_means} / {.fn group_slopes}.",
      i = "Install it with {.code install.packages(\"emmeans\")}."
    ))
  }
  invisible(TRUE)
}

marg_require_fit <- function(x, fn_name) {
  fit <- x$metadata$fit
  if (is.null(fit)) {
    cli::cli_abort(c(
      "The original fit is not retained on this {.cls symbolized_model}.",
      i = "Re-run {.fn symbolize} on your fit; {.fn {fn_name}} needs the fitted object."
    ))
  }
  fit
}

# Gate fits whose family doesn't fit the marginal-means abstraction. Today
# this is just biv_gaussian: a "marginal mean" in a bivariate fit is a joint
# 2-vector prediction, not a scalar, and emmeans does not (today) provide a
# basis for biv_gaussian. We catch this upfront with a symbolizer-layer
# message rather than letting drmTMB's emmeans preflight raise a less
# explanatory error downstream.
marg_check_family_supported <- function(x, fn_name) {
  fam <- x$model$family %||% NA_character_
  unsupported <- c("biv_gaussian")
  if (fam %in% unsupported) {
    cli::cli_abort(c(
      "{.fn {fn_name}} does not currently support {.val {fam}} fits.",
      i = "A {.emph marginal mean} in a bivariate fit is a joint 2-vector
           prediction {.code (mu1_i, mu2_i)}, not a scalar, so the
           {.pkg emmeans} marginal abstraction does not apply.",
      i = "For per-response predictions on a bivariate fit, use
           {.fn drmTMB::predict_parameters} on the fit directly.",
      i = "Alternatively, refit each response as a univariate Gaussian and
           call {.fn {fn_name}} on each."
    ))
  }
  # metafor rma fits: emmeans ships no recover_data / emm_basis method for
  # class `rma`, so the reference grid cannot be built. Gate with an
  # explanatory message pointing at metafor's own moderator tools rather
  # than letting emmeans raise its generic "Can't handle an object" error.
  cls <- x$model$class %||% NA_character_
  if (cls %in% c("rma.uni", "rma.mv", "rma")) {
    cli::cli_abort(c(
      "{.fn {fn_name}} does not support {.pkg metafor} ({.cls {cls}}) fits.",
      i = "{.pkg emmeans} has no reference-grid method for {.cls rma} objects,
           so per-group means and contrasts cannot be computed this way.",
      i = "For moderator comparisons use {.pkg metafor}'s own tools:
           {.fn metafor::predict} on a moderator grid, or
           {.fn metafor::anova} for model-based contrasts."
    ))
  }
  invisible(TRUE)
}

# Factors detected from the symbol_dictionary (role == "factor").
marg_factors <- function(x) {
  d <- x$symbol_dictionary
  if (is.null(d) || nrow(d) == 0L) return(character(0L))
  out <- d$variable[d$role == "factor" & !is.na(d$variable)]
  unique(out[nzchar(out)])
}

# Continuous predictors that interact with `continuous` in the mu submodel.
marg_factor_partners <- function(x, continuous) {
  terms_tbl <- x$terms
  if (is.null(terms_tbl) || nrow(terms_tbl) == 0L) return(character(0L))
  inter <- terms_tbl[terms_tbl$role == "interaction", , drop = FALSE]
  if (nrow(inter) == 0L) return(character(0L))
  partners <- unique(unlist(lapply(inter$variable, function(v) {
    pieces <- strsplit(v, ":", fixed = TRUE)[[1L]]
    if (continuous %in% pieces) setdiff(pieces, continuous) else character(0L)
  })))
  partners
}

# Resolve `at` into (by_vars, at_list) for the emtrends call.
marg_resolve_at <- function(at, continuous, x, factors) {
  if (is.null(at)) {
    partners <- marg_factor_partners(x, continuous)
    by_vars <- intersect(partners, factors)
    if (length(by_vars) == 0L) by_vars <- factors
    return(list(by_vars = by_vars, at_list = list()))
  }
  if (is.character(at)) {
    return(list(by_vars = at, at_list = list()))
  }
  if (is.list(at)) {
    nm <- names(at)
    if (is.null(nm) || any(!nzchar(nm))) {
      cli::cli_abort("{.arg at} must be a named list when used for continuous stratification.")
    }
    return(list(by_vars = nm, at_list = at))
  }
  cli::cli_abort(
    "{.arg at} must be NULL, a character vector of factor names, or a named list."
  )
}

# Build the symbolizer_group_means tibble from emmeans output.
# When emmeans is called with `type = "response"` the estimate column is
# renamed from "emmean" to "response" (Gaussian / identity-link families
# keep "emmean" because no back-transform was performed). Try both.
marg_tibble_means <- function(df, by, ci_method, scale = "response") {
  est_col <- if ("response" %in% names(df)) "response" else
             if ("emmean" %in% names(df))   "emmean"   else
             setdiff(names(df), c(by, "SE", "df", "asymp.LCL", "asymp.UCL",
                                  "lower.CL", "upper.CL"))[[1L]]
  marg_finalize(df, by = by, ci_method = ci_method, scale = scale,
                est_col = est_col, klass = "symbolizer_group_means",
                predictor = NULL)
}

# Build the symbolizer_group_slopes tibble from emtrends output.
marg_tibble_slopes <- function(df, by_vars, predictor, ci_method,
                               scale = "response") {
  # emtrends names the slope column "<var>.trend"; with type = "response"
  # it may be just "trend" or back-transformed differently. Try a few.
  est_col <- paste0(predictor, ".trend")
  if (!est_col %in% names(df)) {
    # Fallback: pick the column emmeans actually emitted (it may rename
    # under unusual settings).
    cands <- setdiff(names(df), c(by_vars, "SE", "df", "asymp.LCL",
                                  "asymp.UCL", "lower.CL", "upper.CL"))
    if (length(cands) >= 1L) est_col <- cands[[1L]]
  }
  marg_finalize(df, by = by_vars, ci_method = ci_method, scale = scale,
                est_col = est_col, klass = "symbolizer_group_slopes",
                predictor = predictor)
}

# Shared assembly: emmeans data frame -> symbolizer tibble.
marg_finalize <- function(df, by, ci_method, scale, est_col, klass, predictor) {
  estimate  <- df[[est_col]]
  se_col    <- if ("SE" %in% names(df)) "SE" else NA_character_
  # `lower.HPD` / `upper.HPD` are the Bayesian credible-band columns emmeans
  # emits for MCMCglmm and brms fits (no SE); the *.CL columns are the
  # frequentist intervals. Try both so posterior fits keep their bands.
  lo_col    <- marg_first_present(df, c("asymp.LCL", "lower.CL", "LCL", "lower.HPD"))
  hi_col    <- marg_first_present(df, c("asymp.UCL", "upper.CL", "UCL", "upper.HPD"))
  std_error <- if (!is.na(se_col)) df[[se_col]] else rep(NA_real_, nrow(df))
  lo        <- if (!is.na(lo_col)) df[[lo_col]] else rep(NA_real_, nrow(df))
  hi        <- if (!is.na(hi_col)) df[[hi_col]] else rep(NA_real_, nrow(df))
  excl_zero <- !is.na(lo) & !is.na(hi) & sign(lo) == sign(hi) &
    lo != 0 & hi != 0
  level_combo <- marg_level_combo(df, by)
  out <- tibble::tibble(level_combo = level_combo)
  for (v in by) {
    if (v %in% names(df)) out[[v]] <- df[[v]]
  }
  out$estimate      <- as.numeric(estimate)
  out$std_error     <- as.numeric(std_error)
  out$confint_low   <- as.numeric(lo)
  out$confint_high  <- as.numeric(hi)
  out$excludes_zero <- excl_zero
  out$ci_method     <- rep(ci_method, nrow(out))
  out$scale         <- rep(scale, nrow(out))
  if (!is.null(predictor)) {
    out <- tibble::add_column(out, predictor = rep(predictor, nrow(out)),
                              .before = 1L)
  }
  class(out) <- c(klass, "tbl_df", "tbl", "data.frame")
  out
}

marg_first_present <- function(df, candidates) {
  hit <- candidates[candidates %in% names(df)]
  if (length(hit) >= 1L) hit[[1L]] else NA_character_
}

# Call emmeans / emtrends, forwarding `data` ONLY when we actually retained one
# (e.g. MCMCglmm, whose fit does not carry its model frame and whose
# recover_data method needs it). Passing `data = NULL` explicitly is NOT the
# same as omitting it -- emmeans then fails with "undefined columns selected".
marg_emmeans <- function(fit, spec, data = NULL) {
  if (is.null(data)) emmeans::emmeans(fit, spec)
  else emmeans::emmeans(fit, spec, data = data)
}

marg_emtrends <- function(fit, spec, var, at = list(), data = NULL) {
  has_at <- length(at) > 0L
  if (is.null(data)) {
    if (has_at) emmeans::emtrends(fit, spec, var = var, at = at)
    else        emmeans::emtrends(fit, spec, var = var)
  } else {
    if (has_at) emmeans::emtrends(fit, spec, var = var, at = at, data = data)
    else        emmeans::emtrends(fit, spec, var = var, data = data)
  }
}

marg_level_combo <- function(df, by) {
  if (length(by) == 0L) return(rep("", nrow(df)))
  parts <- lapply(by, function(v) {
    if (!v %in% names(df)) return(rep("", nrow(df)))
    paste0(v, "=", format(df[[v]], trim = TRUE))
  })
  if (length(parts) == 1L) return(parts[[1L]])
  do.call(paste, c(parts, sep = ", "))
}

# ---- print methods ----------------------------------------------------------

#' @export
print.symbolizer_group_means <- function(x, ...) {
  cli::cli_h2("Group means")
  marg_print_rows(x, predictor = NULL)
  invisible(x)
}

#' @export
print.symbolizer_group_slopes <- function(x, ...) {
  predictor <- if ("predictor" %in% names(x) && nrow(x) >= 1L) {
    x$predictor[[1L]]
  } else NA_character_
  if (!is.na(predictor)) {
    cli::cli_h2("Group slopes for {.val {predictor}}")
  } else {
    cli::cli_h2("Group slopes")
  }
  marg_print_rows(x, predictor = predictor)
  invisible(x)
}

# Shared printer for both group-means and group-slopes objects.
marg_print_rows <- function(x, predictor = NULL) {
  if (nrow(x) == 0L) {
    cli::cli_text("{.emph (no rows)}")
    return(invisible(x))
  }
  fmt <- function(v) formatC(v, digits = 3L, format = "fg", flag = "#")
  for (i in seq_len(nrow(x))) {
    est <- fmt(x$estimate[[i]])
    lo  <- x$confint_low[[i]]
    hi  <- x$confint_high[[i]]
    ci_str <- if (!is.na(lo) && !is.na(hi)) {
      paste0(" (", fmt(lo), ", ", fmt(hi), ")")
    } else ""
    marker <- if (isTRUE(x$excludes_zero[[i]])) " *" else ""
    cli::cli_text(
      "{.emph {x$level_combo[[i]]}}  estimate = {.val {est}}{ci_str}{marker}"
    )
  }
  ci_methods <- unique(x$ci_method[!is.na(x$ci_method)])
  scales     <- if ("scale" %in% names(x)) unique(x$scale[!is.na(x$scale)]) else character(0L)
  scale_note <- if (length(scales) == 1L) {
    sprintf("Scale: %s. ", scales)
  } else ""
  if (length(ci_methods) == 1L) {
    cli::cli_text(
      "{.emph {scale_note}CI method: {ci_methods}. Rows marked {.code *} have a 95% interval that excludes zero.}"
    )
  }
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# ----------------------------------------------------------------------------
# group_contrasts(): pairwise / vs-reference comparisons of factor levels.
#
# The coefficient table shows each level versus the reference; group_means()
# shows each level's mean. group_contrasts() answers the question those two
# cannot: "which levels differ from each OTHER?" It delegates to
# emmeans::contrast() and reports confidence bands with NO p-values (VISION:
# light-touch uncertainty, compatibility bands only). Multiplicity is opt-in
# via `adjust` -- it widens the band, it never adds a star.
# ----------------------------------------------------------------------------

#' Pairwise and reference contrasts between factor levels
#'
#' @description
#' `group_contrasts()` compares the levels of a factor against each other
#' (or against a reference), delegating to [`emmeans::contrast()`]. Use it for
#' any multi-level factor where the coefficient table -- which only reports each
#' level versus the reference -- leaves "which levels differ from each other?"
#' unanswered.
#'
#' Each row is one contrast with a point estimate, standard error, 95%
#' confidence band, and an `excludes_zero` flag. **No p-values are reported**:
#' symbolizer shows compatibility bands, not tests. For families on a log or
#' logit link the response-scale contrast is a *ratio* (or odds ratio), whose
#' null value is 1, not 0 -- the `effect_type` column records which, and the
#' `excludes_zero` flag is computed against the correct null.
#'
#' Not supported on bivariate Gaussian (`biv_gaussian`) fits -- see
#' [`group_means()`] for the limitation and alternatives.
#'
#' @param x A [`symbolized_model`][new_symbolized_model] whose underlying fit is
#'   retained on `x$metadata$fit`.
#' @param by Character vector of factor name(s) whose levels are contrasted.
#'   Defaults to all factors in the model.
#' @param method Contrast family, passed to [`emmeans::contrast()`]:
#'   `"pairwise"` (all pairs, default), `"trt.vs.ctrl"` (each level versus the
#'   reference), `"revpairwise"`, `"consec"` (consecutive levels), or `"poly"`.
#' @param within Optional factor name(s) to compute the contrasts *within each
#'   level of* (emmeans `by`). Use this for the multi-factor case: pairwise
#'   contrasts of one factor separately at each level of another.
#' @param scale One of `"response"` (default) or `"link"`. On `"link"` the
#'   contrast is an additive difference on the linear-predictor scale; on
#'   `"response"` it is back-transformed (a ratio for log links, an odds ratio
#'   for logit links).
#' @param ci_method Confidence-interval method label; defaults to
#'   `x$metadata$ci_method`. See [`group_means()`].
#' @param adjust Multiplicity adjustment for the confidence bands: `"none"`
#'   (default; one per-contrast interval), `"tukey"` (family-wise), or `"mvt"`.
#'   This only widens the interval -- it never produces a p-value.
#' @param ... Reserved for future use.
#'
#' @return A tibble (S3 class `symbolizer_group_contrasts`) with one row per
#'   contrast. Columns: `contrast`, one column per `within` factor, `level_combo`,
#'   `estimate`, `std_error`, `confint_low`, `confint_high`, `excludes_zero`,
#'   `ci_method`, `scale`, `method`, `adjust`, `effect_type`.
#' @seealso [`group_means()`], [`group_slopes()`]
#' @examples
#' d <- transform(mtcars, gear = factor(gear))
#' sym <- symbolize(lm(mpg ~ gear, data = d))
#' if (requireNamespace("emmeans", quietly = TRUE)) {
#'   # which gears differ from each other (not just from the reference)?
#'   group_contrasts(sym, by = "gear")
#' }
#' @export
group_contrasts <- function(x, by = NULL,
                            method = c("pairwise", "trt.vs.ctrl",
                                       "revpairwise", "consec", "poly"),
                            within = NULL, scale = c("response", "link"),
                            ci_method = NULL,
                            adjust = c("none", "tukey", "mvt"), ...) {
  UseMethod("group_contrasts")
}

#' @export
group_contrasts.default <- function(x, ...) {
  cli::cli_abort(c(
    "{.fn group_contrasts} has no method for objects of class {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
group_contrasts.symbolized_model <- function(x, by = NULL,
                                             method = c("pairwise", "trt.vs.ctrl",
                                                        "revpairwise", "consec",
                                                        "poly"),
                                             within = NULL,
                                             scale = c("response", "link"),
                                             ci_method = NULL,
                                             adjust = c("none", "tukey", "mvt"),
                                             ...) {
  scale  <- match.arg(scale)
  method <- match.arg(method)
  adjust <- match.arg(adjust)
  marg_require_emmeans()
  marg_check_family_supported(x, "group_contrasts")
  fit <- marg_require_fit(x, "group_contrasts")
  factors <- marg_factors(x)
  if (length(factors) == 0L) {
    cli::cli_abort(c(
      "This model has no factors -- {.fn group_contrasts} compares factor levels.",
      i = "For continuous-predictor slopes use {.fn group_slopes}."
    ))
  }
  if (is.null(by)) {
    by <- factors
  } else if (!is.character(by) || any(!nzchar(by))) {
    cli::cli_abort("{.arg by} must be a non-empty character vector of factor names.")
  }
  unknown <- setdiff(by, factors)
  if (length(unknown) > 0L) {
    cli::cli_abort(c(
      "Unknown factor{?s} in {.arg by}: {.val {unknown}}.",
      i = "Known factors in this model: {.val {factors}}."
    ))
  }
  if (!is.null(within)) {
    if (!is.character(within) || any(!nzchar(within))) {
      cli::cli_abort("{.arg within} must be a character vector of factor names.")
    }
    unknown_w <- setdiff(within, factors)
    if (length(unknown_w) > 0L) {
      cli::cli_abort(c(
        "Unknown factor{?s} in {.arg within}: {.val {unknown_w}}.",
        i = "Known factors in this model: {.val {factors}}."
      ))
    }
    if (length(intersect(by, within)) > 0L) {
      cli::cli_abort("{.arg by} and {.arg within} must not overlap.")
    }
  }
  ci_method <- ci_method %||% x$metadata$ci_method %||% "wald"

  # The reference grid must span both the contrasted factors and any `within`
  # stratifiers (mirrors group_means' `*` join). emmeans then contrasts `by`
  # within each combination of `within`.
  grid_vars <- unique(c(by, within))
  spec <- stats::as.formula(paste("~", paste(grid_vars, collapse = " * ")))
  emm <- marg_emmeans(fit, spec, x$metadata$data)
  # Lognormal identity-link special case (see group_means): tell emmeans about
  # the implicit log transform so the response-scale contrast is a ratio of
  # geometric means with a delta-method band.
  if (identical(x$model$family, "lognormal") && scale == "response") {
    emm <- stats::update(emm, tran = "log")
  }
  ctr <- emmeans::contrast(emm, method = method, by = within, adjust = adjust)

  # CIs WITHOUT p-values: infer = c(CIs = TRUE, tests = FALSE) emits the
  # confidence band and omits t.ratio / p.value. type = "response" back-
  # transforms (a difference of logs becomes a RATIO).
  df <- as.data.frame(summary(
    ctr,
    infer = c(TRUE, FALSE),
    type  = if (scale == "response") "response" else "link",
    level = 0.95
  ))

  effect_type <- marg_contrast_effect_type(x$model$family, scale)
  marg_tibble_contrasts(df, by = by, within = within, method = method,
                        adjust = adjust, ci_method = ci_method, scale = scale,
                        effect_type = effect_type)
}

# Whether a response-scale contrast is a plain difference, a ratio (log link),
# or an odds ratio (logit link). Link-scale contrasts are always differences.
#' @keywords internal
marg_contrast_effect_type <- function(family, scale) {
  if (identical(scale, "link")) return("difference")
  fam <- family %||% ""
  log_link <- c("poisson", "nbinom2", "nbinom1", "Gamma", "gamma", "lognormal",
                "truncated_nbinom2", "truncated_nbinom1", "truncated_poisson")
  logit_link <- c("beta", "binomial", "beta_binomial", "betabinomial",
                  "bernoulli", "cumulative_logit")
  if (fam %in% log_link)   return("ratio")
  if (fam %in% logit_link) return("odds_ratio")
  "difference"
}

# Build the symbolizer_group_contrasts tibble from an emmeans contrast summary.
# emmeans names the estimate column "estimate" (link scale), "ratio" (log
# response) or "odds.ratio" (logit response). For ratios the null is 1, not 0,
# so excludes_zero is computed against the correct null per effect_type.
#' @keywords internal
marg_tibble_contrasts <- function(df, by, within, method, adjust, ci_method,
                                  scale, effect_type) {
  est_col <- marg_first_present(df, c("estimate", "ratio", "odds.ratio"))
  if (is.na(est_col)) {
    est_col <- setdiff(names(df),
                       c("contrast", within, "SE", "df", "asymp.LCL",
                         "asymp.UCL", "lower.CL", "upper.CL"))[[1L]]
  }
  lo_col <- marg_first_present(df, c("asymp.LCL", "lower.CL", "LCL", "lower.HPD"))
  hi_col <- marg_first_present(df, c("asymp.UCL", "upper.CL", "UCL", "upper.HPD"))
  se_col <- if ("SE" %in% names(df)) "SE" else NA_character_

  estimate  <- as.numeric(df[[est_col]])
  std_error <- if (!is.na(se_col)) as.numeric(df[[se_col]]) else rep(NA_real_, nrow(df))
  lo <- if (!is.na(lo_col)) as.numeric(df[[lo_col]]) else rep(NA_real_, nrow(df))
  hi <- if (!is.na(hi_col)) as.numeric(df[[hi_col]]) else rep(NA_real_, nrow(df))

  null_val <- if (effect_type %in% c("ratio", "odds_ratio")) 1 else 0
  excludes_null <- !is.na(lo) & !is.na(hi) &
    ((lo > null_val & hi > null_val) | (lo < null_val & hi < null_val))

  contrast_lab <- if ("contrast" %in% names(df)) {
    as.character(df$contrast)
  } else rep(NA_character_, nrow(df))

  out <- tibble::tibble(contrast = contrast_lab)
  for (v in within) {
    if (v %in% names(df)) out[[v]] <- df[[v]]
  }
  out$level_combo   <- if (length(within) > 0L) marg_level_combo(df, within) else rep("", nrow(df))
  out$estimate      <- estimate
  out$std_error     <- std_error
  out$confint_low   <- lo
  out$confint_high  <- hi
  out$excludes_zero <- excludes_null   # name kept for column parity; null per effect_type
  out$ci_method     <- rep(ci_method, nrow(out))
  out$scale         <- rep(scale, nrow(out))
  out$method        <- rep(method, nrow(out))
  out$adjust        <- rep(adjust, nrow(out))
  out$effect_type   <- rep(effect_type, nrow(out))
  class(out) <- c("symbolizer_group_contrasts", "tbl_df", "tbl", "data.frame")
  out
}

#' @export
print.symbolizer_group_contrasts <- function(x, ...) {
  method <- if ("method" %in% names(x) && nrow(x) >= 1L) x$method[[1L]] else "pairwise"
  cli::cli_h2("Group contrasts ({method})")
  marg_print_contrast_rows(x)
  invisible(x)
}

marg_print_contrast_rows <- function(x) {
  if (nrow(x) == 0L) {
    cli::cli_text("{.emph (no rows)}")
    return(invisible(x))
  }
  fmt <- function(v) formatC(v, digits = 3L, format = "fg", flag = "#")
  eff <- if ("effect_type" %in% names(x)) x$effect_type[[1L]] else "difference"
  for (i in seq_len(nrow(x))) {
    lab <- x$contrast[[i]]
    within_lab <- if ("level_combo" %in% names(x) && nzchar(x$level_combo[[i]])) {
      paste0(" @ ", x$level_combo[[i]])
    } else ""
    est <- fmt(x$estimate[[i]])
    lo  <- x$confint_low[[i]]
    hi  <- x$confint_high[[i]]
    ci_str <- if (!is.na(lo) && !is.na(hi)) paste0(" (", fmt(lo), ", ", fmt(hi), ")") else ""
    marker <- if (isTRUE(x$excludes_zero[[i]])) " *" else ""
    cli::cli_text("{.emph {lab}{within_lab}}  estimate = {.val {est}}{ci_str}{marker}")
  }
  scales <- unique(x$scale[!is.na(x$scale)])
  cims   <- unique(x$ci_method[!is.na(x$ci_method)])
  adj    <- if ("adjust" %in% names(x)) unique(x$adjust)[[1L]] else "none"
  eff_note <- if (eff %in% c("ratio", "odds_ratio")) {
    sprintf("Values are %s; the null is 1, not 0. ",
            if (identical(eff, "odds_ratio")) "odds ratios" else "ratios")
  } else ""
  multi_note <- if (identical(adj, "none") && nrow(x) > 1L) {
    "Intervals are per-contrast, not family-wise; pass adjust = \"tukey\" for simultaneous bands. "
  } else ""
  scale_note <- if (length(scales) == 1L) sprintf("Scale: %s. ", scales) else ""
  ci_note    <- if (length(cims) == 1L) sprintf("CI method: %s. ", cims) else ""
  cli::cli_text(
    "{.emph {eff_note}{multi_note}{scale_note}{ci_note}Adjustment: {adj}. Rows marked {.code *} have a 95% interval that excludes the null.}"
  )
}
