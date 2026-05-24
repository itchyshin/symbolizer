test_that("symbolize.drmTMB returns a valid symbolized_model", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(
    fit,
    symbols = c(body_mass = "W_i", temperature = "T_i"),
    units   = c(body_mass = "g", temperature = "C"),
    context = "avian body-size location-scale model"
  )
  expect_s3_class(sym, "symbolized_model")
  expect_silent(symbolizer:::validate_symbolized_model(sym))
})

test_that("model metadata captures class, package, family, response, n_obs", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  expect_equal(sym$model$class, "drmTMB")
  expect_equal(sym$model$package, "drmTMB")
  expect_equal(sym$model$family, "gaussian")
  expect_equal(sym$model$response, "body_mass")
  expect_equal(sym$model$n_obs, 80L)
})

test_that("submodels carries one row per dpar with correct links", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  expect_equal(sym$submodels$parameter, c("mu", "sigma"))
  expect_equal(sym$submodels$link,      c("identity", "log"))
  expect_equal(sym$submodels$coef_family, c("beta", "gamma"))
})

test_that("terms uses beta for mu and gamma for sigma", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  mu_terms <- sym$terms[sym$terms$submodel == "mu", , drop = FALSE]
  sg_terms <- sym$terms[sym$terms$submodel == "sigma", , drop = FALSE]
  expect_equal(mu_terms$coefficient_symbol, c("\\beta_{0}",  "\\beta_{1}"))
  expect_equal(sg_terms$coefficient_symbol, c("\\gamma_{0}", "\\gamma_{1}"))
})

test_that("fixed_effects join coefficient estimates from drmTMB", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  fe <- sym$fixed_effects
  expect_equal(nrow(fe), 4L)
  expect_true(all(!is.na(fe$estimate)))
  expected_mu    <- unname(drmTMB::fixef(fit, dpar = "mu"))
  expected_sigma <- unname(drmTMB::fixef(fit, dpar = "sigma"))
  expect_equal(fe$estimate[fe$submodel == "mu"],    expected_mu)
  expect_equal(fe$estimate[fe$submodel == "sigma"], expected_sigma)
})

test_that("symbol_dictionary includes response, predictors, parameters, coefficients", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit,
                   symbols = c(body_mass = "W_i", temperature = "T_i"),
                   units   = c(body_mass = "g", temperature = "C"))
  d <- sym$symbol_dictionary
  expect_true("W_i" %in% d$symbol)
  expect_true("T_i" %in% d$symbol)
  expect_true(any(d$role == "parameter"   & d$symbol == "\\mu_i"))
  expect_true(any(d$role == "parameter"   & d$symbol == "\\sigma_i"))
  expect_true(any(d$role == "coefficient" & grepl("beta",  d$symbol)))
  expect_true(any(d$role == "coefficient" & grepl("gamma", d$symbol)))
  expect_equal(d$units[d$variable %in% "body_mass"],   "g")
  expect_equal(d$units[d$variable %in% "temperature"], "C")
})

test_that("factor rows in symbol_table mark the reference level", {
  set.seed(1)
  n <- 60
  dat <- data.frame(
    body_mass = rnorm(n, 30),
    sex = factor(rep(c("female", "male"), length.out = n)),
    site = factor(rep(letters[1:3], length.out = n))
  )
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ sex + site, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  d <- sym$symbol_dictionary
  sex_row <- d[d$variable == "sex" & !is.na(d$variable), , drop = FALSE]
  expect_match(sex_row$description, "female \\[reference\\]")
  site_row <- d[d$variable == "site" & !is.na(d$variable), , drop = FALSE]
  expect_match(site_row$description, "a \\[reference\\]")
  expect_match(site_row$description, "b, c")
})

test_that("components has distribution + one linear predictor per submodel", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  expect_equal(sym$components$name,
               c("distribution", "mu_linear_predictor", "sigma_linear_predictor"))
  expect_match(sym$components$equation[[1L]], "W_i \\\\mid \\\\mu_i")
  expect_match(sym$components$equation[[2L]], "^\\\\mu_i =")
  expect_match(sym$components$equation[[3L]], "^\\\\log\\(\\\\sigma_i\\) =")
})

test_that("assumptions templates substitute response and response_symbol", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i"))
  a <- sym$assumptions
  cd <- a$expression_latex[a$assumption == "conditional_distribution"]
  expect_match(cd, "W_i \\\\mid \\\\mu_i")
  ind <- a$expression_latex[a$assumption == "independence"]
  expect_match(ind, "W_i \\\\perp W_j")
  meaning_cd <- a$biological_meaning[a$assumption == "conditional_distribution"]
  expect_match(meaning_cd, "body_mass")
})

test_that("assumptions without RE use plain conditional independence", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i"))
  a <- sym$assumptions
  expect_true("independence" %in% a$assumption)
  expect_false("independence_given_random_effects" %in% a$assumption)
})

test_that("assumptions with RE swap in independence_given_random_effects", {
  fit_re <- fit_drm_with_re()
  sym <- symbolize(fit_re, symbols = c(body_mass = "W_i"))
  a <- sym$assumptions
  expect_true("independence_given_random_effects" %in% a$assumption)
  expect_false("independence" %in% a$assumption)
  meaning <- a$biological_meaning[a$assumption == "independence_given_random_effects"]
  expect_match(meaning, "random effects")
  expr <- a$expression_latex[a$assumption == "independence_given_random_effects"]
  expect_match(expr, "\\\\mathbf\\{u\\}")
})

test_that("interpretation has one row per coefficient with templated readings", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  interp <- sym$interpretation
  expect_equal(nrow(interp), 4L)
  expect_setequal(unique(interp$coefficient_role), c("intercept", "slope"))
  slope_mu <- interp[interp$submodel == "mu" & interp$coefficient_role == "slope", , drop = FALSE]
  expect_match(slope_mu$natural_scale_reading, "body_mass")
  expect_match(slope_mu$natural_scale_reading, "temperature")
  slope_sg <- interp[interp$submodel == "sigma" & interp$coefficient_role == "slope", , drop = FALSE]
  expect_match(slope_sg$variance_scale_reading, "exp\\(2\\*")
})

test_that("transformation predictors get interpretation rows on mu", {
  testthat::skip_if_not_installed("drmTMB")
  set.seed(42L)
  n <- 80L
  temperature <- runif(n, 10, 25)
  food <- rlnorm(n, log(5), 0.4)
  dat <- data.frame(
    body_mass = rnorm(n, 5 + 0.4 * temperature + 2 * log(food), 1),
    temperature = temperature,
    food = food
  )
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ temperature + log(food),
                        sigma ~ temperature),
    family = stats::gaussian(),
    data   = dat
  )
  sym <- symbolize(fit)
  expect_true(any(sym$interpretation$term_label == "log(food)"))
  log_row <- sym$interpretation[
    sym$interpretation$term_label == "log(food)", , drop = FALSE
  ]
  expect_equal(log_row$coefficient_role, "transformation")
  expect_match(log_row$natural_scale_reading, "log\\(food\\)")
  expect_match(log_row$biological_reading, "log\\(food\\)")
  expect_match(log_row$link_scale_reading, "log\\(food\\)")
})

test_that("formula_bridge has one row per submodel mapping R to math", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, symbols = c(body_mass = "W_i", temperature = "T_i"))
  br <- sym$formula_bridge
  expect_equal(br$submodel, c("mu", "sigma"))
  expect_match(br$r_syntax[[1L]], "body_mass ~ temperature")
  expect_match(br$r_syntax[[2L]], "sigma ~ temperature")
  expect_match(br$mathematics[[1L]], "^\\\\mu_i =")
  expect_match(br$mathematics[[2L]], "^\\\\log\\(\\\\sigma_i\\) =")
})

test_that("metadata captures call, context, package versions, created_by", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, context = "test context")
  expect_equal(sym$metadata$context, "test context")
  expect_equal(sym$metadata$created_by, "symbolize.drmTMB")
  expect_true(!is.null(sym$metadata$call))
  expect_true(!is.null(sym$metadata$package_versions$symbolizer))
})

test_that("random intercepts gate via capability_check and populate RE/VC", {
  fit_re <- fit_drm_with_re()
  sym <- symbolize(
    fit_re,
    symbols = c(body_mass = "W_i", temperature = "T_i")
  )
  expect_s3_class(sym, "symbolized_model")
  expect_true(!is.null(sym$random_effects))
  expect_true(!is.null(sym$variance_components))
  expect_equal(sym$random_effects$group_var, "group")
  expect_equal(sym$random_effects$n_levels, 6L)
  expect_equal(sym$variance_components$group_var, "group")
  expect_match(sym$variance_components$symbol, "\\\\sigma_\\{group\\}")
})

test_that("random intercept appears in mu linear predictor (both notations)", {
  fit_re <- fit_drm_with_re()
  sym <- symbolize(fit_re, symbols = c(body_mass = "W_i", temperature = "T_i"))
  mu_row <- sym$components[sym$components$kind == "linear_predictor" &
                             sym$components$submodel == "mu", , drop = FALSE]
  expect_match(mu_row$equation, "u_\\{group\\(i\\)\\}")
  expect_match(mu_row$equation_matrix, "\\\\mathbf\\{u\\}")
  # RE distribution row should be present.
  re_dist <- sym$components[sym$components$kind == "random_effect_distribution", , drop = FALSE]
  expect_equal(nrow(re_dist), 1L)
  expect_match(re_dist$equation, "u_\\{group\\} \\\\sim \\\\mathcal\\{N\\}")
  expect_match(re_dist$equation_matrix, "\\\\mathbf\\{u\\}_\\{group\\}")
  expect_match(re_dist$equation_matrix, "\\\\mathbf\\{I\\}_\\{6\\}")
})

test_that("symbol dictionary lists RE intercept and variance component", {
  fit_re <- fit_drm_with_re()
  sym <- symbolize(fit_re, symbols = c(body_mass = "W_i", temperature = "T_i"))
  d <- sym$symbol_dictionary
  expect_true(any(d$role == "random_intercept"))
  expect_true(any(d$role == "variance_component"))
  vc <- d[d$role == "variance_component", , drop = FALSE]
  expect_match(vc$symbol, "\\\\sigma_\\{group\\}")
  ri <- d[d$role == "random_intercept", , drop = FALSE]
  expect_match(ri$symbol, "u_\\{group\\(i\\)\\}")
  expect_match(ri$symbol_matrix, "\\\\mathbf\\{u\\}_\\{group\\}")
})

test_that("fixed-effects extraction still works correctly with RE present", {
  fit_re <- fit_drm_with_re()
  sym <- symbolize(fit_re)
  # The fixed-effects rows should be unchanged by RE -- RE was stripped before extract_terms.
  expect_equal(nrow(sym$fixed_effects), 4L)
  expected_mu <- unname(drmTMB::fixef(fit_re, dpar = "mu"))
  fe_mu <- sym$fixed_effects[sym$fixed_effects$submodel == "mu", , drop = FALSE]
  expect_equal(fe_mu$estimate, expected_mu)
})

test_that("random slopes still raise a clear error pointing at status", {
  # We can't easily build a real fit with (x | group) without drmTMB support,
  # but the parser-level check is unit-testable.
  expect_error(
    symbolizer:::drm_assert_supported_re(
      tibble::tibble(
        submodel = "mu",
        term_label = "(temperature | group)",
        lhs_expr = "temperature",
        group_var = "group",
        n_levels = 6L
      ),
      "mu"
    ),
    "intercept-only random effects"
  )
})

test_that("RE on sigma submodel raises a clear error", {
  expect_error(
    symbolizer:::drm_assert_supported_re(
      tibble::tibble(
        submodel = "sigma",
        term_label = "(1 | group)",
        lhs_expr = "1",
        group_var = "group",
        n_levels = 6L
      ),
      "sigma"
    ),
    "mu submodel only"
  )
})

test_that("default method still errors for unsupported classes", {
  expect_error(symbolize(structure(list(), class = "no_method")),
               "no method")
})

test_that("S3: interaction templates point at group_slopes / group_means", {
  set.seed(1); n <- 120
  dat <- data.frame(
    body_mass = rnorm(n, 30),
    sex = factor(rep(c("female", "male"), length.out = n)),
    site = factor(rep(letters[1:3], length.out = n)),
    body_size = rnorm(n)
  )
  # cont x factor
  fit_cf <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ sex * body_size, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym_cf <- symbolize(fit_cf)
  cf_row <- sym_cf$interpretation[
    sym_cf$interpretation$coefficient_role == "interaction_cont_factor", ,
    drop = FALSE
  ]
  expect_match(cf_row$biological_reading[[1L]], "group_slopes", fixed = TRUE)
  # factor x factor
  fit_ff <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ site * sex, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym_ff <- symbolize(fit_ff)
  ff_row <- sym_ff$interpretation[
    sym_ff$interpretation$coefficient_role == "interaction_factor_factor", ,
    drop = FALSE
  ]
  expect_match(ff_row$biological_reading[[1L]], "group_means", fixed = TRUE)
})

test_that("S4: intercept-less factor fit gets cell-means description + cell_mean reading", {
  set.seed(1); n <- 80
  dat <- data.frame(
    body_mass = rnorm(n, 30),
    sex = factor(rep(c("female", "male"), length.out = n))
  )
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ 0 + sex, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  # symbol_table marks the factor row as cell-means rather than [reference]
  sex_row <- sym$symbol_dictionary[
    sym$symbol_dictionary$variable == "sex" &
      !is.na(sym$symbol_dictionary$variable), , drop = FALSE
  ]
  expect_match(sex_row$description, "cell-means")
  expect_false(grepl("[reference]", sex_row$description, fixed = TRUE))
  # interpretation rows for the factor use cell_mean coefficient_role
  cm_rows <- sym$interpretation[
    sym$interpretation$coefficient_role == "cell_mean", , drop = FALSE
  ]
  expect_equal(nrow(cm_rows), 2L)
  expect_match(cm_rows$natural_scale_reading[[1L]], "Expected body_mass")
  expect_match(cm_rows$biological_reading[[1L]], "cell-means")
})

test_that("S4: intercept-FULL fit still uses factor_contrast role and [reference] marker", {
  set.seed(1); n <- 80
  dat <- data.frame(
    body_mass = rnorm(n, 30),
    sex = factor(rep(c("female", "male"), length.out = n))
  )
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ sex, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  sex_row <- sym$symbol_dictionary[
    sym$symbol_dictionary$variable == "sex" &
      !is.na(sym$symbol_dictionary$variable), , drop = FALSE
  ]
  expect_match(sex_row$description, "\\[reference\\]")
  expect_false(grepl("cell-means", sex_row$description, fixed = TRUE))
  expect_true(any(sym$interpretation$coefficient_role == "factor_contrast"))
  expect_false(any(sym$interpretation$coefficient_role == "cell_mean"))
})

test_that("factor_contrast interpretation surfaces the reference level by name", {
  set.seed(1); n <- 80
  dat <- data.frame(
    body_mass = rnorm(n, 30),
    sex = factor(rep(c("female", "male"), length.out = n))
  )
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ sex, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  fc <- sym$interpretation[sym$interpretation$coefficient_role == "factor_contrast", , drop = FALSE]
  expect_true(nrow(fc) >= 1L)
  expect_match(fc$biological_reading[[1L]], "female", fixed = TRUE)
})

test_that("continuous x factor interaction gets a biological reading", {
  set.seed(2); n <- 120
  body_size <- rnorm(n)
  sex <- factor(rep(c("female", "male"), length.out = n))
  body_mass <- 30 + 2 * body_size + 3 * (sex == "male") + 1.5 * body_size * (sex == "male") + rnorm(n)
  dat <- data.frame(body_mass = body_mass, sex = sex, body_size = body_size)
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ sex * body_size, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  interaction_rows <- sym$interpretation[sym$interpretation$coefficient_role == "interaction_cont_factor", , drop = FALSE]
  expect_true(nrow(interaction_rows) >= 1L)
  expect_match(interaction_rows$biological_reading[[1L]], "differs by")
})

test_that("S1: fixed_effects + interpretation carry confidence band columns", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit)
  # All new columns present in both fixed_effects and interpretation
  fe_cols <- names(sym$fixed_effects)
  expect_true(all(c("std_error", "confint_low", "confint_high",
                    "excludes_zero", "ci_method") %in% fe_cols))
  ip_cols <- names(sym$interpretation)
  expect_true(all(c("std_error", "confint_low", "confint_high",
                    "excludes_zero", "ci_method") %in% ip_cols))
  # Default ci_method is wald; stored on metadata
  expect_equal(sym$metadata$ci_method, "wald")
  expect_true(all(sym$interpretation$ci_method == "wald"))
  # On this fit (strong predictor) most rows should exclude zero
  expect_true(any(sym$interpretation$excludes_zero))
  # Wald SE recoverable from the symmetric band
  fe <- sym$fixed_effects
  recovered <- (fe$confint_high - fe$confint_low) / (2 * stats::qnorm(0.975))
  expect_equal(fe$std_error, recovered, tolerance = 1e-8)
})

test_that("S1: ci_method = 'profile' produces non-NA bounds and is recorded", {
  fit <- fit_drm_location_scale()
  sym <- symbolize(fit, ci_method = "profile")
  expect_equal(sym$metadata$ci_method, "profile")
  expect_true(all(sym$interpretation$ci_method == "profile"))
  # Profile CIs are asymmetric; std_error is left NA by design
  expect_true(all(is.na(sym$fixed_effects$std_error)))
  # But the bounds themselves are non-NA
  expect_true(all(!is.na(sym$fixed_effects$confint_low)))
  expect_true(all(!is.na(sym$fixed_effects$confint_high)))
})

test_that("interaction-row estimate is looked up correctly and matches drmTMB::fixef", {
  # Regression test for a previous bug: drm_build_fixed_effects() looked up
  # interaction rows by term_label ("sex:body_size") but drmTMB names the
  # column with the contrast level appended ("sexmale:body_size"). Fixed in
  # 387ca84. This test pins that the lookup stays correct.
  set.seed(2); n <- 120
  dat <- data.frame(
    body_mass = rnorm(n, 30),
    sex = factor(rep(c("female", "male"), length.out = n)),
    body_size = rnorm(n)
  )
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ sex * body_size, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  ir <- sym$fixed_effects[sym$fixed_effects$role == "interaction", , drop = FALSE]
  expect_equal(nrow(ir), 1L)
  expect_false(is.na(ir$estimate))
  expected <- unname(drmTMB::fixef(fit, dpar = "mu")["sexmale:body_size"])
  expect_equal(ir$estimate, expected)
})

test_that("factor x factor interaction gets a difference-of-differences reading", {
  set.seed(3); n <- 120
  site <- factor(rep(letters[1:3], length.out = n))
  sex <- factor(rep(c("female", "male"), length.out = n))
  body_mass <- rnorm(n, 30)
  dat <- data.frame(body_mass = body_mass, site = site, sex = sex)
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ site * sex, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  ff <- sym$interpretation[sym$interpretation$coefficient_role == "interaction_factor_factor", , drop = FALSE]
  expect_true(nrow(ff) >= 1L)
  expect_match(ff$biological_reading[[1L]], "differs by")
})

test_that("biv_gaussian fit symbolizes with two responses, two mus, two sigmas, and rho12", {
  fit <- fit_drm_biv_gaussian()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  # Submodels should include the bivariate dpars
  expect_true(all(c("mu1", "mu2", "sigma1", "sigma2", "rho12") %in% sym$submodels$parameter))
  # Symbol dictionary should carry the two responses and rho12
  d <- sym$symbol_dictionary
  expect_true(any(grepl("rho_{12", d$symbol, fixed = TRUE)) ||
              any(grepl("rho12", d$symbol, fixed = TRUE)))
  # An assumption table row for the residual decomposition (the Sigma_i form)
  expect_true(any(sym$assumptions$assumption == "residual_decomposition"))
  # Interpretation should have a rho12 intercept reading
  expect_true(any(sym$interpretation$submodel == "rho12"))
})

test_that("biv_gaussian: links are recorded per dpar (atanh_guarded on rho12)", {
  fit <- fit_drm_biv_gaussian()
  sym <- symbolize(fit)
  s <- sym$submodels
  expect_equal(s$link[s$parameter == "mu1"], "identity")
  expect_equal(s$link[s$parameter == "mu2"], "identity")
  expect_equal(s$link[s$parameter == "sigma1"], "log")
  expect_equal(s$link[s$parameter == "sigma2"], "log")
  expect_equal(s$link[s$parameter == "rho12"], "atanh_guarded")
})

test_that("biv_gaussian: fixed_effects join coefficient estimates from drmTMB", {
  fit <- fit_drm_biv_gaussian()
  sym <- symbolize(fit)
  fe <- sym$fixed_effects
  # mu1 has 2 coefs, mu2 has 2 coefs, sigma1/sigma2/rho12 each have 1 = 7
  expect_equal(nrow(fe), 7L)
  expect_true(all(!is.na(fe$estimate)))
  expect_equal(fe$estimate[fe$submodel == "mu1"],
               unname(drmTMB::fixef(fit, dpar = "mu1")))
  expect_equal(fe$estimate[fe$submodel == "rho12"],
               unname(drmTMB::fixef(fit, dpar = "rho12")))
})

test_that("biv_gaussian: components include the Sigma_i decomposition row", {
  fit <- fit_drm_biv_gaussian()
  sym <- symbolize(fit)
  decomp <- sym$components[sym$components$kind == "covariance_decomposition", , drop = FALSE]
  expect_equal(nrow(decomp), 1L)
  expect_match(decomp$equation, "\\\\Sigma_i =")
  expect_match(decomp$equation, "\\\\begin\\{pmatrix\\}")
  expect_match(decomp$equation, "\\\\rho_\\{12,i\\}")
})

test_that("biv_gaussian: distribution row uses MVN_2 with both responses", {
  fit <- fit_drm_biv_gaussian()
  sym <- symbolize(fit)
  expect_equal(sym$distribution$family, "biv_gaussian")
  expect_match(sym$distribution$latex, "\\\\mathcal\\{N\\}_2")
  expect_match(sym$distribution$latex, "\\\\Sigma_i")
})

test_that("biv_gaussian: linear predictors use atanh^{-1} on rho12", {
  fit <- fit_drm_biv_gaussian()
  sym <- symbolize(fit)
  rho_row <- sym$components[sym$components$kind == "linear_predictor" &
                              sym$components$submodel == "rho12", , drop = FALSE]
  expect_equal(nrow(rho_row), 1L)
  expect_match(rho_row$equation, "\\\\mathrm\\{tanh\\}\\^\\{-1\\}\\(\\\\rho_\\{12,i\\}\\)")
})

test_that("biv_gaussian: model$responses captures both response variable names", {
  fit <- fit_drm_biv_gaussian()
  sym <- symbolize(fit)
  expect_equal(sym$model$family, "biv_gaussian")
  expect_equal(sym$model$responses, c("y1", "y2"))
})

test_that("biv_gaussian: assumption rows present and substituted with responses", {
  fit <- fit_drm_biv_gaussian()
  sym <- symbolize(fit)
  a <- sym$assumptions
  expect_true("conditional_distribution" %in% a$assumption)
  expect_true("residual_decomposition" %in% a$assumption)
  expect_true("independence_across_observations" %in% a$assumption)
  expect_true("linear_predictor_rho12" %in% a$assumption)
  # response_1 / response_2 substitution worked
  cd_meaning <- a$biological_meaning[a$assumption == "conditional_distribution"]
  expect_match(cd_meaning, "y1")
  expect_match(cd_meaning, "y2")
})

test_that("biv_gaussian: interpretation has separate rows per submodel and rho12 mentions tanh", {
  fit <- fit_drm_biv_gaussian()
  sym <- symbolize(fit)
  interp <- sym$interpretation
  expect_true(all(c("mu1", "mu2", "sigma1", "sigma2", "rho12") %in% interp$submodel))
  rho_intercept <- interp[interp$submodel == "rho12" &
                            interp$coefficient_role == "intercept", , drop = FALSE]
  expect_equal(nrow(rho_intercept), 1L)
  expect_match(rho_intercept$natural_scale_reading, "tanh")
  # mu1 reading should mention y1 (not y2)
  mu1_int <- interp[interp$submodel == "mu1" &
                      interp$coefficient_role == "intercept", , drop = FALSE]
  expect_match(mu1_int$biological_reading, "y1", fixed = TRUE)
  mu2_int <- interp[interp$submodel == "mu2" &
                      interp$coefficient_role == "intercept", , drop = FALSE]
  expect_match(mu2_int$biological_reading, "y2", fixed = TRUE)
})

test_that("biv_gaussian: formula_bridge has one row per dpar with bivariate meanings", {
  fit <- fit_drm_biv_gaussian()
  sym <- symbolize(fit)
  br <- sym$formula_bridge
  expect_equal(br$submodel, c("mu1", "mu2", "sigma1", "sigma2", "rho12"))
  expect_match(br$statistical_meaning[br$submodel == "mu1"], "y1")
  expect_match(br$statistical_meaning[br$submodel == "mu2"], "y2")
  expect_match(br$statistical_meaning[br$submodel == "rho12"], "correlation")
})
