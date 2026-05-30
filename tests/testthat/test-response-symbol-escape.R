# Page-audit P6b: a snake_case response variable must render math-safe in
# equations() / as_latex() -- escaped underscore inside \mathrm{}, never a
# bare `body_mass` (which MathJax italicises as `body` subscript `mass`).
# The intentional structural subscripts (`\mu_i`, `\beta_{0}`) must survive.
# Every extractor's *_resolve_response_symbol delegates to the shared
# default_response_symbol(); drmTMB and phylolm already did this, the other
# Gaussian extractors did not (the rung-1..3 ladder bug).

test_that("default_response_symbol escapes snake_case + wraps multi-char", {
  expect_equal(default_response_symbol("body_mass"), "\\mathrm{body\\_mass}_i")
  expect_equal(default_response_symbol("count"),     "\\mathrm{count}_i")
  expect_equal(default_response_symbol("y"),         "y_i")
})

test_that("lm with a snake_case response renders the name math-safe", {
  set.seed(1)
  d <- data.frame(body_mass = rnorm(30), temperature = rnorm(30))
  sym <- symbolize(lm(body_mass ~ temperature, data = d))
  tex <- as_latex(sym, notation = "index")
  # escaped, upright identifier -- not a bare underscore
  expect_true(grepl("\\mathrm{body\\_mass}", tex, fixed = TRUE))
  expect_false(grepl("body_mass \\mid", tex, fixed = TRUE))
  # intentional structural subscripts untouched
  expect_true(grepl("\\mu_i", tex, fixed = TRUE))
  expect_true(grepl("\\beta_{0}", tex, fixed = TRUE))
})
