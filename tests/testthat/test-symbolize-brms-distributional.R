# Test for brms distributional (sigma ~ z) added in v0.11.

fit_brms_distributional <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("brms")
  if (is.null(.brms_fit_cache$dist)) {
    set.seed(11L)
    n <- 80L
    dat <- data.frame(y = rnorm(n, 0, 1 + abs(rnorm(n))), x = rnorm(n))
    .brms_fit_cache$dist <- suppressMessages(suppressWarnings(brms::brm(
      brms::bf(y ~ x, sigma ~ x),
      data = dat,
      family = stats::gaussian(),
      chains = 1, iter = 300, warmup = 150,
      refresh = 0, silent = 2
    )))
  }
  .brms_fit_cache$dist
}

test_that("symbolize.brmsfit handles brmsformula sigma ~ x distributional fits", {
  fit <- fit_brms_distributional()
  sym <- symbolize(fit)
  expect_true("sigma" %in% sym$fixed_effects$submodel)
  sigma_rows <- sym$fixed_effects[sym$fixed_effects$submodel == "sigma", ,
                                  drop = FALSE]
  expect_true(nrow(sigma_rows) >= 2L)
  # All rows should have non-NA credible bounds
  expect_false(any(is.na(sigma_rows$confint_low)))
  expect_false(any(is.na(sigma_rows$confint_high)))
  expect_true(all(sigma_rows$ci_method == "credible"))
})

test_that("brms distributional LaTeX includes both submodels with correct links", {
  fit <- fit_brms_distributional()
  sym <- symbolize(fit)
  tex <- as_latex(sym)
  expect_match(tex, "mu_i", fixed = TRUE)
  expect_match(tex, "sigma_i", fixed = TRUE)
  expect_match(tex, "log(", fixed = TRUE)  # log link on sigma
})
