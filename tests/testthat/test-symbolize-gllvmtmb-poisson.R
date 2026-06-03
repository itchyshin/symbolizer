test_that("gllvmTMB Poisson fit symbolizes end-to-end", {
  fit <- fit_gllvm_poisson()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$family, "poisson")
})

test_that("gllvmTMB Poisson distribution row uses Poisson on the log scale", {
  fit <- fit_gllvm_poisson()
  sym <- symbolize(fit)
  expect_match(sym$distribution$latex, "Poisson", fixed = TRUE)
  expect_match(sym$distribution$latex, "\\exp",   fixed = TRUE)
  # A Poisson model has no row-level residual SD, so the Gaussian
  # Normal/sigma_eps form must not leak into the distribution line.
  expect_false(grepl("Normal", sym$distribution$latex, fixed = TRUE))
})

test_that("gllvmTMB Poisson trait intercepts read as expected counts", {
  fit <- fit_gllvm_poisson()
  sym <- symbolize(fit)
  mu_rows <- sym$interpretation[sym$interpretation$submodel == "mu", , drop = FALSE]
  expect_true(any(grepl("count|exp\\(", mu_rows$biological_reading)))
})

test_that("gllvmTMB Poisson Lambda_B loadings note the log scale", {
  fit <- fit_gllvm_poisson()
  sym <- symbolize(fit)
  L_rows <- sym$interpretation[sym$interpretation$submodel == "Lambda_B", , drop = FALSE]
  expect_true(any(grepl("log scale", L_rows$biological_reading, fixed = TRUE)))
})

test_that("gllvmTMB Poisson components distribution row is family-aware (not Gaussian)", {
  fit <- fit_gllvm_poisson()
  sym <- symbolize(fit)
  dist_row <- sym$components[sym$components$kind == "distribution", , drop = FALSE]
  expect_equal(nrow(dist_row), 1L)
  expect_match(dist_row$equation, "Poisson", fixed = TRUE)
  expect_match(dist_row$equation_matrix, "Poisson", fixed = TRUE)
  expect_false(grepl("Normal", dist_row$equation, fixed = TRUE))
  expect_false(grepl("sigma_\\epsilon", dist_row$equation, fixed = TRUE))
  # The components distribution row must stay in lockstep with the
  # family-aware distribution tibble (same line in every view).
  expect_equal(dist_row$equation[[1L]], sym$distribution$latex[[1L]])
  expect_equal(dist_row$equation_matrix[[1L]], sym$distribution$latex_matrix[[1L]])
})

test_that("gllvmTMB Poisson capability rows are First slice", {
  caps <- symbolizer_capabilities()
  rows <- caps[caps$class == "gllvmTMB" & caps$family == "poisson", ]
  expect_true(nrow(rows) >= 1L)
  expect_true(all(rows$status == "First slice"))
})

test_that("gllvmTMB Poisson parameterization carries no residual-SD scale parameter", {
  fit <- fit_gllvm_poisson()
  sym <- symbolize(fit)
  expect_equal(sym$parameterization$response_distribution, "Poisson")
  expect_equal(sym$parameterization$link_mu, "log")
})

test_that("renderers consume the Poisson symbolize output without error", {
  fit <- fit_gllvm_poisson()
  sym <- symbolize(fit)
  expect_silent(equations(sym))
  expect_type(as_latex(sym), "character")
  expect_type(as_latex(sym, notation = "matrix"), "character")
})

test_that("gllvmTMB binomial components distribution row is Bernoulli, not Gaussian (regression)", {
  # Companion to the Poisson family-aware fix: the binomial components
  # distribution row previously fell back to the Gaussian Normal/sigma_eps
  # form. It must now mirror the Bernoulli distribution tibble.
  fit <- fit_gllvm_binomial()
  sym <- symbolize(fit)
  dist_row <- sym$components[sym$components$kind == "distribution", , drop = FALSE]
  expect_match(dist_row$equation, "Bernoulli", fixed = TRUE)
  expect_false(grepl("Normal", dist_row$equation, fixed = TRUE))
  expect_equal(dist_row$equation[[1L]], sym$distribution$latex[[1L]])
})
