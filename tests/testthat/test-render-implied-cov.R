# Tests for the latex_implied_cov_block emitter used in Tab 3 of the
# gllvm widget. Each tier (B and W) emits a stacked block that shows
# the numerical Σ next to Λ Λ^T + diag(Ψ²).

test_that("latex_implied_cov_block emits the three-term decomposition", {
  Lambda <- matrix(c(1.0, 0.5, 0.2,
                     0.0, 0.7, 0.3), nrow = 3, byrow = FALSE)
  Psi    <- c(0.4, 0.3, 0.5)
  Sigma  <- Lambda %*% t(Lambda) + diag(Psi^2)
  out <- symbolizer:::latex_implied_cov_block(
    tier = "B", Sigma = Sigma, Lambda = Lambda, Psi = Psi
  )
  expect_type(out, "character")
  expect_length(out, 1L)
  expect_match(out, "\\\\boldsymbol\\{\\\\Sigma\\}_B", fixed = FALSE)
  expect_match(out, "\\\\boldsymbol\\{\\\\Lambda\\}_B", fixed = FALSE)
  expect_match(out, "\\\\boldsymbol\\{\\\\Psi\\}_B", fixed = FALSE)
  expect_match(out, "between-individual", fixed = TRUE)
})

test_that("latex_implied_cov_block returns NULL when any matrix is NULL", {
  expect_null(symbolizer:::latex_implied_cov_block(
    tier = "W", Sigma = NULL, Lambda = NULL, Psi = NULL
  ))
})

test_that("latex_implied_cov_block tier = 'W' uses Λ_W / Ψ_W / Σ_W labels", {
  Lambda <- matrix(0.3, nrow = 3, ncol = 1)
  Psi    <- c(0.5, 0.4, 0.6)
  Sigma  <- Lambda %*% t(Lambda) + diag(Psi^2)
  out <- symbolizer:::latex_implied_cov_block(
    tier = "W", Sigma = Sigma, Lambda = Lambda, Psi = Psi
  )
  expect_match(out, "\\\\boldsymbol\\{\\\\Sigma\\}_W", fixed = FALSE)
  expect_match(out, "\\\\boldsymbol\\{\\\\Lambda\\}_W", fixed = FALSE)
  expect_match(out, "\\\\boldsymbol\\{\\\\Psi\\}_W", fixed = FALSE)
  expect_match(out, "within-individual", fixed = TRUE)
})
