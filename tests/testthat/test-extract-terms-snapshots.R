# Snapshot tests locking in extract_terms() output for the cases that drive
# every renderer: factor contrasts, interactions, transformations, offsets,
# and one-sided formulas.
#
# Wide tibble printing is needed so the full latex_term column is captured
# in each snapshot rather than collapsed into "i N more variables".

print_full <- function(x) {
  withr::with_options(
    list(width = 500, tibble.width = Inf, pillar.print_max = Inf),
    print(x)
  )
}

test_that("multi-level factor produces one row per contrast level", {
  dat <- fx_three_level_factor()
  result <- extract_terms(y ~ site, dat, "mu")
  expect_snapshot(print_full(result))
})

test_that("continuous x continuous interaction", {
  dat <- fx_continuous_pair()
  result <- extract_terms(
    y ~ x * z, dat, "mu",
    symbols = c(x = "X_i", z = "Z_i")
  )
  expect_snapshot(print_full(result))
})

test_that("continuous x factor interaction", {
  dat <- fx_cont_factor()
  result <- extract_terms(
    y ~ x * sex, dat, "mu",
    symbols = c(x = "X_i", sex = "S_i")
  )
  expect_snapshot(print_full(result))
})

test_that("factor x factor interaction", {
  dat <- data.frame(
    y = 1:8,
    a = factor(rep(c("a1", "a2"), 4)),
    b = factor(rep(c("b1", "b2"), each = 4))
  )
  result <- extract_terms(y ~ a * b, dat, "mu")
  expect_snapshot(print_full(result))
})

test_that("offset with function call (log)", {
  dat <- fx_with_offset()
  result <- extract_terms(
    y ~ x + offset(log(exposure)), dat, "mu",
    symbols = c(x = "X_i", exposure = "E_i")
  )
  expect_snapshot(print_full(result))
})

test_that("offset without function call", {
  dat <- fx_with_offset()
  result <- extract_terms(
    y ~ x + offset(exposure), dat, "mu",
    symbols = c(x = "X_i", exposure = "E_i")
  )
  expect_snapshot(print_full(result))
})

test_that("scale(x) transformation", {
  dat <- fx_continuous_pair()
  result <- extract_terms(
    y ~ scale(x), dat, "mu",
    symbols = c(x = "X_i")
  )
  expect_snapshot(print_full(result))
})

test_that("log(z) transformation", {
  dat <- fx_continuous_pair()
  result <- extract_terms(
    y ~ log(z), dat, "mu",
    symbols = c(z = "Z_i")
  )
  expect_snapshot(print_full(result))
})

test_that("I(x^2) identity-protected expression", {
  dat <- fx_continuous_pair()
  result <- extract_terms(
    y ~ x + I(x^2), dat, "mu",
    symbols = c(x = "X_i")
  )
  expect_snapshot(print_full(result))
})

test_that("poly(x, 2) orthogonal polynomial", {
  dat <- fx_continuous_pair()
  result <- extract_terms(
    y ~ poly(x, 2), dat, "mu",
    symbols = c(x = "X_i")
  )
  expect_snapshot(print_full(result))
})

test_that("one-sided formula on sigma submodel with gamma coefficients", {
  dat <- fx_continuous_pair()
  result <- extract_terms(
    ~ x, dat, "sigma",
    symbols = c(x = "X_i"),
    coefficient_family = "gamma"
  )
  expect_snapshot(print_full(result))
})
