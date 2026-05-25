# ----------------------------------------------------------------------------
# symbolize.lm / symbolize.glm
#
# v0.10 First slice extractors for base R lm() and glm() fits.
#
# lm objects:
#   fit$call             original call (has formula, data env)
#   formula(fit)         the formula
#   fit$model            the model frame (data + response)
#   coef(fit)            named numeric vector of coefficients
#   vcov(fit)            variance-covariance matrix
#   confint(fit)         frequentist CIs
#   summary(fit)$sigma   residual SD
#
# glm objects (inherit from lm):
#   fit$family$family    e.g. "gaussian", "binomial", "poisson"
#   fit$family$link      e.g. "identity", "logit", "log"
#   confint(fit)         profile-likelihood CIs (slow); add method = "Wald"
#                        via confint.default(fit) for fast Wald CIs.
#
# v0.10 scope (lm): Gaussian + identity link; fixed effects only (no RE
# structure exists for lm).
#
# v0.10 scope (glm): Gaussian / binomial / poisson families with their
# canonical links. Quasi families and offsets are deferred to v0.10.x.
# ----------------------------------------------------------------------------

#' Symbolize a base R lm() fit (Gaussian, v0.10 first slice)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from a base R
#' `lm` object. v0.10 covers the Gaussian conditional submodel only
#' (the only family `lm()` fits). The residual standard deviation
#' (`summary(fit)$sigma`) is exposed as the `sigma` variance component
#' but is not modelled -- `lm()` doesn't support distributional
#' regression on sigma.
#'
#' @section Confidence intervals:
#' CIs come from `stats::confint(fit)`. The method is "Wald-t" -- the
#' usual frequentist t-based CI you'd see in `summary(fit)`.
#' `ci_method` is set to `"wald"` for consistency with the other
#' frequentist extractors.
#'
#' @inheritParams symbolize
#' @return A `symbolized_model` object.
#' @export
symbolize.lm <- function(fit, symbols = NULL, units = NULL,
                         context = NULL, ...) {
  # glm objects inherit from lm; route them through symbolize.glm so
  # the family / link / capability checks work correctly.
  if (inherits(fit, "glm")) {
    return(symbolize.glm(fit, symbols = symbols, units = units,
                         context = context, ...))
  }
  family <- "gaussian"
  capability_check("lm", family, "mu")
  base_symbolize_impl(fit, family = family, link = "identity",
                      class_name = "lm", package_name = "stats",
                      symbols = symbols, units = units, context = context, ...)
}

#' Symbolize a base R glm() fit (Gaussian / binomial / poisson, v0.10 first slice)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from a base R
#' `glm` object. v0.10 covers Gaussian / binomial / poisson with their
#' canonical links (identity / logit / log). Quasi-families, offsets,
#' and family-specific weights are deferred via the capability registry.
#'
#' @inheritParams symbolize
#' @return A `symbolized_model` object.
#' @export
symbolize.glm <- function(fit, symbols = NULL, units = NULL,
                          context = NULL, ...) {
  family <- fit$family$family
  link <- fit$family$link
  if (is.null(family) || !nzchar(family)) {
    cli::cli_abort("Could not resolve {.code fit$family$family}.")
  }
  capability_check("glm", family, "mu")
  base_symbolize_impl(fit, family = family, link = link %||% "identity",
                      class_name = "glm", package_name = "stats",
                      symbols = symbols, units = units, context = context, ...)
}

# Shared lm / glm implementation. The two methods differ only in
# family / link / class_name; everything else is the same.
base_symbolize_impl <- function(fit, family, link, class_name, package_name,
                                 symbols, units, context, ...) {
  form <- stats::formula(fit)
  response <- all.vars(form[[2L]])[[1L]]
  data <- fit$model
  if (is.null(data)) data <- stats::model.frame(fit)
  n_obs <- as.integer(nrow(data))

  entries <- list(
    list(
      dpar = "mu",
      response = response,
      rhs = base_rhs_expr(form),
      expr = form,
      position = 1L
    )
  )

  param <- get_parameterization(family)
  index <- list(observation = "i", individual = "j",
                group = "g", trait = "k", time = "t")

  response_symbol <- base_resolve_response_symbol(response, symbols)
  response_symbol_matrix <- drm_response_symbol_matrix(response_symbol)
  response_units <- drm_resolve_units(response, units)

  model <- list(
    class = class_name,
    package = package_name,
    family = family,
    response = response,
    n_obs = n_obs
  )

  distribution <- drm_build_distribution(
    family, response_symbol, response_symbol_matrix,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )
  submodels  <- base_build_submodels(entries, fit, param, link)
  terms_tbl  <- drm_build_terms(entries, data, symbols)
  fixed_eff  <- base_build_fixed_effects(terms_tbl, fit)
  re_tbl     <- drm_build_random_effects(list())  # no random effects on lm/glm
  vc_tbl     <- base_build_variance_components(fit, family)
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
  expanded <- list(y = data[[response]], X = NULL, Z = NULL,
                   beta = stats::coef(fit), u = NULL,
                   fitted = stats::fitted(fit),
                   residuals = stats::residuals(fit))

  metadata <- list(
    call = fit$call,
    context = context %||% "",
    ci_method = "wald",
    fit = fit,
    package_versions = list(
      symbolizer = utils::packageVersion("symbolizer")
    ),
    created_by = sprintf("symbolize.%s", class_name)
  )

  sym_stub <- list(
    model = model, metadata = metadata, random_effects = re_tbl
  )
  warnings_tbl <- tibble::tibble(code = character(0),
                                  severity = character(0),
                                  message = character(0))

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

base_rhs_expr <- function(f) {
  if (length(f) == 3L) f[[3L]] else f[[2L]]
}

base_resolve_response_symbol <- function(response, symbols) {
  if (!is.null(symbols) && !is.null(symbols[[response]])) {
    return(as.character(symbols[[response]]))
  }
  response
}

base_build_submodels <- function(entries, fit, param, link_mu) {
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

# Fixed effects: estimates + Wald CIs from confint(). For glm, use
# confint.default() to get fast Wald CIs (the default confint() for glm
# uses profile likelihood which is slow).
base_build_fixed_effects <- function(terms_tbl, fit) {
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
  est_all <- stats::coef(fit)
  ci_df <- tryCatch(
    if (inherits(fit, "glm")) stats::confint.default(fit) else stats::confint(fit),
    error = function(e) NULL
  )
  se_all <- tryCatch(sqrt(diag(stats::vcov(fit))), error = function(e) NULL)

  estimate <- rep(NA_real_, nrow(terms_tbl))
  std_err  <- rep(NA_real_, nrow(terms_tbl))
  ci_low   <- rep(NA_real_, nrow(terms_tbl))
  ci_high  <- rep(NA_real_, nrow(terms_tbl))
  for (i in seq_len(nrow(terms_tbl))) {
    row <- terms_tbl[i, , drop = FALSE]
    if (is.na(row$coefficient_symbol)) next
    hit <- base_hit_name(row)
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
    ci_method = rep("wald", nrow(terms_tbl))
  )
}

base_hit_name <- function(row) {
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

# Variance components. lm has a residual SD only (no random effects).
# glm: for gaussian / quasi family, residual SD is sqrt(dispersion); for
# binomial / poisson, dispersion is fixed at 1 and not a "variance
# component" in the usual sense.
base_build_variance_components <- function(fit, family) {
  if (identical(family, "gaussian")) {
    sd_resid <- as.numeric(stats::sigma(fit))
    return(tibble::tibble(
      parameter   = "residual",
      group       = "residual",
      term        = "Residual",
      sd_estimate = sd_resid,
      var_estimate = sd_resid ^ 2
    ))
  }
  # Non-Gaussian glm: no row-level residual SD.
  tibble::tibble(
    parameter = character(0), group = character(0), term = character(0),
    sd_estimate = double(0), var_estimate = double(0)
  )
}
