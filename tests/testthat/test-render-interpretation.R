test_that("parameter_interpretation() returns a symbolizer_interpretation object", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- parameter_interpretation(sym)
  expect_s3_class(out, "symbolizer_interpretation")
  expect_s3_class(out, "tbl_df")
})

test_that("parameter_interpretation() default returns 4 rows with all reading columns", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- parameter_interpretation(sym)
  expect_equal(nrow(out), 4L)
  expect_true(all(
    c("submodel", "term_label", "coefficient_role", "estimate",
      "link_scale_reading", "natural_scale_reading",
      "variance_scale_reading", "biological_reading") %in% names(out)
  ))
})

test_that("parameter_interpretation(scale = 'natural') drops other reading columns", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- parameter_interpretation(sym, scale = "natural")
  expect_named(
    out,
    c("submodel", "term_label", "coefficient_role", "estimate",
      "natural_scale_reading")
  )
})

test_that("parameter_interpretation(scale = 'link') keeps only the link reading", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- parameter_interpretation(sym, scale = "link")
  expect_named(
    out,
    c("submodel", "term_label", "coefficient_role", "estimate",
      "link_scale_reading")
  )
})

test_that("parameter_interpretation(scale = 'variance') keeps only the variance reading", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- parameter_interpretation(sym, scale = "variance")
  expect_named(
    out,
    c("submodel", "term_label", "coefficient_role", "estimate",
      "variance_scale_reading")
  )
})

test_that("parameter_interpretation(scale = 'biological') keeps only the biological reading", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- parameter_interpretation(sym, scale = "biological")
  expect_named(
    out,
    c("submodel", "term_label", "coefficient_role", "estimate",
      "biological_reading")
  )
})

test_that("mu temperature slope natural reading mentions body_mass and temperature", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- parameter_interpretation(sym)
  slope_mu <- out[out$submodel == "mu" & out$coefficient_role == "slope", ,
                  drop = FALSE]
  expect_equal(nrow(slope_mu), 1L)
  expect_match(slope_mu$natural_scale_reading, "body_mass")
  expect_match(slope_mu$natural_scale_reading, "temperature")
})

test_that("sigma temperature slope variance reading contains 'exp(2*'", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- parameter_interpretation(sym)
  slope_sg <- out[out$submodel == "sigma" & out$coefficient_role == "slope", ,
                  drop = FALSE]
  expect_equal(nrow(slope_sg), 1L)
  expect_match(slope_sg$variance_scale_reading, "exp(2*", fixed = TRUE)
})

test_that("mu intercept biological reading mentions 'Baseline body_mass'", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  out <- parameter_interpretation(sym)
  int_mu <- out[out$submodel == "mu" & out$coefficient_role == "intercept", ,
                drop = FALSE]
  expect_equal(nrow(int_mu), 1L)
  expect_match(int_mu$biological_reading, "Baseline body_mass")
})

test_that("parameter_interpretation.default() errors with a pointer to symbolize()", {
  expect_error(parameter_interpretation(list()), "symbolize")
})

test_that("print method renders a clean per-submodel summary (snapshot)", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  expect_snapshot(print(parameter_interpretation(sym)))
})
