# ----------------------------------------------------------------------------
# symbolize.MCMCglmm
#
# v0.9 First slice extractor for MCMCglmm fits. Targets the Gaussian
# family with optional `~ g` (intercept-only) random effects.
#
# MCMCglmm fitted objects are idiosyncratic:
#
#   fit$Fixed$formula     fixed-effects formula  e.g.  y ~ x
#   fit$Random$formula    random-effects formula e.g.  ~ g  (one-sided)
#   fit$family            character vector, family per observation;
#                         take the first element for the family name
#   fit$Sol               MCMC samples for fixed effects (matrix:
#                         iters x coefficients)
#   summary(fit)$solutions   data frame: post.mean, l-95% CI, u-95% CI,
#                            eff.samp, pMCMC
#   summary(fit)$Gcovariances  variance components for random effects
#   summary(fit)$Rcovariances  residual variance
#
# Critically, MCMCglmm does NOT store the data on the fit object, so
# symbolize.MCMCglmm() takes a mandatory `data` argument.
#
# v0.9 scope: Gaussian + identity link, fixed effects, optional `~ g`
# random intercepts. v0.12 adds: animal models / phylogenetic effects
# via `ginverse = list(animal = Ainv)` -- the extractor detects
# ginverse groups, treats them as "animal" effects in the
# variance-components tibble, and adds a heritability row to the
# parameter-interpretation tibble when both an animal effect and
# residual variance are present.
#
# MCMCglmm's flexible residual covariance structures (`us(trait):unit`,
# `idh(trait):unit`) and non-Gaussian families are still deferred.
# ----------------------------------------------------------------------------

#' Symbolize an MCMCglmm fit (Gaussian, v0.9 first slice)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from an
#' `MCMCglmm` fit. v0.9 covers the Gaussian conditional submodel
#' (identity link) with optional `~ g` random intercepts. Other
#' families and MCMCglmm's flexible covariance structures return
#' capability errors via [`capability_check()`].
#'
#' MCMCglmm does NOT keep the data frame on the fitted object, so
#' `data` is a mandatory argument here.
#'
#' @section Credible intervals:
#' MCMCglmm is Bayesian. The CI band in `fixed_effects` and
#' `interpretation` is a 95% **credible interval** (`l-95% CI` /
#' `u-95% CI` from `summary(fit)$solutions`). `ci_method` is set to
#' `"credible"`.
#'
#' @inheritParams symbolize
#' @param data The data frame used to fit. Required: MCMCglmm does not
#'   keep the data on the fitted object.
#'
#' @references
#' Hadfield, J. D. (2010). MCMC Methods for Multi-Response Generalized
#' Linear Mixed Models: The MCMCglmm R Package. *Journal of
#' Statistical Software*, 33(2), 1-22.
#'
#' @return A `symbolized_model` object.
#' @export
symbolize.MCMCglmm <- function(fit, symbols = NULL, units = NULL,
                               context = NULL, data = NULL, ...) {
  if (!requireNamespace("MCMCglmm", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg MCMCglmm} is needed to symbolize this fit.",
      i = "Install it with {.code install.packages(\"MCMCglmm\")}."
    ))
  }
  if (is.null(data)) {
    cli::cli_abort(c(
      "{.arg data} is required for {.fn symbolize.MCMCglmm}.",
      i = "MCMCglmm does not keep the data frame on the fitted object; pass it explicitly."
    ))
  }
  # MCMCglmm's family is a per-observation character vector; the
  # family name is uniform across observations for the basic case.
  family_raw <- fit$family
  family <- if (length(family_raw) > 0L) unique(family_raw)[[1L]] else NA_character_
  if (is.na(family) || !nzchar(family)) {
    cli::cli_abort("Could not resolve {.code fit$family}.")
  }
  capability_check("MCMCglmm", family, "mu")

  cond_form <- fit$Fixed$formula
  if (is.null(cond_form)) {
    cli::cli_abort("Could not resolve {.code fit$Fixed$formula}.")
  }
  response <- all.vars(cond_form[[2L]])[[1L]]
  if (!nzchar(response)) {
    cli::cli_abort("Could not resolve response variable from the MCMCglmm formula.")
  }
  n_obs <- as.integer(nrow(data))

  entries <- list(
    list(
      dpar = "mu",
      response = response,
      rhs = mcmcglmm_rhs_expr(cond_form),
      expr = cond_form,
      position = 1L
    )
  )

  # Random effects from fit$Random$formula. v0.9 first slice: only
  # one-sided ~ g (intercept-only) per group.
  re_per_entry <- lapply(entries, function(e) {
    mcmcglmm_re_terms(fit, e$dpar, data)
  })
  has_re <- vapply(re_per_entry, function(x) !is.null(x), logical(1L))
  has_animal <- length(fit$ginverse %||% list()) > 0L
  if (any(has_re)) {
    capability_check("MCMCglmm", family, "random_effects")
    if (has_animal) {
      capability_check("MCMCglmm", family, "animal")
    }
    for (i in which(has_re)) {
      drm_assert_supported_re(re_per_entry[[i]], entries[[i]]$dpar)
    }
  }
  animal_groups <- names(fit$ginverse %||% list())

  param <- get_parameterization(family)
  index <- list(observation = "i", individual = "j",
                group = "g", trait = "k", time = "t")

  response_symbol <- mcmcglmm_resolve_response_symbol(response, symbols)
  response_symbol_matrix <- drm_response_symbol_matrix(response_symbol)
  response_units <- drm_resolve_units(response, units)

  model <- list(
    class = "MCMCglmm",
    package = "MCMCglmm",
    family = family,
    response = response,
    n_obs = n_obs
  )

  entries_fe <- entries  # no RE stripping needed -- Random is separate

  link <- "identity"  # MCMCglmm gaussian uses identity by convention

  distribution <- drm_build_distribution(
    family, response_symbol, response_symbol_matrix,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )
  submodels  <- mcmcglmm_build_submodels(entries, fit, param, link)
  terms_tbl  <- drm_build_terms(entries_fe, data, symbols)
  fixed_eff  <- mcmcglmm_build_fixed_effects(terms_tbl, fit)
  re_tbl     <- drm_build_random_effects(re_per_entry)
  vc_tbl     <- mcmcglmm_build_variance_components(fit, animal_groups)
  cov_tbl    <- drm_build_covariance_components(re_tbl)
  # v0.21.4-rescope: MCMCglmm's ginverse path uses the Hadfield-Nakagawa
  # all-nodes augmentation (tips + internal nodes). For a k-tip tree the
  # augmented dimension is at most 2k - 2; polytomies after ultrametric
  # smoothing can lower it. The actual dim is `nrow(fit$ginverse[[g]])`.
  # Override re_tbl$n_levels for phylo groups so the matrix-form
  # equation (\mathbf{u}_g \sim N(0, sigma^2 A_{n x n})) and the
  # symbol_dictionary's dimension_concrete render the all-nodes count,
  # not the tip count. This matches what the widget Tab 3 shim emits
  # and keeps Tab 2 ~ Tab 3 internally consistent (Rose consistency
  # scan 2026-05-27).
  if (length(animal_groups) > 0L && !is.null(fit$ginverse)) {
    for (gname in animal_groups) {
      Ainv_g <- fit$ginverse[[gname]]
      if (!is.null(Ainv_g) && nrow(Ainv_g) > 0L) {
        idx <- which(re_tbl$group_var == gname)
        if (length(idx) > 0L) {
          re_tbl$n_levels[idx] <- as.integer(nrow(Ainv_g))
        }
      }
    }
  }
  # v0.21.1+ phylo / animal-model structured-matrix mapping. When the
  # ginverse path is active, every animal_group's matrix-form random-
  # effect distribution line should render with \mathbf{A} instead of
  # \mathbf{I}_n. Index form stays as the marginal N(0, sigma^2).
  structured_matrix_for_group <- if (length(animal_groups) > 0L) {
    stats::setNames(as.list(rep("\\mathbf{A}", length(animal_groups))),
                    animal_groups)
  } else NULL
  components <- drm_build_components(
    submodels, terms_tbl, re_tbl,
    response_symbol, response_symbol_matrix,
    family = family,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_,
    structured_matrix_for_group = structured_matrix_for_group
  )
  # v0.21+ structured-dependence signals. MCMCglmm's ginverse path is the
  # Hadfield-Nakagawa all-nodes representation of a phylogenetic correlation
  # matrix (also used for pedigree-based animal models). The detected_signals
  # vector drives the requires-column gating in the assumption /
  # interpretation builders so phylo-specific rows fire only when phylo is
  # actually detected.
  detected_signals <- if (has_animal) "phylo" else character(0L)
  structured_matrices <- if (has_animal) {
    lapply(animal_groups, function(g) {
      list(
        symbol             = "\\mathbf{A}",
        symbol_matrix      = "\\mathbf{A}",
        variable           = g,
        units              = NA_character_,
        role               = "structured_correlation_phylo",
        dimension          = "\\mathbb{R}^{k \\times k}",
        dimension_concrete = sprintf("\\mathbb{R}^{k_{%s} \\times k_{%s}}", g, g),
        description        = sprintf("phylogenetic / pedigree correlation matrix on %s (Hadfield-Nakagawa all-nodes sparse-precision representation, supplied via ginverse)", g)
      )
    })
  } else NULL

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
  expanded <- list(y = data[[response]], X = NULL, Z = NULL,
                   beta = NULL, u = NULL, fitted = NULL, residuals = NULL)

  heritability_tbl <- mcmcglmm_heritability_row(vc_tbl)
  metadata <- list(
    call = NULL,
    context = context %||% "",
    ci_method = "credible",
    fit = fit,
    package_versions = list(
      symbolizer = utils::packageVersion("symbolizer"),
      MCMCglmm   = utils::packageVersion("MCMCglmm")
    ),
    animal_groups = animal_groups,
    heritability = heritability_tbl,
    phylo_representation = if (has_animal) "all_nodes" else NULL,
    detected_signals = detected_signals,
    created_by = "symbolize.MCMCglmm"
  )

  sym_stub <- list(
    model = model, metadata = metadata, random_effects = re_tbl
  )
  warnings_tbl <- mcmcglmm_build_warnings(fit, sym_stub)

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

mcmcglmm_rhs_expr <- function(f) {
  if (length(f) == 3L) f[[3L]] else f[[2L]]
}

mcmcglmm_resolve_response_symbol <- function(response, symbols) {
  if (!is.null(symbols) && !is.null(symbols[[response]])) {
    return(as.character(symbols[[response]]))
  }
  # v0.21.1+: escape underscores and wrap multi-character names in
  # \mathrm{...} so MathJax doesn't parse `_` as a subscript marker.
  # Previously returned the raw column name -- "log_mass" rendered as
  # "log subscript m a s s" because MathJax saw the underscore as math.
  # Mirrors drm_resolve_response_symbol() in R/symbolize-drmtmb.R.
  esc <- gsub("_", "\\_", response, fixed = TRUE)
  if (nchar(response) > 1L) {
    paste0("\\mathrm{", esc, "}_i")
  } else {
    paste0(esc, "_i")
  }
}

mcmcglmm_build_submodels <- function(entries, fit, param, link_mu) {
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

# Random effects: one row per (group, intercept) pair. v0.9 first
# slice handles only `~ g` (intercept-only). MCMCglmm's flexible
# covariance structures are deferred.
mcmcglmm_re_terms <- function(fit, dpar, data) {
  if (dpar != "mu") return(NULL)
  rf <- fit$Random$formula
  if (is.null(rf)) return(NULL)
  # Parse the random formula. A one-sided ~ g gives all.vars(rf) = "g".
  groups <- all.vars(rf)
  groups <- groups[nzchar(groups)]
  if (length(groups) == 0L) return(NULL)
  rows <- list()
  for (g in groups) {
    n_levels <- if (!is.null(data[[g]])) length(unique(data[[g]])) else NA_integer_
    rows[[length(rows) + 1L]] <- tibble::tibble(
      submodel    = "mu",
      term_label  = sprintf("(1 | %s)", g),
      lhs_expr    = "1",
      group_var   = g,
      component   = "(Intercept)",
      n_levels    = as.integer(n_levels)
    )
  }
  do.call(rbind, rows)
}

# Fixed-effects tibble. Pull post.mean + 95% credible bounds from
# summary(fit)$solutions.
mcmcglmm_build_fixed_effects <- function(terms_tbl, fit) {
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
  sol <- summary(fit)$solutions
  # `sol` columns: post.mean, l-95% CI, u-95% CI, eff.samp, pMCMC.
  # Posterior SD isn't directly given; we can compute from fit$Sol if
  # needed.
  posterior_sd <- if (!is.null(fit$Sol)) apply(fit$Sol, 2L, stats::sd) else NULL

  estimate <- rep(NA_real_, nrow(terms_tbl))
  std_err  <- rep(NA_real_, nrow(terms_tbl))
  ci_low   <- rep(NA_real_, nrow(terms_tbl))
  ci_high  <- rep(NA_real_, nrow(terms_tbl))
  for (i in seq_len(nrow(terms_tbl))) {
    row <- terms_tbl[i, , drop = FALSE]
    if (is.na(row$coefficient_symbol)) next
    hit <- mcmcglmm_hit_name(row)
    j <- which(rownames(sol) == hit)
    if (length(j) >= 1L) {
      estimate[i] <- as.numeric(sol[j[[1L]], "post.mean"])
      ci_low[i]   <- as.numeric(sol[j[[1L]], "l-95% CI"])
      ci_high[i]  <- as.numeric(sol[j[[1L]], "u-95% CI"])
      if (!is.null(posterior_sd) && hit %in% names(posterior_sd)) {
        std_err[i] <- as.numeric(posterior_sd[[hit]])
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
    ci_method = rep("credible", nrow(terms_tbl))
  )
}

mcmcglmm_hit_name <- function(row) {
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

# Variance components from summary's Gcovariances + Rcovariances.
# `animal_groups` is the character vector of group names that have a
# relationship-matrix inverse attached (`fit$ginverse`); rows for those
# groups carry `kind = "animal"` so downstream readers know the
# implied prior is N(0, sigma^2 * A) rather than N(0, sigma^2 * I).
mcmcglmm_build_variance_components <- function(fit, animal_groups = character(0)) {
  s <- summary(fit)
  rows <- list()
  if (!is.null(s$Gcovariances)) {
    gc <- s$Gcovariances
    for (i in seq_len(nrow(gc))) {
      sd_est <- sqrt(as.numeric(gc[i, "post.mean"]))
      grp <- rownames(gc)[[i]]
      rows[[length(rows) + 1L]] <- tibble::tibble(
        parameter   = "mu",
        group       = grp,
        term        = "(Intercept)",
        sd_estimate = sd_est,
        var_estimate = sd_est ^ 2,
        kind        = if (grp %in% animal_groups) "animal" else "random"
      )
    }
  }
  if (!is.null(s$Rcovariances)) {
    rc <- s$Rcovariances
    if (nrow(rc) >= 1L) {
      sd_resid <- sqrt(as.numeric(rc[1L, "post.mean"]))
      rows[[length(rows) + 1L]] <- tibble::tibble(
        parameter   = "residual",
        group       = "residual",
        term        = "Residual",
        sd_estimate = sd_resid,
        var_estimate = sd_resid ^ 2,
        kind        = "residual"
      )
    }
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(
      parameter = character(0), group = character(0), term = character(0),
      sd_estimate = double(0), var_estimate = double(0),
      kind = character(0)
    ))
  }
  do.call(rbind, rows)
}

# Derive heritability rows from variance_components. When an "animal"
# row and a "residual" row are both present, append a derived row
# h^2 = sigma_A^2 / (sigma_A^2 + sigma_E^2). The derived row is added
# to the `interpretation` tibble (not the variance_components tibble)
# so renderers that read variance components see only direct
# estimates.
mcmcglmm_heritability_row <- function(vc_tbl) {
  if (!"kind" %in% names(vc_tbl)) return(NULL)
  animal_rows <- vc_tbl[vc_tbl$kind == "animal", , drop = FALSE]
  resid_rows  <- vc_tbl[vc_tbl$kind == "residual", , drop = FALSE]
  if (nrow(animal_rows) == 0L || nrow(resid_rows) == 0L) return(NULL)
  out <- list()
  for (i in seq_len(nrow(animal_rows))) {
    var_a <- as.numeric(animal_rows$var_estimate[[i]])
    var_e <- as.numeric(resid_rows$var_estimate[[1L]])
    h2 <- var_a / (var_a + var_e)
    out[[length(out) + 1L]] <- tibble::tibble(
      group         = animal_rows$group[[i]],
      variance_A    = var_a,
      variance_E    = var_e,
      heritability  = h2,
      reading       = sprintf(
        "Heritability h^2 = sigma^2_p / (sigma^2_p + sigma^2_e) = %.3f -- the proportion of phenotypic variation in %s attributable to phylogenetic / additive-genetic effects (in animal-model literature this is also written sigma^2_A / (sigma^2_A + sigma^2_E)).",
        h2, animal_rows$group[[i]]
      )
    )
  }
  do.call(rbind, out)
}

mcmcglmm_build_warnings <- function(fit, sym_stub) {
  rows <- list()
  re <- sym_stub$random_effects
  if (!is.null(re) && nrow(re) > 0L && "n_levels" %in% names(re)) {
    small <- re[re$n_levels < 5L, , drop = FALSE]
    for (i in seq_len(nrow(small))) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        code = "few_re_levels",
        severity = "warning",
        message = sprintf(
          "Random-effect group %s has %d levels - identifiability of the variance component depends heavily on the prior.",
          small$group_var[[i]], small$n_levels[[i]]
        ),
        context = ""
      )
    }
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(code = character(0), severity = character(0),
                          message = character(0), context = character(0)))
  }
  do.call(rbind, rows)
}
