test_that("symbolize.glmmTMB builds a symbolized_model for a simple Gaussian fit", {
  fit <- fit_glmm_gaussian_simple()
  sym <- symbolize(fit)
  expect_s3_class(sym, "symbolized_model")
  expect_equal(sym$model$class, "glmmTMB")
  expect_equal(sym$model$family, "gaussian")
  expect_equal(sym$model$response, "body_mass")
  expect_true(nrow(sym$fixed_effects) >= 2L)
  expect_true(all(c("submodel", "term_label", "estimate",
                    "confint_low", "confint_high",
                    "excludes_zero", "ci_method") %in%
                  names(sym$fixed_effects)))
})

test_that("symbolize.glmmTMB carries 95% Wald CIs that exclude zero on a strong slope", {
  fit <- fit_glmm_gaussian_simple()
  sym <- symbolize(fit)
  slope_row <- sym$fixed_effects[sym$fixed_effects$role == "predictor", , drop = FALSE]
  expect_equal(nrow(slope_row), 1L)
  expect_false(is.na(slope_row$confint_low))
  expect_false(is.na(slope_row$confint_high))
  expect_true(slope_row$confint_low < slope_row$confint_high)
  # The seeded simulation has slope 0.4 with sigma 1.5 across 80 obs and a
  # temperature range of 10-25, so the slope is well-separated from zero.
  expect_true(slope_row$excludes_zero)
  expect_equal(slope_row$ci_method, "wald")
})

test_that("symbolize.glmmTMB handles dispformula = ~ x and produces a sigma submodel", {
  fit <- fit_glmm_gaussian_dispformula()
  sym <- symbolize(fit)
  expect_true("sigma" %in% sym$fixed_effects$submodel)
  sigma_rows <- sym$fixed_effects[sym$fixed_effects$submodel == "sigma", , drop = FALSE]
  expect_true(nrow(sigma_rows) >= 2L)  # intercept + slope on temperature
  # Both should have non-NA CIs
  expect_false(any(is.na(sigma_rows$confint_low)))
  expect_false(any(is.na(sigma_rows$confint_high)))
})

test_that("symbolize.glmmTMB handles (1 | g) random intercepts on the conditional submodel", {
  fit <- fit_glmm_gaussian_re()
  sym <- symbolize(fit)
  expect_true(!is.null(sym$random_effects) && nrow(sym$random_effects) >= 1L)
  expect_true("g" %in% sym$random_effects$group_var)
  expect_true("(Intercept)" %in% sym$random_effects$component)
  # Variance components should include both the RE SD and residual sigma
  vc <- sym$variance_components
  expect_true("residual" %in% vc$group)
  expect_true("g" %in% vc$group)
  # Residual SD should be positive
  resid_sd <- vc$sd_estimate[vc$group == "residual"]
  expect_true(resid_sd > 0)
})

test_that("symbolize.glmmTMB returns valid LaTeX for both mu-only and mu+sigma fits", {
  sym1 <- symbolize(fit_glmm_gaussian_simple())
  tex1 <- as_latex(sym1)
  expect_type(tex1, "character")
  expect_match(tex1, "Normal", fixed = TRUE)
  expect_match(tex1, "mu", fixed = TRUE)

  sym2 <- symbolize(fit_glmm_gaussian_dispformula())
  tex2 <- as_latex(sym2)
  expect_match(tex2, "log", fixed = TRUE)
  expect_match(tex2, "sigma", fixed = TRUE)
})

test_that("symbolize.glmmTMB rejects ziformula (not in v0.7 first slice)", {
  testthat::skip_if_not_installed("glmmTMB")
  set.seed(7L)
  n <- 60
  dat <- data.frame(y = rnorm(n), x = rnorm(n))
  fit <- suppressWarnings(glmmTMB::glmmTMB(
    y ~ x, ziformula = ~ x, data = dat, family = stats::gaussian()
  ))
  expect_error(symbolize(fit), "not in the first slice|Planned|reserved|not yet supported",
               ignore.case = TRUE)
})

test_that("symbolize.glmmTMB's interpretation tibble carries the CI columns", {
  fit <- fit_glmm_gaussian_simple()
  sym <- symbolize(fit)
  interp <- sym$interpretation
  expect_true(all(c("confint_low", "confint_high", "excludes_zero", "ci_method") %in%
                  names(interp)))
  # At least one row should have non-NA CI bounds (the intercept and slope)
  expect_true(sum(!is.na(interp$confint_low)) >= 1L)
})

# Audit B1: the glmmTMB extractor must surface the conditional design
# matrix X and the response-scale fitted mean so Tab 3 fills with data.
test_that("symbolize.glmmTMB populates expanded$X / mu_hat (audit B1)", {
  fit <- fit_glmm_poisson()  # FE-only Poisson (log link)
  sym <- symbolize(fit)
  ex <- sym$expanded
  expect_true(is.matrix(ex$X))
  expect_equal(nrow(ex$X), sym$model$n_obs)
  expect_equal(length(ex$beta), ncol(ex$X))
  # eta_hat = X*beta on link scale; mu_hat = exp(eta_hat) = fitted.
  expect_equal(as.numeric(ex$eta_hat),
               as.numeric(ex$X %*% ex$beta), tolerance = 1e-6)
  expect_equal(as.numeric(ex$mu_hat),
               as.numeric(stats::fitted(fit)), tolerance = 1e-6)
  html <- as_html_three_views(sym)
  expect_false(grepl("not captured", html))
  expect_match(html, "mathbf\\{X\\}")
})

test_that("symbolize.glmmTMB populates the Z*u block so Tab 3 closes (audit #11)", {
  sym <- symbolize(fit_glmm_gaussian_re())   # Gaussian (1 | g) random intercepts
  ex  <- sym$expanded
  expect_true(is.matrix(ex$Z_g))
  expect_false(is.null(ex$u))
  expect_equal(nrow(ex$Z_g), sym$model$n_obs)
  expect_equal(ncol(ex$Z_g), length(ex$u))
  # The decomposition must close: y_i = X_i*beta + (Z*u)_i + resid_i, and the
  # link-scale predictor is the full conditional X*beta + Z*u (no double count).
  i  <- 1L
  xb <- sum(ex$X[i, ] * ex$beta)
  zu <- sum(ex$Z_g[i, ] * ex$u)
  expect_equal(ex$eta_hat[[i]], xb + zu, tolerance = 1e-6)
  expect_equal(ex$y[[i]], xb + zu + (ex$y[[i]] - ex$mu_hat[[i]]), tolerance = 1e-6)
  # The stacked matrix now surfaces the Z and u blocks instead of dropping them.
  html <- as_html_three_views(sym)
  expect_match(html, "mathbf\\{Z\\}")
  expect_match(html, "mathbf\\{u\\}")
})

test_that("symbolize.glmmTMB without random effects leaves Z_g / u NULL", {
  ex <- symbolize(fit_glmm_gaussian_simple())$expanded
  expect_null(ex$Z_g)
  expect_null(ex$u)
})

test_that("a constant-scale Gaussian matrix form is sigma^2 I, not a heteroscedastic diag", {
  skip_if_not_installed("glmmTMB")
  set.seed(1); n <- 80; x <- runif(n, 10, 25)
  d <- data.frame(y = rnorm(n, 30 + 0.4 * x, 2), x = x)
  m <- symbolize(glmmTMB::glmmTMB(y ~ x, data = d))$distribution$latex_matrix
  expect_match(m, "\\sigma^2 \\mathbf{I}", fixed = TRUE)
  expect_false(grepl("diag", m, fixed = TRUE))    # not the per-observation form
  # a modelled dispersion (dispformula) genuinely IS heteroscedastic -> keep diag
  d2 <- data.frame(y = rnorm(n, 30 + 0.4 * x, exp(0.3 + 0.05 * x)), x = x)
  md <- symbolize(glmmTMB::glmmTMB(y ~ x, dispformula = ~ x, data = d2))$distribution$latex_matrix
  expect_match(md, "diag", fixed = TRUE)
})

test_that("a glmmTMB dispformula reports a modelled residual, not a retrieval failure", {
  skip_if_not_installed("glmmTMB")
  set.seed(2); n <- 160; x <- runif(n, 10, 25)
  g <- factor(rep(letters[1:10], length.out = n))
  d <- data.frame(y = rnorm(n, 30 + 0.4 * x + rnorm(10)[g], exp(0.3 + 0.05 * x)),
                  x = x, g = g)
  sym <- symbolize(glmmTMB::glmmTMB(y ~ x + (1 | g), dispformula = ~ x, data = d))
  # no misleading NA-valued residual row
  vc <- sym$variance_components
  expect_false(any(vc$group == "residual" & is.na(vc$sd_estimate)))
  # icc() reports the residual as modelled (location-scale), not "could not retrieve"
  ic <- icc(sym)
  expect_true(is.na(as.numeric(ic)))
  expect_no_match(attr(ic, "reason"), "could not retrieve")
  expect_match(attr(ic, "reason"), "varies across observations|location-scale")
})
