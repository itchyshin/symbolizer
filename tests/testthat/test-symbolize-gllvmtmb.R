test_that("symbolize.gllvmTMB returns a valid symbolized_model", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(
    fit,
    symbols = c(value = "\\mathbf{Y}"),
    units   = c(value = "z-score"),
    context = "behavioural syndromes B-tier first slice"
  )
  expect_s3_class(sym, "symbolized_model")
  expect_silent(validate_symbolized_model(sym))
})

test_that("model metadata captures class, package, family, response, n_obs", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_equal(sym$model$class, "gllvmTMB")
  expect_equal(sym$model$package, "gllvmTMB")
  expect_equal(sym$model$family, "gaussian")
  expect_equal(sym$model$response, "value")
  expect_true(is.integer(sym$model$n_obs))
  # n_obs is the number of long-format rows.
  expect_true(sym$model$n_obs >= 30L)
  # response_dim captures unit/trait/latent shape.
  expect_equal(sym$model$response_dim$traits, 3L)
  expect_equal(sym$model$response_dim$units, 30L)
  expect_equal(sym$model$response_dim$latent, 1L)
})

test_that("submodels include mu and Lambda_B with correct links", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_equal(sym$submodels$parameter, c("mu", "Lambda_B"))
  expect_equal(sym$submodels$link, c("identity", "identity"))
  expect_equal(sym$submodels$coef_family, c("mu", "Lambda"))
})

test_that("terms carry per-trait intercept rows with mu_{trait} symbols", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_equal(nrow(sym$terms), 3L)
  expect_true(all(sym$terms$role == "trait_intercept"))
  expect_match(sym$terms$symbol, "^\\\\mu_\\{trait_[0-9]+\\}$")
})

test_that("fixed_effects join b_fix estimates from sd_report", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  fe <- sym$fixed_effects
  expect_equal(nrow(fe), 3L)
  expect_true(all(!is.na(fe$estimate)))
  # Estimates should match the b_fix row of summary(fit$sd_report, "fixed")
  ss <- summary(fit$sd_report, "fixed")
  bfix <- unname(ss[rownames(ss) == "b_fix", "Estimate"])
  expect_equal(fe$estimate, bfix)
})

test_that("loadings tibble has one row per (trait, axis) of Lambda_B", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_false(is.null(sym$loadings))
  expect_equal(nrow(sym$loadings), 3L)   # 3 traits x 1 axis
  expect_setequal(unique(sym$loadings$axis), "LV1")
  # Numeric estimates should match fit$report$Lambda_B
  L <- as.matrix(fit$report$Lambda_B)
  expect_equal(sym$loadings$estimate, as.numeric(L))
  # Loading symbols use \\lambda_{B,tk}
  expect_match(sym$loadings$symbol, "^\\\\lambda_\\{B,[0-9]+[0-9]+\\}$")
})

test_that("components has distribution + mu_lp + latent + implied_covariance", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_setequal(
    sym$components$name,
    c("distribution", "mu_linear_predictor",
      "latent_score_distribution", "implied_between_unit_covariance")
  )
  # Distribution row carries both index and matrix-form equations.
  d_row <- sym$components[sym$components$kind == "distribution", , drop = FALSE]
  expect_match(d_row$equation, "\\\\mathrm\\{Normal\\}")
  expect_match(d_row$equation_matrix, "\\\\mathcal\\{MN\\}")
  # Linear predictor index form references lambda_{B,t(j)k}.
  lp <- sym$components[sym$components$kind == "linear_predictor", , drop = FALSE]
  expect_match(lp$equation, "\\\\lambda_\\{B,t\\(j\\)k\\}")
  expect_match(lp$equation_matrix, "\\\\boldsymbol\\{\\\\Lambda\\}_B\\^\\\\top")
  # Latent score row.
  lz <- sym$components[sym$components$kind == "latent_distribution", , drop = FALSE]
  expect_match(lz$equation, "z_\\{B,ik\\} \\\\sim")
  expect_match(lz$equation_matrix, "\\\\mathbf\\{I\\}_\\{d_B\\}")
  # Implied covariance without unique() should NOT include Psi_B.
  icov <- sym$components[sym$components$kind == "implied_covariance", , drop = FALSE]
  expect_match(icov$equation, "\\\\lambda_\\{B,tk\\} \\\\lambda_\\{B,t'k\\}")
  expect_false(grepl("\\\\psi_\\{B", icov$equation, perl = FALSE))
})

test_that("symbol dictionary lists response, traits, loadings, latent scores", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit,
                   symbols = c(value = "\\mathbf{Y}"),
                   units   = c(value = "z-score"))
  d <- sym$symbol_dictionary
  expect_true(any(d$role == "response" & d$symbol_matrix == "\\mathbf{Y}"))
  expect_true(any(d$role == "trait_intercept"))
  expect_true(any(d$role == "loading" & d$symbol_matrix == "\\boldsymbol{\\Lambda}_B"))
  expect_true(any(d$role == "latent_score" & d$symbol_matrix == "\\mathbf{Z}_B"))
  expect_true(any(d$role == "implied_covariance"
                  & d$symbol_matrix == "\\boldsymbol{\\Sigma}_B"))
  expect_true(any(d$role == "residual_sd" & d$symbol == "\\sigma_\\epsilon"))
  # User-supplied units flow through.
  expect_equal(d$units[d$variable %in% "value"], "z-score")
})

test_that("assumptions are loaded from the gllvm_gaussian template family", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  a <- sym$assumptions
  expect_true(all(a$family == "gllvm_gaussian"))
  expect_true("response_distribution" %in% a$assumption)
  expect_true("latent_score_distribution" %in% a$assumption)
  expect_true("loading_identifiability" %in% a$assumption)
  expect_true("implied_between_unit_covariance" %in% a$assumption)
  # response substitution should plug in the variable name.
  rd <- a$biological_meaning[a$assumption == "response_distribution"]
  expect_match(rd, "value")
})

test_that("interpretation contains rows for trait intercepts and loadings", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  interp <- sym$interpretation
  expect_true("trait_intercept" %in% interp$coefficient_role)
  expect_true("loading" %in% interp$coefficient_role)
  # Trait intercept rows reference the trait level in the natural reading.
  ti <- interp[interp$coefficient_role == "trait_intercept", , drop = FALSE]
  expect_equal(nrow(ti), 3L)
  expect_match(ti$natural_scale_reading[[1L]], "trait_1")
  # Loading rows reference both trait and latent axis.
  ld <- interp[interp$coefficient_role == "loading", , drop = FALSE]
  expect_equal(nrow(ld), 3L)
  expect_match(ld$biological_reading[[1L]], "trait_1")
  expect_match(ld$biological_reading[[1L]], "LV1")
})

test_that("formula_bridge has one row per submodel mapping R to math", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  br <- sym$formula_bridge
  expect_equal(br$submodel, c("mu", "Lambda_B"))
  expect_match(br$r_syntax[[1L]], "value ~ 0 \\+ trait")
  expect_match(br$r_syntax[[2L]], "^latent\\(0 \\+ trait \\| site, d = 1\\)$")
  expect_match(br$mathematics[[1L]], "\\\\mu_t")
  expect_match(br$mathematics[[2L]], "\\\\lambda_\\{B,t\\(j\\)k\\}")
  expect_match(br$mathematics_matrix[[2L]], "\\\\mathbf\\{Z\\}_B")
})

test_that("expanded carries response matrix, Lambda_B, Z_B, sigma_eps", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  ex <- expand(sym)
  expect_true(is.matrix(ex$Y))
  expect_equal(dim(ex$Y), c(30L, 3L))
  expect_true(is.matrix(ex$Lambda_B))
  expect_equal(dim(ex$Lambda_B), c(3L, 1L))
  expect_true(is.matrix(ex$Z_B))
  expect_equal(dim(ex$Z_B), c(30L, 1L))
  expect_true(is.numeric(ex$sigma_eps))
  expect_length(ex$sigma_eps, 1L)
})

test_that("variance_components carries sigma_eps (and Psi_B when unique() present)", {
  fit  <- fit_gllvm_basic()
  sym  <- symbolize(fit)
  vc   <- sym$variance_components
  expect_false(is.null(vc))
  expect_true("sigma_eps" %in% vc$submodel)
  expect_false("Psi_B" %in% vc$submodel)

  fit2 <- fit_gllvm_with_unique()
  sym2 <- symbolize(fit2)
  vc2  <- sym2$variance_components
  expect_true("Psi_B" %in% vc2$submodel)
  expect_equal(sum(vc2$submodel == "Psi_B"), 3L)
})

test_that("implied covariance row includes Psi_B when unique() present", {
  fit <- fit_gllvm_with_unique()
  sym <- symbolize(fit)
  icov <- sym$components[sym$components$kind == "implied_covariance", , drop = FALSE]
  expect_match(icov$equation, "\\\\psi_\\{B,t\\}")
  expect_match(icov$equation_matrix, "\\\\boldsymbol\\{\\\\Psi\\}_B")
})

test_that("capability gating rejects planned families (poisson)", {
  fit_p <- fit_gllvm_poisson()
  expect_error(symbolize(fit_p), "Planned or reserved")
})

test_that("renderers consume symbolize.gllvmTMB output without error", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit)
  expect_silent(equations(sym))
  expect_type(as_latex(sym), "character")
  expect_type(as_latex(sym, notation = "matrix"), "character")
  expect_silent(symbol_table(sym))
  expect_silent(assumption_table(sym))
  expect_silent(parameter_interpretation(sym))
  expect_silent(formula_bridge(sym))
  expect_silent(notation_bridge(sym))
})

test_that("metadata captures call, context, package versions, created_by", {
  fit <- fit_gllvm_basic()
  sym <- symbolize(fit, context = "test gllvmTMB context")
  expect_equal(sym$metadata$context, "test gllvmTMB context")
  expect_equal(sym$metadata$created_by, "symbolize.gllvmTMB")
  expect_true(!is.null(sym$metadata$call))
  expect_true(!is.null(sym$metadata$package_versions$symbolizer))
  expect_true(!is.null(sym$metadata$package_versions$gllvmTMB))
})
