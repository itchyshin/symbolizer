# print() paths on render-tables accessors (R/render-tables.R, notation-bridge).

capture_cli <- function(x) {
  paste(utils::capture.output(print(x), type = "message"), collapse = "\n")
}

test_that("print on symbol, assumption, formula, and interpretation tables", {
  skip_if_not_installed("drmTMB")
  sym <- symbolize(
    fit_drm_location_scale(),
    symbols = c(body_mass = "W_i"),
    units = c(body_mass = "g")
  )
  out_sym <- capture_cli(symbol_table(sym))
  expect_match(out_sym, "Symbol dictionary", fixed = TRUE)
  expect_match(out_sym, "units", fixed = TRUE)
  out_as <- capture_cli(assumption_table(sym))
  expect_match(out_as, "Assumptions", fixed = TRUE)
  expect_match(out_as, "explicit", fixed = TRUE)
  out_fb <- capture_cli(formula_bridge(sym))
  expect_match(out_fb, "Formula bridge", fixed = TRUE)
  out_pi <- capture_cli(parameter_interpretation(sym))
  expect_match(out_pi, "Parameter interpretation", fixed = TRUE)
})

test_that("print.notation_bridge and print.symbolizer_equations", {
  skip_if_not_installed("drmTMB")
  sym <- symbolize(fit_drm_location_scale())
  out_nb <- capture_cli(notation_bridge(sym))
  expect_match(out_nb, "Notation bridge", fixed = TRUE)
  out_eq <- capture_cli(equations(sym, notation = "both"))
  expect_match(out_eq, "Equations", fixed = TRUE)
})

test_that("assumption_table.default errors like other accessors", {
  expect_error(assumption_table(data.frame()), "symbolize")
})

test_that("group_means on link scale for Poisson differs from response scale", {
  skip_if_not_installed("emmeans")
  set.seed(2L)
  d <- transform(mtcars, gear = factor(gear))
  sym <- symbolize(glm(mpg ~ gear, data = d, family = poisson()))
  gm_link <- group_means(sym, scale = "link")
  gm_resp <- group_means(sym, scale = "response")
  expect_equal(unique(gm_link$scale), "link")
  expect_equal(unique(gm_resp$scale), "response")
  expect_false(isTRUE(all.equal(gm_link$estimate, gm_resp$estimate)))
})

test_that("methods_text on glmmTMB gaussian mentions the package", {
  skip_if_not_installed("glmmTMB")
  set.seed(1L)
  d <- data.frame(y = rnorm(80), x = rnorm(80), g = factor(rep(1:4, each = 20)))
  fit <- suppressWarnings(glmmTMB::glmmTMB(y ~ x + (1 | g), data = d))
  mt <- methods_text(symbolize(fit))
  expect_match(mt$text, "glmmTMB", fixed = TRUE)
  expect_match(mt$text, "random", ignore.case = TRUE)
})
