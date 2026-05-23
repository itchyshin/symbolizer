test_that("get_parameterization('gaussian') returns the expected contract", {
  p <- symbolizer:::get_parameterization("gaussian")
  expect_type(p, "list")
  expect_true(all(c(
    "family", "response_distribution", "scale_parameter", "scale_meaning",
    "link_mu", "link_sigma", "variance_expression",
    "natural_sd_ratio", "natural_variance_ratio", "notes"
  ) %in% names(p)))
  expect_equal(p$family, "gaussian")
  expect_equal(p$link_mu, "identity")
  expect_equal(p$link_sigma, "log")
  expect_equal(p$scale_parameter, "sigma")
  expect_equal(p$response_distribution, "Normal")
})

test_that("get_parameterization() errors for an unknown family", {
  expect_snapshot(
    error = TRUE,
    symbolizer:::get_parameterization("nonexistent")
  )
})
