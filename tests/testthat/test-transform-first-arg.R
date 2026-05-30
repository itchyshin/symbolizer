# E4 / B82 (CC): a multi-argument transform like poly(x, 2) must take only its
# FIRST argument as the variable. Previously the whole arg list leaked into the
# math subscript ("x, 2"), producing an ugly symbol AND silently ignoring a
# user-supplied symbol for x (because the key "x" never matched "x, 2").

test_that("multi-arg transform keeps only the first argument as the variable (B82)", {
  dat <- fx_continuous_pair()
  result <- extract_terms(y ~ poly(x, 2), dat, "mu", symbols = c(x = "X_i"))
  tr <- result[result$role == "transformation", ]

  expect_true(nrow(tr) >= 1L)
  # The variable is the transformed predictor 'x', NOT the deparsed arg list.
  expect_true(all(tr$variable == "x"))
  expect_false(any(grepl(",", tr$variable, fixed = TRUE)))
  # The supplied symbol for x is therefore honoured (no '\mathrm{x, 2}' fallback).
  expect_true(all(grepl("X_i", tr$symbol, fixed = TRUE)))
  expect_false(any(grepl("x, 2", tr$symbol, fixed = TRUE)))
})

test_that("single-arg transforms are unaffected by the first-argument rule", {
  dat <- fx_continuous_pair()
  res_exp   <- extract_terms(y ~ exp(x), dat, "mu", symbols = c(x = "X_i"))
  res_scale <- extract_terms(y ~ scale(x), dat, "mu", symbols = c(x = "X_i"))

  exp_tr   <- res_exp[res_exp$role == "transformation", ]
  scale_tr <- res_scale[res_scale$role == "transformation", ]

  expect_true(all(exp_tr$variable == "x"))
  expect_true(all(scale_tr$variable == "x"))
  expect_true(all(grepl("X_i", exp_tr$symbol, fixed = TRUE)))
})
