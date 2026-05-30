# ----------------------------------------------------------------------------
# symbolize.lmerMod (and the glmerMod sibling)
#
# v0.10 First slice extractor for lme4 fits. Targets the Gaussian
# family (identity link) with optional `(1 | g)` random intercepts on
# the conditional submodel.
#
# lme4 fitted objects expose (relevant pieces):
#
#   formula(fit)        the conditional formula  e.g.  y ~ x + (1 | g)
#   fixef(fit)          named numeric vector of fixed-effect estimates
#   ranef(fit)          list of per-group random-effect estimates
#   VarCorr(fit)        per-grouping variance-covariance estimate;
#                       has a 'sc' attribute holding the residual SD
#   sigma(fit)          residual SD
#   confint(fit, parm) Wald or profile CIs
#   fit@frame           the data frame used to fit (S4 slot)
#
# v0.10 scope: Gaussian + identity link, fixed effects, optional
# (1 | g) random intercepts on the conditional submodel.
# ----------------------------------------------------------------------------

#' Symbolize an lme4 lmer() fit (Gaussian, v0.10 first slice)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from an
#' `lmerMod` object. v0.10 covers the Gaussian conditional submodel
#' with optional `(1 | g)` random intercepts. Generalised mixed
#' models (glmer / glmerMod) are routed through `symbolize.glmerMod`.
#'
#' @section Confidence intervals:
#' CIs come from `lme4::confint(fit, parm = "beta_", method = ci_method)`.
#' Default `ci_method = "Wald"`. Profile-likelihood CIs (`"profile"`)
#' are slower but more honest for fits with small group counts.
#' `ci_method` is stored on metadata as lowercase `"wald"` /
#' `"profile"`.
#'
#' @inheritParams symbolize
#' @param ci_method Confidence-interval method passed to
#'   `lme4::confint.merMod`. One of `"Wald"` (default, fast),
#'   `"profile"`, or `"boot"`.
#'
#' @references
#' Bates, D., Maechler, M., Bolker, B., & Walker, S. (2015). Fitting
#' Linear Mixed-Effects Models Using lme4. *Journal of Statistical
#' Software*, 67(1), 1-48.
#'
#' @return A `symbolized_model` object.
#' @export
symbolize.lmerMod <- function(fit, symbols = NULL, units = NULL,
                              context = NULL, ci_method = "Wald", ...) {
  if (!requireNamespace("lme4", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg lme4} is needed to symbolize this fit.",
      i = "Install it with {.code install.packages(\"lme4\")}."
    ))
  }
  family <- "gaussian"
  capability_check("lmerMod", family, "mu")
  lme4_symbolize_impl(fit, family = family, link = "identity",
                       class_name = "lmerMod",
                       symbols = symbols, units = units, context = context,
                       ci_method = ci_method, ...)
}

#' Symbolize an lme4 glmer() fit (binomial / poisson, v0.11 first slice)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from a
#' `glmerMod` object. v0.11 covers binomial / poisson families with
#' their canonical links, plus optional `(1 | g)` random intercepts.
#'
#' @inheritParams symbolize.lmerMod
#' @return A `symbolized_model` object.
#' @export
symbolize.glmerMod <- function(fit, symbols = NULL, units = NULL,
                               context = NULL, ci_method = "Wald", ...) {
  if (!requireNamespace("lme4", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg lme4} is needed to symbolize this fit.",
      i = "Install it with {.code install.packages(\"lme4\")}."
    ))
  }
  family <- fit@resp$family$family
  link <- fit@resp$family$link %||% "identity"
  if (is.null(family) || !nzchar(family)) {
    cli::cli_abort("Could not resolve {.code fit@resp$family$family}.")
  }
  capability_check("glmerMod", family, "mu")
  lme4_symbolize_impl(fit, family = family, link = link,
                       class_name = "glmerMod",
                       symbols = symbols, units = units, context = context,
                       ci_method = ci_method, ...)
}

# Shared lme4 implementation. Currently only used by lmerMod; the
# glmerMod sibling can be added later.
lme4_symbolize_impl <- function(fit, family, link, class_name,
                                 symbols, units, context, ci_method, ...) {
  form <- stats::formula(fit)
  response <- all.vars(form[[2L]])[[1L]]
  data <- fit@frame
  n_obs <- as.integer(nrow(data))

  entries <- list(
    list(
      dpar = "mu",
      response = response,
      rhs = lme4_rhs_expr(form),
      expr = form,
      position = 1L
    )
  )

  re_per_entry <- lapply(entries, function(e) lme4_re_terms(fit, e$dpar))
  has_re <- vapply(re_per_entry, function(x) !is.null(x), logical(1L))
  if (any(has_re)) {
    capability_check(class_name, family, "random_effects")
    for (i in which(has_re)) {
      drm_assert_supported_re(re_per_entry[[i]], entries[[i]]$dpar)
    }
  }

  param <- get_parameterization(family)
  index <- list(observation = "i", individual = "j",
                group = "g", trait = "k", time = "t")

  response_symbol <- lme4_resolve_response_symbol(response, symbols)
  response_symbol_matrix <- drm_response_symbol_matrix(response_symbol)
  response_units <- drm_resolve_units(response, units)

  model <- list(
    class = class_name,
    package = "lme4",
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
  submodels  <- lme4_build_submodels(entries, fit, param, link)
  terms_tbl  <- drm_build_terms(entries_fe, data, symbols)
  fixed_eff  <- lme4_build_fixed_effects(terms_tbl, fit, ci_method = ci_method)
  re_tbl     <- drm_build_random_effects(re_per_entry)
  vc_tbl     <- lme4_build_variance_components(fit, family)
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
    response_1 = response, response_2 = NA_character_,
    # lmer / glmer are homoscedastic: a single residual SD (lmer) or no
    # dispersion (glmer) -- never a scale submodel. Drop the location-scale
    # sigma rows the shared Gaussian template carries (audit P2 phantom-sigma).
    constant_scale = TRUE
  )
  interp <- drm_build_interpretation(
    fixed_eff, family, response, data,
    response_1 = response, response_2 = NA_character_
  )
  bridge <- drm_build_formula_bridge(
    entries, components, response,
    response_1 = response, response_2 = NA_character_
  )
  expanded <- list(y = data[[response]], X = NULL, Z = NULL,
                   beta = lme4::fixef(fit), u = NULL,
                   fitted = stats::fitted(fit),
                   residuals = stats::residuals(fit))

  metadata <- list(
    call = fit@call,
    context = context %||% "",
    ci_method = tolower(ci_method),
    fit = fit,
    package_versions = list(
      symbolizer = utils::packageVersion("symbolizer"),
      lme4       = utils::packageVersion("lme4")
    ),
    created_by = sprintf("symbolize.%s", class_name)
  )

  sym_stub <- list(
    model = model, metadata = metadata, random_effects = re_tbl
  )
  warnings_tbl <- lme4_build_warnings(fit, sym_stub)

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

lme4_rhs_expr <- function(f) {
  if (length(f) == 3L) f[[3L]] else f[[2L]]
}

lme4_resolve_response_symbol <- function(response, symbols) {
  if (!is.null(symbols) && !is.null(symbols[[response]])) {
    return(as.character(symbols[[response]]))
  }
  default_response_symbol(response)
}

lme4_build_submodels <- function(entries, fit, param, link_mu) {
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

lme4_re_terms <- function(fit, dpar) {
  if (dpar != "mu") return(NULL)
  vc <- lme4::VarCorr(fit)
  if (is.null(vc) || length(vc) == 0L) return(NULL)
  rows <- list()
  for (g in names(vc)) {
    mat <- vc[[g]]
    cmp <- if (!is.null(attr(mat, "stddev"))) names(attr(mat, "stddev"))
           else rownames(mat)
    if (is.null(cmp)) next
    for (c in cmp) {
      n_levels <- length(unique(fit@frame[[g]]))
      term_label <- if (c == "(Intercept)") {
        sprintf("(1 | %s)", g)
      } else {
        sprintf("(1 + %s | %s):%s", c, g, c)
      }
      rows[[length(rows) + 1L]] <- tibble::tibble(
        submodel    = "mu",
        term_label  = term_label,
        lhs_expr    = if (length(cmp) == 1L && c == "(Intercept)") "1"
                      else paste(cmp, collapse = " + "),
        group_var   = g,
        component   = c,
        n_levels    = as.integer(n_levels)
      )
    }
  }
  if (length(rows) == 0L) return(NULL)
  do.call(rbind, rows)
}

lme4_build_fixed_effects <- function(terms_tbl, fit, ci_method = "Wald") {
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
  est_all <- lme4::fixef(fit)
  # lme4 returns vcov as a Matrix::dpoMatrix; coerce to a base matrix
  # so diag() resolves to the dense base-R method.
  vc_mat <- tryCatch(as.matrix(stats::vcov(fit)), error = function(e) NULL)
  se_all <- if (!is.null(vc_mat)) sqrt(diag(vc_mat)) else NULL

  ci_df <- tryCatch(
    suppressWarnings(suppressMessages(
      stats::confint(fit, parm = "beta_", method = ci_method, level = 0.95)
    )),
    error = function(e) NULL
  )

  estimate <- rep(NA_real_, nrow(terms_tbl))
  std_err  <- rep(NA_real_, nrow(terms_tbl))
  ci_low   <- rep(NA_real_, nrow(terms_tbl))
  ci_high  <- rep(NA_real_, nrow(terms_tbl))
  for (i in seq_len(nrow(terms_tbl))) {
    row <- terms_tbl[i, , drop = FALSE]
    if (is.na(row$coefficient_symbol)) next
    hit <- lme4_hit_name(row)
    if (hit %in% names(est_all)) {
      estimate[i] <- unname(est_all[[hit]])
    }
    if (!is.null(se_all) && hit %in% names(se_all)) {
      std_err[i] <- unname(se_all[[hit]])
    }
    if (!is.null(ci_df) && hit %in% rownames(ci_df)) {
      ci_low[i]  <- as.numeric(ci_df[hit, 1L])
      ci_high[i] <- as.numeric(ci_df[hit, 2L])
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
    ci_method = rep(tolower(ci_method), nrow(terms_tbl))
  )
}

lme4_hit_name <- function(row) {
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

lme4_build_variance_components <- function(fit, family) {
  rows <- list()
  vc <- lme4::VarCorr(fit)
  if (length(vc) > 0L) {
    for (g in names(vc)) {
      mat <- vc[[g]]
      sds <- attr(mat, "stddev")
      if (is.null(sds)) sds <- sqrt(diag(mat))
      for (c in names(sds)) {
        rows[[length(rows) + 1L]] <- tibble::tibble(
          parameter   = "mu",
          group       = g,
          term        = c,
          sd_estimate = as.numeric(sds[[c]]),
          var_estimate = as.numeric(sds[[c]]) ^ 2
        )
      }
    }
  }
  if (identical(family, "gaussian")) {
    sd_resid <- as.numeric(stats::sigma(fit))
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

lme4_build_warnings <- function(fit, sym_stub) {
  rows <- list()
  re <- sym_stub$random_effects
  if (!is.null(re) && nrow(re) > 0L && "n_levels" %in% names(re)) {
    small <- re[re$n_levels < 5L, , drop = FALSE]
    for (i in seq_len(nrow(small))) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        code = "few_re_levels",
        severity = "warning",
        message = sprintf(
          "Random-effect group %s has %d levels - Wald CIs on the variance component are unreliable. Consider ci_method = 'profile'.",
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
