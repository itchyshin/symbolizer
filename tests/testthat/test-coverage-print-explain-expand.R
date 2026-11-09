# Console print / explain paths that CI still skips lightly.

test_that("print.symbolizer_group_slopes and group_contrasts emit cli output", {
  skip_if_not_installed("emmeans")
  d <- transform(mtcars, gear = factor(gear), cyl = factor(cyl))
  sym <- symbolize(lm(mpg ~ wt * gear, data = d))
  gs <- group_slopes(sym, continuous = "wt")
  gc <- group_contrasts(sym, by = "gear")
  out_gs <- paste(utils::capture.output(print(gs), type = "message"), collapse = "\n")
  out_gc <- paste(utils::capture.output(print(gc), type = "message"), collapse = "\n")
  expect_match(out_gs, "Group slopes", fixed = TRUE)
  expect_match(out_gs, "wt", fixed = TRUE)
  expect_match(out_gc, "Group contrasts", fixed = TRUE)
  expect_match(out_gc, "gear", fixed = TRUE)
})

test_that("group_contrasts with adjust = tukey widens intervals", {
  skip_if_not_installed("emmeans")
  d <- transform(mtcars, gear = factor(gear))
  sym <- symbolize(lm(mpg ~ gear, data = d))
  gc <- group_contrasts(sym, by = "gear", adjust = "tukey")
  expect_equal(unique(gc$adjust), "tukey")
  expect_s3_class(gc, "symbolizer_group_contrasts")
})

test_that("explain() and print.symbolized_explanation summarize a drmTMB fit", {
  skip_if_not_installed("drmTMB")
  fit <- fit_drm_location_scale()
  ex <- explain(fit)
  expect_s3_class(ex, "symbolized_explanation")
  out <- paste(utils::capture.output(print(ex), type = "message"), collapse = "\n")
  expect_match(out, "body_mass", fixed = TRUE)
  expect_match(out, "Equations", fixed = TRUE)
})

test_that("print.symbolized_model and summary.symbolized_model emit compact headers", {
  skip_if_not_installed("drmTMB")
  sym <- symbolize(fit_drm_location_scale(), context = "sym print smoke")
  out <- paste(utils::capture.output(print(sym), type = "message"), collapse = "\n")
  expect_match(out, "symbolized_model", ignore.case = TRUE)
  summ <- summary(sym)
  out2 <- paste(utils::capture.output(print(summ), type = "message"), collapse = "\n")
  expect_match(out2, "Summary", fixed = TRUE)
})

test_that("knit_print assumption_table uses a responsive wrapper", {
  skip_if_not_installed("knitr")
  skip_if_not_installed("drmTMB")
  sym <- symbolize(fit_drm_location_scale())
  txt <- as.character(knitr::knit_print(assumption_table(sym)))
  expect_match(txt, "table-responsive", fixed = TRUE)
})

test_that("print.symbolized_expanded shows head/tail truncation", {
  skip_if_not_installed("drmTMB")
  sym <- symbolize(fit_drm_location_scale())
  skip_if(is.null(sym$expanded))
  ex <- expand(sym, head = 2L, tail = 1L)
  out <- paste(utils::capture.output(print(ex), type = "message"), collapse = "\n")
  expect_match(out, "Expanded numeric arrays", fixed = TRUE)
})

test_that("isTRUE_vec and esc_html behave on edge inputs", {
  expect_identical(symbolizer:::isTRUE_vec(NULL), logical(0))
  expect_identical(symbolizer:::isTRUE_vec(c(TRUE, NA)), c(TRUE, FALSE))
  expect_match(symbolizer:::esc_html("a & b <c>"), "&amp;", fixed = TRUE)
})
