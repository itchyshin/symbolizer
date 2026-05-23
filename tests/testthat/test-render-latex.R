test_that("equations() returns a symbolizer_equations tibble with both notations", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  eq <- equations(sym)
  expect_s3_class(eq, "symbolizer_equations")
  expect_s3_class(eq, "tbl_df")
  expect_named(eq, c("name", "kind", "submodel", "index", "matrix"))
  expect_equal(
    eq$name,
    c("distribution", "mu_linear_predictor", "sigma_linear_predictor")
  )
})

test_that("equations()$index carries the index-form LaTeX lines", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  eq <- equations(sym)
  mu_row <- eq[eq$submodel == "mu" & !is.na(eq$submodel), , drop = FALSE]
  expect_match(mu_row$index, "^\\\\mu_i = \\\\beta_\\{0\\} \\+ \\\\beta_\\{1\\} \\\\, T_i$")
  sg_row <- eq[eq$submodel == "sigma" & !is.na(eq$submodel), , drop = FALSE]
  expect_match(sg_row$index, "^\\\\log\\(\\\\sigma_i\\) = \\\\gamma_\\{0\\}")
})

test_that("equations()$matrix carries the matrix-form LaTeX lines", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  eq <- equations(sym)
  mu_row <- eq[eq$submodel == "mu" & !is.na(eq$submodel), , drop = FALSE]
  expect_match(mu_row$matrix,
               "^\\\\boldsymbol\\{\\\\mu\\} = \\\\mathbf\\{X\\} \\\\boldsymbol\\{\\\\beta\\}$")
  sg_row <- eq[eq$submodel == "sigma" & !is.na(eq$submodel), , drop = FALSE]
  expect_match(sg_row$matrix,
               "\\\\mathbf\\{Z\\} \\\\boldsymbol\\{\\\\gamma\\}")
})

test_that("equations() records the notation attribute and accepts all values", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  expect_equal(attr(equations(sym), "notation"), "index")
  expect_equal(attr(equations(sym, notation = "matrix"), "notation"), "matrix")
  expect_equal(attr(equations(sym, notation = "both"), "notation"), "both")
  expect_error(equations(sym, notation = "nope"))
})

test_that("equations.default points users at symbolize()", {
  expect_error(equations(list()), "no method")
  expect_error(equations(list()), "symbolize")
})

test_that("print.symbolizer_equations returns its input invisibly", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  eq <- equations(sym)
  msgs <- testthat::capture_messages(out <- print(eq))
  expect_identical(out, eq)
  expect_true(any(grepl("Equations", msgs)))
})

test_that("as_latex(notation = 'index') wraps lines in aligned with index form", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- as_latex(sym, notation = "index")
  expect_type(out, "character")
  expect_length(out, 1L)
  expect_match(out, "\\\\begin\\{aligned\\}", fixed = FALSE)
  expect_match(out, "\\\\end\\{aligned\\}",   fixed = FALSE)
  expect_match(out, "\\\\mu_i & = \\\\beta_\\{0\\}", fixed = FALSE)
  expect_false(grepl("\\boldsymbol{\\mu}", out, fixed = TRUE))
})

test_that("as_latex(notation = 'matrix') uses bold matrix form with lowercase response", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- as_latex(sym, notation = "matrix")
  expect_match(out, "\\mathbf{w}",                       fixed = TRUE)
  expect_match(out, "\\mathbf{X} \\boldsymbol{\\beta}",  fixed = TRUE)
  expect_match(out, "\\boldsymbol{\\mu} & =",            fixed = TRUE)
})

test_that("as_latex(notation = 'both') contains both notations and labels", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- as_latex(sym, notation = "both")
  expect_match(out, "\\text{(index notation)}",  fixed = TRUE)
  expect_match(out, "\\text{(matrix notation)}", fixed = TRUE)
  expect_match(out, "\\mu_i & = \\beta_{0}",     fixed = TRUE)
  expect_match(out, "\\mathbf{X} \\boldsymbol{\\beta}", fixed = TRUE)
})

test_that("as_latex(env = 'align*') overrides the LaTeX environment", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- as_latex(sym, notation = "index", env = "align*")
  expect_match(out, "\\begin{align*}", fixed = TRUE)
  expect_match(out, "\\end{align*}",   fixed = TRUE)
  expect_false(grepl("\\begin{aligned}", out, fixed = TRUE))
})

test_that("as_latex.default errors and points at symbolize()", {
  expect_error(as_latex(list()), "no method")
  expect_error(as_latex(list()), "symbolize")
})

test_that("as_latex validates the env argument", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  expect_error(as_latex(sym, env = ""),         "non-empty string")
  expect_error(as_latex(sym, env = c("a", "b")), "non-empty string")
})

test_that("as_latex snapshot is stable for notation = 'both'", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  expect_snapshot(cat(as_latex(sym, notation = "both")))
})
