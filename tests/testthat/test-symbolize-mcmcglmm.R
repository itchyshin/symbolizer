test_that("symbolize.MCMCglmm requires the data argument", {
  testthat::skip_if_not_installed("MCMCglmm")
  bundle <- fit_mcmcglmm_gaussian_simple()
  expect_error(symbolize(bundle$fit), "data.*required|MCMCglmm.*data",
               ignore.case = TRUE)
})

test_that("symbolize.MCMCglmm builds a symbolized_model for a Gaussian fit", {
  bundle <- fit_mcmcglmm_gaussian_simple()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "MCMCglmm")
  expect_equal(sym$model$family, "gaussian")
  expect_equal(sym$model$response, "body_mass")
  expect_equal(sym$metadata$ci_method, "credible")
})

test_that("MCMCglmm fixed_effects carries 95% credible band labelled 'credible'", {
  bundle <- fit_mcmcglmm_gaussian_simple()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_true(all(c("confint_low", "confint_high",
                    "excludes_zero", "ci_method") %in%
                  names(sym$fixed_effects)))
  expect_true(all(sym$fixed_effects$ci_method == "credible"))
  slope_row <- sym$fixed_effects[sym$fixed_effects$role == "predictor", ,
                                 drop = FALSE]
  expect_equal(nrow(slope_row), 1L)
  expect_false(is.na(slope_row$confint_low))
  expect_false(is.na(slope_row$confint_high))
})

test_that("MCMCglmm ~ g random intercepts produce group + RE rows", {
  bundle <- fit_mcmcglmm_gaussian_re()
  sym <- symbolize(bundle$fit, data = bundle$data)
  expect_true(!is.null(sym$random_effects) && nrow(sym$random_effects) >= 1L)
  expect_true("g" %in% sym$random_effects$group_var)
  expect_true("(Intercept)" %in% sym$random_effects$component)
  vc <- sym$variance_components
  expect_true("g" %in% vc$group)
  expect_true("residual" %in% vc$group)
})

test_that("symbolize.MCMCglmm produces valid LaTeX", {
  bundle <- fit_mcmcglmm_gaussian_simple()
  sym <- symbolize(bundle$fit, data = bundle$data)
  tex <- as_latex(sym)
  expect_type(tex, "character")
  expect_match(tex, "Normal", fixed = TRUE)
})

# Audit B1: the MCMCglmm extractor must surface the fixed-effects design
# matrix X (from fit$X) and the response-scale fitted mean so Tab 3
# ("equations with data") fills the stacked-matrix block instead of the
# "design matrix not captured" placeholder.
test_that("symbolize.MCMCglmm populates expanded$X (audit B1)", {
  bundle <- fit_mcmcglmm_gaussian_simple()
  sym <- symbolize(bundle$fit, data = bundle$data)
  ex <- sym$expanded
  expect_true(is.matrix(ex$X))
  expect_equal(nrow(ex$X), sym$model$n_obs)
  expect_equal(length(ex$beta), ncol(ex$X))
  # No per-level random effects were saved (pr = FALSE), so mu_hat is the
  # fixed-effects-only prediction X*beta (identity link), and there is no
  # dangling RE term.
  expect_null(ex$Z_g)
  expect_equal(as.numeric(ex$mu_hat),
               as.numeric(ex$X %*% ex$beta), tolerance = 1e-8)
  # Tab 3 shows the design matrix, not the placeholder.
  html <- as_html_three_views(sym)
  expect_false(grepl("not captured", html))
  expect_match(html, "mathbf\\{X\\}")
})

# Audit B2: when the fit saved the per-level random effects (pr = TRUE),
# the extractor must surface Z_g + u so the worked row closes on
# mu_hat = X*beta + Z*u row-by-row, instead of joining an intercept-only
# X*beta to the full fitted mean with \approx.
test_that("symbolize.MCMCglmm with pr=TRUE closes mu_hat = X*beta + Z*u (audit B2)", {
  testthat::skip_if_not_installed("MCMCglmm")
  set.seed(202L)
  ped <- data.frame(
    animal = paste0("a", 1:30),
    sire = c(rep(NA, 6), sample(paste0("a", 1:3), 24, replace = TRUE)),
    dam  = c(rep(NA, 6), sample(paste0("a", 4:6), 24, replace = TRUE))
  )
  Ainv <- MCMCglmm::inverseA(ped)$Ainv
  animal <- factor(rep(paste0("a", 1:30), 2))
  phenotype <- rnorm(60, mean = as.integer(animal) * 0.1, sd = 1)
  dat <- data.frame(phenotype = phenotype, animal = animal)
  fit <- suppressWarnings(suppressMessages(MCMCglmm::MCMCglmm(
    phenotype ~ 1, random = ~animal, data = dat,
    ginverse = list(animal = Ainv),
    nitt = 1500, burnin = 500, thin = 2, verbose = FALSE, pr = TRUE
  )))
  sym <- symbolize(fit, data = dat)
  ex <- sym$expanded
  expect_true(is.matrix(ex$Z_g))
  expect_equal(length(ex$u), ncol(ex$Z_g))
  # mu_hat equals the FULL conditional prediction, not the intercept-only
  # X*beta. The two genuinely differ here (the B2 scenario).
  xb <- as.numeric(ex$X %*% ex$beta)
  full <- xb + as.numeric(ex$Z_g %*% ex$u)
  expect_equal(as.numeric(ex$mu_hat), full, tolerance = 1e-6)
  expect_false(isTRUE(all.equal(as.numeric(ex$mu_hat), xb)))
  # The worked row must NOT join the intercept-only value to mu_hat with
  # \approx; it shows one consistent mu_hat with the RE term added in.
  wr <- as_html_three_views(sym)
  expect_match(wr, "hat\\{u\\}")          # the BLUP term is rendered
  expect_false(grepl("not captured", wr))
})
