test_that("gllvmTMB binomial fit symbolizes end-to-end", {
  fit <- fit_gllvm_binomial()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$family, "binomial")
})

test_that("gllvmTMB binomial distribution row uses Bernoulli on logit scale", {
  fit <- fit_gllvm_binomial()
  sym <- symbolize(fit)
  expect_match(sym$distribution$latex, "Bernoulli",  fixed = TRUE)
  expect_match(sym$distribution$latex, "logit",      fixed = TRUE)
})

test_that("gllvmTMB binomial trait intercepts read as logit baseline probabilities", {
  fit <- fit_gllvm_binomial()
  sym <- symbolize(fit)
  mu_rows <- sym$interpretation[sym$interpretation$submodel == "mu", , drop = FALSE]
  expect_true(any(grepl("plogis|success rate|success probability",
                        mu_rows$biological_reading)))
})

test_that("gllvmTMB binomial Lambda_B loadings note the logit scale", {
  fit <- fit_gllvm_binomial()
  sym <- symbolize(fit)
  L_rows <- sym$interpretation[sym$interpretation$submodel == "Lambda_B", , drop = FALSE]
  expect_true(any(grepl("logit", L_rows$biological_reading, fixed = TRUE)))
})

test_that("gllvmTMB binomial capability rows are First slice", {
  caps <- symbolizer_capabilities()
  rows <- caps[caps$class == "gllvmTMB" & caps$family == "binomial", ]
  expect_true(nrow(rows) >= 1L)
  expect_true(all(rows$status == "First slice"))
})
