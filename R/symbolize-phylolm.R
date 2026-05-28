# ----------------------------------------------------------------------------
# symbolize.phylolm
#
# v0.21.4 first-slice extractor for phylolm fits (Ho & Ane 2014). phylolm
# fits the phylogenetic-GLS marginal form:
#
#   y = X*beta + e,  e ~ N(0, sigma^2 * C(alpha))
#
# where C(alpha) is a tree-derived correlation matrix whose shape depends
# on the evolutionary model:
#
#   BM      C = A          (no free phylo parameter)
#   lambda  C(l) = l*A + (1-l)*I    (Pagel's lambda; l in [0, 1])
#   OU      C(a) = e^{-a*d_ij}      (mean-reversion rate a; tree-distance d)
#   EB      C(r)            (Early-Burst, rate r)
#   kappa   C(k)            (Grafen's kappa)
#   delta   C(d)            (Pagel's delta)
#   trend   directional drift
#
# This first slice surfaces BM + lambda. Other evolutionary models are
# accepted (the metadata fields surface fit$model and fit$optpar so the
# user can inspect them) but the marginalization-bridge prose in the
# assumption / interpretation rows is calibrated to BM + lambda only.
#
# Critically, phylolm does NOT have an explicit u_p random-effect tibble
# -- the phylogenetic signal lives entirely in the residual covariance.
# Downstream renderers should understand this via
# metadata$phylo_representation = "pgls_marginal".
#
# Object structure:
#
#   fit$coefficients        named numeric vector (Intercept, x, ...)
#   fit$vcov                p x p coefficient covariance (Wald SE diag)
#   fit$sigma2              scalar sigma^2 estimate
#   fit$optpar              numeric phylo parameter (NA / empty for BM)
#   fit$sigma2_error        additional measurement-error variance (0 unless
#                           measurement_error = TRUE)
#   fit$y, fit$X            response + design matrix (n x p)
#   fit$fitted.values       length n
#   fit$residuals           length n
#   fit$n, fit$d            n_obs, n_predictors
#   fit$model               "BM" / "lambda" / "OUrandomRoot" / ...
#   fit$formula             y ~ x formula
#   fit$call, fit$logLik    bookkeeping
#   fit$mean.tip.height     tree summary
#
# Data not stored on fit -- pass `data = ...` explicitly OR rely on
# fit$model.frame (which phylolm DOES populate, unlike MCMCglmm).
# ----------------------------------------------------------------------------

#' Symbolize a phylolm fit (Gaussian PGLS, v0.21.4 first slice)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from a `phylolm`
#' object. v0.21.4 covers BM and Pagel's lambda evolutionary models;
#' OU / EB / kappa / delta / trend produce a `symbolized_model` but
#' carry the model name in `metadata$phylo_model` for downstream
#' diagnostics rather than full template support.
#'
#' phylolm fits the PGLS marginal form `y = X*beta + e, e ~ N(0, sigma^2 *
#' C(alpha))` where `C(alpha)` is a tree-derived correlation matrix. There
#' is no explicit `u_p` random-effect — the phylogenetic signal lives
#' entirely in the residual covariance. `metadata$phylo_representation`
#' is set to `"pgls_marginal"` so downstream renderers can phrase this
#' correctly.
#'
#' @section Confidence intervals:
#' phylolm reports Wald-type standard errors via `vcov(fit)`. The
#' `confint_low` / `confint_high` columns of `fixed_effects` are
#' computed as `estimate +/- 1.96 * std_error`, and `ci_method` is set
#' to `"wald"`.
#'
#' @inheritParams symbolize
#' @param data Optional data frame. If `NULL`, falls back to
#'   `fit$model.frame` (phylolm stores it there).
#'
#' @references
#' Ho, L.S.T. & Ané, C. (2014). A linear-time algorithm for Gaussian
#' and non-Gaussian trait evolution models. *Systematic Biology*,
#' 63(3), 397-408.
#'
#' Tung Ho, L.S. & Ané, C. (2014). Intrinsic inference difficulties for
#' trait evolution with Ornstein-Uhlenbeck models. *Methods in Ecology
#' and Evolution*, 5(11), 1133-1146.
#'
#' @return A `symbolized_model` object.
#' @export
symbolize.phylolm <- function(fit, symbols = NULL, units = NULL,
                              context = NULL, data = NULL, ...) {
  if (!requireNamespace("phylolm", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg phylolm} is needed to symbolize this fit.",
      i = "Install it with {.code install.packages(\"phylolm\")}."
    ))
  }
  if (is.null(data)) {
    # phylolm stores the model frame on the fit (unlike MCMCglmm).
    data <- fit$model.frame
    if (is.null(data)) {
      cli::cli_abort(c(
        "{.arg data} is required: {.code fit$model.frame} is empty.",
        i = "Pass the data frame used to fit explicitly."
      ))
    }
  }
  family <- "gaussian"
  capability_check("phylolm", family, "mu")

  cond_form <- fit$formula
  if (is.null(cond_form)) {
    cli::cli_abort("Could not resolve {.code fit$formula}.")
  }
  response <- all.vars(cond_form[[2L]])[[1L]]
  if (!nzchar(response)) {
    cli::cli_abort("Could not resolve response variable from the phylolm formula.")
  }
  n_obs <- as.integer(fit$n %||% nrow(data))

  entries <- list(
    list(
      dpar = "mu",
      response = response,
      rhs = phylolm_rhs_expr(cond_form),
      expr = cond_form,
      position = 1L
    )
  )

  # phylolm has NO random-effects bar -- phylo signal is in the residual.
  re_per_entry <- list(NULL)

  param <- get_parameterization(family)
  index <- list(observation = "i", individual = "j",
                group = "g", trait = "k", time = "t")

  response_symbol <- phylolm_resolve_response_symbol(response, symbols)
  response_symbol_matrix <- drm_response_symbol_matrix(response_symbol)
  response_units <- drm_resolve_units(response, units)

  model <- list(
    class = "phylolm",
    package = "phylolm",
    family = family,
    response = response,
    n_obs = n_obs
  )

  entries_fe <- entries  # no RE bar to strip
  link <- "identity"

  distribution <- drm_build_distribution(
    family, response_symbol, response_symbol_matrix,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )
  submodels <- phylolm_build_submodels(entries, fit, param, link)
  terms_tbl <- drm_build_terms(entries_fe, data, symbols)
  fixed_eff <- phylolm_build_fixed_effects(terms_tbl, fit)
  re_tbl    <- NULL
  vc_tbl    <- phylolm_build_variance_components(fit)
  cov_tbl   <- drm_build_covariance_components(re_tbl)

  # phylolm fits are always phylo (the phylogeny is the residual
  # structure). The structured-matrix bookkeeping mirrors MCMCglmm /
  # brms / drmTMB so downstream renderers treat A consistently.
  detected_signals <- "phylo"
  structured_matrices <- list(list(
    symbol             = "\\mathbf{A}",
    symbol_matrix      = "\\mathbf{A}",
    variable           = "species",
    units              = NA_character_,
    role               = "structured_correlation_phylo",
    dimension          = "\\mathbb{R}^{k \\times k}",
    dimension_concrete = sprintf("\\mathbb{R}^{%d \\times %d}", n_obs, n_obs),
    description        = sprintf(
      "phylogenetic correlation matrix on tip species (k = %d), embedded in the residual covariance under phylolm's %s evolutionary model (PGLS marginal form)",
      n_obs, fit$model
    )
  ))

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
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_,
    structured_matrices = structured_matrices
  )
  assumptions <- drm_build_assumptions(
    family, response, response_symbol, re_tbl,
    response_1 = response, response_2 = NA_character_,
    detected_signals = detected_signals
  )
  interp <- drm_build_interpretation(
    fixed_eff, family, response, data,
    response_1 = response, response_2 = NA_character_,
    detected_signals = detected_signals
  )
  bridge <- drm_build_formula_bridge(
    entries, components, response,
    response_1 = response, response_2 = NA_character_
  )
  # phylolm gives us a clean, complete expanded block straight from the fit.
  expanded <- list(
    y         = as.numeric(fit$y),
    X         = fit$X,
    Z         = NULL,
    beta      = as.numeric(fit$coefficients),
    u         = NULL,
    fitted    = as.numeric(fit$fitted.values),
    residuals = as.numeric(fit$residuals)
  )

  phylo_param <- if (length(fit$optpar) > 0L && is.numeric(fit$optpar[[1L]])) {
    as.numeric(fit$optpar[[1L]])
  } else {
    NA_real_
  }
  metadata <- list(
    call = fit$call,
    context = context %||% "",
    ci_method = "wald",
    fit = fit,
    package_versions = list(
      symbolizer = utils::packageVersion("symbolizer"),
      phylolm    = utils::packageVersion("phylolm")
    ),
    phylo_representation = "pgls_marginal",
    phylo_model = fit$model,
    phylo_param = phylo_param,
    detected_signals = detected_signals,
    created_by = "symbolize.phylolm"
  )

  warnings_tbl <- tibble::tibble(
    code = character(0), severity = character(0),
    message = character(0), context = character(0)
  )

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

phylolm_rhs_expr <- function(f) {
  if (length(f) == 3L) f[[3L]] else f[[2L]]
}

phylolm_resolve_response_symbol <- function(response, symbols) {
  if (!is.null(symbols) && !is.null(symbols[[response]])) {
    return(as.character(symbols[[response]]))
  }
  esc <- gsub("_", "\\_", response, fixed = TRUE)
  if (nchar(response) > 1L) {
    paste0("\\mathrm{", esc, "}_i")
  } else {
    paste0(esc, "_i")
  }
}

phylolm_build_submodels <- function(entries, fit, param, link_mu) {
  rows <- lapply(entries, function(e) {
    dpar <- e$dpar
    coef_family <- drm_coef_family_for(dpar)
    link <- if (dpar == "mu") link_mu else "log"
    f <- stats::as.formula(paste("~", paste(deparse(e$rhs), collapse = " ")))
    tibble::tibble(
      parameter = dpar,
      formula = list(f),
      link = link,
      coef_family = coef_family,
      position = e$position
    )
  })
  do.call(rbind, rows)
}

# Fixed-effects tibble. phylolm's vcov(fit) gives the Wald covariance;
# SEs are sqrt(diag(vcov)). 95% CIs are estimate +/- 1.96 * SE.
phylolm_build_fixed_effects <- function(terms_tbl, fit) {
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
  coefs <- fit$coefficients
  ses   <- sqrt(diag(fit$vcov))
  estimate <- rep(NA_real_, nrow(terms_tbl))
  std_err  <- rep(NA_real_, nrow(terms_tbl))
  for (i in seq_len(nrow(terms_tbl))) {
    row <- terms_tbl[i, , drop = FALSE]
    if (is.na(row$coefficient_symbol)) next
    hit <- phylolm_hit_name(row)
    j <- which(names(coefs) == hit)
    if (length(j) >= 1L) {
      estimate[i] <- as.numeric(coefs[[j[[1L]]]])
      std_err[i]  <- as.numeric(ses[[j[[1L]]]])
    }
  }
  z <- stats::qnorm(0.975)
  ci_low  <- estimate - z * std_err
  ci_high <- estimate + z * std_err
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

phylolm_hit_name <- function(row) {
  if (row$term_label == "(Intercept)") return("(Intercept)")
  if (row$role == "factor_contrast" &&
      !is.na(row$contrast_level) && nzchar(row$contrast_level)) {
    return(paste0(row$variable, row$contrast_level))
  }
  if (row$role == "interaction" &&
      !is.na(row$contrast_level) && nzchar(row$contrast_level)) {
    pieces <- strsplit(row$term_label,    ":", fixed = TRUE)[[1L]]
    levels <- strsplit(row$contrast_level, ":", fixed = TRUE)[[1L]]
    if (length(levels) < length(pieces)) {
      levels <- c(levels, rep("", length(pieces) - length(levels)))
    }
    mm <- vapply(seq_along(pieces), function(k) {
      lv <- levels[[k]]
      if (is.na(lv) || !nzchar(lv) || identical(lv, "-")) pieces[[k]]
      else paste0(pieces[[k]], lv)
    }, character(1L))
    return(paste(mm, collapse = ":"))
  }
  row$term_label
}

# Variance components. phylolm's marginal form has ONE primary variance
# component sigma^2 (the scale of the C(alpha) covariance), plus an
# optional sigma^2_error when measurement_error = TRUE.
phylolm_build_variance_components <- function(fit) {
  rows <- list()
  sigma2_est <- as.numeric(fit$sigma2)
  rows[[length(rows) + 1L]] <- tibble::tibble(
    parameter   = "residual",
    group       = "phylo",
    term        = "sigma^2 (phylogenetic)",
    sd_estimate = sqrt(sigma2_est),
    var_estimate = sigma2_est,
    kind        = "phylo"
  )
  sigma2_err <- as.numeric(fit$sigma2_error %||% 0)
  if (!is.na(sigma2_err) && sigma2_err > 0) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      parameter   = "residual",
      group       = "residual",
      term        = "sigma^2_error (measurement error)",
      sd_estimate = sqrt(sigma2_err),
      var_estimate = sigma2_err,
      kind        = "residual"
    )
  }
  do.call(rbind, rows)
}
