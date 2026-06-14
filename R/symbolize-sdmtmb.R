# ----------------------------------------------------------------------------
# symbolize.sdmTMB
#
# v0.12 First slice extractor for sdmTMB fits. Targets the Gaussian
# family with optional spatial random field (omega) and / or
# spatiotemporal field (epsilon). Non-Gaussian families and
# delta-models (two-component sdmTMB fits) are routed to the
# capability registry.
#
# The fitted sdmTMB object exposes (relevant pieces):
#
#   fit$formula             list of formula(s); usually length 1, length 2
#                           for delta models. v0.12 supports length 1.
#   fit$family$family       "gaussian" / "tweedie" / "binomial" / ...
#   fit$family$link         "identity" / "log" / ...
#   fit$data                data frame used to fit
#   fit$spatial             "on" / "off"
#   fit$spatiotemporal      "rw" / "ar1" / "iid" / "off"
#   fit$time                NULL if spatial only; character if spatiotemporal
#   sdmTMB::tidy(fit)            fixed-effects estimate / std.error / CI
#   sdmTMB::tidy(fit, "ran_pars") range / sigma_O (spatial SD) /
#                                 sigma_E (spatiotemporal SD) / phi / ...
#
# Symbol grammar:
#   omega(s_i) ~ GMRF(0, Q(kappa))                   (spatial field)
#   epsilon(s_i, t) ~ GMRF(0, Q(kappa))              (spatiotemporal)
# where Q(kappa) is the SPDE precision matrix and the range parameter
# kappa = sqrt(8) / range.
# ----------------------------------------------------------------------------

#' Symbolize an sdmTMB fit (Gaussian, v0.12 first slice)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from an
#' `sdmTMB` fit. v0.12 first slice covers Gaussian models with
#' optional spatial random field (`spatial = "on"`) and / or
#' spatiotemporal random field via the `time` argument. Non-Gaussian
#' families, delta models, and `spatial_varying` slopes are routed
#' through the capability registry.
#'
#' @section Confidence intervals:
#' Fixed-effect CIs come from `sdmTMB::tidy(fit)` (Wald, 95% by
#' default). Random-parameter CIs (range, spatial SD, spatiotemporal
#' SD) come from `sdmTMB::tidy(fit, "ran_pars")` and appear in
#' `variance_components`.
#'
#' @inheritParams symbolize
#'
#' @references
#' Anderson, S. C., Ward, E. J., English, P. A., & Barnett, L. A. K.
#' (2022). sdmTMB: an R package for fast, flexible, and user-friendly
#' generalized linear mixed effects models with spatial and
#' spatiotemporal random fields. *bioRxiv*.
#' \doi{10.1101/2022.03.24.485545}
#'
#' @return A `symbolized_model` object.
#' @export
symbolize.sdmTMB <- function(fit, symbols = NULL, units = NULL,
                             context = NULL, ...) {
  if (!requireNamespace("sdmTMB", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg sdmTMB} is needed to symbolize this fit.",
      i = "Install it with {.code install.packages(\"sdmTMB\")}."
    ))
  }
  family <- fit$family$family
  link   <- fit$family$link %||% "identity"
  # Delta / two-component fits (e.g. delta_gamma()) set fit$family$family to
  # a length-2 vector such as c("binomial", "Gamma"). Route those to the
  # delta_model capability gate (Planned or reserved) BEFORE the scalar
  # guards below, which would otherwise hit a length>1 vector in `||` and
  # abort with the opaque base-R "'length = 2' in coercion to 'logical(1)'".
  if (length(family) > 1L) {
    capability_check("sdmTMB", paste(family, collapse = "/"), "delta_model")
  }
  if (is.null(family) || !nzchar(family)) {
    cli::cli_abort("Could not resolve {.code fit$family$family}.")
  }
  capability_check("sdmTMB", family, "mu")

  has_spatial <- identical(fit$spatial, "on")
  has_spatiotemporal <- !is.null(fit$time) &&
    !identical(fit$spatiotemporal %||% "off", "off")
  if (has_spatial) capability_check("sdmTMB", family, "omega")
  if (has_spatiotemporal) capability_check("sdmTMB", family, "epsilon")

  # sdmTMB stores formulas as a list (length 2 for delta models). v0.12
  # supports length 1.
  forms <- fit$formula
  if (is.list(forms) && length(forms) > 1L) {
    capability_check("sdmTMB", family, "delta_model")
  }
  cond_form <- if (is.list(forms)) forms[[1L]] else forms
  response <- all.vars(cond_form[[2L]])[[1L]]
  data <- fit$data
  n_obs <- as.integer(nrow(data))

  entries <- list(
    list(
      dpar = "mu",
      response = response,
      rhs = sdmtmb_rhs_expr(cond_form),
      expr = cond_form,
      position = 1L
    )
  )

  param <- get_parameterization(family)
  index <- list(observation = "i", individual = "j",
                group = "g", site = "s", time = "t")

  response_symbol <- sdmtmb_resolve_response_symbol(response, symbols)
  response_symbol_matrix <- drm_response_symbol_matrix(response_symbol)
  response_units <- drm_resolve_units(response, units)

  model <- list(
    class = "sdmTMB",
    package = "sdmTMB",
    family = family,
    response = response,
    n_obs = n_obs,
    spatial = has_spatial,
    spatiotemporal = has_spatiotemporal
  )

  distribution <- drm_build_distribution(
    family, response_symbol, response_symbol_matrix,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )
  submodels  <- sdmtmb_build_submodels(entries, param, link)
  terms_tbl  <- drm_build_terms(entries, data, symbols)
  factor_cod <- build_factor_coding(data, terms_tbl, fit)
  fixed_eff  <- sdmtmb_build_fixed_effects(terms_tbl, fit)
  mesh_n     <- sdmtmb_mesh_n(fit)
  re_per_entry <- list(sdmtmb_build_re_per_entry(
    has_spatial, has_spatiotemporal, mesh_n = mesh_n
  ))
  re_tbl     <- drm_build_random_effects(re_per_entry)
  vc_tbl     <- sdmtmb_build_variance_components(fit, has_spatial, has_spatiotemporal)
  cov_tbl    <- drm_build_covariance_components(re_tbl)
  # Spatial / spatiotemporal fields are spatially-correlated Gaussian
  # random fields, NOT iid intercepts. Route their distribution lines and
  # symbol-dictionary entries through the structured-covariance machinery
  # (matrix symbol \boldsymbol{\Omega}) so no equation asserts independence.
  structured_matrix_for_group <-
    sdmtmb_structured_matrix_for_group(has_spatial, has_spatiotemporal)
  structured_matrices <-
    sdmtmb_structured_matrices(has_spatial, has_spatiotemporal, mesh_n)
  detected_signals <- if (has_spatial || has_spatiotemporal) "spatial" else character(0L)
  components <- drm_build_components(
    submodels, terms_tbl, re_tbl,
    response_symbol, response_symbol_matrix,
    family = family,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_,
    structured_matrix_for_group = structured_matrix_for_group
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
  # Tab 3 ("equations with data") needs the fixed-effects design matrix X,
  # the coefficient vector beta, and the linear predictor; without X the
  # stacked-matrix + worked-row block falls back to the "design matrix not
  # captured" placeholder (audit B1). `model.matrix(fit)` is the
  # fixed-effects design (it does NOT contain the spatial random field --
  # that is a structured-covariance block, surfaced separately), so
  # eta_hat = X*beta and mu_hat = link_inv(eta_hat) are the fixed-effects
  # prediction. The residual y - mu_hat then carries the spatial field +
  # observation noise, which keeps the Gaussian response equation closing
  # row-by-row. Each accessor is wrapped so a fit that cannot produce a
  # model matrix degrades to NULL (the prior behaviour).
  X_mat   <- tryCatch(stats::model.matrix(fit), error = function(e) NULL)
  beta    <- tryCatch(stats::coef(fit), error = function(e) NULL)
  eta_hat <- if (!is.null(X_mat) && !is.null(beta) &&
                 ncol(X_mat) == length(beta)) {
    drop(X_mat %*% beta)
  } else NULL
  mu_hat  <- if (is.null(eta_hat)) NULL else drm_apply_link_inverse(eta_hat, link)
  e_resid <- if (!is.null(mu_hat)) as.numeric(data[[response]]) - mu_hat else NULL
  expanded <- list(y = data[[response]], X = X_mat, Z = NULL,
                   beta = if (is.null(beta)) NULL else as.numeric(beta),
                   u = NULL, eta_hat = eta_hat, mu_hat = mu_hat, e = e_resid,
                   fitted = tryCatch(stats::fitted(fit), error = function(e) NULL),
                   residuals = e_resid)

  metadata <- list(
    call = fit$call,
    context = context %||% "",
    ci_method = "wald",
    fit = fit,
    package_versions = list(
      symbolizer = utils::packageVersion("symbolizer"),
      sdmTMB     = utils::packageVersion("sdmTMB")
    ),
    spatial = has_spatial,
    spatiotemporal = has_spatiotemporal,
    # Structured-dependence signals so the three-views renderer surfaces the
    # spatial covariance block (Cov(u) = sigma_O^2 Omega) in every view,
    # rather than treating the field as an unstructured iid intercept.
    spatial_representation = if (has_spatial || has_spatiotemporal) "gmrf_spde" else NULL,
    structured_matrix_for_group = structured_matrix_for_group,
    detected_signals = detected_signals,
    created_by = "symbolize.sdmTMB"
  )

  sym_stub <- list(
    model = model, metadata = metadata, random_effects = re_tbl
  )
  warnings_tbl <- sdmtmb_build_warnings(fit, sym_stub)

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
    factor_coding       = factor_cod,
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

sdmtmb_rhs_expr <- function(f) {
  if (length(f) == 3L) f[[3L]] else f[[2L]]
}

sdmtmb_resolve_response_symbol <- function(response, symbols) {
  if (!is.null(symbols) && !is.null(symbols[[response]])) {
    return(as.character(symbols[[response]]))
  }
  default_response_symbol(response)
}

sdmtmb_build_submodels <- function(entries, param, link_mu) {
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

# Fixed effects via sdmTMB::tidy(fit). Returns a tibble of
# (term, estimate, std.error, conf.low, conf.high).
sdmtmb_build_fixed_effects <- function(terms_tbl, fit) {
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
  td <- tryCatch(sdmTMB::tidy(fit, conf.int = TRUE, conf.level = 0.95),
                 error = function(e) NULL)
  if (is.null(td)) td <- data.frame(term = character(0))
  estimate <- rep(NA_real_, nrow(terms_tbl))
  std_err  <- rep(NA_real_, nrow(terms_tbl))
  ci_low   <- rep(NA_real_, nrow(terms_tbl))
  ci_high  <- rep(NA_real_, nrow(terms_tbl))
  for (i in seq_len(nrow(terms_tbl))) {
    row <- terms_tbl[i, , drop = FALSE]
    if (is.na(row$coefficient_symbol)) next
    hit <- sdmtmb_hit_name(row)
    j <- which(td$term == hit)
    if (length(j) >= 1L) {
      estimate[i] <- as.numeric(td$estimate[j[[1L]]])
      if ("std.error" %in% names(td)) {
        std_err[i] <- as.numeric(td$std.error[j[[1L]]])
      }
      if (all(c("conf.low", "conf.high") %in% names(td))) {
        ci_low[i]  <- as.numeric(td$conf.low[j[[1L]]])
        ci_high[i] <- as.numeric(td$conf.high[j[[1L]]])
      }
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

sdmtmb_hit_name <- function(row) {
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

# Number of spatial random-field knots (mesh vertices). This is the
# dimension of the spatial covariance matrix Omega; the field is mapped to
# the n observations via the SPDE projection matrix. Falls back to NA when
# the mesh vertex count cannot be read (rendered defensively downstream).
sdmtmb_mesh_n <- function(fit) {
  n <- tryCatch(fit$spde$mesh$n, error = function(e) NULL)
  if (is.null(n) || length(n) != 1L || !is.finite(n)) return(NA_integer_)
  as.integer(n)
}

# Render the spatial / spatiotemporal random fields in the same shape
# drm_build_random_effects() expects. Each field appears as a "group"
# with a single component (the intercept of the field). The covariance is
# NOT iid: it is a spatially-correlated Gaussian random field, surfaced via
# structured_matrix_for_group in symbolize.sdmTMB(). `n_levels` is the mesh
# vertex (knot) count so the matrix-form dimension reads concretely rather
# than leaking a literal NA. NULL when no random fields are present.
sdmtmb_build_re_per_entry <- function(has_spatial, has_spatiotemporal,
                                      mesh_n = NA_integer_) {
  rows <- list()
  if (has_spatial) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      submodel    = "mu",
      term_label  = "(1 | site)",
      lhs_expr    = "1",
      group_var   = "site",
      component   = "(Intercept)",
      n_levels    = mesh_n
    )
  }
  if (has_spatiotemporal) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      submodel    = "mu",
      term_label  = "(1 | site_time)",
      lhs_expr    = "1",
      group_var   = "site_time",
      component   = "(Intercept)",
      n_levels    = mesh_n
    )
  }
  if (length(rows) == 0L) return(NULL)
  do.call(rbind, rows)
}

# Map each present random field to its structured spatial covariance matrix
# symbol (\boldsymbol{\Omega}). This routes the matrix- and index-form
# random-effect distribution lines through drm_build_components()'s
# structured-covariance branch instead of the iid identity, so the spatial
# field is no longer mis-rendered as independence. NULL when no fields.
sdmtmb_structured_matrix_for_group <- function(has_spatial, has_spatiotemporal) {
  groups <- character(0L)
  if (has_spatial) groups <- c(groups, "site")
  if (has_spatiotemporal) groups <- c(groups, "site_time")
  if (length(groups) == 0L) return(NULL)
  stats::setNames(as.list(rep("\\boldsymbol{\\Omega}", length(groups))), groups)
}

# Symbol-dictionary rows for the spatial covariance matrix Omega, mirroring
# the phylogenetic-A rows other extractors emit. NULL when no fields.
sdmtmb_structured_matrices <- function(has_spatial, has_spatiotemporal, mesh_n) {
  dim_concrete <- if (is.na(mesh_n)) {
    "\\mathbb{R}^{m \\times m}"
  } else {
    sprintf("\\mathbb{R}^{%d \\times %d}", mesh_n, mesh_n)
  }
  out <- list()
  if (has_spatial) {
    out[[length(out) + 1L]] <- list(
      symbol             = "\\boldsymbol{\\Omega}",
      symbol_matrix      = "\\boldsymbol{\\Omega}",
      variable           = "site",
      units              = NA_character_,
      role               = "structured_correlation_spatial",
      dimension          = "\\mathbb{R}^{m \\times m}",
      dimension_concrete = dim_concrete,
      description        = "spatial correlation matrix of the Gaussian random field over the mesh knots (Matern field via the SPDE / GMRF approximation; range and marginal SD in the variance components)"
    )
  }
  if (has_spatiotemporal) {
    out[[length(out) + 1L]] <- list(
      symbol             = "\\boldsymbol{\\Omega}",
      symbol_matrix      = "\\boldsymbol{\\Omega}",
      variable           = "site_time",
      units              = NA_character_,
      role               = "structured_correlation_spatiotemporal",
      dimension          = "\\mathbb{R}^{m \\times m}",
      dimension_concrete = dim_concrete,
      description        = "spatial correlation matrix of the spatiotemporal Gaussian random field over the mesh knots at each time step (Matern field via the SPDE / GMRF approximation)"
    )
  }
  if (length(out) == 0L) return(NULL)
  out
}

# Variance components from sdmTMB::tidy(fit, "ran_pars"). Carries
# range, sigma_O (spatial SD), sigma_E (spatiotemporal SD), phi (when
# present for non-Gaussian families).
sdmtmb_build_variance_components <- function(fit, has_spatial, has_spatiotemporal) {
  rp <- tryCatch(sdmTMB::tidy(fit, "ran_pars"), error = function(e) NULL)
  rows <- list()
  if (!is.null(rp) && nrow(rp) > 0L) {
    for (i in seq_len(nrow(rp))) {
      tm <- as.character(rp$term[[i]])
      est <- as.numeric(rp$estimate[[i]])
      rows[[length(rows) + 1L]] <- tibble::tibble(
        parameter    = "mu",
        group        = sdmtmb_param_group(tm),
        term         = tm,
        # `range` is the Matern correlation distance (the lag at which spatial
        # correlation decays to ~0.13) -- a value biologists need to read the
        # spatial field, so carry its estimate. It is a distance, NOT a variance,
        # so it gets no var_estimate (kind = "spatial_range" labels it).
        sd_estimate  = if (tm %in% c("sigma_O", "sigma_E", "phi", "range")) est else NA_real_,
        var_estimate = if (tm %in% c("sigma_O", "sigma_E", "phi")) est ^ 2 else NA_real_,
        kind         = sdmtmb_param_kind(tm)
      )
    }
  }
  # Residual SD for Gaussian sdmTMB lives in phi.
  if (identical(fit$family$family, "gaussian") &&
      !is.null(rp) && "phi" %in% rp$term) {
    # Already added above; nothing more to do.
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(
      parameter = character(0), group = character(0), term = character(0),
      sd_estimate = double(0), var_estimate = double(0), kind = character(0)
    ))
  }
  do.call(rbind, rows)
}

sdmtmb_param_group <- function(term_name) {
  switch(term_name,
    range     = "spatial_field",
    sigma_O   = "spatial_field",
    sigma_E   = "spatiotemporal_field",
    phi       = "residual",
    tweedie_p = "family",
    "other"
  )
}

sdmtmb_param_kind <- function(term_name) {
  switch(term_name,
    sigma_O   = "spatial_random",
    sigma_E   = "spatiotemporal_random",
    range     = "spatial_range",
    phi       = "residual",
    tweedie_p = "family",
    "other"
  )
}

sdmtmb_build_warnings <- function(fit, sym_stub) {
  rows <- list()
  if (isTRUE(fit$bad_eig %||% FALSE)) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      code = "bad_eig",
      severity = "warning",
      message = "sdmTMB reports a bad-eigenvalue Hessian. Random-field standard errors may be unreliable.",
        context = ""
      )
  }
  if (!isTRUE(fit$pos_def_hessian %||% TRUE)) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      code = "non_pos_def_hessian",
      severity = "warning",
      message = "sdmTMB reports a non-positive-definite Hessian. Re-fit with a finer mesh or a stronger prior.",
        context = ""
      )
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(code = character(0), severity = character(0),
                          message = character(0), context = character(0)))
  }
  do.call(rbind, rows)
}
