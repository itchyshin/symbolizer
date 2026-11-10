# Coverage for R/methods-text.R and R/simulate-recipe.R branches that covr
# still misses on main (~88%).

test_that("methods_text runs for glm/lm/glmmTMB/gllvmTMB/lmerMod template slots", {
  testthat::skip_if_not_installed("glmmTMB")
  testthat::skip_if_not_installed("gllvmTMB")
  testthat::skip_if_not_installed("lme4")

  sym_lm <- symbolize(lm(mpg ~ wt + cyl, data = transform(mtcars, cyl = factor(cyl))))
  mt_lm <- methods_text(sym_lm)
  expect_match(mt_lm$text, "ordinary linear model", fixed = TRUE)
  expect_match(mt_lm$text, "32 observations", fixed = TRUE)
  expect_match(mt_lm$text, "mpg", fixed = TRUE)
  expect_false(grepl("[unfilled:", mt_lm$text, fixed = TRUE))

  sym_glm <- symbolize(glm(
    am ~ wt + factor(cyl), data = mtcars, family = stats::binomial()
  ))
  mt_glm <- methods_text(sym_glm)
  expect_match(mt_glm$text, "logit", fixed = TRUE)
  expect_match(mt_glm$text, "odds ratio", fixed = TRUE)

  sym_glt <- symbolize(fit_glmm_gaussian_simple())
  mt_glt <- methods_text(sym_glt)
  expect_match(mt_glt$text, "Gaussian", fixed = TRUE)
  expect_false(grepl("[unfilled:", mt_glt$text, fixed = TRUE))

  sym_disp <- symbolize(fit_glmm_gaussian_dispformula())
  mt_disp <- methods_text(sym_disp)
  expect_match(mt_disp$text, "scale", ignore.case = TRUE)

  if (requireNamespace("gllvmTMB", quietly = TRUE)) {
    sym_glv <- symbolize(fit_gllvm_basic())
    mt_glv <- methods_text(sym_glv)
    expect_match(mt_glv$text, "latent", ignore.case = TRUE)
    expect_match(mt_glv$text, "traits", ignore.case = TRUE)
  }

  fit_lmer <- suppressWarnings(lme4::lmer(
    Reaction ~ Days + (1 | Subject), data = lme4::sleepstudy
  ))
  sym_lmer <- symbolize(fit_lmer)
  mt_lmer <- methods_text(sym_lmer)
  expect_match(mt_lmer$text, "Gaussian", fixed = TRUE)
  expect_match(mt_lmer$text, "random intercept", fixed = TRUE)
})

test_that("methods_text runs for a brms Gaussian fit", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("brms")
  sym <- symbolize(fit_brms_gaussian_simple())
  mt <- methods_text(sym)
  expect_match(mt$text, "Gaussian", fixed = TRUE)
  expect_false(grepl("[unfilled:", mt$text, fixed = TRUE))
})

test_that("methods_text units clauses and rho12 phrasing helpers resolve", {
  fit <- fit_drm_biv_gaussian()
  sym <- symbolize(fit, units = c(y1 = "mm", y2 = "g"))
  mt <- methods_text(sym)
  expect_match(mt$text, "units", ignore.case = TRUE)
  expect_match(mt$text, "mm", fixed = TRUE)
  expect_match(mt$text, "g", fixed = TRUE)
  expect_match(mt$text, "both intercept-only", fixed = TRUE)
})

test_that("methods internal helpers cover oxford list and package version fallback", {
  expect_identical(
    symbolizer:::methods_oxford_list(c("a")),
    "`a`"
  )
  expect_match(
    symbolizer:::methods_oxford_list(c("a", "b", "c")),
    "`a`, `b`, and `c`",
    fixed = TRUE
  )
  expect_identical(symbolizer:::methods_pkg_version(""), "??")
  expect_identical(symbolizer:::methods_pkg_version("DefinitelyNotAPackage999"), "??")
})

# ---- simulate_recipe families ------------------------------------------------

test_that("simulate_recipe covers zi, nbinom2, beta, lognormal, and student paths", {
  testthat::skip_if_not_installed("glmmTMB")

  set.seed(21L); n <- 120L
  dat_zi <- data.frame(y = stats::rpois(n, 3) * stats::rbinom(n, 1, 0.7),
                       x = stats::rnorm(n))
  fit_zi <- suppressWarnings(glmmTMB::glmmTMB(
    y ~ x, ziformula = ~ x, data = dat_zi, family = stats::poisson()
  ))
  sym_zi <- symbolize(fit_zi)
  rec_zi <- simulate_recipe(sym_zi)
  expect_match(rec_zi$r_code, "pi_zi", fixed = TRUE)
  expect_match(rec_zi$r_code, "rpois", fixed = TRUE)
  expect_true(rec_zi$metadata$has_zi)

  sym_nb <- symbolize(fit_drm_nbinom2())
  rec_nb <- simulate_recipe(sym_nb)
  expect_match(rec_nb$r_code, "rnbinom", fixed = TRUE)
  expect_true(rec_nb$metadata$has_sigma)

  sym_be <- symbolize(suppressWarnings(fit_drm_beta()))
  rec_be <- simulate_recipe(sym_be)
  expect_match(rec_be$r_code, "rbeta", fixed = TRUE)

  sym_ln <- symbolize(suppressWarnings(fit_drm_lognormal()))
  rec_ln <- simulate_recipe(sym_ln)
  expect_match(rec_ln$r_code, "rnorm", fixed = TRUE)
  expect_true(any(grepl("N\\(mu_i", rec_ln$pseudocode)))

  sym_st <- symbolize(fit_drm_student())
  rec_st <- simulate_recipe(sym_st)
  expect_match(rec_st$r_code, "rnorm", fixed = TRUE)
})

test_that("simulate_recipe print and knit_print emit the recipe body", {
  testthat::skip_if_not_installed("knitr")
  rec <- simulate_recipe(symbolize(fit_drm_poisson()))
  msgs <- utils::capture.output(
    utils::capture.output(print(rec), type = "message")
  )
  joined <- paste(msgs, collapse = "\n")
  expect_match(joined, "Simulation recipe", fixed = TRUE)
  expect_match(joined, "rpois", fixed = TRUE)

  kp <- knitr::knit_print(rec)
  expect_s3_class(kp, "knit_asis")
  expect_match(as.character(kp), "```r", fixed = TRUE)
  expect_match(as.character(kp), "Pseudocode", fixed = TRUE)
})

