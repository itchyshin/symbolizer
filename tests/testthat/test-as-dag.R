test_that("as_dag errors helpfully on non-symbolized input", {
  expect_error(as_dag(list()), "has no method")
})

test_that("as_dag returns a symbolic_dag S3 list with nodes, edges, and dot", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  dag <- as_dag(sym)
  expect_s3_class(dag, "symbolic_dag")
  expect_named(dag, c("nodes", "edges", "dot"))
  expect_true(nrow(dag$nodes) >= 3L)   # at least response + mu + sigma
  expect_true(nrow(dag$edges) >= 2L)
  expect_type(dag$dot, "character")
  expect_length(dag$dot, 1L)
  expect_match(dag$dot, "^digraph", fixed = FALSE)
})

test_that("Gaussian fit's DAG includes response, mu, sigma, and the predictor", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  dag <- as_dag(sym)
  expect_true("response"  %in% dag$nodes$kind)
  expect_true("parameter" %in% dag$nodes$kind)
  expect_true("predictor" %in% dag$nodes$kind)
  expect_true(any(dag$nodes$label == "body_mass"))
  expect_true(any(dag$nodes$label == "temperature"))
  # Both mu and sigma should be parameter nodes:
  param_labels <- dag$nodes$label[dag$nodes$kind == "parameter"]
  expect_setequal(param_labels, c("μ", "σ"))
})

test_that("Gaussian fit with (1 | group) has group + random-effect nodes", {
  fit_re <- fit_drm_with_re()
  sym <- symbolize(fit_re)
  dag <- as_dag(sym)
  expect_true("group" %in% dag$nodes$kind)
  expect_true("random_effect" %in% dag$nodes$kind)
  # The group node feeds the random-effect node:
  g_id <- dag$nodes$id[dag$nodes$kind == "group"][[1L]]
  u_id <- dag$nodes$id[dag$nodes$kind == "random_effect"][[1L]]
  expect_true(any(dag$edges$from == g_id & dag$edges$to == u_id))
})

test_that("DAG DOT string is valid (one digraph block, matching braces)", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  dag <- as_dag(sym)
  expect_match(dag$dot, "^digraph", fixed = FALSE)
  expect_match(dag$dot, "}$",       fixed = FALSE)
  # Equal number of opening and closing braces:
  expect_equal(
    length(gregexpr("\\{", dag$dot)[[1L]]),
    length(gregexpr("\\}", dag$dot)[[1L]])
  )
})

test_that("print.symbolic_dag emits the dot string and a node summary", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  dag <- as_dag(sym)
  msgs <- testthat::capture_messages(print(dag))
  out <- paste(msgs, collapse = "")
  expect_match(out, "Symbolic DAG")
  expect_match(out, "Nodes")
  expect_match(out, "DOT")
})

test_that("knit_print.symbolic_dag wraps the DOT in a fenced code block", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  dag <- as_dag(sym)
  kp <- knitr::knit_print(dag)
  expect_s3_class(kp, "knit_asis")
  s <- as.character(kp)
  expect_match(s, "```dot",  fixed = TRUE)
  expect_match(s, "digraph", fixed = FALSE)
})
