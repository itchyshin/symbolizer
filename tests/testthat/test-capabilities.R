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

test_that("every status word is one of the five canonical values", {
  # Invariant from VISION.md / AGENTS.md: the only legal status words are the
  # five below. Guards against near-misses like a bare "Unsupported" (missing
  # "or blocked") or "Planned" silently entering capabilities.csv.
  allowed <- c(
    "Stable", "First slice", "Opt-in control",
    "Planned or reserved", "Unsupported or blocked"
  )
  caps <- symbolizer_capabilities()
  expect_true(all(caps$status %in% allowed),
              info = paste("Unexpected status word(s):",
                           paste(setdiff(unique(caps$status), allowed),
                                 collapse = ", ")))
})

test_that("the 'today we can read' message advertises brms / metafor phylo support", {
  # Design note (guards against a recurring audit false-positive): a handful
  # of rows are keyed on the *friendly* class name (`brms`, `metafor`) with a
  # conceptual component (`phylo`, `meta_phylo_multilevel`) so the rejection
  # message advertises that capability under the name users recognise. These
  # are NOT gate rows -- the gate dispatches brms via `brmsfit` and metafor via
  # `rma.mv` / `rma.uni`, using components like `random_effects` / `structured`.
  # They are intentional advertisement twins of the gate-reachable drmTMB rows.
  bullets <- symbolizer:::capability_today_bullets(symbolizer_capabilities())
  joined  <- paste(bullets, collapse = "\n")
  expect_match(joined, "brms", fixed = TRUE)
  expect_match(joined, "metafor", fixed = TRUE)
})
