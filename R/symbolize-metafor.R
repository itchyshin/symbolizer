# ----------------------------------------------------------------------------
# symbolize.rma.uni / symbolize.rma.mv
#
# v0.13.0 First slice for metafor random-effects meta-analysis and
# meta-regression. v0.14.1 adds rma.mv (multilevel / multivariate
# meta-analysis) -- supports multiple random-effect tiers via
# `random = list(~ 1 | study, ~ 1 | outcome)` or the nested syntax
# `random = ~ 1 | district / study`.
#
# Both classes share the same fixed-effects model and CI extraction
# (via fit$beta / fit$se / fit$ci.lb / fit$ci.ub). They differ in:
#   - rma.uni stores between-study heterogeneity in fit$tau2 (one
#     scalar);
#   - rma.mv stores it in fit$sigma2 (numeric vector, one per random
#     effect) with names in fit$s.names.
#
# Models the two-tier structure explicitly:
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
#' @section Location-scale (rma.ls):
#' When the fit was created with `rma(..., scale = ~ z)`,
#' `symbolize.rma.uni()` adds a second submodel `tau2` to the
#' returned object. metafor parameterises the scale model as
#' `log(tau^2_i) = alpha_0 + alpha_1 z_{1i} + ... + alpha_q z_{qi}`
#' -- log of the **variance**, not the SD -- with coefficient family
#' `alpha`. This contrasts with the SD parameterisation that brms,
#' glmmTMB, and drmTMB use for their distributional location-scale
#' models (`log(sigma_i) = gamma_0 + gamma_k z_ki`). The natural-scale
#' reading on a metafor scale slope is therefore "tau^2_i changes
#' multiplicatively by exp(alpha_k) per unit of z_k" -- a change in
#' the variance, not the SD. The two scales are related by
#' `alpha_k ~ 2 * gamma_k` (since `log(tau^2) = 2 * log(tau) + const`).
#'
#' @references
#' Viechtbauer, W., & López-López, J. A. (2022). Location-scale
#' models for meta-analysis. *Research Synthesis Methods*, 13(6),
#' 697-715.
#'
#' Nakagawa, S., Mizuno, A., Morrison, K., Ricolfi, L., Williams, C.,
#' Drobniak, S. M., Lagisz, M., & Yang, Y. (2025). Location-scale
#' meta-analysis and meta-regression as a tool to capture large-scale
#' changes in biological and methodological heterogeneity: A spotlight
#' on heteroscedasticity. *Global Change Biology*, 31, e70204.
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
  # Note: metafor models log(tau^2_i) (log of the VARIANCE), not log(sigma_i).
  # Coefficient family for tau2 is alpha. Symbol is tau^2.
  is_location_scale <- identical(fit$model %||% "rma.uni", "rma.ls")
  if (is_location_scale) {
    capability_check("rma.uni", family, "tau2_scale")
  } else if (!is.null(fit$tau2) && length(fit$tau2) == 1L && fit$tau2 > 0) {
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

  # Location-scale rma.ls: append a tau2 submodel. metafor models
  # log(tau^2_i) (log VARIANCE, not log SD) with coefficient alpha.
  if (is_location_scale && !is.null(fit$Z)) {
    z_pred_names <- setdiff(colnames(fit$Z), c("intrcpt", "(Intercept)"))
    z_rhs <- if (length(z_pred_names) == 0L) "1" else paste(z_pred_names, collapse = " + ")
    tau2_form <- stats::as.formula(paste("tau2 ~", z_rhs))
    for (m in z_pred_names) {
      if (!m %in% names(data) && m %in% colnames(fit$Z)) {
        data[[m]] <- as.numeric(fit$Z[, m])
      }
    }
    entries[[length(entries) + 1L]] <- list(
      dpar = "tau2",
      response = NA_character_,
      rhs = if (length(z_pred_names) == 0L) quote(1) else metafor_rhs_expr(tau2_form),
      expr = tau2_form,
      position = 2L
    )
  }

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
    tau2 = if (is.null(fit$tau2) || length(fit$tau2) == 0L) NA_real_
           else as.numeric(fit$tau2),
    is_location_scale = isTRUE(is_location_scale),
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

# ----------------------------------------------------------------------------
# symbolize.rma.mv
#
# v0.13.1 extractor for metafor multilevel / multivariate meta-analysis.
# Differences from rma.uni:
#
#   - fit$random is a list of formulas (one per random-effect tier)
#   - fit$sigma2 is a numeric vector (one per tier); fit$s.names
#     carries human-readable names
#   - fit$tau2 is unused (always 0); heterogeneity lives in sigma2
#   - fit$R is a named list of (correlation) matrices, NULL where
#     unstructured. A non-NULL entry tags the tier as "structured"
#     (phylogenetic / spatial / pedigree-style), and the model is
#     u_r ~ N(0, sigma^2_r * R_r) instead of u_r ~ N(0, sigma^2_r * I).
# ----------------------------------------------------------------------------

#' Symbolize a metafor rma.mv fit (multilevel / multivariate meta-analysis, v0.13.1)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from an
#' `rma.mv` fit. Covers the multi-tier random-effects structure
#' (`random = list(~ 1 | study, ~ 1 | id)` or nested
#' `~ 1 | district / study`), optional R-matrix structured random
#' effects (e.g., phylogenetic via `R = list(phylo = phylo.cor)`),
#' and meta-regression moderators.
#'
#' Each random-effect tier gets a row in `variance_components` with
#' `kind = "heterogeneity"` (unstructured) or `kind = "structured"`
#' (when an R-matrix is attached). Tiers with an R-matrix render as
#' `u_r ~ N(0, sigma^2_r * R_r)` in the LaTeX; structured tiers also
#' appear in `sym$metadata$structured_random` with their matrix
#' dimension.
#'
#' @inheritParams symbolize
#' @return A `symbolized_model` object.
#' @export
symbolize.rma.mv <- function(fit, symbols = NULL, units = NULL,
                             context = NULL, ...) {
  if (!requireNamespace("metafor", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg metafor} is needed to symbolize this fit.",
      i = "Install it with {.code install.packages(\"metafor\")}."
    ))
  }
  family <- "meta_normal"
  capability_check("rma.mv", family, "mu")

  response <- "yi"
  data <- fit$data
  if (is.null(data)) data <- data.frame(yi = fit$yi, vi = fit$vi)
  n_obs <- as.integer(fit$k %||% nrow(data))

  beta_names <- rownames(fit$beta) %||% names(stats::coef(fit))
  pred_names <- setdiff(beta_names, c("intrcpt", "(Intercept)"))
  rhs_text <- if (length(pred_names) == 0L) "1" else paste(pred_names, collapse = " + ")
  cond_form <- stats::as.formula(paste(response, "~", rhs_text))

  # Bring moderator columns into a fresh `data` frame so drm_build_terms
  # can resolve them (rma.mv's data slot may not carry them).
  if (length(pred_names) > 0L && !is.null(fit$X)) {
    for (m in pred_names) {
      if (!m %in% names(data) && m %in% colnames(fit$X)) {
        data[[m]] <- as.numeric(fit$X[, m])
      }
    }
  }

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

  # Detect structured (R-matrix) random-effect tiers.
  structured_groups <- character(0)
  if (!is.null(fit$R) && length(fit$R) > 0L) {
    for (gn in names(fit$R)) {
      if (!is.null(fit$R[[gn]])) structured_groups <- c(structured_groups, gn)
    }
  }
  if (length(structured_groups) > 0L) {
    capability_check("rma.mv", family, "structured")
  }

  # Detect UN-structure inner / outer ~ inner|outer with struct="UN".
  # fit$struct is a per-formula character vector (e.g. c("UN", "CS")).
  # When UN is in play, s.names is typically empty and the variance
  # decomposition lives on fit$G (block-diagonal covariance), fit$tau2
  # (diagonal variances), and fit$rho (off-diagonal correlations).
  un_index <- which((fit$struct %||% character(0)) == "UN")
  has_un <- length(un_index) > 0L
  if (has_un) {
    capability_check("rma.mv", family, "struct_UN")
  }

  model <- list(
    class = "rma.mv",
    package = "metafor",
    family = family,
    response = response,
    n_obs = n_obs,
    method = fit$method,
    n_random_tiers = length(fit$random %||% list())
  )

  distribution <- drm_build_distribution(
    family, response_symbol, response_symbol_matrix,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )
  submodels  <- metafor_build_submodels(entries, param)
  terms_tbl  <- drm_build_terms(entries, data, symbols)
  fixed_eff  <- metafor_build_fixed_effects(terms_tbl, fit)
  re_per_entry <- list(metafor_mv_build_re_per_entry(fit))
  re_tbl     <- drm_build_random_effects(re_per_entry)
  vc_tbl     <- metafor_mv_build_variance_components(fit, structured_groups)
  cov_tbl    <- drm_build_covariance_components(re_tbl)
  components <- drm_build_components(
    submodels, terms_tbl, re_tbl,
    response_symbol, response_symbol_matrix,
    family = family,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )

  # v0.21+ structured-dependence signals (rma.mv). Discriminate phylo vs
  # spatial by R-matrix group name. Names matching the phylo lexicon ->
  # "phylo"; spatial lexicon -> "spatial"; anything else stays
  # "structured" (v0.13 behaviour).
  phylo_pat <- "species|phylo|phylogeny|taxon|animal"
  spatial_pat <- "site|location|plot|spatial|coords"
  detected_signals <- character(0L)
  phylo_grps <- character(0L)
  spatial_grps <- character(0L)
  for (gn in structured_groups) {
    if (grepl(phylo_pat, gn, ignore.case = TRUE)) {
      phylo_grps <- c(phylo_grps, gn)
    } else if (grepl(spatial_pat, gn, ignore.case = TRUE)) {
      spatial_grps <- c(spatial_grps, gn)
    }
  }
  if (length(phylo_grps) > 0L)   detected_signals <- c(detected_signals, "phylo")
  if (length(spatial_grps) > 0L) detected_signals <- c(detected_signals, "spatial")
  structured_matrices <- c(
    lapply(phylo_grps, function(gn) list(
      symbol             = "\\mathbf{A}",
      symbol_matrix      = "\\mathbf{A}",
      variable           = gn,
      units              = NA_character_,
      role               = "structured_correlation_phylo",
      dimension          = "\\mathbb{R}^{k \\times k}",
      dimension_concrete = sprintf("\\mathbb{R}^{%d \\times %d}",
                                   NROW(fit$R[[gn]]), NROW(fit$R[[gn]])),
      description        = sprintf("phylogenetic correlation matrix on %s, attached via R = list(%s = A): Sigma = sigma_p^2 * A (tips-only k x k representation)", gn, gn)
    )),
    lapply(spatial_grps, function(gn) list(
      symbol             = "\\boldsymbol{\\Omega}",
      symbol_matrix      = "\\boldsymbol{\\Omega}",
      variable           = gn,
      units              = NA_character_,
      role               = "structured_correlation_spatial",
      dimension          = "\\mathbb{R}^{k \\times k}",
      dimension_concrete = sprintf("\\mathbb{R}^{%d \\times %d}",
                                   NROW(fit$R[[gn]]), NROW(fit$R[[gn]])),
      description        = sprintf("spatial correlation matrix on %s, attached via R = list(%s = Omega): Sigma = sigma_omega^2 * Omega (not a Wishart precision; not a CAR/SAR weights matrix)", gn, gn)
    ))
  )
  if (length(structured_matrices) == 0L) structured_matrices <- NULL

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
  expanded <- list(y = as.numeric(fit$yi), X = fit$X, Z = NULL,
                   beta = as.numeric(fit$beta), u = NULL,
                   fitted = stats::fitted(fit), residuals = stats::residuals(fit))

  # Structured random-effects metadata: one row per tier with an
  # attached R-matrix.
  structured_tbl <- if (length(structured_groups) > 0L) {
    do.call(rbind, lapply(structured_groups, function(gn) {
      tibble::tibble(
        group = gn,
        matrix_dim = NROW(fit$R[[gn]]),
        matrix_kind = "R"
      )
    }))
  } else NULL

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
    n_random_tiers = length(fit$random %||% list()),
    structured_random = structured_tbl,
    sigma2 = fit$sigma2,
    s_names = fit$s.names,
    phylo_representation = if (length(phylo_grps) > 0L) "tips_only" else NULL,
    spatial_representation = if (length(spatial_grps) > 0L) "tips_only" else NULL,
    detected_signals = detected_signals,
    created_by = "symbolize.rma.mv"
  )

  sym_stub <- list(
    model = model, metadata = metadata, random_effects = re_tbl
  )
  warnings_tbl <- metafor_mv_build_warnings(fit, sym_stub)

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

# rma.mv random-effects: one row per (tier, intercept). Tier names
# come from fit$s.names which already handles the nested-syntax
# unrolling (e.g., "district" + "district/study"). When the fit uses
# UN structure (~ inner | outer, struct = "UN"), s.names is empty
# and the inner levels come from fit$g.levels.f instead.
metafor_mv_build_re_per_entry <- function(fit) {
  s_names <- fit$s.names %||% character(0)
  n_levels <- fit$s.nlevels %||% rep(NA_integer_, length(s_names))
  rows <- list()
  for (i in seq_along(s_names)) {
    nm <- s_names[[i]]
    rows[[length(rows) + 1L]] <- tibble::tibble(
      submodel    = "mu",
      term_label  = sprintf("(1 | %s)", nm),
      lhs_expr    = "1",
      group_var   = nm,
      component   = "(Intercept)",
      n_levels    = as.integer(n_levels[[i]])
    )
  }
  # UN structure: render the inner-level random effects (e.g., one per
  # outcome / trait) as separate group_vars. The outer level (study /
  # trial) is the implicit grouping variable.
  if (length((fit$struct %||% character(0))) > 0L &&
      any(fit$struct == "UN") &&
      !is.null(fit$g.levels.f) && length(fit$g.levels.f) >= 1L) {
    inner_levels <- fit$g.levels.f[[1L]]
    outer_n <- length(fit$g.levels.f[[2L]] %||% character(0))
    for (lvl in inner_levels) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        submodel    = "mu",
        term_label  = sprintf("(1 | %s)", lvl),
        lhs_expr    = "1",
        group_var   = lvl,
        component   = "(Intercept)",
        n_levels    = as.integer(outer_n)
      )
    }
  }
  if (length(rows) == 0L) return(NULL)
  do.call(rbind, rows)
}

# rma.mv variance components: one row per random-effect tier with
# kind = "heterogeneity" (or "structured" if an R-matrix is attached;
# or "heterogeneity_un" when UN structure produces per-inner-level
# diagonal variances). Also append a row for the (known) mean
# sampling variance, and UN-structure off-diagonal correlations as
# kind = "correlation".
metafor_mv_build_variance_components <- function(fit, structured_groups) {
  rows <- list()
  s_names <- fit$s.names %||% character(0)
  sigma2 <- fit$sigma2 %||% numeric(0)
  for (i in seq_along(s_names)) {
    nm <- s_names[[i]]
    s2 <- as.numeric(sigma2[[i]])
    is_struct <- nm %in% structured_groups
    rows[[length(rows) + 1L]] <- tibble::tibble(
      parameter    = "mu",
      group        = nm,
      term         = sprintf("sigma^2_%s", nm),
      sd_estimate  = sqrt(s2),
      var_estimate = s2,
      kind         = if (is_struct) "structured" else "heterogeneity"
    )
  }
  # UN-structure rows: per-inner-level diagonal variances from fit$tau2;
  # off-diagonal correlations from fit$rho.
  if (length((fit$struct %||% character(0))) > 0L &&
      any(fit$struct == "UN") &&
      !is.null(fit$g.levels.f) && length(fit$g.levels.f) >= 1L) {
    inner_levels <- as.character(fit$g.levels.f[[1L]])
    tau2 <- fit$tau2 %||% rep(NA_real_, length(inner_levels))
    for (i in seq_along(inner_levels)) {
      v <- if (length(tau2) >= i) as.numeric(tau2[[i]]) else NA_real_
      rows[[length(rows) + 1L]] <- tibble::tibble(
        parameter    = "mu",
        group        = inner_levels[[i]],
        term         = sprintf("tau^2_%s", inner_levels[[i]]),
        sd_estimate  = sqrt(v),
        var_estimate = v,
        kind         = "heterogeneity_un"
      )
    }
    # Off-diagonal correlations. For UN with K inner levels there are
    # K*(K-1)/2 correlations stored in fit$rho.
    if (!is.null(fit$rho) && length(inner_levels) >= 2L) {
      pair_idx <- 1L
      for (a in seq_along(inner_levels)) {
        if (a == length(inner_levels)) break
        for (b in seq.int(a + 1L, length(inner_levels))) {
          r <- if (length(fit$rho) >= pair_idx) as.numeric(fit$rho[[pair_idx]]) else NA_real_
          rows[[length(rows) + 1L]] <- tibble::tibble(
            parameter    = "mu",
            group        = sprintf("%s,%s", inner_levels[[a]], inner_levels[[b]]),
            term         = sprintf("rho_%s_%s", inner_levels[[a]], inner_levels[[b]]),
            sd_estimate  = NA_real_,
            var_estimate = r,
            kind         = "correlation"
          )
          pair_idx <- pair_idx + 1L
        }
      }
    }
  }
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

metafor_mv_build_warnings <- function(fit, sym_stub) {
  rows <- list()
  k <- fit$k %||% 0L
  n_tiers <- length(fit$random %||% list())
  if (k < 10L && n_tiers > 0L) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      code = "few_effect_sizes",
      severity = "warning",
      message = sprintf(
        "Only %d effect sizes across %d random-effect tier(s) -- some sigma^2 components are likely poorly identified.",
        k, n_tiers
      )
    )
  }
  # Detect zero / near-zero variance components (potentially
  # unidentified). For UN structure, s.names is empty -- fall back to
  # a generic tier label.
  if (!is.null(fit$sigma2) && length(fit$sigma2) > 0L) {
    s_names <- fit$s.names %||% character(0)
    for (i in seq_along(fit$sigma2)) {
      if (fit$sigma2[[i]] < 1e-8) {
        nm <- if (length(s_names) >= i) s_names[[i]] else sprintf("tier %d", i)
        rows[[length(rows) + 1L]] <- tibble::tibble(
          code = "zero_variance_component",
          severity = "warning",
          message = sprintf(
            "Variance component for %s estimated at ~ 0 -- the tier may be unidentified, or that variation is genuinely absent. Consider whether the random structure is appropriate.",
            nm
          ),
        context = ""
      )
      }
    }
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(code = character(0), severity = character(0),
                          message = character(0), context = character(0)))
  }
  do.call(rbind, rows)
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
    link <- if (identical(dpar, "tau2")) "log" else "identity"
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
  alpha_names <- if (!is.null(fit$alpha)) {
    rownames(fit$alpha) %||% colnames(fit$Z) %||% character(0)
  } else character(0)
  estimate <- rep(NA_real_, nrow(terms_tbl))
  std_err  <- rep(NA_real_, nrow(terms_tbl))
  ci_low   <- rep(NA_real_, nrow(terms_tbl))
  ci_high  <- rep(NA_real_, nrow(terms_tbl))
  for (i in seq_len(nrow(terms_tbl))) {
    row <- terms_tbl[i, , drop = FALSE]
    if (is.na(row$coefficient_symbol)) next
    hit <- metafor_hit_name(row)
    if (identical(row$submodel, "tau2")) {
      # Scale-part coefficients: pull from fit$alpha + alpha SE/CI slots.
      j <- which(alpha_names == hit)
      if (length(j) >= 1L) {
        estimate[i] <- as.numeric(fit$alpha[j[[1L]], 1L])
        if (!is.null(fit$se.alpha))    std_err[i] <- as.numeric(fit$se.alpha[j[[1L]]])
        if (!is.null(fit$ci.lb.alpha)) ci_low[i]  <- as.numeric(fit$ci.lb.alpha[j[[1L]]])
        if (!is.null(fit$ci.ub.alpha)) ci_high[i] <- as.numeric(fit$ci.ub.alpha[j[[1L]]])
      }
    } else {
      # Location-part coefficients from fit$beta + standard CI slots.
      j <- which(beta_names == hit)
      if (length(j) >= 1L) {
        estimate[i] <- as.numeric(fit$beta[j[[1L]], 1L])
        if (!is.null(fit$se))    std_err[i] <- as.numeric(fit$se[j[[1L]]])
        if (!is.null(fit$ci.lb)) ci_low[i]  <- as.numeric(fit$ci.lb[j[[1L]]])
        if (!is.null(fit$ci.ub)) ci_high[i] <- as.numeric(fit$ci.ub[j[[1L]]])
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

# Treat the between-study heterogeneity as a random-effect "group"
# called "study", with single intercept-only component. NULL when
# `tau^2` is exactly zero (fixed-effects meta-analysis).
metafor_build_re_per_entry <- function(fit) {
  # rma.uni: tau2 is a scalar. rma.ls: tau2 is a vector (one per
  # observation). Treat either case as "yes there's a study-level u_i"
  # when any element is non-zero.
  tau2 <- fit$tau2
  if (is.null(tau2) || length(tau2) == 0L) return(NULL)
  if (all(is.na(tau2)) || all(tau2 == 0)) return(NULL)
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
# For rma.ls, tau^2 is a vector (one per observation); summarise by the
# mean to give a single representative row, and mark kind = "heterogeneity_scale".
metafor_build_variance_components <- function(fit) {
  rows <- list()
  tau2 <- fit$tau2
  is_scale_model <- identical(fit$model %||% "rma.uni", "rma.ls")
  if (!is.null(tau2) && length(tau2) > 0L && !all(is.na(tau2))) {
    if (is_scale_model || length(tau2) > 1L) {
      tau2_mean <- mean(as.numeric(tau2), na.rm = TRUE)
      rows[[length(rows) + 1L]] <- tibble::tibble(
        parameter    = "mu",
        group        = "study",
        term         = "mean(tau^2_i)",
        sd_estimate  = sqrt(tau2_mean),
        var_estimate = tau2_mean,
        kind         = if (is_scale_model) "heterogeneity_scale" else "heterogeneity"
      )
    } else {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        parameter    = "mu",
        group        = "study",
        term         = "tau^2",
        sd_estimate  = sqrt(as.numeric(tau2[[1L]])),
        var_estimate = as.numeric(tau2[[1L]]),
        kind         = "heterogeneity"
      )
    }
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
      ),
      context = ""
    )
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(code = character(0), severity = character(0),
                          message = character(0), context = character(0)))
  }
  do.call(rbind, rows)
}
