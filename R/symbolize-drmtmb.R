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
#'
#' @references
#' Nakagawa, S. (forthcoming). `drmTMB`: Distributional regression in TMB.
#' <https://itchyshin.github.io/drmTMB/>
#'
#' Kristensen, K., Nielsen, A., Berg, C. W., Skaug, H., & Bell, B. M.
#' (2016). TMB: Automatic Differentiation and Laplace Approximation.
#' *Journal of Statistical Software*, 70(5), 1-21.
#'
#' @return A `symbolized_model` object.
#' @export
symbolize.drmTMB <- function(fit, symbols = NULL, units = NULL,
                             context = NULL, ci_method = "wald", ...) {
  if (!requireNamespace("drmTMB", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg drmTMB} is needed to symbolize this fit.",
      i = "Install it with {.code remotes::install_github(\"itchyshin/drmTMB\")}."
    ))
  }
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

  # v0.22.1.1: detect drmTMB structured-dependence markers (phylo, animal,
  # spatial, meta_V) and synthesise random-effect rows for structured tiers
  # that drmTMB absorbs into its internal sparse-precision pipeline rather
  # than fit$random_effects. Without this, phylo(1 | species, tree = ...)
  # detected via metadata$phylo_representation never reaches the equation
  # renderer, so the central thesis equation (u_p ~ N(0, sigma_p^2 A)) is
  # silently missing from the rendered widget (V2 Pat-lens blocker on
  # symbolizer-meta-analysis.Rmd Sec 4).
  detected_signals <- character(0L)
  has_drmtmb_phylo <- FALSE
  has_drmtmb_spatial <- FALSE
  has_drmtmb_meta_v <- FALSE
  phylo_groups_per_dpar <- list()   # named list: dpar -> character vector of group_vars
  for (e in entries) {
    if (is.null(e$rhs)) next
    rhs_text <- paste(deparse(e$rhs), collapse = " ")
    if (grepl("(^|[^A-Za-z._])(phylo|animal)\\s*\\(", rhs_text)) {
      has_drmtmb_phylo <- TRUE
      # Parse `phylo(<lhs> | group, ...)` / `animal(<lhs> | group, ...)`
      # marker(s) and pull the group-var. There can be more than one
      # phylo() block on the same submodel (rare but legal).
      hits <- gregexpr(
        "(?:phylo|animal)\\s*\\(\\s*[^|]+\\|\\s*([A-Za-z._][A-Za-z0-9._]*)",
        rhs_text, perl = TRUE)[[1L]]
      if (hits[[1L]] > 0L) {
        starts <- as.integer(hits)
        lens   <- attr(hits, "match.length")
        for (h in seq_along(starts)) {
          m <- substr(rhs_text, starts[[h]], starts[[h]] + lens[[h]] - 1L)
          gv <- sub(".*\\|\\s*", "", m)
          phylo_groups_per_dpar[[e$dpar]] <-
            c(phylo_groups_per_dpar[[e$dpar]] %||% character(0L), gv)
        }
      }
    }
    if (grepl("(^|[^A-Za-z._])spatial\\s*\\(", rhs_text)) {
      has_drmtmb_spatial <- TRUE
    }
    # v0.22.1: detect meta_V() sampling-variance marker (meta-analysis).
    if (grepl("(^|[^A-Za-z._])meta_V\\s*\\(", rhs_text)) {
      has_drmtmb_meta_v <- TRUE
    }
  }
  if (has_drmtmb_phylo)   detected_signals <- c(detected_signals, "phylo")
  if (has_drmtmb_spatial) detected_signals <- c(detected_signals, "spatial")
  if (has_drmtmb_meta_v)  detected_signals <- c(detected_signals, "meta_analysis")

  # Inject synthetic phylo random-effect rows into re_per_entry so the
  # equation renderer, variance_components, symbol table, and assumption
  # gate all see them. From symbolizer's standpoint, phylo(1 | species)
  # IS a random effect on the submodel even though drmTMB stores it via
  # the structured-precision pipeline (fit$random_effects holds only
  # unstructured tiers).
  structured_matrix_for_group <- list()
  if (has_drmtmb_phylo) {
    for (i in seq_along(entries)) {
      dpar <- entries[[i]]$dpar
      gvs  <- phylo_groups_per_dpar[[dpar]]
      if (is.null(gvs) || length(gvs) == 0L) next
      for (gv in unique(gvs)) {
        # Skip when an unstructured (1 | gv) tier already exists for this
        # dpar -- the user-facing structured information lives in the
        # structured-matrix decoration, not in a duplicate row.
        existing <- re_per_entry[[i]]
        already  <- !is.null(existing) &&
                    any(existing$group_var == gv & existing$submodel == dpar)
        if (already) {
          structured_matrix_for_group[[gv]] <- "\\mathbf{A}"
          next
        }
        n_levels <- if (gv %in% names(data)) {
          length(unique(data[[gv]]))
        } else NA_integer_
        synth <- tibble::tibble(
          submodel   = dpar,
          term_label = sprintf("(1 | %s)", gv),
          lhs_expr   = "1",
          group_var  = gv,
          component  = "(Intercept)",
          n_levels   = as.integer(n_levels)
        )
        re_per_entry[[i]] <- if (is.null(existing)) synth else rbind(existing, synth)
        structured_matrix_for_group[[gv]] <- "\\mathbf{A}"
      }
    }
    has_re <- vapply(re_per_entry, function(x) !is.null(x) && nrow(x) > 0L,
                     logical(1L))
  }
  if (length(structured_matrix_for_group) == 0L) {
    structured_matrix_for_group <- NULL
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
  # cumulative_logit has no intercept on the linear predictor (the K-1
  # cutpoints theta_k replace it). drmTMB's fit$coefficients reflects this
  # but R's formula parsing assumes an implicit intercept; strip it so
  # downstream tables and LaTeX stay honest.
  if (identical(family, "cumulative_logit")) {
    terms_tbl <- terms_tbl[!(terms_tbl$submodel == "mu" &
                             terms_tbl$role == "intercept"), , drop = FALSE]
  }
  factor_cod   <- build_factor_coding(data, terms_tbl, fit)
  fixed_eff    <- drm_build_fixed_effects(terms_tbl, fit, ci_method = ci_method)
  re_tbl       <- drm_build_random_effects(re_per_entry)
  vc_tbl       <- drm_build_variance_components(re_per_entry, fit$sdpars)
  cov_tbl      <- drm_build_covariance_components(re_tbl)
  components   <- drm_build_components(submodels, terms_tbl, re_tbl,
                                       response_symbol, response_symbol_matrix,
                                       family = family,
                                       response_symbol_1 = response_symbol_1,
                                       response_symbol_2 = response_symbol_2,
                                       structured_matrix_for_group =
                                         structured_matrix_for_group)
  # v0.21+ structured-dependence symbol-dictionary scaffolding. detected_*
  # booleans and detected_signals are set early so re_per_entry can be
  # augmented before re_tbl / components / variance_components build.
  structured_matrices <- c(
    if (has_drmtmb_phylo) list(list(
      symbol             = "\\mathbf{A}",
      symbol_matrix      = "\\mathbf{A}",
      variable           = NA_character_,
      units              = NA_character_,
      role               = "structured_correlation_phylo",
      dimension          = "\\mathbb{R}^{k \\times k}",
      dimension_concrete = "\\mathbb{R}^{k \\times k}",
      description        = "phylogenetic / pedigree correlation matrix from drmTMB::phylo() or drmTMB::animal(); Hadfield-Nakagawa A-inverse sparse-precision representation (all-nodes: latent vector spans tips and internal nodes)"
    )),
    if (has_drmtmb_spatial) list(list(
      symbol             = "\\boldsymbol{\\Omega}",
      symbol_matrix      = "\\boldsymbol{\\Omega}",
      variable           = NA_character_,
      units              = NA_character_,
      role               = "structured_correlation_spatial",
      dimension          = "\\mathbb{R}^{n_s \\times n_s}",
      dimension_concrete = "\\mathbb{R}^{n_s \\times n_s}",
      description        = "spatial correlation / GMRF precision built from drmTMB::spatial() coords or mesh"
    ))
  )
  if (length(structured_matrices) == 0L) structured_matrices <- NULL

  symbol_dict  <- drm_build_symbol_dictionary(
    terms_tbl, response, response_symbol, response_symbol_matrix,
    response_units, family, submodels, units, data, n_obs, re_tbl,
    response_1 = response_1, response_2 = response_2,
    response_symbol_1 = response_symbol_1,
    response_symbol_2 = response_symbol_2,
    structured_matrices = structured_matrices
  )
  assumptions  <- drm_build_assumptions(family, response, response_symbol, re_tbl,
                                        response_1 = response_1,
                                        response_2 = response_2,
                                        detected_signals = detected_signals)
  interp       <- drm_build_interpretation(fixed_eff, family, response, data,
                                           response_1 = response_1,
                                           response_2 = response_2,
                                           detected_signals = detected_signals)
  bridge       <- drm_build_formula_bridge(entries, components, response,
                                           response_1 = response_1,
                                           response_2 = response_2)
  expanded     <- drm_build_expanded(fit, re_per_entry, has_re,
                                     structured_matrix_for_group =
                                       structured_matrix_for_group)

  # v0.22.1: meta_V() detection overrides the caller-supplied context so
  # that the meta-analytic context is always tagged when the marker is
  # present. The caller's explicit context (if any) is preserved in the
  # fallback so non-meta fits are unaffected.
  resolved_context <- if (isTRUE(has_drmtmb_meta_v)) {
    "meta_analysis"
  } else {
    context %||% ""
  }

  metadata <- list(
    call = fit$call,
    context = resolved_context,
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
    phylo_representation = if (has_drmtmb_phylo) "all_nodes" else NULL,
    spatial_representation = if (has_drmtmb_spatial) "package_managed" else NULL,
    structured_matrices = structured_matrices,
    structured_matrix_for_group = structured_matrix_for_group,
    detected_signals = detected_signals,
    created_by = "symbolize.drmTMB"
  )

  # Build a stub object first so the warnings detector can inspect it.
  sym_stub <- list(
    model = model,
    metadata = metadata,
    random_effects = re_tbl
  )
  warnings_tbl <- drm_build_warnings(fit, sym_stub)

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
  component  <- vapply(parsed, `[[`, character(1L), "component")
  n_levels   <- vapply(re$terms, length, integer(1L), USE.NAMES = FALSE)
  tibble::tibble(
    submodel    = dpar,
    term_label  = term_labels,
    lhs_expr    = lhs_expr,
    group_var   = group_vars,
    component   = component,
    n_levels    = as.integer(n_levels)
  )
}

# Parse a random-effect term label from drmTMB. Three shapes are handled
# today:
#
#   "(1 | group)"                  intercept-only; component = "(Intercept)"
#   "(1 + x | group):(Intercept)"  random intercept piece of a random slope
#   "(1 + x | group):x"            random slope piece on predictor `x`
#
# Returns: list(lhs, group, component). `lhs` is the full RE formula text
# (e.g. "1 + x"). `component` is the specific coefficient — "(Intercept)"
# for intercept rows, or the predictor name for slope rows.
drm_parse_re_term <- function(term_label) {
  # Split into "(re_expr)" and an optional suffix after the first "):" pair
  # that closes the parens.
  split_at <- regexpr("\\)\\s*:", term_label)
  if (split_at[[1L]] > 0L) {
    re_part   <- substr(term_label, 1L, split_at[[1L]])           # "(1 + x | g)"
    suffix    <- substr(term_label, split_at[[1L]] + attr(split_at, "match.length"),
                        nchar(term_label))                          # "(Intercept)" or "x"
    # Keep "(Intercept)" with its parens — that's the canonical R name
    # for the intercept coefficient and how downstream code recognises it.
    component <- trimws(suffix)
  } else {
    re_part   <- term_label
    component <- "(Intercept)"
  }
  # Now re_part is "(lhs | group)"; strip outer parens and split on |.
  inner <- sub("^\\(\\s*", "", re_part)
  inner <- sub("\\s*\\)$", "", inner)
  parts <- strsplit(inner, "\\|", fixed = FALSE)[[1L]]
  if (length(parts) != 2L) {
    cli::cli_abort("Could not parse random-effect term {.val {term_label}}.")
  }
  list(
    lhs       = trimws(parts[[1L]]),
    group     = trimws(parts[[2L]]),
    component = component
  )
}

# Validate which RE shapes we render today. Intercept-only and intercept-plus-
# slope on mu both pass. Random effects on submodels other than mu, or RE
# formulas that don't include the intercept, still error. The error message
# names the registry status word so users know what to look for.
drm_assert_supported_re <- function(re_tbl, dpar) {
  if (dpar != "mu") {
    cli::cli_abort(c(
      "Random effects on submodel {.val {dpar}} not yet supported.",
      i = "Random effects on mu are {.emph First slice}; other submodels are {.emph Planned or reserved}."
    ))
  }
  # Each random-effects group must include an intercept. Slope-only random
  # effects (e.g. `(temperature | group)`) are uncommon and not supported
  # in the First slice. We check this per-group: if any group lacks an
  # "(Intercept)" component, reject.
  for (gv in unique(re_tbl$group_var)) {
    sel <- which(re_tbl$group_var == gv)
    if (!"(Intercept)" %in% re_tbl$component[sel]) {
      flag <- paste(re_tbl$term_label[sel], collapse = ", ")
      cli::cli_abort(c(
        "Random-effect term not yet supported in submodel {.val {dpar}}: {.val {flag}}.",
        i = "First-slice random effects must include an intercept: {.code (1 | group)} or {.code (1 + x | group)} where {.code x} is a single bare predictor."
      ))
    }
  }
  # Component names that aren't "(Intercept)" must be bare predictor names.
  bad <- !(re_tbl$component == "(Intercept)" |
           grepl("^[A-Za-z._][A-Za-z0-9._]*$", re_tbl$component))
  if (any(bad)) {
    flag <- paste(re_tbl$term_label[bad], collapse = ", ")
    cli::cli_abort(c(
      "Random-effect term not yet supported in submodel {.val {dpar}}: {.val {flag}}.",
      i = "First-slice random effects handle {.code (1 | group)} and {.code (1 + x | group)} where {.code x} is a single bare predictor."
    ))
  }
  invisible(re_tbl)
}

drm_strip_re_terms <- function(rhs_expr) {
  # Walk the parse tree to remove `(... | ...)` random-effect bars AND
  # drmTMB special-call markers (`meta_V(...)`, etc.) that stats::terms()
  # cannot evaluate, leaving only fixed-effect terms. The previous regex-
  # based implementation explicitly rejected inner parens, so brms's
  # `(1 | gr(species, cov = A))` survived the strip and crashed
  # `stats::model.frame()` with "could not find function 'gr'".
  # The tree walker handles arbitrary nesting inside the grouping
  # expression.
  terms <- .drm_decompose_plus(rhs_expr)
  keep <- !vapply(terms, .drm_is_re_bar, logical(1L)) &
          !vapply(terms, .drm_is_meta_v_term, logical(1L))
  kept <- terms[keep]
  if (length(kept) == 0L) return(quote(1))
  Reduce(function(a, b) call("+", a, b), kept)
}

.drm_decompose_plus <- function(expr) {
  # Recursively split an additive expression into a list of `+`-separated
  # terms. Non-`+` expressions are returned as singletons.
  if (is.call(expr) && identical(expr[[1L]], as.name("+")) &&
      length(expr) == 3L) {
    c(.drm_decompose_plus(expr[[2L]]), list(expr[[3L]]))
  } else {
    list(expr)
  }
}

.drm_is_re_bar <- function(expr) {
  # An RE bar is `( <stuff> | <stuff> )` — outer call is `(`, inner is `|`.
  # This matches both lme4-style `(1 | g)` and brms-style
  # `(1 | gr(species, cov = A))` because `inner` is just whatever R parsed
  # between the parens; we check only its root operator.
  if (!is.call(expr)) return(FALSE)
  if (!identical(expr[[1L]], as.name("("))) return(FALSE)
  inner <- expr[[2L]]
  is.call(inner) && identical(inner[[1L]], as.name("|"))
}

.drm_is_meta_v_term <- function(expr) {
  # v0.22.1: meta_V(V = ...) is a drmTMB sampling-variance marker.
  # stats::terms() / stats::model.frame() cannot evaluate it (the function
  # lives in drmTMB, not in base R), so strip it from the fixed-effect rhs
  # before passing to extract_terms(). The marker presence is detected
  # separately (via deparsed formula grep) and recorded in metadata$context.
  if (!is.call(expr)) return(FALSE)
  fn_name <- as.character(expr[[1L]])[1L]
  fn_name %in% c("meta_V", "drmTMB::meta_V")
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
    zi      = "alpha",  # zero-inflation submodel; logit link
    hu      = "delta",  # hurdle submodel; logit link
    tau2    = "alpha",  # metafor location-scale: log(tau^2_i) = alpha_0 + sum alpha_k z_ki
    cli::cli_abort("No coefficient symbol family defined for dpar {.val {dpar}}.")
  )
}

drm_link_for <- function(family, dpar, family_link, family_links = NULL) {
  # For multi-dpar families (biv_gaussian, student, and future families that
  # carry one link per dpar), drmTMB exposes the per-dpar lookup as a named
  # vector on either `fit$family$link` or `fit$family$links`. Use whichever
  # exists, indexed by the current dpar.
  lookup <- if (!is.null(family_links) && !is.null(names(family_links))) {
    family_links
  } else if (is.character(family_link) && length(family_link) > 1L &&
             !is.null(names(family_link))) {
    family_link
  } else NULL
  if (!is.null(lookup) && dpar %in% names(lookup)) {
    return(unname(lookup[[dpar]]))
  }
  # Univariate Gaussian / other single-dpar families: fall back to the
  # historical hardcoded mapping.
  if (dpar == "mu") return(family_link)
  if (dpar == "sigma") return("log")
  # Zero-inflation and hurdle submodels both use the logit link by drmTMB
  # convention (probability of structural zero / probability of being
  # above the hurdle).
  if (dpar == "zi") return("logit")
  if (dpar == "hu") return("logit")
  # metafor location-scale: log of the heterogeneity VARIANCE (not SD).
  if (dpar == "tau2") return("log")
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
    zi     = "\\pi_{\\mathrm{zi}}",  # zero-inflation probability
    hu     = "\\pi_{\\mathrm{hu}}",  # hurdle probability
    tau2   = "\\tau^{2}",            # meta-analytic heterogeneity (variance)
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
  # Audit M3: the scale (sigma) submodel design matrix is \mathbf{X}_\sigma,
  # NOT \mathbf{Z}. \mathbf{Z} is reserved exclusively for the random-effects
  # incidence matrix (it maps the group-level BLUPs \mathbf{u} onto the n
  # observations). Tab 3's stacked-matrix block already renamed the scale
  # design to \mathbf{X}_\sigma (Noether's audit); routing the symbol
  # through here keeps Tab 2 (the matrix view) and the symbol glossary
  # consistent, so the same fit never shows \mathbf{Z} meaning two
  # different matrices across tabs.
  switch(
    dpar,
    mu     = "\\mathbf{X}",
    mu1    = "\\mathbf{X}_{1}",
    mu2    = "\\mathbf{X}_{2}",
    sigma  = "\\mathbf{X}_{\\sigma}",
    sigma1 = "\\mathbf{X}_{\\sigma_{1}}",
    sigma2 = "\\mathbf{X}_{\\sigma_{2}}",
    rho12  = "\\mathbf{W}",
    zi     = "\\mathbf{X}_{\\mathrm{zi}}",
    hu     = "\\mathbf{X}_{\\mathrm{hu}}",
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
  #
  # If the input is already a `\mathrm{...}_i`-wrapped fallback from
  # drm_resolve_response_symbol (e.g. `\mathrm{body\_mass}_i` when the
  # user didn't supply a `symbols = c(...)` mapping), extract the inner
  # name and re-wrap as a bold vector with the underscores still
  # escaped. Otherwise the result would be `\mathbf{\mathrm{body\\_mass}}`
  # which mangles the LaTeX.
  m <- regmatches(response_symbol,
                  regexec("^\\\\mathrm\\{(.*)\\}_i$", response_symbol))[[1L]]
  if (length(m) == 2L) {
    # Already-escaped scalar fallback. Lowercase the inner name and
    # re-emit as `\mathbf{...}`. Underscores are already `\_`-escaped.
    return(paste0("\\mathbf{", tolower(m[[2L]]), "}"))
  }
  root <- sub("_i$", "", response_symbol)
  root_lc <- tolower(root)
  # Escape literal underscores so MathJax doesn't render them as
  # subscripts inside the bold wrapper.
  root_lc <- gsub("_", "\\_", root_lc, fixed = TRUE)
  paste0("\\mathbf{", root_lc, "}")
}

drm_resolve_response_symbol <- function(response, symbols) {
  if (!is.null(symbols) && response %in% names(symbols)) {
    return(unname(symbols[[response]]))
  }
  default_response_symbol(response)
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
  # B6 fix (Ayumi's bug): drmTMB exposes `phylo()`, `animal()`, `spatial()`,
  # and `gp()` as formula markers wrapping a random-effect spec, e.g.
  # `phylo(1 | species, tree = tree)`. R's `stats::terms()` /
  # `stats::model.frame()` don't know about these markers and treat them
  # as function calls on literal columns, crashing with
  # "invalid type (NULL) for variable 'phylo(1 | species, tree = tree)'".
  # Strip the marker (replace with its first argument wrapped in parens
  # so lme4-style RE notation `(g | group)` is preserved) before handing
  # to `stats::terms()`. The marker presence is detected separately
  # (`has_drmtmb_phylo` etc.) and surfaced via `metadata$phylo_representation`.
  #
  # v0.22.1: after drm_strip_markers() converts e.g. `phylo(1 | phylogeny)`
  # → `(1 | phylogeny)`, those newly exposed RE bars must be stripped too so
  # stats::model.frame() doesn't try to evaluate `1 | phylogeny`.
  rhs <- drm_strip_markers(entry$rhs)
  rhs <- drm_strip_re_terms(rhs)
  rhs_txt <- paste(deparse(rhs), collapse = " ")
  stats::as.formula(paste("~", rhs_txt))
}

# Recursively walk an R expression and replace `phylo(<re_spec>, ...)`,
# `animal(<re_spec>, ...)`, `spatial(<re_spec>, ...)`, `gp(<re_spec>, ...)`
# calls with `(<re_spec>)` so downstream stats::terms() sees a normal
# mixed-model formula.
drm_strip_markers <- function(expr) {
  if (is.call(expr)) {
    fn_name <- as.character(expr[[1L]])[1L]
    if (fn_name %in% c("phylo", "animal", "spatial", "gp",
                       "drmTMB::phylo", "drmTMB::animal",
                       "drmTMB::spatial", "drmTMB::gp")) {
      # Marker call: replace with `(<first-arg>)`. First arg is the RE spec.
      inner <- expr[[2L]]
      return(call("(", inner))
    }
    for (i in seq_along(expr)[-1]) {
      expr[[i]] <- drm_strip_markers(expr[[i]])
    }
  }
  expr
}

# ---- builders ---------------------------------------------------------------

drm_build_distribution <- function(family, response_symbol,
                                   response_symbol_matrix,
                                   response_symbol_1 = NULL,
                                   response_symbol_2 = NULL,
                                   constant_scale = FALSE) {
  tex <- drm_distribution_template(
    family,
    response_symbol = response_symbol,
    response_symbol_matrix = response_symbol_matrix,
    response_symbol_1 = response_symbol_1,
    response_symbol_2 = response_symbol_2,
    constant_scale = constant_scale
  )
  tibble::tibble(
    family = family,
    response_symbol = response_symbol,
    response_symbol_matrix = response_symbol_matrix,
    parameters = drm_distribution_parameters(family),
    latex = tex$index_latex,
    latex_matrix = tex$matrix_latex
  )
}

# Look up the distribution-row LaTeX for a family from
# inst/extdata/family-distributions.csv and substitute the response symbols.
# Adding a new univariate family is a CSV-only operation; structural-shape
# families (biv_gaussian etc.) get their existing rows and the substitution
# layer handles the extra placeholders.
drm_distribution_template <- function(family, response_symbol,
                                      response_symbol_matrix,
                                      response_symbol_1 = NULL,
                                      response_symbol_2 = NULL,
                                      constant_scale = FALSE) {
  tbl <- load_template("family-distributions")
  hit <- tbl[tbl$family == family, , drop = FALSE]
  if (nrow(hit) == 0L) {
    cli::cli_abort(c(
      "No distribution-row template for family {.val {family}}.",
      i = "Add a row to {.file inst/extdata/family-distributions.csv}."
    ))
  }
  if (identical(family, "biv_gaussian") &&
      (is.null(response_symbol_1) || is.null(response_symbol_2))) {
    cli::cli_abort("biv_gaussian distribution row requires both response symbols.")
  }
  mapping <- list(
    response_symbol        = response_symbol,
    response_symbol_matrix = response_symbol_matrix,
    response_symbol_1      = response_symbol_1 %||% "",
    response_symbol_2      = response_symbol_2 %||% ""
  )
  index_latex <- drm_substitute(hit$index_latex[[1L]], mapping)
  # When the residual SD / dispersion is constant across observations (no
  # scale submodel -- lm, lmer, an intercept-only dispformula, ...), the
  # per-observation index on sigma is over-specified: write \sigma, not
  # \sigma_i (audit M4 -- the indexed form wrongly implied heteroscedasticity
  # from Rung 1 of the ladder). Targeted fixed-string swap: it leaves \mu_i,
  # \sigma_{1i} (bivariate), and \sigma_p (phylogenetic) untouched. The matrix
  # form already uses \boldsymbol{\sigma} with no per-observation index.
  if (isTRUE(constant_scale)) {
    index_latex <- gsub("\\sigma_i", "\\sigma", index_latex, fixed = TRUE)
  }
  list(
    index_latex  = index_latex,
    matrix_latex = drm_substitute(hit$matrix_latex[[1L]], mapping)
  )
}

# Map family -> the parameters string used in sym$distribution$parameters.
# This is informational only (small) and stays in code since it is a fixed
# property of the family rather than user-facing prose.
drm_distribution_parameters <- function(family) {
  switch(
    family,
    gaussian     = "mu, sigma",
    student      = "mu, sigma, nu",
    biv_gaussian = "mu1, mu2, sigma1, sigma2, rho12",
    lognormal    = "mu, sigma",
    gamma        = "mu, sigma",
    beta         = "mu, sigma",
    poisson      = "mu",
    nbinom2      = "mu, sigma",
    # Fall back: let it stay empty; the LaTeX row is the canonical truth.
    ""
  )
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

# v0.22.2.1: link inverse mapping for drmTMB families. Returns the
# response-scale predicted value given the linear predictor eta_hat.
# drmTMB family$link is a vector; the mu-submodel link is element [[1L]].
# For Lognormal the mu link is "identity" (drmTMB's mu parameterises
# E[log Y]); callers needing the response-scale E[Y] = exp(mu + sigma^2/2)
# compute it from mu_hat + sigma_hat downstream.
drm_apply_link_inverse <- function(eta_hat, link) {
  switch(
    link,
    identity = eta_hat,
    log      = exp(eta_hat),
    logit    = stats::plogis(eta_hat),
    probit   = stats::pnorm(eta_hat),
    cloglog  = -expm1(-exp(eta_hat)),
    inverse  = 1 / eta_hat,
    # Fallback: assume identity. Matches the pre-v0.22.2.1 behaviour
    # for any link name we haven't catalogued yet.
    eta_hat
  )
}

drm_build_expanded <- function(fit, re_per_entry, has_re,
                                structured_matrix_for_group = NULL) {
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
  # v0.22.2.1: store the LINEAR PREDICTOR (eta_hat) here; mu_hat
  # (response-scale predicted mean) is derived later after Z*u is added
  # and the link inverse is applied. For identity-link families
  # (Gaussian, drmTMB Lognormal-on-log-Y) mu_hat == eta_hat.
  eta_hat <- if (!is.null(X) && !is.null(beta)) drop(X %*% beta) else NULL
  sigma_hat <- if (!is.null(X_sigma) && !is.null(gamma)) {
    exp(drop(X_sigma %*% gamma))
  } else NULL
  e <- tryCatch(as.numeric(stats::residuals(fit)), error = function(...) NULL)

  # v0.22.2-discipline Slice A1: per-tier Z surfacing.
  # The pre-v0.22.2 build extracted only `re_per_entry[[which(has_re)[1]]]`
  # -- silently dropping every random-effect tier beyond the first. For
  # phylo + study fits, that hid the phylogenetic tier (the article
  # thesis) from Tab 3's numeric expansion. The maintainer's
  # Fisher-pass surfaced this bug on 2026-05-28.
  #
  # The fix iterates EVERY tier across EVERY submodel that has random
  # effects, builds per-tier Z via factor-coerced model.matrix (see
  # v0.22.1.3 fix for why factor coercion matters), and stores per-tier
  # BLUPs in `u_per_tier`. iid tiers' BLUPs come from
  # `fit$random_effects$mu$terms`; structured tiers' BLUPs come from
  # `fit$obj$report()$u_phylo` (all-nodes encoding; the first n_tips
  # entries are the tip BLUPs in factor-level order).
  #
  # Back-compat: `Z_g` and `u` keep their existing semantics (= first
  # tier) so existing renderer code that reads them keeps working.
  Z_per_tier <- list()
  u_per_tier <- list()
  tier_kind  <- character(0L)
  if (any(has_re)) {
    for (i in which(has_re)) {
      re_info <- re_per_entry[[i]]
      if (is.null(re_info) || nrow(re_info) == 0L) next
      for (gv in unique(re_info$group_var)) {
        if (!(gv %in% names(fit$data))) next
        # Factor-coerce before model.matrix (v0.22.1.3 discipline).
        data_local <- fit$data
        data_local[[gv]] <- factor(data_local[[gv]])
        levels_g <- levels(data_local[[gv]])
        Zg <- stats::model.matrix(
          stats::reformulate(paste0("0+", gv)),
          data = data_local
        )
        cn <- colnames(Zg)
        bare <- sub(paste0("^", gv), "", cn)
        if (length(bare) == length(levels_g)) colnames(Zg) <- bare
        Z_per_tier[[gv]] <- Zg

        is_structured <- !is.null(structured_matrix_for_group) &&
                         !is.null(structured_matrix_for_group[[gv]])
        tier_kind[[gv]] <- if (is_structured) "structured" else "iid"

        u_g <- NULL
        if (is_structured) {
          # Structured tier (phylo): drmTMB stores BLUPs in
          # fit$obj$report()$u_phylo under the all-nodes encoding:
          # length = n_tips + n_internal_nodes. The first n_tips
          # entries are the tip-level BLUPs, ordered by the factor's
          # levels (which matches `levels_g` above when phylogeny is
          # stored alphabetically in the tree).
          rep_obj <- tryCatch(fit$obj$report(),
                              error = function(...) NULL)
          if (!is.null(rep_obj) && !is.null(rep_obj$u_phylo)) {
            u_phylo_all <- as.numeric(rep_obj$u_phylo)
            n_tips      <- length(levels_g)
            if (length(u_phylo_all) >= n_tips) {
              u_g <- u_phylo_all[seq_len(n_tips)]
            }
          }
        } else {
          # iid tier: drmTMB stores BLUPs by level name in
          # fit$random_effects$mu$terms[[term_label]].
          term_label <- sprintf("(1 | %s)", gv)
          blups <- fit$random_effects$mu$terms[[term_label]]
          if (!is.null(blups)) {
            if (!is.null(names(blups)) &&
                all(colnames(Zg) %in% names(blups))) {
              blups <- blups[colnames(Zg)]
            }
            u_g <- as.numeric(blups)
          }
        }
        u_per_tier[[gv]] <- u_g
      }
    }
  }

  # Back-compat aliases: first tier becomes Z_g / u.
  Z_g <- if (length(Z_per_tier) > 0L) Z_per_tier[[1L]] else NULL
  u   <- if (length(u_per_tier) > 0L) u_per_tier[[1L]] else NULL

  # v0.22.2.1: include EVERY random-effect tier's contribution in eta_hat
  # so the linear-predictor is complete. Pre-2026-05-28 behaviour
  # computed mu_hat = X*beta only; the residual e came from
  # stats::residuals(fit) which IS y - (X*beta + sum_g Z_g*u_g). That
  # mismatch broke Tab 3's worked row. Add Zu to eta_hat per tier.
  if (!is.null(eta_hat) && length(Z_per_tier) > 0L) {
    for (gv in names(Z_per_tier)) {
      Z_gv <- Z_per_tier[[gv]]
      u_gv <- u_per_tier[[gv]]
      if (!is.null(Z_gv) && !is.null(u_gv)) {
        eta_hat <- eta_hat + drop(Z_gv %*% u_gv)
      }
    }
  }

  # v0.22.2.1 part 2: apply the link inverse so mu_hat carries the
  # RESPONSE-scale predicted value (not the linear predictor). Surfaced
  # by the Fisher pass on symbolizer-families.html: Beta widget displayed
  # mu_hat = -0.95, an impossible value for a Beta mean. After this fix
  # mu_hat = plogis(eta_hat) = 0.279 ∈ (0,1) as required.
  #
  # Family / link mapping. drmTMB stores link as a length-vector with
  # the mu-submodel link in position [[1L]]. For Lognormal drmTMB's
  # mu parameterises E[log Y] (identity link on mu), so identity is
  # correct -- the response-scale E[Y] = exp(mu + sigma^2/2) is a
  # separate derived quantity that callers compute downstream.
  mu_hat <- if (is.null(eta_hat)) NULL else {
    link <- if (!is.null(fit$family$link)) as.character(fit$family$link[[1L]]) else "identity"
    drm_apply_link_inverse(eta_hat, link)
  }

  list(
    y          = y,
    X          = X,
    beta       = if (is.null(beta))  NULL else as.numeric(beta),
    X_sigma    = X_sigma,
    gamma      = if (is.null(gamma)) NULL else as.numeric(gamma),
    Z_g        = Z_g,
    u          = u,
    Z_per_tier = Z_per_tier,
    u_per_tier = u_per_tier,
    tier_kind  = tier_kind,
    e          = e,
    eta_hat    = eta_hat,
    mu_hat     = mu_hat,
    sigma_hat  = sigma_hat
  )
}

# Render a data-derived group / column name safely as a LaTeX subscript
# (audit M2). A snake_case name such as `study_ID` interpolated raw into
# a subscript -- e.g. `\sigma_{study_ID}`, `u_{study_ID(i)}`,
# `\mathbf{u}_{study_ID}` -- is read by KaTeX as a nested double
# subscript (`_{study` then a stray `_ID`), so it renders wrong. Wrap
# multi-token names in `\mathrm{...}` with the underscore escaped so the
# whole name reads upright as one identifier; leave single-token names
# (`g`, `species`) untouched so the historical simple symbols are
# unchanged.
#' @keywords internal
drm_group_subscript <- function(group_var) {
  if (length(group_var) != 1L || is.na(group_var) || !nzchar(group_var)) {
    return(group_var)
  }
  if (grepl("_", group_var, fixed = TRUE)) {
    sprintf("\\mathrm{%s}", gsub("_", "\\_", group_var, fixed = TRUE))
  } else {
    group_var
  }
}

drm_build_random_effects <- function(re_per_entry) {
  filled <- Filter(Negate(is.null), re_per_entry)
  if (length(filled) == 0L) return(NULL)
  out <- do.call(rbind, filled)
  # Determine per-(submodel, group_var) how many components there are.
  # Single-component groups (intercept-only) use the historic simple
  # symbols u_{group(i)} / \sigma_{group}. Multi-component groups use
  # numbered subscripts: u_{0,group(i)} for the intercept, u_{1,group(i)}
  # for the first slope, etc.
  out$component_index <- NA_integer_
  out$u_symbol_index  <- NA_character_
  out$u_symbol_matrix <- NA_character_
  out$sigma_symbol    <- NA_character_
  out$predictor_factor <- NA_character_  # what multiplies u_k in the linear predictor (NA for intercept)
  for (sm in unique(out$submodel)) {
    for (gv in unique(out$group_var[out$submodel == sm])) {
      sel <- which(out$submodel == sm & out$group_var == gv)
      n_comp <- length(sel)
      # Sort so the intercept row is first; slope rows come after in
      # the order drmTMB emitted them.
      sel <- sel[order(out$component[sel] != "(Intercept)",
                       out$component[sel])]
      for (k in seq_along(sel)) {
        row <- sel[[k]]
        idx <- k - 1L  # 0-based index, matches the math convention
        out$component_index[[row]] <- idx
        # Escape snake_case group names for safe subscript rendering
        # (audit M2); single-token names pass through unchanged.
        gv_sub <- drm_group_subscript(gv)
        if (n_comp == 1L) {
          # Intercept-only: keep the historical simple symbols.
          out$u_symbol_index[[row]]  <- sprintf("u_{%s(i)}", gv_sub)
          out$u_symbol_matrix[[row]] <- "\\mathbf{u}"
          out$sigma_symbol[[row]]    <- sprintf("\\sigma_{%s}", gv_sub)
        } else {
          # Multi-component: numbered subscripts. Intercept gets 0,
          # slopes get 1, 2, ...
          out$u_symbol_index[[row]]  <- sprintf("u_{%d,%s(i)}", idx, gv_sub)
          out$u_symbol_matrix[[row]] <- sprintf("\\mathbf{u}_{%d}", idx)
          out$sigma_symbol[[row]]    <- sprintf("\\sigma_{u_{%d,%s}}", idx, gv_sub)
        }
        # For non-intercept components, record the predictor that
        # multiplies u_k in the linear predictor.
        if (out$component[[row]] != "(Intercept)") {
          out$predictor_factor[[row]] <- out$component[[row]]
        }
      }
    }
  }
  out
}

drm_build_variance_components <- function(re_per_entry, sdpars = NULL) {
  re <- drm_build_random_effects(re_per_entry)
  if (is.null(re)) return(NULL)
  desc <- vapply(seq_len(nrow(re)), function(i) {
    if (re$component[[i]] == "(Intercept)") {
      sprintf("between-%s standard deviation of the random intercept on %s",
              re$group_var[[i]], re$submodel[[i]])
    } else {
      sprintf("between-%s standard deviation of the random slope on %s on the %s submodel",
              re$group_var[[i]], re$component[[i]], re$submodel[[i]])
    }
  }, character(1L))
  # v0.22.x: pull the numeric between-group SD from the fitted object's
  # `sdpars` (a list keyed by submodel; each element a named vector of RE
  # SDs, e.g. fit$sdpars$mu = c("(1 | group)" = 0.613)). This is the
  # keystone that lets variance_partition() / icc() / the variation panel
  # read real numbers for drmTMB (lme4 / glmmTMB already carry them).
  # Match a row to its SD by the group variable appearing inside the
  # RE-term name "( ... | <group> )". Unmatched rows get NA (graceful).
  sd_for <- function(submodel, group_var) {
    v <- if (!is.null(sdpars)) sdpars[[submodel]] else NULL
    if (is.null(v) || length(v) == 0L) return(NA_real_)
    hit <- v[grepl(sprintf("\\|\\s*%s\\s*\\)$",
                           gsub("([.\\\\^$|(){}+*?\\[\\]])", "\\\\\\1", group_var)),
                   names(v))]
    if (length(hit) >= 1L) as.numeric(hit[[1L]]) else as.numeric(v[[1L]])
  }
  sd_est <- vapply(seq_len(nrow(re)),
                   function(i) sd_for(re$submodel[[i]], re$group_var[[i]]),
                   numeric(1L))
  tibble::tibble(
    submodel    = re$submodel,
    group_var   = re$group_var,
    component   = re$component,
    parameter   = sprintf("sigma_%s_%s", re$group_var,
                          ifelse(re$component == "(Intercept)", "0",
                                 re$component)),
    symbol      = re$sigma_symbol,
    n_levels    = re$n_levels,
    sd_estimate = sd_est,
    var_estimate = sd_est^2,
    description = desc
  )
}

# Pairwise within-group correlations between random components. For
# (1 + x | g) this produces one row (intercept x x). For (1 | g) it
# returns NULL since there's only one component per group.
drm_build_covariance_components <- function(re_tbl) {
  if (is.null(re_tbl) || nrow(re_tbl) == 0L) return(NULL)
  rows <- list()
  for (sm in unique(re_tbl$submodel)) {
    for (gv in unique(re_tbl$group_var[re_tbl$submodel == sm])) {
      sel <- which(re_tbl$submodel == sm & re_tbl$group_var == gv)
      if (length(sel) < 2L) next
      comps <- re_tbl$component[sel]
      for (i in seq_along(comps)) {
        for (j in seq_along(comps)) {
          if (j <= i) next
          rows[[length(rows) + 1L]] <- tibble::tibble(
            submodel    = sm,
            group_var   = gv,
            component_1 = comps[[i]],
            component_2 = comps[[j]],
            rho_symbol  = sprintf("\\rho_{u_{%d,%s},\\, u_{%d,%s}}",
                                  re_tbl$component_index[sel][[i]],
                                  drm_group_subscript(gv),
                                  re_tbl$component_index[sel][[j]],
                                  drm_group_subscript(gv)),
            description = sprintf(
              "within-%s correlation between the random %s and the random %s on %s",
              gv,
              if (comps[[i]] == "(Intercept)") "intercept" else paste("slope on", comps[[i]]),
              if (comps[[j]] == "(Intercept)") "intercept" else paste("slope on", comps[[j]]),
              sm
            )
          )
        }
      }
    }
  }
  if (length(rows) == 0L) return(NULL)
  do.call(rbind, rows)
}

drm_build_components <- function(submodels, terms_tbl, re_tbl, response_symbol,
                                  response_symbol_matrix,
                                  family = "gaussian",
                                  response_symbol_1 = NULL,
                                  response_symbol_2 = NULL,
                                  structured_matrix_for_group = NULL,
                                  constant_scale = FALSE) {
  # v0.21.1+ `structured_matrix_for_group`: optional named list mapping
  # random-effect group name to a LaTeX matrix symbol (e.g.,
  # list(species = "\\mathbf{A}") for a phylogenetic random effect, or
  # list(site = "\\boldsymbol{\\Omega}") for spatial). When the group
  # appears in this list, the matrix-form distribution line for that
  # random effect uses the structured matrix instead of \mathbf{I}_n.
  # Default NULL preserves the v0.20 \mathbf{I}_n behaviour for all
  # non-structured fits.
  is_biv <- identical(family, "biv_gaussian")
  # Distribution row LaTeX is templated from family-distributions.csv,
  # not branched per family. Adding a univariate family is a CSV-only op.
  tex <- drm_distribution_template(
    family,
    response_symbol        = response_symbol,
    response_symbol_matrix = response_symbol_matrix,
    response_symbol_1      = response_symbol_1,
    response_symbol_2      = response_symbol_2,
    constant_scale         = constant_scale
  )
  rows <- list()
  rows[[1L]] <- tibble::tibble(
    name            = "distribution",
    kind            = "distribution",
    submodel        = NA_character_,
    equation        = tex$index_latex,
    equation_matrix = tex$matrix_latex,
    status          = "stated"
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
      # Index form: render each component as its own term. Intercept rows
      # contribute the bare u_{...} symbol; slope rows multiply by the
      # predictor variable.
      idx_terms <- vapply(seq_len(nrow(re_for_dpar)), function(i) {
        u_sym <- re_for_dpar$u_symbol_index[[i]]
        pred  <- re_for_dpar$predictor_factor[[i]]
        # Render the slope covariate through the default-symbol machinery so a
        # snake_case name escapes its underscore and wraps upright (matching the
        # fixed effect): `\mathrm{body\_size}_i`, not a raw `body_size_i` whose
        # `_` silently breaks the math. Single-letter names are unchanged.
        if (is.na(pred)) u_sym else
          sprintf("%s \\, %s", u_sym, default_response_symbol(pred))
      }, character(1L))
      re_idx <- paste(idx_terms, collapse = " + ")
      rhs <- if (nzchar(rhs)) paste(rhs, "+", re_idx) else re_idx
      # Matrix form: for intercept-only groups, render the bare \mathbf{u};
      # for multi-component groups, use \mathbf{Z}_g \mathbf{u}_g per group.
      # When there's more than one random-effect group, disambiguate the
      # intercept-only term with \mathbf{u}_g so the multilevel structure
      # is visible (otherwise the linear predictor collapses to repeated
      # bare \mathbf{u} terms, which is unreadable).
      groups <- unique(re_for_dpar$group_var)
      mat_terms <- vapply(groups, function(gv) {
        sel <- which(re_for_dpar$group_var == gv)
        # Escape snake_case group names for safe subscript rendering
        # (audit M2); single-token names pass through unchanged.
        gv_sub <- drm_group_subscript(gv)
        if (length(sel) == 1L &&
            is.na(re_for_dpar$predictor_factor[[sel[[1L]]]])) {
          # Intercept-only group: bare \mathbf{u} when there's only one
          # group (historic notation); group-subscripted otherwise.
          if (length(groups) == 1L) {
            re_for_dpar$u_symbol_matrix[[sel[[1L]]]]
          } else {
            sprintf("\\mathbf{u}_{%s}", gv_sub)
          }
        } else {
          # Multi-component (random intercept + slopes): \mathbf{Z}_g \mathbf{u}_g.
          sprintf("\\mathbf{Z}_{%s}\\, \\mathbf{u}_{%s}", gv_sub, gv_sub)
        }
      }, character(1L))
      re_mat <- paste(mat_terms, collapse = " + ")
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
  # Random-effect distribution row(s). For each (submodel, group_var) emit:
  #   - one univariate Normal row when the group has just an intercept
  #     (historic shape), OR
  #   - a joint multivariate Normal row plus a covariance-decomposition row
  #     when the group has multiple components (intercept + slope(s)).
  if (!is.null(re_tbl)) {
    re_keys <- unique(re_tbl[, c("submodel", "group_var")])
    for (kk in seq_len(nrow(re_keys))) {
      sm <- re_keys$submodel[[kk]]
      g  <- re_keys$group_var[[kk]]
      # Escape snake_case group names for safe LaTeX subscript rendering
      # (audit M2). `g` itself stays raw for internal row names and data
      # matching; `g_sub` is what goes inside `_{...}` subscripts.
      g_sub <- drm_group_subscript(g)
      sel <- which(re_tbl$submodel == sm & re_tbl$group_var == g)
      n_comp <- length(sel)
      n_levels <- re_tbl$n_levels[[sel[[1L]]]]
      if (n_comp == 1L) {
        sym <- re_tbl$sigma_symbol[[sel[[1L]]]]
        # v0.21.1+: if this group has a structured covariance matrix
        # registered (phylogenetic, spatial, animal), use it on the
        # matrix form instead of the identity. The index form stays as
        # the marginal `u_g \sim N(0, sigma^2)` since A's diagonal is 1
        # and the per-species draw is marginally N(0, sigma^2) anyway --
        # the structural information lives in the joint, which is the
        # matrix form's headline.
        struct_sym <- if (!is.null(structured_matrix_for_group) &&
                          !is.null(structured_matrix_for_group[[g]])) {
          structured_matrix_for_group[[g]]
        } else NULL
        # When a structured matrix is present, the random effect's
        # distribution is a JOINT multivariate normal: the structure
        # lives in the joint covariance, not the per-species marginal
        # (A's diagonal is 1, so the marginal is just N(0, sigma^2)).
        # Index form for non-phylo fits keeps the old scalar marginal
        # form for back-compat (u_g ~ N(0, sigma^2)); for phylo / spatial
        # fits the index-form line gets upgraded to bold-vector joint
        # form because that is where the structural information lives.
        # Matrix form always uses bold vectors. Biology gloss above the
        # equation explains the joint reading.
        if (!is.null(struct_sym)) {
          eq_index <- sprintf(
            "\\mathbf{u}_{%s} \\sim \\mathcal{N}(\\mathbf{0},\\, %s^2 %s)",
            g_sub, sym, struct_sym
          )
          eq_matrix <- sprintf(
            "\\mathbf{u}_{%s} \\sim \\mathcal{N}(\\mathbf{0},\\, %s^2 %s_{%d \\times %d})",
            g_sub, sym, struct_sym, n_levels, n_levels
          )
        } else {
          eq_index <- sprintf("u_{%s} \\sim \\mathcal{N}(0,\\, %s^2)", g_sub, sym)
          eq_matrix <- sprintf(
            "\\mathbf{u}_{%s} \\sim \\mathcal{N}(\\mathbf{0},\\, %s^2 \\mathbf{I}_{%d})",
            g_sub, sym, n_levels
          )
        }
        rows[[length(rows) + 1L]] <- tibble::tibble(
          name = sprintf("%s_random_intercept_%s", sm, g),
          kind = "random_effect_distribution",
          submodel = sm,
          equation = eq_index,
          equation_matrix = eq_matrix,
          status = "stated"
        )
      } else {
        # Multi-component (random intercept + slope(s)): joint MVN.
        idx_vec <- paste0("(",
          paste(re_tbl$u_symbol_index[sel], collapse = ",\\, "),
          ")^{\\!\\top}")
        rows[[length(rows) + 1L]] <- tibble::tibble(
          name = sprintf("%s_random_effects_%s", sm, g),
          kind = "random_effect_distribution",
          submodel = sm,
          equation = sprintf(
            "%s \\sim \\mathcal{N}_{%d}(\\mathbf{0},\\, \\boldsymbol{\\Sigma}_{u,%s})",
            idx_vec, n_comp, g_sub
          ),
          equation_matrix = sprintf(
            "\\mathbf{u}_{%s} \\sim \\mathcal{N}_{%d}(\\mathbf{0},\\, \\boldsymbol{\\Sigma}_{u,%s})",
            g_sub, n_comp, g_sub
          ),
          status = "stated"
        )
        # Covariance-matrix decomposition row.
        sigmas <- re_tbl$sigma_symbol[sel]
        diag_terms <- sprintf("%s^2", sigmas)
        # Off-diagonal: rho_{u_i,u_j} * sigma_i * sigma_j. Use the rho
        # symbols we'd put in covariance_components.
        off_terms <- list()
        for (i in seq_len(n_comp)) for (j in seq_len(n_comp)) {
          if (i == j) next
          if (i < j) {
            off_terms[[length(off_terms) + 1L]] <- sprintf(
              "\\rho_{u_{%d,%s},u_{%d,%s}}\\, %s\\, %s",
              re_tbl$component_index[sel][[i]], g_sub,
              re_tbl$component_index[sel][[j]], g_sub,
              sigmas[[i]], sigmas[[j]]
            )
          }
        }
        # Build a 2x2 (or larger) matrix in TeX.
        sigma_mat <- if (n_comp == 2L) {
          sprintf(
            "\\boldsymbol{\\Sigma}_{u,%s} = \\begin{pmatrix} %s & %s \\\\ %s & %s \\end{pmatrix}",
            g_sub,
            diag_terms[[1L]], off_terms[[1L]],
            off_terms[[1L]], diag_terms[[2L]]
          )
        } else {
          # For >2 components, write Sigma_u in terms of D and Omega
          # rather than spelling out the full matrix.
          sprintf(
            "\\boldsymbol{\\Sigma}_{u,%s} = \\mathbf{D}_{u,%s}\\, \\boldsymbol{\\Omega}_{u,%s}\\, \\mathbf{D}_{u,%s} \\text{ where } \\mathbf{D}_{u,%s} = \\mathrm{diag}(%s)",
            g_sub, g_sub, g_sub, g_sub, g_sub,
            paste(sigmas, collapse = ",\\, ")
          )
        }
        rows[[length(rows) + 1L]] <- tibble::tibble(
          name = sprintf("%s_random_effects_covariance_%s", sm, g),
          kind = "covariance_decomposition",
          submodel = sm,
          equation = sigma_mat,
          equation_matrix = sigma_mat,
          status = "stated"
        )
      }
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
  # `rho12` (two-digit subscript gets a comma before i to keep readability),
  # "\\pi_{\\mathrm{zi},i}" for `zi` (non-digit subscript: insert ", i"
  # inside the existing subscript braces).
  m_digits <- regmatches(greek, regexec("^(.*)_\\{([0-9]+)\\}$", greek))[[1L]]
  if (length(m_digits) == 3L && nzchar(m_digits[[2L]]) && nzchar(m_digits[[3L]])) {
    sub_digits <- m_digits[[3L]]
    sep <- if (nchar(sub_digits) >= 2L) "," else ""
    return(paste0(m_digits[[2L]], "_{", sub_digits, sep, "i}"))
  }
  # Non-digit subscript: insert ", i" before the closing brace.
  m_sub <- regmatches(greek, regexec("^(.*)_\\{(.+)\\}$", greek))[[1L]]
  if (length(m_sub) == 3L && nzchar(m_sub[[2L]]) && nzchar(m_sub[[3L]])) {
    return(paste0(m_sub[[2L]], "_{", m_sub[[3L]], ",\\, i}"))
  }
  paste0(greek, "_i")
}

drm_build_symbol_dictionary <- function(terms_tbl, response, response_symbol,
                                        response_symbol_matrix,
                                        response_units, family, submodels,
                                        units, data, n_obs, re_tbl = NULL,
                                        response_1 = NULL, response_2 = NULL,
                                        response_symbol_1 = NULL,
                                        response_symbol_2 = NULL,
                                        structured_matrices = NULL,
                                        constant_scale = FALSE) {
  # `structured_matrices` (v0.21+): optional list of rows to append for
  # structured-covariance matrices (phylogenetic A, spatial Omega, etc.).
  # Each entry is a named list with the same fields as a symbol_dictionary
  # row: symbol, symbol_matrix, variable, units, role, dimension,
  # dimension_concrete, description. Extractors that detect a structured
  # random effect pass these so the dictionary surfaces the matrix as a
  # first-class symbol. NULL or empty list -> no-op (back-compat).
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
  # v0.22.4 #10: the dispersion parameter's gloss must be family-aware.
  # "conditional sigma of y" is misleading for Beta (sigma is a PRECISION:
  # larger => tighter, the opposite of an SD), Gamma (dispersion), NegBin
  # (overdispersion), etc. Source the meaning from the per-family
  # scale_meaning column of family-parameterizations.csv.
  sigma_meaning_lookup <- function(fam, column = "scale_meaning") {
    tbl <- tryCatch(load_template("family-parameterizations"),
                    error = function(e) NULL)
    if (is.null(tbl) || !"family" %in% names(tbl) ||
        !column %in% names(tbl)) return("")
    hit <- tbl[tbl$family == fam, , drop = FALSE]
    if (nrow(hit) == 0L) return("")
    sm <- hit[[column]][[1L]]
    if (is.na(sm) || !nzchar(sm)) "" else sm
  }
  for (i in seq_len(nrow(submodels))) {
    dpar <- submodels$parameter[[i]]
    greek <- drm_param_greek(dpar)
    desc_i <- if (identical(dpar, "sigma")) {
      sm <- sigma_meaning_lookup(family)
      if (nzchar(sm)) sm else sprintf("conditional %s of %s", dpar, param_owner(dpar))
    } else if (dpar %in% c("mu", "mu1", "mu2")) {
      # The mean parameter's gloss is family-aware too: "conditional mu of y" is
      # wrong for Lognormal, where mu is the mean of log(Y), not of Y. Reuse the
      # family-parameterizations lookup with the mean_meaning column; families
      # with no override fall back to the generic "conditional mu of <response>".
      mm <- sigma_meaning_lookup(family, "mean_meaning")
      if (nzchar(mm)) mm else sprintf("conditional %s of %s", dpar, param_owner(dpar))
    } else {
      sprintf("conditional %s of %s", dpar, param_owner(dpar))
    }
    rows[[length(rows) + 1L]] <- tibble::tibble(
      symbol = drm_param_index_form(dpar, greek),
      symbol_matrix = drm_param_greek_bold(dpar),
      variable = NA_character_,
      units = NA_character_,
      role = "parameter",
      dimension = "\\mathbb{R}^n",
      dimension_concrete = sprintf("\\mathbb{R}^{%d}", n_obs),
      description = desc_i
    )
  }
  # v0.21.1+ residual-SD row.
  # Florence + Rose audit 2026-05-26: the equation block for any
  # Gaussian-style family carries `\sigma_i` (or its matrix-form
  # counterpart) in the response distribution -- but extractors that
  # don't promote sigma to its own submodel (lm, lmer, MCMCglmm, brms
  # Gaussian, glmmTMB Gaussian, metafor) never add a row for it,
  # so the symbol gloss list silently misses sigma. Add it once here
  # so every Gaussian-style fit's gloss is complete. drmTMB and
  # biv_gaussian already include sigma submodels via the loop above;
  # we detect that and skip to avoid duplicating the row.
  family_has_residual_sd <- family %in% c(
    "gaussian", "lognormal", "student", "Gamma", "beta",
    "nbinom2", "beta_binomial", "truncated_nbinom2", "meta_normal"
  )
  already_has_sigma <- "sigma" %in% submodels$parameter ||
                      "sigma1" %in% submodels$parameter ||
                      "sigma2" %in% submodels$parameter
  if (family_has_residual_sd && !already_has_sigma) {
    desc <- switch(family,
      gaussian        = "residual standard deviation",
      lognormal       = "residual standard deviation on the log scale",
      student         = "residual scale",
      Gamma           = "Gamma dispersion (on the log scale)",
      beta            = "Beta precision (on the log scale)",
      nbinom2         = "negative-binomial dispersion (size, on the log scale)",
      beta_binomial   = "beta-binomial precision (on the log scale)",
      truncated_nbinom2 = "negative-binomial dispersion (size, on the log scale)",
      meta_normal     = "residual heterogeneity SD (tau)",
      "residual scale"
    )
    # Constant-scale guard (v0.22.5 #10): the default glosses above assume a
    # drmTMB-style log-link dispersion submodel (e.g. "(on the log scale)").
    # A fit with a SINGLE constant scalar scale and NO dispersion submodel
    # (an mgcv gam/bam Gamma reports phi directly, not on the log scale)
    # needs an honest constant-scale gloss instead. Source it from the
    # `scale_meaning_constant` column of family-parameterizations.csv; fall
    # back to the log-scale switch value if no constant gloss is templated.
    if (isTRUE(constant_scale)) {
      cm <- sigma_meaning_lookup(family, column = "scale_meaning_constant")
      if (nzchar(cm)) desc <- cm
    }
    rows[[length(rows) + 1L]] <- tibble::tibble(
      # Audit M4: this row is added only for fits with NO scale submodel
      # (lm, lmer, MCMCglmm, brms / glmmTMB Gaussian, metafor) -- i.e. a
      # single residual SD that is constant across observations (the
      # dimension below says so). The symbol must therefore be the
      # unindexed scalar `\sigma`, not `\sigma_i`; the per-observation
      # subscript is reserved for genuine location-scale fits whose sigma
      # submodel makes the SD vary by row.
      symbol = "\\sigma",
      symbol_matrix = "\\boldsymbol{\\sigma}",
      variable = NA_character_,
      units = NA_character_,
      role = "residual_sd",
      dimension = "scalar (constant across observations)",
      dimension_concrete = "scalar",
      description = sprintf("%s of %s",
                            desc,
                            response_1 %||% response %||% "y")
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
      # Escape snake_case group names for safe LaTeX subscript rendering
      # (audit M2); `g` stays raw for the plain-text variable / description.
      g_sub <- drm_group_subscript(g)
      rows[[length(rows) + 1L]] <- tibble::tibble(
        symbol             = re_tbl$u_symbol_index[[i]],
        symbol_matrix      = sprintf("\\mathbf{u}_{%s}", g_sub),
        variable           = g,
        units              = NA_character_,
        role               = "random_intercept",
        dimension          = sprintf("scalar; $\\mathbb{R}^{G_{%s}}$ in matrix form", g_sub),
        dimension_concrete = sprintf("scalar; $\\mathbb{R}^{%d}$ in matrix form", G),
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
  # v0.21+ structured-covariance matrix rows (A, Omega, ...). Each entry is
  # a named list with the symbol_dictionary row fields; extractors that
  # detect a phylogenetic / spatial / temporal structured random effect
  # pass these to surface the matrix itself as a first-class symbol.
  if (!is.null(structured_matrices) && length(structured_matrices) > 0L) {
    for (sm in structured_matrices) {
      rows[[length(rows) + 1L]] <- tibble::as_tibble(sm)
    }
  }
  do.call(rbind, rows)
}

# Honest link-aware prose for a given link, from inst/extdata/link-readings.csv.
# Returns the matching row, the generic "*" fallback, or NULL.
drm_link_reading <- function(link) {
  tbl <- tryCatch(load_template("link-readings"), error = function(e) NULL)
  if (is.null(tbl) || !"link" %in% names(tbl)) return(NULL)
  hit <- tbl[tbl$link == link, , drop = FALSE]
  if (nrow(hit) == 0L) hit <- tbl[tbl$link == "*", , drop = FALSE]
  if (nrow(hit) == 0L) return(NULL)
  hit[1L, , drop = FALSE]
}

# TRUE when an explicit fit link differs from the family's default link
# (family-parameterizations.csv link_mu). When they match, the family-keyed
# prose is already correct, so no override is needed (NULL link_mu => FALSE,
# preserving behaviour for every caller that does not pass a link).
drm_link_overrides_default <- function(family, link_mu) {
  if (is.null(link_mu) || is.na(link_mu) || !nzchar(link_mu)) return(FALSE)
  default <- tryCatch(get_parameterization(family)$link_mu,
                      error = function(e) NA_character_)
  !is.na(default) && nzchar(default) && !identical(link_mu, default)
}

drm_build_assumptions <- function(family, response, response_symbol,
                                  re_tbl = NULL,
                                  response_1 = NULL, response_2 = NULL,
                                  detected_signals = character(0L),
                                  link_mu = NULL,
                                  constant_scale = FALSE) {
  tbl <- load_template("assumption-templates")
  rows <- tbl[tbl$family == family, , drop = FALSE]
  if (nrow(rows) == 0L) {
    cli::cli_abort("No assumption template rows for family {.val {family}}.")
  }
  # Constant-scale guard (v0.22.5 #10): some fitted classes estimate a SINGLE
  # scalar dispersion / scale parameter with NO dispersion submodel and NO log
  # link on the scale (e.g. an mgcv gam/bam Gamma or gaussian fit reports one
  # phi / residual variance directly). The shared family templates carry a
  # `sigma` submodel block -- a log-linked linear_predictor `log(sigma_i) =
  # gamma_0 + sum_k gamma_k Z_{ki}` plus a positivity row -- that describes a
  # drmTMB-style location-scale model such a fit does NOT have. Drop those
  # phantom sigma-submodel rows when the caller flags a constant scale. The
  # single scalar value lives in variance_components, not in an assumptions
  # submodel. drmTMB / glmmTMB / brms location-scale fits keep the default
  # `constant_scale = FALSE`, so their real sigma submodel is untouched.
  if (isTRUE(constant_scale)) {
    rows <- rows[rows$submodel != "sigma" | is.na(rows$submodel), , drop = FALSE]
  }
  # v0.21+ requires-column gating. Rows can carry a `requires` value naming
  # a structured-dependence signal (phylo / spatial / animal / temporal /
  # meta_analysis). Such rows fire ONLY when the extractor reports a
  # matching signal via `detected_signals`. Rows whose `requires` is empty
  # / NA / outside the known vocabulary fire unconditionally (the unknown
  # case covers pre-existing field-shift parse issues in the CSV).
  if ("requires" %in% names(rows)) {
    req <- rows$requires
    known <- c("phylo", "phylo_marginal", "spatial", "animal",
               "temporal", "meta_analysis")
    keep <- is.na(req) | req == "" | !(req %in% known) |
            (req %in% detected_signals)
    rows <- rows[keep, , drop = FALSE]
  }
  has_re <- !is.null(re_tbl) && nrow(re_tbl) > 0L
  # A structured-dependence signal (e.g. phylo_marginal from phylolm's PGLS
  # residual covariance) breaks the plain conditional-independence claim even
  # when there is no random-effect tibble: the dependence lives in the dense
  # residual covariance, not in a u_p tier. Drop the unconditional
  # `independence` row in that case too, so the headline assumptions do not
  # self-contradict the phylo-covariance rows. Guarded strictly by the
  # signal so ordinary Gaussian fits (no signal, no re_tbl) keep `independence`.
  structured_dependence_signals <- c("phylo_marginal", "spatial", "temporal")
  has_structured_dependence <- any(detected_signals %in%
                                     structured_dependence_signals)
  if (has_structured_dependence) {
    # The dependence lives in a dense residual covariance and there is no
    # random-effect tier (phylolm marginalizes u_p into e). BOTH independence
    # variants are then false / misleading -- drop them and let the
    # marginal-covariance rows carry the dependence statement.
    drop_assumption <- c("independence", "independence_given_random_effects")
  } else if (has_re) {
    drop_assumption <- "independence"
  } else {
    drop_assumption <- "independence_given_random_effects"
  }
  rows <- rows[!(rows$assumption %in% drop_assumption), , drop = FALSE]
  # phylolm's PGLS marginal form has a single scalar sigma^2 and no scale
  # (distributional) submodel, so the generic Gaussian sigma-submodel
  # boilerplate (log(sigma_i) = gamma_0 + ..., sigma_i > 0) describes
  # machinery that does not exist. Drop those scale-submodel rows under the
  # marginal-PGLS signal only; location-scale Gaussian fits (drmTMB) carry
  # no phylo_marginal signal and keep their sigma submodel rows.
  if ("phylo_marginal" %in% detected_signals) {
    rows <- rows[is.na(rows$submodel) | rows$submodel != "sigma", ,
                 drop = FALSE]
  }
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
  out <- tibble::tibble(
    family = rows$family,
    submodel = rows$submodel,
    assumption = rows$assumption,
    expression_latex = expr,
    biological_meaning = meaning,
    status = rows$status
  )
  # Link-honesty: when the fit uses a non-default link (e.g. mgcv Gamma's
  # inverse), the family-keyed linear_predictor template names the wrong link.
  # Replace its left-hand side + meaning with the actual link's prose.
  if (drm_link_overrides_default(family, link_mu)) {
    lr <- drm_link_reading(link_mu)
    if (!is.null(lr)) {
      # Only the mean submodel's linear predictor names the mu link; the sigma
      # submodel row keeps its own log(sigma_i) = ... template.
      lp <- which(out$assumption == "linear_predictor" &
                    out$submodel %in% c("mu", "mu1", "mu2"))
      if (length(lp) >= 1L) {
        out$expression_latex[lp] <- paste0(lr$lp_lhs[[1L]],
          " = \\beta_0 + \\sum_k \\beta_k X_{ki}")
        out$biological_meaning[lp] <- lr$link_meaning[[1L]]
      }
    }
  }
  out
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
                                     response_1 = NULL, response_2 = NULL,
                                     detected_signals = character(0L),
                                     link_mu = NULL) {
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
  # v0.21+ requires-column gating (see drm_build_assumptions for rationale).
  if ("requires" %in% names(tbl)) {
    req <- tbl$requires
    known <- c("phylo", "spatial", "animal", "temporal", "meta_analysis")
    keep <- is.na(req) | req == "" | !(req %in% known) |
            (req %in% detected_signals)
    tbl <- tbl[keep, , drop = FALSE]
  }
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
  # Link-honesty: when the fit uses a non-default link, the family-keyed
  # readings name the wrong link scale (e.g. "Log mean ... exp(beta)" for an
  # inverse-link Gamma). Override the mean-submodel link/natural readings with
  # the actual link's honest prose. NULL link_mu => no override.
  lr_override <- if (drm_link_overrides_default(family, link_mu)) {
    drm_link_reading(link_mu)
  } else {
    NULL
  }
  # Variables appearing in an interaction term. Interaction rows carry
  # variable = "x:sex" (colon-joined component names, no contrast-level
  # suffix), so split on ":". A factor contrast whose factor is in this set
  # reads as the difference at the interacting predictor's reference (0), not
  # the marginal average -- it gets the interaction-aware template (E3 / P7).
  interacting_vars <- {
    iv <- fixed_eff$variable[fixed_eff$role == "interaction"]
    iv <- iv[!is.na(iv)]
    if (length(iv)) unique(unlist(strsplit(iv, ":", fixed = TRUE))) else character(0)
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
    # E3: a factor contrast whose factor interacts gets the interaction-aware
    # template when one exists for this (family, submodel); otherwise it keeps
    # the plain marginal reading (no regression for families without the row).
    if (identical(cr, "factor_contrast") && !is.na(r$variable) &&
        r$variable %in% interacting_vars &&
        any(tbl$family == family & tbl$submodel == r$submodel &
            tbl$coefficient_role == "factor_contrast_interaction")) {
      cr <- "factor_contrast_interaction"
    }
    template <- tbl[
      tbl$family == family &
        tbl$submodel == r$submodel &
        tbl$coefficient_role == cr,
      , drop = FALSE
    ]
    if (nrow(template) == 0L) next
    if (!is.null(lr_override) && r$submodel %in% c("mu", "mu1", "mu2")) {
      template$link_scale_reading[[1L]]    <- lr_override$link_scale_reading[[1L]]
      template$natural_scale_reading[[1L]] <- lr_override$natural_scale_reading[[1L]]
    }
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
