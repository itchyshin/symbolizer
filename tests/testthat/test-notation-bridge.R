test_that("components carry both index and matrix equation forms", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  expect_true("equation_matrix" %in% names(sym$components))
  expect_match(sym$components$equation_matrix[[1L]],
               "\\\\mathbf\\{w\\} \\\\mid \\\\boldsymbol\\{\\\\mu\\}")
  mu_row <- sym$components[sym$components$submodel == "mu" &
                             !is.na(sym$components$submodel), , drop = FALSE]
  expect_match(mu_row$equation_matrix,
               "\\\\boldsymbol\\{\\\\mu\\} = \\\\mathbf\\{X\\} \\\\boldsymbol\\{\\\\beta\\}")
  sg_row <- sym$components[sym$components$submodel == "sigma" &
                             !is.na(sym$components$submodel), , drop = FALSE]
  expect_match(sg_row$equation_matrix,
               "\\\\log\\(\\\\boldsymbol\\{\\\\sigma\\}\\) = \\\\mathbf\\{Z\\} \\\\boldsymbol\\{\\\\gamma\\}")
})

test_that("symbol_dictionary carries abstract and concrete dimension columns", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  d <- sym$symbol_dictionary
  expect_true("dimension"          %in% names(d))
  expect_true("dimension_concrete" %in% names(d))
  expect_true("symbol_matrix"      %in% names(d))
  # Vectors are lowercase bold; matrices are uppercase bold.
  resp <- d[d$role == "response", , drop = FALSE]
  expect_equal(resp$symbol_matrix, "\\mathbf{w}")
  expect_equal(resp$dimension,          "\\mathbb{R}^n")
  expect_equal(resp$dimension_concrete, "\\mathbb{R}^{80}")
  des <- d[d$role == "design_matrix", , drop = FALSE]
  expect_setequal(des$symbol_matrix, c("\\mathbf{X}", "\\mathbf{Z}"))
  expect_setequal(des$dimension_concrete,
                  c("\\mathbb{R}^{80 \\times 2}", "\\mathbb{R}^{80 \\times 2}"))
  beta <- d[d$role == "coefficient" & grepl("beta", d$symbol), , drop = FALSE]
  expect_equal(beta$symbol_matrix, "\\boldsymbol{\\beta}")
  expect_equal(beta$dimension_concrete, "\\mathbb{R}^{2}")
  expect_match(beta$dimension, "p_\\\\mu")
})

test_that("formula_bridge has both index and matrix mathematics columns", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  br <- sym$formula_bridge
  expect_true("mathematics_matrix" %in% names(br))
  expect_match(br$mathematics_matrix[[1L]], "\\\\boldsymbol\\{\\\\mu\\}")
  expect_match(br$mathematics_matrix[[2L]], "\\\\boldsymbol\\{\\\\sigma\\}")
})

test_that("notation_bridge returns concept, both notations, both dimensions", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  nb <- notation_bridge(sym)
  expect_s3_class(nb, "notation_bridge")
  expect_named(nb, c("concept", "index", "matrix", "dimension", "dimension_concrete"))
  expect_true(any(nb$concept == "conditional_distribution"))
  expect_true(any(nb$concept == "mu_linear_predictor"))
  expect_true(any(nb$concept == "sigma_linear_predictor"))
  body_mass_row <- nb[nb$concept == "body_mass", , drop = FALSE]
  expect_equal(body_mass_row$index, "W_i")
  expect_equal(body_mass_row$matrix, "\\mathbf{w}")
  cd_row <- nb[nb$concept == "conditional_distribution", , drop = FALSE]
  expect_equal(cd_row$dimension_concrete, "\\mathbb{R}^{80}")
})

test_that("notation_bridge.default points at symbolize()", {
  expect_error(notation_bridge(list()), "no method")
})

test_that("response symbol matrix strips _i and bolds the lowercased root", {
  fit <- fit_drm_location_scale()
  sym1 <- symbolize(fit, symbols = c(body_mass = "W_i"))
  expect_equal(sym1$distribution$response_symbol_matrix, "\\mathbf{w}")
  sym2 <- symbolize(fit)
  # The default response-symbol fallback is now `\\mathrm{body\\_mass}_i`
  # (v0.19.2: underscores in the column name are escaped so MathJax
  # doesn't render `body_mass` as "body subscript m subscript ass").
  # The matrix-form is the lowercased bold-vector with `\\_` still
  # escaped: `\\mathbf{body\\_mass}`.
  expect_equal(sym2$distribution$response_symbol_matrix,
               "\\mathbf{body\\_mass}")
})
