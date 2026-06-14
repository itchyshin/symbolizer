# ----------------------------------------------------------------------------
# symbolize.gam
#
# v0.14 First slice extractor for mgcv generalized additive models.
# Targets the additive grammar:
#
#   g(mu_i) = beta_0 + sum_k beta_k x_{ki} + sum_l f_l(z_{li})
#   f_l(z_li) = sum_{j=1}^{K_l} b_j(z_li) alpha_{lj}        (basis expansion)
#   lambda_l * alpha_l^T S_l alpha_l                         (smoothing penalty)
#
# The fitted gam object exposes:
#
#   fit$formula              full formula  y ~ s(x) + z
#   fit$family$family        e.g. "gaussian"
#   fit$family$link          e.g. "identity"
#   fit$smooth               list of smooth specifications, each with
#                              $label (e.g. "s(x)"), $bs.dim (K),
#                              $term (the underlying variable),
#                              $by (factor name for s(x, by = ...)),
#                              $first.para / $last.para indices into coef
#   fit$sp                   smoothing parameters lambda_l (one per smooth)
#   fit$nsdf                 number of parametric (non-smooth) coefficients
#   summary(fit)$p.coeff     parametric coefficient estimates
#   summary(fit)$p.t         parametric t-statistics
#   summary(fit)$se          standard errors (parametric + smooth-flat)
#   summary(fit)$s.table     smooth-term summary: edf, Ref.df, F, p-value
#   fit$model                model frame
#
# v0.14 scope: gaussian / poisson / binomial / Gamma families;
# s(x), s(x, by = factor), te(x, z) smooths; REML. Other smooth
# classes (bs = "re", bs = "fs", soap-film, etc.) are still
# Planned. mgcv::gamm() and gamm4::gamm4() return lists with a `$gam`
# slot of class "gam" -- pass that slot to `symbolize()` (e.g.,
# `symbolize(fit_gamm$gam)`).
# ----------------------------------------------------------------------------

#' Symbolize an mgcv gam / bam fit (additive grammar, v0.14 first slice)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from an
#' `mgcv::gam()` or `mgcv::bam()` fit. The first slice covers
#' gaussian / poisson / binomial / Gamma families with smooth
#' specifications `s(x)`, `s(x, by = factor)`, and `te(x, z)`.
#'
#' For `mgcv::gamm()` or `gamm4::gamm4()`, both return a list with a
#' `$gam` component of class `"gam"`. Pass that component to
#' `symbolize()`:
#' ```
#' g <- mgcv::gamm(y ~ s(x), random = list(g = ~1), data = d)
#' sym <- symbolize(g$gam)
#' ```
#' Correlation structures and lme4-style random effects from `gamm` /
#' `gamm4` are reflected via the `$gam` object's smooth and
#' parametric-coefficient blocks; the GAMM-specific covariance
#' structures are not separately rendered in v0.14.
#'
#' @section Confidence intervals:
#' Parametric (non-smooth) coefficients in `fixed_effects` carry
#' approximate Wald 95% CIs computed as estimate ± 1.96 * SE from
#' `summary(fit)$p.coeff` / `summary(fit)$se`. Smooth-term inference
#' is summarised separately in `sym$metadata$smooths` (basis
#' dimension, edf, p-value per smooth) rather than a single
#' coefficient row.
#'
#' @inheritParams symbolize
#'
#' @references
#' Wood, S. N. (2017). *Generalized Additive Models: An Introduction
#' with R* (2nd ed.). Chapman and Hall/CRC.
#'
#' Wood, S. N. (2011). Fast stable restricted maximum likelihood and
#' marginal likelihood estimation of semiparametric generalized linear
#' models. *Journal of the Royal Statistical Society (B)*, 73(1),
#' 3-36.
#'
#' @return A `symbolized_model` object.
#' @export
symbolize.gam <- function(fit, symbols = NULL, units = NULL,
                          context = NULL, ...) {
  if (!requireNamespace("mgcv", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg mgcv} is needed to symbolize this fit.",
      i = "Install it with {.code install.packages(\"mgcv\")}."
    ))
  }
  family <- fit$family$family
  link   <- fit$family$link %||% "identity"
  if (is.null(family) || !nzchar(family)) {
    cli::cli_abort("Could not resolve {.code fit$family$family}.")
  }
  capability_check("gam", family, "mu")

  has_smooths <- !is.null(fit$smooth) && length(fit$smooth) > 0L
  if (has_smooths) {
    capability_check("gam", family, "smooth")
  }

  cond_form <- fit$formula
  response <- all.vars(cond_form[[2L]])[[1L]]
  data <- fit$model
  n_obs <- as.integer(nrow(data))

  # Parametric (non-smooth) side: build entries from the parametric
  # subset of the formula. mgcv exposes parametric-only terms in
  # fit$pterms.
  param_terms <- if (!is.null(fit$pterms)) attr(fit$pterms, "term.labels") else character(0)
  param_intercept <- attr(fit$pterms %||% stats::terms(cond_form), "intercept") == 1L
  param_rhs <- if (length(param_terms) == 0L) {
    if (param_intercept) "1" else "0"
  } else {
    paste(c(if (!param_intercept) "0", param_terms), collapse = " + ")
  }
  param_form <- stats::as.formula(paste(response, "~", param_rhs))
  entries <- list(
    list(
      dpar = "mu",
      response = response,
      rhs = mgcv_rhs_expr(param_form),
      expr = param_form,
      position = 1L
    )
  )

  param <- get_parameterization(family)
  index <- list(observation = "i", individual = "j", group = "g", trait = "k")

  response_symbol <- mgcv_resolve_response_symbol(response, symbols)
  response_symbol_matrix <- drm_response_symbol_matrix(response_symbol)
  response_units <- drm_resolve_units(response, units)

  model <- list(
    class = "gam",
    package = "mgcv",
    family = family,
    response = response,
    n_obs = n_obs,
    method = fit$method,
    smooth_count = if (has_smooths) length(fit$smooth) else 0L
  )

  distribution <- drm_build_distribution(
    family, response_symbol, response_symbol_matrix,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )
  submodels  <- mgcv_build_submodels(entries, param, link)
  # An mgcv gam/bam fit estimates at most a SINGLE constant scale parameter
  # (gaussian residual variance fit$sig2, Gamma scale phi) and never a
  # dispersion SUBMODEL -- its submodels table carries only `mu`. Flag this so
  # the shared drmTMB builders drop the phantom log-linked sigma submodel from
  # the assumptions block and gloss sigma_i as a constant scale (not "on the
  # log scale"). Self-correcting: if a future mgcv extractor ever adds a
  # dispersion submodel, the flag flips off and the real submodel is kept.
  constant_scale <- !any(submodels$parameter %in% c("sigma", "sigma1", "sigma2"))
  terms_tbl  <- drm_build_terms(entries, data, symbols)
  factor_cod <- build_factor_coding(data, terms_tbl, fit)
  fixed_eff  <- mgcv_build_fixed_effects(terms_tbl, fit)
  re_tbl     <- drm_build_random_effects(list(NULL))
  vc_tbl     <- mgcv_build_variance_components(fit)
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
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_,
    constant_scale = constant_scale
  )
  assumptions <- drm_build_assumptions(
    family, response, response_symbol, re_tbl,
    response_1 = response, response_2 = NA_character_,
    link_mu = link, constant_scale = constant_scale
  )
  interp <- drm_build_interpretation(
    fixed_eff, family, response, data,
    response_1 = response, response_2 = NA_character_,
    link_mu = link
  )
  bridge <- drm_build_formula_bridge(
    entries, components, response,
    response_1 = response, response_2 = NA_character_
  )
  # Tab 3 ("equations with data") needs the design matrix X, the
  # response-scale fitted mean mu_hat, and the link-scale linear predictor
  # eta_hat; without X the stacked-matrix + worked-row block falls back to
  # the "design matrix not captured" placeholder (audit B1). For a gam the
  # `model.matrix(fit)` columns include the smooth basis and align with
  # `coef(fit)`, so X*beta = eta_hat. Each accessor is wrapped so a fit
  # that cannot produce a model matrix degrades to NULL.
  X_mat   <- tryCatch(stats::model.matrix(fit), error = function(e) NULL)
  mu_hat  <- tryCatch(as.numeric(stats::fitted(fit)), error = function(e) NULL)
  eta_hat <- tryCatch(as.numeric(stats::predict(fit, type = "link")),
                      error = function(e) mu_hat)
  e_resid <- tryCatch(as.numeric(stats::residuals(fit)), error = function(e) NULL)
  expanded <- list(y = data[[response]], X = X_mat, Z = NULL,
                   beta = stats::coef(fit), u = NULL,
                   eta_hat = eta_hat, mu_hat = mu_hat, e = e_resid,
                   fitted = stats::fitted(fit),
                   residuals = stats::residuals(fit))

  # Smooth terms: one tibble per smooth, captured in metadata$smooths.
  smooth_tbl <- mgcv_build_smooth_table(fit)

  # Post-process the mu linear-predictor LaTeX to append the smooth
  # terms (f_1(x_i), f_2(z_i), ...) so the additive structure shows.
  components <- mgcv_append_smooths(components, smooth_tbl)

  metadata <- list(
    call = fit$call,
    context = context %||% "",
    ci_method = "wald",
    fit = fit,
    package_versions = list(
      symbolizer = utils::packageVersion("symbolizer"),
      mgcv       = utils::packageVersion("mgcv")
    ),
    method = fit$method,
    smooths = smooth_tbl,
    smoothing_params = fit$sp,
    created_by = "symbolize.gam"
  )

  sym_stub <- list(
    model = model, metadata = metadata, random_effects = re_tbl
  )
  warnings_tbl <- mgcv_build_warnings(fit, sym_stub)

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

# bam inherits from gam, so a default method-resolution would already
# hit symbolize.gam. Adding the explicit method for clarity and so
# class(fit)[1L] == "bam" prints correctly in errors.
#' @rdname symbolize.gam
#' @export
symbolize.bam <- symbolize.gam

# ---- helpers ---------------------------------------------------------------

mgcv_rhs_expr <- function(f) {
  if (length(f) == 3L) f[[3L]] else f[[2L]]
}

mgcv_resolve_response_symbol <- function(response, symbols) {
  if (!is.null(symbols) && !is.null(symbols[[response]])) {
    return(as.character(symbols[[response]]))
  }
  default_response_symbol(response)
}

mgcv_build_submodels <- function(entries, param, link_mu) {
  rows <- lapply(entries, function(e) {
    dpar <- e$dpar
    coef_family <- drm_coef_family_for(dpar)
    f <- stats::as.formula(paste("~", paste(deparse(e$rhs), collapse = " ")))
    tibble::tibble(
      parameter = dpar,
      formula = list(f),
      link = link_mu,
      coef_family = coef_family,
      position = e$position
    )
  })
  do.call(rbind, rows)
}

# Pull parametric coefficients (intercept + non-smooth predictors)
# from summary(fit)$p.coeff. Wald CIs use the standard
# error and qnorm(0.975). Smooth-term coefficients are NOT included
# here; smooths are summarised in metadata$smooths.
mgcv_build_fixed_effects <- function(terms_tbl, fit) {
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
  s <- summary(fit)
  p_coef <- s$p.coeff
  # The parametric SEs are the first nsdf entries of s$se. The smooth-
  # term SEs follow; we don't use those here.
  nsdf <- fit$nsdf %||% length(p_coef)
  p_se <- if (!is.null(s$se)) s$se[seq_len(nsdf)] else stats::setNames(rep(NA_real_, nsdf), names(p_coef))
  q <- stats::qnorm(0.975)
  estimate <- rep(NA_real_, nrow(terms_tbl))
  std_err  <- rep(NA_real_, nrow(terms_tbl))
  ci_low   <- rep(NA_real_, nrow(terms_tbl))
  ci_high  <- rep(NA_real_, nrow(terms_tbl))
  for (i in seq_len(nrow(terms_tbl))) {
    row <- terms_tbl[i, , drop = FALSE]
    if (is.na(row$coefficient_symbol)) next
    hit <- mgcv_hit_name(row)
    if (hit %in% names(p_coef)) {
      estimate[i] <- as.numeric(p_coef[hit])
      se_i <- if (hit %in% names(p_se)) as.numeric(p_se[hit]) else NA_real_
      std_err[i] <- se_i
      if (!is.na(se_i)) {
        ci_low[i]  <- estimate[i] - q * se_i
        ci_high[i] <- estimate[i] + q * se_i
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

mgcv_hit_name <- function(row) {
  if (row$term_label == "(Intercept)") return("(Intercept)")
  if (row$role == "factor_contrast" &&
      !is.na(row$contrast_level) && nzchar(row$contrast_level)) {
    return(paste0(row$variable, row$contrast_level))
  }
  # A factor-involving interaction's parametric coefficient is named "gb:x" /
  # "gb:hq", not the raw term label "g:x" -- reconstruct it so the estimate is
  # not dropped to NA.
  if (!is.na(row$role) && row$role == "interaction") {
    return(mm_interaction_hit(row$term_label, row$contrast_level))
  }
  row$term_label
}

# Smooth-term summary table: one row per smooth with label, basis
# dimension, edf, p-value, and the underlying variable.
mgcv_build_smooth_table <- function(fit) {
  if (is.null(fit$smooth) || length(fit$smooth) == 0L) {
    return(tibble::tibble(
      label = character(0), bs_dim = integer(0), edf = double(0),
      p_value = double(0), variable = character(0), by_var = character(0),
      smooth_class = character(0)
    ))
  }
  s <- summary(fit)
  s_tab <- s$s.table %||% matrix(NA_real_, 0L, 4L)
  rows <- list()
  for (i in seq_along(fit$smooth)) {
    sm <- fit$smooth[[i]]
    label <- sm$label
    bs_dim <- as.integer(sm$bs.dim %||% NA_integer_)
    edf <- if (label %in% rownames(s_tab)) as.numeric(s_tab[label, "edf"]) else NA_real_
    p_value <- if (label %in% rownames(s_tab) && "p-value" %in% colnames(s_tab)) {
      as.numeric(s_tab[label, "p-value"])
    } else NA_real_
    variable <- if (!is.null(sm$term)) paste(sm$term, collapse = ":") else NA_character_
    by_var <- if (!is.null(sm$by) && nzchar(sm$by) && sm$by != "NA") sm$by else NA_character_
    smooth_class <- if (!is.null(class(sm)) && length(class(sm)) > 0L) {
      class(sm)[[1L]]
    } else NA_character_
    rows[[length(rows) + 1L]] <- tibble::tibble(
      label = label,
      bs_dim = bs_dim,
      edf = edf,
      p_value = p_value,
      variable = variable,
      by_var = by_var,
      smooth_class = smooth_class
    )
  }
  do.call(rbind, rows)
}

# Variance components: residual SD (for gaussian) and smoothing
# parameters lambda_l (one per smooth term). Smoothing parameters
# are not "variance" in the usual sense but they live in this
# tibble for convenience -- `kind = "smoothing_param"` distinguishes.
mgcv_build_variance_components <- function(fit) {
  rows <- list()
  if (identical(fit$family$family, "gaussian") && !is.null(fit$sig2)) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      parameter    = "residual",
      group        = "residual",
      term         = "Residual",
      sd_estimate  = sqrt(as.numeric(fit$sig2)),
      var_estimate = as.numeric(fit$sig2),
      kind         = "residual"
    )
  }
  # Non-Gaussian families with an estimated scale (e.g. Gamma, scat) carry a
  # single constant dispersion phi = fit$sig2 = summary(fit)$dispersion. In the
  # drmTMB Gamma parameterisation the equation's sigma_i satisfies
  # sigma_i^2 = phi (Var = sigma^2 * mu^2), so var_estimate = phi = sigma_i^2 and
  # sd_estimate = sqrt(phi) = sigma_i. Fixed-scale families (poisson, binomial:
  # scale.estimated FALSE) carry no scale parameter and get no row.
  if (!identical(fit$family$family, "gaussian") &&
      !is.null(fit$sig2) && isTRUE(fit$scale.estimated)) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      parameter    = "sigma",
      group        = "dispersion",
      term         = "Dispersion (scale)",
      sd_estimate  = sqrt(as.numeric(fit$sig2)),
      var_estimate = as.numeric(fit$sig2),
      kind         = "dispersion"
    )
  }
  if (!is.null(fit$sp) && length(fit$sp) > 0L) {
    for (i in seq_along(fit$sp)) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        parameter    = "mu",
        group        = "smooth",
        term         = names(fit$sp)[[i]] %||% sprintf("smooth_%d", i),
        sd_estimate  = NA_real_,
        var_estimate = as.numeric(fit$sp[[i]]),
        kind         = "smoothing_param"
      )
    }
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(
      parameter = character(0), group = character(0), term = character(0),
      sd_estimate = double(0), var_estimate = double(0), kind = character(0)
    ))
  }
  do.call(rbind, rows)
}

# Append smooth-term symbols to the mu linear-predictor row of the
# components tibble. Each smooth contributes `f_l(x_i)` (or
# `f_{l}(x_i, z_i)` for `te(x, z)` / tensor products) added to the
# index-form equation and `\mathbf{f}_l` added to the matrix form.
mgcv_append_smooths <- function(components, smooth_tbl) {
  if (is.null(components) || nrow(components) == 0L) return(components)
  if (is.null(smooth_tbl) || nrow(smooth_tbl) == 0L) return(components)
  mu_idx <- which(components$submodel == "mu")
  if (length(mu_idx) == 0L) return(components)
  i <- mu_idx[[1L]]
  smooth_terms_index <- vapply(seq_len(nrow(smooth_tbl)), function(j) {
    vars <- strsplit(smooth_tbl$variable[[j]], ":", fixed = TRUE)[[1L]]
    var_subs <- paste0(vars, "_i", collapse = ",\\, ")
    sprintf("f_{%d}(%s)", j, var_subs)
  }, character(1L))
  smooth_terms_matrix <- vapply(seq_len(nrow(smooth_tbl)), function(j) {
    sprintf("\\mathbf{f}_{%d}", j)
  }, character(1L))
  add_idx <- paste(smooth_terms_index, collapse = " + ")
  add_mat <- paste(smooth_terms_matrix, collapse = " + ")
  if ("equation" %in% names(components)) {
    components$equation[[i]] <- paste(components$equation[[i]], "+", add_idx)
  }
  if ("equation_matrix" %in% names(components)) {
    components$equation_matrix[[i]] <- paste(components$equation_matrix[[i]],
                                              "+", add_mat)
  }
  components
}

mgcv_build_warnings <- function(fit, sym_stub) {
  rows <- list()
  # Detect when an edf is suspiciously close to its basis dimension.
  s <- summary(fit)
  if (!is.null(fit$smooth) && length(fit$smooth) > 0L && !is.null(s$s.table)) {
    s_tab <- s$s.table
    for (i in seq_along(fit$smooth)) {
      sm <- fit$smooth[[i]]
      label <- sm$label
      if (!label %in% rownames(s_tab)) next
      edf <- as.numeric(s_tab[label, "edf"])
      bs_dim <- as.integer(sm$bs.dim %||% NA_integer_)
      if (!is.na(edf) && !is.na(bs_dim) && bs_dim - edf < 1) {
        rows[[length(rows) + 1L]] <- tibble::tibble(
          code = "smooth_at_basis_limit",
          severity = "warning",
          message = sprintf(
            "Smooth %s has edf %.2f close to basis dimension %d -- consider increasing k via s(%s, k = ...). See mgcv::gam.check().",
            label, edf, bs_dim, paste(sm$term, collapse = ", ")
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
