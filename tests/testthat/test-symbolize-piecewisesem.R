# Tests for the piecewiseSEM bridge. `psem()` is a list of fitted nodes
# (lm / glm / glmer / lmerMod / glmmTMB / lme), optional `%~~%` residual
# covariance arcs (class "formula.cerror"), and a `$data` data frame.
# symbolize.psem walks the list and delegates to symbolize.<class>() per
# node, returning a `symbolized_psem`.

test_that("symbolize(psem) returns a symbolized_psem", {
  bundle <- fit_psem_lm_chain()
  sym <- symbolize(bundle$fit)
  expect_s3_class(sym, "symbolized_psem")
})

test_that("symbolized_psem carries one part per node, in declared order", {
  bundle <- fit_psem_lm_chain()
  sym <- symbolize(bundle$fit)
  expect_equal(sym$node_names, bundle$node_names)
  expect_equal(length(sym$parts), length(bundle$node_names))
  for (i in seq_along(sym$parts)) {
    expect_s3_class(sym$parts[[i]], "symbolized_model")
  }
})

test_that("symbolized_psem records the generator in metadata", {
  bundle <- fit_psem_lm_chain()
  sym <- symbolize(bundle$fit)
  expect_equal(sym$metadata$generator, "symbolizer::symbolize.psem")
})

test_that("as_latex.symbolized_psem stamps every node header", {
  bundle <- fit_psem_lm_chain()
  sym <- symbolize(bundle$fit)
  tex <- as_latex(sym)
  expect_type(tex, "character")
  expect_length(tex, 1L)
  for (n in bundle$node_names) {
    expect_match(tex, paste0("Node: ", n), fixed = TRUE)
  }
})

test_that("equations.symbolized_psem row-binds nodes with a leading node column", {
  bundle <- fit_psem_lm_chain()
  sym <- symbolize(bundle$fit)
  eq <- equations(sym)
  expect_s3_class(eq, "data.frame")
  expect_true("node" %in% names(eq))
  expect_equal(names(eq)[[1L]], "node")
  expect_setequal(unique(eq$node), bundle$node_names)
})

test_that("assumption_table.symbolized_psem row-binds nodes with a leading node column", {
  bundle <- fit_psem_lm_chain()
  sym <- symbolize(bundle$fit)
  at <- assumption_table(sym)
  expect_s3_class(at, "data.frame")
  expect_true("node" %in% names(at))
  expect_equal(names(at)[[1L]], "node")
  # Every model node should appear at least once.
  for (n in bundle$node_names) {
    expect_true(any(at$node == n), info = paste("missing node:", n))
  }
})

test_that("%~~% arcs surface as Residual cov rows in assumption_table only", {
  bundle <- fit_psem_lm_with_cor()
  sym <- symbolize(bundle$fit)
  # The arc is stored on the symbolized_psem itself.
  expect_true(length(sym$cov_arcs) >= 1L)
  # Surface in assumption_table.
  at <- assumption_table(sym)
  cov_rows <- at[grepl("^Residual cov", at$assumption), , drop = FALSE]
  expect_true(nrow(cov_rows) >= 1L)
  expect_match(cov_rows$assumption[[1L]], "w", fixed = TRUE)
  expect_match(cov_rows$assumption[[1L]], "x", fixed = TRUE)
  # NOT surfaced as equations() rows (bidirected, not regressions).
  eq <- equations(sym)
  expect_false(any(grepl("Residual cov", eq$node)))
})

test_that("piecewiseSEM/*/* is registered with lives_in = symbolizer", {
  caps <- symbolizer_capabilities()
  expect_true("lives_in" %in% names(caps))
  row <- caps[caps$class == "piecewiseSEM" &
                caps$family == "*" &
                caps$component == "*", , drop = FALSE]
  expect_equal(nrow(row), 1L)
  expect_equal(row$status, "Stable")
  expect_equal(row$lives_in, "symbolizer")
})

test_that("drm_sem/*/* is registered with lives_in = drmSEM", {
  caps <- symbolizer_capabilities()
  row <- caps[caps$class == "drm_sem" &
                caps$family == "*" &
                caps$component == "*", , drop = FALSE]
  expect_equal(nrow(row), 1L)
  expect_equal(row$status, "Stable")
  expect_equal(row$lives_in, "drmSEM")
})

# ---- HTML view (shared symbolized_model_set parent) ------------------------
# symbolize.psem tags its output `symbolized_model_set` so a single
# `as_html_three_views.symbolized_model_set` method serves both the psem
# collator and drmSEM's `symbolized_drm_sem` (which already carries that
# parent class). The method stacks the per-node three-views widget under a
# `<h2>Node: <name></h2>` header. Both collators key their nodes by name on
# `x$parts`, so the method reads `names(x$parts)` and never needs to know
# which collator it received.

test_that("symbolize(psem) output carries the symbolized_model_set parent", {
  bundle <- fit_psem_lm_chain()
  sym <- symbolize(bundle$fit)
  expect_s3_class(sym, "symbolized_model_set")
})

test_that("as_html_three_views(symbolized_psem) returns one HTML string", {
  bundle <- fit_psem_lm_chain()
  sym <- symbolize(bundle$fit)
  html <- as_html_three_views(sym)
  expect_type(html, "character")
  expect_length(html, 1L)
})

test_that("as_html_three_views(symbolized_psem) stamps a header per node", {
  bundle <- fit_psem_lm_chain()
  sym <- symbolize(bundle$fit)
  html <- as_html_three_views(sym)
  for (n in bundle$node_names) {
    expect_match(html, paste0("Node: ", n), fixed = TRUE)
  }
})

test_that("as_html_three_views(symbolized_psem) embeds one widget per node", {
  bundle <- fit_psem_lm_chain()
  sym <- symbolize(bundle$fit)
  html <- as_html_three_views(sym)
  # Each single-model widget emits exactly one role="tablist"; a two-node
  # collator must therefore carry two.
  n_tablists <- length(gregexpr("role=\"tablist\"", html, fixed = TRUE)[[1L]])
  expect_equal(n_tablists, length(bundle$node_names))
})

test_that("as_html_three_views(symbolized_psem, standalone = TRUE) is a full page", {
  bundle <- fit_psem_lm_chain()
  sym <- symbolize(bundle$fit)
  html <- as_html_three_views(sym, standalone = TRUE)
  expect_match(html, "<!DOCTYPE html>", fixed = TRUE)
  expect_match(html, "MathJax", fixed = TRUE)
})

test_that("print(symbolized_psem) is a compact summary, not a raw list dump", {
  bundle <- fit_psem_lm_chain()
  sym <- symbolize(bundle$fit)
  out <- paste(capture.output(print(sym)), collapse = "\n")
  # Names every node, labels the object, and is short (not a $parts dump).
  for (n in bundle$node_names) {
    expect_match(out, n, fixed = TRUE)
  }
  expect_match(out, "symbolized_psem", fixed = TRUE)
  expect_false(grepl("$parts", out, fixed = TRUE))
})

test_that("print(symbolized_psem) reports a declared covariance arc", {
  bundle <- fit_psem_lm_with_cor()
  sym <- symbolize(bundle$fit)
  out <- paste(capture.output(print(sym)), collapse = "\n")
  expect_match(out, "covariance", ignore.case = TRUE)
  expect_invisible(print(sym))
})
