test_that("load_template('capabilities') returns a non-empty tibble", {
  tbl <- symbolizer:::load_template("capabilities")
  expect_s3_class(tbl, "tbl_df")
  expect_gt(nrow(tbl), 0L)
})

test_that("load_template() caches: second call returns the identical object", {
  first <- symbolizer:::load_template("capabilities")
  second <- symbolizer:::load_template("capabilities")
  expect_true(identical(first, second))
})

test_that("clear_template_cache() empties the cache", {
  # Warm the cache, then clear and confirm the env has no bindings.
  symbolizer:::load_template("capabilities")
  symbolizer:::clear_template_cache()
  expect_length(ls(envir = symbolizer:::.symbolizer_template_cache), 0L)
})

test_that("load_template() errors for a missing CSV", {
  expect_snapshot(
    error = TRUE,
    symbolizer:::load_template("definitely-does-not-exist")
  )
})
