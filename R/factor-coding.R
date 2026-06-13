# ----------------------------------------------------------------------------
# factor-coding.R
#
# Reference-level + contrast-scheme metadata for a symbolized_model. Built once
# during extraction from the model frame and the contrasts the fit actually
# used, then stored on `x$factor_coding`. Downstream readers (the symbol
# dictionary's `[reference]` tag, `ref_for_var()` template substitution, the
# `explain_factors()` surface, and the `group_*` emmeans layer) consult this
# instead of re-deriving the reference level from `levels(factor(x))[1]`, which
# is silently wrong for non-treatment coding (sum / Helmert / poly) and for
# treatment coding with a non-first base level.
#
# Architectural note: renderers never re-parse formulas. `build_factor_coding()`
# runs inside the extractor where the model frame and fit are already in scope,
# and the result is a plain optional tibble carried on the object.
# ----------------------------------------------------------------------------

# Build the factor-coding tibble for one fit. Returns NULL when the model has
# no factor predictors (so old objects and factor-free fits are unaffected).
#
# @param data The model frame used for fitting (factors retain their contrasts).
# @param terms_tbl The term-grammar bridge from `extract_terms()` /
#   `drm_build_terms()` -- used to find which variables are factor predictors
#   and whether their submodel carries an intercept (cell-means parameterisation).
# @param fit The original fitted object (optional). When it exposes a
#   `$contrasts` list (lm / glm), that is the authoritative record of the
#   contrasts used, including those passed via the `contrasts =` argument that
#   never reach the model-frame column.
#' @keywords internal
build_factor_coding <- function(data, terms_tbl, fit = NULL) {
  if (is.null(data) || !is.data.frame(data) ||
      is.null(terms_tbl) || nrow(terms_tbl) == 0L) {
    return(NULL)
  }

  # Candidate factor variables: factor_contrast main effects plus the factor
  # pieces of any interaction term (a factor may appear only in an interaction).
  cand <- terms_tbl$variable[terms_tbl$role == "factor_contrast"]
  cand <- cand[!is.na(cand)]
  inter <- terms_tbl$variable[terms_tbl$role == "interaction"]
  for (iv in inter[!is.na(inter)]) {
    cand <- c(cand, strsplit(iv, ":", fixed = TRUE)[[1L]])
  }
  cand <- unique(cand[nzchar(cand)])

  is_factor_col <- function(v) {
    v %in% names(data) &&
      (is.factor(data[[v]]) || is.character(data[[v]]) || is.ordered(data[[v]]))
  }
  cand <- cand[vapply(cand, is_factor_col, logical(1L))]
  if (length(cand) == 0L) return(NULL)

  specs <- lapply(cand, function(v) factor_coding_spec(v, data, terms_tbl, fit))

  tibble::tibble(
    variable             = vapply(specs, `[[`, character(1L), "variable"),
    levels               = lapply(specs, `[[`, "levels"),
    reference_level      = vapply(specs, `[[`, character(1L), "reference_level"),
    contrast_type        = vapply(specs, `[[`, character(1L), "contrast_type"),
    n_dummies            = vapply(specs, `[[`, integer(1L),   "n_dummies"),
    is_default_treatment = vapply(specs, `[[`, logical(1L),   "is_default_treatment")
  )
}

# Resolve one factor's coding into a named list (one row of factor_coding).
#' @keywords internal
factor_coding_spec <- function(v, data, terms_tbl, fit = NULL) {
  f   <- as.factor(data[[v]])
  lev <- levels(f)
  k   <- length(lev)

  # Intercept-less submodel -> the factor's columns are cell means, not
  # contrasts, regardless of the contrasts attribute.
  if (factor_is_cell_means(v, terms_tbl)) {
    return(list(
      variable = v, levels = lev, reference_level = NA_character_,
      contrast_type = "cell_means", n_dummies = k,
      is_default_treatment = FALSE
    ))
  }

  ct   <- factor_contrasts_spec(v, f, fit)
  type <- classify_contrast(ct, k)
  ref  <- reference_from_contrasts(ct, lev)
  n_dummies <- if (is.matrix(ct)) ncol(ct) else max(k - 1L, 0L)
  is_def <- identical(type, "treatment") &&
    !is.na(ref) && identical(ref, lev[[1L]])

  list(
    variable = v, levels = lev,
    reference_level = if (is.na(ref)) NA_character_ else ref,
    contrast_type = type, n_dummies = as.integer(n_dummies),
    is_default_treatment = is_def
  )
}

# A factor is read as cell means when a submodel it appears in (as a
# factor_contrast) has no intercept row -- e.g. `y ~ 0 + group`.
#' @keywords internal
factor_is_cell_means <- function(v, terms_tbl) {
  sub <- unique(terms_tbl$submodel[
    terms_tbl$role == "factor_contrast" &
      !is.na(terms_tbl$variable) & terms_tbl$variable == v
  ])
  if (length(sub) == 0L) return(FALSE)
  any(vapply(sub, function(s) {
    !any(terms_tbl$submodel == s & terms_tbl$role == "intercept")
  }, logical(1L)))
}

# The contrast matrix the fit actually used. Prefer `fit$contrasts` (lm / glm
# record it there, including contrasts passed via the `contrasts =` argument);
# fall back to the contrasts attribute carried on the model-frame factor.
#' @keywords internal
factor_contrasts_spec <- function(v, f, fit = NULL) {
  # `fit$contrasts` is a base-R list accessor; S4 fits (lme4 merMod) have no
  # `$` method and would error, so guard on isS4() and read safely. S4 fits
  # fall through to the model-frame contrasts, which retain the scheme.
  fit_contrasts <- if (!is.null(fit) && !isS4(fit)) {
    tryCatch(fit[["contrasts"]], error = function(e) NULL)
  } else {
    NULL
  }
  if (!is.null(fit_contrasts) && v %in% names(fit_contrasts)) {
    spec <- fit_contrasts[[v]]
    if (is.character(spec) && length(spec) == 1L) {
      gen <- tryCatch(get(spec, mode = "function"), error = function(e) NULL)
      if (!is.null(gen)) {
        m <- tryCatch(gen(nlevels(f)), error = function(e) NULL)
        if (!is.null(m)) return(m)
      }
    }
    if (is.matrix(spec)) return(spec)
  }
  tryCatch(stats::contrasts(f), error = function(e) NULL)
}

# Classify a contrast matrix into a scheme name. Treatment family (any base
# level, including contr.SAS's last-level base) is detected structurally so a
# relevel()'d or base = j factor is still "treatment"; the remaining named
# schemes are matched against the base-R generators.
#' @keywords internal
classify_contrast <- function(ct, k) {
  if (is.null(ct) || !is.matrix(ct)) return("custom")
  if (is_treatment_like(ct, k)) return("treatment")
  same <- function(gen) {
    g <- tryCatch(gen(k), error = function(e) NULL)
    !is.null(g) && isTRUE(all.equal(unname(ct), unname(as.matrix(g)),
                                    check.attributes = FALSE, tolerance = 1e-8))
  }
  if (same(stats::contr.sum))     return("sum")
  if (same(stats::contr.helmert)) return("helmert")
  if (same(function(n) stats::contr.poly(n))) return("poly")
  "custom"
}

# A treatment-family contrast: k-1 indicator columns, each a single 1, exactly
# one all-zero (reference) row, and the non-reference rows spanning the
# remaining levels. True for contr.treatment (any base) and contr.SAS.
#' @keywords internal
is_treatment_like <- function(ct, k) {
  if (!is.matrix(ct) || ncol(ct) != k - 1L || nrow(ct) != k) return(FALSE)
  if (!all(ct %in% c(0, 1))) return(FALSE)
  if (!all(colSums(ct) == 1)) return(FALSE)
  zero_rows <- which(rowSums(ct) == 0)
  if (length(zero_rows) != 1L) return(FALSE)
  nrow(unique(ct[-zero_rows, , drop = FALSE])) == k - 1L
}

# The reference level is the level whose contrast-matrix row is all zero. This
# is well defined for treatment / SAS coding (and any custom scheme with a
# single zero row); NA for sum / Helmert / poly, which have no reference.
#' @keywords internal
reference_from_contrasts <- function(ct, lev) {
  if (!is.matrix(ct)) return(NA_character_)
  zero_rows <- which(apply(ct, 1L, function(r) all(r == 0)))
  if (length(zero_rows) == 1L) lev[[zero_rows]] else NA_character_
}
