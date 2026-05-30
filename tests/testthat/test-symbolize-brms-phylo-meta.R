# Equation-fidelity tests for symbolize.brmsfit on the two structured
# surfaces the 2026-05-29 capability re-verify flagged as MAJOR:
#
#   (A) Phylo via gr(group, cov = A): the random-effect covariance must
#       carry the correlation matrix A, so the equation is NOT
#       indistinguishable from a plain iid (1 | g) intercept. Sibling
#       extractors (metafor, MCMCglmm) inject `sigma^2 A` into the RE
#       distribution line; brms must do the same.
#
#   (B) Meta-analytic se(...): a `bf(y | se(sqrt(vi)) ~ ...)` fit has a
#       KNOWN per-study sampling variance, so the conditional
#       distribution must render as the `meta_normal` known-variance form
#       `Normal(theta_i, v_i), v_i known`, NOT a freely-estimated
#       residual `Normal(mu_i, sigma_i^2)`.
#
# The live-fit assertions reuse the cached helper fixtures fit_brms_phylo()
# (pure phylo) and fit_brms_phylo_meta() (se + phylo + multilevel, the
# fixture that hits BOTH defects at once). A deterministic builder-level
# test exercises the structured-matrix wiring without a live fit.

# ---- (A) phylo: A must appear in the RE covariance -------------------------

test_that("brms pure-phylo RE distribution carries the A correlation matrix", {
  testthat::skip_on_cran()
  bundle <- fit_brms_phylo()
  sym <- symbolize(bundle$fit)
  tex <- as_latex(sym, notation = "index")
  # The phylo group's random-effect line must include \mathbf{A} in the
  # covariance and use the bold-vector joint form, not the scalar marginal.
  expect_match(
    tex,
    "\\mathbf{u}_{species} & \\sim \\mathcal{N}(\\mathbf{0},\\, \\sigma_{species}^2 \\mathbf{A})",
    fixed = TRUE
  )
  # Negative guard: it must NOT render the bare iid scalar form.
  expect_false(grepl(
    "u_{species} & \\sim \\mathcal{N}(0,\\, \\sigma_{species}^2)",
    tex,
    fixed = TRUE
  ))
})

test_that("brms phylo structured-matrix mapping is wired into components", {
  testthat::skip_on_cran()
  bundle <- fit_brms_phylo()
  sym <- symbolize(bundle$fit)
  re_dist <- sym$components[
    sym$components$kind == "random_effect_distribution", , drop = FALSE
  ]
  phylo_row <- re_dist[grepl("species", re_dist$name), , drop = FALSE]
  expect_gt(nrow(phylo_row), 0L)
  # Both index and matrix forms must reference A.
  expect_true(any(grepl("\\mathbf{A}", phylo_row$equation, fixed = TRUE)))
  expect_true(any(grepl("\\mathbf{A}", phylo_row$equation_matrix, fixed = TRUE)))
})

test_that("brms phylo + multilevel: only the phylo group gets A, plain group stays iid", {
  testthat::skip_on_cran()
  fit <- fit_brms_phylo_meta()
  sym <- symbolize(fit)
  tex <- as_latex(sym, notation = "index")
  # phylogeny is the gr(., cov = mat) tier -> gets A.
  expect_match(
    tex,
    "\\mathbf{u}_{phylogeny} & \\sim \\mathcal{N}(\\mathbf{0},\\, \\sigma_{phylogeny}^2 \\mathbf{A})",
    fixed = TRUE
  )
  # study_ID is a plain (1 | study_ID) tier -> stays scalar iid (no A).
  expect_match(
    tex,
    "u_{study_ID} & \\sim \\mathcal{N}(0,\\, \\sigma_{study_ID}^2)",
    fixed = TRUE
  )
})

# ---- (B) meta: se() must switch to the known-variance distribution --------

test_that("brms se(sqrt(vi)) fit renders the meta_normal known-variance distribution", {
  testthat::skip_on_cran()
  fit <- fit_brms_phylo_meta()
  sym <- symbolize(fit)
  # Family is remapped to meta_normal for rendering once se() is detected.
  expect_equal(sym$model$family, "meta_normal")
  tex <- as_latex(sym, notation = "index")
  # The conditional distribution line must show the KNOWN sampling
  # variance v_i, not a free residual sigma_i^2.
  expect_match(tex, "v_i \\text{ known}", fixed = TRUE)
  expect_match(tex, "\\mathrm{Normal}(\\theta_i,\\, v_i)", fixed = TRUE)
  # It must NOT render the freely-estimated Gaussian residual form.
  expect_false(grepl(
    "\\sim \\mathrm{Normal}(\\mu_i,\\, \\sigma_i^2)",
    tex,
    fixed = TRUE
  ))
})

test_that("brms meta context is still tagged and detection metadata preserved", {
  testthat::skip_on_cran()
  fit <- fit_brms_phylo_meta()
  sym <- symbolize(fit)
  expect_match(sym$metadata$context, "meta_analysis", fixed = TRUE)
  expect_true("phylo" %in% sym$metadata$detected_signals)
  expect_equal(sym$metadata$phylo_representation, "tips_only")
})

test_that("brms meta fit fires meta_normal known-sampling-variance assumption rows", {
  testthat::skip_on_cran()
  fit <- fit_brms_phylo_meta()
  sym <- symbolize(fit)
  a <- sym$assumptions
  expect_s3_class(a, "data.frame")
  # The meta_normal assumption template carries a known_sampling_variance
  # row; this is the prose-layer guarantee that v_i is an input, not a
  # parameter.
  expect_true("known_sampling_variance" %in% a$assumption)
})

# ---- builder-level deterministic test (no live fit) ------------------------

test_that("drm_build_components injects A for a brms-shaped structured group", {
  # Minimal drmTMB-shaped tibbles mirroring what symbolize.brmsfit builds
  # for y ~ 1 + (1 | gr(species, cov = A)). No brms fit required: this
  # locks the structured_matrix_for_group -> equation wiring directly.
  submodels <- tibble::tibble(
    parameter = "mu",
    formula = list(stats::as.formula("~ 1")),
    link = "identity",
    coef_family = "beta",
    position = 1L
  )
  terms_tbl <- tibble::tibble(
    submodel = "mu",
    term_label = "(Intercept)",
    variable = "(Intercept)",
    role = "intercept",
    contrast_level = NA_character_,
    transform = NA_character_,
    symbol = NA_character_,
    coefficient_symbol = "\\beta_{0}",
    latex_term = "\\beta_{0}"
  )
  re_tbl <- drm_build_random_effects(list(tibble::tibble(
    submodel = "mu",
    term_label = "(1 | species)",
    lhs_expr = "1",
    group_var = "species",
    component = "(Intercept)",
    n_levels = 8L
  )))
  comps_plain <- drm_build_components(
    submodels, terms_tbl, re_tbl,
    response_symbol = "y_i", response_symbol_matrix = "\\mathbf{y}",
    family = "gaussian"
  )
  comps_struct <- drm_build_components(
    submodels, terms_tbl, re_tbl,
    response_symbol = "y_i", response_symbol_matrix = "\\mathbf{y}",
    family = "gaussian",
    structured_matrix_for_group = list(species = "\\mathbf{A}")
  )
  re_plain <- comps_plain[comps_plain$kind == "random_effect_distribution", ]
  re_struct <- comps_struct[comps_struct$kind == "random_effect_distribution", ]
  # Without the mapping: bare iid scalar form, no A.
  expect_false(grepl("\\mathbf{A}", re_plain$equation, fixed = TRUE))
  # With the mapping: A appears in both index and matrix forms.
  expect_true(grepl("\\mathbf{A}", re_struct$equation, fixed = TRUE))
  expect_true(grepl("\\mathbf{A}", re_struct$equation_matrix, fixed = TRUE))
})
