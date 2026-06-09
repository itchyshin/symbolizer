# ----------------------------------------------------------------------------
# symbolize.psem
#
# Bridge for piecewiseSEM `psem()` fits. A `psem` object is a list whose
# entries are:
#   - fitted models (lm / glm / glmer / lmerMod / glmmTMB / lme, ...),
#     one per structural equation node (response variable),
#   - optional `%~~%` arcs of class "formula.cerror" carrying a string
#     like "w ~~ x" that declares a residual correlation,
#   - a `$data` slot (data.frame) at the entry named "data".
#
# symbolize.psem walks the list, delegates each fitted node to
# `symbolize.<class>()`, collects the per-node `symbolized_model` objects
# into `parts`, records `%~~%` arcs into `cov_arcs`, and returns a
# `symbolized_psem` collator.
#
# Companion methods (`as_latex`, `equations`, `assumption_table`) consume
# the collator and concatenate / row-bind their per-node counterparts so
# downstream tooling works node-by-node.
#
# Mean-only by construction: each node is a single-formula mean-structure
# fit. For distributional / multivariate structural equations use drmSEM's
# `symbolize.drm_sem` (which delegates per node to `symbolize.drmTMB`).
# ----------------------------------------------------------------------------

#' Symbolize a piecewiseSEM `psem` fit
#'
#' Walks the per-node fits inside a `piecewiseSEM::psem()` object and
#' delegates each to `symbolize.<class>()`, returning a `symbolized_psem`
#' collator that bundles the per-node `symbolized_model` objects, the
#' node names (response variables, in declared order), and any declared
#' `%~~%` residual covariance arcs.
#'
#' Each node is mean-structure only by construction. For distributional
#' (location-scale) or multivariate structural equations, use the
#' `drm_sem` path in the drmSEM package.
#'
#' @param fit A `piecewiseSEM::psem()` fit.
#' @inheritParams symbolize
#'
#' @return A `symbolized_psem` object with elements `parts` (list of
#'   per-node `symbolized_model`s, named by response variable),
#'   `node_names` (character), `cov_arcs` (character, declared `%~~%`
#'   arcs as `"a ~~ b"` strings), and `metadata`.
#' @export
symbolize.psem <- function(fit, symbols = NULL, units = NULL,
                           context = NULL, ...) {
  capability_check("piecewiseSEM", "*", "*")
  data_idx <- which(names(fit) == "data")
  parts <- list()
  node_names <- character(0)
  cov_arcs <- character(0)
  for (i in seq_along(fit)) {
    if (length(data_idx) > 0L && i %in% data_idx) next
    entry <- fit[[i]]
    if (inherits(entry, "formula.cerror")) {
      cov_arcs <- c(cov_arcs, as.character(entry))
      next
    }
    node <- psem_node_name(entry, i)
    sub <- symbolize(entry, symbols = symbols, units = units,
                     context = context, ...)
    parts[[node]] <- sub
    node_names <- c(node_names, node)
  }
  metadata <- list(
    generator = "symbolizer::symbolize.psem",
    context = context %||% "",
    package_versions = list(
      symbolizer = utils::packageVersion("symbolizer"),
      piecewiseSEM = utils::packageVersion("piecewiseSEM")
    )
  )
  structure(
    list(
      parts = parts,
      node_names = node_names,
      cov_arcs = cov_arcs,
      metadata = metadata
    ),
    # `symbolized_model_set` is the shared parent that drmSEM's
    # `symbolized_drm_sem` also carries, so one
    # `as_html_three_views.symbolized_model_set` method serves both
    # collators. The method keys nodes by `names(x$parts)`, which both
    # collators populate.
    class = c("symbolized_psem", "symbolized_model_set")
  )
}

# ---- print -----------------------------------------------------------------

#' Compact summary of a multi-node symbolized SEM
#'
#' Print method for `symbolized_model_set` — the shared parent of
#' `symbolized_psem` and drmSEM's `symbolized_drm_sem`. Lists one line per
#' node (response, family) instead of dumping the underlying list, and notes
#' any declared `%~~%` covariance arcs. drmSEM ships its own more-specific
#' `print.symbolized_drm_sem`, which takes precedence for `drm_sem` objects.
#'
#' @param x A `symbolized_model_set`.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.symbolized_model_set <- function(x, ...) {
  nodes <- names(x$parts)
  cls <- class(x)[[1L]]
  # Plain stdout (cat) so the summary is predictable and capturable; this is
  # a console print method, not cli messaging.
  cat(sprintf("<%s>: %d node%s\n", cls, length(nodes),
              if (length(nodes) == 1L) "" else "s"))
  for (nm in nodes) {
    part <- x$parts[[nm]]
    fam <- tryCatch(part$model$family, error = function(e) NULL)
    kind <- tryCatch(part$model$class, error = function(e) NULL)
    detail <- paste(c(kind, fam), collapse = ", ")
    if (nzchar(detail)) {
      cat(sprintf("  - %s (%s)\n", nm, detail))
    } else {
      cat(sprintf("  - %s\n", nm))
    }
  }
  arcs <- x$cov_arcs
  if (!is.null(arcs) && length(arcs) > 0L) {
    cat(sprintf("  %d residual covariance arc%s: %s\n",
                length(arcs), if (length(arcs) == 1L) "" else "s",
                paste(arcs, collapse = "; ")))
  }
  invisible(x)
}

# ---- companions: as_latex / equations / assumption_table -------------------

#' @export
as_latex.symbolized_psem <- function(x, notation = c("index", "matrix", "both"),
                                     env = "aligned", ...) {
  notation <- match.arg(notation)
  blocks <- vapply(
    seq_along(x$parts),
    function(i) {
      paste0("## Node: ", x$node_names[[i]], "\n",
             as_latex(x$parts[[i]], notation = notation, env = env, ...))
    },
    character(1L)
  )
  paste(blocks, collapse = "\n\n")
}

#' @export
equations.symbolized_psem <- function(x, notation = c("index", "matrix", "both"),
                                      ...) {
  notation <- match.arg(notation)
  rows <- lapply(seq_along(x$parts), function(i) {
    eq <- equations(x$parts[[i]], notation = notation, ...)
    eq$node <- x$node_names[[i]]
    eq[, c("node", setdiff(names(eq), "node")), drop = FALSE]
  })
  out <- do.call(rbind, rows)
  attr(out, "notation") <- notation
  class(out) <- c("symbolizer_equations", class(out))
  out
}

#' @export
assumption_table.symbolized_psem <- function(x, ...) {
  rows <- lapply(seq_along(x$parts), function(i) {
    tbl <- assumption_table(x$parts[[i]], ...)
    tbl <- tibble::as_tibble(tbl)
    tbl$node <- x$node_names[[i]]
    tbl[, c("node", setdiff(names(tbl), "node")), drop = FALSE]
  })
  out <- do.call(rbind, rows)
  cov_rows <- lapply(x$cov_arcs, psem_cov_arc_row, template = out)
  if (length(cov_rows) > 0L) {
    out <- do.call(rbind, c(list(out), cov_rows))
  }
  class(out) <- c("symbolizer_assumption_table", class(out))
  out
}

# ---- helpers ---------------------------------------------------------------

psem_node_name <- function(entry, i) {
  f <- tryCatch(stats::formula(entry), error = function(e) NULL)
  if (is.null(f) || length(f) < 2L) {
    return(paste0("node_", i))
  }
  lhs_vars <- all.vars(f[[2L]])
  if (length(lhs_vars) == 0L) paste0("node_", i) else lhs_vars[[1L]]
}

# Build one assumption-table row for a `%~~%` arc. Matches the column shape
# of the row-binded per-node table so rbind() lines up.
psem_cov_arc_row <- function(arc, template) {
  pieces <- strsplit(arc, "~~", fixed = TRUE)[[1L]]
  lhs <- trimws(pieces[[1L]])
  rhs <- trimws(pieces[[2L]])
  row <- template[1L, , drop = FALSE]
  row[] <- NA
  row$node <- sprintf("[cov] %s ~~ %s", lhs, rhs)
  if ("assumption" %in% names(row)) {
    row$assumption <- sprintf("Residual cov(%s, %s)", lhs, rhs)
  }
  if ("expression_latex" %in% names(row)) {
    row$expression_latex <- sprintf(
      "\\mathrm{Cov}(\\varepsilon_{%s}, \\varepsilon_{%s}) \\neq 0", lhs, rhs
    )
  }
  if ("biological_meaning" %in% names(row)) {
    # Avoid a literal "%~~%" here: the double tilde is markdown strikethrough,
    # so it is stripped when the assumption table renders through pandoc
    # (vignette / pkgdown). The label column already names the arc.
    row$biological_meaning <- sprintf(
      "Residual covariance between %s and %s, declared explicitly (a bidirected arc, not a regression).",
      lhs, rhs
    )
  }
  if ("status" %in% names(row)) row$status <- "stated"
  row
}
