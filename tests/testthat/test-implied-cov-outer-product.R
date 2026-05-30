# E1: the gllvm implied-covariance block must render the FULL chain
# Sigma = Lambda Lambda^T + Psi^2, where the term under the "Lambda Lambda^T"
# label is the T x T outer product (not the raw T x d loading matrix), and the
# T x d loadings Lambda are shown separately as the factor that builds it.

test_that("latex_implied_cov_block renders the T x T outer product, not raw Lambda", {
  # 3 traits, 2 latent dims. Column-major: col1 = (1, 0.5, 0.5), col2 = (0.2, 0.3, 0.4).
  Lambda <- matrix(c(1, 0.5, 0.5, 0.2, 0.3, 0.4), nrow = 3, ncol = 2)
  Psi   <- c(0.1, 0.2, 0.3)                       # uniqueness SDs
  Sigma <- Lambda %*% t(Lambda) + diag(Psi^2)     # implied 3x3 covariance

  blk <- symbolizer:::latex_implied_cov_block("B", Sigma = Sigma,
                                              Lambda = Lambda, Psi = Psi)

  # The (1,1) entry of Lambda Lambda^T is sum(Lambda[1, ]^2) = 1 + 0.04 = 1.04;
  # the raw loading Lambda[1,1] is 1 and Sigma[1,1] is 1.05. So "1.04" present
  # proves the outer product (not raw Lambda, not Sigma) is rendered under the
  # Lambda Lambda^T label.
  llt11 <- formatC(sum(Lambda[1, ]^2), digits = 3, format = "g")  # "1.04"
  expect_match(blk, llt11, fixed = TRUE)

  # The loadings Lambda are shown as their own labelled block ("loadings").
  expect_match(blk, "loadings", fixed = TRUE)

  # And the full equation still closes symbolically: Sigma = LL^T + Psi^2.
  expect_match(blk, "\\\\boldsymbol\\{\\\\Sigma\\}_B", perl = TRUE)
  expect_match(blk, "\\\\boldsymbol\\{\\\\Psi\\}_B", perl = TRUE)
})
