# E4 / B81 family: a factor-contrast LaTeX label `[variable = level]` must escape
# underscores in BOTH the variable name and the level, so a snake_case factor
# (body_size) does not render `body` with an italic subscript `size` in math.
# build_latex()'s factor_contrast branch interpolated both raw.

test_that("factor_contrast LaTeX escapes underscores in variable and level (E4/B81)", {
  set.seed(1)
  d <- data.frame(y = rnorm(80),
                  body_size = factor(sample(c("ref", "big_one"), 80, TRUE)))
  d$body_size <- relevel(d$body_size, ref = "ref")  # contrast level = big_one (snake)
  lat <- paste(as_latex(symbolize(lm(y ~ body_size, data = d))), collapse = "\n")

  expect_true(grepl("[body", lat, fixed = TRUE))        # contrast bracket present
  expect_false(grepl("[body_size", lat, fixed = TRUE))  # variable: NOT the raw underscore
  expect_true(grepl("body\\_size", lat, fixed = TRUE))  # variable: escaped
  expect_false(grepl("big_one", lat, fixed = TRUE))     # level: NOT raw
  expect_true(grepl("big\\_one", lat, fixed = TRUE))    # level: escaped
})
