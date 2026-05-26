# ----------------------------------------------------------------------------
# symbolize.brmsfit
#
# v0.8 First slice extractor for brms fits. Targets the Gaussian family
# (identity link) with optional `(1 | g)` random intercepts on the
# conditional submodel.
#
# The fitted brmsfit object exposes (relevant pieces):
#
#   fit$formula                brmsformula; $formula slot has the R formula
#   fit$family$family          e.g. "gaussian"
#   fit$family$link            e.g. "identity"
#   fit$data                   the data frame used to fit
#   fixef(fit)                 matrix with columns Estimate, Est.Error,
#                              Q2.5, Q97.5 (the 95% credible band)
#   ranef(fit)                 list of per-group posterior summaries
#   VarCorr(fit)               per-group $sd matrix + $residual__$sd
#   posterior_summary(fit)     superset of fixef + RE SDs + sigma
#   fit$ranef                  data.frame describing each RE term
#
# v0.8 scope: Gaussian + identity link, fixed effects, optional (1 | g)
# random intercepts on the conditional submodel. brms's per-distribution
# parameter formulas (sigma ~ z, nu ~ z) and the distributional formula
# interface are deferred to v0.8.x.
#
# The CI band semantics are Bayesian: Q2.5 / Q97.5 are posterior quantiles
# of a credible interval, not a frequentist confidence interval. We label
# ci_method = "credible" so downstream renderers can phrase it correctly.
# ----------------------------------------------------------------------------

#' Symbolize a brms fit (Gaussian, v0.8 first slice)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from a `brmsfit`
#' object. v0.8 covers the Gaussian conditional submodel (identity link)
#' with optional `(1 | g)` random intercepts. Other families and brms's
#' distributional-parameter formulas (`sigma ~ z`, etc.) return capability
#' errors via [`capability_check()`].
#'
#' @section Credible intervals:
#' brms is Bayesian, so the "confidence band" carried in
#' `fixed_effects` and `interpretation` is a 95% **credible interval** --
#' the 2.5% and 97.5% posterior quantiles. `excludes_zero` is the
#' indicator for whether the credible interval excludes zero (i.e. the
#' posterior puts negligible mass on either side of zero). `ci_method`
#' is set to `"credible"` so renderers can label the band correctly.
#'
#' @inheritParams symbolize
#'
#' @references
#' Bürkner, P.-C. (2017). brms: An R Package for Bayesian Multilevel
#' Models Using Stan. *Journal of Statistical Software*, 80(1), 1-28.
#'
#' @return A `symbolized_model` object.
#' @export
symbolize.brmsfit <- function(fit, symbols = NULL, units = NULL,
                              context = NULL, ...) {
  if (!requireNamespace("brms", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg brms} is needed to symbolize this fit.",
      i = "Install it with {.code install.packages(\"brms\")}."
    ))
  }
  family <- fit$family$family
  link   <- fit$family$link %||% "identity"
  if (is.null(family) || !nzchar(family)) {
    cli::cli_abort("Could not resolve {.code fit$family$family}.")
  }
  # brms distinguishes bernoulli() from binomial() for technical
  # reasons (the trials() argument); mathematically Bernoulli is just
  # Binomial with n_i = 1. We alias internally so the same templates,
  # parameterization, and assumption rows apply to both.
  if (identical(family, "bernoulli")) family <- "binomial"
  capability_check("brmsfit", family, "mu")

  # brms supports per-distribution parameter formulas (sigma ~ z, nu ~ z,
  # etc.) via brmsformula. As of v0.11, we handle a sigma submodel
  # explicitly when the user fit `bf(y ~ x, sigma ~ z)`; other dpars
  # are still rejected via the capability registry.
  pforms <- fit$formula$pforms %||% list()
  has_sigma_distributional <- "sigma" %in% names(pforms)
  if (has_sigma_distributional) {
    capability_check("brmsfit", family, "sigma_distributional")
  }
  # Any pform other than sigma still hits the wildcard reject.
  other_pforms <- setdiff(names(pforms), "sigma")
  if (length(other_pforms) > 0L) {
    capability_check("brmsfit", family,
                     sprintf("%s_distributional", other_pforms[[1L]]))
  }

  response <- brms_response_name(fit)
  if (!nzchar(response)) {
    cli::cli_abort("Could not resolve response variable from the brms formula.")
  }
  data <- fit$data
  n_obs <- as.integer(nrow(data))

  cond_form <- fit$formula$formula
  entries <- list(
    list(
      dpar = "mu",
      response = response,
      rhs = brms_rhs_expr(cond_form),
      expr = cond_form,
      position = 1L
    )
  )
  # Add sigma submodel entry when bf(y ~ x, sigma ~ z) was used.
  if (has_sigma_distributional) {
    sigma_form <- pforms$sigma
    sigma_full <- stats::as.formula(
      paste("sigma ~", paste(deparse(brms_rhs_expr(sigma_form)), collapse = " ")),
      env = environment(sigma_form)
    )
    entries[[length(entries) + 1L]] <- list(
      dpar = "sigma",
      response = NA_character_,
      rhs = brms_rhs_expr(sigma_form),
      expr = sigma_full,
      position = 2L
    )
  }

  # Random-effects per entry (drmTMB-shaped tibble or NULL).
  re_per_entry <- lapply(entries, function(e) brms_re_terms(fit, e$dpar))
  has_re <- vapply(re_per_entry, function(x) !is.null(x), logical(1L))
  if (any(has_re)) {
    capability_check("brmsfit", family, "random_effects")
    for (i in which(has_re)) {
      drm_assert_supported_re(re_per_entry[[i]], entries[[i]]$dpar)
    }
  }

  param <- get_parameterization(family)
  index <- list(observation = "i", individual = "j",
                group = "g", trait = "k", time = "t")

  response_symbol <- brms_resolve_response_symbol(response, symbols)
  response_symbol_matrix <- drm_response_symbol_matrix(response_symbol)
  response_units <- drm_resolve_units(response, units)

  model <- list(
    class = "brmsfit",
    package = "brms",
    family = family,
    response = response,
    n_obs = n_obs
  )

  entries_fe <- entries
  for (i in which(has_re)) {
    entries_fe[[i]]$rhs <- drm_strip_re_terms(entries[[i]]$rhs)
  }

  distribution <- drm_build_distribution(
    family, response_symbol, response_symbol_matrix,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )
  submodels  <- brms_build_submodels(entries, fit, param, link)
  terms_tbl  <- drm_build_terms(entries_fe, data, symbols)
  fixed_eff  <- brms_build_fixed_effects(terms_tbl, fit)
  re_tbl     <- drm_build_random_effects(re_per_entry)
  vc_tbl     <- brms_build_variance_components(fit, re_per_entry)
  cov_tbl    <- drm_build_covariance_components(re_tbl)
  components <- drm_build_components(
    submodels, terms_tbl, re_tbl,
    response_symbol, response_symbol_matrix,
    family = family,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )
  # v0.21+ structured-dependence detection. brms exposes phylogenetic /
  # known-covariance random effects via `gr(group, cov = A)` inside a
  # (1 | gr(group, cov = A)) term. Detect by scanning fit$ranef$cov
  # (brms's per-RE-term metadata) for non-empty / non-NA `cov`. The
  # covariance matrix is stored in fit$data2 under the matrix name.
  detected_signals <- character(0L)
  brms_phylo_groups <- character(0L)
  ranef <- tryCatch(fit$ranef, error = function(e) NULL)
  if (!is.null(ranef) && "cov" %in% names(ranef)) {
    for (i in seq_len(nrow(ranef))) {
      cv <- ranef$cov[[i]]
      if (!is.null(cv) && !is.na(cv) && nzchar(as.character(cv))) {
        brms_phylo_groups <- c(brms_phylo_groups, as.character(ranef$group[[i]]))
      }
    }
    brms_phylo_groups <- unique(brms_phylo_groups)
  }
  has_brms_phylo <- length(brms_phylo_groups) > 0L
  if (has_brms_phylo) detected_signals <- c(detected_signals, "phylo")
  structured_matrices <- if (has_brms_phylo) {
    lapply(brms_phylo_groups, function(g) list(
      symbol             = "\\mathbf{A}",
      symbol_matrix      = "\\mathbf{A}",
      variable           = g,
      units              = NA_character_,
      role               = "structured_correlation_phylo",
      dimension          = "\\mathbb{R}^{k \\times k}",
      dimension_concrete = sprintf("\\mathbb{R}^{k_{%s} \\times k_{%s}}", g, g),
      description        = sprintf("phylogenetic correlation matrix on %s, attached via gr(%s, cov = A) (tips-only k x k representation)", g, g)
    ))
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
  expanded <- brms_build_expanded(fit)

  metadata <- list(
    call = fit$call,
    context = context %||% "",
    # brms gives credible intervals (Bayesian), not confidence intervals.
    # Downstream renderers can use ci_method to phrase the band correctly.
    ci_method = "credible",
    fit = fit,
    package_versions = list(
      symbolizer = utils::packageVersion("symbolizer"),
      brms       = utils::packageVersion("brms")
    ),
    phylo_representation = if (has_brms_phylo) "tips_only" else NULL,
    detected_signals = detected_signals,
    created_by = "symbolize.brmsfit"
  )

  sym_stub <- list(
    model = model, metadata = metadata, random_effects = re_tbl
  )
  warnings_tbl <- brms_build_warnings(fit, sym_stub)

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

# Does the fit's brmsformula have a per-distributional-parameter formula
# (e.g. sigma ~ x)? brms stores these as `pforms` on the brmsformula.
brms_has_distributional_formula <- function(fit) {
  bf <- fit$formula
  pforms <- bf$pforms %||% list()
  length(pforms) > 0L
}

# Pull the RHS of an R formula as an unevaluated expression.
brms_rhs_expr <- function(f) {
  if (length(f) == 3L) f[[3L]] else f[[2L]]
}

# Response variable name from a brmsfit. brms's `fit$formula$resp` is
# a *Stan-safe* identifier that strips characters Stan can't handle
# (notably `_`), so for response = "body_mass" the resp slot reports
# "bodymass". We want the original column name in the data, so parse
# the formula LHS directly.
brms_response_name <- function(fit) {
  f <- fit$formula$formula
  if (length(f) == 3L) {
    v <- all.vars(f[[2L]])
    if (length(v) >= 1L && nzchar(v[[1L]])) return(v[[1L]])
  }
  r <- fit$formula$resp
  if (!is.null(r) && nzchar(r)) return(r)
  ""
}

# Symbol for the response (user override or default to variable name).
brms_resolve_response_symbol <- function(response, symbols) {
  if (!is.null(symbols) && !is.null(symbols[[response]])) {
    return(as.character(symbols[[response]]))
  }
  response
}

# Submodels tibble: one row for the conditional submodel.
brms_build_submodels <- function(entries, fit, param, link_mu) {
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

# Per-dpar random-effects tibble. v0.8 first slice handles only mu's
# `(1 | g)` and `(1 + x | g)` random intercepts / random slopes.
brms_re_terms <- function(fit, dpar) {
  if (dpar != "mu") return(NULL)
  # brms::VarCorr errors with "The model does not contain covariance
  # matrices" on fixed-effects-only fits. Catch and treat as no RE.
  vc <- tryCatch(brms::VarCorr(fit), error = function(e) NULL)
  if (is.null(vc)) return(NULL)
  # Drop the residual_ entry; only keep grouping variances.
  vc <- vc[!names(vc) %in% c("residual__")]
  if (length(vc) == 0L) return(NULL)
  rows <- list()
  for (g in names(vc)) {
    sd_mat <- vc[[g]]$sd
    cmp <- rownames(sd_mat)
    if (is.null(cmp)) next
    for (c in cmp) {
      n_levels <- length(unique(fit$data[[g]]))
      term_label <- if (c == "Intercept") {
        sprintf("(1 | %s)", g)
      } else {
        sprintf("(1 + %s | %s):%s", c, g, c)
      }
      # brms uses "Intercept" without parens; drmTMB-style is "(Intercept)".
      # Normalise so drm_assert_supported_re / drm_build_random_effects
      # recognise it as an intercept row.
      component <- if (c == "Intercept") "(Intercept)" else c
      rows[[length(rows) + 1L]] <- tibble::tibble(
        submodel    = "mu",
        term_label  = term_label,
        lhs_expr    = if (length(cmp) == 1L && c == "Intercept") "1"
                      else paste(cmp, collapse = " + "),
        group_var   = g,
        component   = component,
        n_levels    = as.integer(n_levels)
      )
    }
  }
  if (length(rows) == 0L) return(NULL)
  do.call(rbind, rows)
}

# Fixed-effects tibble. brms's fixef() returns a matrix with columns
# Estimate, Est.Error, Q2.5, Q97.5 -- directly usable as the
# credible-interval band.
brms_build_fixed_effects <- function(terms_tbl, fit) {
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
  fe <- brms::fixef(fit)
  # fe is a matrix; row names are coefficient names (Intercept, x,
  # sexmale, etc.). Columns: Estimate, Est.Error, Q2.5, Q97.5. When
  # bf() carries a sigma formula, sigma coefficients appear with
  # row name prefix "sigma_" (e.g. "sigma_Intercept", "sigma_x").
  estimate <- rep(NA_real_, nrow(terms_tbl))
  std_err  <- rep(NA_real_, nrow(terms_tbl))
  ci_low   <- rep(NA_real_, nrow(terms_tbl))
  ci_high  <- rep(NA_real_, nrow(terms_tbl))
  for (i in seq_len(nrow(terms_tbl))) {
    row <- terms_tbl[i, , drop = FALSE]
    if (is.na(row$coefficient_symbol)) next
    hit <- brms_hit_name(row)
    # Prefix non-mu rows with the submodel name (brms's convention).
    if (row$submodel != "mu") hit <- paste0(row$submodel, "_", hit)
    j <- which(rownames(fe) == hit)
    if (length(j) >= 1L) {
      estimate[i] <- as.numeric(fe[j[[1L]], "Estimate"])
      std_err[i]  <- as.numeric(fe[j[[1L]], "Est.Error"])
      ci_low[i]   <- as.numeric(fe[j[[1L]], "Q2.5"])
      ci_high[i]  <- as.numeric(fe[j[[1L]], "Q97.5"])
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

# Resolve the model-matrix column name (the "hit") for a term row.
# brms uses "Intercept" without parens (unlike drmTMB / glmmTMB).
brms_hit_name <- function(row) {
  if (row$term_label == "(Intercept)") return("Intercept")
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

# Variance components: posterior-mean SD per random-effects component
# plus the residual SD.
brms_build_variance_components <- function(fit, re_per_entry) {
  rows <- list()
  vc <- tryCatch(brms::VarCorr(fit), error = function(e) NULL)
  if (is.null(vc)) vc <- list()
  for (g in names(vc)) {
    if (g == "residual__") next
    sd_mat <- vc[[g]]$sd
    cmp <- rownames(sd_mat)
    if (is.null(cmp)) next
    for (c in cmp) {
      sd_est <- as.numeric(sd_mat[c, "Estimate"])
      rows[[length(rows) + 1L]] <- tibble::tibble(
        parameter   = "mu",
        group       = g,
        term        = if (c == "Intercept") "(Intercept)" else c,
        sd_estimate = sd_est,
        var_estimate = sd_est ^ 2
      )
    }
  }
  if (identical(fit$family$family, "gaussian") &&
      !is.null(vc$residual__$sd)) {
    sd_resid <- as.numeric(vc$residual__$sd[1L, "Estimate"])
    rows[[length(rows) + 1L]] <- tibble::tibble(
      parameter   = "residual",
      group       = "residual",
      term        = "Residual",
      sd_estimate = sd_resid,
      var_estimate = sd_resid ^ 2
    )
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(
      parameter = character(0), group = character(0), term = character(0),
      sd_estimate = double(0), var_estimate = double(0)
    ))
  }
  do.call(rbind, rows)
}

# Minimal expanded block. brms doesn't expose the design matrix as
# cleanly; use posterior_summary's point estimates.
brms_build_expanded <- function(fit) {
  list(
    y = as.numeric(fit$data[[brms_response_name(fit)]]),
    X = NULL,
    Z = NULL,
    beta = brms::fixef(fit)[, "Estimate"],
    u = NULL,
    fitted = NULL,
    residuals = NULL
  )
}

# Warning detection. Flag random-effect groups with few levels -- for
# Bayesian fits, this is less about CIs being wrong (the posterior
# handles it) and more about identifiability with weak priors.
brms_build_warnings <- function(fit, sym_stub) {
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
