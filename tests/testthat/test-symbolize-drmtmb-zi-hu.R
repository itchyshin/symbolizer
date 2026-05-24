# Zero-inflation (zi) and hurdle (hu) submodels layered on top of a count
# family. drmTMB supports:
#   - poisson + zi
#   - nbinom2 + zi
#   - truncated_nbinom2 + hu

# --- Zero-inflation on Poisson ----------------------------------------------

test_that("Poisson + zi fit symbolizes with both mu and zi submodels", {
  fit <- fit_drm_poisson_zi()
  sym <- symbolize(fit)
  expect_setequal(unique(sym$submodels$parameter), c("mu", "zi"))
  zi_row <- sym$submodels[sym$submodels$parameter == "zi", ]
  expect_equal(zi_row$link, "logit")
})

test_that("Poisson + zi has a zi linear-predictor component on the logit scale", {
  fit <- fit_drm_poisson_zi()
  sym <- symbolize(fit)
  zi_lp <- sym$components$equation[sym$components$name == "zi_linear_predictor"]
  expect_match(zi_lp, "logit",       fixed = TRUE)
  expect_match(zi_lp, "pi_{",        fixed = TRUE)
  expect_match(zi_lp, "alpha_{0}",   fixed = TRUE)
})

test_that("Poisson + zi interpretation has rows for both mu and zi", {
  fit <- fit_drm_poisson_zi()
  sym <- symbolize(fit)
  expect_true("zi" %in% sym$interpretation$submodel)
  zi_rows <- sym$interpretation[sym$interpretation$submodel == "zi", , drop = FALSE]
  expect_true(any(grepl("structural zero", zi_rows$biological_reading,
                         fixed = TRUE)))
})

test_that("Poisson + zi methods_text mentions zero-inflation explicitly", {
  fit <- fit_drm_poisson_zi()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  expect_match(mt$text, "zero-inflation",       fixed = TRUE)
  expect_match(mt$text, "structural zero",      fixed = TRUE)
  expect_match(mt$text, "logit scale",          fixed = TRUE)
})

test_that("Poisson + zi capability row is First slice", {
  caps <- symbolizer_capabilities()
  row <- caps[caps$class == "drmTMB" & caps$family == "poisson" &
              caps$component == "zi", ]
  expect_equal(nrow(row), 1L)
  expect_equal(row$status, "First slice")
})

# --- Hurdle on truncated_nbinom2 --------------------------------------------

test_that("truncated_nbinom2 + hu fit symbolizes with mu, sigma, and hu submodels", {
  fit <- fit_drm_truncated_nbinom2_hu()
  sym <- symbolize(fit)
  expect_setequal(unique(sym$submodels$parameter), c("mu", "sigma", "hu"))
  hu_row <- sym$submodels[sym$submodels$parameter == "hu", ]
  expect_equal(hu_row$link, "logit")
})

test_that("truncated_nbinom2 + hu has a hu linear-predictor component", {
  fit <- fit_drm_truncated_nbinom2_hu()
  sym <- symbolize(fit)
  hu_lp <- sym$components$equation[sym$components$name == "hu_linear_predictor"]
  expect_match(hu_lp, "logit",     fixed = TRUE)
  expect_match(hu_lp, "pi_{",      fixed = TRUE)
  expect_match(hu_lp, "delta_{0}", fixed = TRUE)
})

test_that("truncated_nbinom2 + hu methods_text mentions the hurdle explicitly", {
  fit <- fit_drm_truncated_nbinom2_hu()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  expect_match(mt$text, "hurdle component", fixed = TRUE)
  expect_match(mt$text, "logit scale",      fixed = TRUE)
  expect_match(mt$text, "zero-truncated",   fixed = TRUE)
  expect_false(grepl("[unfilled:", mt$text, fixed = TRUE))
})

test_that("truncated_nbinom2 + hu capability row is First slice", {
  caps <- symbolizer_capabilities()
  row <- caps[caps$class == "drmTMB" & caps$family == "truncated_nbinom2" &
              caps$component == "hu", ]
  expect_equal(nrow(row), 1L)
  expect_equal(row$status, "First slice")
})
