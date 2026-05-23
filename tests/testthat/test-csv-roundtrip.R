test_that("every inst/extdata CSV parses cleanly with read.csv", {
  ext_dir <- system.file("extdata", package = "symbolizer")
  if (!nzchar(ext_dir)) ext_dir <- file.path(testthat::test_path(), "..", "..", "inst", "extdata")
  csvs <- list.files(ext_dir, pattern = "\\.csv$", full.names = TRUE)
  expect_true(length(csvs) > 0L)
  for (f in csvs) {
    # Parse; expect no warning about column counts.
    expect_no_warning(utils::read.csv(f, stringsAsFactors = FALSE))
    df <- utils::read.csv(f, stringsAsFactors = FALSE)
    # Every row must have the same number of columns as the header (no NA-padding).
    expect_true(all(complete.cases(df) | rowSums(is.na(df)) <= 1L),
                info = paste("file:", basename(f)))
  }
})
