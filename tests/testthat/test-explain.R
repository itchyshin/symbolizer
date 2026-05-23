# Tests for the Phase 4 / A1 first-time-user surface:
#   - `explain(fit)` one-call entry
#   - `summary(sym)` plain-English walkthrough
#   - friendlier `capability_check()` error message
#
# cli writes its output to stderr / message stream by default. To capture the
# walkthrough text in a test we sink BOTH the output and message streams to
# a tempfile via withr::defer().

capture_walkthrough <- function(expr) {
  # cli writes its rich text via the `message` stream; printed values use
  # `output`. Capture both and concatenate.
  out_lines <- character(0)
  msg_lines <- character(0)
  out_lines <- utils::capture.output(
    msg_lines <- utils::capture.output(force(expr), type = "message"),
    type = "output"
  )
  c(out_lines, msg_lines)
}

# ---- explain() --------------------------------------------------------------

test_that("explain() returns a symbolized_explanation that wraps the model", {
  fit <- fit_drm_location_scale()
  ex <- explain(
    fit,
    symbols = c(body_mass = "W_i", temperature = "T_i"),
    units   = c(body_mass = "g"),
    context = "explain() test"
  )
  expect_s3_class(ex, "symbolized_explanation")
  expect_s3_class(ex$model, "symbolized_model")
})

test_that("explain() populates every reader-facing piece", {
  fit <- fit_drm_location_scale()
  ex <- explain(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  expect_false(is.null(ex$equations))
  expect_false(is.null(ex$symbols))
  expect_false(is.null(ex$assumptions))
  expect_false(is.null(ex$bridge))
  expect_false(is.null(ex$interpretation))
  expect_false(is.null(ex$notation_bridge))
  expect_s3_class(ex$equations,       "symbolizer_equations")
  expect_s3_class(ex$symbols,         "symbolizer_symbol_table")
  expect_s3_class(ex$assumptions,     "symbolizer_assumption_table")
  expect_s3_class(ex$bridge,          "symbolizer_formula_bridge")
  expect_s3_class(ex$interpretation,  "symbolizer_interpretation")
  expect_s3_class(ex$notation_bridge, "notation_bridge")
})

test_that("explain() pre-rendered pieces are non-empty for a real fit", {
  fit <- fit_drm_location_scale()
  ex <- explain(fit)
  expect_gt(nrow(ex$equations), 0L)
  expect_gt(nrow(ex$symbols), 0L)
  expect_gt(nrow(ex$assumptions), 0L)
  expect_gt(nrow(ex$bridge), 0L)
  expect_gt(nrow(ex$interpretation), 0L)
  expect_gt(nrow(ex$notation_bridge), 0L)
})

test_that("print(explain(fit)) writes non-empty output", {
  fit <- fit_drm_location_scale()
  ex <- explain(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- capture_walkthrough(print(ex))
  expect_gt(length(out), 5L)
  # Plain-English overview paragraph fronts the walkthrough.
  expect_true(any(grepl("Gaussian|gaussian", out)))
  expect_true(any(grepl("body_mass", out)))
})

# ---- summary.symbolized_model() ---------------------------------------------

test_that("summary(sym) returns invisibly and prints non-empty output", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  res <- NULL
  out <- capture_walkthrough({ res <- summary(sym) })
  expect_gt(length(out), 5L)
  # The plain-English paragraph should appear in the printed walkthrough.
  expect_true(any(grepl("This is a", out)))
  # And `body_mass` should be mentioned in plain English.
  expect_true(any(grepl("body_mass", out)))
})

test_that("summary(sym) bundles the same six reader pieces as explain()", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  res <- NULL
  capture_walkthrough({ res <- summary(sym) })
  expect_s3_class(res, "summary.symbolized_model")
  for (field in c("equations", "symbols", "assumptions", "bridge",
                  "interpretation", "notation_bridge")) {
    expect_false(is.null(res[[field]]), info = field)
  }
})

test_that("print(sym) leads with a pointer to summary() / explain()", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  out <- capture_walkthrough(print(sym))
  expect_gt(length(out), 0L)
  # Somewhere in the printed output, the pointer line should mention both
  # `summary` and `explain` (cli may wrap, so we check across all lines).
  joined <- paste(out, collapse = " ")
  expect_match(joined, "summary")
  expect_match(joined, "explain")
})

# ---- friendlier capability_check() error -----------------------------------

test_that("capability_check() lists 'Today we can read' on planned tuples", {
  err <- tryCatch(
    symbolizer:::capability_check("brmsfit", "gaussian", "mu"),
    error = identity
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(msg, "Today we can read")
  expect_match(msg, "Stable")
  expect_match(msg, "drmTMB")
})

test_that("capability_check() error names the rejected status word", {
  err <- tryCatch(
    symbolizer:::capability_check("brmsfit", "gaussian", "mu"),
    error = identity
  )
  msg <- conditionMessage(err)
  expect_match(msg, "Planned or reserved")
})
