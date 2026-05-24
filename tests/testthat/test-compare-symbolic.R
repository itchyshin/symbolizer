test_that("compare_symbolic errors helpfully on non-symbolized input", {
  expect_error(
    compare_symbolic(list(), list()),
    "has no method"
  )
})

test_that("compare_symbolic on symbolized_model needs a second symbolized_model", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  expect_error(
    compare_symbolic(sym, list()),
    "must also be a"
  )
})

test_that("compare_symbolic returns the four-slot S3 list", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  cmp <- compare_symbolic(sym, sym)
  expect_s3_class(cmp, "symbolic_comparison")
  expect_named(cmp,
               c("meta", "diff_submodels", "diff_terms", "diff_assumptions"))
  expect_named(cmp$meta, c("left", "right"))
})

test_that("comparing a fit with itself yields all 'both' presence and same statuses", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  cmp <- compare_symbolic(sym, sym)
  expect_true(all(cmp$diff_submodels$presence == "both"))
  expect_true(all(cmp$diff_terms$presence == "both"))
  expect_true(all(cmp$diff_assumptions$same_status))
})

test_that("comparing two univariate fits picks up the new submodel terms", {
  fit_a <- fit_drm_location_scale()  # mu ~ temperature, sigma ~ temperature
  sym_a <- symbolize(fit_a)
  # A second fit with only a mu intercept and a sigma intercept; same submodels
  # exist but different term sets.
  set.seed(33L)
  dat <- data.frame(body_mass = rnorm(60L, 30, 2))
  fit_b <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ 1, sigma ~ 1),
    family = stats::gaussian(),
    data   = dat
  )
  sym_b <- symbolize(fit_b)
  cmp <- compare_symbolic(sym_a, sym_b)
  expect_setequal(cmp$diff_submodels$submodel, c("mu", "sigma"))
  expect_true(all(cmp$diff_submodels$presence == "both"))
  # temperature is on the left only, in both mu and sigma submodels:
  left_only_terms <- cmp$diff_terms[cmp$diff_terms$presence == "left_only", ]
  expect_true(all(c("mu", "sigma") %in% unique(left_only_terms$submodel)))
  expect_true(any(grepl("temperature", left_only_terms$term_label)))
})

test_that("comparing univariate vs bivariate Gaussian flags disjoint submodels", {
  fit_uv <- fit_drm_location_scale()
  sym_uv <- symbolize(fit_uv)
  fit_bv <- fit_drm_biv_gaussian()
  sym_bv <- symbolize(fit_bv)
  cmp <- compare_symbolic(sym_uv, sym_bv)
  # Univariate has mu, sigma; bivariate has mu1, mu2, sigma1, sigma2, rho12.
  # No submodel name overlaps; everything should be left_only or right_only.
  expect_true(all(cmp$diff_submodels$presence %in% c("left_only", "right_only")))
  expect_setequal(
    cmp$diff_submodels$submodel[cmp$diff_submodels$presence == "left_only"],
    c("mu", "sigma")
  )
  expect_setequal(
    cmp$diff_submodels$submodel[cmp$diff_submodels$presence == "right_only"],
    c("mu1", "mu2", "sigma1", "sigma2", "rho12")
  )
  # Families differ:
  expect_equal(cmp$meta$left$family,  "gaussian")
  expect_equal(cmp$meta$right$family, "biv_gaussian")
})

test_that("comparing a fit with RE vs one without flips the independence assumption status", {
  fit_no_re <- fit_drm_location_scale()
  fit_re    <- fit_drm_with_re()
  sym_no_re <- symbolize(fit_no_re)
  sym_re    <- symbolize(fit_re)
  cmp <- compare_symbolic(sym_no_re, sym_re)
  expect_true("independence" %in% cmp$diff_assumptions$assumption ||
              "independence_given_random_effects" %in% cmp$diff_assumptions$assumption)
  # At least one assumption should NOT have same_status (one side gets the
  # plain independence row, the other gets the conditional row):
  expect_true(any(!cmp$diff_assumptions$same_status))
})

test_that("print.symbolic_comparison runs without error and emits cli output", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  cmp <- compare_symbolic(sym, sym)
  # cli::cli_* writes to stderr, captured by expect_message via the
  # standard cli sink.
  msgs <- testthat::capture_messages(print(cmp))
  out <- paste(msgs, collapse = "")
  expect_match(out, "Symbolic comparison")
  expect_match(out, "Model summaries")
})

test_that("knit_print.symbolic_comparison returns markdown asis_output", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  cmp <- compare_symbolic(sym, sym)
  out <- knitr::knit_print(cmp)
  expect_s3_class(out, "knit_asis")
  expect_match(as.character(out), "Model summaries", fixed = TRUE)
  expect_match(as.character(out), "Submodels",       fixed = TRUE)
})
