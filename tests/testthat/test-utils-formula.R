test_that("formula_rhs() returns the RHS of a two-sided formula", {
  expect_equal(deparse1(symbolizer:::formula_rhs(y ~ x + z)), "x + z")
})

test_that("formula_rhs() returns the RHS of a one-sided formula", {
  expect_equal(deparse1(symbolizer:::formula_rhs(~ x)), "x")
})

test_that("formula_lhs() returns the LHS symbol of a two-sided formula", {
  expect_equal(as.character(symbolizer:::formula_lhs(y ~ x)), "y")
})

test_that("formula_lhs() returns NULL for a one-sided formula", {
  expect_null(symbolizer:::formula_lhs(~ x))
})

test_that("formula_vars() returns unique base variable names", {
  vars <- symbolizer:::formula_vars(y ~ x + z + log(w))
  expect_true(setequal(vars, c("x", "z", "w")))
})

test_that("formula_vars() returns character(0) for non-formula input", {
  expect_identical(symbolizer:::formula_vars("not a formula"), character(0))
})

test_that("wrap_aligned() emits a proper aligned environment", {
  out <- symbolizer:::wrap_aligned(c("\\mu_i = \\beta_0", "\\sigma_i = \\gamma_0"))
  expect_match(out, "\\\\begin\\{aligned\\}")
  expect_match(out, "\\\\end\\{aligned\\}")
  expect_match(out, " \\\\\\\\\n", fixed = FALSE)
})

test_that("formula_rhs() errors for non-formula input", {
  expect_error(symbolizer:::formula_rhs("not a formula"), "must be a formula")
})
