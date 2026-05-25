test_that("symbolizer_capabilities() returns the expected tibble shape", {
  caps <- symbolizer_capabilities()
  expect_s3_class(caps, "tbl_df")
  expect_named(
    caps,
    c("class", "family", "component", "status", "since", "notes")
  )
  expect_gt(nrow(caps), 0L)
})

test_that("capability_check() returns Stable invisibly for drmTMB/gaussian/mu", {
  expect_invisible(symbolizer:::capability_check("drmTMB", "gaussian", "mu"))
  status <- withVisible(symbolizer:::capability_check("drmTMB", "gaussian", "mu"))
  expect_equal(status$value, "Stable")
  expect_false(status$visible)
})

test_that("capability_check() returns Stable for drmTMB/gaussian/sigma", {
  status <- withVisible(symbolizer:::capability_check("drmTMB", "gaussian", "sigma"))
  expect_equal(status$value, "Stable")
  expect_false(status$visible)
})

test_that("capability_check() returns First slice for drmTMB random effects", {
  status <- withVisible(
    symbolizer:::capability_check("drmTMB", "gaussian", "random_effects")
  )
  expect_equal(status$value, "First slice")
  expect_false(status$visible)
})

test_that("capability_check() rejects drmTMB/gaussian/zi (Planned)", {
  expect_snapshot(
    error = TRUE,
    symbolizer:::capability_check("drmTMB", "gaussian", "zi")
  )
})

test_that("capability_check() rejects sdmTMB/binomial/mu (Planned) via wildcard", {
  expect_snapshot(
    error = TRUE,
    symbolizer:::capability_check("sdmTMB", "binomial", "mu")
  )
})

test_that("capability_check() errors when no entry exists at all", {
  expect_snapshot(
    error = TRUE,
    symbolizer:::capability_check("nonexistent", "weird", "thing")
  )
})

test_that("specific rows are preferred over wildcard rows", {
  # Both `drmTMB/gaussian/mu` (Stable, specific) and broader wildcard rows
  # could theoretically match. The specific row must win, so the returned
  # status is "Stable" rather than any wildcard status.
  status <- withVisible(symbolizer:::capability_check("drmTMB", "gaussian", "mu"))
  expect_equal(status$value, "Stable")
})
