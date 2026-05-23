# Tests for the knit_print methods in R/knit-print.R.
#
# Each method must (i) return a `knit_asis` object, (ii) emit a markdown
# pipe table or LaTeX block, and (iii) wrap anything that looks like LaTeX
# in `$...$` via the internal sym_dollar() helper.

make_kp_sym <- function() {
  fit <- fit_drm_location_scale()
  symbolize(
    fit,
    symbols = c(body_mass = "W_i", temperature = "T_i"),
    units   = c(body_mass = "g", temperature = "C")
  )
}

# ---- knit_print.symbolizer_symbol_table -------------------------------------

test_that("knit_print.symbolizer_symbol_table returns knit_asis with a pipe table", {
  sym <- make_kp_sym()
  out <- knitr::knit_print(symbol_table(sym))
  expect_s3_class(out, "knit_asis")
  expect_match(as.character(out), "|", fixed = TRUE)
})

test_that("knit_print.symbolizer_symbol_table wraps response vector in dollars", {
  sym <- make_kp_sym()
  rendered <- as.character(knitr::knit_print(symbol_table(sym)))
  # Lowercase bold w for the response vector, wrapped in $...$.
  expect_match(rendered, "$\\mathbf{w}$", fixed = TRUE)
  # Concrete dimension reflects n = 80.
  expect_match(rendered, "$\\mathbb{R}^{80}$", fixed = TRUE)
  # No bare \mathbf{w} outside of $...$.
  stripped <- gsub("\\$\\\\mathbf\\{w\\}\\$", "", rendered)
  expect_false(grepl("\\mathbf{w}", stripped, fixed = TRUE))
})

# ---- knit_print.symbolizer_assumption_table ---------------------------------

test_that("knit_print.symbolizer_assumption_table renders the conditional row", {
  sym <- make_kp_sym()
  out <- knitr::knit_print(assumption_table(sym))
  expect_s3_class(out, "knit_asis")
  rendered <- as.character(out)
  # Conditional distribution row carries the dollar-wrapped LaTeX expression.
  expect_match(rendered, "$W_i \\mid \\mu_i", fixed = TRUE)
})

test_that("knit_print.symbolizer_assumption_table never emits bare \\mu_i", {
  sym <- make_kp_sym()
  rendered <- as.character(knitr::knit_print(assumption_table(sym)))
  # Every \mu_i occurrence is inside $...$, so removing the wrapped forms
  # should leave no trace of the bare token.
  stripped <- gsub("\\$[^$]*\\$", "", rendered, perl = TRUE)
  expect_false(grepl("\\mu_i", stripped, fixed = TRUE))
})

test_that("knit_print.symbolizer_assumption_table uses friendly status labels", {
  sym <- make_kp_sym()
  at <- assumption_table(sym)
  rendered <- as.character(knitr::knit_print(at))
  # Friendly labels appear in the rendered markdown.
  expect_true(any(grepl("explicit", rendered, fixed = TRUE)))
  expect_true(any(grepl("follows from the formula", rendered, fixed = TRUE)))
  expect_true(any(grepl("your responsibility", rendered, fixed = TRUE)))
  # Raw CSV keys do NOT appear in the rendered markdown.
  expect_false(grepl("not_checked", rendered, fixed = TRUE))
  # Underlying data column keeps the CSV keys.
  expect_true("stated" %in% at$status)
  expect_true("not_checked" %in% at$status)
})

# ---- knit_print.symbolizer_formula_bridge -----------------------------------

test_that("knit_print.symbolizer_formula_bridge keeps both math columns by default", {
  sym <- make_kp_sym()
  out <- knitr::knit_print(formula_bridge(sym))
  expect_s3_class(out, "knit_asis")
  rendered <- as.character(out)
  expect_match(rendered, "math (index)", fixed = TRUE)
  expect_match(rendered, "math (matrix)", fixed = TRUE)
})

test_that("knit_print.symbolizer_formula_bridge backticks R syntax", {
  sym <- make_kp_sym()
  rendered <- as.character(knitr::knit_print(formula_bridge(sym)))
  expect_match(rendered, "`body_mass ~ temperature`", fixed = TRUE)
})

# ---- knit_print.symbolizer_interpretation -----------------------------------

test_that("knit_print.symbolizer_interpretation lists the core columns", {
  sym <- make_kp_sym()
  out <- knitr::knit_print(parameter_interpretation(sym))
  expect_s3_class(out, "knit_asis")
  rendered <- as.character(out)
  for (col in c("submodel", "term_label", "coefficient_role",
                "estimate", "biological_reading")) {
    expect_match(rendered, col, fixed = TRUE)
  }
})

test_that("knit_print.symbolizer_interpretation formats estimates with formatC", {
  sym <- make_kp_sym()
  rendered <- as.character(knitr::knit_print(parameter_interpretation(sym)))
  # The intercept estimate is ~29.56058 raw; formatC(digits = 3) yields "29.6".
  expect_match(rendered, "29.6", fixed = TRUE)
  expect_false(grepl("29.56058", rendered, fixed = TRUE))
})

# ---- knit_print.notation_bridge ---------------------------------------------

test_that("knit_print.notation_bridge wraps both index and matrix notations", {
  sym <- make_kp_sym()
  out <- knitr::knit_print(notation_bridge(sym))
  expect_s3_class(out, "knit_asis")
  rendered <- as.character(out)
  expect_match(rendered, "$W_i$", fixed = TRUE)
  expect_match(rendered, "$\\mathbf{w}$", fixed = TRUE)
})

# ---- knit_print.symbolizer_equations ----------------------------------------

test_that("knit_print.symbolizer_equations(notation = 'index') yields index aligned block", {
  sym <- make_kp_sym()
  rendered <- as.character(knitr::knit_print(equations(sym, notation = "index")))
  expect_match(rendered, "$$\n\\begin{aligned}", fixed = TRUE)
  expect_match(rendered, "\\mu_i = ", fixed = TRUE)
  expect_false(grepl("\\boldsymbol{\\mu}", rendered, fixed = TRUE))
})

test_that("knit_print.symbolizer_equations(notation = 'matrix') yields matrix aligned block", {
  sym <- make_kp_sym()
  rendered <- as.character(knitr::knit_print(equations(sym, notation = "matrix")))
  expect_match(rendered, "\\boldsymbol{\\mu}", fixed = TRUE)
  expect_match(rendered, "\\mathbf{X}", fixed = TRUE)
  expect_false(grepl("\\beta_{0} \\, T_i", rendered, fixed = TRUE))
})

test_that("knit_print.symbolizer_equations(notation = 'both') stacks index and matrix", {
  sym <- make_kp_sym()
  rendered <- as.character(knitr::knit_print(equations(sym, notation = "both")))
  expect_match(rendered, "**Index form:**", fixed = TRUE)
  expect_match(rendered, "**Matrix form:**", fixed = TRUE)
})

# ---- sym_dollar() helper ----------------------------------------------------

test_that("sym_dollar() replaces NA, empty, and '--' with an em-dash", {
  expect_identical(symbolizer:::sym_dollar(NA_character_), "—")
  expect_identical(symbolizer:::sym_dollar(""),            "—")
  expect_identical(symbolizer:::sym_dollar("--"),          "—")
})

test_that("sym_dollar() wraps LaTeX-looking strings in $...$", {
  expect_identical(symbolizer:::sym_dollar("\\mu_i"), "$\\mu_i$")
  expect_identical(symbolizer:::sym_dollar("X_i"),    "$X_i$")
})

test_that("sym_dollar() leaves plain prose unwrapped", {
  expect_identical(symbolizer:::sym_dollar("column of design matrix"),
                   "column of design matrix")
  # Snake-case identifiers stay unwrapped: bare underscore is not LaTeX.
  expect_identical(symbolizer:::sym_dollar("body_mass"), "body_mass")
  # Subscript-with-brace IS LaTeX.
  expect_identical(symbolizer:::sym_dollar("\\beta_{0}"), "$\\beta_{0}$")
})
