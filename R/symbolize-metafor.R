# ----------------------------------------------------------------------------
# symbolize.rma.uni
#
# v0.13 First slice extractor for metafor random-effects meta-analysis
# and meta-regression. Models the two-tier structure explicitly:
#
#   y_i | theta_i  ~ N(theta_i, v_i)              (sampling level, v_i known)
#   theta_i        = beta_0 + sum_k beta_k x_{ki} + u_i
#                                                  (true-effect level)
#   u_i ~ N(0, tau^2)                              (heterogeneity)
#
# The fitted rma.uni object exposes:
#
#   fit$yi              effect sizes (numeric)
#   fit$vi              sampling variances (numeric, KNOWN, not estimated)
#   fit$X               design matrix (intercept named "intrcpt")
#   fit$beta            coefficient matrix (k_b x 1)
#   fit$se              standard errors
#   fit$ci.lb, fit$ci.ub  95% confidence bounds
#   fit$tau2            between-study heterogeneity variance
#   fit$k               number of effect sizes
#   fit$method          REML / DL / HE / ML / EB / SJ / ...
#   fit$data            original data frame
#   fit$mods            moderator data (NULL if y ~ 1)
#
# The first-slice scope is the random-effects / mixed-effects meta-
# regression case (`y ~ 1` or `y ~ mods`). rma.mv (multilevel /
# multivariate) and selection / publication-bias models stay Planned.
# ----------------------------------------------------------------------------

#' Symbolize a metafor rma.uni fit (meta-analysis / meta-regression, v0.13 first slice)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from an
#' `rma.uni` fit. v0.13 covers random / mixed-effects meta-analysis
#' with optional moderators. The fitted object's `yi` and `vi` slots
#' are treated as known (sampling variances are not parameters), and
#' the between-study heterogeneity `tau^2` appears in the
#' `variance_components` tibble.
#'
#' @inheritParams symbolize
#' @return A `symbolized_model` object.
#' @export
symbolize.rma.uni <- function(fit, symbols = NULL, units = NULL,
                              context = NULL, ...) {
  if (!requireNamespace("metafor", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg metafor} is needed to symbolize this fit.",
      i = "Install it with {.code install.packages(\"metafor\")}."
    ))
  }
  family <- "meta_normal"
  capability_check("rma.uni", family, "mu")
  if (!is.null(fit$tau2) && fit$tau2 > 0) {
    capability_check("rma.uni", family, "tau2")
  }

  # The "response" here is the effect size; metafor stores it as fit$yi
  # but doesn't give it a column name on the fit object. Default to "yi".
  response <- "yi"

  data <- fit$data
  if (is.null(data)) {
    data <- data.frame(yi = fit$yi, vi = fit$vi)
    if (!is.null(fit$X) && ncol(fit$X) > 1L) {
      mod_cols <- colnames(fit$X)
      mod_cols <- mod_cols[mod_cols != "intrcpt"]
      for (m in mod_cols) data[[m]] <- as.numeric(fit$X[, m])
    }
  }
  n_obs <- as.integer(fit$k %||% nrow(data))

  # Synthesize a formula from fit$X / fit$beta. Drop the intercept name
  # ("intrcpt") so R's extract_terms picks it up as the implicit
  # intercept. Other columns become predictors.
  beta_names <- rownames(fit$beta) %||% names(stats::coef(fit))
  pred_names <- setdiff(beta_names, c("intrcpt", "(Intercept)"))
  rhs_text <- if (length(pred_names) == 0L) "1" else paste(pred_names, collapse = " + ")
  cond_form <- stats::as.formula(paste(response, "~", rhs_text))

  entries <- list(
    list(
      dpar = "mu",
      response = response,
      rhs = if (length(pred_names) == 0L) quote(1) else metafor_rhs_expr(cond_form),
      expr = cond_form,
      position = 1L
    )
  )

  param <- get_parameterization(family)
  index <- list(observation = "i", study = "s", outcome = "k")

  response_symbol <- metafor_resolve_response_symbol(response, symbols)
  response_symbol_matrix <- "\\mathbf{y}"
  response_units <- drm_resolve_units(response, units)

  model <- list(
    class = "rma.uni",
    package = "metafor",
    family = family,
    response = response,
    n_obs = n_obs,
    method = fit$method
  )

  distribution <- drm_build_distribution(
    family, response_symbol, response_symbol_matrix,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )
  submodels  <- metafor_build_submodels(entries, param)
  terms_tbl  <- drm_build_terms(entries, data, symbols)
  fixed_eff  <- metafor_build_fixed_effects(terms_tbl, fit)
  re_per_entry <- list(metafor_build_re_per_entry(fit))
  re_tbl     <- drm_build_random_effects(re_per_entry)
  vc_tbl     <- metafor_build_variance_components(fit)
  cov_tbl    <- drm_build_covariance_components(re_tbl)
  components <- drm_build_components(
    submodels, terms_tbl, re_tbl,
    response_symbol, response_symbol_matrix,
    family = family,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )
  symbol_dict <- drm_build_symbol_dictionary(
    terms_tbl, response, response_symbol, response_symbol_matrix,
    response_units, family, submodels, units, data, n_obs, re_tbl,
    response_1 = response, response_2 = NA_character_,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )
  assumptions <- drm_build_assumptions(
    family, response, response_symbol, re_tbl,
    response_1 = response, response_2 = NA_character_
  )
  interp <- drm_build_interpretation(
    fixed_eff, family, response, data,
    response_1 = response, response_2 = NA_character_
  )
  bridge <- drm_build_formula_bridge(
    entries, components, response,
    response_1 = response, response_2 = NA_character_
  )
  expanded <- list(y = as.numeric(fit$yi), X = fit$X, Z = NULL,
                   beta = as.numeric(fit$beta), u = NULL,
                   fitted = stats::fitted(fit), residuals = stats::residuals(fit))

  metadata <- list(
    call = fit$call,
    context = context %||% "",
    ci_method = "wald",
    fit = fit,
    package_versions = list(
      symbolizer = utils::packageVersion("symbolizer"),
      metafor    = utils::packageVersion("metafor")
    ),
    method = fit$method,
    tau2 = as.numeric(fit$tau2 %||% NA_real_),
    created_by = "symbolize.rma.uni"
  )

  sym_stub <- list(
    model = model, metadata = metadata, random_effects = re_tbl
  )
  warnings_tbl <- metafor_build_warnings(fit, sym_stub)

  new_symbolized_model(
    model               = model,
    index               = index,
    parameterization    = param,
    distribution        = distribution,
    submodels           = submodels,
    terms               = terms_tbl,
    fixed_effects       = fixed_eff,
    random_effects      = re_tbl,
    variance_components = vc_tbl,
    covariance_components = cov_tbl,
    symbol_dictionary   = symbol_dict,
    assumptions         = assumptions,
    components          = components,
    interpretation      = interp,
    formula_bridge      = bridge,
    warnings_registry   = warnings_tbl,
    expanded            = expanded,
    metadata            = metadata
  )
}

# ---- helpers ---------------------------------------------------------------

metafor_rhs_expr <- function(f) {
  if (length(f) == 3L) f[[3L]] else f[[2L]]
}

metafor_resolve_response_symbol <- function(response, symbols) {
  if (!is.null(symbols) && !is.null(symbols[[response]])) {
    return(as.character(symbols[[response]]))
  }
  "y"
}

metafor_build_submodels <- function(entries, param) {
  rows <- lapply(entries, function(e) {
    dpar <- e$dpar
    coef_family <- drm_coef_family_for(dpar)
    f <- stats::as.formula(paste("~", paste(deparse(e$rhs), collapse = " ")))
    tibble::tibble(
      parameter = dpar,
      formula = list(f),
      link = "identity",
      coef_family = coef_family,
      position = e$position
    )
  })
  do.call(rbind, rows)
}

# Map metafor's beta row name to the symbolizer term hit. metafor uses
# "intrcpt" instead of "(Intercept)".
metafor_hit_name <- function(row) {
  if (row$term_label == "(Intercept)") return("intrcpt")
  row$term_label
}

metafor_build_fixed_effects <- function(terms_tbl, fit) {
  if (nrow(terms_tbl) == 0L) {
    return(tibble::tibble(
      submodel = character(0), term_label = character(0),
      variable = character(0), role = character(0),
      contrast_level = character(0), transform = character(0),
      symbol = character(0), coefficient_symbol = character(0),
      latex_term = character(0),
      estimate = double(0), std_error = double(0),
      confint_low = double(0), confint_high = double(0),
      excludes_zero = logical(0), ci_method = character(0)
    ))
  }
  beta_names <- rownames(fit$beta) %||% names(stats::coef(fit))
  estimate <- rep(NA_real_, nrow(terms_tbl))
  std_err  <- rep(NA_real_, nrow(terms_tbl))
  ci_low   <- rep(NA_real_, nrow(terms_tbl))
  ci_high  <- rep(NA_real_, nrow(terms_tbl))
  for (i in seq_len(nrow(terms_tbl))) {
    row <- terms_tbl[i, , drop = FALSE]
    if (is.na(row$coefficient_symbol)) next
    hit <- metafor_hit_name(row)
    j <- which(beta_names == hit)
    if (length(j) >= 1L) {
      estimate[i] <- as.numeric(fit$beta[j[[1L]], 1L])
      if (!is.null(fit$se)) std_err[i] <- as.numeric(fit$se[j[[1L]]])
      if (!is.null(fit$ci.lb)) ci_low[i]  <- as.numeric(fit$ci.lb[j[[1L]]])
      if (!is.null(fit$ci.ub)) ci_high[i] <- as.numeric(fit$ci.ub[j[[1L]]])
    }
  }
  excludes_zero <- !is.na(ci_low) & !is.na(ci_high) &
    sign(ci_low) == sign(ci_high) & ci_low != 0 & ci_high != 0
  tibble::tibble(
    submodel = terms_tbl$submodel,
    term_label = terms_tbl$term_label,
    variable = terms_tbl$variable,
    role = terms_tbl$role,
    contrast_level = terms_tbl$contrast_level,
    transform = terms_tbl$transform,
    symbol = terms_tbl$symbol,
    coefficient_symbol = terms_tbl$coefficient_symbol,
    latex_term = terms_tbl$latex_term,
    estimate = estimate,
    std_error = std_err,
    confint_low = ci_low,
    confint_high = ci_high,
    excludes_zero = excludes_zero,
    ci_method = rep("wald", nrow(terms_tbl))
  )
}

# Treat the between-study heterogeneity as a random-effect "group"
# called "study", with single intercept-only component. NULL when
# `tau^2` is exactly zero (fixed-effects meta-analysis).
metafor_build_re_per_entry <- function(fit) {
  if (is.null(fit$tau2) || fit$tau2 == 0) return(NULL)
  tibble::tibble(
    submodel    = "mu",
    term_label  = "(1 | study)",
    lhs_expr    = "1",
    group_var   = "study",
    component   = "(Intercept)",
    n_levels    = as.integer(fit$k %||% NA_integer_)
  )
}

# tau^2 appears as the variance component. Also report the (known)
# sampling-variance summary (mean v_i) for transparency.
metafor_build_variance_components <- function(fit) {
  rows <- list()
  tau2 <- as.numeric(fit$tau2 %||% NA_real_)
  if (!is.na(tau2)) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      parameter    = "mu",
      group        = "study",
      term         = "tau^2",
      sd_estimate  = sqrt(tau2),
      var_estimate = tau2,
      kind         = "heterogeneity"
    )
  }
  # Mean sampling variance as a known summary -- not estimated, but
  # reported for the reader's reference.
  if (!is.null(fit$vi)) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      parameter    = "mu",
      group        = "sampling",
      term         = "mean(v_i)",
      sd_estimate  = sqrt(mean(fit$vi, na.rm = TRUE)),
      var_estimate = mean(fit$vi, na.rm = TRUE),
      kind         = "sampling_variance"
    )
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(
      parameter = character(0), group = character(0), term = character(0),
      sd_estimate = double(0), var_estimate = double(0), kind = character(0)
    ))
  }
  do.call(rbind, rows)
}

metafor_build_warnings <- function(fit, sym_stub) {
  rows <- list()
  k <- fit$k %||% 0L
  if (k < 10L) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      code = "few_effect_sizes",
      severity = "warning",
      message = sprintf(
        "Only %d effect sizes -- tau^2 is poorly identified with k < 10. Consider a profile-likelihood CI on tau^2 (metafor::confint(fit, type = \"PL\")).",
        k
      )
    )
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(code = character(0), severity = character(0),
                          message = character(0)))
  }
  do.call(rbind, rows)
}
