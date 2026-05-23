# ----------------------------------------------------------------------------
# symbolize.drmTMB
#
# v0.1 extractor for the drmTMB Gaussian location-scale family with fixed
# effects. The real `drmTMB` fitted object exposes:
#
#   fit$formula$entries     list of submodel entries, each with
#                             $dpar, $response, $lhs, $rhs, $expr, $position
#   fit$family$family       e.g. "gaussian"
#   fit$family$link         e.g. "identity"  (drmTMB locks log link on sigma)
#   fit$coefficients        list, one named numeric per dpar
#   drmTMB::fixef(fit, dpar) accessor for the same per-dpar estimates
#   fit$data                the original data frame
#   fit$nobs                sample size
#   fit$random_effects      list; non-empty when (1 | group) is present
#   fit$call                the original drmTMB() call
#
# Renderers consume the returned `symbolized_model`. No renderer is allowed
# to parse formulas itself; this extractor is the single source of truth.
# ----------------------------------------------------------------------------

#' Symbolize a drmTMB fit (Gaussian location-scale, v0.1)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from a `drmTMB` fit.
#' v0.1 covers the Gaussian location-scale fixed-effects path; other families
#' and components return capability errors via [`capability_check()`].
#'
#' @inheritParams symbolize
#' @return A `symbolized_model` object.
#' @export
symbolize.drmTMB <- function(fit, symbols = NULL, units = NULL,
                             context = NULL, ...) {
  entries <- fit$formula$entries
  if (!is.list(entries) || length(entries) == 0L) {
    cli::cli_abort("{.arg fit} has no submodel entries in {.code fit$formula$entries}.")
  }
  family <- fit$family$family
  response <- entries[[1L]]$response
  if (is.na(response) || !nzchar(response)) {
    cli::cli_abort("Could not resolve the response variable from {.code fit$formula$entries[[1]]$response}.")
  }
  data <- fit$data
  n_obs <- as.integer(fit$nobs %||% nrow(data))

  for (e in entries) {
    capability_check("drmTMB", family, e$dpar)
  }

  re_per_entry <- lapply(entries, function(e) drm_re_terms(fit, e$dpar))
  has_re <- vapply(re_per_entry, function(x) !is.null(x), logical(1L))
  if (any(has_re)) {
    # v0.1 supports Gaussian random intercepts "(1 | group)" only.
    capability_check("drmTMB", family, "random_effects")
    for (i in which(has_re)) {
      drm_assert_supported_re(re_per_entry[[i]], entries[[i]]$dpar)
    }
  }

  param <- get_parameterization(family)
  index <- list(observation = "i", individual = "j",
                group = "g", trait = "k", time = "t")

  response_symbol <- drm_resolve_response_symbol(response, symbols)
  response_symbol_matrix <- drm_response_symbol_matrix(response_symbol)
  response_units <- drm_resolve_units(response, units)

  model <- list(
    class = "drmTMB",
    package = "drmTMB",
    family = family,
    response = response,
    n_obs = n_obs
  )

  # For fixed-effects extraction, strip RE terms from the rhs of any entry
  # that carries them. The RE structure itself is rebuilt separately below.
  entries_fe <- entries
  for (i in which(has_re)) {
    entries_fe[[i]]$rhs <- drm_strip_re_terms(entries[[i]]$rhs)
  }

  distribution <- drm_build_distribution(family, response_symbol,
                                         response_symbol_matrix)
  submodels    <- drm_build_submodels(entries, fit, param)
  terms_tbl    <- drm_build_terms(entries_fe, data, symbols)
  fixed_eff    <- drm_build_fixed_effects(terms_tbl, fit)
  re_tbl       <- drm_build_random_effects(re_per_entry)
  vc_tbl       <- drm_build_variance_components(re_per_entry)
  components   <- drm_build_components(submodels, terms_tbl, re_tbl,
                                       response_symbol, response_symbol_matrix)
  symbol_dict  <- drm_build_symbol_dictionary(
    terms_tbl, response, response_symbol, response_symbol_matrix,
    response_units, family, submodels, units, data, n_obs, re_tbl
  )
  assumptions  <- drm_build_assumptions(family, response, response_symbol, re_tbl)
  interp       <- drm_build_interpretation(fixed_eff, family, response, data)
  bridge       <- drm_build_formula_bridge(entries, components, response)
  expanded     <- drm_build_expanded(fit, re_per_entry, has_re)

  metadata <- list(
    call = fit$call,
    context = context %||% "",
    package_versions = list(
      symbolizer = utils::packageVersion("symbolizer"),
      drmTMB     = utils::packageVersion("drmTMB")
    ),
    created_by = "symbolize.drmTMB"
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
    symbol_dictionary   = symbol_dict,
    assumptions         = assumptions,
    components          = components,
    interpretation      = interp,
    formula_bridge      = bridge,
    expanded            = expanded,
    metadata            = metadata
  )
}

# ---- helpers ----------------------------------------------------------------

`%||%` <- function(a, b) if (is.null(a)) b else a

drm_rhs_has_random <- function(rhs) {
  txt <- paste(deparse(rhs), collapse = " ")
  grepl("\\|", txt, fixed = FALSE)
}

drm_re_terms <- function(fit, dpar) {
  re <- fit$random_effects[[dpar]]
  if (is.null(re) || is.null(re$terms) || length(re$terms) == 0L) return(NULL)
  term_labels <- names(re$terms)
  parsed <- lapply(term_labels, drm_parse_re_term)
  group_vars <- vapply(parsed, `[[`, character(1L), "group")
  lhs_expr   <- vapply(parsed, `[[`, character(1L), "lhs")
  n_levels   <- vapply(re$terms, length, integer(1L), USE.NAMES = FALSE)
  tibble::tibble(
    submodel    = dpar,
    term_label  = term_labels,
    lhs_expr    = lhs_expr,
    group_var   = group_vars,
    n_levels    = as.integer(n_levels)
  )
}

drm_parse_re_term <- function(term_label) {
  # Expect "(lhs | group)" -- strip outer parens, split on |.
  inner <- sub("^\\(\\s*", "", term_label)
  inner <- sub("\\s*\\)$", "", inner)
  parts <- strsplit(inner, "\\|", fixed = FALSE)[[1L]]
  if (length(parts) != 2L) {
    cli::cli_abort("Could not parse random-effect term {.val {term_label}}.")
  }
  list(lhs = trimws(parts[[1L]]), group = trimws(parts[[2L]]))
}

drm_assert_supported_re <- function(re_tbl, dpar) {
  unsupported <- re_tbl$lhs_expr != "1"
  if (any(unsupported)) {
    bad <- paste(re_tbl$term_label[unsupported], collapse = ", ")
    cli::cli_abort(c(
      "Random-effect term not yet supported in submodel {.val {dpar}}: {.val {bad}}.",
      i = "v0.1 First slice handles intercept-only random effects {.code (1 | group)} only."
    ))
  }
  if (dpar != "mu") {
    cli::cli_abort(c(
      "Random effects on submodel {.val {dpar}} not yet supported.",
      i = "v0.1 First slice handles random intercepts on the mu submodel only."
    ))
  }
  invisible(re_tbl)
}

drm_strip_re_terms <- function(rhs_expr) {
  txt <- paste(deparse(rhs_expr), collapse = " ")
  # Remove " + (...| ...)" / "(... | ...) + " / standalone "(... | ...)".
  txt <- gsub("\\+\\s*\\([^()]*\\|[^()]*\\)", "", txt)
  txt <- gsub("\\([^()]*\\|[^()]*\\)\\s*\\+", "", txt)
  txt <- gsub("\\([^()]*\\|[^()]*\\)", "", txt)
  txt <- trimws(txt)
  if (!nzchar(txt)) txt <- "1"
  parse(text = txt)[[1L]]
}

drm_coef_family_for <- function(dpar) {
  switch(
    dpar,
    mu      = "beta",
    sigma   = "gamma",
    nu      = "nu",
    cli::cli_abort("No coefficient symbol family defined for dpar {.val {dpar}}.")
  )
}

drm_link_for <- function(family, dpar, family_link) {
  if (dpar == "mu") return(family_link)
  if (dpar == "sigma") return("log")
  family_link
}

drm_param_greek <- function(dpar) {
  switch(
    dpar,
    mu = "\\mu", sigma = "\\sigma", nu = "\\nu",
    paste0("\\", dpar)
  )
}

drm_param_greek_bold <- function(dpar) {
  paste0("\\boldsymbol{", drm_param_greek(dpar), "}")
}

drm_design_matrix_symbol <- function(dpar) {
  switch(
    dpar,
    mu = "\\mathbf{X}",
    sigma = "\\mathbf{Z}",
    paste0("\\mathbf{X}_{", dpar, "}")
  )
}

drm_coef_vector_symbol <- function(coef_family) {
  paste0("\\boldsymbol{\\", coef_family, "}")
}

drm_response_symbol_matrix <- function(response_symbol) {
  # Strip a trailing _i and bold-face the (lower-cased) root.
  # Vectors are lowercase bold by convention: "W_i" -> "\mathbf{w}".
  root <- sub("_i$", "", response_symbol)
  paste0("\\mathbf{", tolower(root), "}")
}

drm_resolve_response_symbol <- function(response, symbols) {
  if (!is.null(symbols) && response %in% names(symbols)) {
    return(unname(symbols[[response]]))
  }
  paste0(response, "_i")
}

drm_resolve_units <- function(var, units) {
  if (!is.null(units) && var %in% names(units)) return(unname(units[[var]]))
  NA_character_
}

drm_response_symbol_j <- function(response_symbol) {
  if (grepl("_i$", response_symbol)) {
    sub("_i$", "_j", response_symbol)
  } else {
    paste0(response_symbol, "_j")
  }
}

drm_substitute <- function(s, mapping) {
  if (is.na(s)) return(s)
  for (key in names(mapping)) {
    s <- gsub(paste0("{", key, "}"), mapping[[key]], s, fixed = TRUE)
  }
  s
}

drm_format_estimate <- function(x, digits = 3L) {
  if (is.na(x)) return(NA_character_)
  formatC(x, digits = digits, format = "fg", flag = "#")
}

drm_entry_formula <- function(entry) {
  expr <- entry$expr
  if (inherits(expr, "formula")) return(expr)
  stats::as.formula(paste(deparse(expr), collapse = " "))
}

drm_entry_rhs_formula <- function(entry) {
  rhs_txt <- paste(deparse(entry$rhs), collapse = " ")
  stats::as.formula(paste("~", rhs_txt))
}

# ---- builders ---------------------------------------------------------------

drm_build_distribution <- function(family, response_symbol, response_symbol_matrix) {
  if (family != "gaussian") {
    cli::cli_abort("Distribution row not implemented for family {.val {family}}.")
  }
  tibble::tibble(
    family = family,
    response_symbol = response_symbol,
    response_symbol_matrix = response_symbol_matrix,
    parameters = "mu, sigma",
    latex = sprintf(
      "%s \\mid \\mu_i,\\, \\sigma_i \\sim \\mathrm{Normal}(\\mu_i,\\, \\sigma_i^2)",
      response_symbol
    ),
    latex_matrix = sprintf(
      "%s \\mid \\boldsymbol{\\mu},\\, \\boldsymbol{\\sigma} \\sim \\mathcal{N}(\\boldsymbol{\\mu},\\, \\mathrm{diag}(\\boldsymbol{\\sigma}^2))",
      response_symbol_matrix
    )
  )
}

drm_build_submodels <- function(entries, fit, param) {
  family_link <- fit$family$link
  rows <- lapply(entries, function(e) {
    dpar <- e$dpar
    f <- drm_entry_formula(e)
    link <- drm_link_for(fit$family$family, dpar, family_link)
    coef_family <- drm_coef_family_for(dpar)
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

drm_build_terms <- function(entries, data, symbols) {
  rows <- lapply(entries, function(e) {
    f <- drm_entry_rhs_formula(e)
    extract_terms(
      formula = f,
      data = data,
      submodel = e$dpar,
      symbols = symbols,
      coefficient_family = drm_coef_family_for(e$dpar)
    )
  })
  do.call(rbind, rows)
}

drm_build_fixed_effects <- function(terms_tbl, fit) {
  if (nrow(terms_tbl) == 0L) {
    return(tibble::tibble(
      submodel = character(0),
      term_label = character(0),
      variable = character(0),
      role = character(0),
      contrast_level = character(0),
      transform = character(0),
      symbol = character(0),
      coefficient_symbol = character(0),
      latex_term = character(0),
      estimate = double(0),
      std_error = double(0)
    ))
  }
  coef_for <- function(dpar) {
    cf <- fit$coefficients[[dpar]]
    if (is.null(cf)) cf <- drmTMB::fixef(fit, dpar = dpar)
    cf
  }
  estimate <- rep(NA_real_, nrow(terms_tbl))
  for (i in seq_len(nrow(terms_tbl))) {
    row <- terms_tbl[i, , drop = FALSE]
    if (is.na(row$coefficient_symbol)) next
    cf <- coef_for(row$submodel)
    if (row$term_label == "(Intercept)") {
      hit <- "(Intercept)"
    } else {
      # Match by model-matrix column name reconstructed from term_label.
      hit <- if (!is.na(row$contrast_level) && nzchar(row$contrast_level)) {
        # Single-factor contrast: variable + level
        if (row$role == "factor_contrast") {
          paste0(row$variable, row$contrast_level)
        } else {
          row$term_label
        }
      } else {
        row$term_label
      }
    }
    if (!is.null(cf) && hit %in% names(cf)) {
      estimate[i] <- unname(cf[hit])
    }
  }
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
    std_error = rep(NA_real_, nrow(terms_tbl))
  )
}

drm_build_expanded <- function(fit, re_per_entry, has_re) {
  y       <- fit$model$y
  X       <- fit$model$X$mu
  X_sigma <- fit$model$X$sigma
  beta    <- fit$coefficients$mu
  gamma   <- fit$coefficients$sigma
  mu_hat <- if (!is.null(X) && !is.null(beta)) drop(X %*% beta) else NULL
  sigma_hat <- if (!is.null(X_sigma) && !is.null(gamma)) {
    exp(drop(X_sigma %*% gamma))
  } else NULL
  e <- tryCatch(as.numeric(stats::residuals(fit)), error = function(...) NULL)
  Z_g <- NULL; u <- NULL
  if (any(has_re)) {
    re_info <- re_per_entry[[which(has_re)[1L]]]
    if (!is.null(re_info) && nrow(re_info) > 0L) {
      g_var <- re_info$group_var[[1L]]
      term_label <- re_info$term_label[[1L]]
      if (g_var %in% names(fit$data)) {
        levels_g <- levels(factor(fit$data[[g_var]]))
        Z_g <- stats::model.matrix(stats::reformulate(paste0("0+", g_var)),
                                   data = fit$data)
        # rename columns from `<g_var><level>` to bare level if possible
        cn <- colnames(Z_g)
        bare <- sub(paste0("^", g_var), "", cn)
        if (length(bare) == length(levels_g)) colnames(Z_g) <- bare
      }
      blups <- fit$random_effects$mu$terms[[term_label]]
      if (!is.null(blups)) u <- as.numeric(blups)
    }
  }
  list(
    y         = y,
    X         = X,
    beta      = if (is.null(beta)) NULL else as.numeric(beta),
    X_sigma   = X_sigma,
    gamma     = if (is.null(gamma)) NULL else as.numeric(gamma),
    Z_g       = Z_g,
    u         = u,
    e         = e,
    mu_hat    = mu_hat,
    sigma_hat = sigma_hat
  )
}

drm_build_random_effects <- function(re_per_entry) {
  filled <- Filter(Negate(is.null), re_per_entry)
  if (length(filled) == 0L) return(NULL)
  out <- do.call(rbind, filled)
  out$u_symbol_index <- sprintf("u_{%s(i)}", out$group_var)
  out$u_symbol_matrix <- "\\mathbf{u}"
  out$sigma_symbol <- sprintf("\\sigma_{%s}", out$group_var)
  out
}

drm_build_variance_components <- function(re_per_entry) {
  re <- drm_build_random_effects(re_per_entry)
  if (is.null(re)) return(NULL)
  tibble::tibble(
    submodel   = re$submodel,
    group_var  = re$group_var,
    parameter  = sprintf("sigma_%s", re$group_var),
    symbol     = re$sigma_symbol,
    n_levels   = re$n_levels,
    description = sprintf("between-%s standard deviation on %s",
                          re$group_var, re$submodel)
  )
}

drm_build_components <- function(submodels, terms_tbl, re_tbl, response_symbol,
                                  response_symbol_matrix) {
  rows <- list()
  rows[[1L]] <- tibble::tibble(
    name = "distribution",
    kind = "distribution",
    submodel = NA_character_,
    equation = sprintf(
      "%s \\mid \\mu_i,\\, \\sigma_i \\sim \\mathrm{Normal}(\\mu_i,\\, \\sigma_i^2)",
      response_symbol
    ),
    equation_matrix = sprintf(
      "%s \\mid \\boldsymbol{\\mu},\\, \\boldsymbol{\\sigma} \\sim \\mathcal{N}(\\boldsymbol{\\mu},\\, \\mathrm{diag}(\\boldsymbol{\\sigma}^2))",
      response_symbol_matrix
    ),
    status = "stated"
  )
  for (i in seq_len(nrow(submodels))) {
    dpar <- submodels$parameter[[i]]
    link <- submodels$link[[i]]
    coef_family <- submodels$coef_family[[i]]
    sub_terms <- terms_tbl[terms_tbl$submodel == dpar, , drop = FALSE]
    coef_terms <- sub_terms[!is.na(sub_terms$coefficient_symbol), , drop = FALSE]
    offset_terms <- sub_terms[sub_terms$role == "offset", , drop = FALSE]
    rhs <- if (nrow(coef_terms) > 0L) {
      paste(coef_terms$latex_term, collapse = " + ")
    } else {
      ""
    }
    if (nrow(offset_terms) > 0L) {
      rhs <- paste(c(rhs, offset_terms$latex_term), collapse = " + ")
    }
    greek <- drm_param_greek(dpar)
    greek_bold <- drm_param_greek_bold(dpar)
    X_sym <- drm_design_matrix_symbol(dpar)
    coef_vec <- drm_coef_vector_symbol(coef_family)
    apply_link <- function(target, link) {
      switch(
        link,
        identity = target,
        log      = paste0("\\log(", target, ")"),
        logit    = paste0("\\mathrm{logit}(", target, ")"),
        paste0("\\mathrm{", link, "}(", target, ")")
      )
    }
    lhs_idx <- apply_link(paste0(greek, "_i"), link)
    lhs_mat <- apply_link(greek_bold, link)
    rhs_mat <- paste0(X_sym, " ", coef_vec)
    if (nrow(offset_terms) > 0L) {
      # Offset enters the linear predictor as-is in matrix form too.
      rhs_mat <- paste(c(rhs_mat, offset_terms$latex_term), collapse = " + ")
    }
    # RE contribution to this submodel's linear predictor.
    re_for_dpar <- if (!is.null(re_tbl)) {
      re_tbl[re_tbl$submodel == dpar, , drop = FALSE]
    } else NULL
    if (!is.null(re_for_dpar) && nrow(re_for_dpar) > 0L) {
      re_idx <- paste(re_for_dpar$u_symbol_index, collapse = " + ")
      rhs <- if (nzchar(rhs)) paste(rhs, "+", re_idx) else re_idx
      re_mat <- paste(re_for_dpar$u_symbol_matrix, collapse = " + ")
      rhs_mat <- if (nzchar(rhs_mat)) paste(rhs_mat, "+", re_mat) else re_mat
    }
    rows[[length(rows) + 1L]] <- tibble::tibble(
      name = paste0(dpar, "_linear_predictor"),
      kind = "linear_predictor",
      submodel = dpar,
      equation = paste(lhs_idx, "=", rhs),
      equation_matrix = paste(lhs_mat, "=", rhs_mat),
      status = "stated"
    )
  }
  # Random-effect distribution row(s).
  if (!is.null(re_tbl)) {
    for (i in seq_len(nrow(re_tbl))) {
      g <- re_tbl$group_var[[i]]
      sym <- re_tbl$sigma_symbol[[i]]
      rows[[length(rows) + 1L]] <- tibble::tibble(
        name = sprintf("%s_random_intercept_%s", re_tbl$submodel[[i]], g),
        kind = "random_effect_distribution",
        submodel = re_tbl$submodel[[i]],
        equation = sprintf("u_{%s} \\sim \\mathcal{N}(0,\\, %s^2)", g, sym),
        equation_matrix = sprintf(
          "\\mathbf{u}_{%s} \\sim \\mathcal{N}(\\mathbf{0},\\, %s^2 \\mathbf{I}_{%d})",
          g, sym, re_tbl$n_levels[[i]]
        ),
        status = "stated"
      )
    }
  }
  do.call(rbind, rows)
}

drm_build_symbol_dictionary <- function(terms_tbl, response, response_symbol,
                                        response_symbol_matrix,
                                        response_units, family, submodels,
                                        units, data, n_obs, re_tbl = NULL) {
  # Helper: per-submodel coefficient count (for concrete p_mu / p_sigma).
  p_for <- function(dpar) {
    sum(terms_tbl$submodel == dpar &
          !is.na(terms_tbl$coefficient_symbol))
  }
  rows <- list()
  rows[[1L]] <- tibble::tibble(
    symbol = response_symbol,
    symbol_matrix = response_symbol_matrix,
    variable = response,
    units = response_units,
    role = "response",
    dimension = "\\mathbb{R}^n",
    dimension_concrete = sprintf("\\mathbb{R}^{%d}", n_obs),
    description = "response variable"
  )
  predictors <- terms_tbl[
    !is.na(terms_tbl$variable) &
      terms_tbl$role %in% c("predictor", "factor_contrast",
                            "transformation", "offset"),
    , drop = FALSE
  ]
  predictors <- predictors[!duplicated(predictors$variable), , drop = FALSE]
  for (i in seq_len(nrow(predictors))) {
    p <- predictors[i, , drop = FALSE]
    var <- p$variable
    cls <- if (var %in% names(data)) class(data[[var]])[[1L]] else NA_character_
    desc <- switch(
      p$role,
      factor_contrast = if (!is.na(cls)) {
        sprintf("factor (%s)", paste(levels(factor(data[[var]])), collapse = ", "))
      } else "factor",
      offset = "offset (no coefficient)",
      transformation = sprintf("predictor (%s-transformed)", p$transform),
      "continuous predictor"
    )
    dim_abs <- if (identical(p$role, "offset")) {
      "\\mathbb{R}^n"
    } else {
      "column of design matrix"
    }
    dim_con <- if (identical(p$role, "offset")) {
      sprintf("\\mathbb{R}^{%d}", n_obs)
    } else {
      sprintf("column of X (length %d)", n_obs)
    }
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = p$symbol,
      symbol_matrix = NA_character_,
      variable = var,
      units = drm_resolve_units(var, units),
      role = if (p$role == "factor_contrast") "factor" else p$role,
      dimension = dim_abs,
      dimension_concrete = dim_con,
      description = desc
    )
  }
  # Parameter symbols (per submodel): scalar mu_i / sigma_i + bold vector form.
  for (i in seq_len(nrow(submodels))) {
    dpar <- submodels$parameter[[i]]
    greek <- drm_param_greek(dpar)
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = paste0(greek, "_i"),
      symbol_matrix = drm_param_greek_bold(dpar),
      variable = NA_character_,
      units = NA_character_,
      role = "parameter",
      dimension = "\\mathbb{R}^n",
      dimension_concrete = sprintf("\\mathbb{R}^{%d}", n_obs),
      description = sprintf("conditional %s of %s", dpar, response)
    )
  }
  # Coefficients (per submodel): scalar beta_0, beta_1 + bold vector form.
  for (i in seq_len(nrow(submodels))) {
    dpar <- submodels$parameter[[i]]
    cf <- submodels$coef_family[[i]]
    n_coef <- p_for(dpar)
    if (n_coef == 0L) next
    indices <- paste0("\\", cf, "_{", seq.int(0L, n_coef - 1L), "}")
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = paste(indices, collapse = ", "),
      symbol_matrix = drm_coef_vector_symbol(cf),
      variable = NA_character_,
      units = NA_character_,
      role = "coefficient",
      dimension = sprintf("\\mathbb{R}^{p_\\%s}", dpar),
      dimension_concrete = sprintf("\\mathbb{R}^{%d}", n_coef),
      description = sprintf("%s submodel coefficients", dpar)
    )
  }
  # Matrix-only structural symbols: design matrices, one per submodel.
  for (i in seq_len(nrow(submodels))) {
    dpar <- submodels$parameter[[i]]
    n_coef <- p_for(dpar)
    if (n_coef == 0L) next
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = NA_character_,
      symbol_matrix = drm_design_matrix_symbol(dpar),
      variable = NA_character_,
      units = NA_character_,
      role = "design_matrix",
      dimension = sprintf("\\mathbb{R}^{n \\times p_\\%s}", dpar),
      dimension_concrete = sprintf("\\mathbb{R}^{%d \\times %d}", n_obs, n_coef),
      description = sprintf("%s submodel design matrix", dpar)
    )
  }
  # Random-effect symbols (intercept-only first slice).
  if (!is.null(re_tbl)) {
    for (i in seq_len(nrow(re_tbl))) {
      g <- re_tbl$group_var[[i]]
      G <- re_tbl$n_levels[[i]]
      rows[[length(rows) + 1L]] <- tibble::tibble(
        symbol             = re_tbl$u_symbol_index[[i]],
        symbol_matrix      = sprintf("\\mathbf{u}_{%s}", g),
        variable           = g,
        units              = NA_character_,
        role               = "random_intercept",
        dimension          = sprintf("scalar; \\mathbb{R}^{G_{%s}} in matrix form", g),
        dimension_concrete = sprintf("scalar; \\mathbb{R}^{%d} in matrix form", G),
        description        = sprintf("random intercept by %s", g)
      )
      rows[[length(rows) + 1L]] <- tibble::tibble(
        symbol             = re_tbl$sigma_symbol[[i]],
        symbol_matrix      = re_tbl$sigma_symbol[[i]],
        variable           = NA_character_,
        units              = NA_character_,
        role               = "variance_component",
        dimension          = "scalar",
        dimension_concrete = "scalar",
        description        = sprintf("between-%s standard deviation", g)
      )
    }
  }
  do.call(rbind, rows)
}

drm_build_assumptions <- function(family, response, response_symbol,
                                  re_tbl = NULL) {
  tbl <- load_template("assumption-templates")
  rows <- tbl[tbl$family == family, , drop = FALSE]
  if (nrow(rows) == 0L) {
    cli::cli_abort("No assumption template rows for family {.val {family}}.")
  }
  has_re <- !is.null(re_tbl) && nrow(re_tbl) > 0L
  drop_assumption <- if (has_re) "independence" else "independence_given_random_effects"
  rows <- rows[rows$assumption != drop_assumption, , drop = FALSE]
  mapping <- list(
    response = response,
    response_symbol = response_symbol,
    response_symbol_j = drm_response_symbol_j(response_symbol)
  )
  expr <- vapply(rows$expression_latex, drm_substitute,
                 character(1L), mapping = mapping, USE.NAMES = FALSE)
  meaning <- vapply(rows$biological_meaning, drm_substitute,
                    character(1L), mapping = mapping, USE.NAMES = FALSE)
  tibble::tibble(
    family = rows$family,
    submodel = rows$submodel,
    assumption = rows$assumption,
    expression_latex = expr,
    biological_meaning = meaning,
    status = rows$status
  )
}

drm_role_to_interp <- function(role) {
  switch(
    role,
    intercept = "intercept",
    predictor = "slope",
    factor_contrast = "factor_contrast",
    transformation = "transformation",
    NA_character_  # interactions, offsets: no v0.1 template
  )
}

drm_build_interpretation <- function(fixed_eff, family, response, data) {
  if (nrow(fixed_eff) == 0L) {
    return(tibble::tibble(
      submodel = character(0),
      term_label = character(0),
      coefficient_role = character(0),
      estimate = double(0),
      link_scale_reading = character(0),
      natural_scale_reading = character(0),
      variance_scale_reading = character(0),
      biological_reading = character(0)
    ))
  }
  tbl <- load_template("interpretation-templates")
  rows <- list()
  for (i in seq_len(nrow(fixed_eff))) {
    r <- fixed_eff[i, , drop = FALSE]
    cr <- drm_role_to_interp(r$role)
    if (is.na(cr)) next
    template <- tbl[
      tbl$family == family &
        tbl$submodel == r$submodel &
        tbl$coefficient_role == cr,
      , drop = FALSE
    ]
    if (nrow(template) == 0L) next
    predictor <- if (is.na(r$variable)) "" else r$variable
    level <- if (is.na(r$contrast_level)) "" else r$contrast_level
    transform <- if (is.na(r$transform)) "" else r$transform
    coef_str <- drm_format_estimate(r$estimate)
    mapping <- list(
      response = response,
      predictor = predictor,
      level = level,
      transform = transform,
      coef = coef_str %||% ""
    )
    rows[[length(rows) + 1L]] <- tibble::tibble(
      submodel = r$submodel,
      term_label = r$term_label,
      coefficient_role = cr,
      estimate = r$estimate,
      link_scale_reading = drm_substitute(template$link_scale_reading[[1L]], mapping),
      natural_scale_reading = drm_substitute(template$natural_scale_reading[[1L]], mapping),
      variance_scale_reading = drm_substitute(template$variance_scale_reading[[1L]], mapping),
      biological_reading = drm_substitute(template$biological_reading[[1L]], mapping)
    )
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(
      submodel = character(0),
      term_label = character(0),
      coefficient_role = character(0),
      estimate = double(0),
      link_scale_reading = character(0),
      natural_scale_reading = character(0),
      variance_scale_reading = character(0),
      biological_reading = character(0)
    ))
  }
  do.call(rbind, rows)
}

drm_build_formula_bridge <- function(entries, components, response) {
  rows <- lapply(entries, function(e) {
    dpar <- e$dpar
    r_syntax <- paste(deparse(drm_entry_formula(e)), collapse = " ")
    sel <- components$submodel == dpar & !is.na(components$submodel)
    math_idx <- if (any(sel)) components$equation[sel][[1L]] else NA_character_
    math_mat <- if (any(sel)) components$equation_matrix[sel][[1L]] else NA_character_
    meaning <- if (dpar == "mu") {
      sprintf("Expected %s is a linear function of the mean-model predictors", response)
    } else if (dpar == "sigma") {
      sprintf("Log residual SD of %s is a linear function of the scale-model predictors", response)
    } else {
      sprintf("%s submodel", dpar)
    }
    tibble::tibble(
      submodel = dpar,
      r_syntax = r_syntax,
      statistical_meaning = meaning,
      mathematics = math_idx,
      mathematics_matrix = math_mat
    )
  })
  do.call(rbind, rows)
}
