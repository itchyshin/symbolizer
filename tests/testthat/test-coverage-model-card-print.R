# Console print.symbolizer_model_card() branches (R/model-card.R).

test_that("print.model_card surfaces marginal blocks and factor coding when present", {
  skip_if_not_installed("emmeans")
  d <- transform(mtcars, gear = factor(gear), cyl = factor(cyl))
  sym <- symbolize(lm(mpg ~ wt * gear, data = d))
  card <- model_card(sym)
  out <- paste(utils::capture.output(print(card), type = "message"), collapse = "\n")
  expect_match(out, "model card", ignore.case = TRUE)
  expect_match(out, "Group means", fixed = TRUE)
  expect_match(out, "Group slopes", fixed = TRUE)
  expect_match(out, "Group contrasts", fixed = TRUE)
  expect_match(out, "Factor coding", fixed = TRUE)
  expect_invisible(print(card))
})

test_that("print.model_card reports empty extraction and plot registries for lm", {
  sym <- symbolize(lm(mpg ~ wt, data = mtcars))
  card <- model_card(sym)
  out <- paste(utils::capture.output(print(card), type = "message"), collapse = "\n")
  expect_match(out, "no extraction calls registered", ignore.case = TRUE)
  expect_match(out, "no plot recipes registered", ignore.case = TRUE)
})

test_that("model_card gllvmTMB extraction and plot recipes are non-empty", {
  skip_if_not_installed("gllvmTMB")
  fit <- fit_gllvm_basic()
  card <- model_card(symbolize(fit))
  expect_true(length(card$extraction_calls) > 0L)
  expect_true(length(card$recommended_plots) > 0L)
  expect_true(any(grepl("getLoadings", card$extraction_calls, fixed = TRUE)))
  expect_true(any(grepl("Loading plot", names(card$recommended_plots), fixed = TRUE)))
})
