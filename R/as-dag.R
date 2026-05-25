#' Model diagram for a symbolized model
#'
#' @description
#' Returns a structural DAG of the fitted model: nodes for the response,
#' each predictor, each parameter (mu, sigma, ...), and any random-effect
#' grouping variables; edges connecting predictors to the parameters they
#' enter, parameters to the response, and groups to their random-effect
#' contribution. The returned object is an S3 list with `nodes` and
#' `edges` tibbles plus a generated DOT-language string.
#'
#' Rendering live needs a downstream tool that consumes DOT - the
#' `DiagrammeR` package (which symbolizer does NOT require) is one
#' option; pasting `as_dag(sym)$dot` into <https://dreampuf.github.io/GraphvizOnline/>
#' is another. The S3 print method shows the DOT string and a brief
#' summary; `as_dag(sym)$nodes` and `$edges` are the raw tables.
#'
#' This is a structural surface - it visualises *how* the symbolic
#' object connects predictors, parameters, and the response. It does
#' not show coefficient values; for those see
#' [parameter_interpretation()].
#'
#' @param x A [`symbolized_model`][new_symbolized_model].
#' @param ... Reserved for future use.
#'
#' @return A list classed `c("symbolic_dag", "list")` with three
#'   slots: `nodes` (tibble), `edges` (tibble), `dot` (single
#'   character string with the GraphViz / DOT representation).
#'
#' @export
as_dag <- function(x, ...) {
  UseMethod("as_dag")
}

#' @export
as_dag.default <- function(x, ...) {
  cli::cli_abort(c(
    "{.fn as_dag} has no method for {.cls {class(x)[1L]}}.",
    i = "Pass the output of {.fn symbolize}."
  ))
}

#' @export
as_dag.symbolized_model <- function(x, ...) {
  nodes <- build_dag_nodes(x)
  edges <- build_dag_edges(x, nodes)
  out <- list(
    nodes   = nodes,
    edges   = edges,
    dot     = build_dag_dot(nodes, edges, sym = x),
    mermaid = build_dag_mermaid(nodes, edges, sym = x),
    tikz    = build_dag_tikz(nodes, edges, sym = x)
  )
  class(out) <- c("symbolic_dag", "list")
  out
}

# -- internals ---------------------------------------------------------------

# Collect every node we want on the diagram. Each node carries: id (used
# inside the DOT string), label (shown to the reader), kind (response,
# parameter, predictor, group, random_effect), and optional `submodel`
# pointer (which parameter does this predictor feed?).
build_dag_nodes <- function(x) {
  rows <- list()

  # Response node(s).
  resp <- x$model$responses %||% x$model$response
  for (r in resp) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      id    = paste0("y_", dag_slug(r)),
      label = r,
      kind  = "response",
      submodel = NA_character_
    )
  }

  # Parameter nodes (one per submodel - mu, sigma, nu, rho12, ...).
  for (sm in unique(x$submodels$parameter)) {
    rows[[length(rows) + 1L]] <- tibble::tibble(
      id    = paste0("p_", sm),
      label = dag_param_label(sm),
      kind  = "parameter",
      submodel = sm
    )
  }

  # Predictor nodes - one per unique variable appearing in terms$variable.
  if (!is.null(x$terms) && nrow(x$terms) > 0L) {
    preds <- unique(x$terms$variable[!is.na(x$terms$variable) &
                                     nzchar(x$terms$variable) &
                                     x$terms$role != "intercept"])
    for (p in preds) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        id    = paste0("x_", dag_slug(p)),
        label = p,
        kind  = "predictor",
        submodel = NA_character_
      )
    }
  }

  # Random-effect nodes - one per group variable, one per random component.
  if (!is.null(x$random_effects) && nrow(x$random_effects) > 0L) {
    re <- x$random_effects
    groups <- unique(re$group_var)
    for (g in groups) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        id    = paste0("g_", dag_slug(g)),
        label = g,
        kind  = "group",
        submodel = NA_character_
      )
    }
    if ("component" %in% names(re)) {
      for (i in seq_len(nrow(re))) {
        u_id <- sprintf("u_%s_%s", dag_slug(re$group_var[[i]]),
                        dag_slug(re$component[[i]]))
        rows[[length(rows) + 1L]] <- tibble::tibble(
          id    = u_id,
          label = sprintf("u_%s,%s", re$group_var[[i]],
                          if (re$component[[i]] == "(Intercept)") "0"
                          else re$component[[i]]),
          kind  = "random_effect",
          submodel = re$submodel[[i]]
        )
      }
    }
  }

  do.call(rbind, rows)
}

build_dag_edges <- function(x, nodes) {
  rows <- list()
  add <- function(from, to, kind) {
    rows[[length(rows) + 1L]] <<- tibble::tibble(
      from = from, to = to, kind = kind
    )
  }

  # parameter -> response (every parameter feeds the response distribution)
  resp_ids <- nodes$id[nodes$kind == "response"]
  for (param_id in nodes$id[nodes$kind == "parameter"]) {
    for (r in resp_ids) add(param_id, r, "distribution")
  }

  # predictor -> parameter (one edge per (variable, submodel) pair the
  # variable appears in)
  if (!is.null(x$terms) && nrow(x$terms) > 0L) {
    trms <- x$terms
    for (i in seq_len(nrow(trms))) {
      if (is.na(trms$variable[[i]]) || !nzchar(trms$variable[[i]])) next
      if (trms$role[[i]] == "intercept") next
      pred_id <- paste0("x_", dag_slug(trms$variable[[i]]))
      sm  <- trms$submodel[[i]]
      par_id <- paste0("p_", sm)
      if (pred_id %in% nodes$id && par_id %in% nodes$id) {
        add(pred_id, par_id, "linear_predictor")
      }
    }
  }

  # group -> random_effect (each group has one or more random components)
  # random_effect -> parameter (the random component contributes to its parameter)
  if (!is.null(x$random_effects) && nrow(x$random_effects) > 0L &&
      "component" %in% names(x$random_effects)) {
    re <- x$random_effects
    for (i in seq_len(nrow(re))) {
      u_id <- sprintf("u_%s_%s", dag_slug(re$group_var[[i]]),
                      dag_slug(re$component[[i]]))
      g_id <- paste0("g_", dag_slug(re$group_var[[i]]))
      par_id <- paste0("p_", re$submodel[[i]])
      add(g_id, u_id, "groups")
      add(u_id, par_id, "random_contribution")
    }
  }

  do.call(rbind, rows)
}

# Assemble the DOT string. Subgraphs by node kind so a layout engine can
# place predictors on the left, parameters in the middle, response on
# the right.
build_dag_dot <- function(nodes, edges, sym) {
  shape_for <- function(kind) {
    switch(
      kind,
      response      = "doublecircle",
      parameter     = "ellipse",
      predictor     = "box",
      group         = "house",
      random_effect = "circle",
      "ellipse"
    )
  }
  fill_for <- function(kind) {
    switch(
      kind,
      response      = "#fde0dc",
      parameter     = "#fef0d9",
      predictor     = "#e0f3db",
      group         = "#dadaeb",
      random_effect = "#fdbb84",
      "#ffffff"
    )
  }
  node_lines <- vapply(seq_len(nrow(nodes)), function(i) {
    sprintf(
      '  %s [label="%s", shape=%s, style=filled, fillcolor="%s"];',
      nodes$id[[i]], nodes$label[[i]],
      shape_for(nodes$kind[[i]]), fill_for(nodes$kind[[i]])
    )
  }, character(1L))
  style_for_edge <- function(kind) {
    switch(
      kind,
      distribution        = "[style=bold, color=\"#a0282b\"]",
      linear_predictor    = "[style=solid]",
      groups              = "[style=dashed, color=\"#666666\"]",
      random_contribution = "[style=dashed]",
      ""
    )
  }
  edge_lines <- if (!is.null(edges) && nrow(edges) > 0L) {
    vapply(seq_len(nrow(edges)), function(i) {
      sprintf("  %s -> %s %s;", edges$from[[i]], edges$to[[i]],
              style_for_edge(edges$kind[[i]]))
    }, character(1L))
  } else character(0L)
  paste(
    c(
      sprintf("digraph symbolic_model_%s {",
              dag_slug(sym$model$class %||% "fit")),
      "  rankdir = LR;",
      "  node  [fontname = \"Helvetica\"];",
      "  edge  [fontname = \"Helvetica\"];",
      "",
      node_lines,
      "",
      edge_lines,
      "}"
    ),
    collapse = "\n"
  )
}

# Assemble the Mermaid-flowchart string. Same structural DAG as the
# DOT renderer; different syntax. Each node id is the symbolizer id;
# shapes are encoded via Mermaid's bracket conventions:
#   response       (( double-circle ))
#   parameter      (( single ))
#   predictor      [ rect ]
#   group          {{ hex }}
#   random_effect  (( oval ))
build_dag_mermaid <- function(nodes, edges, sym) {
  node_shape <- function(kind, id, label) {
    open_close <- switch(
      kind,
      response      = c("(((", ")))"),
      parameter     = c("((",  "))"),
      predictor     = c("[",   "]"),
      group         = c("{{",  "}}"),
      random_effect = c("(",   ")"),
      c("[",  "]")
    )
    sprintf("%s%s\"%s\"%s", id, open_close[[1L]], label, open_close[[2L]])
  }
  node_lines <- vapply(seq_len(nrow(nodes)), function(i) {
    node_shape(nodes$kind[[i]], nodes$id[[i]], nodes$label[[i]])
  }, character(1L))
  edge_style <- function(kind) {
    switch(
      kind,
      distribution        = "==>",          # bold
      linear_predictor    = "-->",          # solid
      groups              = "-.->",         # dashed
      random_contribution = "-.->",         # dashed
      "-->"
    )
  }
  edge_lines <- if (!is.null(edges) && nrow(edges) > 0L) {
    vapply(seq_len(nrow(edges)), function(i) {
      sprintf("  %s %s %s", edges$from[[i]], edge_style(edges$kind[[i]]), edges$to[[i]])
    }, character(1L))
  } else character(0L)
  paste(
    c("flowchart LR",
      paste0("  ", node_lines),
      edge_lines),
    collapse = "\n"
  )
}

# Assemble the TikZ string. Wraps the DAG in tikzpicture environment
# with positioning, basic shapes, and color fills matching the DOT
# / Mermaid versions. Renderable inside a LaTeX document that loads
# \usepackage{tikz} and \usetikzlibrary{positioning,shapes.geometric}.
build_dag_tikz <- function(nodes, edges, sym) {
  shape_for <- function(kind) {
    switch(
      kind,
      response      = "double circle",
      parameter     = "ellipse",
      predictor     = "rectangle",
      group         = "regular polygon, regular polygon sides=5",
      random_effect = "circle",
      "ellipse"
    )
  }
  fill_for <- function(kind) {
    switch(
      kind,
      response      = "red!20",
      parameter     = "yellow!20",
      predictor     = "green!20",
      group         = "blue!20",
      random_effect = "orange!30",
      "white"
    )
  }
  node_lines <- vapply(seq_len(nrow(nodes)), function(i) {
    sprintf(
      "  \\node[draw, %s, fill=%s] (%s) {%s};",
      shape_for(nodes$kind[[i]]),
      fill_for(nodes$kind[[i]]),
      nodes$id[[i]],
      escape_tikz(nodes$label[[i]])
    )
  }, character(1L))
  edge_style <- function(kind) {
    switch(
      kind,
      distribution        = "[ultra thick, ->, color=red!60!black]",
      linear_predictor    = "[->]",
      groups              = "[->, dashed, color=gray]",
      random_contribution = "[->, dashed]",
      "[->]"
    )
  }
  edge_lines <- if (!is.null(edges) && nrow(edges) > 0L) {
    vapply(seq_len(nrow(edges)), function(i) {
      sprintf("  \\draw%s (%s) -- (%s);",
              edge_style(edges$kind[[i]]),
              edges$from[[i]], edges$to[[i]])
    }, character(1L))
  } else character(0L)
  paste(
    c(
      "% requires: \\usepackage{tikz}",
      "% \\usetikzlibrary{positioning,shapes.geometric}",
      "\\begin{tikzpicture}[node distance=2cm, auto]",
      node_lines,
      edge_lines,
      "\\end{tikzpicture}"
    ),
    collapse = "\n"
  )
}

# Escape characters that are special inside TikZ node labels.
escape_tikz <- function(s) {
  s <- gsub("\\\\", "\\\\textbackslash{}", s)
  s <- gsub("([&%$#_{}])", "\\\\\\1", s)
  s
}

# Sanitise a label into a node id (letters, digits, underscores).
dag_slug <- function(s) {
  out <- gsub("[^A-Za-z0-9_]+", "_", s)
  out <- sub("^_+", "", out)
  out <- sub("_+$", "", out)
  if (!nzchar(out)) out <- "node"
  out
}

# Pretty label for a parameter dpar. Greek letters escaped to \uXXXX so
# the R source stays ASCII (R CMD check WARNING otherwise).
dag_param_label <- function(dpar) {
  switch(
    dpar,
    mu     = "\u03BC",            # mu
    sigma  = "\u03C3",            # sigma
    nu     = "\u03BD",            # nu
    rho12  = "\u03C1_12",         # rho_12
    mu1    = "\u03BC_1",          # mu_1
    mu2    = "\u03BC_2",          # mu_2
    sigma1 = "\u03C3_1",          # sigma_1
    sigma2 = "\u03C3_2",          # sigma_2
    zi     = "\u03C0_zi",         # pi_zi
    hu     = "\u03C0_hu",         # pi_hu
    dpar
  )
}

# -- print / knit_print ------------------------------------------------------

#' @export
print.symbolic_dag <- function(x, ...) {
  cli::cli_h2("Symbolic DAG")
  cli::cli_text("{nrow(x$nodes)} node{?s}, {nrow(x$edges)} edge{?s}.")
  cli::cli_h3("Nodes")
  for (k in unique(x$nodes$kind)) {
    labels <- x$nodes$label[x$nodes$kind == k]
    cli::cli_text("{.strong {k}}: {paste(labels, collapse = ', ')}")
  }
  cli::cli_h3("DOT")
  cli::cli_text(
    "{.emph Copy the dot string into GraphvizOnline or pipe through DiagrammeR::grViz to render.}"
  )
  cli::cli_verbatim(x$dot)
  invisible(x)
}

#' @exportS3Method knitr::knit_print
knit_print.symbolic_dag <- function(x, ...) {
  if (!requireNamespace("knitr", quietly = TRUE)) return(invisible(x))
  # Fenced DOT block - many static-site engines render it; otherwise
  # the user can copy-paste into GraphvizOnline.
  out <- paste(
    c("",
      "```dot",
      x$dot,
      "```",
      ""),
    collapse = "\n"
  )
  knitr::asis_output(out)
}
