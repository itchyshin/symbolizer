# ----------------------------------------------------------------------------
# symbolize.gllvmTMB
#
# v0.1 First slice extractor for the gllvmTMB Gaussian latent-variable family.
# Targets the canonical two-tier multivariate Normal model:
#
#   y_{ij}        ~ Normal(eta_{ij}, sigma_eps^2)             (row-level)
#   eta_{ij}      = mu_{t(j)} + (Lambda_B z_{B,i})_{t(j)}     (linear predictor)
#   z_{B,i}       ~ N(0, I_{d_B})                             (latent scores)
#   Sigma_B       = Lambda_B Lambda_B^T + Psi_B                (implied cov)
#
# where i indexes the unit (e.g. site / individual), j indexes the row, t(j)
# the trait of row j, k the latent axis, T the number of traits, and d_B the
# between-unit latent dimension.
#
# The fitted gllvmTMB object exposes:
#
#   fit$formula             value ~ 0 + trait (RHS used for fixed effects only;
#                            covstruct sugar is stored separately below).
#   fit$family$family       e.g. "gaussian"
#   fit$family$link         e.g. "identity"
#   fit$covstructs          list of covstruct entries, each with $kind (e.g.
#                             "rr" / "diag" / "phylo_rr" ...), $lhs, $group,
#                             $extra (with $d for latent-factor terms).
#   fit$trait_col,
#   fit$unit_col            column names in the long-format data frame.
#   fit$n_traits, fit$n_sites, fit$d_B   model dimensions.
#   fit$X_fix, fit$X_fix_names           per-row fixed-effects design matrix.
#   fit$report              named list: $Lambda_B, $Sigma_B, $sigma_eps, $sd_B,
#                             $eta, ...
#   fit$tmb_data$y          long-format response vector.
#   summary(fit$sd_report,
#           "fixed")        named matrix with rows like b_fix, theta_rr_B,
#                             log_sigma_eps -- carries point estimates + SEs.
#
# Renderers consume the returned `symbolized_model`. No renderer parses
# formulas; this extractor is the single source of truth for gllvmTMB.
# ----------------------------------------------------------------------------

#' Symbolize a gllvmTMB fit (Gaussian and binomial latent-variable models)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from a `gllvmTMB` fit.
#' Covers the Gaussian and binomial B-tier latent-variable families:
#' per-trait intercepts (`0 + trait`), the between-unit reduced-rank loading
#' term (`latent(0 + trait | unit, d = K)`), and the optional per-trait unique
#' variances (`unique(0 + trait | unit)`). Other families and covstructs
#' return capability errors via [`capability_check()`].
#'
#' @section Confidence intervals:
#' Fixed-effect estimates and Wald-style approximate CIs are pulled
#' from `summary(fit$sd_report, "fixed")`. Loadings
#' (`\boldsymbol{\Lambda}_B`) and the between-unit covariance
#' (`\boldsymbol{\Sigma}_B`) are point estimates;
#' parametric-bootstrap uncertainty via
#' `gllvmTMB::bootstrap_Sigma()` is on the deferred list.
#'
#' @inheritParams symbolize
#'
#' @references
#' Nakagawa, S. (forthcoming). `gllvmTMB`: Generalized linear latent-variable
#' models in TMB. <https://itchyshin.github.io/gllvmTMB/>
#'
#' @return A `symbolized_model` object.
#' @export
symbolize.gllvmTMB <- function(fit, symbols = NULL, units = NULL,
                               context = NULL, ...) {
  family <- fit$family$family
  if (!nzchar(family)) {
    cli::cli_abort("Could not resolve {.code fit$family$family}.")
  }
  capability_check("gllvmTMB", family, "mu")

  # Covstructs supported in v0.1
  cs <- fit$covstructs %||% list()
  cs_kinds <- vapply(cs, function(e) as.character(e$kind %||% NA), character(1L))
  cs_groups <- vapply(cs, function(e) {
    if (is.null(e$group)) return(NA_character_)
    paste(deparse(e$group), collapse = " ")
  }, character(1L))
  for (i in seq_along(cs)) {
    cap_for_kind <- glm_capability_for_covstruct(cs_kinds[[i]], cs_groups[[i]],
                                                 fit$unit_col)
    capability_check("gllvmTMB", family, cap_for_kind)
  }
  # sigma_eps is a meaningful row-level residual SD only for Gaussian
  # latent-variable models. For Bernoulli / Poisson / binomial etc. the
  # response distribution is determined by mu and there is no separate
  # residual-SD parameter even though fit$report$sigma_eps may exist as
  # a placeholder.
  if (identical(family, "gaussian") && !is.null(fit$report$sigma_eps)) {
    capability_check("gllvmTMB", family, "sigma_eps")
  }

  response <- glm_response_name(fit$formula)
  trait_col <- fit$trait_col
  unit_col  <- fit$unit_col
  if (!nzchar(response) || !nzchar(trait_col) || !nzchar(unit_col)) {
    cli::cli_abort("Could not resolve response / trait / unit columns from the fit.")
  }
  data <- fit$data
  n_obs   <- as.integer(NROW(fit$tmb_data$y) %||% nrow(data))
  n_traits <- as.integer(fit$n_traits %||% length(levels(factor(data[[trait_col]]))))
  n_sites  <- as.integer(fit$n_sites  %||% length(levels(factor(data[[unit_col]]))))
  d_B      <- as.integer(fit$d_B %||% 0L)

  trait_levels <- levels(factor(data[[trait_col]]))

  response_symbol_matrix <- glm_response_symbol_matrix(response, symbols)
  response_symbol_scalar <- "y_{ij}"
  response_units <- glm_resolve_units(response, units)

  # Map the upstream family ("gaussian", "binomial", ...) to a template
  # family name used by the assumption / interpretation CSVs.
  tpl_family <- gllvm_template_family(family)
  param <- get_parameterization(tpl_family)
  index <- list(observation = "j", unit = "i", trait = "t", latent = "k")

  model <- list(
    class = "gllvmTMB",
    package = "gllvmTMB",
    family = family,
    response = response,
    response_dim = list(rows = n_obs, traits = n_traits, units = n_sites,
                        latent = d_B),
    n_obs = n_obs
  )

  distribution <- glm_build_distribution(response_symbol_scalar,
                                         response_symbol_matrix,
                                         tpl_family = tpl_family,
                                         link = fit$family$link %||% "identity")
  submodels    <- glm_build_submodels(d_B)
  terms_tbl    <- glm_build_terms(fit, data, symbols, trait_levels)
  fixed_eff    <- glm_build_fixed_effects(terms_tbl, fit, trait_levels)
  loadings_tbl <- glm_build_loadings(fit, trait_levels)
  vc_tbl       <- glm_build_variance_components(fit)
  components   <- glm_build_components(
    response_symbol_scalar, response_symbol_matrix, d_B, fit
  )
  symbol_dict  <- glm_build_symbol_dictionary(
    terms_tbl, response, response_symbol_scalar, response_symbol_matrix,
    response_units, n_obs, n_traits, n_sites, d_B, units, data, fit
  )
  # v0.21+ structured-dependence signals (gllvmTMB). Covstruct kinds
  # phylo_rr / phylo_diag / phylo_scalar / phylo_slope map to "phylo";
  # spde / spatial map to "spatial". Package manages the matrix internally
  # so phylo_representation is tagged "package_managed".
  detected_signals <- character(0L)
  has_gllvm_phylo <- any(grepl("^phylo", cs_kinds))
  has_gllvm_spatial <- any(cs_kinds %in% c("spde", "spatial"))
  if (has_gllvm_phylo)   detected_signals <- c(detected_signals, "phylo")
  if (has_gllvm_spatial) detected_signals <- c(detected_signals, "spatial")
  assumptions  <- glm_build_assumptions(response, response_symbol_scalar,
                                        tpl_family = tpl_family,
                                        response_symbol_matrix, fit,
                                        detected_signals = detected_signals)
  interp       <- glm_build_interpretation(fixed_eff, loadings_tbl, response,
                                            tpl_family = tpl_family,
                                            detected_signals = detected_signals)
  bridge       <- glm_build_formula_bridge(fit, response, response_symbol_matrix,
                                           d_B)
  expanded     <- glm_build_expanded(fit, trait_levels)

  metadata <- list(
    call = fit$call %||% sys.call(),
    context = context %||% "",
    package_versions = list(
      symbolizer = utils::packageVersion("symbolizer"),
      gllvmTMB   = utils::packageVersion("gllvmTMB")
    ),
    phylo_representation = if (has_gllvm_phylo) "package_managed" else NULL,
    spatial_representation = if (has_gllvm_spatial) "package_managed" else NULL,
    detected_signals = detected_signals,
    created_by = "symbolize.gllvmTMB"
  )

  new_symbolized_model(
    model               = model,
    index               = index,
    parameterization    = param,
    distribution        = distribution,
    submodels           = submodels,
    terms               = terms_tbl,
    fixed_effects       = fixed_eff,
    random_effects      = NULL,
    variance_components = vc_tbl,
    loadings            = loadings_tbl,
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

# `%||%` already defined in symbolize-drmtmb.R; do not redefine.

glm_response_name <- function(formula) {
  if (!inherits(formula, "formula") || length(formula) < 3L) return("")
  paste(deparse(formula[[2L]]), collapse = " ")
}

glm_response_symbol_matrix <- function(response, symbols) {
  if (!is.null(symbols) && response %in% names(symbols)) {
    return(unname(symbols[[response]]))
  }
  "\\mathbf{Y}"
}

glm_resolve_units <- function(var, units) {
  if (!is.null(units) && var %in% names(units)) return(unname(units[[var]]))
  NA_character_
}

glm_capability_for_covstruct <- function(kind, group, unit_col) {
  if (!nzchar(group)) group <- ""
  is_unit <- identical(group, unit_col)
  switch(
    kind,
    rr     = if (is_unit) "Lambda_B" else "Lambda_W",
    diag   = if (is_unit) "Psi_B"    else "Psi_W",
    phylo_rr     = "phylo",
    phylo_diag   = "phylo",
    phylo_scalar = "phylo",
    phylo_slope  = "phylo",
    spde         = "spatial",
    spatial      = "spatial",
    equalto      = "Sigma",
    propto       = "Sigma",
    cli::cli_abort(c(
      "Unknown gllvmTMB covstruct kind {.val {kind}}.",
      i = "Add a row to {.file inst/extdata/capabilities.csv}."
    ))
  )
}

glm_has_unique_unit <- function(fit) {
  cs <- fit$covstructs %||% list()
  any(vapply(cs, function(e) {
    g_txt <- if (is.null(e$group)) "" else paste(deparse(e$group), collapse = " ")
    identical(e$kind, "diag") && identical(g_txt, fit$unit_col)
  }, logical(1L)))
}

glm_has_within_unit <- function(fit) {
  cs <- fit$covstructs %||% list()
  unit_col <- fit$unit_col %||% ""
  any(vapply(cs, function(e) {
    g_txt <- if (is.null(e$group)) "" else paste(deparse(e$group), collapse = " ")
    identical(e$kind, "rr") && !identical(g_txt, unit_col)
  }, logical(1L)))
}

# ---- builders ---------------------------------------------------------------

glm_build_distribution <- function(response_symbol, response_symbol_matrix,
                                   tpl_family = "gllvm_gaussian",
                                   link = "identity") {
  if (identical(tpl_family, "gllvm_binomial")) {
    return(tibble::tibble(
      family = tpl_family,
      response_symbol = response_symbol,
      response_symbol_matrix = response_symbol_matrix,
      parameters = "mu, Lambda_B, (Psi_B)",
      latex = paste0(
        response_symbol,
        " \\mid \\mu_{t(j)}, \\boldsymbol{\\Lambda}_B, \\mathbf{z}_{B,i} ",
        "\\sim \\mathrm{Bernoulli}(\\mathrm{logit}^{-1}(\\mu_{t(j)} + ",
        "(\\boldsymbol{\\Lambda}_B \\mathbf{z}_{B,i})_{t(j)}))"
      ),
      latex_matrix = paste0(
        response_symbol_matrix,
        " \\mid \\boldsymbol{\\mu}, \\boldsymbol{\\Lambda}_B, \\mathbf{Z}_B ",
        "\\sim \\mathrm{Bernoulli}(\\mathrm{logit}^{-1}(",
        "\\mathbf{1}_n \\boldsymbol{\\mu}^\\top + \\mathbf{Z}_B \\boldsymbol{\\Lambda}_B^\\top))"
      )
    ))
  }
  # Default: gllvm_gaussian shape.
  tibble::tibble(
    family = tpl_family,
    response_symbol = response_symbol,
    response_symbol_matrix = response_symbol_matrix,
    parameters = "mu, Lambda_B, sigma_eps, (Psi_B)",
    latex = paste0(
      response_symbol,
      " \\mid \\mu_{t(j)}, \\boldsymbol{\\Lambda}_B, \\mathbf{z}_{B,i},",
      " \\sigma_\\epsilon \\sim ",
      "\\mathrm{Normal}(\\mu_{t(j)} + (\\boldsymbol{\\Lambda}_B \\mathbf{z}_{B,i})_{t(j)},",
      " \\sigma_\\epsilon^2)"
    ),
    latex_matrix = paste0(
      response_symbol_matrix,
      " \\mid \\boldsymbol{\\mu}, \\boldsymbol{\\Lambda}_B, \\mathbf{Z}_B,",
      " \\sigma_\\epsilon \\sim ",
      "\\mathcal{MN}(\\mathbf{1}_n \\boldsymbol{\\mu}^\\top + \\mathbf{Z}_B \\boldsymbol{\\Lambda}_B^\\top,",
      " \\sigma_\\epsilon^2 \\mathbf{I}_n, \\mathbf{I}_T)"
    )
  )
}

# Map an upstream gllvmTMB family name (the string that gllvmTMB stores in
# fit$family$family) to the template-family slug used by the CSVs.
gllvm_template_family <- function(family) {
  switch(
    family,
    gaussian = "gllvm_gaussian",
    binomial = "gllvm_binomial",
    # Anything else falls through to gllvm_gaussian — but the capability
    # check earlier in symbolize.gllvmTMB will have errored already if the
    # family is not registered. Defensive default only.
    "gllvm_gaussian"
  )
}

glm_build_submodels <- function(d_B) {
  rows <- list(
    tibble::tibble(
      parameter = "mu",
      formula = list(stats::as.formula("~ 0 + trait")),
      link = "identity",
      coef_family = "mu",
      position = 1L
    )
  )
  if (d_B > 0L) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      parameter = "Lambda_B",
      formula = list(stats::as.formula("~ latent(0 + trait | unit)")),
      link = "identity",
      coef_family = "Lambda",
      position = 2L
    )
  }
  do.call(rbind, rows)
}

glm_build_terms <- function(fit, data, symbols, trait_levels) {
  trait_col <- fit$trait_col
  formula_mu <- stats::as.formula(paste0("~ 0 + ", trait_col))
  trait_factor <- factor(data[[trait_col]], levels = trait_levels)
  data_mu <- data.frame(trait_factor)
  names(data_mu) <- trait_col
  terms_mu <- extract_terms(
    formula = formula_mu,
    data = data_mu,
    submodel = "mu",
    symbols = symbols,
    coefficient_family = "mu"
  )
  # Override the auto-generated symbols/latex for per-trait intercepts so the
  # output matches the canonical gllvmTMB notation (mu_{trait_*}).
  if (nrow(terms_mu) > 0L) {
    terms_mu$role <- "trait_intercept"
    terms_mu$variable <- trait_col
    terms_mu$symbol <- paste0("\\mu_{", terms_mu$contrast_level, "}")
    terms_mu$coefficient_symbol <- paste0("\\mu_{", terms_mu$contrast_level, "}")
    terms_mu$latex_term <- terms_mu$coefficient_symbol
  }
  terms_mu
}

glm_build_fixed_effects <- function(terms_tbl, fit, trait_levels) {
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
  # Pull b_fix point estimates + std errors from sd_report
  est <- rep(NA_real_, nrow(terms_tbl))
  se  <- rep(NA_real_, nrow(terms_tbl))
  ss <- tryCatch(summary(fit$sd_report, "fixed"), error = function(...) NULL)
  if (!is.null(ss)) {
    bfix_idx <- which(rownames(ss) == "b_fix")
    if (length(bfix_idx) == nrow(terms_tbl)) {
      est <- unname(ss[bfix_idx, "Estimate"])
      se  <- unname(ss[bfix_idx, "Std. Error"])
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
    estimate = est,
    std_error = se
  )
}

glm_build_loadings <- function(fit, trait_levels) {
  L <- fit$report$Lambda_B
  if (is.null(L) || length(L) == 0L) return(NULL)
  L <- as.matrix(L)
  T_n <- nrow(L)
  d_B <- ncol(L)
  if (T_n == 0L || d_B == 0L) return(NULL)
  # Get standard errors of the free theta_rr_B entries
  ss <- tryCatch(summary(fit$sd_report, "fixed"), error = function(...) NULL)
  theta_se <- if (!is.null(ss)) {
    rows <- which(rownames(ss) == "theta_rr_B")
    if (length(rows) > 0L) unname(ss[rows, "Std. Error"]) else NULL
  } else NULL
  # Fill SE entry-by-entry following the lower-triangular free pattern.
  # The number of free entries per column k is T - k + 1 (lower-triangular),
  # but exploratory rr also uses a free first column for k = 1 (T entries),
  # so safest is: free entries are those where t >= k. Pin/zero entries are
  # the strict upper triangle. Map free entries in column-major order.
  se_mat <- matrix(NA_real_, T_n, d_B)
  if (!is.null(theta_se)) {
    free_idx <- 1L
    for (k in seq_len(d_B)) {
      for (t in seq_len(T_n)) {
        if (t < k) next
        if (free_idx <= length(theta_se)) {
          se_mat[t, k] <- theta_se[[free_idx]]
          free_idx <- free_idx + 1L
        }
      }
    }
  }
  trait_lab <- if (length(trait_levels) == T_n) trait_levels else paste0("trait_", seq_len(T_n))
  rows <- list()
  for (k in seq_len(d_B)) {
    for (t in seq_len(T_n)) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        submodel = "Lambda_B",
        matrix = "\\boldsymbol{\\Lambda}_B",
        trait = trait_lab[[t]],
        axis = sprintf("LV%d", k),
        trait_index = t,
        axis_index = k,
        symbol = sprintf("\\lambda_{B,%d%d}", t, k),
        estimate = L[t, k],
        std_error = se_mat[t, k]
      )
    }
  }
  do.call(rbind, rows)
}

glm_build_variance_components <- function(fit) {
  rows <- list()
  sigma_eps <- fit$report$sigma_eps
  if (!is.null(sigma_eps) && length(sigma_eps) > 0L) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      submodel = "sigma_eps",
      group_var = NA_character_,
      parameter = "sigma_eps",
      symbol = "\\sigma_\\epsilon",
      n_levels = NA_integer_,
      estimate = as.numeric(sigma_eps)[[1L]],
      description = "shared row-level residual SD"
    )
  }
  sd_B <- fit$report$sd_B
  if (!is.null(sd_B) && length(sd_B) > 0L) {
    n_t <- length(sd_B)
    for (t in seq_len(n_t)) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        submodel = "Psi_B",
        group_var = fit$unit_col,
        parameter = sprintf("psi_B_%d", t),
        symbol = sprintf("\\psi_{B,%d}", t),
        n_levels = NA_integer_,
        estimate = as.numeric(sd_B[[t]]),
        description = sprintf("between-%s unique SD for trait %d",
                              fit$unit_col, t)
      )
    }
  }
  if (length(rows) == 0L) return(NULL)
  do.call(rbind, rows)
}

glm_build_components <- function(response_symbol, response_symbol_matrix,
                                  d_B, fit) {
  rows <- list()
  # Distribution
  rows[[length(rows) + 1L]] <- tibble::tibble(
    name = "distribution",
    kind = "distribution",
    submodel = NA_character_,
    equation = paste0(
      response_symbol,
      " \\mid \\mu_{t(j)}, \\boldsymbol{\\Lambda}_B, \\mathbf{z}_{B,i},",
      " \\sigma_\\epsilon \\sim ",
      "\\mathrm{Normal}(\\mu_{t(j)} + (\\boldsymbol{\\Lambda}_B \\mathbf{z}_{B,i})_{t(j)},",
      " \\sigma_\\epsilon^2)"
    ),
    equation_matrix = paste0(
      response_symbol_matrix,
      " \\mid \\boldsymbol{\\mu}, \\boldsymbol{\\Lambda}_B, \\mathbf{Z}_B,",
      " \\sigma_\\epsilon \\sim ",
      "\\mathcal{MN}(\\mathbf{1}_n \\boldsymbol{\\mu}^\\top + \\mathbf{Z}_B \\boldsymbol{\\Lambda}_B^\\top,",
      " \\sigma_\\epsilon^2 \\mathbf{I}_n, \\mathbf{I}_T)"
    ),
    status = "stated"
  )
  # mu linear predictor (index + matrix form)
  rhs_idx <- if (d_B > 0L) {
    "\\mu_{t(j)} + \\sum_{k=1}^{d_B} \\lambda_{B,t(j)k} z_{B,ik}"
  } else {
    "\\mu_{t(j)}"
  }
  rhs_mat <- if (d_B > 0L) {
    "\\mathbf{1}_n \\boldsymbol{\\mu}^\\top + \\mathbf{Z}_B \\boldsymbol{\\Lambda}_B^\\top"
  } else {
    "\\mathbf{1}_n \\boldsymbol{\\mu}^\\top"
  }
  rows[[length(rows) + 1L]] <- tibble::tibble(
    name = "mu_linear_predictor",
    kind = "linear_predictor",
    submodel = "mu",
    equation = paste("\\eta_{ij} =", rhs_idx),
    equation_matrix = paste("\\boldsymbol{\\eta} =", rhs_mat),
    status = "stated"
  )
  # Latent-score distribution
  if (d_B > 0L) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      name = "latent_score_distribution",
      kind = "latent_distribution",
      submodel = "Lambda_B",
      equation = "z_{B,ik} \\sim \\mathcal{N}(0, 1)",
      equation_matrix = "\\mathbf{z}_{B,i} \\sim \\mathcal{N}(\\mathbf{0}, \\mathbf{I}_{d_B})",
      status = "stated"
    )
    # Implied between-unit covariance row.
    has_psi <- glm_has_unique_unit(fit)
    rhs_cov_idx <- if (has_psi) {
      "\\sum_{k=1}^{d_B} \\lambda_{B,tk} \\lambda_{B,t'k} + \\psi_{B,t} \\delta_{tt'}"
    } else {
      "\\sum_{k=1}^{d_B} \\lambda_{B,tk} \\lambda_{B,t'k}"
    }
    rhs_cov_mat <- if (has_psi) {
      "\\boldsymbol{\\Lambda}_B \\boldsymbol{\\Lambda}_B^\\top + \\boldsymbol{\\Psi}_B"
    } else {
      "\\boldsymbol{\\Lambda}_B \\boldsymbol{\\Lambda}_B^\\top"
    }
    rows[[length(rows) + 1L]] <- tibble::tibble(
      name = "implied_between_unit_covariance",
      kind = "implied_covariance",
      submodel = "Lambda_B",
      equation = paste("\\Sigma_{B,tt'} =", rhs_cov_idx),
      equation_matrix = paste("\\boldsymbol{\\Sigma}_B =", rhs_cov_mat),
      status = "implied"
    )
  }
  do.call(rbind, rows)
}

glm_build_symbol_dictionary <- function(terms_tbl, response, response_symbol,
                                        response_symbol_matrix, response_units,
                                        n_obs, n_traits, n_sites, d_B,
                                        units, data, fit) {
  rows <- list()
  rows[[length(rows) + 1L]] <- tibble::tibble(
    symbol = "y_{ij}",
    symbol_matrix = response_symbol_matrix,
    variable = response,
    units = response_units,
    role = "response",
    dimension = "\\mathbb{R}^{n \\times T}",
    dimension_concrete = sprintf("\\mathbb{R}^{%d \\times %d}", n_sites, n_traits),
    description = sprintf(
      "response (matrix form n x T; index form y_{ij} is unit i, trait t(j) row of %s)",
      response
    )
  )
  # Trait factor and trait index
  rows[[length(rows) + 1L]] <- tibble::tibble(
    symbol = "t",
    symbol_matrix = NA_character_,
    variable = fit$trait_col,
    units = NA_character_,
    role = "index",
    dimension = sprintf("\\{1, \\ldots, %d\\}", n_traits),
    dimension_concrete = sprintf("\\{1, \\ldots, %d\\}", n_traits),
    description = "trait index"
  )
  rows[[length(rows) + 1L]] <- tibble::tibble(
    symbol = "i",
    symbol_matrix = NA_character_,
    variable = fit$unit_col,
    units = NA_character_,
    role = "index",
    dimension = sprintf("\\{1, \\ldots, %d\\}", n_sites),
    dimension_concrete = sprintf("\\{1, \\ldots, %d\\}", n_sites),
    description = "unit index"
  )
  # Trait intercepts
  if (nrow(terms_tbl) > 0L) {
    sym_join <- paste(terms_tbl$symbol, collapse = ", ")
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = sym_join,
      symbol_matrix = "\\boldsymbol{\\mu}",
      variable = NA_character_,
      units = NA_character_,
      role = "trait_intercept",
      dimension = "\\mathbb{R}^T",
      dimension_concrete = sprintf("\\mathbb{R}^{%d}", n_traits),
      description = "per-trait grand-mean intercepts"
    )
  }
  if (d_B > 0L) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = "\\lambda_{B,tk}",
      symbol_matrix = "\\boldsymbol{\\Lambda}_B",
      variable = NA_character_,
      units = NA_character_,
      role = "loading",
      dimension = "\\mathbb{R}^{T \\times d_B}",
      dimension_concrete = sprintf("\\mathbb{R}^{%d \\times %d}", n_traits, d_B),
      description = "between-unit reduced-rank loading matrix"
    )
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = "z_{B,ik}",
      symbol_matrix = "\\mathbf{Z}_B",
      variable = NA_character_,
      units = NA_character_,
      role = "latent_score",
      dimension = "\\mathbb{R}^{n_\\text{unit} \\times d_B}",
      dimension_concrete = sprintf("\\mathbb{R}^{%d \\times %d}", n_sites, d_B),
      description = "between-unit latent scores"
    )
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = "k",
      symbol_matrix = NA_character_,
      variable = NA_character_,
      units = NA_character_,
      role = "index",
      dimension = sprintf("\\{1, \\ldots, %d\\}", d_B),
      dimension_concrete = sprintf("\\{1, \\ldots, %d\\}", d_B),
      description = "latent-axis index"
    )
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = NA_character_,
      symbol_matrix = "\\boldsymbol{\\Sigma}_B",
      variable = NA_character_,
      units = NA_character_,
      role = "implied_covariance",
      dimension = "\\mathbb{R}^{T \\times T}",
      dimension_concrete = sprintf("\\mathbb{R}^{%d \\times %d}", n_traits, n_traits),
      description = "implied between-unit trait covariance"
    )
  }
  if (!is.null(fit$report$sigma_eps)) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = "\\sigma_\\epsilon",
      symbol_matrix = "\\sigma_\\epsilon",
      variable = NA_character_,
      units = NA_character_,
      role = "residual_sd",
      dimension = "scalar",
      dimension_concrete = "scalar",
      description = "shared row-level residual SD"
    )
  }
  if (glm_has_unique_unit(fit)) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = "\\psi_{B,t}",
      symbol_matrix = "\\boldsymbol{\\Psi}_B",
      variable = NA_character_,
      units = NA_character_,
      role = "unique_variance",
      dimension = "diagonal \\mathbb{R}^{T \\times T}",
      dimension_concrete = sprintf("diagonal \\mathbb{R}^{%d \\times %d}",
                                   n_traits, n_traits),
      description = "between-unit unique variance per trait"
    )
  }
  do.call(rbind, rows)
}

glm_build_assumptions <- function(response, response_symbol_scalar,
                                  response_symbol_matrix, fit,
                                  tpl_family = "gllvm_gaussian",
                                  detected_signals = character(0L)) {
  tbl <- load_template("assumption-templates")
  rows <- tbl[tbl$family == tpl_family, , drop = FALSE]
  if (nrow(rows) == 0L) {
    cli::cli_abort("No assumption template rows for family {.val {tpl_family}}.")
  }
  # v0.21+ requires-column gating (mirrors drm_build_assumptions).
  if ("requires" %in% names(rows)) {
    req <- rows$requires
    known <- c("phylo", "spatial", "animal", "temporal", "meta_analysis")
    keep <- is.na(req) | req == "" | !(req %in% known) |
            (req %in% detected_signals)
    rows <- rows[keep, , drop = FALSE]
  }
  # If there is no unique() term on the unit, drop the Psi-bearing rows only
  # if they explicitly depend on Psi -- the implied_between_unit_covariance row
  # already handles Psi_B = 0 in its prose, so we leave it.
  root <- glm_response_symbol_root(response_symbol_scalar)
  mapping <- list(
    response = response,
    response_symbol = response_symbol_scalar,
    response_symbol_matrix = response_symbol_matrix,
    response_symbol_t = paste0(root, "_t"),
    `response_symbol_t'` = paste0(root, "_{t'}")
  )
  drm_substitute <- get("drm_substitute", envir = asNamespace("symbolizer"))
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

# Strip the row-level subscript (e.g. "_{ij}" or "_i") from a response symbol
# to recover the underlying root, used when forming per-trait variants like
# y_t and y_{t'} for cross-trait assumption expressions.
glm_response_symbol_root <- function(response_symbol) {
  s <- sub("_\\{[^}]*\\}$", "", response_symbol)
  s <- sub("_[A-Za-z0-9]+$", "", s)
  s
}

glm_build_interpretation <- function(fixed_eff, loadings_tbl, response,
                                     tpl_family = "gllvm_gaussian",
                                     detected_signals = character(0L)) {
  tbl <- load_template("interpretation-templates")
  # v0.21+ requires-column gating.
  if ("requires" %in% names(tbl)) {
    req <- tbl$requires
    known <- c("phylo", "spatial", "animal", "temporal", "meta_analysis")
    keep <- is.na(req) | req == "" | !(req %in% known) |
            (req %in% detected_signals)
    tbl <- tbl[keep, , drop = FALSE]
  }
  rows <- list()
  if (nrow(fixed_eff) > 0L) {
    tpl_mu <- tbl[tbl$family == tpl_family &
                    tbl$submodel == "mu" &
                    tbl$coefficient_role == "trait_intercept", , drop = FALSE]
    if (nrow(tpl_mu) > 0L) {
      for (i in seq_len(nrow(fixed_eff))) {
        r <- fixed_eff[i, , drop = FALSE]
        if (!identical(r$role, "trait_intercept")) next
        mapping <- list(
          response = response,
          trait = if (is.na(r$contrast_level)) "" else r$contrast_level,
          coef = glm_format_estimate(r$estimate)
        )
        rows[[length(rows) + 1L]] <- tibble::tibble(
          submodel = "mu",
          term_label = r$term_label,
          coefficient_role = "trait_intercept",
          estimate = r$estimate,
          link_scale_reading = glm_sub(tpl_mu$link_scale_reading[[1L]], mapping),
          natural_scale_reading = glm_sub(tpl_mu$natural_scale_reading[[1L]], mapping),
          variance_scale_reading = glm_sub(tpl_mu$variance_scale_reading[[1L]], mapping),
          biological_reading = glm_sub(tpl_mu$biological_reading[[1L]], mapping)
        )
      }
    }
  }
  if (!is.null(loadings_tbl) && nrow(loadings_tbl) > 0L) {
    tpl_l <- tbl[tbl$family == tpl_family &
                   tbl$submodel == "Lambda_B" &
                   tbl$coefficient_role == "loading", , drop = FALSE]
    if (nrow(tpl_l) > 0L) {
      for (i in seq_len(nrow(loadings_tbl))) {
        r <- loadings_tbl[i, , drop = FALSE]
        mapping <- list(
          response = response,
          trait = r$trait,
          axis  = r$axis,
          coef  = glm_format_estimate(r$estimate)
        )
        rows[[length(rows) + 1L]] <- tibble::tibble(
          submodel = "Lambda_B",
          term_label = sprintf("Lambda_B[%d,%d]", r$trait_index, r$axis_index),
          coefficient_role = "loading",
          estimate = r$estimate,
          link_scale_reading = glm_sub(tpl_l$link_scale_reading[[1L]], mapping),
          natural_scale_reading = glm_sub(tpl_l$natural_scale_reading[[1L]], mapping),
          variance_scale_reading = glm_sub(tpl_l$variance_scale_reading[[1L]], mapping),
          biological_reading = glm_sub(tpl_l$biological_reading[[1L]], mapping)
        )
      }
    }
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

glm_build_formula_bridge <- function(fit, response, response_symbol_matrix,
                                     d_B) {
  r_call <- if (!is.null(fit$call)) {
    paste(deparse(fit$call$formula %||% fit$formula), collapse = " ")
  } else {
    paste(deparse(fit$formula), collapse = " ")
  }
  # Reconstruct a representation of the full formula (the parsed object stores
  # only the fixed-effect side).
  cs <- fit$covstructs %||% list()
  cs_strings <- vapply(cs, function(e) {
    extra <- e$extra %||% list()
    arg_d <- if (!is.null(extra$d)) sprintf(", d = %d", as.integer(extra$d)) else ""
    lhs_txt <- paste(deparse(e$lhs), collapse = " ")
    grp_txt <- paste(deparse(e$group), collapse = " ")
    sprintf("%s(%s | %s%s)", e$kind, lhs_txt, grp_txt, arg_d)
  }, character(1L))
  full_formula <- if (length(cs_strings) > 0L) {
    paste(c(r_call, cs_strings), collapse = " + ")
  } else {
    r_call
  }
  rows <- list()
  rows[[length(rows) + 1L]] <- tibble::tibble(
    submodel = "mu",
    r_syntax = paste0(response, " ~ 0 + ", fit$trait_col),
    statistical_meaning = sprintf(
      "Per-trait grand-mean intercept for %s", response
    ),
    mathematics = "\\mu_t \\in \\mathbb{R} \\text{ for } t = 1, \\ldots, T",
    mathematics_matrix = "\\boldsymbol{\\mu} \\in \\mathbb{R}^T"
  )
  if (d_B > 0L) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      submodel = "Lambda_B",
      r_syntax = sprintf("latent(0 + %s | %s, d = %d)", fit$trait_col,
                         fit$unit_col, d_B),
      statistical_meaning = sprintf(
        "Between-%s reduced-rank latent factors of rank %d",
        fit$unit_col, d_B
      ),
      mathematics = paste(
        "\\eta_{ij} = \\mu_{t(j)} + \\sum_{k=1}^{d_B}",
        "\\lambda_{B,t(j)k} z_{B,ik}"
      ),
      mathematics_matrix = paste(
        "\\boldsymbol{\\eta} = \\mathbf{1}_n \\boldsymbol{\\mu}^\\top +",
        "\\mathbf{Z}_B \\boldsymbol{\\Lambda}_B^\\top"
      )
    )
  }
  out <- do.call(rbind, rows)
  attr(out, "full_formula") <- full_formula
  out
}

glm_build_expanded <- function(fit, trait_levels) {
  y_long   <- fit$tmb_data$y
  n_obs    <- length(y_long)
  n_traits <- as.integer(fit$n_traits %||% NA_integer_)
  n_sites  <- as.integer(fit$n_sites  %||% NA_integer_)

  trait_id <- if (!is.null(fit$tmb_data$trait_id))
    as.integer(fit$tmb_data$trait_id) + 1L else NULL
  site_id  <- if (!is.null(fit$tmb_data$site_id))
    as.integer(fit$tmb_data$site_id)  + 1L else NULL

  # Reshape long y into the n_sites x n_traits Y matrix if possible.
  Y <- tryCatch({
    M <- matrix(NA_real_, n_sites, n_traits)
    for (r in seq_along(y_long)) {
      M[site_id[r], trait_id[r]] <- y_long[r]
    }
    rownames(M) <- as.character(seq_len(n_sites))
    colnames(M) <- if (length(trait_levels) == n_traits) trait_levels else
      paste0("trait_", seq_len(n_traits))
    M
  }, error = function(...) NULL)

  Lambda_B  <- if (!is.null(fit$report$Lambda_B))  as.matrix(fit$report$Lambda_B)  else NULL
  Sigma_B   <- if (!is.null(fit$report$Sigma_B))   as.matrix(fit$report$Sigma_B)   else NULL
  sigma_eps <- if (!is.null(fit$report$sigma_eps)) as.numeric(fit$report$sigma_eps) else NULL
  Z_B <- tryCatch(as.matrix(gllvmTMB::getLV(fit, level = "unit")),
                  error = function(...) NULL)
  eta <- if (!is.null(fit$report$eta)) as.numeric(fit$report$eta) else NULL

  # ---- widget-shape slots ---------------------------------------------------
  # The three-views renderer (R/render-three-views.R) needs to emit a
  # response-equation row of the shape `y_r = (X beta)_r + u_r + epsilon_r`,
  # and a stacked block `[y]_{n x 1} = [X]_{n x T}[beta] + [u]_{n x 1}`. The
  # eight slots below close that contract for a Gaussian-identity fit.

  # X: one-hot trait indicator for each observation (n_obs x n_traits). The
  # canonical formula is `value ~ 0 + trait + latent(...)`, so the trait
  # column is the only fixed-effect design column. We label the columns
  # by their trait level so the worked-row renderer's predictor_label()
  # doesn't fall back to "x_{k}" (which then mis-escapes `_` to `\_`).
  X <- if (!is.null(trait_id) && !is.na(n_traits))
    diag(n_traits)[trait_id, , drop = FALSE] else NULL
  if (!is.null(X)) {
    colnames(X) <- if (length(trait_levels) == n_traits) trait_levels else
      paste0("trait", seq_len(n_traits))
  }

  # beta: trait intercepts. b_fix may carry slope columns when the formula
  # adds predictors; the widget displays only the first n_traits trait
  # intercepts (the slope-bearing case is out of scope for the first slice).
  beta_full <- if (!is.null(fit$opt$par))
    unname(fit$opt$par[names(fit$opt$par) == "b_fix"]) else NULL
  beta <- if (!is.null(beta_full) && length(beta_full) >= n_traits)
    beta_full[seq_len(n_traits)] else NULL

  # u: per-observation random-effect contribution. By construction
  # eta = X beta + u for the canonical formula, so we recover u as the
  # gap between eta and the fixed part. This is the renderer's u_{n x 1}.
  u <- if (!is.null(eta) && !is.null(X) && !is.null(beta))
    as.numeric(eta - as.numeric(X %*% beta)) else NULL

  # mu_hat / fitted / residuals: Gaussian identity link, so mu_hat = eta,
  # fitted = mu_hat, residuals = y - fitted.
  mu_hat    <- eta
  fitted    <- mu_hat
  residuals <- if (!is.null(fitted)) as.numeric(y_long) - fitted else NULL

  # Z_g: identity-on-observations marker. The renderer's Z-drop logic uses
  # n_obs == n_distinct_levels to fold Z u into the bare u_{n x 1} column
  # instead of emitting a wall of zeros. gllvm has one observation per
  # (unit, trait) row, so the right Z to advertise is I_n. We give Z_g
  # per-observation column names so the worked-row's RE label reads
  # `\hat{u}_{1}` rather than the generic `\hat{u}_{\mathrm{group}(1)}`.
  Z_g <- if (n_obs >= 1L) {
    M <- diag(n_obs)
    colnames(M) <- as.character(seq_len(n_obs))
    M
  } else NULL

  # Psi_B: per-trait diagonal uniqueness, populated only when the fit has a
  # unique(0 + trait | unit) term. gllvmTMB exposes the diagonal SD vector
  # as report$sd_B (length n_traits).
  Psi_B <- if (isTRUE(glm_has_unique_unit(fit)) && !is.null(fit$report$sd_B))
    as.numeric(fit$report$sd_B) else NULL

  list(
    y         = as.numeric(y_long),
    Y         = Y,
    mu        = beta_full,
    Lambda_B  = Lambda_B,
    Z_B       = Z_B,
    Sigma_B   = Sigma_B,
    sigma_eps = sigma_eps,
    eta       = eta,
    # widget-shape slots (added in v0.21.5-redo for the three-views renderer):
    X         = X,
    beta      = beta,
    u         = u,
    Z_g       = Z_g,
    mu_hat    = mu_hat,
    fitted    = fitted,
    residuals = residuals,
    Psi_B     = Psi_B
  )
}

# ---- internal utilities -----------------------------------------------------

glm_format_estimate <- function(x, digits = 3L) {
  if (is.null(x) || length(x) == 0L || is.na(x)) return("")
  formatC(x, digits = digits, format = "fg", flag = "#")
}

glm_sub <- function(s, mapping) {
  if (is.null(s) || is.na(s)) return(s)
  for (key in names(mapping)) {
    s <- gsub(paste0("{", key, "}"), mapping[[key]], s, fixed = TRUE)
  }
  s
}
