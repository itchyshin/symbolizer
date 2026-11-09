# Targeted tests for knit_print / print paths flagged as under-covered by covr
# (R/knit-print.R, R/model-card.R, R/explain.R).

capture_walkthrough <- function(expr) {
  out_lines <- character(0)
  msg_lines <- character(0)
  out_lines <- utils::capture.output(
    msg_lines <- utils::capture.output(force(expr), type = "message"),
    type = "output"
  )
  c(out_lines, msg_lines)
}

skip_if_no_knit <- function() {
  testthat::skip_if_not_installed("knitr")
}

skip_if_no_marg <- function() {
  testthat::skip_if_not_installed("emmeans")
  testthat::skip_if_not_installed("drmTMB")
}

# ---- knit_print: marginal tables -------------------------------------------

test_that("knit_print group_means and group_slopes emit titled sections", {
  skip_if_no_marg()
  skip_if_no_knit()
  set.seed(5L); n <- 120L
  body_size <- rnorm(n)
  sex <- factor(rep(c("female", "male"), length.out = n))
  body_mass <- 30 + 2 * body_size + 3 * (sex == "male") +
    1.5 * body_size * (sex == "male") + rnorm(n)
  dat <- data.frame(body_mass = body_mass, sex = sex, body_size = body_size)
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(body_mass ~ sex * body_size, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit)
  gm <- knitr::knit_print(group_means(sym))
  gs <- knitr::knit_print(group_slopes(sym, continuous = "body_size"))
  expect_s3_class(gm, "knit_asis")
  expect_s3_class(gs, "knit_asis")
  expect_match(as.character(gm), "Group means", fixed = TRUE)
  expect_match(as.character(gs), "Group slopes", fixed = TRUE)
  expect_match(as.character(gs), "body_size", fixed = TRUE)
})

test_that("knit_print group_contrasts formats binomial odds-ratio contrasts", {
  skip_if_no_marg()
  skip_if_no_knit()
  testthat::skip_if_not_installed("lme4")
  set.seed(1L)
  d <- transform(lme4::cbpp, alive = incidence > 0)
  fit <- suppressWarnings(lme4::glmer(
    alive ~ period + (1 | herd), data = d, family = stats::binomial()
  ))
  sym <- symbolize(fit)
  gc <- knitr::knit_print(group_contrasts(sym, by = "period"))
  txt <- as.character(gc)
  expect_s3_class(gc, "knit_asis")
  expect_match(txt, "Group contrasts", fixed = TRUE)
  expect_match(txt, "odds ratios", fixed = TRUE)
  expect_match(txt, "excludes the null (1)", fixed = TRUE)
})

test_that("knit_print random_effects and variance_components render tables", {
  skip_if_no_knit()
  sym <- symbolize(fit_drm_with_re())
  re <- knitr::knit_print(sym$random_effects)
  vc <- knitr::knit_print(sym$variance_components)
  expect_s3_class(re, "knit_asis")
  expect_s3_class(vc, "knit_asis")
  expect_match(as.character(re), "<code>", fixed = TRUE)
  expect_match(as.character(vc), "|", fixed = TRUE)
})

test_that("knit_print parameter_interpretation adds a single-method CI footer", {
  skip_if_no_knit()
  sym <- symbolize(fit_drm_location_scale())
  out <- as.character(knitr::knit_print(parameter_interpretation(sym)))
  expect_match(out, "CI method: `wald`", fixed = TRUE)
  expect_match(out, "excludes zero", fixed = TRUE)
})

# ---- knit_print: model_card + explain ----------------------------------------

test_that("knit_print model_card stitches every section including marginals", {
  skip_if_no_marg()
  skip_if_no_knit()
  set.seed(6L); n <- 100L
  dat <- data.frame(
    y = rnorm(n, 30), sex = factor(rep(c("F", "M"), length.out = n)),
    x = rnorm(n)
  )
  fit <- drmTMB::drmTMB(
    drmTMB::drm_formula(y ~ sex * x, sigma ~ 1),
    family = stats::gaussian(), data = dat
  )
  sym <- symbolize(fit, context = "knit coverage fixture")
  kp <- knitr::knit_print(model_card(sym))
  txt <- as.character(kp)
  expect_s3_class(kp, "knit_asis")
  expect_match(txt, "Model card", fixed = TRUE)
  expect_match(txt, "knit coverage fixture", fixed = TRUE)
  expect_match(txt, "Group means", fixed = TRUE)
  expect_match(txt, "Group slopes", fixed = TRUE)
  expect_match(txt, "Extraction calls", fixed = TRUE)
  expect_match(txt, "Recommended plots", fixed = TRUE)
})

test_that("knit_print model_card names empty extraction slots for base glm fits", {
  skip_if_no_knit()
  sym <- symbolize(stats::glm(y ~ x,
    data = data.frame(y = rbinom(50, 1, 0.5), x = rnorm(50)),
    family = stats::binomial()
  ))
  txt <- as.character(knitr::knit_print(model_card(sym)))
  expect_match(txt, "No extraction calls registered", fixed = TRUE)
  expect_match(txt, "No plot recipes registered", fixed = TRUE)
})

test_that("knit_print explain includes factor coding and variance components", {
  skip_if_no_knit()
  testthat::skip_if_not_installed("lme4")
  fit <- suppressWarnings(lme4::lmer(
    Reaction ~ Days + (1 | Subject), data = lme4::sleepstudy
  ))
  ex <- explain(fit)
  out <- as.character(knitr::knit_print(ex))
  expect_s3_class(knitr::knit_print(ex), "knit_asis")
  expect_match(out, "Explaining your", fixed = TRUE)
  expect_match(out, "How the variation splits", fixed = TRUE)
  ex_fac <- explain(lm(mpg ~ wt + cyl, data = transform(mtcars, cyl = factor(cyl))))
  fac_out <- as.character(knitr::knit_print(ex_fac))
  expect_match(fac_out, "Factor coding", fixed = TRUE)
})

# ---- print: model_card + explain ---------------------------------------------

test_that("model_card print lists factor_coding lines when factors are present", {
  skip_if_no_marg()
  dat <- transform(mtcars, gear = factor(gear))
  out <- capture_walkthrough(print(model_card(symbolize(lm(mpg ~ gear, data = dat)))))
  joined <- paste(out, collapse = " ")
  expect_match(joined, "Factor coding", fixed = TRUE)
  expect_match(joined, "gear", fixed = TRUE)
})

test_that("print model_card walks every bundle section on the console", {
  skip_if_no_marg()
  fit <- fit_drm_with_re()
  sym <- symbolize(fit, context = "console card")
  card <- model_card(sym)
  out <- capture_walkthrough(print(card))
  joined <- paste(out, collapse = " ")
  expect_match(joined, "model card", ignore.case = TRUE)
  expect_match(joined, "console card", fixed = TRUE)
  expect_match(joined, "Extraction calls", fixed = TRUE)
  expect_match(joined, "Recommended plots", fixed = TRUE)
  expect_match(joined, "Group means", fixed = TRUE)
})

test_that("explain_factors print and knit_print surface means and contrasts", {
  skip_if_no_marg()
  skip_if_no_knit()
  exf <- explain_factors(ef_fit())
  out <- capture_walkthrough(print(exf))
  joined <- paste(out, collapse = " ")
  expect_match(joined, "Factors in your", fixed = TRUE)
  expect_match(joined, "site", fixed = TRUE)
  kp <- as.character(knitr::knit_print(exf))
  expect_match(kp, "Group means", fixed = TRUE)
  expect_match(kp, "Pairwise contrasts", fixed = TRUE)
  expect_match(kp, "Interactions", fixed = TRUE)
})

test_that("print explain surfaces factor coding and variance split sections", {
  testthat::skip_if_not_installed("lme4")
  fit <- suppressWarnings(lme4::lmer(Reaction ~ Days + (1 | Subject),
                                     data = lme4::sleepstudy))
  ex <- explain(fit)
  out <- capture_walkthrough(print(ex))
  joined <- paste(out, collapse = " ")
  expect_match(joined, "How the variation splits", fixed = TRUE)
  ex_fac <- explain(lm(mpg ~ wt + cyl, data = transform(mtcars, cyl = factor(cyl))))
  fac_out <- capture_walkthrough(print(ex_fac))
  expect_true(any(grepl("Factor coding", fac_out, ignore.case = TRUE)))
})
