#' Build the term-grammar / model-matrix bridge for one submodel
#'
#' @description
#' `extract_terms()` is the prerequisite for every renderer. It bridges
#' R formula terms <-> model-matrix columns <-> biological symbols. Without
#' this layer, equations silently break on factor contrasts, interactions,
#' offsets, and transformations.
#'
#' For each model-matrix column (plus offsets), it returns one row giving the
#' term label, source variable, role classification, factor contrast level,
#' transformation applied, biological symbol, coefficient symbol, and a
#' ready-to-splice LaTeX fragment.
#'
#' Supported roles in v0.1: `intercept`, `predictor`, `factor_contrast`,
#' `interaction`, `transformation`, `offset`. Random-effect terms are detected
#' upstream and removed before `extract_terms()` runs in v0.1.
#'
#' @param formula One-sided or two-sided formula for the submodel.
#' @param data Data frame used for fitting.
#' @param submodel Character. Name of the submodel, e.g. `"mu"`, `"sigma"`.
#' @param symbols Named character vector mapping variable names to LaTeX
#'   symbols. Missing variables receive auto-generated symbols.
#' @param coefficient_family Character. Coefficient symbol family used in
#'   `coefficient_symbol`, e.g. `"beta"` for mu, `"gamma"` for log sigma.
#'
#' @return A tibble with columns: `submodel`, `term_label`, `variable`, `role`,
#'   `contrast_level`, `transform`, `symbol`, `coefficient_symbol`,
#'   `latex_term`.
#' @keywords internal
extract_terms <- function(formula, data, submodel,
                          symbols = NULL,
                          coefficient_family = "beta") {
  if (!inherits(formula, "formula")) {
    cli::cli_abort("{.arg formula} must be a formula.")
  }
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.")
  }

  # Strip LHS to a one-sided formula
  rhs_formula <- if (length(formula) == 3L) {
    out <- formula[c(1L, 3L)]
    environment(out) <- environment(formula)
    out
  } else {
    formula
  }

  tt <- stats::terms(rhs_formula, data = data)
  mf <- stats::model.frame(tt, data = data)
  mm <- stats::model.matrix(tt, mf)

  col_names  <- colnames(mm)
  assign     <- attr(mm, "assign")
  term_labels <- attr(tt, "term.labels")

  classes <- vapply(mf, function(col) class(col)[1L], character(1L))
  factor_vars <- names(classes)[classes %in% c("factor", "ordered", "character")]

  offset_idx <- attr(tt, "offset")
  offset_terms <- character(0L)
  if (!is.null(offset_idx) && length(offset_idx) > 0L) {
    variables_attr <- attr(tt, "variables")
    offset_terms <- vapply(offset_idx, function(i) {
      deparse1(variables_attr[[i + 1L]])
    }, character(1L))
  }

  lookup_symbol <- function(var) {
    if (is.null(var) || is.na(var) || !nzchar(var)) return(NA_character_)
    if (!is.null(symbols) && var %in% names(symbols)) {
      return(unname(symbols[[var]]))
    }
    paste0(var, "_i")
  }

  classify_term <- function(term_label, col_name) {
    if (col_name == "(Intercept)") {
      return(list(role = "intercept", variable = NA_character_,
                  contrast_level = NA_character_, transform = ""))
    }
    pieces <- strsplit(term_label, ":", fixed = TRUE)[[1L]]
    has_interaction <- length(pieces) > 1L
    piece_info <- lapply(pieces, function(p) {
      m <- regmatches(p, regexec("^([A-Za-z_.][A-Za-z0-9_.]*)\\((.+)\\)$", p))[[1L]]
      if (length(m) == 3L) list(fn = m[2L], inner = m[3L])
      else                list(fn = "",   inner = p)
    })
    vars <- vapply(piece_info, `[[`, character(1L), "inner")
    fns  <- vapply(piece_info, `[[`, character(1L), "fn")

    col_pieces <- strsplit(col_name, ":", fixed = TRUE)[[1L]]
    levels_ <- character(length(pieces))
    for (k in seq_along(pieces)) {
      var_k <- vars[k]
      if (var_k %in% factor_vars && nchar(col_pieces[k]) > nchar(pieces[k])) {
        levels_[k] <- substring(col_pieces[k], nchar(pieces[k]) + 1L)
      }
    }

    if (has_interaction) {
      role <- "interaction"
      variable <- paste(vars, collapse = ":")
      contrast_level <- if (any(nzchar(levels_))) {
        paste(ifelse(nzchar(levels_), levels_, "-"), collapse = ":")
      } else NA_character_
      transform <- if (any(nzchar(fns))) paste(fns, collapse = ":") else ""
    } else if (nzchar(fns[1L])) {
      role <- "transformation"
      variable <- vars[1L]
      contrast_level <- NA_character_
      transform <- fns[1L]
    } else if (vars[1L] %in% factor_vars) {
      role <- "factor_contrast"
      variable <- vars[1L]
      contrast_level <- if (nzchar(levels_[1L])) levels_[1L] else NA_character_
      transform <- ""
    } else {
      role <- "predictor"
      variable <- vars[1L]
      contrast_level <- NA_character_
      transform <- ""
    }
    list(role = role, variable = variable,
         contrast_level = contrast_level, transform = transform)
  }

  build_latex <- function(role, variable, contrast_level, transform,
                          symbol, coef_symbol) {
    if (role == "intercept") return(coef_symbol)
    if (role == "factor_contrast") {
      return(sprintf("%s \\, [%s = \\mathrm{%s}]",
                     coef_symbol, variable, contrast_level))
    }
    if (role == "interaction") {
      vars <- strsplit(variable, ":", fixed = TRUE)[[1L]]
      var_syms <- vapply(vars, lookup_symbol, character(1L))
      return(paste0(coef_symbol, " \\, ",
                    paste(var_syms, collapse = " \\, ")))
    }
    if (role == "transformation") {
      inner_sym <- lookup_symbol(variable)
      return(sprintf("%s \\, \\mathrm{%s}(%s)",
                     coef_symbol, transform, inner_sym))
    }
    paste0(coef_symbol, " \\, ", symbol)
  }

  n_rows <- length(col_names) + length(offset_terms)
  rows <- vector("list", n_rows)

  # Coefficient family may carry its own subscript for multi-response models,
  # e.g. "beta_{1}" for the first response of biv_gaussian. Detect that and
  # merge into a single subscript ("\\beta_{1,k}") rather than nesting braces.
  cf_match <- regmatches(coefficient_family,
                         regexec("^([A-Za-z]+)(_\\{([^}]+)\\})?$",
                                 coefficient_family))[[1L]]
  cf_root <- if (length(cf_match) >= 2L && nzchar(cf_match[[2L]])) cf_match[[2L]] else coefficient_family
  cf_inner <- if (length(cf_match) == 4L && nzchar(cf_match[[4L]])) cf_match[[4L]] else ""

  for (ci in seq_along(col_names)) {
    col_name <- col_names[ci]
    term_idx <- assign[ci]
    term_label <- if (term_idx == 0L) "(Intercept)" else term_labels[term_idx]
    info <- classify_term(term_label, col_name)
    coef_idx <- ci - 1L
    coef_symbol <- if (nzchar(cf_inner)) {
      sprintf("\\%s_{%s,%d}", cf_root, cf_inner, coef_idx)
    } else {
      sprintf("\\%s_{%d}", cf_root, coef_idx)
    }
    symbol <- if (is.na(info$variable)) NA_character_ else lookup_symbol(info$variable)
    latex_term <- build_latex(
      info$role, info$variable, info$contrast_level, info$transform,
      symbol, coef_symbol
    )
    rows[[ci]] <- tibble::tibble(
      submodel = submodel,
      term_label = term_label,
      variable = info$variable,
      role = info$role,
      contrast_level = info$contrast_level,
      transform = info$transform,
      symbol = symbol,
      coefficient_symbol = coef_symbol,
      latex_term = latex_term
    )
  }

  for (oi in seq_along(offset_terms)) {
    ot <- offset_terms[oi]
    inner_match <- regmatches(ot, regexec("^offset\\((.+)\\)$", ot))[[1L]]
    inner_expr <- if (length(inner_match) == 2L) inner_match[2L] else ot
    fn_match <- regmatches(inner_expr,
      regexec("^([A-Za-z_.][A-Za-z0-9_.]*)\\((.+)\\)$", inner_expr))[[1L]]
    if (length(fn_match) == 3L) {
      fn <- fn_match[2L]; var <- fn_match[3L]
    } else {
      fn <- ""; var <- inner_expr
    }
    var_sym <- lookup_symbol(var)
    latex_term <- if (nzchar(fn)) {
      sprintf("\\mathrm{%s}(%s)", fn, var_sym)
    } else var_sym
    rows[[length(col_names) + oi]] <- tibble::tibble(
      submodel = submodel,
      term_label = ot,
      variable = var,
      role = "offset",
      contrast_level = NA_character_,
      transform = fn,
      symbol = var_sym,
      coefficient_symbol = NA_character_,
      latex_term = latex_term
    )
  }

  out <- if (n_rows == 0L) {
    tibble::tibble(
      submodel = character(0L),
      term_label = character(0L),
      variable = character(0L),
      role = character(0L),
      contrast_level = character(0L),
      transform = character(0L),
      symbol = character(0L),
      coefficient_symbol = character(0L),
      latex_term = character(0L)
    )
  } else {
    do.call(rbind, rows)
  }
  out
}
