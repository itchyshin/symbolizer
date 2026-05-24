# ----------------------------------------------------------------------------
# symbolize.drmTMB
#
# v0.1 extractor for the drmTMB Gaussian location-scale family with fixed
# effects. The real `drmTMB` fitted object exposes:
#
#   fit$formula$entries     list of submodel entries, each with
#                             $dpar, $response, $lhs, $rhs, $expr, $position
#   fit$family$family       e.g. "gaussian" or "biv_gaussian"
#   fit$family$link         e.g. "identity"  (gaussian: drmTMB locks log on sigma)
#   fit$family$links        named character per dpar (biv_gaussian only)
#   fit$family$dpars        character vector of all dpars (biv_gaussian only)
#   fit$family$n_response   integer; 2 for biv_gaussian, 1 for univariate
#   fit$coefficients        list, one named numeric per dpar
#   drmTMB::fixef(fit, dpar) accessor for the same per-dpar estimates
#   fit$data                the original data frame
#   fit$nobs                sample size
#   fit$random_effects      list; non-empty when (1 | group) is present
#   fit$call                the original drmTMB() call
#
# Bivariate Gaussian (`biv_gaussian()`): five entries in fit$formula$entries,
# with dpars c("mu1", "mu2", "sigma1", "sigma2", "rho12"); the first two carry
# their own response variable (entry$response = "y1" / "y2"), the scale and
# correlation entries have no response. The rho12 link is "atanh_guarded",
# which is the Fisher z (tanh inverse) link with a guard near +/-1.
#
# Renderers consume the returned `symbolized_model`. No renderer is allowed
# to parse formulas itself; this extractor is the single source of truth.
# ----------------------------------------------------------------------------

#' Symbolize a drmTMB fit (Gaussian and bivariate Gaussian, v0.1)
#'
#' Builds a [`symbolized_model`][new_symbolized_model] from a `drmTMB` fit.
#' v0.1 covers the Gaussian location-scale fixed-effects path (with optional
#' `(1 | group)` random intercepts on `mu`) and the bivariate Gaussian
#' (`biv_gaussian()`) location-scale-correlation path. Other families and
#' components return capability errors via [`capability_check()`].
#'
#' @section Confidence intervals:
#' The returned `fixed_effects` and `interpretation` tibbles carry a confidence
#' band per coefficient: `confint_low`, `confint_high`, `excludes_zero`, plus
#' a `ci_method` column recording which method produced them. The default
#' `ci_method = "wald"` is fast and is what `drmTMB::confint(fit, method = "wald")`
#' returns by default. Wald intervals can be too narrow when group counts
#' are small (finite-df situations). For more honest intervals, pass
#' `ci_method = "profile"` — slower but profile-likelihood-based.
#' Satterthwaite / Kenward-Roger corrections are not implemented; when Wald
#' looks suspicious the recommended alternative is `"profile"`.
#'
#' @inheritParams symbolize
#' @param ci_method Confidence-interval method passed to
#'   [`drmTMB::confint`][drmTMB::confint.drmTMB]. One of `"wald"` (default,
#'   fast), `"profile"` (slower, more honest), or `"bootstrap"`.
#' @return A `symbolized_model` object.
#' @export
symbolize.drmTMB <- function(fit, symbols = NULL, units = NULL,
                             context = NULL, ci_method = "wald", ...) {
  entries <- fit$formula$entries
  if (!is.list(entries) || length(entries) == 0L) {
    cli::cli_abort("{.arg fit} has no submodel entries in {.code fit$formula$entries}.")
  }
  family <- fit$family$family
  is_biv <- identical(family, "biv_gaussian")
  # For biv_gaussian, the location entries (mu1, mu2) carry the two responses;
  # for univariate models the first entry carries the single response.
  if (is_biv) {
    responses <- vapply(entries, function(e) {
      r <- e$response
      if (is.null(r) || is.na(r) || !nzchar(r)) NA_character_ else r
    }, character(1L))
    responses <- responses[!is.na(responses)]
    if (length(responses) != 2L) {
      cli::cli_abort(c(
        "Expected two response variables for {.val biv_gaussian} but found {length(responses)}.",
        i = "Check {.code fit$formula$entries[[i]]$response} for mu1 and mu2."
      ))
    }
    response_1 <- responses[[1L]]
    response_2 <- responses[[2L]]
    response <- paste(response_1, response_2, sep = ", ")
  } else {
    response <- entries[[1L]]$response
    if (is.na(response) || !nzchar(response)) {
      cli::cli_abort("Could not resolve the response variable from {.code fit$formula$entries[[1]]$response}.")
    }
    response_1 <- response
    response_2 <- NA_character_
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

  if (is_biv) {
    # Per-response symbols; default to "Y_{1i}" / "Y_{2i}".
    response_symbol_1 <- drm_resolve_biv_response_symbol(response_1, symbols,
                                                         which = 1L)
    response_symbol_2 <- drm_resolve_biv_response_symbol(response_2, symbols,
                                                         which = 2L)
    response_symbol_matrix_1 <- drm_response_symbol_matrix(response_symbol_1)
    response_symbol_matrix_2 <- drm_response_symbol_matrix(response_symbol_2)
    # A single joint symbol used by some downstream pieces. Pair notation.
    response_symbol <- sprintf("(%s, %s)", response_symbol_1, response_symbol_2)
    response_symbol_matrix <- "\\mathbf{Y}"
    response_units <- NA_character_
  } else {
    response_symbol <- drm_resolve_response_symbol(response, symbols)
    response_symbol_matrix <- drm_response_symbol_matrix(response_symbol)
    response_units <- drm_resolve_units(response, units)
    response_symbol_1 <- response_symbol
    response_symbol_2 <- NA_character_
    response_symbol_matrix_1 <- response_symbol_matrix
    response_symbol_matrix_2 <- NA_character_
  }

  model <- list(
    class = "drmTMB",
    package = "drmTMB",
    family = family,
    response = response,
    n_obs = n_obs
  )
  if (is_biv) {
    model$responses <- c(response_1, response_2)
  }

  # For fixed-effects extraction, strip RE terms from the rhs of any entry
  # that carries them. The RE structure itself is rebuilt separately below.
  entries_fe <- entries
  for (i in which(has_re)) {
    entries_fe[[i]]$rhs <- drm_strip_re_terms(entries[[i]]$rhs)
  }

  distribution <- drm_build_distribution(family, response_symbol,
                                         response_symbol_matrix,
                                         response_symbol_1 = response_symbol_1,
                                         response_symbol_2 = response_symbol_2)
  submodels    <- drm_build_submodels(entries, fit, param)
  terms_tbl    <- drm_build_terms(entries_fe, data, symbols)
  fixed_eff    <- drm_build_fixed_effects(terms_tbl, fit, ci_method = ci_method)
  re_tbl       <- drm_build_random_effects(re_per_entry)
  vc_tbl       <- drm_build_variance_components(re_per_entry)
  components   <- drm_build_components(submodels, terms_tbl, re_tbl,
                                       response_symbol, response_symbol_matrix,
                                       family = family,
                                       response_symbol_1 = response_symbol_1,
                                       response_symbol_2 = response_symbol_2)
  symbol_dict  <- drm_build_symbol_dictionary(
    terms_tbl, response, response_symbol, response_symbol_matrix,
    response_units, family, submodels, units, data, n_obs, re_tbl,
    response_1 = response_1, response_2 = response_2,
    response_symbol_1 = response_symbol_1,
    response_symbol_2 = response_symbol_2
  )
  assumptions  <- drm_build_assumptions(family, response, response_symbol, re_tbl,
                                        response_1 = response_1,
                                        response_2 = response_2)
  interp       <- drm_build_interpretation(fixed_eff, family, response, data,
                                           response_1 = response_1,
                                           response_2 = response_2)
  bridge       <- drm_build_formula_bridge(entries, components, response,
                                           response_1 = response_1,
                                           response_2 = response_2)
  expanded     <- drm_build_expanded(fit, re_per_entry, has_re)

  metadata <- list(
    call = fit$call,
    context = context %||% "",
    ci_method = ci_method,
    # The fit is retained by reference so downstream accessors that need to
    # re-query the original object (e.g. group_means / group_slopes via
    # emmeans) can do so without round-tripping through the call. R's
    # reference semantics keep this cheap: no copy is made.
    fit = fit,
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
    mu1     = "beta_{1}",
    mu2     = "beta_{2}",
    sigma   = "gamma",
    sigma1  = "gamma_{1}",
    sigma2  = "gamma_{2}",
    rho12   = "rho",
    nu      = "nu",
    cli::cli_abort("No coefficient symbol family defined for dpar {.val {dpar}}.")
  )
}

drm_link_for <- function(family, dpar, family_link, family_links = NULL) {
  if (identical(family, "biv_gaussian") && !is.null(family_links) &&
      dpar %in% names(family_links)) {
    return(unname(family_links[[dpar]]))
  }
  if (dpar == "mu") return(family_link)
  if (dpar == "sigma") return("log")
  family_link
}

drm_param_greek <- function(dpar) {
  switch(
    dpar,
    mu     = "\\mu",
    mu1    = "\\mu_{1}",
    mu2    = "\\mu_{2}",
    sigma  = "\\sigma",
    sigma1 = "\\sigma_{1}",
    sigma2 = "\\sigma_{2}",
    rho12  = "\\rho_{12}",
    nu     = "\\nu",
    paste0("\\", dpar)
  )
}

drm_param_greek_bold <- function(dpar) {
  # Greek vector form per dpar. Wraps subscripts inside the bold symbol so
  # vectors over observations show as e.g. \\boldsymbol{\\mu}_{1}.
  switch(
    dpar,
    mu1    = "\\boldsymbol{\\mu}_{1}",
    mu2    = "\\boldsymbol{\\mu}_{2}",
    sigma1 = "\\boldsymbol{\\sigma}_{1}",
    sigma2 = "\\boldsymbol{\\sigma}_{2}",
    rho12  = "\\boldsymbol{\\rho}_{12}",
    paste0("\\boldsymbol{", drm_param_greek(dpar), "}")
  )
}

drm_design_matrix_symbol <- function(dpar) {
  switch(
    dpar,
    mu     = "\\mathbf{X}",
    mu1    = "\\mathbf{X}_{1}",
    mu2    = "\\mathbf{X}_{2}",
    sigma  = "\\mathbf{Z}",
    sigma1 = "\\mathbf{Z}_{1}",
    sigma2 = "\\mathbf{Z}_{2}",
    rho12  = "\\mathbf{W}",
    paste0("\\mathbf{X}_{", dpar, "}")
  )
}

drm_coef_vector_symbol <- function(coef_family) {
  # Vector form. coef_family may be e.g. "beta", "beta_{1}", "gamma_{2}", "rho".
  # Strip trailing "_{...}" subscript from the family name and re-attach to the
  # bolded vector so we get "\\boldsymbol{\\beta}_{1}" rather than
  # "\\boldsymbol{\\beta_{1}}".
  m <- regmatches(coef_family,
                  regexec("^([A-Za-z]+)(_\\{[^}]+\\})?$", coef_family))[[1L]]
  if (length(m) == 3L && nzchar(m[[2L]])) {
    paste0("\\boldsymbol{\\", m[[2L]], "}", m[[3L]])
  } else {
    paste0("\\boldsymbol{\\", coef_family, "}")
  }
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

drm_resolve_biv_response_symbol <- function(response, symbols, which) {
  # Per-response symbol for biv_gaussian. User-supplied symbols win; otherwise
  # default to "Y_{1i}" / "Y_{2i}" (capital Y, subscripted per response slot).
  if (!is.null(symbols) && response %in% names(symbols)) {
    return(unname(symbols[[response]]))
  }
  sprintf("Y_{%di}", as.integer(which))
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

drm_build_distribution <- function(family, response_symbol,
                                   response_symbol_matrix,
                                   response_symbol_1 = NULL,
                                   response_symbol_2 = NULL) {
  if (identical(family, "gaussian")) {
    return(tibble::tibble(
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
    ))
  }
  if (identical(family, "biv_gaussian")) {
    if (is.null(response_symbol_1) || is.null(response_symbol_2)) {
      cli::cli_abort("biv_gaussian distribution row requires both response symbols.")
    }
    return(tibble::tibble(
      family = family,
      response_symbol = response_symbol,
      response_symbol_matrix = response_symbol_matrix,
      parameters = "mu1, mu2, sigma1, sigma2, rho12",
      latex = sprintf(
        paste0(
          "(%s, %s) \\mid \\mu_{1i},\\, \\mu_{2i},\\, ",
          "\\sigma_{1i},\\, \\sigma_{2i},\\, \\rho_{12,i} \\sim ",
          "\\mathcal{N}_2\\!\\left((\\mu_{1i}, \\mu_{2i}),\\, \\Sigma_i\\right)"
        ),
        response_symbol_1, response_symbol_2
      ),
      latex_matrix = sprintf(
        paste0(
          "%s \\mid \\mathbf{M},\\, \\mathbf{S},\\, \\boldsymbol{\\rho}_{12} ",
          "\\sim \\mathcal{N}_2(\\mathbf{M},\\, \\boldsymbol{\\Sigma})"
        ),
        response_symbol_matrix
      )
    ))
  }
  cli::cli_abort("Distribution row not implemented for family {.val {family}}.")
}

drm_build_submodels <- function(entries, fit, param) {
  family_link <- fit$family$link
  family_links <- fit$family$links
  rows <- lapply(entries, function(e) {
    dpar <- e$dpar
    f <- drm_entry_formula(e)
    link <- drm_link_for(fit$family$family, dpar, family_link, family_links)
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

drm_build_fixed_effects <- function(terms_tbl, fit, ci_method = "wald") {
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
      std_error = double(0),
      confint_low = double(0),
      confint_high = double(0),
      excludes_zero = logical(0),
      ci_method = character(0)
    ))
  }
  coef_for <- function(dpar) {
    cf <- fit$coefficients[[dpar]]
    if (is.null(cf)) cf <- drmTMB::fixef(fit, dpar = dpar)
    cf
  }
  # Pull all CIs from drmTMB in one shot. Default Wald is fast; "profile" is
  # honest but slow. drmTMB labels rows as "fixef:<dpar>:<column>". On any
  # error (e.g., singular Hessian on a tiny test fit) keep CI columns NA
  # rather than crashing the whole extractor.
  # First pass: compute all the hit (model-matrix column) names. We need
  # them to enumerate parm targets for the profile CI call.
  estimate    <- rep(NA_real_,   nrow(terms_tbl))
  ci_low      <- rep(NA_real_,   nrow(terms_tbl))
  ci_high     <- rep(NA_real_,   nrow(terms_tbl))
  std_error   <- rep(NA_real_,   nrow(terms_tbl))
  hits        <- rep(NA_character_, nrow(terms_tbl))
  for (i in seq_len(nrow(terms_tbl))) {
    row <- terms_tbl[i, , drop = FALSE]
    if (is.na(row$coefficient_symbol)) next
    cf <- coef_for(row$submodel)
    if (row$term_label == "(Intercept)") {
      hit <- "(Intercept)"
    } else if (row$role == "factor_contrast" &&
               !is.na(row$contrast_level) && nzchar(row$contrast_level)) {
      # Single-factor contrast: variable + level (e.g. sex + male = "sexmale").
      hit <- paste0(row$variable, row$contrast_level)
    } else if (row$role == "interaction" &&
               !is.na(row$contrast_level) && nzchar(row$contrast_level)) {
      # Interaction columns: each piece gets its contrast level (if a factor)
      # spliced in. e.g., term_label "sex:body_size" with contrast_level "male:-"
      # becomes "sexmale:body_size"; term_label "site:sex" with contrast_level
      # "B:male" becomes "siteB:sexmale".
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
      hit <- paste(mm, collapse = ":")
    } else {
      hit <- row$term_label
    }
    if (!is.null(cf) && hit %in% names(cf)) {
      estimate[i] <- unname(cf[hit])
    }
    hits[i] <- hit
  }
  # Build parm targets in the "fixef:<dpar>:<column>" format drmTMB expects.
  # Profile needs explicit targets (Wald returns all whether you pass parm
  # or not, but passing it doesn't hurt and stays explicit).
  parm_targets <- vapply(seq_len(nrow(terms_tbl)), function(i) {
    if (is.na(hits[i])) NA_character_
    else paste0("fixef:", terms_tbl$submodel[i], ":", hits[i])
  }, character(1L))
  parm_lookup <- parm_targets[!is.na(parm_targets)]
  # `confint(fit)` dispatches to `confint.drmTMB` (an S3 method); accessing
  # `drmTMB::confint` directly errors because the package only registers
  # the method, not a re-exported `confint` symbol.
  ci_df <- if (length(parm_lookup) > 0L) {
    tryCatch(
      stats::confint(fit, parm = parm_lookup, method = ci_method, level = 0.95),
      error = function(e) NULL
    )
  } else NULL
  # Second pass: join the CI columns back onto rows.
  for (i in seq_len(nrow(terms_tbl))) {
    if (is.na(hits[i]) || is.null(ci_df)) next
    key <- parm_targets[i]
    hit_ci <- ci_df[ci_df$parm == key, , drop = FALSE]
    if (nrow(hit_ci) == 1L) {
      ci_low[i]  <- hit_ci$lower
      ci_high[i] <- hit_ci$upper
      if (identical(ci_method, "wald")) {
        std_error[i] <- (hit_ci$upper - hit_ci$lower) / (2 * stats::qnorm(0.975))
      }
    }
  }
  # Excludes-zero is the indicator: both bounds the same sign, neither zero.
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
    std_error = std_error,
    confint_low = ci_low,
    confint_high = ci_high,
    excludes_zero = excludes_zero,
    ci_method = rep(ci_method, nrow(terms_tbl))
  )
}

drm_build_expanded <- function(fit, re_per_entry, has_re) {
  # Univariate Gaussian path: `fit$model$y`, `fit$model$X$mu`, etc. all exist
  # and are non-NULL. For biv_gaussian the design is per-dpar (X$mu1, X$mu2,
  # ...), and these names are NULL, so the multiplications below quietly
  # produce NULL fields. The three-views renderer reads these fields and
  # skips when NULL, so biv just gets a sparse `expanded` block.
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
                                  response_symbol_matrix,
                                  family = "gaussian",
                                  response_symbol_1 = NULL,
                                  response_symbol_2 = NULL) {
  is_biv <- identical(family, "biv_gaussian")
  rows <- list()
  if (is_biv) {
    rows[[1L]] <- tibble::tibble(
      name = "distribution",
      kind = "distribution",
      submodel = NA_character_,
      equation = sprintf(
        paste0(
          "(%s, %s) \\mid \\mu_{1i},\\, \\mu_{2i},\\, ",
          "\\sigma_{1i},\\, \\sigma_{2i},\\, \\rho_{12,i} \\sim ",
          "\\mathcal{N}_2\\!\\left((\\mu_{1i}, \\mu_{2i}),\\, \\Sigma_i\\right)"
        ),
        response_symbol_1, response_symbol_2
      ),
      equation_matrix = sprintf(
        paste0(
          "%s \\mid \\mathbf{M},\\, \\mathbf{S},\\, \\boldsymbol{\\rho}_{12} ",
          "\\sim \\mathcal{N}_2(\\mathbf{M},\\, \\boldsymbol{\\Sigma})"
        ),
        response_symbol_matrix
      ),
      status = "stated"
    )
  } else {
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
  }
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
        identity        = target,
        log             = paste0("\\log(", target, ")"),
        logit           = paste0("\\mathrm{logit}(", target, ")"),
        atanh_guarded   = paste0("\\mathrm{tanh}^{-1}(", target, ")"),
        paste0("\\mathrm{", link, "}(", target, ")")
      )
    }
    # Scalar form: dpars with explicit "1"/"2" subscripts (mu1, sigma1, ...)
    # need the observation index inserted as a second subscript, e.g.
    # "\\mu_{1i}" rather than "\\mu_{1}_i".
    lhs_target_idx <- drm_param_index_form(dpar, greek)
    lhs_idx <- apply_link(lhs_target_idx, link)
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
  # biv_gaussian: append the implied 2x2 residual covariance decomposition.
  if (is_biv) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      name = "residual_covariance",
      kind = "covariance_decomposition",
      submodel = NA_character_,
      equation = paste0(
        "\\Sigma_i = ",
        "\\begin{pmatrix}\\sigma_{1i}^2 & \\rho_{12,i}\\sigma_{1i}\\sigma_{2i} ",
        "\\\\ \\rho_{12,i}\\sigma_{1i}\\sigma_{2i} & \\sigma_{2i}^2\\end{pmatrix}"
      ),
      equation_matrix = paste0(
        "\\boldsymbol{\\Sigma} = ",
        "\\mathrm{diag}(\\boldsymbol{\\sigma}_{1}) \\mathbf{R}(\\boldsymbol{\\rho}_{12}) ",
        "\\mathrm{diag}(\\boldsymbol{\\sigma}_{2})"
      ),
      status = "stated"
    )
  }
  do.call(rbind, rows)
}

drm_dim_coef <- function(dpar) {
  # Coefficient-count dimension symbol per submodel.
  # Univariate dpars (mu, sigma, nu) get the existing "p_\\mu" form; biv dpars
  # get "p_{mu1}" etc. (because "\\mu1" is not a valid macro).
  if (dpar %in% c("mu", "sigma", "nu")) {
    return(sprintf("\\mathbb{R}^{p_\\%s}", dpar))
  }
  sprintf("\\mathbb{R}^{p_{%s}}", dpar)
}

drm_dim_design <- function(dpar) {
  if (dpar %in% c("mu", "sigma", "nu")) {
    return(sprintf("\\mathbb{R}^{n \\times p_\\%s}", dpar))
  }
  sprintf("\\mathbb{R}^{n \\times p_{%s}}", dpar)
}

drm_coef_scalar_indices <- function(coef_family, n_coef) {
  # Scalar coefficient names per submodel. For univariate dpars, coef_family
  # is e.g. "beta" -> "\\beta_{0}", "\\beta_{1}", ...; for biv dpars,
  # coef_family already includes its own subscript (e.g. "beta_{1}"), so the
  # scalar form merges both subscripts into one: "\\beta_{1,0}", "\\beta_{1,1}".
  m <- regmatches(coef_family,
                  regexec("^([A-Za-z]+)(_\\{[^}]+\\})?$", coef_family))[[1L]]
  if (length(m) == 3L && nzchar(m[[2L]]) && nzchar(m[[3L]])) {
    # Family had its own subscript: merge.
    inner <- sub("_\\{", "", m[[3L]], fixed = FALSE)
    inner <- sub("\\}$", "", inner, fixed = FALSE)
    paste0("\\", m[[2L]], "_{", inner, ",", seq.int(0L, n_coef - 1L), "}")
  } else {
    paste0("\\", coef_family, "_{", seq.int(0L, n_coef - 1L), "}")
  }
}

drm_param_index_form <- function(dpar, greek) {
  # Index form: "\\mu_i" for `mu`, "\\mu_{1i}" for `mu1`, "\\rho_{12,i}" for
  # `rho12` (two-digit subscript gets a comma before i to keep readability).
  m <- regmatches(greek, regexec("^(.*)_\\{([0-9]+)\\}$", greek))[[1L]]
  if (length(m) == 3L && nzchar(m[[2L]]) && nzchar(m[[3L]])) {
    sub_digits <- m[[3L]]
    sep <- if (nchar(sub_digits) >= 2L) "," else ""
    return(paste0(m[[2L]], "_{", sub_digits, sep, "i}"))
  }
  paste0(greek, "_i")
}

drm_build_symbol_dictionary <- function(terms_tbl, response, response_symbol,
                                        response_symbol_matrix,
                                        response_units, family, submodels,
                                        units, data, n_obs, re_tbl = NULL,
                                        response_1 = NULL, response_2 = NULL,
                                        response_symbol_1 = NULL,
                                        response_symbol_2 = NULL) {
  is_biv <- identical(family, "biv_gaussian")
  # Helper: per-submodel coefficient count (for concrete p_mu / p_sigma).
  p_for <- function(dpar) {
    sum(terms_tbl$submodel == dpar &
          !is.na(terms_tbl$coefficient_symbol))
  }
  rows <- list()
  if (is_biv) {
    # Two response-scalar rows, one per response, plus a joint vector row.
    rows[[1L]] <- tibble::tibble(
      symbol = response_symbol_1,
      symbol_matrix = sprintf("\\mathbf{y}_{1}"),
      variable = response_1,
      units = drm_resolve_units(response_1, units),
      role = "response",
      dimension = "\\mathbb{R}^n",
      dimension_concrete = sprintf("\\mathbb{R}^{%d}", n_obs),
      description = sprintf("first response (%s)", response_1)
    )
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = response_symbol_2,
      symbol_matrix = sprintf("\\mathbf{y}_{2}"),
      variable = response_2,
      units = drm_resolve_units(response_2, units),
      role = "response",
      dimension = "\\mathbb{R}^n",
      dimension_concrete = sprintf("\\mathbb{R}^{%d}", n_obs),
      description = sprintf("second response (%s)", response_2)
    )
    # Joint bivariate response matrix.
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = sprintf("(%s, %s)", response_symbol_1, response_symbol_2),
      symbol_matrix = response_symbol_matrix,
      variable = paste(response_1, response_2, sep = ", "),
      units = NA_character_,
      role = "response_pair",
      dimension = "\\mathbb{R}^{n \\times 2}",
      dimension_concrete = sprintf("\\mathbb{R}^{%d \\times 2}", n_obs),
      description = "joint bivariate response"
    )
  } else {
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
  }
  predictors <- terms_tbl[
    !is.na(terms_tbl$variable) &
      terms_tbl$role %in% c("predictor", "factor_contrast",
                            "transformation", "offset"),
    , drop = FALSE
  ]
  predictors <- predictors[!duplicated(predictors$variable), , drop = FALSE]
  # Per-submodel: does it have an intercept row in terms_tbl? If not, the
  # factor's k columns are cell-means columns, not contrasts.
  has_intercept <- function(dpar) {
    any(terms_tbl$submodel == dpar & terms_tbl$role == "intercept")
  }
  for (i in seq_len(nrow(predictors))) {
    p <- predictors[i, , drop = FALSE]
    var <- p$variable
    cls <- if (var %in% names(data)) class(data[[var]])[[1L]] else NA_character_
    intercept_less <- !has_intercept(p$submodel)
    desc <- switch(
      p$role,
      factor_contrast = if (!is.na(cls)) {
        lvls <- levels(factor(data[[var]]))
        if (intercept_less) {
          sprintf("factor (%s) - cell-means parameterisation",
                  paste(lvls, collapse = ", "))
        } else {
          if (length(lvls) >= 1L) {
            lvls[1L] <- paste0(lvls[1L], " [reference]")
          }
          sprintf("factor (%s)", paste(lvls, collapse = ", "))
        }
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
  # Parameter symbols (per submodel): scalar form with observation index + bold
  # vector form. Index form handles dpars like mu1/mu2/rho12 cleanly:
  # "\\mu_{1i}", "\\rho_{12,i}", "\\sigma_i", "\\sigma_{2i}".
  param_owner <- function(dpar) {
    if (!is_biv) return(response)
    if (dpar %in% c("mu1", "sigma1")) return(response_1 %||% response)
    if (dpar %in% c("mu2", "sigma2")) return(response_2 %||% response)
    paste(response_1 %||% "", response_2 %||% "", sep = ", ")
  }
  for (i in seq_len(nrow(submodels))) {
    dpar <- submodels$parameter[[i]]
    greek <- drm_param_greek(dpar)
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = drm_param_index_form(dpar, greek),
      symbol_matrix = drm_param_greek_bold(dpar),
      variable = NA_character_,
      units = NA_character_,
      role = "parameter",
      dimension = "\\mathbb{R}^n",
      dimension_concrete = sprintf("\\mathbb{R}^{%d}", n_obs),
      description = sprintf("conditional %s of %s", dpar, param_owner(dpar))
    )
  }
  # Coefficients (per submodel): scalar beta_0, beta_1 + bold vector form.
  # For biv_gaussian, coef_family carries its own subscript (e.g. "beta_{1}"),
  # which we splice as a single double subscript in the scalar form
  # ("\\beta_{1,0}", "\\beta_{1,1}", ...).
  for (i in seq_len(nrow(submodels))) {
    dpar <- submodels$parameter[[i]]
    cf <- submodels$coef_family[[i]]
    n_coef <- p_for(dpar)
    if (n_coef == 0L) next
    indices <- drm_coef_scalar_indices(cf, n_coef)
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = paste(indices, collapse = ", "),
      symbol_matrix = drm_coef_vector_symbol(cf),
      variable = NA_character_,
      units = NA_character_,
      role = "coefficient",
      dimension = drm_dim_coef(dpar),
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
      dimension = drm_dim_design(dpar),
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
                                  re_tbl = NULL,
                                  response_1 = NULL, response_2 = NULL) {
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
    response_symbol_j = drm_response_symbol_j(response_symbol),
    response_1 = response_1 %||% response,
    response_2 = response_2 %||% ""
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

ref_for_var <- function(var, data) {
  if (is.null(var) || is.na(var) || !var %in% names(data)) return("")
  lvls <- levels(factor(data[[var]]))
  if (length(lvls) == 0L) return("")
  lvls[1L]
}

drm_interaction_sub_role <- function(row, data) {
  # `row` is a single fixed_effects row whose role == "interaction".
  # Inspect the pieces of `variable` (split on ":") and their factor-ness.
  pieces <- strsplit(row$variable, ":", fixed = TRUE)[[1L]]
  is_factor <- vapply(pieces, function(p) {
    p %in% names(data) &&
      class(data[[p]])[1L] %in% c("factor", "ordered", "character")
  }, logical(1L))
  n_fact <- sum(is_factor)
  if (n_fact == 0L)        "interaction_cont_cont"
  else if (n_fact == 1L)   "interaction_cont_factor"
  else                     "interaction_factor_factor"
}

drm_role_to_interp <- function(role, row = NULL, data = NULL,
                                intercept_less = FALSE) {
  switch(
    role,
    intercept       = "intercept",
    predictor       = "slope",
    # When the submodel has no intercept, the factor's k columns are
    # cell-means columns (not contrasts), so route to the cell_mean
    # template which reads as "expected {response} for {variable} = {level}".
    factor_contrast = if (isTRUE(intercept_less)) "cell_mean" else "factor_contrast",
    transformation  = "transformation",
    interaction     = if (!is.null(row) && !is.null(data)) {
      drm_interaction_sub_role(row, data)
    } else NA_character_,
    offset          = NA_character_,
    NA_character_
  )
}

# Build interaction-specific substitution keys from an interaction row.
drm_interaction_subs <- function(row, data) {
  pieces <- strsplit(row$variable, ":", fixed = TRUE)[[1L]]
  if (length(pieces) != 2L) return(list())
  is_fact <- vapply(pieces, function(p) {
    p %in% names(data) &&
      class(data[[p]])[1L] %in% c("factor", "ordered", "character")
  }, logical(1L))
  # Parse contrast_level. Cont:factor rows look like "-:male", factor:factor
  # rows look like "a2:b2". Continuous-only rows have NA contrast_level.
  cl <- if (!is.na(row$contrast_level) && nzchar(row$contrast_level)) {
    strsplit(row$contrast_level, ":", fixed = TRUE)[[1L]]
  } else c("", "")
  if (length(cl) == 1L) cl <- c(cl, "")
  if (sum(is_fact) == 1L) {
    # Continuous x factor: the factor side is the one whose contrast level
    # piece is non-empty and not the placeholder "-".
    factor_side <- if (nzchar(cl[[1L]]) && cl[[1L]] != "-") 1L else 2L
    cont_side <- 3L - factor_side
    list(
      predictor       = pieces[[cont_side]],
      variable        = pieces[[factor_side]],
      level           = cl[[factor_side]],
      reference_level = ref_for_var(pieces[[factor_side]], data)
    )
  } else if (sum(is_fact) == 2L) {
    list(
      factor_a          = pieces[[1L]],
      factor_b          = pieces[[2L]],
      level_a           = cl[[1L]],
      level_b           = cl[[2L]],
      reference_level_a = ref_for_var(pieces[[1L]], data),
      reference_level_b = ref_for_var(pieces[[2L]], data)
    )
  } else {
    list(
      predictor_a = pieces[[1L]],
      predictor_b = pieces[[2L]]
    )
  }
}

drm_build_interpretation <- function(fixed_eff, family, response, data,
                                     response_1 = NULL, response_2 = NULL) {
  empty <- tibble::tibble(
    submodel = character(0),
    term_label = character(0),
    coefficient_role = character(0),
    estimate = double(0),
    std_error = double(0),
    confint_low = double(0),
    confint_high = double(0),
    excludes_zero = logical(0),
    ci_method = character(0),
    link_scale_reading = character(0),
    natural_scale_reading = character(0),
    variance_scale_reading = character(0),
    biological_reading = character(0)
  )
  if (nrow(fixed_eff) == 0L) return(empty)
  is_biv <- identical(family, "biv_gaussian")
  # Per-submodel "owning" response for biv_gaussian: mu1/sigma1 -> response_1,
  # mu2/sigma2 -> response_2, rho12 -> joint. The `{response}` placeholder in
  # the templates is the per-submodel response on biv.
  response_for_sub <- function(sub) {
    if (!is_biv) return(response)
    if (sub %in% c("mu1", "sigma1")) return(response_1 %||% response)
    if (sub %in% c("mu2", "sigma2")) return(response_2 %||% response)
    response
  }
  tbl <- load_template("interpretation-templates")
  # Which submodels are intercept-less? A submodel is intercept-less when
  # fixed_eff has factor_contrast / predictor rows for it but no intercept
  # row. The cell_mean interpretation template fires for those.
  intercept_less_submodels <- {
    has_int <- tapply(
      fixed_eff$role == "intercept", fixed_eff$submodel, any,
      default = FALSE
    )
    names(has_int)[!has_int]
  }
  rows <- list()
  for (i in seq_len(nrow(fixed_eff))) {
    r <- fixed_eff[i, , drop = FALSE]
    cr <- drm_role_to_interp(
      r$role,
      row = r, data = data,
      intercept_less = r$submodel %in% intercept_less_submodels
    )
    if (is.na(cr)) next
    template <- tbl[
      tbl$family == family &
        tbl$submodel == r$submodel &
        tbl$coefficient_role == cr,
      , drop = FALSE
    ]
    if (nrow(template) == 0L) next
    variable <- if (is.na(r$variable)) "" else r$variable
    level <- if (is.na(r$contrast_level)) "" else r$contrast_level
    transform <- if (is.na(r$transform)) "" else r$transform
    coef_str <- drm_format_estimate(r$estimate)
    if (is.na(coef_str)) coef_str <- ""
    mapping <- list(
      response        = response_for_sub(r$submodel),
      response_1      = response_1 %||% response,
      response_2      = response_2 %||% "",
      predictor       = variable,   # default; interaction rows override below
      variable        = variable,
      level           = level,
      transform       = transform,
      coef            = coef_str,
      reference_level = ref_for_var(r$variable, data)
    )
    if (r$role == "interaction") {
      mapping <- utils::modifyList(mapping, drm_interaction_subs(r, data))
    }
    rows[[length(rows) + 1L]] <- tibble::tibble(
      submodel = r$submodel,
      term_label = r$term_label,
      coefficient_role = cr,
      estimate = r$estimate,
      std_error = r$std_error %||% NA_real_,
      confint_low = r$confint_low %||% NA_real_,
      confint_high = r$confint_high %||% NA_real_,
      excludes_zero = r$excludes_zero %||% NA,
      ci_method = r$ci_method %||% NA_character_,
      link_scale_reading = drm_substitute(template$link_scale_reading[[1L]], mapping),
      natural_scale_reading = drm_substitute(template$natural_scale_reading[[1L]], mapping),
      variance_scale_reading = drm_substitute(template$variance_scale_reading[[1L]], mapping),
      biological_reading = drm_substitute(template$biological_reading[[1L]], mapping)
    )
  }
  if (length(rows) == 0L) return(empty)
  do.call(rbind, rows)
}

drm_build_formula_bridge <- function(entries, components, response,
                                     response_1 = NULL, response_2 = NULL) {
  r1 <- response_1 %||% response
  r2 <- response_2 %||% ""
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
    } else if (dpar == "mu1") {
      sprintf("Expected %s is a linear function of the first mean-model predictors", r1)
    } else if (dpar == "mu2") {
      sprintf("Expected %s is a linear function of the second mean-model predictors", r2)
    } else if (dpar == "sigma1") {
      sprintf("Log residual SD of %s is a linear function of the first scale-model predictors", r1)
    } else if (dpar == "sigma2") {
      sprintf("Log residual SD of %s is a linear function of the second scale-model predictors", r2)
    } else if (dpar == "rho12") {
      sprintf("Fisher-z residual correlation between %s and %s is a linear function of the correlation-model predictors", r1, r2)
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
