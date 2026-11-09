# knit_print.symbolizer_group_contrasts formatting branches.

test_that("knit_print group_contrasts on binomial glm uses odds-ratio footer", {
  skip_if_not_installed("knitr")
  skip_if_not_installed("emmeans")
  d <- transform(mtcars, am = factor(am), cyl = factor(cyl))
  fit <- glm(am ~ cyl, data = d, family = binomial())
  gc <- group_contrasts(symbolize(fit), by = "cyl")
  txt <- as.character(knitr::knit_print(gc))
  expect_match(txt, "odds ratio", ignore.case = TRUE)
  expect_match(txt, "|", fixed = TRUE)
})

test_that("knit_print group_contrasts drops empty level_combo column", {
  skip_if_not_installed("knitr")
  skip_if_not_installed("emmeans")
  d <- transform(mtcars, gear = factor(gear))
  gc <- group_contrasts(symbolize(lm(mpg ~ gear, data = d)), by = "gear")
  txt <- as.character(knitr::knit_print(gc))
  expect_false(grepl("level_combo", txt, fixed = TRUE))
})
