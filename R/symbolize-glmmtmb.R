# ----------------------------------------------------------------------------
# symbolize.glmmTMB
#
# v0.7 First slice extractor for glmmTMB fits. Targets the Gaussian
# location (and optional location-scale) family with optional
# `(1 | g)` random intercepts on the conditional submodel.
#
# The fitted glmmTMB object exposes (relevant pieces):
#
#   fit$modelInfo$allForm$formula      conditional formula:  y ~ x + (1 | g)
#   fit$modelInfo$allForm$dispformula  dispersion formula:   ~1   (default)
#                                                          or ~ z  (distributional)
#   fit$modelInfo$allForm$ziformula    zero-inflation:       ~0   (off)
#   fit$modelInfo$respCol              named integer; name == response var
#   fit$modelInfo$grpVar               character vector of grouping vars
#   fit$modelInfo$family$family        e.g. "gaussian"
#   fit$modelInfo$family$link          e.g. "identity"
#   fit$frame                          model frame used to fit
#   fixef(fit)                         list of $cond, $zi, $disp numeric vectors
#   ranef(fit)                         list of per-group random-effect estimates
#   VarCorr(fit)                       per-grouping vc structure + residual sigma
#   sigma(fit)                         residual SD (Gaussian)
#   confint(fit, parm, method)         Wald / profile / uniroot confidence band
#
# v0.7 scope: Gaussian + identity link, fixed effects, optional (1 | g)
# random intercepts on the conditional submodel, optional `dispformula = ~ z`
# producing a sigma submodel. zi formula is not supported in the first slice
# (capability registry will reject it).
# ----------------------------------------------------------------------------

#' Symbolize a glmmTMB fit (Gaussian, v0.7 first slice)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from a `glmmTMB` fit.
#' v0.7 covers the Gaussian conditional submodel (identity link) with
#' optional `(1 | g)` random intercepts and an optional distributional
#' dispformula. Other families and zero-inflation submodels return
#' capability errors via [`capability_check()`].
#'
#' @section Confidence intervals:
#' The returned `fixed_effects` and `interpretation` tibbles carry a
#' confidence band per coefficient: `confint_low`, `confint_high`,
#' `excludes_zero`, plus a `ci_method` column. The default
#' `ci_method = "wald"` is fast and matches `confint(fit, method = "wald")`.
#' `"profile"` and `"uniroot"` are available for slower, more honest
#' bands.
#'
#' @inheritParams symbolize
#' @param ci_method Confidence-interval method passed to
#'   [`glmmTMB::confint.glmmTMB`]. One of `"wald"` (default, fast),
#'   `"profile"`, or `"uniroot"`.
#'
#' @references
#' Brooks, M. E., Kristensen, K., van Benthem, K. J., Magnusson, A.,
#' Berg, C. W., Nielsen, A., Skaug, H. J., Maechler, M., & Bolker,
#' B. M. (2017). glmmTMB Balances Speed and Flexibility Among
#' Packages for Zero-inflated Generalized Linear Mixed Models. *The
#' R Journal*, 9(2), 378-400.
#'
#' @return A `symbolized_model` object.
#' @export
symbolize.glmmTMB <- function(fit, symbols = NULL, units = NULL,
                              context = NULL, ci_method = "wald", ...) {
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg glmmTMB} is needed to symbolize this fit.",
      i = "Install it with {.code install.packages(\"glmmTMB\")}."
    ))
  }
  family <- fit$modelInfo$family$family
  link   <- fit$modelInfo$family$link %||% "identity"
  if (is.null(family) || !nzchar(family)) {
    cli::cli_abort("Could not resolve {.code fit$modelInfo$family$family}.")
  }
  # First-slice capability gate: Gaussian only.
  capability_check("glmmTMB", family, "mu")

  # Detect distributional dispersion (dispformula != ~1).
  disp_form  <- fit$modelInfo$allForm$dispformula
  has_sigma_sub <- !glmm_is_intercept_only(disp_form)
  if (has_sigma_sub) {
    capability_check("glmmTMB", family, "sigma")
  }

  # Detect ziformula. ~0 means no zero-inflation; anything else (~ 1 or
  # ~ x) creates a zi submodel.
  zi_form    <- fit$modelInfo$allForm$ziformula
  has_zi_sub <- !glmm_is_zero_formula(zi_form)
  if (has_zi_sub) {
    capability_check("glmmTMB", family, "zi")
  }

  # Resolve the response variable.
  response <- glmm_response_name(fit)
  if (!nzchar(response)) {
    cli::cli_abort("Could not resolve response variable from {.code fit$modelInfo$respCol}.")
  }
  data <- fit$frame
  n_obs <- as.integer(fit$modelInfo$nobs %||% nrow(data))

  # Detect meta-analysis-via-glmmTMB pattern: a RE block with
  # covariance code 11 (propto) means the user attached a known
  # correlation / covariance matrix -- the canonical meta-analytic
  # construction where v_i are known. .valid_covstruct maps
  # numeric blockCodes to names; we test for "propto" (and the
  # not-yet-released "equalto" if present).
  meta_via_glmmTMB <- glmm_detect_meta_pattern(fit)
  if (isTRUE(meta_via_glmmTMB)) {
    capability_check("glmmTMB", family, "propto")
  }

  # Build entries-shaped list so we can reuse drm_build_* helpers downstream.
  # Each entry has $dpar, $response, $rhs (an unevaluated expression),
  # $expr (the full formula), and $position (1, 2, ...).
  cond_form <- fit$modelInfo$allForm$formula
  entries <- list(
    list(
      dpar = "mu",
      response = response,
      rhs = glmm_rhs_expr(cond_form),
      expr = cond_form,
      position = 1L
    )
  )
  if (has_sigma_sub) {
    sigma_full <- stats::as.formula(
      paste("sigma ~", paste(deparse(glmm_rhs_expr(disp_form)), collapse = " ")),
      env = environment(disp_form)
    )
    entries[[length(entries) + 1L]] <- list(
      dpar = "sigma",
      response = NA_character_,
      rhs = glmm_rhs_expr(disp_form),
      expr = sigma_full,
      position = 2L
    )
  }
  if (has_zi_sub) {
    zi_full <- stats::as.formula(
      paste("zi ~", paste(deparse(glmm_rhs_expr(zi_form)), collapse = " ")),
      env = environment(zi_form)
    )
    entries[[length(entries) + 1L]] <- list(
      dpar = "zi",
      response = NA_character_,
      rhs = glmm_rhs_expr(zi_form),
      expr = zi_full,
      position = length(entries) + 1L
    )
  }

  # Extract random-effects per entry (drmTMB-shaped tibble or NULL).
  re_per_entry <- lapply(entries, function(e) glmm_re_terms(fit, e$dpar))
  has_re <- vapply(re_per_entry, function(x) !is.null(x), logical(1L))
  if (any(has_re)) {
    capability_check("glmmTMB", family, "random_effects")
    for (i in which(has_re)) {
      drm_assert_supported_re(re_per_entry[[i]], entries[[i]]$dpar)
    }
  }

  param <- get_parameterization(family)
  index <- list(observation = "i", individual = "j",
                group = "g", trait = "k", time = "t")

  response_symbol <- glmm_resolve_response_symbol(response, symbols)
  response_symbol_matrix <- drm_response_symbol_matrix(response_symbol)
  response_units <- drm_resolve_units(response, units)

  model <- list(
    class = "glmmTMB",
    package = "glmmTMB",
    family = family,
    response = response,
    n_obs = n_obs
  )

  # Strip RE terms from rhs of any entry that carries them. For
  # glmmTMB we also strip propto() / equalto() calls FIRST (they have
  # nested parens with `|` inside that confuse the generic RE stripper)
  # then run the standard RE strip for `(1 | g)` style blocks.
  entries_fe <- entries
  if (isTRUE(meta_via_glmmTMB)) {
    for (i in seq_along(entries_fe)) {
      entries_fe[[i]]$rhs <- glmm_strip_meta_calls(entries_fe[[i]]$rhs)
    }
  }
  for (i in which(has_re)) {
    entries_fe[[i]]$rhs <- drm_strip_re_terms(entries_fe[[i]]$rhs)
  }

  distribution <- drm_build_distribution(
    family, response_symbol, response_symbol_matrix,
    response_symbol_1 = response_symbol, response_symbol_2 = NA_character_
  )
  submodels  <- glmm_build_submodels(entries, fit, param, link)
  terms_tbl  <- drm_build_terms(entries_fe, data, symbols)
  fixed_eff  <- glmm_build_fixed_effects(terms_tbl, fit, ci_method = ci_method)
  re_tbl     <- drm_build_random_effects(re_per_entry)
  vc_tbl     <- glmm_build_variance_components(fit, re_per_entry)
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
  expanded <- glmm_build_expanded(fit, re_per_entry, has_re)

  metadata <- list(
    call = fit$call,
    context = context %||% "",
    ci_method = ci_method,
    fit = fit,
    package_versions = list(
      symbolizer = utils::packageVersion("symbolizer"),
      glmmTMB    = utils::packageVersion("glmmTMB")
    ),
    # v0.20: renamed from `meta_analysis_via_glmmTMB` because propto
    # is the phylogenetic / structured-covariance bridge, not meta-analysis.
    # We also keep the old field set to the same value as a deprecation
    # alias so downstream code that still reads the old name keeps
    # working until the next major version.
    propto_known_corr_block  = isTRUE(meta_via_glmmTMB),
    meta_analysis_via_glmmTMB = isTRUE(meta_via_glmmTMB),  # deprecated alias
    created_by = "symbolize.glmmTMB"
  )

  sym_stub <- list(
    model = model, metadata = metadata, random_effects = re_tbl
  )
  warnings_tbl <- glmm_build_warnings(fit, sym_stub)

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

# Is a formula effectively `~1` (the default disp / cond intercept-only)?
glmm_is_intercept_only <- function(f) {
  if (is.null(f)) return(TRUE)
  txt <- paste(deparse(f), collapse = " ")
  txt <- gsub("\\s+", "", txt)
  identical(txt, "~1")
}

# Is a formula effectively `~0` (zero-inflation off)?
glmm_is_zero_formula <- function(f) {
  if (is.null(f)) return(TRUE)
  txt <- paste(deparse(f), collapse = " ")
  txt <- gsub("\\s+", "", txt)
  identical(txt, "~0")
}

# Pull the RHS of a formula (or one-sided formula's only side) as an
# unevaluated R expression.
glmm_rhs_expr <- function(f) {
  if (length(f) == 3L) f[[3L]] else f[[2L]]
}

# Resolve the response variable name from a glmmTMB fit. The respCol is a
# named integer where the name is the response column in fit$frame.
glmm_response_name <- function(fit) {
  rc <- fit$modelInfo$respCol
  if (!is.null(names(rc)) && nzchar(names(rc)[[1L]])) return(names(rc)[[1L]])
  f <- fit$modelInfo$allForm$formula
  if (length(f) == 3L) return(all.vars(f[[2L]])[[1L]])
  ""
}

# User-provided symbols override the response symbol; otherwise default
# to the response variable name (LaTeX-safe).
glmm_resolve_response_symbol <- function(response, symbols) {
  if (!is.null(symbols) && !is.null(symbols[[response]])) {
    return(as.character(symbols[[response]]))
  }
  response
}

# Build the submodels tibble (parameter, formula, link, coef_family,
# position). Mirrors drm_build_submodels but reads from the glmmTMB
# allForm slots and conventional links.
glmm_build_submodels <- function(entries, fit, param, link_mu) {
  rows <- lapply(entries, function(e) {
    dpar <- e$dpar
    coef_family <- drm_coef_family_for(dpar)
    link <- switch(
      dpar,
      mu    = link_mu,
      sigma = "log",
      zi    = "logit",
      "log"
    )
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

# Per-dpar random-effect tibble shaped like drm_re_terms's output:
# columns (submodel, term_label, lhs_expr, group_var, component, n_levels).
# Returns NULL when no random effects on this submodel.
glmm_re_terms <- function(fit, dpar) {
  if (dpar != "mu") return(NULL)  # v0.7 first slice: cond only
  vc <- glmmTMB::VarCorr(fit)$cond
  if (is.null(vc) || length(vc) == 0L) return(NULL)
  # Identify which RE blocks use propto / equalto (covariance code 11 in
  # glmmTMB 1.1.x). Those blocks are meta-analytic / phylogenetic
  # constructions, not user-facing random effects -- skip them so they
  # don't trip the standard intercept-shape assertion in
  # drm_assert_supported_re().
  cs <- fit$modelInfo$reStruc$condReStruc %||% list()
  meta_block_idx <- vapply(cs, function(x) {
    bc <- x$blockCode %||% NA
    if (is.null(bc) || length(bc) == 0L) return(FALSE)
    as.integer(bc) %in% c(11L)  # propto (and future equalto)
  }, logical(1L))
  rows <- list()
  for (i in seq_along(names(vc))) {
    if (length(meta_block_idx) >= i && isTRUE(meta_block_idx[[i]])) next
    g <- names(vc)[[i]]
    cmp <- rownames(vc[[g]])
    if (is.null(cmp)) next
    for (c in cmp) {
      n_levels <- length(unique(fit$frame[[g]]))
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

# Build fixed-effects tibble with the same shape as drm_build_fixed_effects,
# but pull estimates from fixef(fit)$cond / $disp and CIs from
# glmmTMB::confint(). glmmTMB's confint returns a data frame with rownames
# like "cond.(Intercept)" / "cond.x" / "d~(Intercept)" depending on version;
# we match on both styles defensively.
glmm_build_fixed_effects <- function(terms_tbl, fit, ci_method = "wald") {
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
  fe <- glmmTMB::fixef(fit)
  estimate <- rep(NA_real_, nrow(terms_tbl))
  glmm_fe_component <- function(submodel) {
    switch(submodel,
           mu = "cond",
           sigma = "disp",
           zi = "zi",
           "cond")
  }
  for (i in seq_len(nrow(terms_tbl))) {
    row <- terms_tbl[i, , drop = FALSE]
    if (is.na(row$coefficient_symbol)) next
    component <- glmm_fe_component(row$submodel)
    cf <- fe[[component]]
    if (is.null(cf)) next
    hit <- glmm_hit_name(row)
    if (hit %in% names(cf)) estimate[i] <- unname(cf[[hit]])
  }
  # CIs. glmmTMB::confint(fit, parm = "beta_") returns BOTH cond and disp
  # coefficients in a single call, with row names prefixed "cond." or
  # "disp.". We strip the prefix to match the term row's model-matrix
  # column. On any error (e.g., a singular Hessian on a tiny test fit)
  # leave CI columns NA rather than crash the extractor.
  ci_low  <- rep(NA_real_, nrow(terms_tbl))
  ci_high <- rep(NA_real_, nrow(terms_tbl))
  std_err <- rep(NA_real_, nrow(terms_tbl))
  ci_df <- tryCatch(
    stats::confint(fit, parm = "beta_", method = ci_method, level = 0.95),
    error = function(e) NULL
  )
  if (!is.null(ci_df)) {
    if (is.matrix(ci_df)) ci_df <- as.data.frame(ci_df)
    rn <- rownames(ci_df)
    # glmmTMB labels rows in one of two shapes depending on whether the
    # fit has more than one beta component:
    #   * Single component (cond only): rn = "(Intercept)", "x", ...
    #   * Multiple components (cond + disp / zi): rn = "cond.(Intercept)",
    #     "cond.x", "disp.(Intercept)", "disp.x", ...
    # Detect which shape we have and parse component / bare name accordingly.
    has_prefix <- any(grepl("^(cond|disp|zi)\\.", rn))
    if (has_prefix) {
      comp_prefix <- ifelse(grepl("^cond\\.", rn), "cond",
                     ifelse(grepl("^disp\\.", rn), "disp",
                     ifelse(grepl("^zi\\.",   rn), "zi", NA_character_)))
      bare <- sub("^(cond|disp|zi)\\.", "", rn)
    } else {
      # No prefix: all rows belong to "cond".
      comp_prefix <- rep("cond", length(rn))
      bare <- rn
    }
    for (i in seq_len(nrow(terms_tbl))) {
      want_comp <- glmm_fe_component(terms_tbl$submodel[i])
      hit <- glmm_hit_name(terms_tbl[i, , drop = FALSE])
      j <- which(comp_prefix == want_comp & bare == hit)
      if (length(j) >= 1L) {
        # Columns 1 / 2 are the lower / upper bounds across glmmTMB versions.
        ci_low[i]  <- as.numeric(ci_df[j[[1L]], 1L])
        ci_high[i] <- as.numeric(ci_df[j[[1L]], 2L])
        if (identical(ci_method, "wald")) {
          std_err[i] <- (ci_high[i] - ci_low[i]) / (2 * stats::qnorm(0.975))
        }
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
    ci_method = rep(ci_method, nrow(terms_tbl))
  )
}

# Compute the model-matrix column name (the "hit") for a term row,
# mirroring drm_build_fixed_effects's logic.
glmm_hit_name <- function(row) {
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

# Variance components for glmmTMB. Reads VarCorr() and the residual sigma,
# returns a tibble with (parameter, group, term, sd_estimate, var_estimate).
glmm_build_variance_components <- function(fit, re_per_entry) {
  rows <- list()
  vc <- glmmTMB::VarCorr(fit)$cond
  if (!is.null(vc) && length(vc) > 0L) {
    for (g in names(vc)) {
      sds <- attr(vc[[g]], "stddev")
      if (is.null(sds)) sds <- sqrt(diag(vc[[g]]))
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
  # Residual SD (Gaussian only -- sigma() reports it).
  if (identical(fit$modelInfo$family$family, "gaussian")) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      parameter   = "residual",
      group       = "residual",
      term        = "Residual",
      sd_estimate = as.numeric(glmmTMB::sigma(fit)),
      var_estimate = as.numeric(glmmTMB::sigma(fit)) ^ 2
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

# Build the "expanded" block -- numeric arrays behind the symbols. Minimal
# for v0.7 first slice; downstream `expand()` reads what is present and
# skips NULL fields gracefully.
glmm_build_expanded <- function(fit, re_per_entry, has_re) {
  y <- stats::model.response(fit$frame)
  list(
    y = if (is.numeric(y)) as.numeric(y) else NULL,
    X = NULL,
    Z = NULL,
    beta = glmmTMB::fixef(fit)$cond,
    u = NULL,
    fitted = stats::fitted(fit),
    residuals = stats::residuals(fit)
  )
}

# Warning detection. v0.7 first slice: flag random-effect groups with
# < 5 levels (Wald CIs on variance components get unreliable). v0.16
# adds a "this is a meta-analysis" info row when the fit uses propto()
# (and in future glmmTMB releases, equalto()).
glmm_build_warnings <- function(fit, sym_stub) {
  rows <- list()
  re <- sym_stub$random_effects
  if (!is.null(re) && nrow(re) > 0L && "n_levels" %in% names(re)) {
    small <- re[re$n_levels < 5L, , drop = FALSE]
    for (i in seq_len(nrow(small))) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        code = "few_re_levels",
        severity = "warning",
        message = sprintf(
          "Random-effect group %s has %d levels -- Wald CIs on the variance component are unreliable. Consider ci_method = \"profile\".",
          small$group_var[[i]], small$n_levels[[i]]
        ),
        context = ""
      )
    }
  }
  # v0.20: renamed from `meta_analysis_via_glmmTMB` to
  # `propto_known_corr_block`. v0.16-v0.19 set the old flag name; for
  # back-compat we honour both. The label change reflects the v0.20
  # correction: propto attaches Sigma = sigma^2 * V with sigma^2
  # estimated -- the phylogenetic / pedigree / known-correlation
  # pattern, NOT the meta-analytic fixed-V pattern. Fisher's empirical
  # audit on k = 30 simulated meta-analytic data showed the propto
  # scale converged to sigma^2_propto = 0.942742, not 1, with one
  # extra free parameter relative to metafor::rma.mv(V = V, ...).
  if (isTRUE(sym_stub$metadata$propto_known_corr_block) ||
      isTRUE(sym_stub$metadata$meta_analysis_via_glmmTMB)) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      code = "propto_known_corr_block",
      severity = "info",
      message = paste0(
        "This fit uses propto() to attach a covariance proportional to a known matrix V on a random-effect block: Sigma = sigma^2 * V, with sigma^2 estimated. ",
        "That is the phylogenetic / pedigree / structured-covariance pattern, equivalent to metafor::rma.mv(V = 0, random = ~ 1 | g, R = list(g = V)). ",
        "It is NOT the meta-analytic fixed-V pattern: metafor::rma.mv(V = V, ...) fixes Sigma = V exactly, with no scalar multiplier. ",
        "glmmTMB also estimates an independent residual sigma_res unless dispformula = ~ 0 is passed -- so the full conditional covariance under a propto fit is sigma^2_propto * V + sigma^2_res * I, two free scalars. ",
        "The exact meta-analytic GLMM bridge requires glmmTMB's planned equalto() block (Sigma = V, no multiplier), which is reserved but not yet implemented in glmmTMB <= 1.1.11. ",
        "References: Hadfield & Nakagawa 2010 (phylogenetic mixed models); Viechtbauer & L\u00F3pez-L\u00F3pez 2022 (location-scale meta-analysis); Nakagawa et al. 2025 (multilevel + phylo location-scale)."
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

# Strip propto() / equalto() calls from a formula's RHS. These are
# glmmTMB-internal covariance constructors that extract_terms can't
# evaluate. Returns the rhs with the meta-pattern call removed.
glmm_strip_meta_calls <- function(rhs_expr) {
  txt <- paste(deparse(rhs_expr), collapse = " ")
  # Strip propto(...) / equalto(...) including the surrounding "+".
  pattern <- "(propto|equalto)\\([^)]*\\)"
  txt <- gsub(paste0("\\+\\s*", pattern), "", txt)
  txt <- gsub(paste0(pattern, "\\s*\\+"), "", txt)
  txt <- gsub(pattern, "", txt)
  txt <- trimws(txt)
  if (!nzchar(txt)) txt <- "1"
  parse(text = txt)[[1L]]
}

# Detect the meta-analytic / phylogenetic pattern: a conditional RE
# block with covariance code 11 = propto (or in newer glmmTMB
# releases, "equalto"). Both fix the structure to a known correlation
# / covariance matrix.
glmm_detect_meta_pattern <- function(fit) {
  cs <- fit$modelInfo$reStruc$condReStruc
  if (is.null(cs) || length(cs) == 0L) return(FALSE)
  codes <- vapply(cs, function(x) {
    bc <- x$blockCode %||% NA
    if (is.null(bc) || length(bc) == 0L) NA_integer_ else as.integer(bc)
  }, integer(1L))
  # 11 = propto in glmmTMB 1.1.x. Future "equalto" may take a higher
  # code; .valid_covstruct is an internal glmmTMB lookup, so we fetch
  # it via getFromNamespace (no `:::` import declaration needed).
  valid <- tryCatch(
    utils::getFromNamespace(".valid_covstruct", "glmmTMB"),
    error = function(e) NULL
  )
  meta_codes <- if (!is.null(valid)) {
    unname(valid[names(valid) %in% c("propto", "equalto")])
  } else 11L
  any(codes %in% as.integer(meta_codes), na.rm = TRUE)
}
