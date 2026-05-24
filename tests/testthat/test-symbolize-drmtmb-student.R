test_that("symbolize.drmTMB reads a Student-t fit end-to-end", {
  fit <- fit_drm_student()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$family, "student")
  expect_equal(sym$model$response, "y")
})

test_that("Student-t submodels carries mu, sigma, nu with the right links", {
  fit <- fit_drm_student()
  sym <- symbolize(fit)
  expect_equal(sort(sym$submodels$parameter), c("mu", "nu", "sigma"))
  links <- setNames(sym$submodels$link, sym$submodels$parameter)
  expect_equal(links[["mu"]],    "identity")
  expect_equal(links[["sigma"]], "log")
  expect_equal(links[["nu"]],    "logm2")
})

test_that("Student-t distribution row renders both index and matrix forms", {
  fit <- fit_drm_student()
  sym <- symbolize(fit)
  d <- sym$distribution
  expect_equal(d$family, "student")
  expect_match(d$latex,        "Student", fixed = TRUE)
  expect_match(d$latex,        "nu_i",    fixed = FALSE)
  expect_match(d$latex_matrix, "Student", fixed = TRUE)
  expect_match(d$latex_matrix, "boldsymbol\\{\\\\nu\\}", fixed = FALSE)
})

test_that("Student-t interpretation has rows for all three submodels including nu", {
  fit <- fit_drm_student()
  sym <- symbolize(fit)
  interp <- sym$interpretation
  expect_setequal(unique(interp$submodel), c("mu", "sigma", "nu"))
  # The nu row(s) should mention degrees of freedom in the biological reading.
  nu_rows <- interp[interp$submodel == "nu", , drop = FALSE]
  expect_true(nrow(nu_rows) >= 1L)
  expect_true(any(grepl("nu", nu_rows$biological_reading, fixed = TRUE)))
})

test_that("methods_text on a Student-t fit names the nu submodel and the log(nu - 2) link", {
  fit <- fit_drm_student()
  sym <- symbolize(fit)
  mt <- methods_text(sym)
  expect_match(mt$text, "Student-t",  fixed = TRUE)
  expect_match(mt$text, "log(nu - 2)", fixed = TRUE)
  expect_match(mt$text, "nu > 2",      fixed = TRUE)
})

test_that("Student-t assumption table includes nu-positivity and Student-t conditional distribution", {
  fit <- fit_drm_student()
  sym <- symbolize(fit)
  a <- sym$assumptions
  expect_true("positivity_and_finite_variance" %in% a$assumption)
  cd_row <- a$expression_latex[a$assumption == "conditional_distribution"]
  expect_match(cd_row, "Student", fixed = TRUE)
  expect_match(cd_row, "nu_i",    fixed = FALSE)
})

test_that("Student-t capability rows are First slice", {
  caps <- symbolizer_capabilities()
  st <- caps[caps$class == "drmTMB" & caps$family == "student", ]
  expect_true(all(st$status == "First slice"))
})
