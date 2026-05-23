make_sym <- function() {
  fit <- fit_drm_location_scale()
  symbolize(
    fit,
    symbols = c(body_mass = "W_i", temperature = "T_i"),
    units   = c(body_mass = "g", temperature = "C")
  )
}

# ---- symbol_table -----------------------------------------------------------

test_that("symbol_table() returns both notations by default", {
  sym <- make_sym()
  st <- symbol_table(sym)
  expect_s3_class(st, "symbolizer_symbol_table")
  expect_s3_class(st, "tbl_df")
  expect_true(all(c("symbol", "symbol_matrix") %in% names(st)))
  expect_true(all(c("variable", "units", "role",
                    "dimension", "dimension_concrete", "description")
                  %in% names(st)))
})

test_that("symbol_table(notation = 'index') drops symbol_matrix", {
  sym <- make_sym()
  st <- symbol_table(sym, notation = "index")
  expect_true("symbol"        %in% names(st))
  expect_false("symbol_matrix" %in% names(st))
  expect_equal(nrow(st), nrow(sym$symbol_dictionary))
})

test_that("symbol_table(notation = 'matrix') keeps matrix-form rows only", {
  sym <- make_sym()
  st <- symbol_table(sym, notation = "matrix")
  expect_true("symbol_matrix"  %in% names(st))
  expect_false("symbol"        %in% names(st))
  expect_true("\\mathbf{w}" %in% st$symbol_matrix)
  expect_true("\\mathbf{X}" %in% st$symbol_matrix)
  expect_true("\\mathbf{Z}" %in% st$symbol_matrix)
  # Predictors without a matrix form are dropped.
  expect_false("temperature" %in% st$variable)
  # ...but body_mass (response) has a matrix form and is kept.
  expect_true("body_mass" %in% st$variable)
})

test_that("symbol_table() exposes concrete dimensions for the response", {
  sym <- make_sym()
  st <- symbol_table(sym)
  resp <- st[st$role == "response", , drop = FALSE]
  expect_equal(resp$dimension_concrete, "\\mathbb{R}^{80}")
  expect_equal(resp$dimension,          "\\mathbb{R}^n")
})

test_that("symbol_table.default points at symbolize()", {
  expect_error(symbol_table(list()),               "symbolize")
  expect_error(symbol_table(data.frame(x = 1)),    "symbolize")
})

# ---- assumption_table -------------------------------------------------------

test_that("assumption_table() returns the expected rows", {
  sym <- make_sym()
  at <- assumption_table(sym)
  expect_s3_class(at, "symbolizer_assumption_table")
  expect_s3_class(at, "tbl_df")
  expect_setequal(
    at$assumption,
    c("conditional_distribution", "linear_predictor",
      "independence", "positivity", "no_missing_at_random")
  )
  # Linear predictor appears for both mu and sigma.
  lp <- at[at$assumption == "linear_predictor", , drop = FALSE]
  expect_setequal(lp$submodel, c("mu", "sigma"))
})

test_that("assumption_table() substitutes the response symbol", {
  sym <- make_sym()
  at <- assumption_table(sym)
  cd <- at$expression_latex[at$assumption == "conditional_distribution"]
  expect_match(cd, "W_i \\\\mid")
})

test_that("assumption_table.default points at symbolize()", {
  expect_error(assumption_table(list()), "symbolize")
})

# ---- formula_bridge ---------------------------------------------------------

test_that("formula_bridge() returns both math columns by default", {
  sym <- make_sym()
  br <- formula_bridge(sym)
  expect_s3_class(br, "symbolizer_formula_bridge")
  expect_s3_class(br, "tbl_df")
  expect_equal(nrow(br), 2L)
  expect_setequal(br$submodel, c("mu", "sigma"))
  expect_true(all(c("mathematics", "mathematics_matrix") %in% names(br)))
})

test_that("formula_bridge(notation = 'index') drops mathematics_matrix", {
  sym <- make_sym()
  br <- formula_bridge(sym, notation = "index")
  expect_true("mathematics"        %in% names(br))
  expect_false("mathematics_matrix" %in% names(br))
})

test_that("formula_bridge(notation = 'matrix') drops index mathematics", {
  sym <- make_sym()
  br <- formula_bridge(sym, notation = "matrix")
  expect_true("mathematics_matrix" %in% names(br))
  expect_false("mathematics"        %in% names(br))
  mu_row <- br[br$submodel == "mu", , drop = FALSE]
  expect_match(
    mu_row$mathematics_matrix,
    "\\\\boldsymbol\\{\\\\mu\\} = \\\\mathbf\\{X\\}\\s*\\\\boldsymbol\\{\\\\beta\\}"
  )
})

test_that("formula_bridge.default points at symbolize()", {
  expect_error(formula_bridge(list()), "symbolize")
})

# ---- snapshot prints --------------------------------------------------------

test_that("symbol_table print method is stable", {
  sym <- make_sym()
  expect_snapshot(print(symbol_table(sym)))
})

test_that("assumption_table print method is stable", {
  sym <- make_sym()
  expect_snapshot(print(assumption_table(sym)))
})

test_that("formula_bridge print method is stable", {
  sym <- make_sym()
  expect_snapshot(print(formula_bridge(sym)))
})
