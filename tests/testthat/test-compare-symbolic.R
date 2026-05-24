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

test_that("metrics = TRUE adds a diff_metrics slot with the expected columns", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  cmp <- compare_symbolic(sym, sym, metrics = TRUE)
  expect_true("diff_metrics" %in% names(cmp))
  expect_named(cmp$diff_metrics, c("metric", "left", "right", "delta"))
  expect_setequal(cmp$diff_metrics$metric, c("AIC", "BIC", "logLik", "df"))
  expect_true(isTRUE(attr(cmp$diff_metrics, "comparable")))
  # Self-comparison: every delta should be 0.
  expect_true(all(cmp$diff_metrics$delta == 0))
})

test_that("metrics with different terms produces non-trivial deltas", {
  # Build a shared data frame once and fit two models on it so the n_obs,
  # family, and response all match — the strict ML comparison criterion.
  set.seed(33L); n <- 80L
  dat <- data.frame(
    body_mass   = rnorm(n, 30 + 0.4 * runif(n, 10, 25), 2),
    temperature = runif(n, 10, 25)
  )
  fit_full <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ temperature, sigma ~ temperature),
    family = stats::gaussian(), data = dat
  )
  fit_int <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ 1, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym_full <- symbolize(fit_full)
  sym_int  <- symbolize(fit_int)
  cmp <- compare_symbolic(sym_full, sym_int, metrics = TRUE)
  expect_true(isTRUE(attr(cmp$diff_metrics, "comparable")))
  expect_true(is.na(attr(cmp$diff_metrics, "note")))
  # df differs (full has 4 params, intercept-only has 2):
  df_row <- cmp$diff_metrics[cmp$diff_metrics$metric == "df", ]
  expect_true(df_row$left > df_row$right)
  expect_equal(df_row$delta, df_row$right - df_row$left)
})

test_that("metrics with mismatched n_obs returns incomparable", {
  fit_a <- fit_drm_location_scale()
  set.seed(99L); n <- 40L
  dat_small <- data.frame(
    body_mass   = rnorm(n, 30, 2),
    temperature = runif(n, 10, 25)
  )
  fit_b <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ temperature, sigma ~ 1),
    family = stats::gaussian(), data = dat_small
  )
  sym_a <- symbolize(fit_a)
  sym_b <- symbolize(fit_b)
  cmp <- compare_symbolic(sym_a, sym_b, metrics = TRUE)
  expect_false(isTRUE(attr(cmp$diff_metrics, "comparable")))
  expect_match(attr(cmp$diff_metrics, "note"), "n_obs differs", fixed = TRUE)
  expect_true(all(is.na(cmp$diff_metrics$delta)))
})

test_that("metrics with mismatched family returns incomparable", {
  fit_uv <- fit_drm_location_scale()
  fit_bv <- fit_drm_biv_gaussian()
  sym_uv <- symbolize(fit_uv)
  sym_bv <- symbolize(fit_bv)
  # n_obs may also differ; either way the family difference is the leading
  # incomparability. We only assert that the note flags an incomparability.
  cmp <- compare_symbolic(sym_uv, sym_bv, metrics = TRUE)
  expect_false(isTRUE(attr(cmp$diff_metrics, "comparable")))
  expect_match(attr(cmp$diff_metrics, "note"),
               "incomparable:", fixed = TRUE)
  expect_true(all(is.na(cmp$diff_metrics$delta)))
})

test_that("print.symbolic_comparison shows the Metrics section when present", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  cmp <- compare_symbolic(sym, sym, metrics = TRUE)
  msgs <- testthat::capture_messages(print(cmp))
  out <- paste(msgs, collapse = "")
  expect_match(out, "Metrics")
  expect_match(out, "AIC")
})

test_that("knit_print includes a metrics table when present", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  cmp <- compare_symbolic(sym, sym, metrics = TRUE)
  out <- knitr::knit_print(cmp)
  expect_match(as.character(out), "Metrics", fixed = TRUE)
  expect_match(as.character(out), "AIC",     fixed = TRUE)
})
