# Tests for build_factor_coding() -- the reference-level + contrast-scheme
# metadata that downstream readers consult instead of guessing levels[1].

make_factor_data <- function() {
  data.frame(
    y    = as.numeric(1:12),
    x    = as.numeric(1:12),
    site = factor(rep(c("A", "B", "C"), 4)),
    sex  = factor(rep(c("female", "male"), 6))
  )
}

test_that("default treatment coding: type, reference, dummies, levels", {
  d  <- make_factor_data()
  tt <- extract_terms(y ~ site, d, "mu")
  fc <- build_factor_coding(d, tt)

  expect_s3_class(fc, "tbl_df")
  expect_equal(nrow(fc), 1L)
  expect_equal(fc$variable, "site")
  expect_equal(fc$contrast_type, "treatment")
  expect_equal(fc$reference_level, "A")
  expect_true(fc$is_default_treatment)
  expect_equal(fc$n_dummies, 2L)
  expect_equal(fc$levels[[1L]], c("A", "B", "C"))
})

test_that("relevel() keeps treatment coding with the new base as reference", {
  d <- make_factor_data()
  d$site <- relevel(d$site, ref = "B")
  fc <- build_factor_coding(d, extract_terms(y ~ site, d, "mu"))

  expect_equal(fc$contrast_type, "treatment")
  expect_equal(fc$reference_level, "B")
  # base is still the first level after relevel, so it remains "default" coding
  expect_true(fc$is_default_treatment)
})

test_that("treatment coding with a non-first base is flagged non-default", {
  d <- make_factor_data()
  contrasts(d$site) <- contr.treatment(3, base = 2)
  fc <- build_factor_coding(d, extract_terms(y ~ site, d, "mu"))

  expect_equal(fc$contrast_type, "treatment")
  expect_equal(fc$reference_level, levels(d$site)[[2L]])
  expect_false(fc$is_default_treatment)
})

test_that("sum-to-zero contrasts: type 'sum', no reference", {
  d <- make_factor_data()
  contrasts(d$site) <- contr.sum(3)
  fc <- build_factor_coding(d, extract_terms(y ~ site, d, "mu"))

  expect_equal(fc$contrast_type, "sum")
  expect_true(is.na(fc$reference_level))
  expect_false(fc$is_default_treatment)
})

test_that("Helmert contrasts classified as 'helmert' with no reference", {
  d <- make_factor_data()
  contrasts(d$site) <- contr.helmert(3)
  fc <- build_factor_coding(d, extract_terms(y ~ site, d, "mu"))

  expect_equal(fc$contrast_type, "helmert")
  expect_true(is.na(fc$reference_level))
})

test_that("ordered factor defaults to polynomial contrasts", {
  d <- make_factor_data()
  d$grade <- factor(rep(c("low", "mid", "high"), 4),
                    levels = c("low", "mid", "high"), ordered = TRUE)
  fc <- build_factor_coding(d, extract_terms(y ~ grade, d, "mu"))

  expect_equal(fc$contrast_type, "poly")
  expect_true(is.na(fc$reference_level))
})

test_that("contr.SAS uses the last level as the reference", {
  d <- make_factor_data()
  contrasts(d$site) <- contr.SAS(3)
  fc <- build_factor_coding(d, extract_terms(y ~ site, d, "mu"))

  expect_equal(fc$contrast_type, "treatment")  # SAS is treatment-family
  expect_equal(fc$reference_level, levels(d$site)[[3L]])
  expect_false(fc$is_default_treatment)
})

test_that("intercept-less fit gives cell-means coding", {
  d  <- make_factor_data()
  fc <- build_factor_coding(d, extract_terms(y ~ 0 + site, d, "mu"))

  expect_equal(fc$contrast_type, "cell_means")
  expect_equal(fc$n_dummies, 3L)
  expect_true(is.na(fc$reference_level))
  expect_equal(fc$levels[[1L]], c("A", "B", "C"))
})

test_that("two factors produce two rows", {
  d  <- make_factor_data()
  fc <- build_factor_coding(d, extract_terms(y ~ site + sex, d, "mu"))

  expect_equal(nrow(fc), 2L)
  expect_setequal(fc$variable, c("site", "sex"))
})

test_that("a factor appearing only in an interaction is captured", {
  d  <- make_factor_data()
  fc <- build_factor_coding(d, extract_terms(y ~ x:sex, d, "mu"))

  expect_true("sex" %in% fc$variable)
})

test_that("a model with no factors returns NULL", {
  d  <- make_factor_data()
  expect_null(build_factor_coding(d, extract_terms(y ~ x, d, "mu")))
})

test_that("character predictors are treated as factors", {
  d <- make_factor_data()
  d$region <- rep(c("north", "south"), 6)  # character, not factor
  fc <- build_factor_coding(d, extract_terms(y ~ region, d, "mu"))

  expect_equal(fc$variable, "region")
  expect_equal(fc$contrast_type, "treatment")
})

test_that("symbolize(lm) carries factor_coding on the object", {
  d   <- make_factor_data()
  fit <- lm(y ~ site + sex, data = d)
  sym <- symbolize(fit)

  expect_false(is.null(sym$factor_coding))
  expect_setequal(sym$factor_coding$variable, c("site", "sex"))
  site_row <- sym$factor_coding[sym$factor_coding$variable == "site", ]
  expect_equal(site_row$reference_level, "A")
})

test_that("symbolize(lm) with contrasts = argument records the real scheme", {
  d   <- make_factor_data()
  fit <- lm(y ~ site, data = d, contrasts = list(site = "contr.sum"))
  sym <- symbolize(fit)

  site_row <- sym$factor_coding[sym$factor_coding$variable == "site", ]
  expect_equal(site_row$contrast_type, "sum")
  expect_true(is.na(site_row$reference_level))
})

test_that("S4 fits (lme4 merMod) do not break the contrasts lookup", {
  skip_if_not_installed("lme4")
  d <- make_factor_data()
  d$g <- factor(rep(c("g1", "g2", "g3", "g4"), 3))
  fit <- lme4::lmer(y ~ site + (1 | g), data = d)
  # The S4 `$contrasts` access used to abort; it must now resolve via the
  # model-frame contrasts instead.
  sym <- symbolize(fit)
  expect_false(is.null(sym$factor_coding))
  site_row <- sym$factor_coding[sym$factor_coding$variable == "site", ]
  expect_equal(site_row$contrast_type, "treatment")
  expect_equal(site_row$reference_level, "A")
})

test_that("non-default contrasts raise a templated warning", {
  d <- make_factor_data()
  contrasts(d$site) <- contr.sum(3)
  sym <- symbolize(lm(y ~ site, data = d))
  w <- warning_table(sym)
  hit <- w[w$code == "non_default_contrasts", , drop = FALSE]
  expect_equal(nrow(hit), 1L)
  expect_equal(hit$severity, "warn")
  expect_match(hit$message, "sum")
  expect_match(hit$message, "site")
})

test_that("default treatment coding raises no contrast warning", {
  d <- make_factor_data()
  sym <- symbolize(lm(y ~ site + sex, data = d))
  w <- warning_table(sym)
  expect_equal(nrow(w[w$code == "non_default_contrasts", , drop = FALSE]), 0L)
})

test_that("cell-means coding is exempt from the contrast warning", {
  d <- make_factor_data()
  sym <- symbolize(lm(y ~ 0 + site, data = d))
  w <- warning_table(sym)
  expect_equal(nrow(w[w$code == "non_default_contrasts", , drop = FALSE]), 0L)
})

test_that("Helmert coding names its scheme in the warning", {
  d <- make_factor_data()
  contrasts(d$site) <- contr.helmert(3)
  sym <- symbolize(lm(y ~ site, data = d))
  hit <- warning_table(sym)
  hit <- hit[hit$code == "non_default_contrasts", , drop = FALSE]
  expect_match(hit$message, "Helmert contrasts")
})

test_that("a factor only inside an interaction is labelled interaction_only, no false reference", {
  d <- make_factor_data()
  fc <- build_factor_coding(d, extract_terms(y ~ 0 + x:site, d, "mu"))
  row <- fc[fc$variable == "site", , drop = FALSE]
  expect_equal(row$contrast_type, "interaction_only")
  expect_true(is.na(row$reference_level))
  expect_false(row$is_default_treatment)
})

test_that("interaction_only factors raise no non_default_contrasts warning", {
  d <- make_factor_data()
  sym <- symbolize(lm(y ~ 0 + x:site, data = d))
  w <- warning_table(sym)
  expect_equal(nrow(w[w$code == "non_default_contrasts", , drop = FALSE]), 0L)
})

test_that("non-first-base treatment warns about a non-default reference, not 'treatment contrasts'", {
  d <- make_factor_data()
  sym <- symbolize(lm(y ~ site, data = d, contrasts = list(site = "contr.SAS")))
  hit <- warning_table(sym)
  hit <- hit[hit$code == "non_default_contrasts", , drop = FALSE]
  expect_equal(nrow(hit), 1L)
  expect_match(hit$message, "non-default reference")
  expect_false(grepl("uses treatment contrasts", hit$message))
})

test_that("factor levels with regex metacharacters / backslashes render literally", {
  bs  <- rawToChar(as.raw(92L))
  lvl <- paste0("dose", bs, "1")
  prose <- factor_template_prose(
    "factor_overview", "treatment",
    list(variable = "grp", k = 2, levels = paste0("ctrl, ", lvl),
         reference_level = "ctrl", n_dummy = 1)
  )
  expect_true(grepl(lvl, prose, fixed = TRUE))
})

test_that("validate_symbolized_model accepts NULL and a well-formed tibble", {
  d   <- make_factor_data()
  fit <- lm(y ~ site, data = d)
  sym <- symbolize(fit)

  # The constructor already validated it; round-trip a NULL too.
  sym$factor_coding <- NULL
  expect_invisible(validate_symbolized_model(sym))
})
